const DrivingAnalysis = require("../models/DrivingAnalysis");
const VehicleData = require("../models/VehicleData");
const {
  detectHarshBraking,
  detectRapidAcceleration,
  detectOverspeeding,
  calculateDrivingScore
} = require("../algorithms/drivingBehavior");

const generateAnalysis = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const readings = await VehicleData.find({ vehicle_id: vehicleId })
      .sort({ timestamp: 1 })
      .limit(200);

    if (readings.length < 2) {
      return res.status(400).json({ message: "Not enough telemetry to generate analysis" });
    }

    const speedReadings = readings.map((r) => r.speed);
    const timestamps = readings.map((r) => r.timestamp);

    const harsh = detectHarshBraking(speedReadings, timestamps);
    const accel = detectRapidAcceleration(speedReadings, timestamps);
    const overspeed = detectOverspeeding(speedReadings);
    const { score, classification } = calculateDrivingScore(harsh, accel, overspeed);

    const report = await DrivingAnalysis.create({
      vehicle_id: vehicleId,
      driving_score: score,
      harsh_braking_events: harsh,
      acceleration_events: accel,
      overspeeding_events: overspeed,
      report_date: new Date()
    });

    return res.status(201).json({ ...report.toObject(), classification });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getAnalysisHistory = async (req, res) => {
  try {
    const reports = await DrivingAnalysis.find({ vehicle_id: req.params.vehicleId }).sort({ report_date: -1 });
    return res.json(reports);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getAnalysisById = async (req, res) => {
  try {
    const report = await DrivingAnalysis.findById(req.params.analysisId);
    if (!report) return res.status(404).json({ message: "Analysis not found" });
    return res.json(report);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

module.exports = { generateAnalysis, getAnalysisHistory, getAnalysisById };
