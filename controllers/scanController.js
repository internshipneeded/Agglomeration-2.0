// controllers/scanController.js
const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

const analyzeImageWithGradio = async (imageUrl) => {
  try {
    console.log("1. Connecting to Gradio Model: Arnavtr1/Agglo_2.0...");
    const client = await Client.connect("Arnavtr1/Agglo_2.0");

    console.log("2. Fetching image from Cloudinary...");
    const response = await fetch(imageUrl);
    const imageBlob = await response.blob();

    console.log("3. Sending image to AI (Endpoint: /infer)...");
    const result = await client.predict("/infer", { 
      image: imageBlob, 
    });

    console.log("✅ Raw AI Response:", result.data);

    // --- NEW PARSING LOGIC (For String Output) ---
    // The docs say result.data is [ "String of Brands" ]
    const rawText = result.data[0] || ""; 
    
    if (!rawText) return [];

    // Heuristic: Split by comma or newline to find individual items
    // Example Input: "Bisleri, Aquafina, Coke" -> ["Bisleri", "Aquafina", "Coke"]
    const brands = rawText.split(/,|\n/).map(s => s.trim()).filter(s => s.length > 0);

    // Convert to our standard Detections format
    return brands.map(brandName => ({
        label: "bottle", // Default label since model implies bottles
        brand: brandName,
        confidence: 1.0, // Text output doesn't usually give confidence
        color: "Unknown", 
        material: "PET",
        boundingBox: [] // No boxes available in text mode
    }));

  } catch (error) {
    console.error("❌ AI Inference Failed:", error);
    // Return dummy data so app doesn't crash during demo
    return [{ label: "Error", brand: "Unknown", confidence: 0 }];
  }
};

exports.uploadScan = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ msg: 'No file uploaded' });

    const imageUrl = req.file.path;
    
    // 1. Get AI Results (List of brands)
    const aiResults = await analyzeImageWithGradio(imageUrl);

    // 2. Calculate Logic
    const bottleCount = aiResults.length;
    const estimatedValue = bottleCount * 5; // e.g., ₹5 per bottle

    // 3. Save
    const newScan = new Scan({
      imageUrl,
      batchId: "batch_" + Date.now(),
      totalBottles: bottleCount,
      totalValue: estimatedValue,
      detections: aiResults 
    });

    await newScan.save();
    res.json(newScan);

  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
};

exports.getAllScans = async (req, res) => {
    try {
      const scans = await Scan.find().sort({ timestamp: -1 });
      res.json(scans);
    } catch (err) {
      res.status(500).send('Server Error');
    }
};