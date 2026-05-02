const Navbar = ({ title }) => {
  return (
    <header
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        marginBottom: 16
      }}
    >
      <h1 style={{ margin: 0 }}>{title}</h1>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <span>Driver</span>
      </div>
    </header>
  );
};

export default Navbar;
