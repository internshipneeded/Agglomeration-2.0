// controllers/scanController.js
const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
// 1. Import 'File' specifically for Node.js environment
const { File } = require('node:buffer'); 

// Dynamic import for node-fetch
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// --- HELPER 1: AGGLO 2.0 (Brand Detection) ---
// Updated to accept a 'File' object directly
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
        text: "bottle",      // Prompt looking for bottles
        threshold: 0.5,      
        mask_threshold: 0.5  
    });

    // SAM3 returns annotations at index 2
    // Structure: { image: "...", annotations: [ { image: "...", label: "bottle" } ] }
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
        boundingBox: [], // SAM3 gives masks, not boxes
        // You could store the mask URL here if your Schema allows strict: false
        maskUrl: item.image?.url || item.image 
    }));

  } catch (error) {
    console.error("❌ SAM3 Failed:", error.message);
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
    // We download here so we can pass the same File object to BOTH models
    const response = await fetch(imageUrl);
    if (!response.ok) throw new Error(`Failed to fetch image: ${response.status}`);

    const arrayBuffer = await response.arrayBuffer();
    const imageFile = new File([arrayBuffer], "scan.jpg", { type: "image/jpeg" });

    // 2. RUN MODELS IN PARALLEL
    const [aggloResults, sam3Results] = await Promise.all([
        analyzeWithAgglo(imageFile),
        analyzeWithSAM3(imageFile)
    ]);

    // 3. MERGE RESULTS
    const finalDetections = [...aggloResults, ...sam3Results];

    // 4. CALCULATE STATS
    // We use Math.max because if Agglo sees 3 bottles and SAM3 sees 3, 
    // it's likely the SAME 3 bottles, not 6.
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