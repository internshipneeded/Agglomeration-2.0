import argparse
import os
import warnings
from pathlib import Path

import cv2
import gradio as gr
import numpy as np
import torch
import xgboost as xgb
from PIL import Image

from cnn_model import CNNModel

warnings.filterwarnings('ignore', category=FutureWarning)

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

# Global models - will be loaded in initialize_models()
yolo_model = None
cnn_model = None
xgb_model = None


def initialize_models(cnn_model_path='models/cnn_model.pth', xgb_model_path='models/xgb_model.json'):
    """Initialize all models (YOLO, CNN, XGBoost)."""
    global yolo_model, cnn_model, xgb_model
    
    # Load YOLO model
    print("Loading YOLO model...")
    yolo_model = torch.hub.load('ultralytics/yolov5', 'yolov5s').to(device)
    yolo_model.eval()
    print(f"YOLO model loaded (device: {device})")
    
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
        print(f"Warning: XGBoost model not found at {xgb_model_path}. Classification disabled.")
        xgb_model = None
    
    print("All models initialized successfully!")


def predict_transparency(cnn_model, bottle_image_rgb):
    """Return transparency probability from CNN; if model missing, return 0.0.
    Expects bottle_image_rgb as HxWx3 RGB numpy array.
    """
    if cnn_model is None:
        return 0.0
    with torch.no_grad():
        tensor = torch.from_numpy(bottle_image_rgb).permute(2, 0, 1).float() / 255.0
        tensor = tensor.unsqueeze(0).to(device)
        prob = cnn_model(tensor).item()
    return float(prob)


def detect_bottles(img_bgr):
    """Detect bottles in image using YOLO.
    
    Args:
        img_bgr: Image in BGR format (numpy array)
    
    Returns:
        detections: Array of detections [x1, y1, x2, y2, conf, cls]
    """
    results = yolo_model(img_bgr)
    return results.xyxy[0].cpu().numpy()


def classify_bottle(image):
    """
    Detect bottles in image and classify as PET or Non-PET.
    
    Args:
        image: PIL Image or numpy array (RGB format)
    
    Returns:
        annotated_image: Image with bounding boxes and labels
        results_text: Classification results as text
    """
    # Convert PIL to numpy if needed
    if isinstance(image, Image.Image):
        image = np.array(image)
    
    # Convert RGB to BGR for OpenCV and YOLO
    img_bgr = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
    
    # Detect bottles using YOLO
    detections = detect_bottles(img_bgr)
    
    if len(detections) == 0:
        return image, "No bottles detected in the image."
    
    # Process each detection
    results_list = []
    annotated_img = image.copy()
    
    for idx, (*box, conf, cls) in enumerate(detections):
        x1, y1, x2, y2 = map(int, box)
        
        # Extract bottle crop
        bottle_crop_bgr = img_bgr[y1:y2, x1:x2]
        if bottle_crop_bgr.size == 0:
            continue
            
        # Resize and convert to RGB for models
        bottle_crop_rgb = cv2.resize(bottle_crop_bgr, (32, 32))
        bottle_crop_rgb = cv2.cvtColor(bottle_crop_rgb, cv2.COLOR_BGR2RGB)
        
        # Get transparency probability
        transparency_prob = predict_transparency(cnn_model, bottle_crop_rgb)
        
        # Get PET classification if XGBoost model available
        if xgb_model is not None:
            # Prepare features (same as in xgboost_main.py)
            flat_features = bottle_crop_rgb.astype(np.float32).reshape(-1) / 255.0
            features = np.concatenate([flat_features, np.array([transparency_prob])])
            features = features.reshape(1, -1)
            
            # Predict
            pet_prob = xgb_model.predict_proba(features)[0, 1]
            is_pet = pet_prob > 0.5
            label = "PET" if is_pet else "Non-PET"
            
            # Draw bounding box
            color = (0, 255, 0) if is_pet else (255, 0, 0)  # Green for PET, Red for Non-PET
            cv2.rectangle(annotated_img, (x1, y1), (x2, y2), color, 2)
            
            # Add label
            label_text = f"{label} ({pet_prob:.2f})"
            cv2.putText(annotated_img, label_text, (x1, y1 - 10), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
            
            results_list.append(
                f"Bottle {idx+1}: {label} (confidence: {pet_prob:.2%}, "
                f"transparency: {transparency_prob:.2%})"
            )
        else:
            # Only show transparency
            color = (0, 0, 255)
            cv2.rectangle(annotated_img, (x1, y1), (x2, y2), color, 2)
            label_text = f"Trans: {transparency_prob:.2f}"
            cv2.putText(annotated_img, label_text, (x1, y1 - 10), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
            
            results_list.append(
                f"Bottle {idx+1}: Transparency probability: {transparency_prob:.2%}"
            )
    
    results_text = "\n".join(results_list)
    return annotated_img, results_text


def create_gradio_interface():
    """Create and return the Gradio interface."""
    demo = gr.Interface(
        fn=classify_bottle,
        inputs=gr.Image(type="pil", label="Upload Bottle Image"),
        outputs=[
            gr.Image(type="numpy", label="Detection Results"),
            gr.Textbox(label="Classification Results", lines=10)
        ],
        title="🍾 PET vs Non-PET Bottle Classifier",
        description="""
        Upload an image containing bottles to classify them as PET or Non-PET plastic.
        
        **How it works:**
        1. YOLOv5 detects bottles in the image
        2. CNN model predicts transparency probability
        3. XGBoost classifier determines if bottle is PET or Non-PET
        
        **Color coding:**
        - 🟢 Green box = PET bottle
        - 🔴 Red box = Non-PET bottle
        - 🔵 Blue box = Only transparency available
        """,
        allow_flagging="never",
        cache_examples=False,
    )
    return demo


def main():
    parser = argparse.ArgumentParser(description="PET vs Non-PET Bottle Classifier for Hugging Face Spaces")
    parser.add_argument('--cnn_model_path', default='models/cnn_model.pth', help='Path to trained CNN model')
    parser.add_argument('--xgb_model_path', default='models/xgb_model.json', help='Path to trained XGBoost model')
    parser.add_argument('--server_name', default='0.0.0.0', help='Server name for Gradio')
    parser.add_argument('--server_port', type=int, default=7860, help='Server port for Gradio')
    args = parser.parse_args()
    
    # Initialize models
    initialize_models(cnn_model_path=args.cnn_model_path, xgb_model_path=args.xgb_model_path)
    
    # Create and launch Gradio interface
    print("Creating Gradio interface...")
    demo = create_gradio_interface()
    
    print(f"Launching Gradio app on {args.server_name}:{args.server_port}")
    demo.launch(server_name=args.server_name, server_port=args.server_port, share=False)


if __name__ == "__main__":
    main()

