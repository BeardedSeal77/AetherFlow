'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import TaskBoard from '@/components/TaskBoard'

interface Task {
  id: string;
  title: string;
  status: string;
}

interface ApiResponse {
  data: any;
  status: number;
  statusText: string;
  headers: Record<string, string>;
}

export default function DashboardPage() {
  const router = useRouter()
  const [tasks, setTasks] = useState<Task[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [debugInfo, setDebugInfo] = useState<ApiResponse | null>(null)

  useEffect(() => {
    // Check if user is logged in
    fetch('/api/auth/session')
      .then(async res => {
        const sessionData = await res.json()
        
        // Store debug info
        setDebugInfo({
          data: sessionData,
          status: res.status,
          statusText: res.statusText,
          headers: Object.fromEntries(res.headers.entries())
        })
        
        if (!sessionData.user) {
          setError('Not authenticated. Please log in.')
          router.push('/login')
          return null
        }
        
        console.log('Session data:', sessionData)
        
        // Fetch tasks - now we can continue because we have a valid session
        return fetch('/api/diary/dashboard')
      })
      .then(async res => {
        if (!res) return null
        
        // Store response info for debugging
        const responseText = await res.text()
        console.log('Raw API response:', responseText)
        
        let jsonData = null
        try {
          // Try to parse JSON response
          if (responseText) {
            jsonData = JSON.parse(responseText)
          }
        } catch (parseError) {
          console.error('JSON parse error:', parseError)
          setError(`Failed to parse response: ${parseError}. Raw response: ${responseText}`)
        }
        
        return jsonData
      })
      .then(data => {
        if (data) {
          console.log('Parsed task data:', data)
          setTasks(data.tasks || [])
        }
        setIsLoading(false)
      })
      .catch(err => {
        console.error('Failed to fetch tasks:', err)
        setError(`Failed to fetch tasks: ${err.message}`)
        setIsLoading(false)
      })
  }, [router])

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-Rose"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="p-4">
        <div className="bg-red-50 border border-red-200 rounded-md p-4 mb-4">
          <h3 className="text-red-800 font-medium">Error</h3>
          <p className="text-red-700">{error}</p>
        </div>
        
        {debugInfo && (
          <div className="bg-gray-50 border border-gray-200 rounded-md p-4 mt-4">
            <h3 className="font-medium mb-2">Debug Information</h3>
            <pre className="bg-gray-100 p-2 rounded text-sm overflow-auto max-h-64">
              {JSON.stringify(debugInfo, null, 2)}
            </pre>
          </div>
        )}
      </div>
    )
  }

  return (
    <div>
      <TaskBoard tasks={tasks} />
      
      {/* Debug section for development */}
      <div className="mt-8 p-4 bg-gray-50 border border-gray-200 rounded-md">
        <h3 className="font-medium mb-2">Debug Information</h3>
        <p className="mb-2">Task count: {tasks.length}</p>
        <details>
          <summary className="cursor-pointer text-blue-600">Raw tasks data</summary>
          <pre className="bg-gray-100 p-2 rounded text-sm overflow-auto max-h-64 mt-2">
            {JSON.stringify(tasks, null, 2)}
          </pre>
        </details>
      </div>
    </div>
  )
}