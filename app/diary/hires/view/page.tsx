// app/diary/hires/view/page.tsx
'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import AuthCheck from '../../../auth/AuthCheck'

interface Hire {
  interaction_id: number
  reference_number: string
  customer_name: string
  contact_name: string
  site_name: string
  hire_start_date: string
  hire_end_date: string
  delivery_date: string
  delivery_time: string
  status: string
  allocation_status: string
  has_generic_equipment: boolean
  equipment_count: number
  total_value: number
}

export default function ViewHiresPage() {
  const router = useRouter()
  const [hires, setHires] = useState<Hire[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [filter, setFilter] = useState<'all' | 'pending' | 'allocated' | 'delivered'>('all')

  useEffect(() => {
    loadTodaysHires()
  }, [])

  const loadTodaysHires = async () => {
    try {
      setIsLoading(true)
      const today = new Date().toISOString().split('T')[0]
      const response = await fetch(`/api/hires/today?date=${today}`, {
        credentials: 'include'
      })
      if (response.ok) {
        const data = await response.json()
        setHires(data)
      }
    } catch (error) {
      console.error('Error loading hires:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const filteredHires = hires.filter(hire => {
    if (filter === 'all') return true
    if (filter === 'pending') return hire.allocation_status === 'not_allocated'
    if (filter === 'allocated') return hire.allocation_status === 'allocated'
    if (filter === 'delivered') return hire.status === 'delivered'
    return true
  })

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'not_allocated': return 'bg-yellow text-base'
      case 'allocated': return 'bg-blue text-white'
      case 'quality_checked': return 'bg-green text-white'
      case 'delivered': return 'bg-pine text-white'
      default: return 'bg-subtle text-white'
    }
  }

  const openHire = (hireId: number) => {
    router.push(`/diary/hires/edit/${hireId}`)
  }

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* Page Header - Windows App Style */}
        <div className="bg-surface border-b border-highlight-low shadow-sm">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <div className="flex justify-between items-center">
              <div>
                <h1 className="text-xl font-semibold text-text">View All Hires</h1>
                <p className="text-sm text-subtle mt-1">
                  Equipment hires for {new Date().toLocaleDateString('en-GB')} • {filteredHires.length} items
                </p>
              </div>
              
              {/* Quick Actions Toolbar */}
              <div className="flex items-center gap-2">
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
          {/* Filter Ribbon - Windows App Style */}
          <div className="bg-surface border border-highlight-low rounded-lg p-3 mb-6">
            <div className="flex items-center justify-between">
              <div className="flex gap-2">
                {[
                  { key: 'all', label: 'All Hires', count: hires.length },
                  { key: 'pending', label: 'Pending', count: hires.filter(h => h.allocation_status === 'not_allocated').length },
                  { key: 'allocated', label: 'Allocated', count: hires.filter(h => h.allocation_status === 'allocated').length },
                  { key: 'delivered', label: 'Delivered', count: hires.filter(h => h.status === 'delivered').length }
                ].map(filterOption => (
                  <button
                    key={filterOption.key}
                    onClick={() => setFilter(filterOption.key as any)}
                    className={`px-3 py-1.5 rounded text-sm transition-colors flex items-center gap-2 ${
                      filter === filterOption.key
                        ? 'bg-blue text-white shadow-sm' 
                        : 'bg-overlay/50 text-text hover:bg-highlight-low'
                    }`}
                  >
                    {filterOption.label}
                    <span className="bg-white/20 px-1.5 py-0.5 rounded text-xs">
                      {filterOption.count}
                    </span>
                  </button>
                ))}
              </div>
              
              <div className="text-sm text-subtle">
                Showing {filteredHires.length} of {hires.length} hires
              </div>
            </div>
          </div>

          {/* Hires List */}
          {isLoading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gold mx-auto"></div>
              <p className="text-subtle mt-3">Loading hires...</p>
            </div>
          ) : (
            <div className="space-y-3">
              {filteredHires.map((hire) => (
                <div 
                  key={hire.interaction_id}
                  onClick={() => openHire(hire.interaction_id)}
                  className="bg-surface border border-highlight-low rounded-lg p-4 hover:border-gold/30 hover:shadow-md cursor-pointer transition-all group"
                >
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-3">
                        <h3 className="text-lg font-medium text-text group-hover:text-gold transition-colors">
                          {hire.reference_number}
                        </h3>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(hire.allocation_status)}`}>
                          {hire.allocation_status.replace('_', ' ').toUpperCase()}
                        </span>
                      </div>
                      
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
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
                    </div>
                    
                    <div className="ml-4 flex flex-col gap-2">
                      {hire.has_generic_equipment && hire.allocation_status === 'not_allocated' && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation()
                            router.push(`/diary/hires/edit/${hire.interaction_id}?focus=allocation`)
                          }}
                          className="px-3 py-1.5 bg-iris text-white rounded text-sm hover:bg-iris/80 transition-colors flex items-center gap-1"
                        >
                          🎯 Allocate
                        </button>
                      )}
                      
                      <div className="text-xs text-subtle text-right">
                        Click to edit
                      </div>
                    </div>
                  </div>
                </div>
              ))}

              {filteredHires.length === 0 && (
                <div className="text-center py-12">
                  <div className="text-4xl mb-4">📋</div>
                  <p className="text-text font-medium mb-2">No hires found</p>
                  <p className="text-subtle mb-4">No hires match the selected filter.</p>
                  <button
                    onClick={() => setFilter('all')}
                    className="px-4 py-2 bg-gold text-base rounded hover:bg-gold/80 transition-colors"
                  >
                    Show All Hires
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </AuthCheck>
  )
}