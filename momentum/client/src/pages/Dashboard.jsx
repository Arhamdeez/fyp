import { useState } from "react";
import StatCard from "../components/StatCard";

const Dashboard = () => {
  const [stats, setStats] = useState({
    score: "87/100",
    avgSpeed: "65 km/h",
    efficiency: "7.2 L/100km",
    distance: "245 km"
  });

  return (
    <div>
      <h2>Dashboard</h2>
      <p>Welcome back! Here is your driving overview.</p>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12 }}>
        <StatCard label="Driving Score" value={stats.score} trend="+4% this week" />
        <StatCard label="Average Speed" value={stats.avgSpeed} />
        <StatCard label="Fuel Efficiency" value={stats.efficiency} />
        <StatCard label="Trip Distance" value={stats.distance} />
      </div>
    </div>
  );
};

export default Dashboard;
