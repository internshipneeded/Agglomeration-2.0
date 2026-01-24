import os
import warnings
from io import BytesIO
from contextlib import asynccontextmanager

import cv2
import numpy as np
import torch
import xgboost as xgb
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List, Optional
from PIL import Image
from cnn_model import CNNModel

warnings.filterwarnings('ignore', category=FutureWarning)

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

# Global models
yolo_model = None
cnn_model = None
xgb_model = None


# Pydantic models for responses
class BoundingBox(BaseModel):
    x1: int
    y1: int
    x2: int
    y2: int


class BottleDetection(BaseModel):
    bottle_id: int
    bbox: BoundingBox
    confidence: float
    classification: str
    pet_probability: Optional[float] = None
    transparency_probability: float


class HealthResponse(BaseModel):
    status: str
    models_loaded: dict


class PredictionResponse(BaseModel):
    success: bool
    message: str
    bottles: List[BottleDetection]


class ErrorResponse(BaseModel):
    success: bool
    error: str


def initialize_models(cnn_model_path='models/cnn_model.pth', xgb_model_path='models/xgb_model.json'):
    """Initialize all models (YOLO, CNN, XGBoost)."""
    global yolo_model, cnn_model, xgb_model
    
    # Load YOLO model
    try:
        print("Loading YOLO model...")
        yolo_model = torch.hub.load('ultralytics/yolov5', 'yolov5s', trust_repo=True).to(device)
        yolo_model.eval()
        print(f"YOLO model loaded (device: {device})")
    except Exception as e:
        print(f"Error loading YOLO model: {e}")
        yolo_model = None
    
    # Load CNN model
    if os.path.exists(cnn_model_path):
        cnn_model = CNNModel().to(device)
        cnn_model.load_state_dict(torch.load(cnn_model_path, map_location=device))
        cnn_model.eval()
        print(f"CNN model loaded from {cnn_model_path}")
    else:
        print(f"Warning: CNN model not found at {cnn_model_path}. Transparency feature will be zeros.")
        cnn_model = None
    
    # Load XGBoost model
    if os.path.exists(xgb_model_path):
        xgb_model = xgb.XGBClassifier()
        xgb_model.load_model(xgb_model_path)
        print(f"XGBoost model loaded from {xgb_model_path}")
    else:
        print(f"Warning: XGBoost model not found at {xgb_model_path}.")
        xgb_model = None
    
    print("All models initialized successfully!")


def detect_bottles(img_bgr):
    """Detect bottles in image using YOLO.
    
    Args:
        img_bgr: Image in BGR format (numpy array)
    
    Returns:
        detections: Array of detections [x1, y1, x2, y2, conf, cls]
    """
    results = yolo_model(img_bgr)
    return results.xyxy[0].cpu().numpy()


def predict_transparency(cnn_model, bottle_image_rgb):
    """Return transparency probability from CNN; if model missing, return 0.0.
    Expects bottle_image_rgb as HxWx3 RGB numpy array sized 32x32.
    """
    if cnn_model is None:
        return 0.0
    with torch.no_grad():
        tensor = torch.from_numpy(bottle_image_rgb).permute(2, 0, 1).float() / 255.0
        tensor = tensor.unsqueeze(0).to(device)
        prob = cnn_model(tensor).item()
        return float(prob)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    # Startup
    initialize_models(
        cnn_model_path=os.getenv('CNN_MODEL_PATH', 'models/cnn_model.pth'),
        xgb_model_path=os.getenv('XGB_MODEL_PATH', 'models/xgb_model.json')
    )
    yield
    # Shutdown
    print("Shutting down...")


app = FastAPI(
    title="PET Bottle Classifier API",
    description="Detect and classify bottles as PET or Non-PET using YOLO, CNN, and XGBoost",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy",
        models_loaded={
            'yolo': yolo_model is not None,
            'cnn': cnn_model is not None,
            'xgboost': xgb_model is not None
        }
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict(image: UploadFile = File(...)):
    """
    Predict if bottles in uploaded image are PET or Non-PET.
    
    Args:
        image: Image file (multipart/form-data)
    
    Returns:
        PredictionResponse with detection results
    """
    if yolo_model is None:
        raise HTTPException(
            status_code=503,
            detail="YOLO model not loaded"
        )
    
    try:
        # Read image
        image_bytes = await image.read()
        image_pil = Image.open(BytesIO(image_bytes))
        image_np = np.array(image_pil)
        
        # Convert to BGR for OpenCV and YOLO
        if len(image_np.shape) == 2:  # Grayscale
            img_bgr = cv2.cvtColor(image_np, cv2.COLOR_GRAY2BGR)
        elif image_np.shape[2] == 4:  # RGBA
            img_bgr = cv2.cvtColor(image_np, cv2.COLOR_RGBA2BGR)
        else:  # RGB
            img_bgr = cv2.cvtColor(image_np, cv2.COLOR_RGB2BGR)
        
        # Detect bottles
        detections = detect_bottles(img_bgr)
        
        if len(detections) == 0:
            return PredictionResponse(
                success=True,
                message="No bottles detected in the image",
                bottles=[]
            )
        
        # Process each detection
        results = []
        for idx, (*box, conf, cls) in enumerate(detections):
            x1, y1, x2, y2 = map(int, box)
            
            # Extract bottle crop
            bottle_crop_bgr = img_bgr[y1:y2, x1:x2]
            if bottle_crop_bgr.size == 0:
                continue
            
            # Resize and convert to RGB
            bottle_crop_rgb = cv2.resize(bottle_crop_bgr, (32, 32))
            bottle_crop_rgb = cv2.cvtColor(bottle_crop_rgb, cv2.COLOR_BGR2RGB)
            
            # Get transparency probability
            transparency_prob = predict_transparency(cnn_model, bottle_crop_rgb)
            
            # Get PET classification
            if xgb_model is not None:
                # Prepare features
                flat_features = bottle_crop_rgb.astype(np.float32).reshape(-1) / 255.0
                features = np.concatenate([flat_features, np.array([transparency_prob])])
                features = features.reshape(1, -1)
                
                # Predict
                pet_prob = xgb_model.predict_proba(features)[0, 1]
                is_pet = pet_prob > 0.5
                
                results.append(BottleDetection(
                    bottle_id=idx + 1,
                    bbox=BoundingBox(x1=x1, y1=y1, x2=x2, y2=y2),
                    confidence=float(conf),
                    classification='PET' if is_pet else 'Non-PET',
                    pet_probability=float(pet_prob),
                    transparency_probability=float(transparency_prob)
                ))
            else:
                results.append(BottleDetection(
                    bottle_id=idx + 1,
                    bbox=BoundingBox(x1=x1, y1=y1, x2=x2, y2=y2),
                    confidence=float(conf),
                    classification='unavailable',
                    transparency_probability=float(transparency_prob)
                ))
        
        return PredictionResponse(
            success=True,
            message=f"Detected {len(results)} bottle(s)",
            bottles=results
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing image: {str(e)}"
        )


if __name__ == '__main__':
    import uvicorn
    
    port = int(os.getenv('PORT', 8000))
    uvicorn.run(app, host='0.0.0.0', port=port)
