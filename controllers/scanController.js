// controllers/scanController.js
const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// --- REAL AI ENGINE ---
const analyzeImageWithGradio = async (imageUrl) => {
  try {
    console.log("1. Connecting to Gradio Model: Arnavtr1/Agglo_2.0...");
    const client = await Client.connect("Arnavtr1/Agglo_2.0");

    console.log("2. Fetching image from Cloudinary...");
    const response = await fetch(imageUrl);
    const imageBlob = await response.blob();

    console.log("3. Sending image to AI for prediction...");
    const result = await client.predict("/infer", { 
      image: imageBlob, 
    });

    console.log("✅ AI Response Raw Data:", JSON.stringify(result.data, null, 2));

    // --- PARSING LOGIC ---
    // IMPORTANT: detailed mapping depends on exactly what "Agglo_2.0" returns.
    // Assuming it returns a JSON string or an Object with detection lists.
    // We default to returning the raw data if we can't parse it specifically yet.
    
    // Example: If model returns a list of detections directly
    if (Array.isArray(result.data)) {
        // Map your model's specific output format to your Schema here
        // This is a placeholder mapping:
        return result.data.map(item => ({
            label: item.label || "unknown", // Replace with actual key from model
            confidence: item.score || 0.9,  // Replace with actual key
            brand: item.brand || "Generic",
            color: item.color || "Clear",
            material: "PET", // Defaulting to PET for now
            boundingBox: item.box || [0,0,0,0] 
        }));
    }

    // Fallback: return the raw data wrapped in a generic object so app doesn't crash
    return [{
        label: "AI_Processed",
        confidence: 1.0,
        raw_data: result.data // Saving raw data to debug
    }];

  } catch (error) {
    console.error("❌ AI Inference Failed:", error);
    // Return a dummy error object so the flow doesn't break
    return [{ label: "Error", confidence: 0, material: "Unknown" }];
  }
};

// --- CONTROLLER FUNCTION ---
exports.uploadScan = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ msg: 'No file uploaded' });
    }

    const imageUrl = req.file.path; // Cloudinary URL

    // 1. CALL THE REAL AI
    const aiResults = await analyzeImageWithGradio(imageUrl);

    // 2. CALCULATE LOGIC (Price/Count)
    // Update this logic based on the actual keys your model returns
    let bottleCount = aiResults.length;
    let estimatedValue = 0;

    aiResults.forEach(item => {
        // Example pricing logic
        if (item.label === 'bottle') {
             estimatedValue += (item.color === 'Clear') ? 5.0 : 2.0;
        }
    });

    // 3. SAVE TO DB
    const newScan = new Scan({
      imageUrl,
      batchId: req.body.batchId || "batch_default",
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

// ... keep exports.getAllScans same as before ...
exports.getAllScans = async (req, res) => {
    try {
      const scans = await Scan.find().sort({ timestamp: -1 });
      res.json(scans);
    } catch (err) {
      res.status(500).send('Server Error');
    }
};