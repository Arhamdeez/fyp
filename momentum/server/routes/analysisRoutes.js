const express = require("express");
const {
  generateAnalysis,
  getAnalysisHistory,
  getAnalysisById
} = require("../controllers/analysisController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/generate/:vehicleId", protect, generateAnalysis);
router.get("/vehicle/:vehicleId", protect, getAnalysisHistory);
router.get("/:analysisId", protect, getAnalysisById);

module.exports = router;
