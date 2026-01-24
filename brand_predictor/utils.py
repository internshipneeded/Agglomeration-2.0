import cv2
import numpy as np
from torchvision import transforms

def get_text_map_simple(image):
    if isinstance(image, str): image = cv2.imread(image)
    if image is None: return np.zeros((256, 256, 3)) # robustness
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
    gradient = cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, kernel)
    _, binary = cv2.threshold(gradient, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)
    text_map = cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR)
    return text_map

def get_transforms(img_size):
    return transforms.Compose([
            transforms.Resize((img_size, img_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
        ])
