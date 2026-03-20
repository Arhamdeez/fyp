import { useEffect, useState } from 'react';
import { apiJson } from '../api/client';
import { MiniLineChart } from '../components/charts';

type Vehicle = {
  vehicle_id: number;
  vehicle_model: string;
  vehicle_type: string;
  year: number | null;
};

type Report = {
  analysis_id: number;
  driving_score: number;
  harsh_braking_events: number;
  acceleration_events: number;
  report_date: string;
};

const MOCK_TRIPS = [
  { dest: 'Downtown Office', distance: '24.5 km', duration: '32 min', date: '2026-03-15' },
  { dest: 'Shopping Mall', distance: '12.3 km', duration: '18 min', date: '2026-03-14' },
  { dest: 'Airport', distance: '38.0 km', duration: '45 min', date: '2026-03-12' },
  { dest: 'Home to Work', distance: '15.2 km', duration: '22 min', date: '2026-03-11' },
];

const SPEED_DEMO = [12, 18, 24, 32, 38, 45, 52, 58, 62, 65, 68, 64, 58, 55, 52, 48];
const FUEL_DEMO = [8.2, 7.9, 7.5, 7.8, 7.2, 7.0, 6.8, 7.1, 7.4, 7.2, 6.9, 7.0, 7.3, 7.1, 6.8, 6.5];

export function DashboardPage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [score, setScore] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const v = await apiJson<Vehicle[]>('/vehicles');
        if (cancelled) return;
        setVehicles(v);
        if (v.length > 0) {
          const reports = await apiJson<Report[]>(`/vehicles/${v[0].vehicle_id}/analysis`);
          if (!cancelled && reports.length > 0) {
            const last = reports[reports.length - 1];
            setScore(last.driving_score);
          }
        }
      } catch (e) {
        if (!cancelled) setError(String(e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const displayScore = score ?? 87;
  const avgSpeed = 65;
  const fuel = '7.2 L/100km';
  const tripKm = 245;

  return (
    <div className="page">
      <header className="page-header">
        <h1>Dashboard</h1>
        <p className="lead">Welcome back! Here&apos;s your driving overview.</p>
      </header>
      {error && <p className="error">{error}</p>}

      <div className="cards" style={{ marginBottom: '1.5rem' }}>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-primary)' }} />
          <div className="ms-metric-label">Driving score</div>
          <div className="ms-metric-value ms-stat-accent">
            {displayScore}
            <span className="muted" style={{ fontSize: '1rem', fontWeight: 600 }}>
              /100
            </span>
          </div>
          <div className="ms-trend-up">+8% vs last week</div>
        </article>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-teal)' }} />
          <div className="ms-metric-label">Average speed</div>
          <div className="ms-metric-value">
            {avgSpeed} <span className="muted small">km/h</span>
          </div>
          <div className="ms-metric-sub">avg</div>
        </article>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-green)' }} />
          <div className="ms-metric-label">Fuel efficiency</div>
          <div className="ms-metric-value">{fuel}</div>
          <div className="ms-trend-up">−5% vs prior</div>
        </article>
        <article className="ms-metric-card">
          <div className="ms-metric-dot" style={{ background: 'var(--ms-orange)' }} />
          <div className="ms-metric-label">Trip distance</div>
          <div className="ms-metric-value">
            {tripKm} <span className="muted small">km</span>
          </div>
          <div className="ms-metric-sub">this week</div>
        </article>
      </div>

      <div className="ms-grid-2" style={{ marginBottom: '1.5rem' }}>
        <div className="ms-chart-card">
          <h3>Speed over time</h3>
          <MiniLineChart data={SPEED_DEMO} color="#2563eb" maxY={80} />
          <div className="muted small" style={{ marginTop: '0.5rem' }}>
            Sample timeline (00:00 → 00:30)
          </div>
        </div>
        <div className="ms-chart-card">
          <h3>Fuel consumption (L/100km)</h3>
          <MiniLineChart data={FUEL_DEMO} color="#14b8a6" maxY={12} />
          <div className="muted small" style={{ marginTop: '0.5rem' }}>
            Same window as speed chart
          </div>
        </div>
      </div>

      <div className="ms-chart-card">
        <h3 style={{ marginBottom: '1rem' }}>Recent trip history</h3>
        <div className="table-wrap" style={{ border: 'none' }}>
          <table className="table">
            <thead>
              <tr>
                <th>Destination</th>
                <th>Distance</th>
                <th>Duration</th>
                <th>Date</th>
              </tr>
            </thead>
            <tbody>
              {MOCK_TRIPS.map((t) => (
                <tr key={t.dest + t.date}>
                  <td>{t.dest}</td>
                  <td>{t.distance}</td>
                  <td>{t.duration}</td>
                  <td className="mono small">{t.date}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="muted small" style={{ marginTop: '0.75rem', marginBottom: 0 }}>
          Vehicles registered: <strong>{vehicles.length}</strong>. Add telemetry under Vehicle Data to refresh scores from the API.
        </p>
      </div>
    </div>
  );
}
