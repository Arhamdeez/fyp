import { useEffect, useMemo, useState } from "react";
import AlertBadge from "../components/AlertBadge";

const VehicleData = () => {
  const [isCollecting, setIsCollecting] = useState(true);
  const [lastUpdatedAt, setLastUpdatedAt] = useState(new Date());
  const [metrics, setMetrics] = useState(() => ({
    speed: 0,
    rpm: 0,
    fuel: 63,
    temp: 85
  }));

  useEffect(() => {
    if (!isCollecting) return;
    const interval = setInterval(() => {
      setMetrics((prev) => {
        // Mock "live" updates so you can verify on phone UI immediately.
        // Replace later with real ELM327/phone ingestion or backend polling.
        const nextSpeed = Math.max(0, Math.min(140, Math.round(prev.speed + (Math.random() * 18 - 7))));
        const nextRpm = Math.max(700, Math.min(4500, Math.round(800 + nextSpeed * 25 + Math.random() * 500)));
        const nextTemp = Math.max(60, Math.min(115, Math.round(prev.temp + (Math.random() * 4 - 1))));
        const nextFuel = Math.max(0, Math.min(100, Number((prev.fuel - Math.random() * 0.05).toFixed(2))));
        return { speed: nextSpeed, rpm: nextRpm, temp: nextTemp, fuel: nextFuel };
      });
      setLastUpdatedAt(new Date());
    }, 2000);
    return () => clearInterval(interval);
  }, [isCollecting]);

  const status = useMemo(() => {
    if (!isCollecting) return { severity: "Medium", text: "Paused" };
    return { severity: "Low", text: "Collecting data" };
  }, [isCollecting]);

  return (
    <div>
      <h2>Vehicle Diagnostics</h2>
      <p>Real-time vehicle data from OBD-II scanner.</p>
      <div className="pillRow" style={{ marginTop: 8 }}>
        <span className="liveDot" style={{ opacity: isCollecting ? 1 : 0.25 }} />
        <AlertBadge severity={status.severity} text={status.text} />
        <AlertBadge severity="Low" text="Vehicle Connected" />
        <span style={{ color: "#64748b", fontSize: 12 }}>
          Last update: {lastUpdatedAt.toLocaleTimeString()}
        </span>
      </div>

      <div style={{ marginTop: 12, maxWidth: 520 }}>
        <button type="button" onClick={() => setIsCollecting((v) => !v)}>
          {isCollecting ? "Pause collection" : "Resume collection"}
        </button>
      </div>

      <div className="grid4" style={{ marginTop: 12 }}>
        <div className="card">
          <div style={{ color: "#64748b" }}>Speed</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{metrics.speed} km/h</div>
        </div>
        <div className="card">
          <div style={{ color: "#64748b" }}>Engine RPM</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{metrics.rpm}</div>
        </div>
        <div className="card">
          <div style={{ color: "#64748b" }}>Fuel Level</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{metrics.fuel}%</div>
        </div>
        <div className="card">
          <div style={{ color: "#64748b" }}>Engine Temp</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{metrics.temp}°C</div>
        </div>
      </div>
    </div>
  );
};

export default VehicleData;
