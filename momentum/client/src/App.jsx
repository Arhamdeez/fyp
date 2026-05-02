import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import Sidebar from "./components/Sidebar";
import Navbar from "./components/Navbar";
import Dashboard from "./pages/Dashboard";
import VehicleData from "./pages/VehicleData";
import DrivingAnalysis from "./pages/DrivingAnalysis";
import RouteRecommendations from "./pages/RouteRecommendations";
import VehicleRecommendations from "./pages/VehicleRecommendations";
import Settings from "./pages/Settings";

const PageShell = ({ title, children }) => (
  <div style={{ display: "flex", minHeight: "100vh", background: "#f8fafc" }}>
    <Sidebar />
    <main style={{ flex: 1, padding: 20 }}>
      <Navbar title={title} />
      {children}
    </main>
  </div>
);

const App = () => (
  <BrowserRouter>
    <Routes>
      <Route
        path="/dashboard"
        element={
          <PageShell title="Dashboard">
            <Dashboard />
          </PageShell>
        }
      />
      <Route
        path="/vehicle-data"
        element={
          <PageShell title="Vehicle Data">
            <VehicleData />
          </PageShell>
        }
      />
      <Route
        path="/driving-analysis"
        element={
          <PageShell title="Driving Analysis">
            <DrivingAnalysis />
          </PageShell>
        }
      />
      <Route
        path="/route-recommendations"
        element={
          <PageShell title="Route Recommendations">
            <RouteRecommendations />
          </PageShell>
        }
      />
      <Route
        path="/vehicle-recommendations"
        element={
          <PageShell title="Vehicle Recommendations">
            <VehicleRecommendations />
          </PageShell>
        }
      />
      <Route
        path="/settings"
        element={
          <PageShell title="Settings">
            <Settings />
          </PageShell>
        }
      />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  </BrowserRouter>
);

export default App;
