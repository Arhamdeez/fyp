const StatCard = ({ label, value, trend }) => (
  <div
    style={{
      background: "white",
      borderRadius: 10,
      border: "1px solid #e2e8f0",
      padding: 12
    }}
  >
    <p style={{ margin: 0, color: "#64748b" }}>{label}</p>
    <h3 style={{ margin: "8px 0" }}>{value}</h3>
    {trend ? <p style={{ margin: 0, color: "#10b981" }}>{trend}</p> : null}
  </div>
);

export default StatCard;
