import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { api, TOKEN_KEY } from './client'

describe('API client', () => {
  beforeEach(() => {
    localStorage.clear()
    vi.stubGlobal('fetch', vi.fn())
    window.history.replaceState({}, '', '/login')
  })
  afterEach(() => {
    vi.unstubAllGlobals()
    window.history.replaceState({}, '', '/')
  })

  it('attaches the saved JWT and uses the /api base path', async () => {
    localStorage.setItem(TOKEN_KEY, 'session-token')
    fetch.mockResolvedValue(new Response('{"status":"ok"}', { status: 200 }))

    await expect(api('/health')).resolves.toEqual({ status: 'ok' })
    expect(fetch).toHaveBeenCalledWith('/api/health', expect.objectContaining({
      headers: expect.objectContaining({ Authorization: 'Bearer session-token' }),
    }))
  })

  it('clears local auth on 401 and preserves the API error message', async () => {
    localStorage.setItem(TOKEN_KEY, 'expired-token')
    localStorage.setItem('peerlearn_user', '{"id":1}')
    fetch.mockResolvedValue(new Response('{"error":"invalid email or password"}', { status: 401 }))

    await expect(api('/auth/login', { method: 'POST', body: '{}' })).rejects.toThrow('invalid email or password')
    expect(localStorage.getItem(TOKEN_KEY)).toBeNull()
    expect(localStorage.getItem('peerlearn_user')).toBeNull()
  })
})
