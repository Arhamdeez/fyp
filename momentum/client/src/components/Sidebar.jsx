import { Link, useLocation } from "react-router-dom";

const navItems = [
  { to: "/dashboard", label: "Dashboard" },
  { to: "/vehicle-data", label: "Vehicle Data" },
  { to: "/driving-analysis", label: "Driving Analysis" },
  { to: "/route-recommendations", label: "Route Recommendations" },
  { to: "/vehicle-recommendations", label: "Vehicle Recommendations" },
  { to: "/settings", label: "Settings" }
];

const Sidebar = ({ variant = "desktop", isOpen = false, onClose }) => {
  const location = useLocation();
  const body = (
    <aside
      className={variant === "mobile" ? "sidebarDrawer" : undefined}
      style={
        variant === "desktop"
          ? { width: 240, borderRight: "1px solid #e2e8f0", padding: 16, background: "white" }
          : { padding: 16 }
      }
    >
      <h2>Momentum</h2>
      <p style={{ color: "#64748b" }}>Smart Insights</p>
      <nav style={{ display: "grid", gap: 8, marginTop: 24 }}>
        {navItems.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            onClick={() => onClose?.()}
            style={{
              padding: "8px 12px",
              borderRadius: 8,
              textDecoration: "none",
              color: location.pathname === item.to ? "white" : "#1e293b",
              background: location.pathname === item.to ? "#2563eb" : "transparent"
            }}
          >
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  );

  if (variant !== "mobile") return body;
  if (!isOpen) return null;

  return (
    <>
      <div className="sidebarOverlay" onClick={() => onClose?.()} role="presentation" />
      {body}
    </>
  );
};

export default Sidebar;
