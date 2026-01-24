const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
const { File } = require('node:buffer'); 

// Dynamic import for node-fetch
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

// --- HELPER 1: PET CLASSIFIER (SudoKuder/agglo) ---
const analyzeWithPetModel = async (imageFile) => {
  try {
    console.log("🔹 Connecting to SudoKuder/agglo (Pet Classifier)...");
    const client = await Client.connect("SudoKuder/agglo");

    console.log("🔹 Sending image to Pet Classifier...");
    // The API name based on your snippet is "/classify_bottle"
    const result = await client.predict("/classify_bottle", { 
      image: imageFile, 
    });

    console.log("✅ Pet Classifier Response:", result.data);

    // PARSING LOGIC:
    // Based on the app.py you shared, the model returns:
    // [ result_image_blob, result_text_string ]
    //
    // The text string looks like:
    // "Bottle 1: PET (confidence: 98.50%, transparency: 5.00%)"
    // "Bottle 2: Non-PET (confidence: 92.10%, transparency: 85.00%)"
    
    const textOutput = result.data?.[1]; 
    if (!textOutput || typeof textOutput !== 'string') return [];

    const detections = [];
    const lines = textOutput.split('\n');

    lines.forEach(line => {
        // Regex to extract data from the string
        // Matches: "Bottle 1: PET (confidence: 98.50%, transparency: 5.00%)"
        const match = line.match(/Bottle \d+: (PET|Non-PET) \(confidence: ([\d.]+)%, transparency: ([\d.]+)%\)/);
        
        if (match) {
            const material = match[1]; // "PET" or "Non-PET"
            const conf = parseFloat(match[2]) / 100; // 0.985
            const trans = parseFloat(match[3]) / 100; // 0.05

            // Logic: High transparency (< 30%) usually means "Clear"
            // High transparency value in code might actually mean "Opacity" depending on training, 
            // but usually low transparency prob = Opaque/Colored.
            // Let's assume based on common models: 
            // If transparency is HIGH (e.g. 90%), it is Clear.
            // If transparency is LOW (e.g. 5%), it is Colored.
            // *Adjust this threshold based on your specific model's behavior*
            const isClear = trans > 0.5; 

            detections.push({
                source: "PetClassifier",
                label: "bottle",
                brand: "Unknown", 
                material: material,
                confidence: conf,
                color: isClear ? "Clear" : "Colored",
                boundingBox: [], // This API endpoint returns a drawn image, not coords we can easily use
                meta: {
                    pet_prob: conf,
                    trans_prob: trans
                }
            });
        }
    });

    return detections;

  } catch (error) {
    console.error("❌ Pet Classifier Failed:", error.message);
    return [];
  }
};

// --- HELPER 2: AGGLO 2.0 (Brand Detection) ---
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
        material: "PET", // Default
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

// --- MAIN CONTROLLER ---
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

    // 2. Run ALL 3 Models in Parallel
    const [petResults, aggloResults, sam3Results] = await Promise.all([
        analyzeWithPetModel(imageFile),   // <--- Real SudoKuder/agglo call
        analyzeWithAgglo(imageFile),      // <--- Real Agglo 2.0 call
        analyzeWithSAM3(imageFile)        // <--- Real SAM3 call
    ]);

    // 3. Merge Results
    const finalDetections = [...petResults, ...aggloResults, ...sam3Results];

    // 4. Calculate Stats
    // Count: Prioritize SAM3 (Segmentation), then PetClassifier (Detection), then Agglo (Text)
    const bottleCount = Math.max(sam3Results.length, petResults.length, aggloResults.length);
    
    // Value Calculation:
    let estimatedValue = 0;
    
    if (petResults.length > 0) {
        // Precise calculation if we have material data
        petResults.forEach(b => {
            if (b.material === 'PET') {
                estimatedValue += (b.color === 'Clear' ? 6.0 : 4.0);
            } else {
                estimatedValue += 0.5; // Scrap
            }
        });
        // If detection counts differ, add generic value for extras
        if (bottleCount > petResults.length) {
             estimatedValue += (bottleCount - petResults.length) * 5.0;
        }
    } else {
        // Fallback
        estimatedValue = bottleCount * 5.0; 
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