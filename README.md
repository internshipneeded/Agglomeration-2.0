---
pipeline_tag: image-classification
tags:
  - yolov5
  - xgboost
  - waste-sorting
  - pet-bottles
  - transparency
license: mit
library_name: pytorch
---

# PET vs Non-PET Bottle Classifier

End-to-end pipeline to detect bottles with YOLOv5, estimate transparency with a lightweight CNN, and classify PET vs non-PET bottles with an XGBoost head. Ready to push to the Hugging Face Hub as a model repository.

## Files
- `cnn_model.py` – small CNN that predicts bottle transparency probability.
- `main.py` – trains the CNN on YOLO-cropped bottles.
- `testMain.py` – evaluates the CNN on a directory of images.
- `xgboost_main.py` – builds features from YOLO crops + CNN transparency and trains the XGBoost classifier.
- `inference.py` – single/batch inference script for YOLO + CNN + XGBoost.
- `models/cnn_model.pth` – trained CNN weights.
- `models/xgb_model.json` – trained XGBoost classifier.
- `requirements.txt` – minimal Python dependencies.

## Quickstart (local)
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python inference.py --source path/to/image_or_folder \
  --cnn-model models/cnn_model.pth \
  --xgb-model models/xgb_model.json
```
Output lists detected bottles with YOLO confidence, transparency prob, and PET prob. If the XGBoost model is missing, the script still outputs transparency probability.

## Training
- Train CNN: `python main.py --images_dir ./drinking-waste-DatasetNinja/ds/img/`
- Evaluate CNN: `python testMain.py --images_dir ./drinking-waste-DatasetNinja/ds/img/ --model_path models/cnn_model.pth`
- Train XGBoost: `python xgboost_main.py --images_dir ./drinking-waste-DatasetNinja/ds/img/ --cnn_model_path models/cnn_model.pth`

The YOLOv5 backbone is pulled via `torch.hub` (weights cached automatically). Models save to `models/` by default.

## Hugging Face Hub upload (model repo)
1. Install tooling and log in:
   ```bash
   pip install huggingface_hub git-lfs
   huggingface-cli login
   git lfs install
   ```
2. Track large artifacts:
   ```bash
   git lfs track "*.pth" "*.json" "*.pt"
   ```
3. Add a `README.md` (this file), code, and weights to the repo, then commit.
4. Create the Hub repo and push:
   ```bash
   huggingface-cli repo create YOUR_USERNAME/pet-vs-nonpet --type model
   git remote add origin https://huggingface.co/YOUR_USERNAME/pet-vs-nonpet
   git add .gitattributes README.md cnn_model.py xgboost_main.py main.py testMain.py inference.py requirements.txt models/cnn_model.pth models/xgb_model.json
   git commit -m "Add PET vs non-PET model"
   git push origin main
   ```

## Notes
- The dataset is not included; point scripts to your own JPEG directory matching the `PET*` / other naming convention used in training.
- For Hub Spaces, wrap `inference.py` in a small Gradio/Streamlit UI and list UI deps (e.g., `gradio`) in `requirements.txt`.
- All scripts default to GPU if available; otherwise they run on CPU.
