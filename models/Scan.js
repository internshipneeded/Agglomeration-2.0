// models/Scan.js
const mongoose = require('mongoose');

const ScanSchema = new mongoose.Schema({
  imageUrl: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  totalBottles: { type: Number, default: 0 },
  totalValue: { type: Number, default: 0 },
  
  // Use 'Mixed' to allow any structure the AI returns
  detections: [mongoose.Schema.Types.Mixed] 
});

module.exports = mongoose.model('Scan', ScanSchema);