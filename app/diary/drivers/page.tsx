'use client'

import { useEffect, useState } from 'react'
import AuthCheck from '../../auth/AuthCheck'

interface Driver {
  id: number
  name: string
  status: 'available' | 'on_delivery' | 'on_collection' | 'break' | 'offline'
  current_task?: string
  location?: string
  next_task_time?: string
  phone: string
  vehicle: string
}

interface ScheduleEntry {
  time: string
  driver: string
  task_type: 'delivery' | 'collection'
  customer: string
  equipment: string
  location: string
  status: 'pending' | 'in_progress' | 'completed' | 'delayed'
}

export default function DriversSchedulePage() {
  const [drivers, setDrivers] = useState<Driver[]>([])
  const [schedule, setSchedule] = useState<ScheduleEntry[]>([])

  useEffect(() => {
    // Load mock driver data
    loadDriverData()
    loadScheduleData()
  }, [])

  const loadDriverData = () => {
    const mockDrivers: Driver[] = [
      {
        id: 1,
        name: 'Mike Johnson',
        status: 'on_delivery',
        current_task: 'Delivering Generator to ABC Construction',
        location: 'Industrial Estate',
        next_task_time: '11:30',
        phone: '07700 900123',
        vehicle: 'VAN-001'
      },
      {
        id: 2,
        name: 'Sarah Williams',
        status: 'available',
        location: 'Depot',
        next_task_time: '10:00',
        phone: '07700 900456',
        vehicle: 'VAN-002'
      },
      {
        id: 3,
        name: 'David Brown',
        status: 'on_collection',
        current_task: 'Collecting Rammer from City Centre',
        location: 'City Centre',
        next_task_time: '15:00',
        phone: '07700 900789',
        vehicle: 'VAN-003'
      },
      {
        id: 4,
        name: 'Emma Davis',
        status: 'break',
        location: 'Depot',
        next_task_time: '13:00',
        phone: '07700 900012',
        vehicle: 'VAN-004'
      }
    ]
    setDrivers(mockDrivers)
  }

  const loadScheduleData = () => {
    const mockSchedule: ScheduleEntry[] = [
      {
        time: '08:00',
        driver: 'Mike Johnson',
        task_type: 'delivery',
        customer: 'ABC Construction Ltd',
        equipment: 'Generator 5KVA',
        location: 'Industrial Estate',
        status: 'completed'
      },
      {
        time: '09:30',
        driver: 'Sarah Williams',
        task_type: 'delivery',
        customer: 'Metro Building Services',
        equipment: 'Plate Compactor',
        location: 'City Centre',
        status: 'in_progress'
      },
      {
        time: '10:00',
        driver: 'David Brown',
        task_type: 'collection',
        customer: 'City Contractors',
        equipment: '4 Stroke Rammer',
        location: 'High Street',
        status: 'pending'
      },
      {
        time: '11:30',
        driver: 'Mike Johnson',
        task_type: 'delivery',
        customer: 'Johnson & Partners',
        equipment: 'Extension Cables x3',
        location: 'Business Park',
        status: 'pending'
      },
      {
        time: '13:00',
        driver: 'Emma Davis',
        task_type: 'collection',
        customer: 'Emergency Services',
        equipment: 'Lighting Tower',
        location: 'Town Hall',
        status: 'pending'
      },
      {
        time: '14:30',
        driver: 'Sarah Williams',
        task_type: 'delivery',
        customer: 'Road Works Ltd',
        equipment: 'Traffic Management Kit',
        location: 'A40 Junction',
        status: 'delayed'
      }
    ]
    setSchedule(mockSchedule)
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'available': return 'bg-green text-green'
      case 'on_delivery': return 'bg-blue text-blue'
      case 'on_collection': return 'bg-iris text-iris'
      case 'break': return 'bg-gold text-gold'
      case 'offline': return 'bg-subtle text-subtle'
      case 'pending': return 'bg-gold/20 text-gold'
      case 'in_progress': return 'bg-blue/20 text-blue'
      case 'completed': return 'bg-green/20 text-green'
      case 'delayed': return 'bg-red/20 text-red'
      default: return 'bg-subtle/20 text-subtle'
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'available': return '✅'
      case 'on_delivery': return '🚚'
      case 'on_collection': return '📦'
      case 'break': return '☕'
      case 'offline': return '📴'
      case 'delivery': return '🚚'
      case 'collection': return '📦'
      default: return '📋'
    }
  }

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <h1 className="text-2xl font-bold text-gold">Drivers Schedule</h1>
            <p className="text-subtle mt-1">Driver status and delivery schedule for today</p>
          </div>
        </div>

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            
            {/* Driver Status */}
            <div className="bg-surface border border-highlight-low rounded-lg p-6">
              <h2 className="text-xl font-semibold text-text mb-4">Driver Status</h2>
              <div className="space-y-4">
                {drivers.map((driver) => (
                  <div key={driver.id} className="border border-highlight-low rounded-lg p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center space-x-3">
                        <div className="text-xl">{getStatusIcon(driver.status)}</div>
                        <div>
                          <h3 className="font-semibold text-text">{driver.name}</h3>
                          <p className="text-sm text-subtle">{driver.vehicle} • {driver.phone}</p>
                        </div>
                      </div>
                      <span className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(driver.status)}/20`}>
                        {driver.status.replace('_', ' ').toUpperCase()}
                      </span>
                    </div>
                    
                    {driver.current_task && (
                      <div className="text-sm text-text mb-1">
                        <strong>Current:</strong> {driver.current_task}
                      </div>
                    )}
                    
                    <div className="text-sm text-subtle">
                      <strong>Location:</strong> {driver.location || 'Unknown'}
                    </div>
                    
                    {driver.next_task_time && (
                      <div className="text-sm text-gold mt-2">
                        <strong>Next task:</strong> {driver.next_task_time}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {/* Schedule */}
            <div className="bg-surface border border-highlight-low rounded-lg p-6">
              <h2 className="text-xl font-semibold text-text mb-4">Today's Schedule</h2>
              <div className="space-y-3">
                {schedule.map((entry, index) => (
                  <div key={index} className="border border-highlight-low rounded-lg p-4">
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center space-x-3">
                        <div className="text-lg">{getStatusIcon(entry.task_type)}</div>
                        <div>
                          <div className="font-semibold text-text">{entry.time}</div>
                          <div className="text-sm text-subtle">{entry.driver}</div>
                        </div>
                      </div>
                      <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(entry.status)}`}>
                        {entry.status.replace('_', ' ').toUpperCase()}
                      </span>
                    </div>
                    
                    <div className="text-sm space-y-1">
                      <div><strong>Customer:</strong> {entry.customer}</div>
                      <div><strong>Equipment:</strong> {entry.equipment}</div>
                      <div><strong>Location:</strong> {entry.location}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="mt-8 bg-surface border border-highlight-low rounded-lg p-6">
            <h2 className="text-xl font-semibold text-text mb-4">Quick Actions</h2>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <button className="p-4 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-center">
                <div className="text-2xl mb-2">📞</div>
                <div className="text-sm font-medium">Call Driver</div>
              </button>
              <button className="p-4 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-center">
                <div className="text-2xl mb-2">📍</div>
                <div className="text-sm font-medium">Track Location</div>
              </button>
              <button className="p-4 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-center">
                <div className="text-2xl mb-2">📝</div>
                <div className="text-sm font-medium">Add Task</div>
              </button>
              <button className="p-4 bg-overlay border border-highlight-med rounded-lg hover:border-gold transition-colors text-center">
                <div className="text-2xl mb-2">📊</div>
                <div className="text-sm font-medium">View Reports</div>
              </button>
            </div>
          </div>
        </div>
      </div>
    </AuthCheck>
  )
}