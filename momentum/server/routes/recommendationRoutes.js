const express = require("express");
const {
  getVehicleRecommendations,
  getRouteRecommendations,
  getMaintenanceRecommendations
} = require("../controllers/recommendationController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/vehicle", protect, getVehicleRecommendations);
router.get("/route", protect, getRouteRecommendations);
router.get("/maintenance/:vehicleId", protect, getMaintenanceRecommendations);

module.exports = router;
