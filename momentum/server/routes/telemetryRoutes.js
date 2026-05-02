const express = require("express");
const {
  submitReading,
  getReadings,
  getLatestReading,
  simulateOBDData
} = require("../controllers/telemetryController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/", protect, submitReading);
router.post("/simulate", protect, simulateOBDData);
router.get("/:vehicleId", protect, getReadings);
router.get("/:vehicleId/latest", protect, getLatestReading);

module.exports = router;
