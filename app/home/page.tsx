'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import AuthCheck from '../auth/AuthCheck'

interface User {
  username: string
  name: string
  role: string
}

export default function HomePage() {
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)

  useEffect(() => {
    fetch('/api/auth/session', {
      credentials: 'include'
    })
      .then(res => res.json())
      .then(data => {
        if (data.user) {
          setUser(data.user)
        }
      })
      .catch(err => console.error('Failed to fetch session:', err))
  }, [])

  const quickActions = [
    {
      title: 'New Equipment Hire',
      description: 'Create a new equipment hire for a customer',
      icon: '🛠️',
      href: '/diary/new-interaction',
      color: 'bg-blue'
    },
    {
      title: 'View Diary',
      description: 'View and manage equipment hire diary',
      icon: '📅',
      href: '/diary',
      color: 'bg-green'
    },
    {
      title: 'Equipment Allocation',
      description: 'Allocate specific equipment to hires',
      icon: '⚡',
      href: '/allocation',
      color: 'bg-iris'
    },
    {
      title: 'Driver Tasks',
      description: 'View and manage driver delivery tasks',
      icon: '🚚',
      href: '/tasks',
      color: 'bg-gold'
    }
  ]

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <div className="text-center">
              <h1 className="text-3xl font-bold text-gold mb-2">
                Equipment Hire Management System
              </h1>
              {user && (
                <p className="text-subtle">
                  Welcome back, <span className="text-gold font-medium">{user.name}</span>
                  {user.role && <span className="text-subtle"> ({user.role})</span>}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-text mb-4">Quick Actions</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              {quickActions.map((action, index) => (
                <div
                  key={index}
                  onClick={() => router.push(action.href)}
                  className="bg-surface border border-highlight-low rounded-lg p-6 hover:border-gold cursor-pointer transition-colors"
                >
                  <div className="text-center">
                    <div className="text-4xl mb-3">{action.icon}</div>
                    <h3 className="font-semibold text-text mb-2">{action.title}</h3>
                    <p className="text-sm text-subtle">{action.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Recent Activity */}
          <div className="bg-surface border border-highlight-low rounded-lg p-6">
            <h2 className="text-xl font-semibold text-text mb-4">Recent Activity</h2>
            <div className="text-center py-8 text-subtle">
              <div className="text-4xl mb-3">📊</div>
              <p>Activity dashboard coming soon...</p>
            </div>
          </div>
        </div>
      </div>
    </AuthCheck>
  )
}