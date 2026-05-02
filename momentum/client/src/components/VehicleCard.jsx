const VehicleCard = ({ vehicle }) => (
  <div style={{ border: "1px solid #e2e8f0", borderRadius: 10, padding: 12, background: "white" }}>
    <h3>{vehicle?.name || "Vehicle Name"}</h3>
    <p>Match Score: {vehicle?.score ?? 0}</p>
    <p>Price: {vehicle?.price || "N/A"}</p>
    <button type="button">View Details</button>
  </div>
);

export default VehicleCard;
