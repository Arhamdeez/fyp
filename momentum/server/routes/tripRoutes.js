const express = require("express");
const { createTrip, getTripHistory, getTripDetail } = require("../controllers/tripController");
const { protect } = require("../middleware/authMiddleware");

const router = express.Router();

router.post("/", protect, createTrip);
router.get("/:vehicleId", protect, getTripHistory);
router.get("/:tripId/detail", protect, getTripDetail);

module.exports = router;
