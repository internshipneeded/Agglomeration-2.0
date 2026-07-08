# PET Perplexity ♻️

<div align="center">

<img src="https://img.shields.io/badge/Agglomeration%202.0-Winner-FFD700?style=for-the-badge" alt="Hackathon Winner"/>
<img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
<img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python"/>
<img src="https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white" alt="PyTorch"/>
<img src="https://img.shields.io/badge/OpenCV-5C3EE8?style=for-the-badge&logo=opencv&logoColor=white" alt="OpenCV"/>

<br/>
<b>Team <code>internship_needed</code></b> (AG41)

</div>

PET Perplexity is an intelligent, automated polymer segregation system designed to revolutionize plastic waste management. It uses a cross-platform mobile application powered by advanced Computer Vision and Machine Learning to detect, classify, and analyze PET bottles in real-time.

The system addresses the challenge of segregating plastic waste by identifying key attributes such as bottle presence, size, brand, and material properties.

## 🚀 Key Features

- **Real-time Object Detection** — Instantly detects PET bottles within a video feed or captured image.
- **Bottle Size Classification** — Automatically categorizes bottles into standard sizes (small, medium, large) to aid sorting logistics.
- **Brand Recognition** — Identifies the brand of a bottle using custom-trained deep learning models.
- **Material Analysis** — Uses XGBoost to analyze polymer characteristics for precise segregation.
- **Batch Scanning** — Processes multiple items at once for high-throughput environments.
- **User Dashboard** — A comprehensive mobile interface for tracking scan history and segregation statistics.

## 📱 App Preview

<div align="center">
<table>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/21729aa9-d904-425a-8269-ba6cf8e931ae" width="200" alt="Real-time bottle detection screen"/>
<br/><sub><b>Real-time Detection</b></sub>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/0dd040c0-a29c-40ed-b87c-a5d400d74844" width="200" alt="Bottle size classification screen"/>
<br/><sub><b>Size Classification</b></sub>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/dbd80d00-29c6-411c-8819-07a627ecd70b" width="200" alt="Brand recognition screen"/>
<br/><sub><b>Brand Recognition</b></sub>
</td>
</tr>
<tr>
<td align="center">
<img src="https://github.com/user-attachments/assets/cd59f040-90e2-44d3-b59b-a6dcd4ece6d1" width="200" alt="Material analysis screen"/>
<br/><sub><b>Material Analysis</b></sub>
</td>
<td align="center">
<img src="https://github.com/user-attachments/assets/d9bbeea2-e21a-4f2d-9c65-37504de49547" width="200" alt="Batch scanning screen"/>
<br/><sub><b>Batch Scanning</b></sub>
</td>
<td></td>
</tr>
</table>
</div>

## 🛠️ Tech Stack

### Frontend (Mobile App)
- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **Platforms:** Android, iOS, Web
- **State Management:** Provider / Riverpod (inferred)
- **Architecture:** Feature-first architecture (`lib/features/`)

### Backend & Machine Learning
- **Languages:** Python, Node.js
- **Frameworks:** Flask, FastAPI / Uvicorn, Gradio
- **Computer Vision:**
  - **YOLOv5 / YOLOv8** — robust object detection and bounding box regression.
  - **OpenCV (`cv2`)** — image preprocessing and frame manipulation.
- **Deep Learning Models:**
  - **EfficientNet-B2** — fine-tuned for high-accuracy bottle size classification.
  - **Custom CNNs (PyTorch)** — brand logo detection and classification.
- **Machine Learning:**
  - **XGBoost** — tabular data analysis and material property prediction.

## 🧠 ML Pipeline Architecture

The system runs on a microservices-based architecture where the Flutter app communicates with specialized ML services:

1. **Detection Layer** — The input image passes through a **YOLO** model to detect the presence and location of a bottle.
2. **Dimension Layer** — Cropped regions of interest are sent to the **Dim Predictor** (EfficientNet-B2) to estimate physical dimensions and volume.
3. **Brand Layer** — The **Brand Predictor** analyzes visual features to classify the bottle's brand, aiding source separation.
4. **Analysis Layer** — The **XGBoost** model aggregates these features to make a final segregation decision.

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
│       ├── app.py                  # Flask App for Size Classification
│       └── README.md
│   
├── Agglomeration-2.0-bottlesize/ # Size Classification Model Training
│   └── model.py                # EfficientNet-B2 Implementation
│   
├── Agglomeration-2.0-ML/       # Core ML & XGBoost Logic
│   ├── app.py                  # Gradio/Python App Interface
│   └── xgboost_main.py         # XGBoost Logic
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

| Name | Role |
|---|---|
| Aditya | Mobile App & UI/UX Development |
| Samarth Agarwal | Backend Development |
| Apurva Arya | AI & ML/DL Model Development |
| Arnav Tripathi | AI & ML/DL Model Development |
| Suryansh Kulshreshtha | AI & ML/DL Model Development |
