// middleware/auth.js
const jwt = require('jsonwebtoken');

module.exports = function (req, res, next) {
  // Get token from header (Format: "Bearer <token>")
  const token = req.header('Authorization');

  // Check if no token
  if (!token) {
    return res.status(401).json({ msg: 'No token, authorization denied' });
  }

  try {
    // Remove 'Bearer ' prefix if present
    const cleanToken = token.replace('Bearer ', '');
    
    // Verify token
    const decoded = jwt.verify(cleanToken, process.env.JWT_SECRET);
    
    // Add user from payload to request object
    req.user = decoded;
    next(); // Move to the next middleware/route
  } catch (err) {
    res.status(401).json({ msg: 'Token is not valid' });
  }
};