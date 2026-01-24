// controllers/scanController.js
const Scan = require('../models/Scan');
const fs = require("fs");
const path = require("path");
const os = require("os");
const { Client } = require("@gradio/client");
const fetch = (...args) =>
  import("node-fetch").then(({ default: fetch }) => fetch(...args));

const analyzeImageWithGradio = async (imageUrl) => {
  let tempFilePath;

  try {
    console.log("1. Connecting to Gradio Model...");
    const client = await Client.connect("Arnavtr1/Agglo_2.0", {
      timeout: 120000,
    });

    console.log("2. Downloading image...");
    const response = await fetch(imageUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch image: ${response.status}`);
    }

    const buffer = Buffer.from(await response.arrayBuffer());

    tempFilePath = path.join(os.tmpdir(), `scan_${Date.now()}.jpg`);
    fs.writeFileSync(tempFilePath, buffer);

    console.log("3. Sending image file to AI...");
    const result = await client.predict("/infer", {
      image: { path: tempFilePath },
    });

    console.log("✅ Raw AI Response:", result.data);

    const rawText = result.data?.[0] || "";
    if (!rawText) return [];

    return rawText
      .split(/,|\n/)
      .map(s => s.trim())
      .filter(Boolean)
      .map(brand => ({
        label: "bottle",
        brand,
        confidence: 1.0,
        color: "Unknown",
        material: "PET",
        boundingBox: [],
      }));

  } catch (error) {
    console.error("❌ AI Inference Failed:", error);
    return [];
  } finally {
    if (tempFilePath && fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
    }
  }
};

module.exports = { analyzeImageWithGradio };
