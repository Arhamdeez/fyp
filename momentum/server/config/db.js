const mongoose = require("mongoose");

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const connectDB = async () => {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    console.error("MONGODB_URI is not set in server/.env");
    process.exit(1);
  }

  const maxAttempts = Number(process.env.MONGO_CONNECT_ATTEMPTS || 30);
  const delayMs = Number(process.env.MONGO_CONNECT_RETRY_MS || 2000);

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const conn = await mongoose.connect(uri);
      console.log(`MongoDB connected: ${conn.connection.host}`);
      return;
    } catch (error) {
      console.error(
        `[${attempt}/${maxAttempts}] MongoDB connection failed: ${error.message}`
      );
      if (attempt === maxAttempts) {
        console.error(`
MongoDB is not reachable at ${uri.split("@").pop() || uri}.

Fix one of these:
  1) Start Docker Desktop, then from the momentum folder run:
       docker compose up -d
  2) Install and start MongoDB locally (e.g. brew install mongodb-community && brew services start mongodb-community)
  3) Use MongoDB Atlas: set MONGODB_URI in server/.env to your Atlas connection string
`);
        process.exit(1);
      }
      await sleep(delayMs);
    }
  }
};

module.exports = connectDB;
