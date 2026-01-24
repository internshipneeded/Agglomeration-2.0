// controllers/userController.js
const User = require('../models/User');

// Get User Profile
exports.getProfile = async (req, res) => {
  try {
    // req.user.userId comes from the auth middleware
    const user = await User.findById(req.user.userId).select('-password');
    res.json(user);
  } catch (err) {
    res.status(500).send('Server Error');
  }
};

// Update Profile (Image + Name)
exports.updateProfile = async (req, res) => {
  try {
    const { name } = req.body;
    let profilePicUrl;

    // If an image was uploaded, get the URL from Cloudinary
    if (req.file) {
      profilePicUrl = req.file.path; // Cloudinary automatically puts the URL here
    }

    // Build the update object
    let updateFields = {};
    if (name) updateFields.name = name;
    if (profilePicUrl) updateFields.profilePic = profilePicUrl;

    // Update in MongoDB
    const user = await User.findByIdAndUpdate(
      req.user.userId,
      { $set: updateFields },
      { new: true } // Return the updated document
    ).select('-password');

    res.json(user);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
};