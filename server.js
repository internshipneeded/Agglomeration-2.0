// server.js (Updated)
const express = require('express');
const connectDB = require('./config/db');
const cors = require('cors');
const upload = require('./config/cloudinary');

// Imports
const authRoutes = require('./routes/authRoutes');
const { uploadScan, getAllScans } = require('./controllers/scanController');
const authMiddleware = require('./middleware/auth'); // Import the Guard

require('dotenv').config();
const app = express();

// Middleware
app.use(cors());
app.use(express.json()); // Essential for parsing JSON bodies (login/register)

// Connect DB
connectDB();

// --- PUBLIC ROUTES ---
app.use('/api/auth', authRoutes); // Login & Register are public

// --- PROTECTED ROUTES (Require Token) ---
// We add 'authMiddleware' before the controller
app.post('/api/scan', authMiddleware, upload.single('image'), uploadScan);
app.get('/api/history', authMiddleware, getAllScans);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server started on port ${PORT}`));