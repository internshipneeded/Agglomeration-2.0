import os
import warnings
from io import BytesIO

import cv2
import numpy as np
import torch
import xgboost as xgb
from flask import Flask, request, jsonify
from PIL import Image
from cnn_model import CNNModel

warnings.filterwarnings('ignore', category=FutureWarning)

app = Flask(__name__)

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

# Global models
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
    predict_transparency(cnn_model, bottle_image_rgb):
    """Return transparency probability from CNN; if model missing, return 0.0.
    Expects bottle_image_rgb as HxWx3 RGB numpy array sized 32x32.
    """
    if cnn_model is None:
        return 0.0
    with torch.no_grad():
        tensor = torch.from_numpy(bottle_image_rgb).permute(2, 0, 1).float() / 255.0
        tensor = tensor.unsqueeze(0).to(device)
        prob = cnn_model(tensor).item()
        return float(prob)rain_idx, val_idx = idx[:split], idx[split:]
    return X[train_idx], X[val_idx], y[train_idx], y[val_idx]


def evaluate(preds_prob, labels):
    preds = (preds_prob > 0.5).astype(np.int64)
    total = len(labels)
    correct = (preds == labels).sum()
    tp = ((preds == 1) & (labels == 1)).sum()
    fp = ((preds == 1) & (labels == 0)).sum()
    tn = ((preds == 0) & (labels == 0)).sum()
    fn = ((preds == 0) & (labels == 1)).sum()
    eps = 1e-8
    accuracy = correct / total
    precision = tp / (tp + fp + eps)
    recall = tp / (tp + fn + eps)
    f1 = 2 * precision * recall / (precision + recall + eps)
    return {
        'accuracy': accuracy,
        'precision': precision,
        'recall': recall,
        'f1': f1,
        'tp': int(tp),
        'fp': int(fp),
        'tn': int(tn),
        'fn': int(fn),
        'total': int(total),
    }


def main():
    parser = argparse.ArgumentParser(description="Train and evaluate XGBoost on YOLO-extracted bottle crops")
    parser.add_argument('--images_dir', default='./drinking-waste-DatasetNinja/ds/img/', help='Directory with .jpg images')
    parser.add_argument('--model_out', default='models/xgb_model.json', help='Where to save the XGBoost model')
    parser.add_argument('--val_ratio', type=float, default=0.2, help='Validation split ratio')
    parser.add_argument('--max_depth', type=int, default=5)
    parser.add_argument('--n_estimators', type=int, default=300)
    parser.add_argument('--learning_rate', type=float, default=0.05)
    parser.add_argument('--cnn_model_path', default='models/cnn_model.pth', help='Path to trained CNN model for transparency feature')
    args = parser.parse_args()

    # Load CNN model for transparency probability feature
    global cnn_model
    cnn_model = CNNModel().to(device)
    if os.path.exists(args.cnn_model_path):
        cnn_model.load_state_dict(torch.load(args.cnn_model_path, map_location=device))
        cnn_model.eval()
        print(f"Loaded CNN model from {args.cnn_model_path} (device: {device})")
    else:
        print(f"Warning: CNN model not found at {args.cnn_model_path}. Transparency feature will be zeros.")
        cnn_model = None

    X, y = build_dataset(args.images_dir)
    X_train, X_val, y_train, y_val = train_val_split(X, y, val_ratio=args.val_ratio)
    
    if X_train is None or len(y_train) == 0:
        print("No samples available for training.")
        return

    model = xgb.XGBClassifier(
        max_depth=args.max_depth,
        n_estimators=args.n_estimators,
        learning_rate=args.learning_rate,
        subsample=0.8,
        colsample_bytree=0.8,
        objective='binary:logistic',
        eval_metric='logloss',
        tree_method='hist',
    )

    print("Training XGBoost...")
    model.fit(X_train, y_train)

    print("Evaluating...")
    preds_prob = model.predict_proba(X_val)[:, 1]
    metrics = evaluate(preds_prob, y_val)

    os.makedirs(os.path.dirname(args.model_out), exist_ok=True)
    model.save_model(args.model_out)

    print("\nResults")
    print("-------")
    print(f"Accuracy:  {metrics['accuracy']*100:.2f}%")
    print(f"Precision: {metrics['precision']*100:.2f}%")
    print(f"Recall:    {metrics['recall']*100:.2f}%")
    print(f"F1 Score:  {metrics['f1']*100:.2f}%")
@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'models_loaded': {
            'yolo': yolo_model is not None,
            'cnn': cnn_model is not None,
            'xgboost': xgb_model is not None
        }
    })


@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict if bottles in uploaded image are PET or Non-PET.
    
    # Initialize models on startup
    initialize_models(
        cnn_model_path=os.getenv('CNN_MODEL_PATH', 'models/cnn_model.pth'),
        xgb_model_path=os.getenv('XGB_MODEL_PATH', 'models/xgb_model.json')
    )
    
    # Run Flask app
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=Falsets:
        - 'image' file in multipart/form-data
        
    Returns:
        JSON with detection results
    """
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'Empty filename'}), 400
    
    try:
        # Read image
        image_bytes = file.read()
        image = Image.open(BytesIO(image_bytes))
        image_np = np.array(image)
        
        # Convert RGB to BGR for OpenCV and YOLO
        if len(image_np.shape) == 2:  # Grayscale
            img_bgr = cv2.cvtColor(image_np, cv2.COLOR_GRAY2BGR)
        elif image_np.shape[2] == 4:  # RGBA
            img_bgr = cv2.cvtColor(image_np, cv2.COLOR_RGBA2BGR)
        else:  # RGB
            img_bgr = cv2.cvtColor(image_np, cv2.COLOR_RGB2BGR)
        
        # Detect bottles
        detections = detect_bottles(img_bgr)
        
        if len(detections) == 0:
            return jsonify({
                'success': True,
                'message': 'No bottles detected in the image',
                'bottles': []
            })
        
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
                
                results.append({
                    'bottle_id': idx + 1,
                    'bbox': {
                        'x1': x1,
                        'y1': y1,
                        'x2': x2,
                        'y2': y2
                    },
                    'confidence': float(conf),
                    'classification': 'PET' if is_pet else 'Non-PET',
                    'pet_probability': float(pet_prob),
                    'transparency_probability': float(transparency_prob)
                })
            else:
                results.append({
                    'bottle_id': idx + 1,
                    'bbox': {
                        'x1': x1,
                        'y1': y1,
                        'x2': x2,
                        'y2': y2
                    },
                    'confidence': float(conf),
                    'transparency_probability': float(transparency_prob),
                    'classification': 'unavailable'
                })
        
        return jsonify({
            'success': True,
            'message': f'Detected {len(results)} bottle(s)',
            'bottles': results
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500