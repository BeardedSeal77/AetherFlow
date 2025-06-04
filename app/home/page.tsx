'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function HomePage() {
  const router = useRouter()

  useEffect(() => {
    // Check if user is logged in
    fetch('/api/auth/session')
      .then(res => res.json())
      .then(data => {
        if (!data.user) {
          router.push('/login')
        }
      })
      .catch(err => {
        console.error('Failed to fetch session:', err)
        router.push('/login')
      })
  }, [router])

  return (
    <div className="text-center mt-20">
      <h1 className="text-3xl font-semibold text-text">Welcome Home</h1>
      <p className="text-text mt-4">This is your homepage after login.</p>
    </div>
  )
}