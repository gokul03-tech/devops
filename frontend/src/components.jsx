import { Link, NavLink, Navigate, Outlet, useNavigate } from 'react-router-dom'
import { TOKEN_KEY } from './api'

export function ProtectedRoute() {
  return localStorage.getItem(TOKEN_KEY) ? <Outlet /> : <Navigate to="/login" replace />
}

export function Layout() {
  const navigate = useNavigate()
  const links = [['/', 'Overview'], ['/profile', 'My profile'], ['/partners', 'Find partners'], ['/sessions', 'Sessions'], ['/history', 'Reviews & history']]
  return <div className="app-shell">
    <aside className="sidebar"><Link className="brand" to="/">peer<span>learn</span><b>✦</b></Link>
      <p className="side-label">YOUR CAMPUS</p><nav>{links.map(([to, label]) => <NavLink end={to === '/'} key={to} to={to} className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}><span className="nav-dot" />{label}</NavLink>)}</nav>
      <div className="sidebar-note"><span className="sparkle">✦</span><strong>Good things happen<br />when we learn together.</strong><small>Teach something. Learn something. Meet someone new.</small></div>
      <button className="text-button signout" onClick={() => { localStorage.removeItem(TOKEN_KEY); navigate('/login') }}>↗ &nbsp; Sign out</button>
    </aside>
    <div className="main-column"><header className="topbar"><div className="breadcrumb">PEERLEARN <span>/</span> <b>YOUR SPACE</b></div><div className="avatar">PL</div></header><main><Outlet /></main><footer>MADE FOR CURIOUS MINDS <span>✦</span> LEARN FROM EACH OTHER</footer></div>
  </div>
}

export function PageHeader({ eyebrow, title, description, action }) {
  return <div className="page-header"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1>{description && <p className="muted header-copy">{description}</p>}</div>{action}</div>
}

export function Alert({ error }) { return error ? <div className="alert" role="alert">{error}</div> : null }
export function Loading() { return <div className="loading">Just a moment<span> · · ·</span></div> }
export function Empty({ children }) { return <div className="empty-state"><span>✳</span><p>{children}</p></div> }
