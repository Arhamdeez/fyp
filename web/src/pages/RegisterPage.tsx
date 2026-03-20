import { type FormEvent, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import { ApiError } from '../api/client';
import { GlassSurface } from '../components/GlassSurface';
import { useAuth } from '../context/AuthContext';

export function RegisterPage() {
  const { register, token, ready } = useAuth();
  const nav = useNavigate();
  const [name, setName] = useState('');
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
      await register(name.trim(), email.trim(), password);
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
          <h1>Demo sign up</h1>
          <p className="muted">
            One local profile for this browser. Your name appears in the app after you continue (API optional if the
            server is running).
          </p>
          <form onSubmit={onSubmit} className="form">
            <label className="field">
              <span>Name</span>
              <input value={name} onChange={(e) => setName(e.target.value)} required />
            </label>
            <label className="field">
              <span>Email</span>
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </label>
            <label className="field">
              <span>Password (min 6)</span>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} minLength={6} required />
            </label>
            {error && <p className="error">{error}</p>}
            <button type="submit" className="btn primary" disabled={busy}>
              {busy ? 'Saving…' : 'Continue'}
            </button>
          </form>
          <p className="muted small">
            Already have an account? <Link to="/login">Log in</Link>
          </p>
        </div>
      </GlassSurface>
    </div>
  );
}
