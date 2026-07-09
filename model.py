"""
model.py — Bottle size classifier architecture (EfficientNet-B2 via timm)

This file previously contained the raw Kaggle training script (data prep,
training loop, etc.) instead of the `BottleNet` class that app.py imports.
Two effects of that bug:
  1. `from model import BottleNet` would fail with ImportError, since no
     such name was ever defined.
  2. Even before hitting that, importing the old model.py would execute
     its top-level code immediately (it wasn't guarded by
     `if __name__ == "__main__":`), which tries to read
     /kaggle/input/plastic-bottle-individual-size-dataset and crashes
     with FileNotFoundError outside of a Kaggle notebook.

This replacement defines exactly what app.py needs: a zero-argument
callable `BottleNet()` that reconstructs the same architecture used
during training, so the saved weights load back in with no shape
mismatches.

Verified against the recovered best_model.pth in this fix:
  model.load_state_dict(checkpoint['model_state_dict'], strict=True)
  -> <All keys matched successfully>  (508/508 tensors)

Classes (5, from the training run's checkpoint metadata, in class_to_idx
order): 100cl, 150cl, 200cl, 33cl, 50cl
"""

import timm


def BottleNet(num_classes: int = 5, pretrained: bool = False):
    """
    Factory returning a timm efficientnet_b2 model with the classifier
    head sized for `num_classes`.

    Returns the timm model directly rather than wrapping it in a custom
    nn.Module subclass, because the checkpoint's state_dict keys
    (conv_stem.*, bn1.*, blocks.*, ..., classifier.weight/bias) are the
    raw timm parameter names with no extra prefix -- a wrapper class
    would add one (e.g. "backbone.conv_stem.weight") and break
    load_state_dict(strict=True).
    """
    return timm.create_model("efficientnet_b2", pretrained=pretrained, num_classes=num_classes)