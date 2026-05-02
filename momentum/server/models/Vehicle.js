const mongoose = require("mongoose");

const vehicleSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true
    },
    vehicle_model: { type: String, required: true, trim: true },
    vehicle_type: { type: String, required: true, trim: true },
    year: { type: Number, required: true },
    vin: { type: String, required: true, trim: true, unique: true },
    make: { type: String, trim: true },
    owner: { type: String, trim: true }
  },
  { timestamps: true }
);

module.exports = mongoose.model("Vehicle", vehicleSchema);
