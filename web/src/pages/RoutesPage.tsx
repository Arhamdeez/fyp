import { type FormEvent, useState } from 'react';
import { apiJson } from '../api/client';

type Insights = { summary: string; weather_note: string | null; driving_tip: string };
type Share = {
  share_id: number;
  user_id: number;
  label: string | null;
  created_at: string;
};

function IconNav() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="#2563eb" aria-hidden>
      <path d="M12 2L4.5 20.29l.71.71L12 18l6.79 3 .71-.71z" />
    </svg>
  );
}

export function RoutesPage() {
  const [destination, setDestination] = useState('');
  const [oLat, setOLat] = useState('31.5204');
  const [oLng, setOLng] = useState('74.3587');
  const [dLat, setDLat] = useState('31.4707');
  const [dLng, setDLng] = useState('74.4091');
  const [label, setLabel] = useState('University commute');
  const [insights, setInsights] = useState<Insights | null>(null);
  const [matches, setMatches] = useState<Share[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function onInsights(e?: FormEvent) {
    e?.preventDefault();
    setBusy(true);
    setMsg(null);
    try {
      const olat = parseFloat(oLat);
      const olng = parseFloat(oLng);
      const dlat = parseFloat(dLat);
      const dlng = parseFloat(dLng);
      const m = await apiJson<Insights>('/route/insights', {
        method: 'POST',
        body: JSON.stringify({
          dest_lat: dlat,
          dest_lng: dlng,
          origin_lat: olat,
          origin_lng: olng,
        }),
      });
      setInsights(m);
    } catch (err) {
      setMsg(String(err));
    } finally {
      setBusy(false);
    }
  }

  async function onShare() {
    setBusy(true);
    setMsg(null);
    try {
      const olat = parseFloat(oLat);
      const olng = parseFloat(oLng);
      const dlat = parseFloat(dLat);
      const dlng = parseFloat(dLng);
      await apiJson('/routes/share', {
        method: 'POST',
        body: JSON.stringify({
          origin_lat: olat,
          origin_lng: olng,
          dest_lat: dlat,
          dest_lng: dlng,
          label: label.trim() || null,
        }),
      });
      const q = new URLSearchParams({
        origin_lat: String(olat),
        origin_lng: String(olng),
        dest_lat: String(dlat),
        dest_lng: String(dlng),
        threshold_km: '5',
      });
      const list = await apiJson<Share[]>(`/routes/matches?${q}`);
      setMatches(list);
      setMsg('Route shared; matches updated.');
    } catch (err) {
      setMsg(String(err));
    } finally {
      setBusy(false);
    }
  }

  const weatherText =
    insights?.weather_note ?? 'Clear skies expected for the next 3 hours. Perfect conditions for your trip.';

  return (
    <div className="page">
      <header className="page-header">
        <h1>Route recommendations</h1>
        <p className="lead">Find optimal routes based on traffic and weather.</p>
      </header>

      {msg && <p className={msg.includes('shared') ? 'banner ms-banner-ok' : 'error'}>{msg}</p>}

      <form className="ms-search-row" onSubmit={onInsights}>
        <input
          className="ms-input"
          placeholder="Enter destination address"
          value={destination}
          onChange={(e) => setDestination(e.target.value)}
          aria-label="Destination"
        />
        <button type="submit" className="btn primary" disabled={busy}>
          Find route
        </button>
      </form>

      <div className="ms-map-placeholder">
        <div className="ms-map-figure">
          <svg width="200" height="120" viewBox="0 0 200 120" style={{ opacity: 0.85 }}>
            <circle cx="30" cy="85" r="8" fill="#22c55e" />
            <circle cx="170" cy="35" r="8" fill="#ef4444" />
            <path
              d="M 38 80 Q 100 20 162 40"
              fill="none"
              stroke="#2563eb"
              strokeWidth="3"
              strokeDasharray="8 6"
            />
          </svg>
          <div className="ms-map-nav-icon">
            <IconNav />
          </div>
        </div>
        <div>
          <strong style={{ color: 'var(--ms-text)' }}>Interactive map view</strong>
          <p className="muted small" style={{ margin: '0.35rem 0 0' }}>
            Route visualization will appear here.
          </p>
        </div>
      </div>

      <article className="ms-route-card">
        <div>
          <strong>
            Fastest route
            <span className="ms-badge">Recommended</span>
          </strong>
          <div className="ms-route-meta">
            <span>24.5 km</span>
            <span>28 min</span>
            <span className="ms-traffic">
              <span className="ms-traffic-dot" style={{ background: 'var(--ms-yellow)' }} />
              Moderate traffic
            </span>
            <span>Clear weather</span>
            <span>7.2 L/100km</span>
            <span className="ms-savings">$0.80 savings</span>
          </div>
        </div>
        <button type="button" className="btn primary">
          Select route
        </button>
      </article>

      <article className="ms-route-card">
        <div>
          <strong>Scenic route</strong>
          <div className="ms-route-meta">
            <span>28.3 km</span>
            <span>32 min</span>
            <span className="ms-traffic">
              <span className="ms-traffic-dot" style={{ background: 'var(--ms-green)' }} />
              Light traffic
            </span>
            <span>Clear weather</span>
            <span>6.8 L/100km</span>
            <span className="ms-savings">$1.20 savings</span>
          </div>
        </div>
        <button type="button" className="btn primary">
          Select route
        </button>
      </article>

      <article className="ms-route-card">
        <div>
          <strong>Highway route</strong>
          <div className="ms-route-meta">
            <span>26.1 km</span>
            <span>25 min</span>
            <span className="ms-traffic">
              <span className="ms-traffic-dot" style={{ background: 'var(--ms-red)' }} />
              Heavy traffic
            </span>
            <span>Clear weather</span>
            <span>7.8 L/100km</span>
            <span className="ms-savings">$0.00 savings</span>
          </div>
        </div>
        <button type="button" className="btn primary">
          Select route
        </button>
      </article>

      <div className="ms-weather-bar">
        <span aria-hidden>☁️</span>
        <div>
          <strong>Weather advisory</strong>
          <div>{weatherText}</div>
          {insights?.driving_tip && (
            <div style={{ marginTop: '0.35rem', fontSize: '0.85rem' }}>Tip: {insights.driving_tip}</div>
          )}
        </div>
      </div>

      <details className="ms-advanced">
        <summary>Advanced coordinates &amp; sharing</summary>
        <form className="grid-form" style={{ marginTop: '1rem' }} onSubmit={onInsights}>
          <label className="field">
            <span>Origin lat</span>
            <input value={oLat} onChange={(e) => setOLat(e.target.value)} />
          </label>
          <label className="field">
            <span>Origin lng</span>
            <input value={oLng} onChange={(e) => setOLng(e.target.value)} />
          </label>
          <label className="field">
            <span>Dest lat</span>
            <input value={dLat} onChange={(e) => setDLat(e.target.value)} />
          </label>
          <label className="field">
            <span>Dest lng</span>
            <input value={dLng} onChange={(e) => setDLng(e.target.value)} />
          </label>
          <label className="field span-2">
            <span>Route label (sharing)</span>
            <input value={label} onChange={(e) => setLabel(e.target.value)} />
          </label>
          <div className="toolbar span-2">
            <button type="submit" className="btn secondary" disabled={busy}>
              Refresh insights
            </button>
            <button type="button" className="btn secondary" disabled={busy} onClick={onShare}>
              Share route &amp; find matches
            </button>
          </div>
        </form>
      </details>

      {insights && (
        <article className="card prose" style={{ marginTop: '1.25rem' }}>
          <h2>API summary</h2>
          <p>{insights.summary}</p>
        </article>
      )}

      <h2 style={{ marginTop: '1.5rem', fontSize: '1.1rem' }}>Similar shared routes ({matches.length})</h2>
      <ul className="list">
        {matches.map((m) => (
          <li key={m.share_id}>
            <strong>{m.label ?? 'Unlabeled'}</strong>
            <span className="muted small"> user {m.user_id} · {m.created_at}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
