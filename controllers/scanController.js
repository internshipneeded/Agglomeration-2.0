// controllers/scanController.js
const Scan = require('../models/Scan');
const { Client } = require("@gradio/client");
const { File } = require("undici"); // ✅ REQUIRED
const fetch = (...args) =>
  import('node-fetch').then(({ default: fetch }) => fetch(...args));

const analyzeImageWithGradio = async (imageUrl) => {
  try {
    console.log("1. Connecting to Gradio Model: Arnavtr1/Agglo_2.0...");
    const client = await Client.connect("Arnavtr1/Agglo_2.0", {
      timeout: 120000,
    });

    console.log("2. Fetching image from Cloudinary...");
    const response = await fetch(imageUrl);

    // ✅ Convert image → File (NOT Blob)
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const imageFile = new File([buffer], "scan.jpg", {
      type: "image/jpeg",
    });

    console.log("3. Sending image to AI (Endpoint: /infer)...");
    const result = await client.predict("/infer", {
      image: imageFile,
    });

    console.log("✅ Raw AI Response:", result.data);

    // --- PARSING LOGIC ---
    const rawText = result.data?.[0] || "";
    if (!rawText) return [];

    const brands = rawText
      .split(/,|\n/)
      .map(s => s.trim())
      .filter(Boolean);

    return brands.map(brandName => ({
      label: "bottle",
      brand: brandName,
      confidence: 1.0,
      color: "Unknown",
      material: "PET",
      boundingBox: [],
    }));

  } catch (error) {
    console.error("❌ AI Inference Failed:", error);
    return [{ label: "Error", brand: "Unknown", confidence: 0 }];
  }
};

exports.uploadScan = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ msg: 'No file uploaded' });
    }

    const imageUrl = req.file.path;

    // 1. AI Inference
    const aiResults = await analyzeImageWithGradio(imageUrl);

    // 2. Business Logic
    const bottleCount = aiResults.length;
    const estimatedValue = bottleCount * 5;

    // 3. Save to DB
    const newScan = new Scan({
      imageUrl,
      batchId: "batch_" + Date.now(),
      totalBottles: bottleCount,
      totalValue: estimatedValue,
      detections: aiResults,
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
