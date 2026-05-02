const Trip = require("../models/Trip");

const createTrip = async (req, res) => {
  try {
    const trip = await Trip.create(req.body);
    return res.status(201).json(trip);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getTripHistory = async (req, res) => {
  try {
    const trips = await Trip.find({ vehicle_id: req.params.vehicleId }).sort({ start_time: -1 });
    return res.json(trips);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

const getTripDetail = async (req, res) => {
  try {
    const trip = await Trip.findById(req.params.tripId);
    if (!trip) return res.status(404).json({ message: "Trip not found" });
    return res.json(trip);
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

module.exports = { createTrip, getTripHistory, getTripDetail };
