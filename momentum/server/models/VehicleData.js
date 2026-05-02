const mongoose = require("mongoose");

const vehicleDataSchema = new mongoose.Schema(
  {
    vehicle_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Vehicle",
      required: true
    },
    speed: { type: Number, required: true },
    rpm: { type: Number, required: true },
    fuel_consumption: { type: Number, default: 0 },
    fuel_level: { type: Number, min: 0, max: 100, default: 0 },
    engine_temp: { type: Number, default: 0 },
    engine_load: { type: Number, default: 0 },
    throttle_position: { type: Number, default: 0 },
    error_codes: [{ type: String }],
    timestamp: { type: Date, default: Date.now }
  },
  { timestamps: true }
);

vehicleDataSchema.index({ vehicle_id: 1, timestamp: -1 });

module.exports = mongoose.model("VehicleData", vehicleDataSchema);
