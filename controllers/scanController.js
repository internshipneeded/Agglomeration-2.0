const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
// valid for Node 18+ to create File objects from buffers
const { File } = require('node:buffer'); 

// Dynamic import for node-fetch
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// =========================================================
// 1. PET CLASSIFIER (SudoKuder/agglo)
// =========================================================
const analyzeWithPetModel = async (imageFile) => {
  try {
    const client = await Client.connect("SudoKuder/agglo");
    const result = await client.predict("/classify_bottle", { image: imageFile });

    const textOutput = result.data?.[1]; 
    if (!textOutput || typeof textOutput !== 'string') return [];

    const detections = [];
    const lines = textOutput.split('\n');

    lines.forEach(line => {
        // Parse: "Bottle 1: PET (confidence: 98.50%, transparency: 5.00%)"
        const match = line.match(/Bottle \d+: (PET|Non-PET) \(confidence: ([\d.]+)%, transparency: ([\d.]+)%\)/);
        if (match) {
            const material = match[1];
            const conf = parseFloat(match[2]) / 100;
            const trans = parseFloat(match[3]) / 100;
            const isClear = trans > 0.5; 

            detections.push({
                source: "PetClassifier",
                label: "bottle",
                brand: "Unknown", 
                material: material,
                confidence: conf,
                color: isClear ? "Clear" : "Colored",
                boundingBox: [],
                meta: { pet_prob: conf, trans_prob: trans }
            });
        }
    });
    return detections;
  } catch (error) {
    console.error("❌ Pet Classifier Skipped:", error.message);
    return [];
  }
};

// =========================================================
// 2. AGGLO 2.0 (Brand Detection)
// =========================================================
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
    console.error("❌ Agglo Skipped:", error.message);
    return [];
  }
};

// =========================================================
// 3. SAM3 (Segmentation)
// =========================================================
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
    if (error.message.includes("quota")) {
        console.warn("⚠️ SAM3 Quota Exceeded (Skipping)");
    } else {
        console.error("❌ SAM3 Skipped:", error.message);
    }
    return [];
  }
};

// =========================================================
// 4. HW YOLO (Arnavtr1/hw_yolo)
// =========================================================
const analyzeWithHWYolo = async (imageFile) => {
  try {
    console.log("🔹 Connecting to HW YOLO...");
    const client = await Client.connect("Arnavtr1/hw_yolo");

    // Using the exact parameters from your working snippet
    const result = await client.predict("/inference", { 
        image: imageFile,
        aruco_size_val: 3,
        use_aruco_val: true,
        cap_size_val: 3,
        crushed_val: false,
        fx_val: 3,
        fy_val: 3,
        dist_val: 3,
    });

    console.log("✅ HW YOLO Raw Result:", JSON.stringify(result.data).substring(0, 100) + "...");

    // ROBUST PARSING:
    // result.data is typically an array. Index 0 usually holds the detections.
    let rawOutput = result.data;
    if (Array.isArray(result.data) && result.data.length > 0) {
        rawOutput = result.data[0];
    }

    // Check if it returned null (error state)
    if (!rawOutput) {
        // Check for error object in second index (as seen in your logs)
        if (result.data?.[1]?.error) {
            console.error("❌ HW YOLO Remote Error:", result.data[1].error);
        }
        return [];
    }

    // If string, parse it. If object, use it.
    let parsedData = rawOutput;
    try {
        if (typeof rawOutput === 'string') {
            parsedData = JSON.parse(rawOutput);
        }
    } catch(e) {
        console.warn("⚠️ HW YOLO returned non-JSON string:", rawOutput);
    }

    return [{
        source: "HW_Yolo",
        label: "bottle_yolo",
        brand: "Unknown",
        material: "PET",
        confidence: 0.9,
        color: "Unknown",
        boundingBox: [],
        meta: { raw_output: parsedData }
    }];

  } catch (error) {
    console.error("❌ HW YOLO Skipped:", error.message);
    return [];
  }
};

// =========================================================
// 5. BOTTLE SIZE MODEL (immortal-tree/plastic_bottle_size)
// =========================================================
const analyzeWithBottleSize = async (imageFile) => {
  try {
    const client = await Client.connect("immortal-tree/plastic_bottle_size");
    const result = await client.predict("/predict", { image: imageFile });

    const rawData = result.data;
    let sizeLabel = "Unknown";

    // Handle different Gradio label formats
    if (Array.isArray(rawData) && rawData.length > 0) {
        if (rawData[0]?.label) sizeLabel = rawData[0].label;
        else if (typeof rawData[0] === 'string') sizeLabel = rawData[0];
    } else if (rawData?.label) {
        sizeLabel = rawData.label;
    }

    return [{
        source: "SizeClassifier",
        label: "bottle",
        brand: "Unknown",
        material: "PET",
        confidence: 0.85,
        color: "Unknown",
        boundingBox: [], 
        meta: { detected_size: sizeLabel }
    }];

  } catch (error) {
    console.error("❌ Size Model Skipped:", error.message);
    return [];
  }
};

// =========================================================
// MAIN CONTROLLER
// =========================================================
exports.uploadScan = async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ msg: 'No file uploaded' });

    const imageUrl = req.file.path;
    console.log("📸 Processing Scan:", imageUrl);

    // 1. Download Image (Create File object for Gradio)
    const response = await fetch(imageUrl);
    if (!response.ok) throw new Error("Failed to download image");
    const arrayBuffer = await response.arrayBuffer();
    const imageFile = new File([arrayBuffer], "scan.jpg", { type: "image/jpeg" });

    // 2. Parallel Execution (Wait for all models)
    // We use Promise.all to run them concurrently for speed
    const [petRes, aggloRes, samRes, yoloRes, sizeRes] = await Promise.all([
        analyzeWithPetModel(imageFile),
        analyzeWithAgglo(imageFile),
        analyzeWithSAM3(imageFile),
        analyzeWithHWYolo(imageFile),
        analyzeWithBottleSize(imageFile)
    ]);

    // 3. Merge Valid Detections
    const finalDetections = [
        ...petRes, 
        ...aggloRes, 
        ...samRes, 
        ...yoloRes,
        ...sizeRes
    ];

    // 4. Calculate Stats
    // Logic: Take the highest bottle count reported by any model
    const bottleCount = Math.max(
        samRes.length, 
        petRes.length, 
        aggloRes.length, 
        yoloRes.length, 
        sizeRes.length
    );

    // Ensure at least 1 bottle if we have detections but counts matched oddly
    const finalCount = (bottleCount === 0 && finalDetections.length > 0) ? 1 : bottleCount;

    // 5. Value Calculation
    let estimatedValue = 0;
    if (petRes.length > 0) {
        petRes.forEach(b => {
            if (b.material === 'PET') estimatedValue += (b.color === 'Clear' ? 6.0 : 4.0);
            else estimatedValue += 0.5;
        });
        // Adjust for discrepancies
        if (finalCount > petRes.length) {
             estimatedValue += (finalCount - petRes.length) * 5.0;
        }
    } else {
        estimatedValue = finalCount * 5.0; 
    }

    // 6. Save DB Entry
    const newScan = new Scan({
      imageUrl,
      batchId: "batch_" + Date.now(),
      totalBottles: finalCount,
      totalValue: estimatedValue,
      detections: finalDetections 
    });

    await newScan.save();
    console.log(`✅ Scan Complete: ${finalCount} bottles detected. Total Value: ₹${estimatedValue}`);
    res.json(newScan);

  } catch (err) {
    console.error("🔥 Server Error:", err.message);
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