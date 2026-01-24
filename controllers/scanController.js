const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
const { File } = require('node:buffer'); 
const FormData = require('form-data'); // 📦 NEW: For sending image to Python API

// Dynamic import for node-fetch
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// 🔗 REPLACE THIS WITH YOUR DEPLOYED PYTHON URL
const PET_MODEL_API_URL = "http://10.218.147.29:8000/predict";

// --- HELPER 1: PET PERPLEXITY (Material & Transparency) ---
const analyzeWithPetClassifier = async (imageBuffer) => {
  try {
    console.log("🔹 Connecting to Pet Perplexity Model...");
    
    // Prepare Form Data for FastAPI
    const form = new FormData();
    form.append('image', imageBuffer, { filename: 'scan.jpg', contentType: 'image/jpeg' });

    const response = await fetch(PET_MODEL_API_URL, {
      method: 'POST',
      body: form,
      headers: form.getHeaders()
    });

    if (!response.ok) throw new Error(`Python API responded with ${response.status}`);

    const data = await response.json();
    console.log(`✅ Pet Model found ${data.bottles?.length || 0} items.`);

    if (!data.success || !data.bottles) return [];

    // Map to our Unified Schema
    return data.bottles.map(b => ({
      source: "PetClassifier",
      label: "bottle",
      brand: "Unknown", // This model doesn't detect brands
      confidence: b.confidence,
      
      // Map Classification to Material
      material: b.classification, // "PET" or "Non-PET"
      
      // Map Transparency to Color
      color: b.transparency_probability > 0.5 ? "Clear" : "Colored",
      
      // Store specific probs for UI
      meta: {
        pet_prob: b.pet_probability,
        trans_prob: b.transparency_probability
      },

      // This model DOES give bounding boxes!
      boundingBox: [b.bbox.x1, b.bbox.y1, (b.bbox.x2 - b.bbox.x1), (b.bbox.y2 - b.bbox.y1)] 
    }));

  } catch (error) {
    console.error("❌ Pet Classifier Failed:", error.message);
    return [];
  }
};

// --- HELPER 2: AGGLO 2.0 (Brands) ---
const analyzeWithAgglo = async (imageFile) => {
  try {
    const client = await Client.connect("Arnavtr1/Agglo_2.0");
    const result = await client.predict("/infer", { image: imageFile });
    
    const rawText = result.data?.[0] || "";
    if (!rawText) return [];

    return rawText.split(/,|\n/).map(s => s.trim()).filter(s => s.length > 0)
      .map(brand => ({
        source: "Agglo_2.0",
        label: "bottle",
        brand: brand,
        confidence: 1.0,
        color: "Unknown",
        material: "PET",
        boundingBox: [] 
      }));
  } catch (error) {
    console.error("❌ Agglo Failed:", error.message);
    return [];
  }
};

// --- HELPER 3: SAM3 (Segmentation) ---
const analyzeWithSAM3 = async (imageFile) => {
  try {
    const client = await Client.connect("akhaliq/sam3");
    const result = await client.predict("/segment", { 
        image: imageFile, 
        text: "bottle", 
        threshold: 0.5, 
        mask_threshold: 0.5  
    });

    const segmentationResult = result.data?.[2];
    if (!segmentationResult || !segmentationResult.annotations) return [];

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

// --- MAIN CONTROLLER ---
exports.uploadScan = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ msg: 'No file uploaded' });

    const imageUrl = req.file.path;
    console.log("📸 Processing:", imageUrl);

    // 1. Download Image Once
    const response = await fetch(imageUrl);
    if (!response.ok) throw new Error("Failed to download image from Cloudinary");
    const arrayBuffer = await response.arrayBuffer();
    
    // Create formats for different models
    const buffer = Buffer.from(arrayBuffer); // For PetClassifier (FormData)
    const imageFile = new File([arrayBuffer], "scan.jpg", { type: "image/jpeg" }); // For Gradio

    // 2. Run ALL 3 Models in Parallel
    const [petResults, aggloResults, sam3Results] = await Promise.all([
        analyzeWithPetClassifier(buffer),
        analyzeWithAgglo(imageFile),
        analyzeWithSAM3(imageFile)
    ]);

    // 3. Merge Results
    const finalDetections = [...petResults, ...aggloResults, ...sam3Results];

    // 4. Calculate Stats
    // Use the max count found by any object-counting model (Pet or SAM3)
    const bottleCount = Math.max(petResults.length, sam3Results.length, aggloResults.length);
    
    // Value Calculation: Clear PET is worth more
    let estimatedValue = 0;
    // If we have PetClassifier data, use it for precise pricing
    if (petResults.length > 0) {
        petResults.forEach(b => {
            if (b.material === 'PET') {
                estimatedValue += (b.color === 'Clear' ? 6.0 : 4.0); // ₹6 Clear, ₹4 Colored
            } else {
                estimatedValue += 0.5; // Scrap value for Non-PET
            }
        });
    } else {
        estimatedValue = bottleCount * 5.0; // Fallback
    }

    // 5. Save
    const newScan = new Scan({
      imageUrl,
      batchId: "batch_" + Date.now(),
      totalBottles: bottleCount,
      totalValue: estimatedValue,
      detections: finalDetections 
    });

    await newScan.save();
    res.json(newScan);

  } catch (err) {
    console.error("Server Error:", err.message);
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