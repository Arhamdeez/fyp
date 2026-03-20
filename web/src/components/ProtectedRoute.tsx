import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function ProtectedRoute() {
  const { token, ready } = useAuth();
  if (!ready) {
    return (
      <div className="loading-screen">
        <p>Loading…</p>
      </div>
    );
  }
  if (!token) return <Navigate to="/login" replace />;
  return <Outlet />;
}
