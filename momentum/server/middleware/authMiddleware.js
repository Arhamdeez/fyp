const jwt = require("jsonwebtoken");
const User = require("../models/User");

/** When login is disabled in the mobile/web client, use DEV_BYPASS_AUTH=true to attach a demo user. */
const loadOrCreateDevUser = async () => {
  const email = process.env.DEV_USER_EMAIL || "demo@momentum.local";
  let user = await User.findOne({ email }).select("-password");
  if (user) return user;

  try {
    await User.create({
      name: "Demo Driver",
      email,
      password: process.env.DEV_USER_PASSWORD || "demo123456",
      role: "Driver"
    });
  } catch (e) {
    if (e.code !== 11000) throw e;
  }
  return User.findOne({ email }).select("-password");
};

const protect = async (req, res, next) => {
  if (process.env.DEV_BYPASS_AUTH === "true") {
    try {
      req.user = await loadOrCreateDevUser();
      if (!req.user) {
        return res.status(500).json({ message: "Dev bypass: could not load demo user" });
      }
      return next();
    } catch (error) {
      return res.status(500).json({ message: error.message });
    }
  }

  const authHeader = req.headers.authorization || "";

  if (!authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "Unauthorized: token missing" });
  }

  try {
    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id).select("-password");

    if (!req.user) {
      return res.status(401).json({ message: "Unauthorized: user not found" });
    }

    return next();
  } catch (error) {
    return res.status(401).json({ message: "Unauthorized: invalid token" });
  }
};

const adminOnly = (req, res, next) => {
  if (req.user?.role !== "Admin") {
    return res.status(403).json({ message: "Forbidden: admin only route" });
  }
  return next();
};

module.exports = { protect, adminOnly };
