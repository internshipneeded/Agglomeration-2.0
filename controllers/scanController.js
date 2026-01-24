// controllers/scanController.js
const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
// 1. Import 'File' specifically for Node.js environment
const { File } = require('node:buffer'); 

// Dynamic import for node-fetch
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// --- 1. HELPER: AI ANALYSIS ---
const analyzeImageWithGradio = async (imageUrl) => {
  try {
    console.log("1. Connecting to Gradio Model...");
    const client = await Client.connect("Arnavtr1/Agglo_2.0");

    console.log("2. Downloading image from Cloudinary...");
    const response = await fetch(imageUrl);
    if (!response.ok) throw new Error(`Failed to fetch image: ${response.status}`);

    // 3. Convert Cloudinary stream to a Node.js File object
    // We get the raw buffer first, then wrap it in a File instance
    const arrayBuffer = await response.arrayBuffer();
    
    // This creates a standard File object that the API expects
    const imageFile = new File([arrayBuffer], "input_image.jpg", { type: "image/jpeg" });

    console.log("3. Sending image File to AI...");
    const result = await client.predict("/infer", { 
      image: imageFile, 
    });

    console.log("✅ Raw AI Response:", result.data);

    // Parsing Logic (String -> Array of Objects)
    const rawText = result.data?.[0] || "";
    if (!rawText) return [];

    return rawText
      .split(/,|\n/) // Split by comma or new line
      .map(s => s.trim())
      .filter(s => s.length > 0)
      .map(brand => ({
        label: "bottle",
        brand: brand,
        confidence: 1.0,
        color: "Unknown",
        material: "PET",
        boundingBox: [], // No boxes in text mode
      }));

  } catch (error) {
    console.error("❌ AI Inference Failed:", error);
    // Return dummy data on error so app doesn't crash
    return [{ label: "Error", brand: "Unknown", material: "N/A" }];
  }
};

// --- 2. CONTROLLER: UPLOAD SCAN ---
exports.uploadScan = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ msg: 'No file uploaded' });
    }

    const imageUrl = req.file.path; // Cloudinary URL
    console.log("📸 New Scan Uploaded:", imageUrl);

    // Call the Helper
    const aiResults = await analyzeImageWithGradio(imageUrl);

    // Calculate Value (Logic: ₹5 per bottle)
    const bottleCount = aiResults.length;
    const estimatedValue = bottleCount * 5; 

    // Save to MongoDB
    const newScan = new Scan({
      imageUrl,
      batchId: "batch_" + Date.now(),
      totalBottles: bottleCount,
      totalValue: estimatedValue,
      detections: aiResults 
    });

    await newScan.save();
    
    // Respond to Flutter
    res.json(newScan);

  } catch (err) {
    console.error("Server Error:", err.message);
    res.status(500).send('Server Error');
  }
};

// --- 3. CONTROLLER: GET HISTORY ---
exports.getAllScans = async (req, res) => {
    try {
      const scans = await Scan.find().sort({ timestamp: -1 });
      res.json(scans);
    } catch (err) {
      res.status(500).send('Server Error');
    }
};
