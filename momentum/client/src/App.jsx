import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { useEffect, useState } from "react";
import Sidebar from "./components/Sidebar";
import Navbar from "./components/Navbar";
import Dashboard from "./pages/Dashboard";
import VehicleData from "./pages/VehicleData";
import DrivingAnalysis from "./pages/DrivingAnalysis";
import RouteRecommendations from "./pages/RouteRecommendations";
import VehicleRecommendations from "./pages/VehicleRecommendations";
import Settings from "./pages/Settings";

const PageShell = ({ title, children }) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(() => window.matchMedia?.("(max-width: 900px)")?.matches ?? false);

  useEffect(() => {
    const mq = window.matchMedia?.("(max-width: 900px)");
    if (!mq) return;
    const handler = () => setIsMobile(mq.matches);
    handler();
    mq.addEventListener?.("change", handler);
    return () => mq.removeEventListener?.("change", handler);
  }, []);

  return (
    <div className="appShell">
      {!isMobile ? <Sidebar variant="desktop" /> : null}
      <Sidebar variant="mobile" isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <main className="mainContent">
        <div className="topBarRow">
          {isMobile ? (
            <button className="iconButton" type="button" onClick={() => setSidebarOpen(true)}>
              Menu
            </button>
          ) : (
            <span />
          )}
          <div style={{ flex: 1 }}>
            <Navbar title={title} />
          </div>
        </div>
        {children}
      </main>
    </div>
  );
};

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
