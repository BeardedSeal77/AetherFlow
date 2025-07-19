// app/components/Navbar.tsx
'use client'

import { useState, useEffect } from 'react'
import { useRouter, usePathname } from 'next/navigation'
import Link from 'next/link'

interface User {
  user_id: number
  name: string
  role: string
}

const MAIN_NAV_ITEMS = [
  { key: 'diary', url: '/diary', displayName: 'Diary' },
  { key: 'equipment', url: '/equipment', displayName: 'Equipment' },
  { key: 'customers', url: '/customers', displayName: 'Customers' },
  { key: 'reports', url: '/reports', displayName: 'Reports' },
  { key: 'settings', url: '/settings', displayName: 'Settings' }
]

export default function Navbar() {
  const router = useRouter()
  const pathname = usePathname()
  const [currentUser, setCurrentUser] = useState<User | null>(null)

  useEffect(() => {
    checkAuthStatus()
  }, [])

  const checkAuthStatus = async () => {
    try {
      const response = await fetch('/api/auth/me', {
        credentials: 'include'
      })
      if (response.ok) {
        const user = await response.json()
        setCurrentUser(user)
      }
    } catch (error) {
      console.error('Auth check failed:', error)
    }
  }

  const handleLogout = async () => {
    try {
      await fetch('/api/auth/logout', {
        method: 'POST',
        credentials: 'include'
      })
      setCurrentUser(null)
      router.push('/login')
    } catch (error) {
      console.error('Logout failed:', error)
    }
  }

  const isActiveMainNav = (url: string) => {
    if (url === '/') return pathname === '/'
    return pathname.startsWith(url)
  }

  return (
    <div className="relative">
      <div className="bg-surface shadow-lg border-b border-highlight-low">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            {/* Logo */}
            <div className="flex-shrink-0">
              <Link href="/" className="text-2xl font-bold text-gold hover:text-yellow transition-colors">
                ToolHire
              </Link>
            </div>
            
            {/* Main Navigation */}
            <div className="flex space-x-1">
              {MAIN_NAV_ITEMS.map((item) => (
                <button
                  key={item.key}
                  onClick={() => router.push(item.url)}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                    isActiveMainNav(item.url)
                      ? 'bg-gold/30 text-gold border border-gold/20' 
                      : 'text-text hover:bg-overlay hover:text-gold'
                  }`}
                >
                  {item.displayName}
                </button>
              ))}
            </div>
            
            {/* User Menu */}
            <div className="flex items-center gap-4">
              {currentUser ? (
                <>
                  <span className="text-sm text-text">
                    <strong>{currentUser.name}</strong> ({currentUser.role})
                  </span>
                  <button
                    onClick={handleLogout}
                    className="px-4 py-2 rounded-xl bg-overlay text-base hover:bg-gold transition-colors"
                  >
                    Logout
                  </button>
                </>
              ) : (
                <Link
                  href="/login"
                  className="px-4 py-2 rounded-xl bg-green text-base hover:bg-gold transition-colors"
                >
                  Login
                </Link>
              )}
            </div>
          </div>
        </div>
        
        {/* Main Ribbon Container (Level 2) */}
        <div 
          id="ribbon-container"
          className="bg-overlay/80 backdrop-blur-md border-t border-highlight/20 shadow-inner"
          style={{ display: 'none' }}
        >
          {/* Content will be injected here by main Ribbon component */}
        </div>
        
        {/* Sub-Ribbon Container (Level 3 - for section-specific navigation) */}
        <div 
          id="sub-ribbon-container"
          className="border-t border-highlight-low/30"
          style={{ display: 'none' }}
        >
          {/* Content will be injected here by section layouts */}
        </div>
      </div>
    </div>
  )
}