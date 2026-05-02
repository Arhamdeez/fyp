const colorMap = {
  High: "#ef4444",
  Medium: "#f59e0b",
  Low: "#10b981"
};

const AlertBadge = ({ severity = "Low", text }) => (
  <span
    style={{
      background: colorMap[severity] || colorMap.Low,
      color: "white",
      borderRadius: 999,
      padding: "2px 8px",
      fontSize: 12
    }}
  >
    {text || severity}
  </span>
);

export default AlertBadge;
