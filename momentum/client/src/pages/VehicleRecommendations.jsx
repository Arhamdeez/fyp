import VehicleCard from "../components/VehicleCard";

const vehicles = [
  { name: "Tesla Model 3 - 2024", score: 94, price: "$41,990" },
  { name: "Toyota Camry Hybrid - 2024", score: 91, price: "$30,000" },
  { name: "Honda Civic - 2024", score: 88, price: "$26,000" }
];

const VehicleRecommendations = () => (
  <div>
    <h2>Vehicle Recommendations</h2>
    <p>Vehicles matched to your driving behavior and commute patterns.</p>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12 }}>
      {vehicles.map((vehicle) => (
        <VehicleCard key={vehicle.name} vehicle={vehicle} />
      ))}
    </div>
  </div>
);

export default VehicleRecommendations;
