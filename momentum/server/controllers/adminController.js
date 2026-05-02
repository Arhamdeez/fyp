const User = require("../models/User");

const listUsers = async (_req, res) => {
  const users = await User.find().select("-password").sort({ createdAt: -1 });
  return res.json(users);
};

const updateUserStatus = async (req, res) => {
  const { role } = req.body;
  const user = await User.findByIdAndUpdate(req.params.id, { role }, { new: true }).select("-password");
  if (!user) return res.status(404).json({ message: "User not found" });
  return res.json(user);
};

const deleteUser = async (req, res) => {
  const deleted = await User.findByIdAndDelete(req.params.id);
  if (!deleted) return res.status(404).json({ message: "User not found" });
  return res.json({ message: "User deleted successfully" });
};

module.exports = { listUsers, updateUserStatus, deleteUser };
