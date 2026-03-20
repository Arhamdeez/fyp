/** FastAPI backend base URL (no trailing slash). */
export const API_BASE =
  import.meta.env.VITE_API_BASE?.replace(/\/$/, '') ?? 'http://127.0.0.1:8000';

export const TOKEN_KEY = 'momentum_token';

/** Browser-only demo session (paired with backend POST /auth/demo/establish when API is up). */
export const DEMO_MODE_KEY = 'momentum_demo_mode';
export const DEMO_PROFILE_KEY = 'momentum_demo_profile';

export type DemoProfile = { name: string; email: string; password: string };
