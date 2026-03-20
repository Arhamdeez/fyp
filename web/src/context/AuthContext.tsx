import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { ApiError, apiJson, setToken } from '../api/client';
import { DEMO_MODE_KEY, DEMO_PROFILE_KEY, TOKEN_KEY } from '../config';

type User = { user_id: number; name: string; email: string; role: string };

type AuthContextValue = {
  token: string | null;
  user: User | null;
  ready: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (name: string, email: string, password: string) => Promise<void>;
  logout: () => void;
};

const AuthContext = createContext<AuthContextValue | null>(null);

function readDemoProfile(): { name: string; email: string; password: string } | null {
  try {
    const raw = localStorage.getItem(DEMO_PROFILE_KEY);
    if (!raw) return null;
    const p = JSON.parse(raw) as { name?: string; email?: string; password?: string };
    if (!p?.name?.trim() || !p?.email?.trim() || !p?.password) return null;
    return { name: p.name.trim(), email: p.email.trim(), password: p.password };
  } catch {
    return null;
  }
}

function persistDemo(p: { name: string; email: string; password: string }) {
  localStorage.setItem(DEMO_PROFILE_KEY, JSON.stringify(p));
  localStorage.setItem(DEMO_MODE_KEY, '1');
}

function clearDemoStorage() {
  localStorage.removeItem(DEMO_PROFILE_KEY);
  localStorage.removeItem(DEMO_MODE_KEY);
}

function offlineUser(profile: { name: string; email: string }): User {
  return { user_id: 0, name: profile.name, email: profile.email, role: 'driver' };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setTok] = useState<string | null>(() => localStorage.getItem(TOKEN_KEY));
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const t = localStorage.getItem(TOKEN_KEY);
      const demoProfile = readDemoProfile();

      if (t === 'demo' && demoProfile) {
        try {
          await apiJson<User>('/auth/demo/establish', {
            auth: false,
            method: 'POST',
            body: JSON.stringify({
              email: demoProfile.email,
              password: demoProfile.password,
              name: demoProfile.name,
            }),
          });
        } catch {
          /* offline */
        }
        try {
          const u = await apiJson<User>('/auth/me', { method: 'GET' });
          if (!cancelled) {
            setTok('demo');
            setUser(u);
          }
        } catch {
          if (!cancelled) {
            setTok('demo');
            setUser(offlineUser(demoProfile));
          }
        }
        if (!cancelled) setReady(true);
        return;
      }

      if (t === 'demo' && !demoProfile) {
        setToken(null);
        if (!cancelled) {
          setTok(null);
          setUser(null);
          setReady(true);
        }
        return;
      }

      if (!t) {
        if (!cancelled) setReady(true);
        return;
      }

      try {
        const u = await apiJson<User>('/auth/me', { method: 'GET' });
        if (!cancelled) {
          setTok(t);
          setUser(u);
        }
      } catch {
        if (!cancelled) {
          setToken(null);
          setTok(null);
          setUser(null);
        }
      } finally {
        if (!cancelled) setReady(true);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const logout = useCallback(() => {
    clearDemoStorage();
    setToken(null);
    setTok(null);
    setUser(null);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const trimmed = email.trim();
    try {
      const u = await apiJson<User>('/auth/demo/establish', {
        auth: false,
        method: 'POST',
        body: JSON.stringify({ email: trimmed, password, name: null }),
      });
      persistDemo({ name: u.name, email: trimmed, password });
      setToken('demo');
      setTok('demo');
      setUser(u);
      return;
    } catch (e) {
      if (e instanceof ApiError && e.status === 400) {
        throw new ApiError('No account for this email yet. Use sign up first.', 400);
      }
      if (e instanceof ApiError && e.status !== 401) throw e;
    }
    const m = await apiJson<{ access_token: string }>('/auth/login', {
      auth: false,
      method: 'POST',
      body: JSON.stringify({ email: trimmed, password }),
    });
    clearDemoStorage();
    setToken(m.access_token);
    setTok(m.access_token);
    const u = await apiJson<User>('/auth/me', { method: 'GET' });
    setUser(u);
  }, []);

  const register = useCallback(async (name: string, email: string, password: string) => {
    const n = name.trim();
    const em = email.trim();
    let serverUser: User;
    try {
      serverUser = await apiJson<User>('/auth/demo/establish', {
        auth: false,
        method: 'POST',
        body: JSON.stringify({ name: n, email: em, password }),
      });
    } catch (e) {
      const isClientErr = e instanceof ApiError && e.status != null && e.status >= 400 && e.status < 500;
      if (isClientErr) throw e;
      serverUser = offlineUser({ name: n, email: em });
    }
    persistDemo({ name: n, email: em, password });
    setToken('demo');
    setTok('demo');
    setUser(serverUser);
  }, []);

  const value = useMemo(
    () => ({ token, user, ready, login, register, logout }),
    [token, user, ready, login, register, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

/** Hook colocated with provider (Fast Refresh). */
// eslint-disable-next-line react-refresh/only-export-components -- context + hook pattern
export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth outside AuthProvider');
  return ctx;
}
