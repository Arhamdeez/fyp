import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import api from "../services/api";

const Register = () => {
  const navigate = useNavigate();
  const [form, setForm] = useState({
    name: "",
    email: "",
    password: "",
    confirmPassword: ""
  });
  const [error, setError] = useState("");

  const onSubmit = async (event) => {
    event.preventDefault();
    if (form.password !== form.confirmPassword) {
      setError("Passwords do not match");
      return;
    }

    try {
      await api.post("/auth/register", {
        name: form.name,
        email: form.email,
        password: form.password
      });
      navigate("/login");
    } catch (err) {
      setError(err?.response?.data?.message || "Unable to register");
    }
  };

  return (
    <div style={{ maxWidth: 420, margin: "80px auto" }}>
      <h1>Create Momentum Account</h1>
      <p>Start analyzing your driving behavior today.</p>
      <form onSubmit={onSubmit}>
        <input
          placeholder="Full Name"
          value={form.name}
          onChange={(e) => setForm((prev) => ({ ...prev, name: e.target.value }))}
          required
        />
        <input
          placeholder="Email"
          type="email"
          value={form.email}
          onChange={(e) => setForm((prev) => ({ ...prev, email: e.target.value }))}
          required
        />
        <input
          placeholder="Password"
          type="password"
          value={form.password}
          onChange={(e) => setForm((prev) => ({ ...prev, password: e.target.value }))}
          required
        />
        <input
          placeholder="Confirm Password"
          type="password"
          value={form.confirmPassword}
          onChange={(e) => setForm((prev) => ({ ...prev, confirmPassword: e.target.value }))}
          required
        />
        <button type="submit">Create Account</button>
      </form>
      {error ? <p style={{ color: "red" }}>{error}</p> : null}
      <p>
        Have an account? <Link to="/login">Login</Link>
      </p>
    </div>
  );
};

export default Register;
