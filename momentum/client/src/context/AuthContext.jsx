import { createContext, useContext, useEffect, useMemo, useState } from "react";
import api from "../services/api";

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [token, setToken] = useState(() => localStorage.getItem("momentum_token"));
  const [user, setUser] = useState(null);

  useEffect(() => {
    if (!token) return;
    api
      .get("/auth/profile")
      .then((response) => setUser(response.data.user))
      .catch(() => {
        localStorage.removeItem("momentum_token");
        setToken(null);
        setUser(null);
      });
  }, [token]);

  const login = async (email, password) => {
    const response = await api.post("/auth/login", { email, password });
    localStorage.setItem("momentum_token", response.data.token);
    setToken(response.data.token);
    setUser(response.data.user);
  };

  const logout = () => {
    localStorage.removeItem("momentum_token");
    setToken(null);
    setUser(null);
  };

  const value = useMemo(
    () => ({
      token,
      user,
      isAuthenticated: Boolean(token),
      login,
      logout
    }),
    [token, user]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => useContext(AuthContext);
