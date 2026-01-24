// services/aiService.js
const { Client } = require("@gradio/client");
const { File } = require('node:buffer'); 

// --- MODEL: SAM 3 (Segmentation) ---
const analyzeWithSAM3 = async (imageFile) => {
  try {
    console.log("🔹 Service: Connecting to SAM3 (akhaliq/sam3)...");
    const client = await Client.connect("akhaliq/sam3");
    
    console.log("🔹 Sending Image & Prompt 'bottle'...");
    const result = await client.predict("/segment", { 
        image: imageFile, 
        text: "bottle",      // 💡 CHANGE THIS if you want to detect other things
        threshold: 0.5,      // Detection sensitivity
        mask_threshold: 0.5  // Mask outline precision
    });

    console.log("✅ SAM3 Raw Output (Index 2):", JSON.stringify(result.data[2], null, 2));

    // PARSING LOGIC:
    // The relevant data is in Index [2] of the response array.
    // Structure: { image: "...", annotations: [ { image: "...", label: "bottle" }, ... ] }
    const segmentationResult = result.data[2];

    if (!segmentationResult || !segmentationResult.annotations) {
        console.warn("⚠️ No annotations found.");
        return [];
    }

    // Map the masks to your App's format
    return segmentationResult.annotations.map((item, index) => ({
        source: "SAM3",
        label: item.label || "bottle",
        brand: "Unknown",     // SAM3 finds shapes, not brands
        material: "PET",      // Default assumption
        confidence: 0.99,     // SAM3 is usually high confidence if it returns a mask
        boundingBox: [],      // SAM3 returns masks, not boxes
        maskUrl: item.image?.url || item.image // Save mask URL if available
    }));

  } catch (error) {
    console.error("❌ SAM3 Failed:", error.message);
    return [];
  }
};

module.exports = { analyzeWithSAM3 };