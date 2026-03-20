import { type FormEvent, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { ApiError } from '../api/client';
import { GlassSurface } from '../components/GlassSurface';
import { useAuth } from '../context/AuthContext';

export function LoginPage() {
  const { login, token, ready } = useAuth();
  const nav = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (!ready) {
    return (
      <div className="loading-screen">
        <p>Loading…</p>
      </div>
    );
  }
  if (token) return <Navigate to="/" replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(email.trim(), password);
      nav('/', { replace: true });
    } catch (err) {
      setError(err instanceof ApiError ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth-page">
      <GlassSurface
        variant="light"
        borderRadius={26}
        className="auth-card-shell"
        backgroundOpacity={0.14}
        displace={0.38}
        saturation={1.38}
      >
        <div className="auth-card-inner">
          <h1>Momentum</h1>
          <p className="muted">Sign in with the email and password you used on demo sign up, or use a full API account.</p>
          <form onSubmit={onSubmit} className="form">
            <label className="field">
              <span>Email</span>
              <input
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </label>
            <label className="field">
              <span>Password</span>
              <input
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </label>
            {error && <p className="error">{error}</p>}
            <button type="submit" className="btn primary" disabled={busy}>
              {busy ? 'Signing in…' : 'Log in'}
            </button>
          </form>
          <p className="muted small">
            No account? <Link to="/register">Demo sign up</Link>
          </p>
        </div>
      </GlassSurface>
    </div>
  );
}
