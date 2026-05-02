const mongoose = require("mongoose");

const recommendationSchema = new mongoose.Schema(
  {
    user_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true
    },
    vehicle_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Vehicle"
    },
    recommendation_type: {
      type: String,
      enum: ["Vehicle", "Route", "Maintenance"],
      required: true
    },
    issue_type: { type: String, default: "" },
    suggested_action: { type: String, default: "" },
    description: { type: String, default: "" },
    severity: {
      type: String,
      enum: ["High", "Medium", "Low"],
      default: "Low"
    },
    date_generated: { type: Date, default: Date.now }
  },
  { timestamps: true }
);

module.exports = mongoose.model("Recommendation", recommendationSchema);
