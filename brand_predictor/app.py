import gradio as gr
from pipeline import BrandAttentionPipeline
from PIL import Image
import os

# --- DEPENDENCIES ---
YOLO_PATH = "Logo_Detection_Yolov8.pt"
SALIENCY_PATH = "ECT_SAL.pth"
CLASSIFIER_PATH = "brand_attention_efficientnet_twostream.pth"

CLASSES = [
    'Aquafina', 'Bisleri', 'Coca-Cola', 'Fanta', 
    'Pepsi', 'Sprite', 'Tropicana', 'Unbranded'
]

# Initialize Pipeline (Global)
try:
    pipeline = BrandAttentionPipeline(
        yolo_path=YOLO_PATH,
        saliency_path=SALIENCY_PATH,
        classifier_path=CLASSIFIER_PATH,
        classes=CLASSES
    )
    print("Pipeline initialized successfully.")
except Exception as e:
    print(f"Error initializing pipeline: {e}")
    pipeline = None

def infer(image):
    if pipeline is None:
        return "Error: Deployment not configured correctly (missing weights)."
    
    if image is None:
        return "Please upload an image."
    
    brands = pipeline.predict(image)
    if not brands:
        return "No brands detected."
    
    return ", ".join(brands)

# --- GRADIO APP ---
demo = gr.Interface(
    fn=infer,
    inputs=gr.Image(type="pil", label="Input Image"),
    outputs=gr.Textbox(label="Detected Brands"),
    title="Brand Attention & Detection",
    description="Detects brands in images using a Two-Stream network (YOLOv8 + Saliency Map + EfficientNet). Handles unbranded images via saliency analysis.",
    examples=["test.jpg"] if os.path.exists("test.jpg") else None
)

if __name__ == "__main__":
    demo.launch()
