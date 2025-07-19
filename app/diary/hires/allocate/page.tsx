// app/diary/hires/allocate/page.tsx
'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import AuthCheck from '../../../auth/AuthCheck'
// REMOVED: import Navbar from '../../../components/Navbar'
// REMOVED: import Ribbon from '../../../components/Ribbon'

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

export default function AllocateHiresPage() {
  const router = useRouter()
  const [pendingHires, setPendingHires] = useState<PendingHire[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [priorityFilter, setPriorityFilter] = useState<'all' | 'urgent' | 'today' | 'future'>('all')
  const [selectedHires, setSelectedHires] = useState<number[]>([])

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

  const toggleHireSelection = (hireId: number) => {
    setSelectedHires(prev => 
      prev.includes(hireId) 
        ? prev.filter(id => id !== hireId)
        : [...prev, hireId]
    )
  }

  const bulkAllocate = () => {
    if (selectedHires.length > 0) {
      console.log('Bulk allocating:', selectedHires)
      // Implement bulk allocation logic here
    }
  }

  const selectAll = () => {
    if (selectedHires.length === filteredHires.length) {
      setSelectedHires([])
    } else {
      setSelectedHires(filteredHires.map(hire => hire.interaction_id))
    }
  }

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* REMOVED: <Navbar /> */}
        {/* Page Header - Windows App Style */}
        <div className="bg-surface border-b border-highlight-low shadow-sm">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex justify-between items-center">
              <div>
                <h1 className="text-xl font-semibold text-text">Equipment Allocation</h1>
                <p className="text-sm text-subtle mt-1">
                  Generic equipment requiring specific allocation • {filteredHires.length} pending
                </p>
              </div>
              
              {/* Quick Actions Toolbar */}
              <div className="flex items-center gap-2">
                {selectedHires.length > 0 && (
                  <button 
                    onClick={bulkAllocate}
                    className="px-3 py-1.5 bg-iris text-white rounded hover:bg-iris/80 transition-colors text-sm flex items-center gap-1"
                  >
                    🎯 Allocate Selected ({selectedHires.length})
                  </button>
                )}
                <button 
                  onClick={() => window.location.reload()}
                  className="px-3 py-1.5 bg-overlay text-text rounded hover:bg-highlight-low transition-colors text-sm flex items-center gap-1"
                >
                  🔄 Refresh
                </button>
                <button 
                  onClick={() => router.push('/diary/hires/new')}
                  className="px-3 py-1.5 bg-gold text-base rounded hover:bg-gold/80 transition-colors text-sm flex items-center gap-1"
                >
                  ➕ New Hire
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          {/* Priority Filter Ribbon - Windows App Style */}
          <div className="bg-surface border border-highlight-low rounded-lg p-3 mb-6">
            <div className="flex items-center justify-between">
              <div className="flex gap-2">
                {[
                  { key: 'all', label: 'All Priorities', icon: '📋' },
                  { key: 'urgent', label: 'Urgent', icon: '🚨' },
                  { key: 'today', label: 'Due Today', icon: '📅' },
                  { key: 'future', label: 'Future', icon: '⏰' }
                ].map(filterOption => (
                  <button
                    key={filterOption.key}
                    onClick={() => setPriorityFilter(filterOption.key as any)}
                    className={`px-3 py-1.5 rounded text-sm transition-colors flex items-center gap-2 ${
                      priorityFilter === filterOption.key
                        ? 'bg-blue text-white shadow-sm' 
                        : 'bg-overlay/50 text-text hover:bg-highlight-low'
                    }`}
                  >
                    {filterOption.icon} {filterOption.label}
                  </button>
                ))}
              </div>
              
              <div className="flex items-center gap-4">
                {filteredHires.length > 0 && (
                  <button
                    onClick={selectAll}
                    className="px-3 py-1.5 bg-overlay/50 text-text rounded hover:bg-highlight-low transition-colors text-sm"
                  >
                    {selectedHires.length === filteredHires.length ? '☑️ Deselect All' : '☐ Select All'}
                  </button>
                )}
                
                {selectedHires.length > 0 && (
                  <div className="text-sm text-subtle">
                    {selectedHires.length} selected for bulk allocation
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Statistics Dashboard */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-surface border border-highlight-low rounded-lg p-4">
              <div className="flex items-center gap-3">
                <div className="text-2xl">🚨</div>
                <div>
                  <div className="text-xl font-bold text-red">
                    {pendingHires.filter(h => h.priority === 'urgent').length}
                  </div>
                  <div className="text-sm text-subtle">Urgent</div>
                </div>
              </div>
            </div>
            <div className="bg-surface border border-highlight-low rounded-lg p-4">
              <div className="flex items-center gap-3">
                <div className="text-2xl">📅</div>
                <div>
                  <div className="text-xl font-bold text-yellow">
                    {pendingHires.filter(h => h.priority === 'today').length}
                  </div>
                  <div className="text-sm text-subtle">Due Today</div>
                </div>
              </div>
            </div>
            <div className="bg-surface border border-highlight-low rounded-lg p-4">
              <div className="flex items-center gap-3">
                <div className="text-2xl">⏰</div>
                <div>
                  <div className="text-xl font-bold text-blue">
                    {pendingHires.filter(h => h.priority === 'future').length}
                  </div>
                  <div className="text-sm text-subtle">Future</div>
                </div>
              </div>
            </div>
            <div className="bg-surface border border-highlight-low rounded-lg p-4">
              <div className="flex items-center gap-3">
                <div className="text-2xl">🎯</div>
                <div>
                  <div className="text-xl font-bold text-iris">
                    {selectedHires.length}
                  </div>
                  <div className="text-sm text-subtle">Selected</div>
                </div>
              </div>
            </div>
          </div>

          {/* Pending Allocations List */}
          {isLoading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gold mx-auto"></div>
              <p className="text-subtle mt-3">Loading pending allocations...</p>
            </div>
          ) : (
            <div className="space-y-3">
              {filteredHires.map((hire) => (
                <div 
                  key={hire.interaction_id}
                  className="bg-surface border border-highlight-low rounded-lg overflow-hidden hover:border-gold/30 hover:shadow-md transition-all"
                >
                  <div className="p-4">
                    <div className="flex items-start justify-between">
                      <div className="flex items-start gap-4 flex-1">
                        {/* Selection checkbox */}
                        <input
                          type="checkbox"
                          checked={selectedHires.includes(hire.interaction_id)}
                          onChange={() => toggleHireSelection(hire.interaction_id)}
                          className="mt-2 h-4 w-4 text-iris border-gray-300 rounded focus:ring-iris"
                        />
                        
                        <div className="flex-1">
                          <div className="flex items-center gap-3 mb-3">
                            <h3 className="text-lg font-medium text-text">
                              {hire.reference_number}
                            </h3>
                            <span className={`px-2 py-1 rounded-full text-xs font-medium ${getPriorityColor(hire.priority)}`}>
                              {getPriorityIcon(hire.priority)} {hire.priority.toUpperCase()}
                            </span>
                          </div>
                          
                          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm mb-4">
                            <div>
                              <p className="font-medium text-text">{hire.customer_name}</p>
                              <p className="text-subtle">{hire.contact_name}</p>
                            </div>
                            <div>
                              <p className="text-subtle">📍 {hire.site_name}</p>
                              <p className="text-subtle">
                                🚚 {new Date(hire.delivery_date).toLocaleDateString('en-GB')} at {hire.delivery_time}
                              </p>
                            </div>
                            <div className="text-right">
                              <p className="text-text font-medium">{hire.equipment_count} items</p>
                              <p className="text-green font-semibold">£{hire.total_value.toFixed(2)}</p>
                            </div>
                          </div>
                          
                          {/* Generic Equipment List */}
                          <div className="bg-yellow/10 border border-yellow/30 rounded p-3">
                            <h4 className="text-sm font-medium text-text mb-2 flex items-center gap-2">
                              ⚡ Generic Equipment to Allocate:
                            </h4>
                            <div className="flex flex-wrap gap-2">
                              {hire.generic_equipment.map((equipment, index) => (
                                <span 
                                  key={index}
                                  className="px-2 py-1 bg-yellow text-base rounded text-sm border border-yellow/50"
                                >
                                  {equipment.quantity}x {equipment.type_name} ({equipment.type_code})
                                </span>
                              ))}
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      <div className="ml-4">
                        <button
                          onClick={() => openAllocation(hire.interaction_id)}
                          className="px-4 py-2 bg-iris text-white rounded hover:bg-iris/80 transition-colors flex items-center gap-2"
                        >
                          🎯 Allocate Now
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}

              {filteredHires.length === 0 && (
                <div className="text-center py-12">
                  <div className="text-4xl mb-4">🎯</div>
                  <p className="text-text font-medium mb-2">No pending allocations</p>
                  <p className="text-subtle mb-4">
                    {priorityFilter === 'all' 
                      ? 'All equipment has been allocated!'
                      : `No ${priorityFilter} allocations found.`
                    }
                  </p>
                  <div className="flex justify-center gap-3">
                    <button
                      onClick={() => setPriorityFilter('all')}
                      className="px-4 py-2 bg-overlay text-text rounded hover:bg-highlight-low transition-colors"
                    >
                      Show All
                    </button>
                    <button
                      onClick={() => router.push('/diary/hires/view')}
                      className="px-4 py-2 bg-gold text-base rounded hover:bg-gold/80 transition-colors"
                    >
                      View All Hires
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </AuthCheck>
  )
}