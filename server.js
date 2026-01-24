// server.js
const express = require('express');
const connectDB = require('./config/db');
const cors = require('cors');
// const upload = require('./config/cloudinary'); // NOT NEEDED HERE (Handled in routes/scanRoutes)

// Imports
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const scanRoutes = require('./routes/scanRoutes'); // Import the router

// Note: You don't need to import controllers here anymore
// const { uploadScan, getAllScans } = require('./controllers/scanController'); 
// const authMiddleware = require('./middleware/auth'); // NOT NEEDED HERE (Handled in routes)

require('dotenv').config();
const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Connect DB
connectDB();

// --- HEALTH CHECK ---
app.get('/api/health', (req, res) => {
  const currentTime = new Date().toISOString();
  console.log(`✅ Health check received at: ${currentTime}`);
  res.status(200).json({ 
    status: 'active', 
    timestamp: currentTime,
    uptime: process.uptime() 
  });
});

// --- ROUTES ---

// 1. Auth (Public)
app.use('/api/auth', authRoutes);

// 2. User Profile (Protected inside the router)
app.use('/api/user', userRoutes);

// 3. Scanning (Protected inside the router)
// This single line handles both POST /api/scan and GET /api/scan/history
app.use('/api/scan', scanRoutes); 

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server started on port ${PORT}`));