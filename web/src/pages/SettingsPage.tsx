import { type FormEvent, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { IconCar } from '../components/icons';
import { GlassSurface } from '../components/GlassSurface';

type UserBrief = { user_id: number; name: string; email: string };

function IconUser() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}

function IconBell() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

export function SettingsPage() {
  const { user } = useAuth();
  const k = user ? `${user.user_id}-${user.email}` : 'anon';
  return <SettingsPageBody key={k} user={user} />;
}

function SettingsPageBody({ user }: { user: UserBrief | null }) {
  const [name, setName] = useState(user?.name ?? '');
  const [email, setEmail] = useState(user?.email ?? '');
  const [make, setMake] = useState('Honda');
  const [model, setModel] = useState('Civic');
  const [year, setYear] = useState('2024');
  const [notifTrips, setNotifTrips] = useState(true);
  const [notifWeather, setNotifWeather] = useState(true);
  const [saved, setSaved] = useState<string | null>(null);

  function onProfile(e: FormEvent) {
    e.preventDefault();
    setSaved('Profile changes are demo-only until wired to the API.');
    setTimeout(() => setSaved(null), 4000);
  }

  function onVehicle(e: FormEvent) {
    e.preventDefault();
    setSaved('Vehicle settings saved locally for this demo.');
    setTimeout(() => setSaved(null), 4000);
  }

  return (
    <div className="page">
      <header className="page-header">
        <h1>Settings</h1>
        <p className="lead">Manage your account and preferences.</p>
      </header>
      {saved && <p className="banner ms-banner-ok">{saved}</p>}

      <GlassSurface variant="light" borderRadius={16} className="ms-settings-card" backgroundOpacity={0.12} saturation={1.35} displace={0.18}>
        <h2>
          <IconUser /> Profile settings
        </h2>
        <form className="form" onSubmit={onProfile}>
          <label className="field">
            <span>Full name</span>
            <input className="ms-input" value={name} onChange={(e) => setName(e.target.value)} />
          </label>
          <label className="field">
            <span>Email</span>
            <input className="ms-input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          </label>
          <button type="submit" className="btn primary">
            Save changes
          </button>
        </form>
      </GlassSurface>

      <GlassSurface variant="light" borderRadius={16} className="ms-settings-card" backgroundOpacity={0.12} saturation={1.35} displace={0.18}>
        <h2>
          <IconCar /> Vehicle settings
        </h2>
        <form className="form" onSubmit={onVehicle}>
          <label className="field">
            <span>Vehicle make</span>
            <input className="ms-input" value={make} onChange={(e) => setMake(e.target.value)} />
          </label>
          <label className="field">
            <span>Vehicle model</span>
            <input className="ms-input" value={model} onChange={(e) => setModel(e.target.value)} />
          </label>
          <label className="field">
            <span>Year</span>
            <input className="ms-input" value={year} onChange={(e) => setYear(e.target.value)} />
          </label>
          <button type="submit" className="btn primary">
            Update vehicle
          </button>
        </form>
      </GlassSurface>

      <GlassSurface variant="light" borderRadius={16} className="ms-settings-card" backgroundOpacity={0.12} saturation={1.35} displace={0.18}>
        <h2>
          <IconBell /> Notifications
        </h2>
        <label className="ms-check-row">
          <input type="checkbox" checked={notifTrips} onChange={(e) => setNotifTrips(e.target.checked)} />
          Trip summaries and driving alerts
        </label>
        <label className="ms-check-row">
          <input type="checkbox" checked={notifWeather} onChange={(e) => setNotifWeather(e.target.checked)} />
          Weather advisories for saved routes
        </label>
      </GlassSurface>
    </div>
  );
}
