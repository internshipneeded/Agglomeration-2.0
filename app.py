"""
Bottle Size Classification API - Flask Backend
Deploy on Render.com
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import torch
import timm
import numpy as np
from PIL import Image
import io
import base64
import json
import os

app = Flask(__name__)
CORS(app)  # Enable CORS for frontend access

# ==================== CONFIGURATION ====================
MODEL_PATH = "best_model.pth"
IMAGE_SIZE = 260
device = torch.device("cpu")  # Render uses CPU

# ==================== LOAD MODEL ====================
print("=" * 60)
print("LOADING MODEL...")
print("=" * 60)

# Load checkpoint
checkpoint = torch.load(MODEL_PATH, map_location=device, weights_only=False)

# Get class names from checkpoint
if 'class_names' in checkpoint:
    CLASS_NAMES = checkpoint['class_names']
elif 'class_to_idx' in checkpoint:
    CLASS_NAMES = list(checkpoint['class_to_idx'].keys())
else:
    # Fallback - update these with your actual classes!
    CLASS_NAMES = ["1L", "500ml", "250ml", "2L"]

print(f"Classes: {CLASS_NAMES}")

# Create model
model = timm.create_model(
    "efficientnet_b2",
    pretrained=False,
    num_classes=len(CLASS_NAMES)
)

# Load weights
if 'model_state_dict' in checkpoint:
    model.load_state_dict(checkpoint['model_state_dict'])
    if 'test_acc' in checkpoint:
        print(f"Model Accuracy: {checkpoint['test_acc']:.2%}")
else:
    model.load_state_dict(checkpoint)

model.to(device)
model.eval()

print("✅ Model loaded successfully!")
print("=" * 60)

# ==================== HELPER FUNCTIONS ====================
def preprocess_image(image):
    """Preprocess image for model input"""
    # Convert to RGB
    if image.mode != 'RGB':
        image = image.convert('RGB')
    
    # Resize
    image = image.resize((IMAGE_SIZE, IMAGE_SIZE), Image.Resampling.BILINEAR)
    
    # Normalize (ImageNet stats)
    img_array = np.array(image).astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406])
    std = np.array([0.229, 0.224, 0.225])
    img_array = (img_array - mean) / std
    
    # To tensor
    img_tensor = torch.from_numpy(img_array).permute(2, 0, 1).unsqueeze(0)
    
    return img_tensor

def predict_bottle_size(image):
    """Run prediction on image"""
    try:
        # Preprocess
        img_tensor = preprocess_image(image)
        img_tensor = img_tensor.to(device)
        
        # Predict
        with torch.no_grad():
            outputs = model(img_tensor)
            probabilities = torch.nn.functional.softmax(outputs, dim=1)
        
        # Get results
        probs = probabilities[0].cpu().numpy()
        results = {CLASS_NAMES[i]: float(probs[i]) for i in range(len(CLASS_NAMES))}
        
        # Sort by probability
        results = dict(sorted(results.items(), key=lambda x: x[1], reverse=True))
        
        return results
        
    except Exception as e:
        raise Exception(f"Prediction error: {str(e)}")

# ==================== API ROUTES ====================

@app.route('/', methods=['GET'])
def home():
    """Health check and API info"""
    return jsonify({
        "status": "online",
        "model": "EfficientNet-B2",
        "classes": CLASS_NAMES,
        "num_classes": len(CLASS_NAMES),
        "endpoints": {
            "/predict": "POST - Upload image for classification",
            "/predict_base64": "POST - Send base64 encoded image",
            "/health": "GET - Health check"
        }
    })

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "model_loaded": model is not None,
        "device": str(device)
    })

@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict bottle size from uploaded image
    
    Request:
        - Form data with 'image' file
    
    Response:
        {
            "success": true,
            "predictions": {
                "1L": 0.85,
                "500ml": 0.10,
                ...
            },
            "top_prediction": "1L",
            "confidence": 0.85
        }
    """
    try:
        # Check if image is in request
        if 'image' not in request.files:
            return jsonify({
                "success": False,
                "error": "No image file provided"
            }), 400
        
        file = request.files['image']
        
        # Check if file is empty
        if file.filename == '':
            return jsonify({
                "success": False,
                "error": "Empty filename"
            }), 400
        
        # Read image
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes))
        
        # Predict
        predictions = predict_bottle_size(image)
        
        # Get top prediction
        top_class = list(predictions.keys())[0]
        top_confidence = predictions[top_class]
        
        return jsonify({
            "success": True,
            "predictions": predictions,
            "top_prediction": top_class,
            "confidence": top_confidence
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/predict_base64', methods=['POST'])
def predict_base64():
    """
    Predict bottle size from base64 encoded image
    
    Request JSON:
        {
            "image": "base64_encoded_string"
        }
    
    Response:
        {
            "success": true,
            "predictions": {...},
            "top_prediction": "1L",
            "confidence": 0.85
        }
    """
    try:
        # Get JSON data
        data = request.get_json()
        
        if not data or 'image' not in data:
            return jsonify({
                "success": False,
                "error": "No image data provided"
            }), 400
        
        # Decode base64 image
        image_data = data['image']
        
        # Remove data URL prefix if present
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        image_bytes = base64.b64decode(image_data)
        image = Image.open(io.BytesIO(image_bytes))
        
        # Predict
        predictions = predict_bottle_size(image)
        
        # Get top prediction
        top_class = list(predictions.keys())[0]
        top_confidence = predictions[top_class]
        
        return jsonify({
            "success": True,
            "predictions": predictions,
            "top_prediction": top_class,
            "confidence": top_confidence
        })
        
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/classes', methods=['GET'])
def get_classes():
    """Get list of available classes"""
    return jsonify({
        "classes": CLASS_NAMES,
        "num_classes": len(CLASS_NAMES)
    })

# ==================== ERROR HANDLERS ====================

@app.errorhandler(404)
def not_found(error):
    return jsonify({
        "success": False,
        "error": "Endpoint not found"
    }), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({
        "success": False,
        "error": "Internal server error"
    }), 500

# ==================== RUN APP ====================

if __name__ == '__main__':
    # Get port from environment variable (Render provides this)
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)