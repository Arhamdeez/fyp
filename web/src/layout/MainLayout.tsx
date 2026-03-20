import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  IconBrandCar,
  IconCar,
  IconChart,
  IconDashboard,
  IconLogout,
  IconRoute,
  IconSettings,
  IconStar,
} from '../components/icons';

const nav = [
  { to: '/', label: 'Dashboard', end: true, Icon: IconDashboard },
  { to: '/vehicle', label: 'Vehicle Data', Icon: IconCar },
  { to: '/analysis', label: 'Driving Analysis', Icon: IconChart },
  { to: '/routes', label: 'Route Recommendations', Icon: IconRoute },
  { to: '/recommendations', label: 'Vehicle Recommendations', Icon: IconStar },
  { to: '/settings', label: 'Settings', Icon: IconSettings },
];

export function MainLayout() {
  const { user, logout } = useAuth();
  const display = (user?.name ?? user?.email ?? 'Guest').trim();
  const initial = display.charAt(0).toUpperCase();

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">
            <IconBrandCar />
          </div>
          <div>
            <strong>Momentum</strong>
            <div className="brand-sub">Smart Insights</div>
          </div>
        </div>
        <nav className="nav">
          {nav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => (isActive ? 'nav-link active' : 'nav-link')}
            >
              <item.Icon />
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="sidebar-user">
            <div className="sidebar-user-avatar" aria-hidden>
              {initial}
            </div>
            <div className="sidebar-user-meta">
              <span className="sidebar-user-label">Signed in</span>
              <span className="sidebar-user-name">{display}</span>
            </div>
          </div>
          <button type="button" className="btn-logout" onClick={logout}>
            <IconLogout />
            Logout
          </button>
        </div>
      </aside>
      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
