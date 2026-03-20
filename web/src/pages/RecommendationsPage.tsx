import { useEffect, useState } from 'react';
import { apiJson } from '../api/client';
import { IconStar } from '../components/icons';

type Vehicle = { vehicle_id: number; vehicle_model: string };
type Rec = {
  recommendation_id: number;
  recommendation_type: string;
  description: string;
  date_generated: string;
};

type MockVeh = {
  title: string;
  sub: string;
  score: number;
  efficiency: string;
  range: string;
  price: string;
  tags: string[];
};

const MOCK_VEHICLES: MockVeh[] = [
  {
    title: 'Tesla Model 3',
    sub: '2024 · Electric',
    score: 94,
    efficiency: 'Electric',
    range: '358 km',
    price: '$42,990',
    tags: ['Autopilot', 'Premium interior', 'Long range'],
  },
  {
    title: 'Toyota Prius',
    sub: '2024 · Hybrid',
    score: 89,
    efficiency: '4.4 L/100km',
    range: '900 km',
    price: '$32,500',
    tags: ['Hybrid', 'Efficient', 'Reliable'],
  },
  {
    title: 'Hyundai Ioniq 6',
    sub: '2024 · Electric',
    score: 91,
    efficiency: 'Electric',
    range: '520 km',
    price: '$46,200',
    tags: ['Fast charge', 'Aerodynamic', 'Tech pack'],
  },
];

export function RecommendationsPage() {
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [vehicleId, setVehicleId] = useState<number | ''>('');
  const [commuteKm, setCommuteKm] = useState('15');
  const [items, setItems] = useState<Rec[]>([]);
  const [vType, setVType] = useState('all');
  const [fuelType, setFuelType] = useState('all');
  const [budget, setBudget] = useState(60000);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function loadAll(selectFirst: boolean) {
    const v = await apiJson<Vehicle[]>('/vehicles');
    setVehicles(v);
    if (selectFirst && v.length > 0) {
      setVehicleId((prev) => (prev === '' ? v[0].vehicle_id : prev));
    }
    const r = await apiJson<Rec[]>('/recommendations');
    setItems(r);
  }

  useEffect(() => {
    loadAll(true).catch((e) => setMsg(String(e)));
  }, []);

  async function generate() {
    if (vehicleId === '') return;
    setBusy(true);
    setMsg(null);
    try {
      const km = commuteKm.trim() ? Number(commuteKm) : undefined;
      const q = new URLSearchParams({ vehicle_id: String(vehicleId) });
      if (km !== undefined && !Number.isNaN(km)) q.set('commute_km_estimate', String(km));
      await apiJson(`/recommendations/generate?${q}`, { method: 'POST' });
      const r = await apiJson<Rec[]>('/recommendations');
      setItems(r);
      setMsg('Recommendations updated.');
    } catch (e) {
      setMsg(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <h1>Vehicle recommendations</h1>
        <p className="lead">Vehicles matched to your driving behavior and commute patterns.</p>
      </header>

      {msg && <p className={msg.includes('updated') ? 'banner ms-banner-ok' : 'error'}>{msg}</p>}

      <div className="ms-filters">
        <span className="muted small" style={{ fontWeight: 600, marginRight: '0.5rem' }}>
          Filters
        </span>
        <label className="inline">
          Vehicle type
          <select value={vType} onChange={(e) => setVType(e.target.value)}>
            <option value="all">All types</option>
            <option value="sedan">Sedan</option>
            <option value="suv">SUV</option>
            <option value="ev">Electric</option>
          </select>
        </label>
        <label className="inline">
          Fuel type
          <select value={fuelType} onChange={(e) => setFuelType(e.target.value)}>
            <option value="all">All fuel types</option>
            <option value="ev">Electric</option>
            <option value="hybrid">Hybrid</option>
            <option value="ice">Petrol / diesel</option>
          </select>
        </label>
        <label className="inline" style={{ flex: '1 1 200px' }}>
          Max budget: ${budget.toLocaleString()}
          <input
            type="range"
            min={25000}
            max={90000}
            step={1000}
            value={budget}
            onChange={(e) => setBudget(Number(e.target.value))}
            style={{ width: '100%' }}
          />
        </label>
      </div>

      <div className="toolbar wrap">
        <label className="inline">
          Your vehicle profile
          <select
            value={vehicleId === '' ? '' : String(vehicleId)}
            onChange={(e) => setVehicleId(e.target.value ? Number(e.target.value) : '')}
          >
            {vehicles.length === 0 && <option value="">— add vehicle first —</option>}
            {vehicles.map((v) => (
              <option key={v.vehicle_id} value={v.vehicle_id}>
                {v.vehicle_model}
              </option>
            ))}
          </select>
        </label>
        <label className="inline">
          Typical commute (km)
          <input value={commuteKm} onChange={(e) => setCommuteKm(e.target.value)} style={{ width: '6rem' }} />
        </label>
        <button type="button" className="btn primary" onClick={generate} disabled={busy || vehicleId === ''}>
          Generate from API
        </button>
      </div>

      {items.length > 0 && (
        <section style={{ marginBottom: '1.5rem' }}>
          <h2 style={{ fontSize: '1.1rem', marginBottom: '0.75rem' }}>From your profile (API)</h2>
          <div className="cards">
            {items.map((r) => (
              <article key={r.recommendation_id} className="card">
                <h3>{r.recommendation_type}</h3>
                <p className="small">{r.description}</p>
                <p className="mono muted small">{r.date_generated}</p>
              </article>
            ))}
          </div>
        </section>
      )}

      <h2 style={{ fontSize: '1.1rem', marginBottom: '0.75rem' }}>Curated picks (demo)</h2>
      <div className="ms-vehicle-grid">
        {MOCK_VEHICLES.map((car) => (
          <article key={car.title} className="ms-vehicle-card">
            <div className="ms-vehicle-img" />
            <div className="ms-vehicle-body">
              <div className="ms-vehicle-score">
                <IconStar />
                {car.score}
              </div>
              <h3 style={{ margin: '0 0 0.25rem', fontSize: '1.05rem' }}>{car.title}</h3>
              <p className="muted small" style={{ margin: 0 }}>
                {car.sub}
              </p>
              <div className="muted small" style={{ marginTop: '0.75rem', display: 'grid', gap: '0.35rem' }}>
                <span>Efficiency: {car.efficiency}</span>
                <span>Range: {car.range}</span>
                <span className="ms-savings">Price: {car.price}</span>
              </div>
              <div className="ms-tag-row">
                {car.tags.map((t) => (
                  <span key={t} className="ms-tag">
                    {t}
                  </span>
                ))}
              </div>
              <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                <button type="button" className="btn primary" style={{ flex: '1 1 120px' }}>
                  View details
                </button>
                <button type="button" className="btn secondary">
                  Compare
                </button>
              </div>
            </div>
          </article>
        ))}
      </div>
    </div>
  );
}
