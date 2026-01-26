import os
import torch
import cv2
import numpy as np
from PIL import Image
from ultralytics import YOLO
from model_arch import ECT_SAL, TwoStreamEfficientNet
from utils import get_text_map_simple, get_transforms

class BrandAttentionPipeline:
    def __init__(self, yolo_path, saliency_path, classifier_path, classes, img_size=260, device=None):
        self.device = device if device else torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.img_size = img_size
        self.classes = classes

        print("Loading YOLO...")
        self.yolo = YOLO(yolo_path)

        print("Loading Saliency Model...")
        self.saliency_model = ECT_SAL()
        state_dict_sal = torch.load(saliency_path, map_location=self.device)
        self.saliency_model.load_state_dict(state_dict_sal, strict=False)
        self.saliency_model.to(self.device).eval()

        print("Loading Classifier...")
        self.classifier = TwoStreamEfficientNet(num_classes=len(classes))
        state_dict_cls = torch.load(classifier_path, map_location=self.device)
        self.classifier.load_state_dict(state_dict_cls)
        self.classifier.to(self.device).eval()

        self.transform = get_transforms(img_size)

    def run_saliency(self, original_img):
        # ROI: 256x256 for ECT_SAL
        img_resized = cv2.resize(original_img, (256, 256))
        tmap = get_text_map_simple(img_resized)
        
        img = np.array(img_resized, dtype=np.float32) / 255.
        tmap = np.array(tmap, dtype=np.float32) / 255.
        
        img = np.transpose(img, (2, 0, 1))
        tmap = np.transpose(tmap, (2, 0, 1))
        
        img_t = torch.tensor(img).unsqueeze(0).float().to(self.device)
        tmap_t = torch.tensor(tmap).unsqueeze(0).float().to(self.device)
        
        with torch.no_grad():
            pred_saliency = self.saliency_model(img_t, tmap_t)
            
        pred_saliency = torch.sigmoid(pred_saliency).squeeze().cpu().numpy()
        
        # Resize saliency back to original image size
        h, w = original_img.shape[:2]
        pred_saliency = cv2.resize(pred_saliency, (w, h))
        return pred_saliency

    def predict(self, pil_image):
        cv_image = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
        
        # 1. Pipeline: YOLO Detection
        results = self.yolo(cv_image, verbose=False)
        boxes = results[0].boxes
        
        # 2. Pipeline: Saliency Map Generation
        saliency_map = self.run_saliency(cv_image)
        saliency_map_3c = np.repeat(saliency_map[:, :, np.newaxis], 3, axis=2)
        filtered_np = (np.array(pil_image) / 255.0) * saliency_map_3c
        filtered_image = Image.fromarray((filtered_np * 255).astype(np.uint8))

        saliency_input = self.transform(filtered_image).unsqueeze(0).to(self.device)

        predictions = []

        if len(boxes) > 0:
            # Handle each detection
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                yolo_crop = pil_image.crop((x1, y1, x2, y2))
                yolo_input = self.transform(yolo_crop).unsqueeze(0).to(self.device)
                
                # Inference
                with torch.no_grad():
                    # We repeat saliency input for each crop to match batch size 1
                    output = self.classifier(yolo_input, saliency_input)
                    _, predicted_idx = torch.max(output.data, 1)
                    predicted_class = self.classes[predicted_idx.item()]
                    predictions.append(predicted_class)
        else:
            # No YOLO boxes -> Fallback to Black Image
            yolo_crop = Image.new('RGB', (self.img_size, self.img_size), (0, 0, 0))
            yolo_input = self.transform(yolo_crop).unsqueeze(0).to(self.device)
            
            with torch.no_grad():
                output = self.classifier(yolo_input, saliency_input)
                _, predicted_idx = torch.max(output.data, 1)
                predicted_class = self.classes[predicted_idx.item()]
                predictions.append(predicted_class)

        # Return unique brands found
        return list(set(predictions))

