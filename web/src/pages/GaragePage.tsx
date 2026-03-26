import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiJson } from '../api/client';
import { GlassSurface } from '../components/GlassSurface';
import { HoverLineChart } from '../components/HoverLineChart';
import { MiniLineChart, ScoreDonut } from '../components/charts';
import { IconCar } from '../components/icons';

type Vehicle = {
  vehicle_id: number;
  vehicle_model: string;
  vehicle_type: string;
  year: number | null;
};

type MetricKey = 'speed' | 'rpm' | 'fuel';

const DEMO_VEHICLES: Vehicle[] = [
  { vehicle_id: -1, vehicle_model: 'Tesla Model 3', vehicle_type: 'Electric', year: 2024 },
  { vehicle_id: -2, vehicle_model: 'Toyota Prius', vehicle_type: 'Hybrid', year: 2023 },
  { vehicle_id: -3, vehicle_model: 'Honda Civic', vehicle_type: 'Sedan', year: 2022 },
];

function clamp(n: number, a: number, b: number) {
  return Math.max(a, Math.min(b, n));
}

function mulberry32(seed: number) {
  // deterministic PRNG for stable dummy visuals
  let t = seed >>> 0;
  return function () {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function makeSeries(seed: number, length: number, min: number, max: number, volatility: number) {
  const rnd = mulberry32(seed);
  let v = min + (max - min) * (0.25 + rnd() * 0.5);
  const out: number[] = [];
  for (let i = 0; i < length; i++) {
    const drift = (rnd() - 0.5) * volatility;
    v = clamp(v + drift, min, max);
    v = clamp(v + Math.sin(i / 3) * volatility * 0.12, min, max);
    out.push(Number(v.toFixed(2)));
  }
  return out;
}

export function GaragePage() {
  const navigate = useNavigate();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [apiLoaded, setApiLoaded] = useState(false);

  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [metric, setMetric] = useState<MetricKey>('speed');

  const loadVehicles = useCallback(async () => {
    setBusy(true);
    setMsg(null);
    setApiLoaded(false);
    try {
      const v = await apiJson<Vehicle[]>('/vehicles');
      setVehicles(v);
    } catch (e) {
      setMsg(String(e));
      setVehicles([]);
    } finally {
      setBusy(false);
      setApiLoaded(true);
    }
  }, []);

  useEffect(() => {
    loadVehicles().catch(() => undefined);
  }, [loadVehicles]);

  const isDemo = apiLoaded && vehicles.length === 0;
  const displayedVehicles = isDemo ? DEMO_VEHICLES : vehicles;
  const realVehicleIds = useMemo(() => new Set(vehicles.map((v) => v.vehicle_id)), [vehicles]);

  const selectedVehicle = useMemo(
    () => displayedVehicles.find((v) => v.vehicle_id === selectedId) ?? null,
    [displayedVehicles, selectedId],
  );

  const selectedSeries = useMemo(() => {
    if (!selectedVehicle) return null;
    const seed = Math.abs(selectedVehicle.vehicle_id) * 1337 + 42;
    const speed = makeSeries(seed + 1, 28, 10, 95, 6);
    const rpm = makeSeries(seed + 2, 28, 1200, 4200, 160);
    const fuel = makeSeries(seed + 3, 28, 4.6, 11.8, 0.7);

    const rpmScaled = rpm.map((x) => ((x - 1200) / (4200 - 1200)) * 100);
    const fuelScaled = fuel.map((x) => ((x - 4.6) / (11.8 - 4.6)) * 100);
    return { speed, rpmScaled, fuelScaled };
  }, [selectedVehicle]);

  function openVehicle(v: Vehicle) {
    setSelectedId(v.vehicle_id);
    setMetric('speed');
  }

  async function addVehicle() {
    const model = window.prompt('Vehicle model', 'Honda Civic') ?? '';
    const type = window.prompt('Type (e.g. sedan, suv)', 'sedan') ?? '';
    const yearStr = window.prompt('Year (optional)', String(new Date().getFullYear())) ?? '';

    if (!model.trim()) return;

    const year = yearStr.trim() ? Number(yearStr) : undefined;

    setBusy(true);
    setMsg(null);
    try {
      await apiJson('/vehicles', {
        method: 'POST',
        body: JSON.stringify({
          vehicle_model: model.trim(),
          vehicle_type: type.trim() || 'sedan',
          year: year != null && Number.isFinite(year) ? year : null,
        }),
      });
      await loadVehicles();
      setMsg('Vehicle added.');
      setTimeout(() => setMsg(null), 3000);
    } catch (e) {
      setMsg(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <h1>Garage</h1>
        <p className="lead">Your cars, with premium insights and interactive telemetry previews.</p>
      </header>

      {msg && (
        <p className={msg.includes('added') ? 'banner ms-banner-ok' : msg.toLowerCase().includes('error') ? 'error' : 'banner'}>
          {msg}
        </p>
      )}

      <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', alignItems: 'center', marginBottom: '1.25rem' }}>
        <button type="button" className="btn primary" onClick={addVehicle} disabled={busy}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.55rem' }}>
            <IconCar /> Add vehicle
          </span>
        </button>
        <button
          type="button"
          className="btn ghost"
          onClick={() => loadVehicles().catch(() => undefined)}
          disabled={busy}
        >
          Refresh
        </button>
      </div>

      {isDemo && (
        <GlassSurface variant="light" borderRadius={16} backgroundOpacity={0.12} saturation={1.2} displace={0.1} className="mb-1">
          <div style={{ padding: '1rem' }}>
            <strong>Demo mode</strong>
            <div className="muted" style={{ marginTop: '0.5rem' }}>
              No vehicles found in the API yet. Showing dummy cars + dummy charts for the UI.
            </div>
          </div>
        </GlassSurface>
      )}

      <div className="ms-vehicle-grid">
        {displayedVehicles.map((v) => (
          <GlassSurface
            key={v.vehicle_id}
            variant="light"
            borderRadius={22}
            className="ms-vehicle-card"
            backgroundOpacity={0.12}
            saturation={1.35}
            displace={0.16}
          >
            <div className="ms-vehicle-img" />
            <div className="ms-vehicle-body">
              <div className="ms-vehicle-score" title="Vehicle year">
                {v.year ?? '—'}
              </div>
              <h3 style={{ margin: '0 0 0.25rem', fontSize: '1.05rem' }}>{v.vehicle_model}</h3>
              <p className="muted small" style={{ margin: 0 }}>
                {v.vehicle_type}
              </p>
              <div className="muted small" style={{ marginTop: '0.75rem', display: 'grid', gap: '0.35rem' }}>
                <span>Vehicle ID: {v.vehicle_id}</span>
              </div>

              <div style={{ marginTop: '0.95rem' }}>
                <MiniLineChart data={makeSeries(Math.abs(v.vehicle_id) * 99 + 7, 16, 15, 90, 6)} color="#2563eb" maxY={100} />
              </div>

              <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginTop: '1rem' }}>
                <button type="button" className="btn primary" style={{ flex: '1 1 140px' }} onClick={() => openVehicle(v)}>
                  View telemetry
                </button>
                <button
                  type="button"
                  className="btn secondary"
                  disabled={!realVehicleIds.has(v.vehicle_id)}
                  title={!realVehicleIds.has(v.vehicle_id) ? 'Demo data only. Add a real vehicle in the API.' : 'Open diagnostics'}
                  onClick={() => {
                    if (!realVehicleIds.has(v.vehicle_id)) return;
                    navigate(`/vehicle?vehicle_id=${v.vehicle_id}`);
                  }}
                >
                  Open diagnostics
                </button>
              </div>
            </div>
          </GlassSurface>
        ))}
      </div>

      {selectedVehicle && selectedSeries && (
        <div
          role="dialog"
          aria-modal="true"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) setSelectedId(null);
          }}
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.35)',
            backdropFilter: 'blur(10px)',
            WebkitBackdropFilter: 'blur(10px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 60,
            padding: 18,
          }}
        >
          <GlassSurface
            variant="dark"
            borderRadius={28}
            backgroundOpacity={0.66}
            saturation={1.15}
            displace={0.22}
            className="garage-telemetry-modal"
          >
            <div style={{ padding: '1.15rem' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '1rem' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                    <IconCar />
                    <div>
                      <div style={{ fontSize: 16, fontWeight: 900, lineHeight: 1.2 }}>{selectedVehicle.vehicle_model}</div>
                      <div style={{ color: 'rgba(250,250,250,0.72)', marginTop: 4, fontSize: 13 }}>
                        {selectedVehicle.vehicle_type} · {selectedVehicle.year ?? '—'}
                      </div>
                    </div>
                  </div>
                  <div style={{ color: 'rgba(250,250,250,0.72)', fontSize: 12, marginTop: 8 }}>
                    Preview charts are dummy data for now (UI + interactions).
                  </div>
                </div>

                <button
                  type="button"
                  className="btn ghost"
                  onClick={() => setSelectedId(null)}
                  style={{ borderColor: 'rgba(255,255,255,0.22)', color: 'rgba(255,255,255,0.9)' }}
                >
                  Close
                </button>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: '1.1rem', alignItems: 'start', marginTop: '1rem' }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.75rem' }}>
                    {(
                      [
                        { key: 'speed', label: 'Speed', color: '#2563eb' },
                        { key: 'rpm', label: 'RPM', color: '#14b8a6' },
                        { key: 'fuel', label: 'Fuel', color: '#f59e0b' },
                      ] as { key: MetricKey; label: string; color: string }[]
                    ).map((m) => {
                      const active = metric === m.key;
                      return (
                        <button
                          key={m.key}
                          type="button"
                          onClick={() => setMetric(m.key)}
                          className="btn"
                          style={{
                            padding: '0.55rem 0.95rem',
                            background: active ? m.color : 'rgba(255,255,255,0.08)',
                            borderColor: active ? m.color : 'rgba(255,255,255,0.18)',
                            color: active ? '#fff' : 'rgba(255,255,255,0.86)',
                            boxShadow: active ? undefined : 'none',
                          }}
                        >
                          {m.label}
                        </button>
                      );
                    })}
                  </div>

                  <HoverLineChart
                    data={metric === 'speed' ? selectedSeries.speed : metric === 'rpm' ? selectedSeries.rpmScaled : selectedSeries.fuelScaled}
                    color={metric === 'speed' ? '#2563eb' : metric === 'rpm' ? '#14b8a6' : '#f59e0b'}
                    maxY={100}
                    formatValue={(v) => {
                      if (metric === 'fuel') {
                        const fuel = v / 100 * (11.8 - 4.6) + 4.6;
                        return `${fuel.toFixed(1)} L/100km (est.)`;
                      }
                      return `${Math.round(v)} / 100`;
                    }}
                  />
                </div>

                <div style={{ display: 'grid', placeItems: 'center', gap: '0.75rem' }}>
                  <div style={{ width: 160, height: 160, borderRadius: 22, display: 'grid', placeItems: 'center' }}>
                    <ScoreDonut
                      value={
                        Math.round(
                          60 +
                            (metric === 'speed'
                              ? (selectedSeries.speed[selectedSeries.speed.length - 1] / 100) * 40
                              : metric === 'rpm'
                                ? (1 - selectedSeries.rpmScaled[selectedSeries.rpmScaled.length - 1] / 100) * 20 + 60
                                : (1 - selectedSeries.fuelScaled[selectedSeries.fuelScaled.length - 1] / 100) * 25 + 55),
                        )
                      }
                      size={140}
                    />
                    <div style={{ marginTop: '-0.85rem', textAlign: 'center' }}>
                      <div style={{ fontSize: 18, fontWeight: 900, color: '#fff' }}>Premium score</div>
                      <div style={{ color: 'rgba(250,250,250,0.72)', fontSize: 12, marginTop: 4 }}>Hover the graph</div>
                    </div>
                  </div>

                  <div style={{ color: 'rgba(250,250,250,0.78)', fontSize: 12, textTransform: 'uppercase', letterSpacing: '0.08em', fontWeight: 800 }}>
                    Quick stats (dummy)
                  </div>
                  {(() => {
                    const arr =
                      metric === 'speed'
                        ? selectedSeries.speed
                        : metric === 'rpm'
                          ? selectedSeries.rpmScaled
                          : selectedSeries.fuelScaled;
                    const avg = arr.reduce((a, b) => a + b, 0) / Math.max(1, arr.length);
                    const last = arr[arr.length - 1] ?? 0;
                    return (
                      <div style={{ display: 'grid', gap: 6, justifyItems: 'start' }}>
                        <div style={{ color: '#fff' }}>
                          Avg: {metric === 'fuel' ? (avg / 100) * (11.8 - 4.6) + 4.6 : avg} {metric === 'fuel' ? 'L/100km (est.)' : '/100'}
                        </div>
                        <div>
                          Latest: {metric === 'fuel' ? ((last / 100) * (11.8 - 4.6) + 4.6).toFixed(1) : Math.round(last)}{' '}
                          {metric === 'fuel' ? 'L/100km (est.)' : '/100'}
                        </div>
                      </div>
                    );
                  })()}
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.75rem', marginTop: '1rem' }}>
                <div />
                <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    className="btn primary"
                    disabled={!realVehicleIds.has(selectedVehicle.vehicle_id)}
                    onClick={() => {
                      if (!realVehicleIds.has(selectedVehicle.vehicle_id)) return;
                      setSelectedId(null);
                      navigate(`/vehicle?vehicle_id=${selectedVehicle.vehicle_id}`);
                    }}
                  >
                    Open diagnostics
                  </button>
                </div>
              </div>
            </div>
          </GlassSurface>
        </div>
      )}
    </div>
  );
}

