import { createContext, useContext, useMemo, useState } from 'react'
import { TOKEN_KEY, api } from './api/client'

const AuthContext = createContext(null)
export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem('peerlearn_user') || 'null') } catch { return null }
  })
  async function signIn(credentials, mode = 'login') {
    const result = await api(`/auth/${mode}`, { method: 'POST', body: JSON.stringify(credentials) })
    localStorage.setItem(TOKEN_KEY, result.token)
    localStorage.setItem('peerlearn_user', JSON.stringify(result.user))
    setUser(result.user)
    return result.user
  }
  function signOut() {
    localStorage.removeItem(TOKEN_KEY); localStorage.removeItem('peerlearn_user'); setUser(null)
  }
  const value = useMemo(() => ({ user, setUser, signIn, signOut, authenticated: Boolean(localStorage.getItem(TOKEN_KEY)) }), [user])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
export function useAuth() { return useContext(AuthContext) }
