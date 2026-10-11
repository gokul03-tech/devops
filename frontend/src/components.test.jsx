import { describe, expect, it, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { Layout, ProtectedRoute } from './components'

describe('application shell and route protection', () => {
  beforeEach(() => localStorage.clear())
  it('sends signed-out visitors to login', () => {
    render(<MemoryRouter initialEntries={['/']}><Routes><Route path="/login" element={<p>Sign in screen</p>} /><Route element={<ProtectedRoute />}><Route path="/" element={<p>Private dashboard</p>} /></Route></Routes></MemoryRouter>)
    expect(screen.getByText('Sign in screen')).toBeInTheDocument()
  })
  it('shows navigation for an authenticated student', () => {
    localStorage.setItem('peerlearn_token', 'test')
    render(<MemoryRouter><Layout /></MemoryRouter>)
    expect(screen.getByText('Find partners')).toBeInTheDocument()
    expect(screen.getByText('Reviews & history')).toBeInTheDocument()
  })
})
