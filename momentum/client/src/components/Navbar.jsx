const Navbar = ({ title }) => {
  return (
    <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
      <h1 style={{ margin: 0, fontSize: 20 }}>{title}</h1>
      <div style={{ display: "flex", alignItems: "center", gap: 12, color: "#64748b" }}>
        <span>Driver</span>
      </div>
    </header>
  );
};

export default Navbar;
