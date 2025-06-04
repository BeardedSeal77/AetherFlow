'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { useEffect } from 'react'
import { createPortal } from 'react-dom'

export default function DiaryLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const pathname = usePathname()
  const router = useRouter()

  // The content to be rendered in the second navbar
  const SecondNavContent = () => (
    <div className="flex space-x-4 px-6 py-4">
      <Link
        href="/diary/dashboard"
        className={`px-4 py-2 rounded-xl text-sm font-medium transition-colors ${
          pathname === '/diary' || pathname === '/diary/dashboard'
            ? 'bg-gold/30'
            : 'hover:bg-overlay'
        }`}
        onClick={(e) => {
          e.preventDefault()
          router.push('/diary/dashboard')
        }}
      >
        Dashboard
      </Link>
      <Link
        href="/diary/drivers"
        className={`px-4 py-2 rounded-xl text-sm font-medium transition-colors ${
          pathname === '/diary/drivers'
            ? 'bg-gold/30'
            : 'hover:bg-overlay'
        }`}
        onClick={(e) => {
          e.preventDefault()
          router.push('/diary/drivers') 
        }}
      >
        Drivers Schedule
      </Link>
    </div>
  )

  useEffect(() => {
    // Show the second navbar container when component mounts
    const container = document.getElementById('second-level-navbar-container')
    if (container) {
      container.style.display = 'block'
    }
    
    // Hide the container when component unmounts
    return () => {
      const container = document.getElementById('second-level-navbar-container')
      if (container) {
        container.style.display = 'none'
      }
    }
  }, [])

  return (
    <>
      {typeof window !== 'undefined' && document.getElementById('second-level-navbar-container') && 
        createPortal(<SecondNavContent />, document.getElementById('second-level-navbar-container')!)}
      <div className="mt-4">
        {children}
      </div>
    </>
  )
}