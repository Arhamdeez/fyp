import { API_BASE, DEMO_MODE_KEY, DEMO_PROFILE_KEY, TOKEN_KEY } from '../config';

/** Base64url profile for X-Momentum-Demo-Profile (name + email only). */
export function encodeDemoProfileHeader(): string | null {
  if (localStorage.getItem(DEMO_MODE_KEY) !== '1') return null;
  const raw = localStorage.getItem(DEMO_PROFILE_KEY);
  if (!raw) return null;
  try {
    const p = JSON.parse(raw) as { name?: string; email?: string };
    const name = p?.name?.trim();
    const email = p?.email?.trim();
    if (!name || !email) return null;
    const json = JSON.stringify({ name, email });
    const b64 = btoa(json).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    return b64;
  } catch {
    return null;
  }
}

export class ApiError extends Error {
  status?: number;

  constructor(message: string, status?: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null): void {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

export async function apiJson<T>(
  path: string,
  init: RequestInit & { auth?: boolean } = {},
): Promise<T> {
  const { auth = true, headers: h, ...rest } = init;
  const headers = new Headers(h);
  if (!headers.has('Content-Type') && rest.body && !(rest.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }
  if (auth) {
    const t = getToken();
    if (t) headers.set('Authorization', `Bearer ${t}`);
  }
  const demoHdr = encodeDemoProfileHeader();
  if (demoHdr) headers.set('X-Momentum-Demo-Profile', demoHdr);
  const res = await fetch(`${API_BASE}${path}`, { ...rest, headers });
  const text = await res.text();
  let data: unknown = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  if (!res.ok) {
    let detail = text || res.statusText;
    if (typeof data === 'object' && data !== null && 'detail' in data) {
      const d = (data as { detail: unknown }).detail;
      detail = Array.isArray(d) ? JSON.stringify(d) : String(d);
    }
    throw new ApiError(detail, res.status);
  }
  return data as T;
}
