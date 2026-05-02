const mongoose = require("mongoose");

const drivingAnalysisSchema = new mongoose.Schema(
  {
    vehicle_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Vehicle",
      required: true
    },
    trip_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Trip"
    },
    driving_score: { type: Number, min: 0, max: 100, required: true },
    harsh_braking_events: { type: Number, default: 0 },
    acceleration_events: { type: Number, default: 0 },
    overspeeding_events: { type: Number, default: 0 },
    report_date: { type: Date, default: Date.now }
  },
  { timestamps: true }
);

module.exports = mongoose.model("DrivingAnalysis", drivingAnalysisSchema);
