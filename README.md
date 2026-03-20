# Momentum (FYP prototype)

Smart mobility & digital car garage: OBD-style telemetry, driving analysis, route/weather hints, optional route sharing, and vehicle recommendations—backed by **FastAPI** + SQLite.

## Repository layout

| Path | Role |
|------|------|
| `backend/` | REST API (auth, vehicles, samples, analysis, routes, recommendations) |
| `web/` | **Primary UI for now** — React + Vite SPA (matches SRS browser use case) |
| `momentum_mobile/` | Optional Flutter client for later mobile/OBD hardware demos |

## Quick start

### 1. API

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Docs: <http://127.0.0.1:8000/docs>
- Optional: set `OPENWEATHER_API_KEY` in `backend/.env` for live weather on route insights.

### 2. Web app

```bash
cd web
npm install
cp .env.example .env   # edit VITE_API_BASE if the API is not on 127.0.0.1:8000
npm run dev
```

Open the URL Vite prints (usually <http://127.0.0.1:5173>). Register, add a vehicle, **Simulate OBD burst**, then run **Driving analysis**.

### 3. Flutter (optional)

Useful when you plug in a real OBD bridge on device. From `momentum_mobile/`, set API host in `lib/config.dart` (Android emulator → `http://10.0.2.2:8000`).

## SRS alignment

- Login / register / dashboard-style modules: **web** + API  
- OBD data: prototype via API; hardware can feed the same endpoints  
- Admin FRs from the generic SRS chapter are **not** implemented in this scaffold (add if required by your advisor)

## Group

Muhammad Arham Babar, Irtaza Ali Sameel, Muhammad Abdullah Akram — FAST-NUCES Lahore.
