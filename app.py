"""
Bottle Size Classification API - Flask Backend
Deploy on Render.com
"""

import os
import io
import base64
import json
import torch
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image
from model import BottleNet  # Import your custom class from model.py

# Initialize Flask App
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# ==================== CONFIGURATION ====================
MODEL_PATH = "best_model.pth"
IMAGE_SIZE = 224  # Standard for EfficientNet (usually 224 or 260 depending on training)
DEVICE = torch.device("cpu") # Force CPU for Render Free Tier to avoid slug size issues

# ==================== LOAD MODEL ====================
print("=" * 60)
print("LOADING MODEL...")

try:
    # 1. Initialize the architecture
    # We use your custom class to ensure layers match exactly
    model = BottleNet() 
    
    # 2. Load the checkpoint
    checkpoint = torch.load(MODEL_PATH, map_location=DEVICE)
    
    # 3. Handle different save formats (State Dict vs Full Checkpoint)
    if isinstance(checkpoint, dict) and 'model_state_dict' in checkpoint:
        print("-> Loading from checkpoint dictionary...")
        model.load_state_dict(checkpoint['model_state_dict'])
        
        # Try to extract class names if saved in checkpoint
        if 'class_names' in checkpoint:
            CLASS_NAMES = checkpoint['class_names']
        elif 'class_to_idx' in checkpoint:
            CLASS_NAMES = list(checkpoint['class_to_idx'].keys())
        else:
            CLASS_NAMES = ['Large', 'Medium', 'Small'] # Default Fallback
            
    else:
        print("-> Loading standard state dict...")
        model.load_state_dict(checkpoint)
        CLASS_NAMES = ['Large', 'Medium', 'Small'] # Default Fallback

    # 4. Set to Evaluation Mode
    model.to(DEVICE)
    model.eval()
    print("✅ Model loaded successfully!")
    print(f"✅ Detected Classes: {CLASS_NAMES}")

except Exception as e:
    print(f"❌ Error loading model: {e}")
    print("Make sure 'best_model.pth' and 'model.py' are in the same folder.")
    # Initialize a dummy model so the app doesn't crash immediately on boot, 
    # but requests will fail.
    model = None
    CLASS_NAMES = []

print("=" * 60)

# ==================== HELPER FUNCTIONS ====================
def preprocess_image(image):
    """Preprocess image for model input"""
    # 1. Convert to RGB (handles PNG transparency/Grayscale)
    if image.mode != 'RGB':
        image = image.convert('RGB')
    
    # 2. Resize
    image = image.resize((IMAGE_SIZE, IMAGE_SIZE), Image.Resampling.BILINEAR)
    
    # 3. Normalize (Standard ImageNet stats)
    img_array = np.array(image).astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406])
    std = np.array([0.229, 0.224, 0.225])
    img_array = (img_array - mean) / std
    
    # 4. To tensor (Channels First: HWC -> CHW)
    img_tensor = torch.from_numpy(img_array).permute(2, 0, 1).unsqueeze(0)
    
    return img_tensor

def predict_logic(image):
    """Core prediction logic"""
    if model is None:
        raise Exception("Model not loaded.")

    img_tensor = preprocess_image(image).to(DEVICE)
    
    with torch.no_grad():
        outputs = model(img_tensor)
        probabilities = torch.nn.functional.softmax(outputs, dim=1)
    
    # Map probabilities to class names
    probs = probabilities[0].cpu().numpy()
    results = {CLASS_NAMES[i]: float(probs[i]) for i in range(len(CLASS_NAMES))}
    
    # Sort by confidence
    sorted_results = dict(sorted(results.items(), key=lambda x: x[1], reverse=True))
    return sorted_results

# ==================== API ROUTES ====================

@app.route('/', methods=['GET'])
def home():
    """API Info Page"""
    return jsonify({
        "status": "online",
        "model": "BottleNet (EfficientNet-B2)",
        "classes": CLASS_NAMES,
        "device": str(DEVICE)
    })

@app.route('/health', methods=['GET'])
def health():
    """Health Check"""
    return jsonify({
        "status": "healthy" if model else "degraded",
        "model_loaded": model is not None
    })

@app.route('/predict', methods=['POST'])
def predict():
    """Handle File Uploads (multipart/form-data)"""
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file part'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No selected file'}), 400

        # Read and Predict
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes))
        
        predictions = predict_logic(image)
        top_class = list(predictions.keys())[0]
        
        return jsonify({
            'success': True,
            'bottle_size': top_class, # Kept for backward compatibility
            'top_prediction': top_class,
            'confidence': predictions[top_class],
            'all_predictions': predictions
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/predict_base64', methods=['POST'])
def predict_base64():
    """Handle Base64 JSON requests"""
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({'error': 'No image provided'}), 400

        image_data = data['image']
        
        # Strip header if present (e.g. "data:image/jpeg;base64,...")
        if ',' in image_data:
            image_data = image_data.split(',')[1]

        image_bytes = base64.b64decode(image_data)
        image = Image.open(io.BytesIO(image_bytes))

        predictions = predict_logic(image)
        top_class = list(predictions.keys())[0]

        return jsonify({
            'success': True,
            'bottle_size': top_class,
            'top_prediction': top_class,
            'confidence': predictions[top_class],
            'all_predictions': predictions
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ==================== MAIN ====================
if __name__ == '__main__':
    # Use PORT env variable for Render, default to 5000 locally
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
