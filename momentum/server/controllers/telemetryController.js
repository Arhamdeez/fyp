const VehicleData = require("../models/VehicleData");
const Vehicle = require("../models/Vehicle");
const OBDDevice = require("../models/OBDDevice");
const { decodeErrorCodes, generateMaintenanceRecommendations } = require("../algorithms/vehicleHealth");

const submitReading = async (req, res) => {
  try {
    const { vehicle_id } = req.body;
    const vehicle = await Vehicle.findOne({ _id: vehicle_id, user_id: req.user._id });
    if (!vehicle) return res.status(404).json({ message: "Vehicle not found" });

    const reading = await VehicleData.create(req.body);
    await OBDDevice.findOneAndUpdate(
      { vehicle_id },
      { connection_status: "Connected" },
      { upsert: true, new: true }
    );

    const decoded = decodeErrorCodes(reading.error_codes || []);
    const recommendations = generateMaintenanceRecommendations(decoded);

    return res.status(201).json({ reading, diagnostic_alerts: recommendations });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getReadings = async (req, res) => {
  try {
    const { vehicleId } = req.params;
    const limit = Number(req.query.limit || 50);
    const page = Number(req.query.page || 1);
    const skip = (page - 1) * limit;

    const readings = await VehicleData.find({ vehicle_id: vehicleId })
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(limit);

    return res.json({ page, limit, data: readings });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getLatestReading = async (req, res) => {
  try {
    const reading = await VehicleData.findOne({ vehicle_id: req.params.vehicleId }).sort({ timestamp: -1 });
    if (!reading) return res.status(404).json({ message: "No data found for this vehicle" });
    return res.json(reading);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const simulateOBDData = async (req, res) => {
  try {
    const { vehicle_id } = req.body;
    const sample = {
      vehicle_id,
      speed: Math.floor(Math.random() * 121),
      rpm: Math.floor(800 + Math.random() * 3200),
      fuel_consumption: Number((4 + Math.random() * 10).toFixed(2)),
      fuel_level: Number((20 + Math.random() * 80).toFixed(2)),
      engine_temp: Number((70 + Math.random() * 40).toFixed(2)),
      engine_load: Number((15 + Math.random() * 70).toFixed(2)),
      throttle_position: Number((5 + Math.random() * 95).toFixed(2)),
      error_codes: Math.random() > 0.75 ? ["P0171"] : [],
      timestamp: new Date()
    };
    const reading = await VehicleData.create(sample);
    return res.status(201).json(reading);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

module.exports = { submitReading, getReadings, getLatestReading, simulateOBDData };
