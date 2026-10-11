import React from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Layout, ProtectedRoute } from './components'
import { AuthPage, Dashboard, History, Partners, Profile, Sessions } from './pages'
import './styles.css'

function App() {
  return <BrowserRouter><Routes>
    <Route path="/login" element={<AuthPage mode="login" />} />
    <Route path="/register" element={<AuthPage mode="register" />} />
    <Route element={<ProtectedRoute />}><Route element={<Layout />}>
      <Route index element={<Dashboard />} /><Route path="profile" element={<Profile />} />
      <Route path="partners" element={<Partners />} /><Route path="sessions" element={<Sessions />} />
      <Route path="history" element={<History />} />
    </Route></Route>
    <Route path="*" element={<Navigate to="/" replace />} />
  </Routes></BrowserRouter>
}

createRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>)
