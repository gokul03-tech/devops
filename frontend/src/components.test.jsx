import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './AuthContext'
import { Layout, ProtectedRoute } from './components'
import { AuthPage, MatchCard, SessionActions } from './pages'
import { api } from './api/client'

vi.mock('./api/client', () => ({ TOKEN_KEY: 'peerlearn_token', api: vi.fn() }))
beforeEach(() => { localStorage.clear(); vi.clearAllMocks() })

describe('authentication and protected routing', () => {
  it('renders a login form and stores successful credentials', async () => {
    api.mockResolvedValue({ token: 'token-1', user: { id: 1, name: 'Ari', email: 'ari@example.edu' } })
    render(<AuthProvider><MemoryRouter initialEntries={['/login']}><Routes><Route path="/login" element={<AuthPage mode="login" />} /><Route path="/" element={<p>Dashboard</p>} /></Routes></MemoryRouter></AuthProvider>)
    fireEvent.change(screen.getByLabelText('Campus email'), { target: { value: 'ari@example.edu' } })
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'password123' } })
    fireEvent.click(screen.getByRole('button', { name: /step back in/i }))
    expect(await screen.findByText('Dashboard')).toBeInTheDocument()
    expect(localStorage.getItem('peerlearn_token')).toBe('token-1')
  })
  it('redirects signed-out visitors to login', () => {
    render(<MemoryRouter initialEntries={['/']}><Routes><Route path="/login" element={<p>Sign in screen</p>} /><Route element={<ProtectedRoute />}><Route path="/" element={<p>Private dashboard</p>} /></Route></Routes></MemoryRouter>)
    expect(screen.getByText('Sign in screen')).toBeInTheDocument()
  })
  it('shows authenticated navigation', () => {
    localStorage.setItem('peerlearn_token', 'test')
    render(<AuthProvider><MemoryRouter><Layout /></MemoryRouter></AuthProvider>)
    expect(screen.getByText('Find partners')).toBeInTheDocument()
  })
})

describe('partner match and session actions', () => {
  const person = { id: 2, name: 'Sam Lee', department: 'Design', year: '3', availability: ['Weekends'], match_type: 'Mutual Exchange', score: 4 }
  it('shows the mutual exchange badge on a match card', () => {
    render(<MemoryRouter><MatchCard person={person} onRequest={vi.fn()} /></MemoryRouter>)
    expect(screen.getByText(/Mutual Exchange/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /request a session/i })).toBeInTheDocument()
  })
  it('shows only actions valid for the incoming pending session', () => {
    const onAction = vi.fn()
    render(<SessionActions session={{ id: 5, partner_id: 2, status: 'Pending' }} currentUserId={2} onAction={onAction} />)
    expect(screen.getByRole('button', { name: 'Accept' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Reject' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Cancel' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Mark complete' })).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Reject' }))
    expect(onAction).toHaveBeenCalledWith(5, 'reject')
  })
})
