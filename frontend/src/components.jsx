import { Link, NavLink, Navigate, Outlet, useNavigate } from 'react-router-dom'
import { TOKEN_KEY } from './api/client'
import { useAuth } from './AuthContext'

export function ProtectedRoute() { return localStorage.getItem(TOKEN_KEY) ? <Outlet /> : <Navigate to="/login" replace /> }
export function Button({ children, variant = 'primary', className = '', ...props }) { return <button className={`button ${variant} ${className}`} {...props}>{children}</button> }
export function Card({ children, className = '' }) { return <section className={`panel ${className}`}>{children}</section> }
export function Badge({ children, status, className = '' }) {
  const tone = status ? `status-${String(status).toLowerCase()}` : ''
  return <span className={`badge ${tone} ${className}`.trim()}>{children}</span>
}
export function Modal({ title, children, onClose }) {
  return <div className="modal-backdrop" role="presentation" onMouseDown={e => e.target === e.currentTarget && onClose()}><section role="dialog" aria-modal="true" aria-label={title} className="modal"><button className="modal-close" aria-label="Close" onClick={onClose}>×</button><h2>{title}</h2>{children}</section></div>
}
export function Spinner({ label = 'Loading' }) { return <div className="loading" role="status"><span className="spinner" />{label}…</div> }
export function ErrorMessage({ error }) { return error ? <div className="alert" role="alert">{error}</div> : null }
export function EmptyState({ children }) { return <div className="empty-state"><span>✳</span><p>{children}</p></div> }
export const Alert = ErrorMessage
export const Loading = Spinner
export const Empty = EmptyState
export function PageHeader({ eyebrow, title, description, action }) { return <div className="page-header"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1>{description && <p className="muted header-copy">{description}</p>}</div>{action}</div> }
export function Navbar() {
  const { signOut } = useAuth(); const navigate = useNavigate()
  const links = [['/', 'Overview'], ['/profile', 'My profile'], ['/partners', 'Find partners'], ['/sessions', 'Sessions'], ['/history', 'Reviews & history']]
  return <aside className="sidebar"><Link className="brand" to="/">peer<span>learn</span><b>✦</b></Link><p className="side-label">YOUR CAMPUS</p><nav>{links.map(([to, label]) => <NavLink end={to === '/'} key={to} to={to} className={({ isActive }) => `nav-link ${isActive ? 'active' : ''}`}><span className="nav-dot" />{label}</NavLink>)}</nav><div className="sidebar-note"><span className="sparkle">✦</span><strong>Good things happen<br />when we learn together.</strong><small>Teach something. Learn something. Meet someone new.</small></div><button className="text-button signout" onClick={() => { signOut(); navigate('/login') }}>↗ &nbsp; Sign out</button></aside>
}
export function Layout() {
  return <div className="app-shell"><Navbar /><div className="main-column"><header className="topbar"><div className="breadcrumb">PEERLEARN <span>/</span> <b>YOUR SPACE</b></div><div className="avatar">PL</div></header><main><Outlet /></main><footer>MADE FOR CURIOUS MINDS <span>✦</span> LEARN FROM EACH OTHER</footer></div></div>
}
