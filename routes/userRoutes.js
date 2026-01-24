// routes/userRoutes.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth'); // Protect these routes!
const upload = require('../config/cloudinary'); // Reuse your upload config
const { getProfile, updateProfile } = require('../controllers/userController');

// GET current user info
router.get('/me', auth, getProfile);

// PUT update profile (allows uploading a file named 'profilePic')
router.put('/update', auth, upload.single('profilePic'), updateProfile);

module.exports = router;