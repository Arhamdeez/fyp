import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

const Login = () => {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [form, setForm] = useState({ email: "", password: "" });
  const [error, setError] = useState("");

  const onSubmit = async (event) => {
    event.preventDefault();
    try {
      await login(form.email, form.password);
      navigate("/dashboard");
    } catch (err) {
      setError(err?.response?.data?.message || "Unable to login");
    }
  };

  return (
    <div style={{ maxWidth: 420, margin: "80px auto" }}>
      <h1>Momentum Login</h1>
      <p>Smart Driving Insights</p>
      <form onSubmit={onSubmit}>
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
        <button type="submit">Login</button>
      </form>
      {error ? <p style={{ color: "red" }}>{error}</p> : null}
      <p>
        New user? <Link to="/register">Create account</Link>
      </p>
    </div>
  );
};

export default Login;
