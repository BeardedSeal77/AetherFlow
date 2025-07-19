'use client'

import { useEffect, useState } from 'react'
import AuthCheck from '../../auth/AuthCheck'

interface User {
  username: string
  name: string
  role: string
}

interface Task {
  id: number
  title: string
  type: 'delivery' | 'collection' | 'quality_check' | 'maintenance'
  priority: 'urgent' | 'high' | 'normal' | 'low'
  status: 'pending' | 'in_progress' | 'completed'
  customer?: string
  equipment?: string
  due_time?: string
  location?: string
}

export default function DashboardPage() {
  const [user, setUser] = useState<User | null>(null)
  const [tasks, setTasks] = useState<Task[]>([])

  useEffect(() => {
    // Fetch user session
    fetch('/api/auth/session', {
      credentials: 'include'
    })
      .then(res => res.json())
      .then(data => {
        if (data.user) {
          setUser(data.user)
          // Fetch tasks based on user role
          loadTasksForUser(data.user)
        }
      })
      .catch(err => console.error('Failed to fetch session:', err))
  }, [])

  const loadTasksForUser = (user: User) => {
    // Mock tasks based on user role
    const mockTasks: Task[] = []
    
    if (user.role === 'driver') {
      mockTasks.push(
        {
          id: 1,
          title: 'Deliver Generator to Construction Site',
          type: 'delivery',
          priority: 'urgent',
          status: 'pending',
          customer: 'ABC Construction Ltd',
          equipment: 'Generator 5KVA (GEN14)',
          due_time: '09:00',
          location: '123 Construction Ave, Industrial Estate'
        },
        {
          id: 2,
          title: 'Collect Rammer from City Centre',
          type: 'collection',
          priority: 'high',
          status: 'pending',
          customer: 'City Contractors',
          equipment: '4 Stroke Rammer (R1001)',
          due_time: '14:30',
          location: '45 High Street, City Centre'
        }
      )
    } else if (user.role === 'operator') {
      mockTasks.push(
        {
          id: 3,
          title: 'Quality Check - Compactor',
          type: 'quality_check',
          priority: 'normal',
          status: 'pending',
          equipment: 'Plate Compactor (PC202)',
          due_time: '10:00'
        },
        {
          id: 4,
          title: 'Equipment Allocation Required',
          type: 'delivery',
          priority: 'high',
          status: 'pending',
          customer: 'Metro Building Services',
          due_time: '11:00'
        }
      )
    } else if (user.role === 'admin' || user.role === 'manager') {
      mockTasks.push(
        {
          id: 5,
          title: 'Review Daily Operations',
          type: 'maintenance',
          priority: 'normal',
          status: 'pending',
          due_time: '08:00'
        },
        {
          id: 6,
          title: 'Urgent Equipment Allocation',
          type: 'delivery',
          priority: 'urgent',
          status: 'pending',
          customer: 'Emergency Services Contract',
          due_time: 'ASAP'
        }
      )
    }
    
    setTasks(mockTasks)
  }

  const getTaskIcon = (type: string) => {
    switch (type) {
      case 'delivery': return '🚚'
      case 'collection': return '📦'
      case 'quality_check': return '🔍'
      case 'maintenance': return '🔧'
      default: return '📋'
    }
  }

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent': return 'border-red bg-red/10 text-red'
      case 'high': return 'border-gold bg-gold/10 text-gold'
      case 'normal': return 'border-blue bg-blue/10 text-blue'
      case 'low': return 'border-subtle bg-subtle/10 text-subtle'
      default: return 'border-subtle bg-subtle/10 text-subtle'
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending': return 'bg-gold/20 text-gold'
      case 'in_progress': return 'bg-blue/20 text-blue'
      case 'completed': return 'bg-green/20 text-green'
      default: return 'bg-subtle/20 text-subtle'
    }
  }

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div className="flex justify-between items-center">
              <div>
                <h1 className="text-2xl font-bold text-gold">My Dashboard</h1>
                {user && (
                  <p className="text-subtle mt-1">
                    Welcome {user.name} - {user.role} tasks for today
                  </p>
                )}
              </div>
              <div className="text-right">
                <div className="text-sm text-subtle">Today</div>
                <div className="text-lg font-semibold text-text">
                  {new Date().toLocaleDateString('en-GB', { 
                    weekday: 'long', 
                    year: 'numeric', 
                    month: 'long', 
                    day: 'numeric' 
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Tasks */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {tasks.length === 0 ? (
            <div className="bg-surface border border-highlight-low rounded-lg p-8 text-center">
              <div className="text-4xl mb-4">✅</div>
              <h3 className="text-lg font-semibold text-text mb-2">No Tasks Today</h3>
              <p className="text-subtle">You have no tasks assigned for today. Check back later.</p>
            </div>
          ) : (
            <div className="space-y-4">
              <h2 className="text-xl font-semibold text-text">Your Tasks</h2>
              
              {tasks.map((task) => (
                <div
                  key={task.id}
                  className={`bg-surface border-2 rounded-lg p-6 ${getPriorityColor(task.priority)}`}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex items-start space-x-4">
                      <div className="text-2xl">{getTaskIcon(task.type)}</div>
                      <div className="flex-1">
                        <h3 className="font-semibold text-text text-lg">{task.title}</h3>
                        {task.customer && (
                          <p className="text-subtle mt-1">Customer: {task.customer}</p>
                        )}
                        {task.equipment && (
                          <p className="text-subtle">Equipment: {task.equipment}</p>
                        )}
                        {task.location && (
                          <p className="text-subtle">Location: {task.location}</p>
                        )}
                      </div>
                    </div>
                    
                    <div className="flex flex-col items-end space-y-2">
                      <span className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(task.status)}`}>
                        {task.status.replace('_', ' ').toUpperCase()}
                      </span>
                      {task.due_time && (
                        <div className="text-sm text-subtle">Due: {task.due_time}</div>
                      )}
                      <span className={`px-2 py-1 rounded text-xs font-medium ${getPriorityColor(task.priority)}`}>
                        {task.priority.toUpperCase()}
                      </span>
                    </div>
                  </div>
                  
                  <div className="mt-4 flex space-x-3">
                    <button className="px-4 py-2 bg-gold text-base rounded-md hover:bg-gold/80 transition-colors">
                      View Details
                    </button>
                    {task.status === 'pending' && (
                      <button className="px-4 py-2 bg-blue text-base rounded-md hover:bg-blue/80 transition-colors">
                        Start Task
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </AuthCheck>
  )
}