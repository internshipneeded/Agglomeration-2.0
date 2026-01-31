# PET Perplexity ♻️

> **Winner of the Agglomeration 2.0 Hackathon🏆** (Team internship_needed - AG41)

PET Perplexity is an intelligent, automated polymer segregation system designed to revolutionize plastic waste management. It utilizes a cross-platform mobile application powered by advanced Computer Vision and Machine Learning to detect, classify, and analyze PET bottles in real-time.

The system addresses the challenge of segregating plastic waste by identifying key attributes such as bottle presence, size, brand, and material properties.

## 🚀 Key Features

* **Real-time Object Detection:** Instantly detects PET bottles within a video feed or captured image.
* **Bottle Size Classification:** Automatically categorizes bottles into standard sizes (e.g., small, medium, large) to aid in sorting logistics.
* **Brand Recognition:** Identifies the brand of the bottle using custom-trained deep learning models.
* **Material Analysis:** Utilizes XGBoost algorithms to analyze polymer characteristics for precise segregation.
* **Batch Scanning:** Capability to process multiple items in a batch for high-throughput environments.
* **User Dashboard:** A comprehensive mobile interface for tracking scan history and segregation statistics.

## 🛠️ Tech Stack

### Frontend (Mobile App)
* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Platforms:** Android, iOS, Web
* **State Management:** Provider / Riverpod (Inferred)
* **Architecture:** Feature-first architecture (`lib/features/`)

### Backend & Machine Learning
* **Languages:** Python, Node.js
* **Frameworks:** Flask, FastAPI / Uvicorn, Gradio
* **Computer Vision:**
    * **YOLOv5 / YOLOv8:** For robust object detection and bounding box regression.
    * **OpenCV (`cv2`):** For image preprocessing and frame manipulation.
* **Deep Learning Models:**
    * **EfficientNet-B2:** Finetuned for high-accuracy bottle size classification.
    * **Custom CNNs (PyTorch):** For brand logo detection and classification.
* **Machine Learning:**
    * **XGBoost:** For tabular data analysis and material property prediction.

## 🧠 ML Pipeline Architecture

The system operates on a microservices-based architecture where the Flutter app communicates with specialized ML services:

1.  **Detection Layer:** The input image is passed through a **YOLO** model to detect the presence and location of a bottle.
2.  **Dimension Layer:** Cropped regions of interest are sent to the **Dim Predictor** (EfficientNet-B2) to estimate physical dimensions and volume.
3.  **Brand Layer:** The **Brand Predictor** analyzes visual features to classify the bottle's brand, aiding in source separation.
4.  **Analysis Layer:** The **XGBoost** model aggregates these features to make a final segregation decision.

## 📂 Project Structure

```bash
agglomeration-2.0/
├── internshipneeded/
│   ├── agglomeration-2.0-33bf.../  # Main Flutter Application
│   │   ├── lib/
│   │   │   ├── features/           # UI Screens (Home, Scan, History)
│   │   │   ├── services/           # API Integration (Auth, ScanService)
│   │   │   └── main.dart           # App Entry Point
│   │   └── pubspec.yaml            # Dart Dependencies
│   │
│   ├── brand_predictor/            # Brand Recognition Service
│   │   ├── app.py                  # API Entry Point
│   │   ├── pipeline.py             # Inference Pipeline
│   │   └── model_arch.py           # PyTorch Model Architecture
│   │
│   ├── dim_predictor/              # Dimension/Size Service
│   │   ├── app.py                  # Flask App for Size Classification
│   │   └── README.md
│   │
│   ├── Agglomeration-2.0-bottlesize/ # Size Classification Model Training
│   │   └── model.py                # EfficientNet-B2 Implementation
│   │
│   └── Agglomeration-2.0-ML/       # Core ML & XGBoost Logic
│       ├── app.py                  # Gradio/Python App Interface
│       └── xgboost_main.py         # XGBoost Logic
```
---

## 🤝 Contributing

Contributions are always welcome!

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes.
4. Open a Pull Request.

---


## 👥 Development Team

* **Aditya** (Mobile App & UI/UX Development)
* **Samarth Agarwal** (Backend Development)
* **Apurva Arya**, **Arnav Tripathi**, **Suryansh Kulshreshtha** (AI & ML/DL Model Development)

