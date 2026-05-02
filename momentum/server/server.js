const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const dotenv = require("dotenv");
const connectDB = require("./config/db");

dotenv.config();
connectDB();

const app = express();

// In production set CORS_ORIGIN (comma-separated). In dev, allow LAN devices (phone browser / Flutter).
const isProd = process.env.NODE_ENV === "production";
const corsOrigins = (process.env.CORS_ORIGIN || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);
app.use(
  cors({
    origin: isProd ? corsOrigins.length ? corsOrigins : false : true,
    credentials: true
  })
);
app.use(express.json());
app.use(morgan("dev"));

app.get("/health", (_req, res) => res.json({ status: "ok", service: "momentum-server" }));

app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/vehicles", require("./routes/vehicleRoutes"));
app.use("/api/vehicle-data", require("./routes/telemetryRoutes"));
app.use("/api/trips", require("./routes/tripRoutes"));
app.use("/api/analysis", require("./routes/analysisRoutes"));
app.use("/api/recommendations", require("./routes/recommendationRoutes"));
app.use("/api/admin", require("./routes/adminRoutes"));

const port = Number(process.env.PORT || 5000);
const host = process.env.HOST || "0.0.0.0";

const server = app.listen(port, host, () => {
  console.log(`Momentum server listening on http://${host}:${port} (reachable from other devices on your LAN)`);
});

server.on("error", (err) => {
  if (err.code === "EADDRINUSE") {
    console.error(`
Port ${port} is already in use (EADDRINUSE).

Usually another copy of this server is still running (old nodemon / node).

Fix:
  1) Find it:  lsof -iTCP:${port} -sTCP:LISTEN
  2) Stop it:  kill <PID>
  3) Or use another port in server/.env:  PORT=5002

Then run: npm run dev
`);
  } else {
    console.error("Server listen error:", err);
  }
  process.exit(1);
});
