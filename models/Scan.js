const mongoose = require('mongoose');

const ScanSchema = new mongoose.Schema({
  imageUrl: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  batchId: { type: String, default: "batch_default" },
  
  // Summary Stats
  totalBottles: { type: Number, required: true },
  totalValue: { type: Number, required: true },
  
  // The Detailed AI Results
  detections: [
    {
      label: String,        // "bottle", "contaminant"
      confidence: Number,
      brand: String,        // "Bisleri"
      color: String,        // "Clear", "Green"
      material: String,     // "PET", "HDPE"
      boundingBox: [Number] // [x, y, w, h]
    }
  ]
});

module.exports = mongoose.model('Scan', ScanSchema);