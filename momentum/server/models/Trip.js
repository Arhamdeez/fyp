const mongoose = require("mongoose");

const tripSchema = new mongoose.Schema(
  {
    vehicle_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Vehicle",
      required: true
    },
    start_time: { type: Date, required: true },
    end_time: { type: Date },
    distance: { type: Number, default: 0 },
    average_speed: { type: Number, default: 0 },
    route_coordinates: [
      {
        lat: Number,
        lng: Number
      }
    ]
  },
  { timestamps: true }
);

module.exports = mongoose.model("Trip", tripSchema);
