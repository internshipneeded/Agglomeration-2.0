const express = require('express');
const connectDB = require('./config/db');
const cors = require('cors');

// 1. Import Routes
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes'); // Ensure this file exists
const scanRoutes = require('./routes/scanRoutes'); // Ensure this file exists

require('dotenv').config();
const app = express();

// 2. Middleware
app.use(cors());
app.use(express.json());

// 3. Connect DB
connectDB();

// 4. Health Check (Keep this!)
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'active', timestamp: new Date().toISOString() });
});

// 5. Mount Routes
app.use('/api/auth', authRoutes);
app.use('/api/user', userRoutes);
app.use('/api/scan', scanRoutes); // This handles both POST / and GET /history

// 🛑 DELETED THE MANUAL app.post('/api/scan'...) LINES HERE 
// BECAUSE THEY ARE ALREADY INSIDE scanRoutes.js

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server started on port ${PORT}`));