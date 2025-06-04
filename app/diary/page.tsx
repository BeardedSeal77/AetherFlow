'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function DiaryPage() {
  const router = useRouter()

  useEffect(() => {
    // Redirect to dashboard
    router.push('/diary/dashboard')
  }, [router])

  return (
    <div className="flex justify-center items-center h-48">
      <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-Rose"></div>
    </div>
  )
}