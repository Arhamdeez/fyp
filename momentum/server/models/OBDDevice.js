const mongoose = require("mongoose");

const obdDeviceSchema = new mongoose.Schema(
  {
    vehicle_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Vehicle",
      required: true
    },
    connection_status: {
      type: String,
      enum: ["Connected", "Disconnected"],
      default: "Disconnected"
    }
  },
  { timestamps: true }
);

module.exports = mongoose.model("OBDDevice", obdDeviceSchema);
