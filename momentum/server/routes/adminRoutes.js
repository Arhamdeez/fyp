const express = require("express");
const { listUsers, updateUserStatus, deleteUser } = require("../controllers/adminController");
const { protect, adminOnly } = require("../middleware/authMiddleware");

const router = express.Router();

router.get("/users", protect, adminOnly, listUsers);
router.put("/users/:id/status", protect, adminOnly, updateUserStatus);
router.delete("/users/:id", protect, adminOnly, deleteUser);

module.exports = router;
