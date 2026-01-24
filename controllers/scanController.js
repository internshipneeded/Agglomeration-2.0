const Scan = require('../models/Scan');

// SIMULATED AI ENGINE
// Later, you replace this function with a call to a Python Service
const mockAnalyzeImage = async (imageUrl) => {
  // Simulating 1 second processing time
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  return [
    { label: "bottle", brand: "Bisleri", confidence: 0.98, color: "Clear", material: "PET", boundingBox: [50, 100, 200, 400] },
    { label: "bottle", brand: "Coke", confidence: 0.92, color: "Brown", material: "PET", boundingBox: [300, 120, 180, 390] },
    { label: "contaminant", brand: "Unknown", confidence: 0.85, color: "White", material: "HDPE", boundingBox: [600, 200, 100, 150] }
  ];
};

exports.uploadScan = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ msg: 'No file uploaded' });
    }

    // 1. Image is already in Cloudinary (thanks to Middleware)
    const imageUrl = req.file.path; 

    // 2. Run (Mock) AI
    const aiResults = await mockAnalyzeImage(imageUrl);

    // 3. Calculate Business Logic
    let bottleCount = 0;
    let estimatedValue = 0;

    aiResults.forEach(item => {
      if (item.label === 'bottle') {
        bottleCount++;
        // Logic: Clear PET is 5rs, others 2rs
        estimatedValue += (item.color === 'Clear') ? 5.0 : 2.0;
      }
    });

    // 4. Save to MongoDB
    const newScan = new Scan({
      imageUrl,
      totalBottles: bottleCount,
      totalValue: estimatedValue,
      detections: aiResults
    });

    await newScan.save();

    // 5. Respond to App
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