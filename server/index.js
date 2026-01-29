import dotenv from "dotenv";
import express from "express";
import mongoose from "mongoose";

dotenv.config();
const app = express();
app.use(express.json());

// MongoDB Connection
const _dbURI = process.env.MONGO_DB_URI;
mongoose.connect(_dbURI).then(() => {
  console.log("Connected to Mongo DB");
});

// Local Server
app.listen(process.env.PORT, () =>
  console.log(`Listening to port ${process.env.PORT}`)
);