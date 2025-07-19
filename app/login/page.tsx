'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function LoginPage() {
  const router = useRouter()
  const [formData, setFormData] = useState({
    username: '',
    password: ''
  })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    // Check if user is already logged in
    checkSession()
  }, [])

  const checkSession = async () => {
    try {
      const response = await fetch('/api/auth/session', {
        credentials: 'include'
      })
      const data = await response.json()
      if (data.user) {
        router.push('/')
      }
    } catch (err) {
      // User not logged in, stay on login page
    }
  }

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    })
    setError('')
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify(formData)
      })

      const data = await response.json()

      if (data.success) {
        router.push('/')
      } else {
        setError(data.error || 'Login failed')
      }
    } catch (err) {
      setError('Connection error. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-base flex items-center justify-center">
      <div className="max-w-md w-full mx-4">
        <div className="bg-surface rounded-lg shadow-lg border border-highlight-low p-8">
          <div className="text-center mb-8">
            <div className="w-16 h-16 bg-gold rounded-full flex items-center justify-center mx-auto mb-4">
              <span className="text-base text-2xl font-bold">EH</span>
            </div>
            <h1 className="text-2xl font-bold text-gold">Equipment Hire System</h1>
            <p className="text-subtle mt-2">Sign in to your account</p>
          </div>

          {error && (
            <div className="mb-4 p-3 bg-red/20 border border-red/30 rounded-md">
              <p className="text-red text-sm">{error}</p>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label htmlFor="username" className="block text-sm font-medium text-text mb-2">
                Username
              </label>
              <input
                type="text"
                id="username"
                name="username"
                value={formData.username}
                onChange={handleChange}
                required
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
                placeholder="Enter your username"
              />
            </div>

            <div>
              <label htmlFor="password" className="block text-sm font-medium text-text mb-2">
                Password
              </label>
              <input
                type="password"
                id="password"
                name="password"
                value={formData.password}
                onChange={handleChange}
                required
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
                placeholder="Enter your password"
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue text-text py-3 px-4 rounded-md font-medium hover:bg-gold transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>

          <div className="mt-6 text-center">
            <div className="text-subtle text-sm">
              <p className="mb-2">Demo Accounts:</p>
              <div className="space-y-1 text-xs">
                <p><span className="text-gold">admin</span> / admin123</p>
                <p><span className="text-blue">operator</span> / op123</p>
                <p><span className="text-green">driver</span> / driver123</p>
                <p><span className="text-iris">manager</span> / mgr123</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}