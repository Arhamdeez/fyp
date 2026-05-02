const RouteCard = ({ route }) => (
  <div style={{ border: "1px solid #e2e8f0", borderRadius: 10, padding: 12, background: "white" }}>
    <h3>{route?.name || "Route Option"}</h3>
    <p>
      Distance: {route?.distance || "-"} | ETA: {route?.eta || "-"} | Traffic: {route?.traffic || "-"}
    </p>
    <button type="button">Select Route</button>
  </div>
);

export default RouteCard;
