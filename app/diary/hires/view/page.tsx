'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import AuthCheck from '../../../auth/AuthCheck'
import Navbar from '../../../components/Navbar'
import Ribbon from '../../../components/Ribbon'

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

const ribbonSections = [
  { key: 'view', url: '/diary/hires/view', displayName: 'View All' },
  { key: 'allocate', url: '/diary/hires/allocate', displayName: 'Allocate' },
  { key: 'new', url: '/diary/hires/new', displayName: 'New Hire' }
]

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
        <Navbar />
        
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div className="flex justify-between items-center">
              <h1 className="text-2xl font-bold text-gold">Today's Hires</h1>
              <div className="flex gap-4">
                <button
                  onClick={() => router.push('/diary/hires/allocate')}
                  className="px-4 py-2 bg-blue text-white rounded-lg hover:bg-blue/80 transition-colors"
                >
                  Quick Allocate
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
          {/* Filters */}
          <div className="mb-6 flex gap-2">
            {[
              { key: 'all', label: 'All Hires' },
              { key: 'pending', label: 'Pending Allocation' },
              { key: 'allocated', label: 'Allocated' },
              { key: 'delivered', label: 'Delivered' }
            ].map(filterOption => (
              <button
                key={filterOption.key}
                onClick={() => setFilter(filterOption.key as any)}
                className={`px-4 py-2 rounded-lg transition-colors ${
                  filter === filterOption.key
                    ? 'bg-gold text-base'
                    : 'bg-surface text-text hover:bg-highlight-low'
                }`}
              >
                {filterOption.label}
              </button>
            ))}
          </div>

          {/* Hires List */}
          {isLoading ? (
            <div className="text-center py-12">
              <div className="text-4xl mb-4">⏳</div>
              <p className="text-subtle">Loading hires...</p>
            </div>
          ) : filteredHires.length === 0 ? (
            <div className="text-center py-12">
              <div className="text-4xl mb-4">📋</div>
              <p className="text-subtle">No hires found for today</p>
            </div>
          ) : (
            <div className="grid gap-4">
              {filteredHires.map(hire => (
                <div
                  key={hire.interaction_id}
                  onClick={() => openHire(hire.interaction_id)}
                  className="bg-surface border border-highlight-low rounded-lg p-6 cursor-pointer hover:border-gold transition-colors"
                >
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-lg font-semibold text-text">
                          {hire.reference_number}
                        </h3>
                        <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(hire.allocation_status)}`}>
                          {hire.allocation_status.replace('_', ' ').toUpperCase()}
                        </span>
                        {hire.has_generic_equipment && (
                          <span className="px-2 py-1 bg-yellow text-base rounded text-xs font-medium">
                            NEEDS ALLOCATION
                          </span>
                        )}
                      </div>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 text-sm">
                        <div>
                          <span className="text-subtle">Customer:</span>
                          <p className="text-text font-medium">{hire.customer_name}</p>
                        </div>
                        <div>
                          <span className="text-subtle">Contact:</span>
                          <p className="text-text">{hire.contact_name}</p>
                        </div>
                        <div>
                          <span className="text-subtle">Site:</span>
                          <p className="text-text">{hire.site_name}</p>
                        </div>
                        <div>
                          <span className="text-subtle">Delivery:</span>
                          <p className="text-text">{hire.delivery_date} at {hire.delivery_time}</p>
                        </div>
                      </div>
                      
                      <div className="mt-3 flex gap-6 text-sm">
                        <span className="text-subtle">
                          Equipment: <span className="text-text font-medium">{hire.equipment_count} items</span>
                        </span>
                        <span className="text-subtle">
                          Value: <span className="text-green font-medium">£{hire.total_value?.toFixed(2) || '0.00'}</span>
                        </span>
                        <span className="text-subtle">
                          Period: <span className="text-text">{hire.hire_start_date} to {hire.hire_end_date || 'TBC'}</span>
                        </span>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <div className="text-2xl mb-2">
                        {hire.has_generic_equipment ? '⚙️' : '✅'}
                      </div>
                      <button className="text-gold hover:text-gold/80 text-sm">
                        Edit →
                      </button>
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