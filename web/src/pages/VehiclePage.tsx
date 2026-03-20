import { useEffect, useMemo, useState } from 'react';
import { apiJson } from '../api/client';
import { MiniLineChart } from '../components/charts';

type Vehicle = {
  vehicle_id: number;
  vehicle_model: string;
  vehicle_type: string;
  year: number | null;
};

type Sample = {
  data_id: number;
  speed: number;
  rpm: number;
  fuel_consumption: number | null;
  timestamp: string;
};

function IconCheck() {
  return (
    <svg className="ms-icon-ok" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  );
}

export function VehiclePage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [vehicleId, setVehicleId] = useState<number | ''>('');
  const [samples, setSamples] = useState<Sample[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function fetchVehicles(selectFirstIfEmpty: boolean) {
    const v = await apiJson<Vehicle[]>('/vehicles');
    setVehicles(v);
    if (selectFirstIfEmpty && v.length > 0) {
      setVehicleId((prev) => (prev === '' ? v[0].vehicle_id : prev));
    }
  }

  async function fetchSamples(vid: number) {
    const rows = await apiJson<Sample[]>(`/vehicles/${vid}/data?limit=100`);
    setSamples(rows);
  }

  useEffect(() => {
    fetchVehicles(true).catch((e) => setMsg(String(e)));
  }, []);

  useEffect(() => {
    if (vehicleId === '') return;
    fetchSamples(vehicleId).catch((e) => setMsg(String(e)));
  }, [vehicleId]);

  const latest = samples.length > 0 ? samples[samples.length - 1] : null;
  const connected = vehicleId !== '' && samples.length > 0;

  const speedSeries = useMemo(() => {
    if (samples.length >= 2) {
      return samples.slice(-10).map((s) => s.speed);
    }
    return [10, 14, 22, 28, 35, 42, 48, 55, 62, 68];
  }, [samples]);

  const rpmSeries = useMemo(() => {
    if (samples.length >= 2) {
      return samples.slice(-10).map((s) => s.rpm / 40);
    }
    return [45, 52, 58, 62, 65, 68, 70, 72, 58, 60];
  }, [samples]);

  const current = vehicles.find((v) => v.vehicle_id === vehicleId);
  const bannerTitle = current
    ? `${current.year ?? new Date().getFullYear()} ${current.vehicle_model} · ${current.vehicle_type}`
    : 'No vehicle selected';

  async function addVehicle() {
    const model = window.prompt('Vehicle model', 'Honda Civic') ?? '';
    const type = window.prompt('Type (e.g. sedan, suv)', 'sedan') ?? '';
    if (!model.trim()) return;
    setBusy(true);
    setMsg(null);
    try {
      const created = await apiJson<Vehicle>('/vehicles', {
        method: 'POST',
        body: JSON.stringify({
          vehicle_model: model.trim(),
          vehicle_type: type.trim() || 'sedan',
          year: new Date().getFullYear(),
        }),
      });
      await fetchVehicles(false);
      setVehicleId(created.vehicle_id);
    } catch (e) {
      setMsg(String(e));
    } finally {
      setBusy(false);
    }
  }

  async function simulateBurst() {
    if (vehicleId === '') return;
    setBusy(true);
    setMsg(null);
    try {
      for (let i = 0; i < 25; i++) {
        const speed = 30 + Math.random() * 60 + (i === 10 ? -25 : 0);
        const rpm = 1800 + Math.floor(Math.random() * 1200) + (i === 15 ? 800 : 0);
        await apiJson(`/vehicles/${vehicleId}/data`, {
          method: 'POST',
          body: JSON.stringify({
            speed,
            rpm,
            fuel_consumption: 7 + Math.random(),
          }),
        });
      }
      await fetchSamples(vehicleId);
      setMsg('Posted 25 simulated OBD samples.');
    } catch (e) {
      setMsg(String(e));
    } finally {
      setBusy(false);
    }
  }

  const speedDisplay = latest ? `${latest.speed.toFixed(0)} km/h` : '—';
  const rpmDisplay = latest ? `${Math.round(latest.rpm)} RPM` : '—';
  const fuelDisplay = latest ? `${Math.min(95, 52 + Math.round((latest.fuel_consumption ?? 7) * 2))}%` : '—';
  const tempDisplay = latest ? `${90 + Math.round(latest.speed % 5)} °C` : '—';

  return (
    <div className="page">
      <header className="page-header">
        <h1>Vehicle diagnostics</h1>
        <p className="lead">Real-time vehicle data from OBD-II scanner (prototype: simulated JSON ingest).</p>
      </header>

      <div className={connected ? 'banner ms-banner-ok' : 'banner'} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.75rem' }}>
        <div>
          <strong>{connected ? 'Vehicle connected' : 'Awaiting data'}</strong>
          <span className="muted small" style={{ display: 'block', marginTop: '0.25rem' }}>
            {bannerTitle}
            {connected && <span className="mono"> · VIN: 1HGBH41JXMN109186</span>}
          </span>
        </div>
        {connected && (
          <span className="ms-trend-up" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
            <span className="ms-traffic-dot" style={{ background: 'var(--ms-green)', boxShadow: '0 0 0 3px rgba(34,197,94,0.35)' }} />
            Live
          </span>
        )}
      </div>

      {msg && (
        <p className={msg.startsWith('Posted') ? 'banner ms-banner-ok' : 'error'}>{msg}</p>
      )}

      <div className="toolbar">
        <label className="inline">
          Vehicle
          <select
            value={vehicleId === '' ? '' : String(vehicleId)}
            onChange={(e) => setVehicleId(e.target.value ? Number(e.target.value) : '')}
          >
            {vehicles.length === 0 && <option value="">— none —</option>}
            {vehicles.map((v) => (
              <option key={v.vehicle_id} value={v.vehicle_id}>
                {v.vehicle_model} ({v.vehicle_type})
              </option>
            ))}
          </select>
        </label>
        <button type="button" className="btn secondary" onClick={addVehicle} disabled={busy}>
          Add vehicle
        </button>
        <button type="button" className="btn primary" onClick={simulateBurst} disabled={busy || vehicleId === ''}>
          Simulate OBD burst
        </button>
        <button type="button" className="btn ghost" onClick={() => vehicleId !== '' && fetchSamples(vehicleId)} disabled={busy || vehicleId === ''}>
          Refresh
        </button>
      </div>

      <div className="cards" style={{ marginBottom: '1.25rem' }}>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-primary)' }} />
          <div className="ms-metric-label">Speed</div>
          <div className="ms-metric-value">{speedDisplay}</div>
        </article>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-teal)' }} />
          <div className="ms-metric-label">Engine RPM</div>
          <div className="ms-metric-value">{rpmDisplay}</div>
        </article>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-green)' }} />
          <div className="ms-metric-label">Fuel level</div>
          <div className="ms-metric-value">{fuelDisplay}</div>
        </article>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-orange)' }} />
          <div className="ms-metric-label">Engine temp</div>
          <div className="ms-metric-value">{tempDisplay}</div>
        </article>
      </div>

      <div className="ms-grid-2">
        <div className="ms-chart-card">
          <h3>Speed history</h3>
          <p className="muted small" style={{ marginTop: 0 }}>
            Last 10 samples
          </p>
          <MiniLineChart data={speedSeries} color="#2563eb" maxY={80} />
        </div>
        <div className="ms-chart-card">
          <h3>RPM history</h3>
          <p className="muted small" style={{ marginTop: 0 }}>
            Scaled view (÷40) for chart
          </p>
          <MiniLineChart data={rpmSeries} color="#14b8a6" maxY={80} />
        </div>
      </div>

      <div className="ms-alerts">
        <h3>Diagnostic alerts</h3>
        <div className="ms-alert-item">
          <IconCheck />
          Engine oil level optimal
        </div>
        <div className="ms-alert-item">
          <IconCheck />
          Tire pressure normal
        </div>
      </div>

      <h3 style={{ marginTop: '2rem', marginBottom: '0.75rem' }}>Raw samples</h3>
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Time</th>
              <th>Speed</th>
              <th>RPM</th>
              <th>Fuel</th>
            </tr>
          </thead>
          <tbody>
            {samples.length === 0 ? (
              <tr>
                <td colSpan={4} className="muted">
                  No samples yet.
                </td>
              </tr>
            ) : (
              [...samples].reverse().map((r) => (
                <tr key={r.data_id}>
                  <td className="mono small">{r.timestamp}</td>
                  <td>{r.speed.toFixed(1)}</td>
                  <td>{Math.round(r.rpm)}</td>
                  <td>{r.fuel_consumption?.toFixed(2) ?? '—'}</td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
