export const TOKEN_KEY = 'peerlearn_token'
export const API_BASE_URL = '/api'

export async function api(path, options = {}) {
  const headers = { ...(options.body ? { 'Content-Type': 'application/json' } : {}), ...options.headers }
  const token = localStorage.getItem(TOKEN_KEY)
  if (token) headers.Authorization = `Bearer ${token}`
  let response
  try {
    response = await fetch(`${API_BASE_URL}${path}`, { ...options, headers })
  } catch {
    throw new Error('Could not reach PeerLearn. Check your connection and try again.')
  }
  if (response.status === 401) {
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem('peerlearn_user')
    if (window.location.pathname !== '/login') window.location.assign('/login')
    throw new Error('Your session expired. Please sign in again.')
  }
  if (response.status === 204) return null
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(body.error || `Request failed (${response.status}). Please try again.`)
  return body
}
