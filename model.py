"""
Bottle Size Classification using EfficientNet-B2
Complete Kaggle Script with Improved Data Loading

Changes:
- Uses efficientnet_b2
- Adds motion blur augmentation
- Explicitly saves test split for later evaluation
- Fixed data loading issues with improved path handling
- All-in-one executable script
"""

import os
import random
import shutil
from pathlib import Path
import numpy as np
import torch
import torch.nn as nn
import timm
from torchvision import datasets
from torch.utils.data import DataLoader, WeightedRandomSampler
import albumentations as A
from albumentations.pytorch import ToTensorV2

# Set random seeds for reproducibility
random.seed(42)
torch.manual_seed(42)
np.random.seed(42)

print("=" * 80)
print("BOTTLE SIZE CLASSIFICATION - EfficientNet-B2")
print("=" * 80)

# ==================== CONFIGURATION ====================
BASE_INPUT = Path("/kaggle/input/plastic-bottle-individual-size-dataset")
DST_DIR = Path("/kaggle/working/bottle_dataset")
TRAIN_DIR = DST_DIR / "train"
TEST_DIR = DST_DIR / "test"

BATCH_SIZE = 24
LEARNING_RATE = 2e-4
EPOCHS = 20
IMAGE_SIZE = 260

# ==================== STEP 1: EXPLORE DATASET ====================
print("\n" + "=" * 80)
print("STEP 1: Exploring Dataset Structure")
print("=" * 80)

if not BASE_INPUT.exists():
    raise FileNotFoundError(f"ERROR: Base input directory not found: {BASE_INPUT}")

print(f"Found base directory: {BASE_INPUT}\n")
print("Directory structure:")

# Show directory structure
for item in sorted(BASE_INPUT.rglob("*"))[:50]:  # Limit to first 50 items
    depth = len(item.relative_to(BASE_INPUT).parts)
    indent = "  " * depth
    item_type = "📁" if item.is_dir() else "📄"
    print(f"{indent}{item_type} {item.name}")
    
    # Show sample files for directories
    if item.is_dir():
        files = list(item.glob("*.jpg"))[:2]
        if files:
            for f in files:
                print(f"{indent}  └─ {f.name}")

# ==================== STEP 2: FIND CLASS DIRECTORIES ====================
print("\n" + "=" * 80)
print("STEP 2: Locating Class Directories")
print("=" * 80)

class_dirs = []
for root, dirs, files in os.walk(BASE_INPUT):
    jpg_files = [f for f in files if f.lower().endswith('.jpg')]
    if jpg_files and dirs:
        # This might be the parent directory
        root_path = Path(root)
        for d in dirs:
            dir_path = root_path / d
            if list(dir_path.glob("*.jpg")):
                class_dirs.append(dir_path)
    elif jpg_files and not dirs:
        # This is a class directory
        class_dirs.append(Path(root))

if not class_dirs:
    raise ValueError("ERROR: No directories with .jpg images found!")

# Get the parent directory of class folders
parent_dirs = set([d.parent for d in class_dirs])
print(f"Found {len(class_dirs)} class directories")

if len(parent_dirs) == 1:
    SRC_DIR = list(parent_dirs)[0]
    print(f"Using source directory: {SRC_DIR}")
else:
    print(f"WARNING: Multiple parent directories found: {parent_dirs}")
    SRC_DIR = list(parent_dirs)[0]
    print(f"Defaulting to: {SRC_DIR}")

# ==================== STEP 3: CREATE TRAIN/TEST SPLIT ====================
print("\n" + "=" * 80)
print("STEP 3: Creating Train/Test Split (80/20)")
print("=" * 80)

# Remove existing directories to start fresh
if DST_DIR.exists():
    shutil.rmtree(DST_DIR)
    print("Removed existing dataset directory")

TRAIN_DIR.mkdir(parents=True, exist_ok=True)
TEST_DIR.mkdir(parents=True, exist_ok=True)

total_train = 0
total_test = 0
class_info = []

for cls_dir in sorted(class_dirs):
    cls_name = cls_dir.name
    images = list(cls_dir.glob("*.jpg"))
    
    if len(images) == 0:
        print(f"⚠️  Class '{cls_name}': No images found - SKIPPING")
        continue
    
    random.shuffle(images)
    split_idx = int(0.8 * len(images))
    
    train_count = split_idx
    test_count = len(images) - split_idx
    
    # Create class directories
    (TRAIN_DIR / cls_name).mkdir(exist_ok=True)
    (TEST_DIR / cls_name).mkdir(exist_ok=True)
    
    # Copy files
    for img in images[:split_idx]:
        shutil.copy(img, TRAIN_DIR / cls_name / img.name)
    
    for img in images[split_idx:]:
        shutil.copy(img, TEST_DIR / cls_name / img.name)
    
    total_train += train_count
    total_test += test_count
    class_info.append((cls_name, len(images), train_count, test_count))
    
    print(f"✓ {cls_name:20s}: {len(images):4d} total ({train_count:4d} train, {test_count:3d} test)")

print(f"\n{'Total':20s}: {total_train + total_test:4d} total ({total_train:4d} train, {total_test:3d} test)")

# ==================== STEP 4: DEFINE DATA TRANSFORMATIONS ====================
print("\n" + "=" * 80)
print("STEP 4: Setting Up Data Augmentation")
print("=" * 80)

train_tfms = A.Compose([
    A.Resize(IMAGE_SIZE, IMAGE_SIZE),
    A.Rotate(limit=10, p=0.5),
    A.MotionBlur(blur_limit=7, p=0.3),
    A.RandomBrightnessContrast(p=0.5),
    A.Normalize(mean=(0.485, 0.456, 0.406),
                std=(0.229, 0.224, 0.225)),
    ToTensorV2()
])

test_tfms = A.Compose([
    A.Resize(IMAGE_SIZE, IMAGE_SIZE),
    A.Normalize(mean=(0.485, 0.456, 0.406),
                std=(0.229, 0.224, 0.225)),
    ToTensorV2()
])

print("Training augmentations:")
print("  - Resize to 260x260")
print("  - Random rotation (±10°, p=0.5)")
print("  - Motion blur (p=0.3)")
print("  - Brightness/Contrast adjustment (p=0.5)")
print("  - ImageNet normalization")
print("\nTest transformations:")
print("  - Resize to 260x260")
print("  - ImageNet normalization")

# ==================== STEP 5: CREATE DATASETS ====================
print("\n" + "=" * 80)
print("STEP 5: Creating PyTorch Datasets")
print("=" * 80)

class AlbDataset(torch.utils.data.Dataset):
    """Custom Dataset wrapper for Albumentations transforms"""
    def __init__(self, root, transform):
        self.ds = datasets.ImageFolder(root)
        self.transform = transform

    def __len__(self):
        return len(self.ds)

    def __getitem__(self, idx):
        img, label = self.ds[idx]
        img = np.array(img)
        img = self.transform(image=img)["image"]
        return img, label

# Create base dataset to get class info
base_ds = datasets.ImageFolder(str(TRAIN_DIR))
counts = np.bincount([y for _, y in base_ds])
weights = 1.0 / counts
sample_weights = [weights[y] for _, y in base_ds]

print(f"Classes found: {list(base_ds.class_to_idx.keys())}")
print(f"Class distribution in training set:")
for cls_name, count in zip(base_ds.classes, counts):
    print(f"  {cls_name}: {count} samples (weight: {weights[base_ds.class_to_idx[cls_name]]:.4f})")

# Create datasets with augmentations
train_ds = AlbDataset(str(TRAIN_DIR), train_tfms)
test_ds = AlbDataset(str(TEST_DIR), test_tfms)

# Create weighted sampler for balanced training
sampler = WeightedRandomSampler(sample_weights, len(sample_weights), replacement=True)

# Create data loaders
train_loader = DataLoader(train_ds, batch_size=BATCH_SIZE, sampler=sampler, num_workers=2)
test_loader = DataLoader(test_ds, batch_size=BATCH_SIZE, shuffle=False, num_workers=2)

print(f"\nDataLoader Configuration:")
print(f"  Training batches: {len(train_loader)} (batch size: {BATCH_SIZE})")
print(f"  Test batches: {len(test_loader)} (batch size: {BATCH_SIZE})")
print(f"  Using WeightedRandomSampler for class balance")

# ==================== STEP 6: CREATE MODEL ====================
print("\n" + "=" * 80)
print("STEP 6: Building EfficientNet-B2 Model")
print("=" * 80)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")

model = timm.create_model(
    "efficientnet_b2",
    pretrained=True,
    num_classes=len(base_ds.classes)
)
model.to(device)

# Loss function with class weights
criterion = nn.CrossEntropyLoss(
    weight=torch.tensor(weights, dtype=torch.float).to(device)
)

# Optimizer
optimizer = torch.optim.AdamW(model.parameters(), lr=LEARNING_RATE)

total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)

print(f"\nModel: EfficientNet-B2")
print(f"Total parameters: {total_params:,}")
print(f"Trainable parameters: {trainable_params:,}")
print(f"Number of classes: {len(base_ds.classes)}")
print(f"Optimizer: AdamW (lr={LEARNING_RATE})")
print(f"Loss: CrossEntropyLoss with class weights")

# ==================== STEP 7: TRAINING ====================
print("\n" + "=" * 80)
print("STEP 7: Training Model")
print("=" * 80)

def train_epoch():
    """Train for one epoch"""
    model.train()
    correct, total = 0, 0
    running_loss = 0.0
    
    for batch_idx, (x, y) in enumerate(train_loader):
        x, y = x.to(device), y.to(device)
        
        optimizer.zero_grad()
        out = model(x)
        loss = criterion(out, y)
        loss.backward()
        optimizer.step()
        
        correct += (out.argmax(1) == y).sum().item()
        total += y.size(0)
        running_loss += loss.item()
        
        # Print progress every 50 batches
        if (batch_idx + 1) % 50 == 0:
            print(f"  Batch {batch_idx + 1}/{len(train_loader)} - Loss: {loss.item():.4f}", end='\r')
    
    return correct / total, running_loss / len(train_loader)

def eval_epoch():
    """Evaluate on test set"""
    model.eval()
    correct, total = 0, 0
    running_loss = 0.0
    
    with torch.no_grad():
        for x, y in test_loader:
            x, y = x.to(device), y.to(device)
            out = model(x)
            loss = criterion(out, y)
            
            correct += (out.argmax(1) == y).sum().item()
            total += y.size(0)
            running_loss += loss.item()
    
    return correct / total, running_loss / len(test_loader)

# Training loop
best_test_acc = 0.0
best_epoch = 0
history = {
    'train_acc': [], 'train_loss': [],
    'test_acc': [], 'test_loss': []
}

print(f"\nTraining for {EPOCHS} epochs...\n")
print(f"{'Epoch':^8} | {'Train Acc':^10} | {'Train Loss':^11} | {'Test Acc':^10} | {'Test Loss':^11} | {'Status':^10}")
print("-" * 80)

for epoch in range(EPOCHS):
    train_acc, train_loss = train_epoch()
    test_acc, test_loss = eval_epoch()
    
    # Store history
    history['train_acc'].append(train_acc)
    history['train_loss'].append(train_loss)
    history['test_acc'].append(test_acc)
    history['test_loss'].append(test_loss)
    
    # Save best model
    status = ""
    if test_acc > best_test_acc:
        best_test_acc = test_acc
        best_epoch = epoch + 1
        torch.save({
            'epoch': epoch,
            'model_state_dict': model.state_dict(),
            'optimizer_state_dict': optimizer.state_dict(),
            'test_acc': test_acc,
            'train_acc': train_acc,
        }, '/kaggle/working/best_model.pth')
        status = "⭐ BEST"
    
    print(f"{epoch+1:^8} | {train_acc:^10.4f} | {train_loss:^11.4f} | {test_acc:^10.4f} | {test_loss:^11.4f} | {status:^10}")

# ==================== STEP 8: FINAL RESULTS ====================
print("\n" + "=" * 80)
print("TRAINING COMPLETE!")
print("=" * 80)

print(f"\nBest Results:")
print(f"  Best Test Accuracy: {best_test_acc:.4f} (Epoch {best_epoch})")
print(f"  Final Train Accuracy: {history['train_acc'][-1]:.4f}")
print(f"  Final Test Accuracy: {history['test_acc'][-1]:.4f}")

print(f"\nModel saved to: /kaggle/working/best_model.pth")
print(f"Test set saved to: {TEST_DIR}")

# Save training history
import json
with open('/kaggle/working/training_history.json', 'w') as f:
    json.dump(history, f, indent=2)
print(f"Training history saved to: /kaggle/working/training_history.json")

print("\n" + "=" * 80)
print("All done! 🎉")
print("=" * 80)

# Add this at the end of your training script
import json

# Get class names
class_info = {
    "class_names": base_ds.classes,
    "class_to_idx": base_ds.class_to_idx,
    "num_classes": len(base_ds.classes),
    "best_accuracy": float(best_test_acc),
    "best_epoch": int(best_epoch)
}

with open('/kaggle/working/class_info.json', 'w') as f:
    json.dump(class_info, f, indent=2)

print("\n" + "="*60)
print("CLASS INFORMATION")
print("="*60)
print(json.dumps(class_info, indent=2))
print("\n✅ Saved to: /kaggle/working/class_info.json")

# Also save class names in the model checkpoint
checkpoint = torch.load('/kaggle/working/best_model.pth')
checkpoint['class_names'] = base_ds.classes
checkpoint['class_to_idx'] = base_ds.class_to_idx
torch.save(checkpoint, '/kaggle/working/best_model.pth')
print("✅ Updated best_model.pth with class names")