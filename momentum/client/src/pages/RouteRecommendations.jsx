import RouteCard from "../components/RouteCard";

const routes = [
  { name: "Fastest Route", distance: "12.2 km", eta: "19 min", traffic: "Moderate" },
  { name: "Scenic Route", distance: "14.8 km", eta: "24 min", traffic: "Low" }
];

const RouteRecommendations = () => (
  <div>
    <h2>Route Recommendations</h2>
    <p>Find optimal routes based on traffic and weather.</p>
    <input placeholder="Enter destination" />
    <button type="button">Find Route</button>
    <div style={{ marginTop: 16, display: "grid", gap: 12 }}>
      {routes.map((route) => (
        <RouteCard key={route.name} route={route} />
      ))}
    </div>
  </div>
);

export default RouteRecommendations;
