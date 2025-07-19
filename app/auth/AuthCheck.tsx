'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'

interface User {
  username: string
  name: string
  role: string
}

interface AuthCheckProps {
  children: React.ReactNode
}

export default function AuthCheck({ children }: AuthCheckProps) {
  const router = useRouter()
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    checkAuth()
  }, [])

  const checkAuth = async () => {
    try {
      const response = await fetch('/api/auth/session', {
        credentials: 'include'
      })
      const data = await response.json()
      
      if (data.user) {
        setUser(data.user)
      } else {
        router.push('/login')
      }
    } catch (error) {
      console.error('Auth check failed:', error)
      router.push('/login')
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-base flex items-center justify-center">
        <div className="text-center">
          <div className="w-16 h-16 bg-gold rounded-full flex items-center justify-center mx-auto mb-4">
            <div className="w-8 h-8 border-4 border-base border-t-transparent rounded-full animate-spin"></div>
          </div>
          <p className="text-subtle">Loading...</p>
        </div>
      </div>
    )
  }

  return <>{children}</>
}