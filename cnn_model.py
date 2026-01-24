import torch
import torch.nn as nn
import os

class CNNModel(nn.Module):
    def __init__(self):
        super(CNNModel, self).__init__()
        self.conv1 = nn.Conv2d(in_channels=3, out_channels=16, kernel_size=3, stride=1, padding=1)
        self.relu = nn.ReLU()
        self.pool = nn.MaxPool2d(kernel_size=2, stride=2, padding=0)
        self.conv2 = nn.Conv2d(in_channels=16, out_channels=32, kernel_size=3, stride=1, padding=1)
        self.fc1 = nn.Linear(32 * 8 * 8, 128)
        self.fc2 = nn.Linear(128, 1)  # Binary classification with sigmoid
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        x = self.pool(self.relu(self.conv1(x)))
        x = self.pool(self.relu(self.conv2(x)))
        x = x.view(x.size(0), -1)  # Flexible flattening
        x = self.relu(self.fc1(x))
        x = self.sigmoid(self.fc2(x))  # Outputs probability [0, 1]
        return x

    def save_model(self, filepath):
        """Save the model to a file"""
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        torch.save(self.state_dict(), filepath)
        print(f"Model saved to {filepath}")

    def load_model(self, filepath):
        """Load the model from a file"""
        if os.path.exists(filepath):
            self.load_state_dict(torch.load(filepath))
            print(f"Model loaded from {filepath}")
        else:
            print(f"File not found: {filepath}")