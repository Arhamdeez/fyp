const Recommendation = require("../models/Recommendation");

const getVehicleRecommendations = async (req, res) => {
  const recommendations = await Recommendation.find({
    user_id: req.user._id,
    recommendation_type: "Vehicle"
  }).sort({ date_generated: -1 });
  return res.json(recommendations);
};

const getRouteRecommendations = async (req, res) => {
  const recommendations = await Recommendation.find({
    user_id: req.user._id,
    recommendation_type: "Route"
  }).sort({ date_generated: -1 });
  return res.json(recommendations);
};

const getMaintenanceRecommendations = async (req, res) => {
  const recommendations = await Recommendation.find({
    user_id: req.user._id,
    vehicle_id: req.params.vehicleId,
    recommendation_type: "Maintenance"
  }).sort({ date_generated: -1 });
  return res.json(recommendations);
};

module.exports = {
  getVehicleRecommendations,
  getRouteRecommendations,
  getMaintenanceRecommendations
};
