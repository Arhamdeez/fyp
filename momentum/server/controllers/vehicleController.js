const Vehicle = require("../models/Vehicle");

const addVehicle = async (req, res) => {
  try {
    const payload = { ...req.body, user_id: req.user._id };
    const vehicle = await Vehicle.create(payload);
    return res.status(201).json(vehicle);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getVehicles = async (req, res) => {
  try {
    const vehicles = await Vehicle.find({ user_id: req.user._id }).sort({ createdAt: -1 });
    return res.json(vehicles);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getVehicleById = async (req, res) => {
  try {
    const vehicle = await Vehicle.findOne({ _id: req.params.id, user_id: req.user._id });
    if (!vehicle) return res.status(404).json({ message: "Vehicle not found" });
    return res.json(vehicle);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const updateVehicle = async (req, res) => {
  try {
    const vehicle = await Vehicle.findOneAndUpdate(
      { _id: req.params.id, user_id: req.user._id },
      req.body,
      { new: true }
    );
    if (!vehicle) return res.status(404).json({ message: "Vehicle not found" });
    return res.json(vehicle);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const deleteVehicle = async (req, res) => {
  try {
    const vehicle = await Vehicle.findOneAndDelete({ _id: req.params.id, user_id: req.user._id });
    if (!vehicle) return res.status(404).json({ message: "Vehicle not found" });
    return res.json({ message: "Vehicle deleted successfully" });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

module.exports = {
  addVehicle,
  getVehicles,
  getVehicleById,
  updateVehicle,
  deleteVehicle
};
