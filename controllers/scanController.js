const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
const { File } = require('node:buffer'); 

// Dynamic import for node-fetch to handle image downloading
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// =========================================================
// 1. PET CLASSIFIER (SudoKuder/agglo)
// =========================================================
const analyzeWithPetModel = async (imageFile) => {
  try {
    console.log("🔹 Connecting to SudoKuder/agglo (Pet Classifier)...");
    const client = await Client.connect("SudoKuder/agglo");

    const result = await client.predict("/classify_bottle", { 
      image: imageFile, 
    });

    console.log("✅ Pet Classifier Response:", result.data);

    // Parse the specific string format returned by this model
    const textOutput = result.data?.[1]; 
    if (!textOutput || typeof textOutput !== 'string') return [];

    const detections = [];
    const lines = textOutput.split('\n');

    lines.forEach(line => {
        const match = line.match(/Bottle \d+: (PET|Non-PET) \(confidence: ([\d.]+)%, transparency: ([\d.]+)%\)/);
        if (match) {
            const material = match[1];
            const conf = parseFloat(match[2]) / 100;
            const trans = parseFloat(match[3]) / 100;
            const isClear = trans > 0.5; // Threshold for transparency

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
    console.error("❌ Pet Classifier Failed:", error.message);
    return [];
  }
};

// =========================================================
// 2. AGGLO 2.0 (Brand Detection)
// =========================================================
const analyzeWithAgglo = async (imageFile) => {
  try {
    console.log("🔹 Connecting to Agglo_2.0...");
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

// =========================================================
// 3. SAM3 (Segmentation)
// =========================================================
const analyzeWithSAM3 = async (imageFile) => {
  try {
    console.log("🔸 Connecting to SAM3...");
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

// =========================================================
// 4. HW YOLO (Arnavtr1/hw_yolo) - NEW INTEGRATION
// =========================================================
const analyzeWithHWYolo = async (imageFile) => {
  try {
    console.log("🔹 Connecting to Arnavtr1/hw_yolo...");
    const client = await Client.connect("Arnavtr1/hw_yolo");

    // Using parameters from your Python snippet
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

    console.log("✅ HW YOLO Response:", result.data);

    // Gradio usually returns [json_data, image_path] or similar for detection.
    // We attempt to parse the first element if it's JSON/String data.
    let parsedData = result.data;
    
    // Attempt to normalize the output structure
    return [{
        source: "HW_Yolo",
        label: "bottle_yolo",
        brand: "Unknown",
        material: "PET",
        confidence: 0.9, // Default if model doesn't return explicit confidence per item
        color: "Unknown",
        boundingBox: [],
        meta: { 
            raw_output: parsedData,
            model_params: { aruco: true, crushed: false }
        }
    }];

  } catch (error) {
    console.error("❌ HW YOLO Failed:", error.message);
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
    console.log("📸 Processing:", imageUrl);

    // 1. Download Image Once
    const response = await fetch(imageUrl);
    if (!response.ok) throw new Error("Failed to download image");
    const arrayBuffer = await response.arrayBuffer();
    
    // Create File object for Gradio Clients
    const imageFile = new File([arrayBuffer], "scan.jpg", { type: "image/jpeg" });

    // 2. Run ALL 4 Models in Parallel
    const [petResults, aggloResults, sam3Results, yoloResults] = await Promise.all([
        analyzeWithPetModel(imageFile),   // Model 1
        analyzeWithAgglo(imageFile),      // Model 2
        analyzeWithSAM3(imageFile),       // Model 3
        analyzeWithHWYolo(imageFile)      // Model 4 (New)
    ]);

    // 3. Merge Results
    const finalDetections = [
        ...petResults, 
        ...aggloResults, 
        ...sam3Results, 
        ...yoloResults
    ];

    // 4. Calculate Stats (Prioritize max detection count)
    const bottleCount = Math.max(
        sam3Results.length, 
        petResults.length, 
        aggloResults.length,
        yoloResults.length
    );
    
    // 5. Value Calculation
    let estimatedValue = 0;
    
    if (petResults.length > 0) {
        // Detailed calculation based on material/color if available
        petResults.forEach(b => {
            if (b.material === 'PET') {
                estimatedValue += (b.color === 'Clear' ? 6.0 : 4.0);
            } else {
                estimatedValue += 0.5; // Scrap value
            }
        });
        
        // Add generic value for bottles detected by other models but not the Pet Classifier
        if (bottleCount > petResults.length) {
             estimatedValue += (bottleCount - petResults.length) * 5.0;
        }
    } else {
        // Fallback generic calculation if Pet Classifier fails
        estimatedValue = bottleCount * 5.0; 
    }

    // 6. Save to Database
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