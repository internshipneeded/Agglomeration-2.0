const express = require('express');
const router = express.Router();
const upload = require('../config/cloudinary'); // Imports your Multer/Cloudinary config
const auth = require('../middleware/auth');     // Imports your JWT Security Guard
const { uploadScan, getAllScans } = require('../controllers/scanController');

// @route   POST /api/scan
// @desc    Upload an image, run AI analysis, and save results
// @access  Private (Requires Token)
router.post('/', auth, upload.single('image'), uploadScan);

// @route   GET /api/scan/history
// @desc    Get all previous scans for the logged-in user
// @access  Private (Requires Token)
router.get('/history', auth, getAllScans);

module.exports = router;