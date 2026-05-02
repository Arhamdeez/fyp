import { useState } from "react";
import AlertBadge from "../components/AlertBadge";

const VehicleData = () => {
  const [metrics] = useState({
    speed: 69,
    rpm: 2513,
    fuel: 63,
    temp: 95
  });

  return (
    <div>
      <h2>Vehicle Diagnostics</h2>
      <p>Real-time vehicle data from OBD-II scanner.</p>
      <AlertBadge severity="Low" text="Vehicle Connected" />
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginTop: 12 }}>
        <div>Speed: {metrics.speed} km/h</div>
        <div>Engine RPM: {metrics.rpm}</div>
        <div>Fuel Level: {metrics.fuel}%</div>
        <div>Engine Temp: {metrics.temp} C</div>
      </div>
    </div>
  );
};

export default VehicleData;
