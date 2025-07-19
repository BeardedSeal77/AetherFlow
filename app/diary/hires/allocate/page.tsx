'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import AuthCheck from '../../../auth/AuthCheck'
import Navbar from '../../../components/Navbar'
import Ribbon from '../../../components/Ribbon'

interface PendingHire {
  interaction_id: number
  reference_number: string
  customer_name: string
  contact_name: string
  site_name: string
  hire_start_date: string
  delivery_date: string
  delivery_time: string
  priority: 'urgent' | 'today' | 'future'
  equipment_count: number
  total_value: number
  generic_equipment: Array<{
    equipment_type_id: number
    type_name: string
    type_code: string
    quantity: number
    daily_rate: number
  }>
}

const ribbonSections = [
  { key: 'view', url: '/diary/hires/view', displayName: 'View All' },
  { key: 'allocate', url: '/diary/hires/allocate', displayName: 'Allocate' },
  { key: 'new', url: '/diary/hires/new', displayName: 'New Hire' }
]

export default function AllocateHiresPage() {
  const router = useRouter()
  const [pendingHires, setPendingHires] = useState<PendingHire[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [priorityFilter, setPriorityFilter] = useState<'all' | 'urgent' | 'today' | 'future'>('all')

  useEffect(() => {
    loadPendingAllocations()
  }, [])

  const loadPendingAllocations = async () => {
    try {
      setIsLoading(true)
      const response = await fetch('/api/hires/pending-allocations', {
        credentials: 'include'
      })
      if (response.ok) {
        const data = await response.json()
        setPendingHires(data)
      }
    } catch (error) {
      console.error('Error loading pending allocations:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const filteredHires = pendingHires.filter(hire => {
    if (priorityFilter === 'all') return true
    return hire.priority === priorityFilter
  })

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent': return 'bg-red text-white'
      case 'today': return 'bg-yellow text-base'
      case 'future': return 'bg-blue text-white'
      default: return 'bg-subtle text-white'
    }
  }

  const getPriorityIcon = (priority: string) => {
    switch (priority) {
      case 'urgent': return '🚨'
      case 'today': return '📅'
      case 'future': return '⏰'
      default: return '📋'
    }
  }

  const openAllocation = (hireId: number) => {
    router.push(`/diary/hires/edit/${hireId}?focus=allocation`)
  }

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        <Navbar />
        
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div className="flex justify-between items-center">
              <div>
                <h1 className="text-2xl font-bold text-gold">Equipment Allocation</h1>
                <p className="text-subtle mt-1">Hires with generic equipment requiring specific allocation</p>
              </div>
              <div className="flex gap-4">
                <button
                  onClick={() => router.push('/diary/hires/view')}
                  className="px-4 py-2 bg-overlay text-text rounded-lg hover:bg-highlight-low transition-colors"
                >
                  View All Hires
                </button>
                <button
                  onClick={() => router.push('/diary/hires/new')}
                  className="px-4 py-2 bg-gold text-base rounded-lg hover:bg-gold/80 transition-colors"
                >
                  New Hire
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {/* Priority Filters */}
          <div className="mb-6 flex gap-2">
            {[
              { key: 'all', label: 'All Priorities' },
              { key: 'urgent', label: 'Urgent' },
              { key: 'today', label: 'Today' },
              { key: 'future', label: 'Future' }
            ].map(filterOption => (
              <button
                key={filterOption.key}
                onClick={() => setPriorityFilter(filterOption.key as any)}
                className={`px-4 py-2 rounded-lg transition-colors ${
                  priorityFilter === filterOption.key
                    ? 'bg-gold text-base'
                    : 'bg-surface text-text hover:bg-highlight-low'
                }`}
              >
                {filterOption.label}
              </button>
            ))}
          </div>

          {/* Statistics */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <div className="bg-surface border border-highlight-low rounded-lg p-4">
              <div className="text-2xl font-bold text-red">
                {pendingHires.filter(h => h.priority === 'urgent').length}
              </div>
              <div className="text-sm text-subtle">Urgent Allocations</div>
            </div>
            <div className="bg-surface border border-highlight-low rounded-lg p-4">
              <div className="text-2xl font-bold text-yellow">
                {pendingHires.filter(h => h.priority === 'today').length}
              </div>
              <div className="text-sm text-subtle">Due Today</div>
            </div>
            <div className="bg-surface border border-highlight-low rounded-lg p-4">
              <div className="text-2xl font-bold text-blue">
                {pendingHires.filter(h => h.priority === 'future').length}
              </div>
              <div className="text-sm text-subtle">Future Allocations</div>
            </div>
          </div>

          {/* Pending Allocations */}
          {isLoading ? (
            <div className="text-center py-12">
              <div className="text-4xl mb-4">⚙️</div>
              <p className="text-subtle">Loading pending allocations...</p>
            </div>
          ) : filteredHires.length === 0 ? (
            <div className="text-center py-12">
              <div className="text-4xl mb-4">✅</div>
              <p className="text-subtle">No pending allocations!</p>
              <p className="text-subtle text-sm mt-2">All hires have been allocated specific equipment</p>
            </div>
          ) : (
            <div className="grid gap-4">
              {filteredHires.map(hire => (
                <div
                  key={hire.interaction_id}
                  onClick={() => openAllocation(hire.interaction_id)}
                  className="bg-surface border border-highlight-low rounded-lg p-6 cursor-pointer hover:border-gold transition-colors"
                >
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-3">
                        <h3 className="text-lg font-semibold text-text">
                          {hire.reference_number}
                        </h3>
                        <span className={`px-2 py-1 rounded text-xs font-medium ${getPriorityColor(hire.priority)}`}>
                          {hire.priority.toUpperCase()}
                        </span>
                        <span className="text-lg">
                          {getPriorityIcon(hire.priority)}
                        </span>
                      </div>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 text-sm mb-4">
                        <div>
                          <span className="text-subtle">Customer:</span>
                          <p className="text-text font-medium">{hire.customer_name}</p>
                        </div>
                        <div>
                          <span className="text-subtle">Contact:</span>
                          <p className="text-text">{hire.contact_name}</p>
                        </div>
                        <div>
                          <span className="text-subtle">Delivery:</span>
                          <p className="text-text">{hire.delivery_date} at {hire.delivery_time}</p>
                        </div>
                      </div>
                      
                      {/* Generic Equipment List */}
                      <div className="bg-overlay rounded-lg p-4">
                        <h4 className="text-sm font-medium text-text mb-2">Equipment Requiring Allocation:</h4>
                        <div className="space-y-2">
                          {hire.generic_equipment.map((equipment, index) => (
                            <div key={index} className="flex justify-between items-center text-sm">
                              <div>
                                <span className="text-text font-medium">{equipment.type_name}</span>
                                <span className="text-subtle ml-2">({equipment.type_code})</span>
                              </div>
                              <div className="flex gap-4">
                                <span className="text-text">Qty: {equipment.quantity}</span>
                                <span className="text-green">£{equipment.daily_rate}/day</span>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-right ml-6">
                      <div className="text-3xl mb-2">⚙️</div>
                      <button className="px-4 py-2 bg-blue text-white rounded-lg hover:bg-blue/80 transition-colors">
                        Allocate
                      </button>
                      <div className="text-sm text-subtle mt-2">
                        {hire.equipment_count} items total
                      </div>
                    </div>
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