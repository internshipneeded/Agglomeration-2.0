// controllers/scanController.js
const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
// 1. Import 'File' specifically for Node.js environment
const { File } = require('node:buffer'); 

// Dynamic import for node-fetch
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// --- HELPER 1: AGGLO 2.0 (Brand Detection) ---
const analyzeWithAgglo = async (imageFile) => {
  try {
    console.log("🔹 Connecting to Agglo_2.0...");
    const client = await Client.connect("Arnavtr1/Agglo_2.0");

    console.log("🔹 Sending image to Agglo...");
    const result = await client.predict("/infer", { 
      image: imageFile, 
    });

    console.log("✅ Agglo Response:", result.data);

    // Parsing Logic
    const rawText = result.data?.[0] || "";
    if (!rawText) return [];

    return rawText
      .split(/,|\n/)
      .map(s => s.trim())
      .filter(s => s.length > 0)
      .map(brand => ({
        source: "Agglo_2.0",
        label: "bottle",
        brand: brand,
        confidence: 1.0,
        color: "Unknown",
        material: "PET",
        boundingBox: [], 
      }));

  } catch (error) {
    console.error("❌ Agglo Inference Failed:", error.message);
    return [];
  }
};

// --- HELPER 2: SAM3 (Segmentation) ---
const analyzeWithSAM3 = async (imageFile) => {
  try {
    console.log("🔸 Connecting to SAM3 (akhaliq/sam3)...");
    const client = await Client.connect("akhaliq/sam3");
    
    console.log("🔸 Sending Image & Prompt 'bottle' to SAM3...");
    const result = await client.predict("/segment", { 
        image: imageFile, 
        text: "bottle",      
        threshold: 0.5,      
        mask_threshold: 0.5  
    });

    const segmentationResult = result.data?.[2];

    if (!segmentationResult || !segmentationResult.annotations) {
        console.log("🔸 SAM3 found no annotations.");
        return [];
    }

    console.log(`✅ SAM3 found ${segmentationResult.annotations.length} masks.`);

    return segmentationResult.annotations.map((item) => ({
        source: "SAM3",
        label: item.label || "bottle",
        brand: "Unknown",
        material: "PET",
        confidence: 0.99,
        boundingBox: [], 
        maskUrl: item.image?.url || item.image 
    }));

  } catch (error) {
    console.error("❌ SAM3 Failed:", error.message);
    return [];
  }
};

// --- HELPER 3: SUDO AGGLO (Classification) ---
const analyzeWithSudoAgglo = async (imageFile) => {
  try {
    console.log("🔹 Connecting to SudoKuder/agglo...");
    const client = await Client.connect("SudoKuder/agglo");

    console.log("🔹 Sending image to SudoKuder (Classify Bottle)...");
    const result = await client.predict("/classify_bottle", { 
      image: imageFile, 
    });

    console.log("✅ SudoKuder Response:", result.data);

    // Parsing Logic: SudoKuder returns classification (e.g., Size or Type)
    // result.data is usually an array [ "Label" ] or [ { label: conf } ]
    const rawOutput = result.data?.[0];

    return [{
        source: "SudoKuder",
        label: "classification", // Represents the whole image
        brand: "N/A",
        // Convert the output to string (e.g., "1L", "500ml")
        size: rawOutput ? rawOutput.toString() : "Unknown", 
        confidence: 0.95,
        material: "PET",
        boundingBox: []
    }];

  } catch (error) {
    console.error("❌ SudoKuder Failed:", error.message);
    return [];
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

    // 1. PREPARE FILE (Download Once)
    const response = await fetch(imageUrl);
    if (!response.ok) throw new Error(`Failed to fetch image: ${response.status}`);

    const arrayBuffer = await response.arrayBuffer();
    const imageFile = new File([arrayBuffer], "scan.jpg", { type: "image/jpeg" });

    // 2. RUN ALL 3 MODELS IN PARALLEL
    const [aggloResults, sam3Results, sudoResults] = await Promise.all([
        analyzeWithAgglo(imageFile),
        analyzeWithSAM3(imageFile),
        analyzeWithSudoAgglo(imageFile) // <--- New Model Added Here
    ]);

    // 3. MERGE RESULTS
    const finalDetections = [...aggloResults, ...sam3Results, ...sudoResults];

    // 4. CALCULATE STATS
    // We stick to the max count from the DETECTOR models (Agglo & SAM3).
    // SudoKuder is likely a classifier (returns 1 result for the whole image), 
    // so we don't count it as a "new" bottle to avoid inflating numbers.
    const bottleCount = Math.max(aggloResults.length, sam3Results.length);
    const estimatedValue = bottleCount * 5; 

    // 5. SAVE TO DB
    const newScan = new Scan({
      imageUrl,
      batchId: "batch_" + Date.now(),
      totalBottles: bottleCount,
      totalValue: estimatedValue,
      detections: finalDetections 
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