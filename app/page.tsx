'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function RootPage() {
  const router = useRouter()

  useEffect(() => {
    // Check if user is logged in
    fetch('/api/auth/session')
      .then(res => res.json())
      .then(data => {
        if (data.user) {
          router.push('/home')
        } else {
          router.push('/login')
        }
      })
      .catch(err => {
        console.error('Failed to fetch session:', err)
        router.push('/login')
      })
  }, [router])

  return (
    <div className="flex justify-center items-center h-screen">
      <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-rose"></div>
    </div>
  )
}