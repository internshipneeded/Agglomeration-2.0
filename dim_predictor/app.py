import os
import cv2
import numpy as np
from typing import Optional, Tuple
from PIL import Image, ImageDraw, ImageFont

import gradio as gr

# ------------------------- YOLO -------------------------

try:
    from ultralytics import YOLO
except Exception:
    YOLO = None

# ------------------------- Configuration -------------------------

MODEL_NAME = os.environ.get("YOLO_MODEL", "yolov8n-seg")
CONFIDENCE = 0.35
IMG_SIZE = 640

# ------------------------- Utilities -------------------------

def load_model():
    if YOLO is None:
        raise RuntimeError("ultralytics not installed")
    return YOLO(MODEL_NAME)


def largest_mask_from_results(results):
    res = results[0]
    if res.masks is None:
        raise RuntimeError("No segmentation masks detected")

    masks = res.masks.data.cpu().numpy().astype(np.uint8)
    areas = masks.reshape(masks.shape[0], -1).sum(axis=1)
    idx = int(np.argmax(areas))

    mask = masks[idx].astype(bool)
    score = float(res.boxes.conf[idx].cpu().numpy())

    return mask, {"score": score}


def pixel_height_and_diameter_from_mask(mask: np.ndarray, crushed_mode: bool):
    ys, xs = np.where(mask)
    if ys.size == 0:
        return 0, 0

    height_px = int(ys.max() - ys.min())

    widths = []
    for y in range(ys.min(), ys.max() + 1):
        row = xs[ys == y]
        if row.size >= 2:
            widths.append(row.max() - row.min())

    diameter_px = int(
        np.median(widths) if (crushed_mode and widths) else (max(widths) if widths else 0)
    )

    return height_px, diameter_px


def detect_aruco_marker(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    aruco_dict = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_50)
    params = cv2.aruco.DetectorParameters()
    detector = cv2.aruco.ArucoDetector(aruco_dict, params)

    corners, ids, _ = detector.detectMarkers(gray)
    if ids is None:
        return None

    poly = corners[0].reshape(-1, 2)
    dists = [np.linalg.norm(poly[i] - poly[(i + 1) % 4]) for i in range(4)]
    return float(np.mean(dists))


def detect_cap_diameter_px(image, mask):
    ys, xs = np.where(mask)
    if ys.size == 0:
        return None

    crop = image[ys.min():ys.max()+1, xs.min():xs.max()+1]
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (7, 7), 0)

    circles = cv2.HoughCircles(
        gray,
        cv2.HOUGH_GRADIENT,
        dp=1.2,
        minDist=20,
        param1=100,
        param2=30,
        minRadius=5,
        maxRadius=200,
    )

    if circles is None:
        return None

    _, _, r = max(circles[0], key=lambda c: c[2])
    return 2 * r


def visualize(image, mask, h_cm, d_cm, scale, method):
    pil = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(pil)

    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts:
        pts = [(int(p[0][0]), int(p[0][1])) for p in c]
        if len(pts) > 2:
            draw.line(pts + [pts[0]], width=3)

    txt = f"H:{h_cm:.2f}cm  D:{d_cm:.2f}cm  ({method})"
    draw.text((10, 10), txt, fill=(255, 255, 0))

    return cv2.cvtColor(np.array(pil), cv2.COLOR_RGB2BGR)


# ------------------------- CORE INFERENCE -------------------------

def compute_measurements(
    image,
    use_aruco,
    aruco_size,
    cap_size,
    fx,
    fy,
    dist,
    crushed,
    model,
):
    results = model.predict(
        image,
        imgsz=IMG_SIZE,
        conf=CONFIDENCE,
        device="cpu",
        verbose=False,
    )

    mask, meta = largest_mask_from_results(results)
    h_px, d_px = pixel_height_and_diameter_from_mask(mask, crushed)

    scale = None
    method = "pixel"

    if use_aruco and aruco_size:
        px = detect_aruco_marker(image)
        if px:
            scale = aruco_size / px
            method = "aruco"

    if scale is None and cap_size:
        cap_px = detect_cap_diameter_px(image, mask)
        if cap_px:
            scale = cap_size / cap_px
            method = "cap"

    if scale is None and fy and dist:
        scale = dist / fy
        method = "camera"

    h_cm = h_px * scale if scale else float(h_px)
    d_cm = d_px * scale if scale else float(d_px)

    vis = visualize(image, mask.astype(np.uint8) * 255, h_cm, d_cm, scale, method)

    return vis, {
        "height_cm": h_cm,
        "diameter_cm": d_cm,
        "height_px": h_px,
        "diameter_px": d_px,
        "scale_cm_per_px": scale,
        "method": method,
        "score": meta["score"],
    }


# ------------------------- GRADIO APP -------------------------

def run_app():
    model = load_model()

    def process_image(
        image,
        aruco_size_val,
        use_aruco_val,
        cap_size_val,
        crushed_val,
        fx_val,
        fy_val,
        dist_val,
    ):
        vis, stats = compute_measurements(
            image=image,
            use_aruco=use_aruco_val,
            aruco_size=aruco_size_val,
            cap_size=cap_size_val,
            fx=fx_val,
            fy=fy_val,
            dist=dist_val,
            crushed=crushed_val,
            model=model,
        )
        
        return stats, vis

    with gr.Blocks() as demo:
        gr.Markdown("# Bottle Height & Diameter Measurement")

        with gr.Row():
            img = gr.Image(type="numpy", label="Upload image")

            with gr.Column():
                aruco_size = gr.Number(label="ArUco size (cm)")
                use_aruco = gr.Checkbox(value=True, label="Use ArUco")
                cap_size = gr.Number(label="Cap diameter (cm)")
                crushed = gr.Checkbox(label="Crushed bottle")
                fx = gr.Number(label="Camera fx (px)")
                fy = gr.Number(label="Camera fy (px)")
                dist = gr.Number(label="Camera distance (cm)")
                btn = gr.Button("Run")

        out_img = gr.Image(label="Result")
        out_json = gr.JSON(label="Measurements")

        btn.click(
            process_image,
            inputs=[
                img,
                aruco_size,
                use_aruco,
                cap_size,
                crushed,
                fx,
                fy,
                dist,
            ],
            outputs=[out_json, out_img],
            api_name="inference",
        )

    demo.launch()


if __name__ == "__main__":
    run_app()
