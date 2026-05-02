# Momentum (MERN Scaffold)

This folder contains a MERN scaffold aligned with the Momentum FYP architecture and module split.

## Structure

- `server/` Express + MongoDB API with JWT auth and modular routes/controllers
- `client/` React app with auth context, protected routes, and page/component skeletons

## MongoDB (required)

The API needs a running MongoDB instance. **Nothing is listening on `localhost:27017` until you start one.**

| Option | Command / steps |
|--------|------------------|
| **Docker** (recommended if you use Docker Desktop) | From `momentum/`: `docker compose up -d` — exposes Mongo on port **27017** |
| **MongoDB Atlas** | Create a free cluster, copy the connection string, set `MONGODB_URI` in `server/.env` |
| **Homebrew** (macOS) | `brew tap mongodb/brew && brew install mongodb-community` then `brew services start mongodb-community` |

If Docker shows `Cannot connect to the Docker daemon`, open **Docker Desktop** first, then run `docker compose up -d` again.

The server retries connecting for about a minute so MongoDB can start slightly after `npm run dev`.

## Backend setup

1. `cd server`
2. `npm install`
3. Copy `.env.example` from the repo root into `server/.env` (or create `server/.env` with `MONGODB_URI`, `JWT_SECRET`, `PORT`, etc.)
4. Start MongoDB (see above), then `npm run dev`

API base URL: `http://localhost:5001/api` if you use `PORT=5001`, otherwise `http://localhost:5000/api`

### Implemented API groups

- `/api/auth`
- `/api/vehicles`
- `/api/vehicle-data`
- `/api/trips`
- `/api/analysis`
- `/api/recommendations`
- `/api/admin`

## Frontend setup

1. `cd client`
2. `npm install`
3. Create `client/.env` and set `REACT_APP_API_URL=http://localhost:5000/api`
4. `npm start`

## Phone on the same Wi‑Fi (local dev + ELM327)

Bluetooth (ELM327) is **only** between the **phone and the dongle** in the car.  
Your **laptop** only needs to run the **API**; the phone talks to it over **Wi‑Fi** (same network).

1. Start the API: `cd server && npm run dev` (it listens on `0.0.0.0`, so other devices on the LAN can connect).
2. On the laptop, find your LAN IP, e.g. macOS: System Settings → Network, or run `ipconfig getifaddr en0`.
3. **Flutter app** (physical Android/iPhone on Wi‑Fi), use your PC’s IP and API port (e.g. `5001`):
   ```bash
   cd momentum_mobile
   flutter run --dart-define=MOMENTUM_API_BASE=http://YOUR_PC_LAN_IP:5001/api
   ```
4. **React in the phone’s browser** (optional): build/run the web client with `REACT_APP_API_URL=http://YOUR_PC_LAN_IP:5001/api` and open `http://YOUR_PC_LAN_IP:3001` (or the port Vite/CRA prints).

Ensure the **phone and PC are on the same Wi‑Fi** (not guest isolation). Android already allows cleartext HTTP in this project for dev.

## Notes

- This is a sprint-ready starter, not a fully polished final product.
- Weather/maps integration and full recommendation engine can be added next in dedicated sprints.
