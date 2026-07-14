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

## Branches & Deployments 
 
This repo is split across branches by service. `main` holds the mobile
app and two lightweight predictor services; the rest of the pipeline and
model training code live in separate branches.
 
| Branch | Contents | Live deployment |
|---|---|---|
| `main` | Flutter app (Android/iOS) + `brand_predictor` + `dim_predictor` | NOT CURRENTLY DEPLOYED |
| `ML` | Integrated YOLOv5 + CNN + XGBoost pipeline | https://huggingface.co/spaces/SudoKuder/agglo |
| `bottlesize` | EfficientNet-B2 bottle-size classifier training + Flask API | NOT CURRENTLY DEPLOYED |
| `backend` | Node/Express REST API (auth, scans, MongoDB, Cloudinary) | https://pet-perplexity.onrender.com |
 
To run any service locally: `git checkout <branch>`, then follow that
branch's own README/requirements.txt.
 
---
 
## Project Structure 
 
```
Agglomeration-2.0/            (main branch)
├── lib/                      # Flutter app source
├── android/ ios/ web/        # Platform targets
├── brand_predictor/          # Logo detection + brand classification (Gradio, HF Space)
│   ├── app.py
│   ├── pipeline.py           # Saliency transformer + two-stream EfficientNet-B2
│   ├── model_arch.py
│   └── utils.py
├── dim_predictor/             # Dimension estimation (Gradio, HF Space)
│   ├── app.py                # YOLOv8-seg + ArUco/cap-reference/camera-geometry calibration
│   └── README.md
├── Problem Statement.pdf
└── pubspec.yaml
 
Other branches:
├── ML/                        # Integrated YOLOv5 + CNN + XGBoost inference pipeline
├── bottlesize/                 # EfficientNet-B2 training + standalone Flask API
└── backend/                    # Node/Express API + MongoDB + Cloudinary
```
 
---
 
## ML Pipeline Architecture — Dimension Layer 
 
Current text says the Dimension Layer uses EfficientNet-B2. What's
actually deployed in `dim_predictor` is:
 
**Dimension Layer:** YOLOv8 segmentation isolates the bottle from the
background, then physical height/diameter are computed from the mask
using a three-way scale-calibration fallback: an ArUco marker if one is
visible in frame, otherwise a known bottle-cap diameter as a size
reference, otherwise camera geometry/distance. (EfficientNet-B2 was an
earlier size-*classification* approach, now developed separately in the
`bottlesize` branch as discrete volume classes — 33cl/50cl/100cl/150cl/200cl
— rather than continuous measurements.)




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
