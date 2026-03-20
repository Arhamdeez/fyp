import { useEffect, useMemo, useState } from 'react';
import { apiJson } from '../api/client';
import { MiniBarChart, MiniLineChart, ProgressRow, ScoreDonut } from '../components/charts';
import { GlassSurface } from '../components/GlassSurface';

type Vehicle = { vehicle_id: number; vehicle_model: string };
type Report = {
  analysis_id: number;
  driving_score: number;
  harsh_braking_events: number;
  acceleration_events: number;
  report_date: string;
};

const WEEK = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function weeklyBars(harsh: number, accel: number): number[] {
  const seed = [2, 4, 1, 0, 3, 2, 1];
  const t = Math.max(1, harsh + accel);
  const s = seed.reduce((a, b) => a + b, 0);
  return seed.map((b) => Math.max(0, Math.round((b / s) * t)));
}

const ACCEL_LINE = [2, 3, 4, 3, 5, 6, 8, 7, 6, 5, 7, 9];

const TIPS = [
  'Leave a larger following distance in urban traffic to reduce harsh braking.',
  'Smooth throttle inputs improve your acceleration score and fuel use.',
  'Plan highway merges earlier to avoid sudden speed corrections.',
];

export function AnalysisPage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [vehicleId, setVehicleId] = useState<number | ''>('');
  const [history, setHistory] = useState<Report[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function loadVehicles(selectFirst: boolean) {
    const v = await apiJson<Vehicle[]>('/vehicles');
    setVehicles(v);
    if (selectFirst && v.length > 0) {
      setVehicleId((prev) => (prev === '' ? v[0].vehicle_id : prev));
    }
  }

  async function loadHistory(vid: number) {
    const h = await apiJson<Report[]>(`/vehicles/${vid}/analysis`);
    setHistory(h);
  }

  useEffect(() => {
    loadVehicles(true).catch((e) => setMsg(String(e)));
  }, []);

  useEffect(() => {
    if (vehicleId === '') return;
    loadHistory(vehicleId).catch(() => setHistory([]));
  }, [vehicleId]);

  async function runAnalysis() {
    if (vehicleId === '') return;
    setBusy(true);
    setMsg(null);
    try {
      await apiJson(`/vehicles/${vehicleId}/analyze`, { method: 'POST' });
      await loadHistory(vehicleId);
      setMsg('Analysis saved.');
    } catch (e) {
      setMsg(String(e));
    } finally {
      setBusy(false);
    }
  }

  const latest = history.length > 0 ? history[history.length - 1] : null;
  const score = latest?.driving_score ?? 87;
  const harsh = latest?.harsh_braking_events ?? 12;
  const accel = latest?.acceleration_events ?? 8;

  const barValues = useMemo(() => weeklyBars(harsh, accel), [harsh, accel]);
  const barMax = Math.max(8, ...barValues, 1);

  const accelScore = Math.max(60, Math.min(100, 100 - accel * 2));
  const brakeScore = Math.max(60, Math.min(100, 100 - harsh * 2));
  const speedScore = Math.round((accelScore + brakeScore) / 2 + 3);

  return (
    <div className="page">
      <header className="page-header">
        <h1>Driving behavior analysis</h1>
        <p className="lead">Insights and recommendations based on your driving patterns.</p>
      </header>

      {msg && <p className={msg.includes('saved') ? 'banner ms-banner-ok' : 'error'}>{msg}</p>}

      <div className="toolbar wrap">
        <label className="inline">
          Vehicle
          <select
            value={vehicleId === '' ? '' : String(vehicleId)}
            onChange={(e) => setVehicleId(e.target.value ? Number(e.target.value) : '')}
          >
            {vehicles.length === 0 && <option value="">Add a vehicle first</option>}
            {vehicles.map((v) => (
              <option key={v.vehicle_id} value={v.vehicle_id}>
                {v.vehicle_model}
              </option>
            ))}
          </select>
        </label>
        <button type="button" className="btn primary" onClick={runAnalysis} disabled={busy || vehicleId === ''}>
          Run analysis
        </button>
      </div>

      <GlassSurface
        variant="tinted"
        borderRadius={24}
        className="ms-hero-glass"
        displace={0.48}
        saturation={1.48}
        backgroundOpacity={0.22}
      >
        <div className="ms-hero-glass-inner">
          <div>
            <h2>Overall driving score</h2>
            <p className="ms-hero-big">
              {score} <span style={{ fontSize: '1.5rem', fontWeight: 600, opacity: 0.9 }}>/ 100</span>
            </p>
            <div className="ms-hero-delta">
              <span aria-hidden>↑</span> +8 points from last week
            </div>
          </div>
          <div className="ms-donut-wrap">
            <ScoreDonut value={score} />
            <span className="ms-donut-label">{score}%</span>
          </div>
        </div>
      </GlassSurface>

      <div className="ms-row-3">
        <ProgressRow label="Acceleration" value={accelScore} color="var(--ms-yellow)" />
        <ProgressRow label="Braking" value={brakeScore} color="var(--ms-green)" />
        <ProgressRow label="Speed consistency" value={speedScore} color="var(--ms-green)" />
      </div>

      <div className="ms-grid-2" style={{ marginBottom: '1.5rem' }}>
        <div className="ms-chart-card">
          <h3>Harsh braking events</h3>
          <MiniBarChart labels={WEEK} values={barValues} color="#2563eb" maxY={barMax} />
        </div>
        <div className="ms-chart-card">
          <h3>Acceleration patterns</h3>
          <p className="muted small" style={{ marginTop: 0 }}>
            Relative intensity (8:00–11:00 window)
          </p>
          <MiniLineChart data={ACCEL_LINE} color="#14b8a6" maxY={10} />
        </div>
      </div>

      <div className="ms-chart-card">
        <h3 style={{ marginBottom: '0.75rem' }}>Driving recommendations</h3>
        <ul style={{ margin: 0, paddingLeft: '1.25rem', color: 'var(--ms-text-muted)', fontSize: '0.9rem' }}>
          {TIPS.map((t) => (
            <li key={t} style={{ marginBottom: '0.5rem' }}>
              {t}
            </li>
          ))}
        </ul>
        {latest && (
          <p className="muted small mono" style={{ marginTop: '1rem', marginBottom: 0 }}>
            Last report: {latest.report_date} · Harsh braking: {latest.harsh_braking_events} · Rapid acceleration:{' '}
            {latest.acceleration_events}
          </p>
        )}
      </div>
    </div>
  );
}
