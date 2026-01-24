// config/db.js
const mongoose = require('mongoose');
require('dotenv').config();

const connectDB = async () => {
  try {
    // 1. Connect to your specific Atlas Cluster
    const conn = await mongoose.connect(process.env.MONGO_URI, {
        // Mongoose 6+ defaults these to true, but good to be explicit if using older versions
        // useNewUrlParser: true, 
        // useUnifiedTopology: true,
    });

    console.log(`MongoDB Connected: ${conn.connection.host}`);
    console.log(`Connected to Database: ${conn.connection.name}`);
    
  } catch (err) {
    console.error(`Error: ${err.message}`);
    // If connection fails, stop the server
    process.exit(1);
  }
};

module.exports = connectDB;