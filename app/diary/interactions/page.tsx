'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

interface InteractionDetails {
  interaction_id: number
  reference_number: string
  interaction_status: string
  customer_name: string
  contact_name: string
  contact_phone: string
  contact_email: string
  site_name: string
  site_address: string
  hire_start_date: string
  hire_end_date: string
  delivery_date: string
  delivery_time: string
  notes: string
  created_at: string
  employee_name: string
}

interface EquipmentItem {
  equipment_type_id: number
  type_name: string
  type_code: string
  booked_quantity: number
  allocated_quantity: number
  booking_status: string
  hire_start_date: string
  hire_end_date: string
}

interface AccessoryItem {
  accessory_id: number
  accessory_name: string
  quantity: number
  accessory_type: string
  billing_method: string
  is_consumable: boolean
  equipment_type_name: string
}

interface HireInteraction {
  interaction: InteractionDetails
  equipment: EquipmentItem[]
  accessories: AccessoryItem[]
  total_equipment_items: number
  total_accessories: number
}

export default function ViewInteractionsPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  
  const [interactions, setInteractions] = useState<number[]>([])
  const [currentIndex, setCurrentIndex] = useState(0)
  const [currentInteraction, setCurrentInteraction] = useState<HireInteraction | null>(null)

  useEffect(() => {
    // Check if user is logged in
    fetch('/api/auth/session')
      .then(res => res.json())
      .then(data => {
        if (!data.user) {
          router.push('/login')
          return
        }
        loadInteractionsList()
      })
      .catch(err => {
        console.error('Failed to fetch session:', err)
        router.push('/login')
      })
  }, [router])

  useEffect(() => {
    // Check if a specific interaction ID was provided in URL
    const interactionId = searchParams.get('id')
    if (interactionId && interactions.length > 0) {
      const index = interactions.findIndex(id => id === Number(interactionId))
      if (index !== -1) {
        setCurrentIndex(index)
      }
    }
  }, [searchParams, interactions])

  useEffect(() => {
    if (interactions.length > 0) {
      loadInteractionDetails(interactions[currentIndex])
    }
  }, [currentIndex, interactions])

  const loadInteractionsList = async () => {
    try {
      setIsLoading(true)
      
      // Try the regular API endpoint first
      console.log('Attempting to load interactions from main API...')
      const response = await fetch('/api/hire/hires?limit=1000')
      console.log('Response status:', response.status)
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const data = await response.json()
      console.log('Main API response:', data)

      if (data.success && data.data && data.data.length > 0) {
        const interactionIds = data.data.map((hire: any) => hire.interaction_id)
        setInteractions(interactionIds)
        
        // Load the first interaction or the one specified in URL
        const interactionId = searchParams.get('id')
        if (interactionId) {
          const index = interactionIds.findIndex((id: number) => id === Number(interactionId))
          if (index !== -1) {
            setCurrentIndex(index)
          }
        }
      } else {
        console.warn('Main API failed or returned no data, trying debug endpoint...')
        
        // Fallback to debug endpoint
        const debugResponse = await fetch('/api/debug/simple-hire-list')
        const debugData = await debugResponse.json()
        console.log('Debug API response:', debugData)

        if (debugData.success && debugData.data.length > 0) {
          const interactionIds = debugData.data.map((hire: any) => hire.interaction_id)
          setInteractions(interactionIds)
          
          // Load the first interaction or the one specified in URL
          const interactionId = searchParams.get('id')
          if (interactionId) {
            const index = interactionIds.findIndex((id: number) => id === Number(interactionId))
            if (index !== -1) {
              setCurrentIndex(index)
            }
          }
        } else {
          setError('No hire interactions found in either endpoint')
        }
      }
    } catch (err) {
      console.error('Main API failed, trying debug endpoint:', err)
      
      // Fallback to debug endpoint
      try {
        const debugResponse = await fetch('/api/debug/simple-hire-list')
        const debugData = await debugResponse.json()
        console.log('Debug fallback response:', debugData)

        if (debugData.success && debugData.data.length > 0) {
          const interactionIds = debugData.data.map((hire: any) => hire.interaction_id)
          setInteractions(interactionIds)
          
          // Load the first interaction or the one specified in URL
          const interactionId = searchParams.get('id')
          if (interactionId) {
            const index = interactionIds.findIndex((id: number) => id === Number(interactionId))
            if (index !== -1) {
              setCurrentIndex(index)
            }
          }
        } else {
          setError('No hire interactions found')
        }
      } catch (debugErr) {
        console.error('Debug endpoint also failed:', debugErr)
        setError(`Failed to load interactions: ${err}`)
      }
    } finally {
      setIsLoading(false)
    }
  }

  const loadInteractionDetails = async (interactionId: number) => {
    try {
      setError(null)
      console.log(`Loading details for interaction ${interactionId}...`)
      
      // Try regular API endpoint first
      const response = await fetch(`/api/hire/hires/${interactionId}`)
      console.log('Details response status:', response.status)
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const data = await response.json()
      console.log('Details API response:', data)

      if (data.success && data.data) {
        setCurrentInteraction(data.data.raw_details || data.data)
      } else {
        // Fallback to debug endpoint
        console.warn('Main details API failed, trying debug endpoint...')
        const debugResponse = await fetch(`/api/debug/test-hire-details/${interactionId}`)
        const debugData = await debugResponse.json()
        console.log('Debug details response:', debugData)
        
        if (debugData.success) {
          setCurrentInteraction(debugData.data)
        } else {
          setError(`Failed to load interaction ${interactionId}: ${debugData.error || 'Unknown error'}`)
        }
      }
    } catch (err) {
      console.error('Main details API failed, trying debug endpoint:', err)
      
      // Fallback to debug endpoint
      try {
        const debugResponse = await fetch(`/api/debug/test-hire-details/${interactionId}`)
        const debugData = await debugResponse.json()
        console.log('Debug details fallback response:', debugData)
        
        if (debugData.success) {
          setCurrentInteraction(debugData.data)
        } else {
          setError(`Failed to load interaction ${interactionId}: ${debugData.error}`)
        }
      } catch (debugErr) {
        console.error('Debug details endpoint also failed:', debugErr)
        setError(`Failed to load interaction details: ${err}`)
      }
    }
  }

  const goToPrevious = () => {
    if (currentIndex > 0) {
      setCurrentIndex(currentIndex - 1)
    }
  }

  const goToNext = () => {
    if (currentIndex < interactions.length - 1) {
      setCurrentIndex(currentIndex + 1)
    }
  }

  const goToFirst = () => {
    setCurrentIndex(0)
  }

  const goToLast = () => {
    setCurrentIndex(interactions.length - 1)
  }

  const formatDate = (dateString: string) => {
    if (!dateString) return 'N/A'
    return new Date(dateString).toLocaleDateString('en-ZA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })
  }

  const formatDateTime = (dateTimeString: string) => {
    if (!dateTimeString) return 'N/A'
    return new Date(dateTimeString).toLocaleString('en-ZA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'pending': return 'text-yellow bg-yellow/20'
      case 'in_progress': return 'text-blue bg-blue/20'
      case 'completed': return 'text-green bg-green/20'
      case 'cancelled': return 'text-red bg-red/20'
      default: return 'text-text bg-overlay'
    }
  }

  const getBookingStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'booked': return 'text-yellow bg-yellow/20'
      case 'allocated': return 'text-green bg-green/20'
      case 'cancelled': return 'text-red bg-red/20'
      default: return 'text-text bg-overlay'
    }
  }

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-rose"></div>
      </div>
    )
  }

  if (error && interactions.length === 0) {
    return (
      <div className="max-w-4xl mx-auto p-6">
        <div className="bg-red/20 border border-red text-red p-4 rounded">
          {error}
        </div>
      </div>
    )
  }

  if (interactions.length === 0) {
    return (
      <div className="max-w-4xl mx-auto p-6">
        <div className="bg-overlay p-8 rounded-lg text-center">
          <h2 className="text-xl font-medium text-text mb-4">No Interactions Found</h2>
          <p className="text-subtle mb-6">There are no hire interactions to display.</p>
          <button
            onClick={() => router.push('/diary/new-interaction')}
            className="bg-green text-base px-6 py-3 rounded-lg hover:bg-blue transition-colors"
          >
            Create New Interaction
          </button>
        </div>
      </div>
    )
  }

  const interaction = currentInteraction?.interaction
  const equipment = currentInteraction?.equipment || []
  const accessories = currentInteraction?.accessories || []

  return (
    <div className="max-w-6xl mx-auto p-6">
      {/* Navigation Header */}
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-semibold text-text">Hire Interactions</h1>
        
        <div className="flex items-center gap-4">
          <span className="text-subtle">
            {currentIndex + 1} of {interactions.length}
          </span>
          
          <div className="flex gap-2">
            <button
              onClick={goToFirst}
              disabled={currentIndex === 0}
              className="p-2 bg-overlay text-text rounded hover:bg-highlight-med disabled:opacity-50 disabled:cursor-not-allowed"
              title="First"
            >
              ⏮
            </button>
            <button
              onClick={goToPrevious}
              disabled={currentIndex === 0}
              className="p-2 bg-overlay text-text rounded hover:bg-highlight-med disabled:opacity-50 disabled:cursor-not-allowed"
              title="Previous"
            >
              ⏪
            </button>
            <button
              onClick={goToNext}
              disabled={currentIndex === interactions.length - 1}
              className="p-2 bg-overlay text-text rounded hover:bg-highlight-med disabled:opacity-50 disabled:cursor-not-allowed"
              title="Next"
            >
              ⏩
            </button>
            <button
              onClick={goToLast}
              disabled={currentIndex === interactions.length - 1}
              className="p-2 bg-overlay text-text rounded hover:bg-highlight-med disabled:opacity-50 disabled:cursor-not-allowed"
              title="Last"
            >
              ⏭
            </button>
          </div>
        </div>
      </div>

      {error && (
        <div className="bg-red/20 border border-red text-red p-4 rounded mb-6">
          {error}
        </div>
      )}

      {interaction && (
        <div className="space-y-6">
          {/* Interaction Details */}
          <div className="bg-surface p-6 rounded-lg">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h2 className="text-xl font-semibold text-text">{interaction.reference_number}</h2>
                <p className="text-subtle">Interaction ID: {interaction.interaction_id}</p>
              </div>
              <div className="flex items-center gap-4">
                <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(interaction.interaction_status)}`}>
                  {interaction.interaction_status.toUpperCase()}
                </span>
                <span className="text-sm text-subtle">
                  Created: {formatDateTime(interaction.created_at)}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Customer & Contact Information */}
              <div>
                <h3 className="font-medium text-text mb-3">Customer & Contact</h3>
                <div className="space-y-2 text-sm">
                  <div>
                    <span className="text-subtle">Customer:</span>
                    <span className="ml-2 text-text font-medium">{interaction.customer_name}</span>
                  </div>
                  <div>
                    <span className="text-subtle">Contact:</span>
                    <span className="ml-2 text-text">{interaction.contact_name}</span>
                  </div>
                  {interaction.contact_phone && (
                    <div>
                      <span className="text-subtle">Phone:</span>
                      <span className="ml-2 text-text">{interaction.contact_phone}</span>
                    </div>
                  )}
                  {interaction.contact_email && (
                    <div>
                      <span className="text-subtle">Email:</span>
                      <span className="ml-2 text-text">{interaction.contact_email}</span>
                    </div>
                  )}
                  <div>
                    <span className="text-subtle">Created by:</span>
                    <span className="ml-2 text-text">{interaction.employee_name}</span>
                  </div>
                </div>
              </div>

              {/* Delivery Information */}
              <div>
                <h3 className="font-medium text-text mb-3">Delivery Information</h3>
                <div className="space-y-2 text-sm">
                  <div>
                    <span className="text-subtle">Site:</span>
                    <span className="ml-2 text-text">{interaction.site_name}</span>
                  </div>
                  <div>
                    <span className="text-subtle">Address:</span>
                    <span className="ml-2 text-text">{interaction.site_address}</span>
                  </div>
                  <div>
                    <span className="text-subtle">Delivery Date:</span>
                    <span className="ml-2 text-text">{formatDate(interaction.delivery_date)}</span>
                  </div>
                  {interaction.delivery_time && (
                    <div>
                      <span className="text-subtle">Delivery Time:</span>
                      <span className="ml-2 text-text">{interaction.delivery_time}</span>
                    </div>
                  )}
                  {interaction.hire_start_date && (
                    <div>
                      <span className="text-subtle">Hire Period:</span>
                      <span className="ml-2 text-text">
                        {formatDate(interaction.hire_start_date)} 
                        {interaction.hire_end_date && ` - ${formatDate(interaction.hire_end_date)}`}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            </div>

            {interaction.notes && (
              <div className="mt-4 pt-4 border-t border-highlight-med">
                <h3 className="font-medium text-text mb-2">Notes</h3>
                <p className="text-subtle text-sm">{interaction.notes}</p>
              </div>
            )}
          </div>

          {/* Equipment List */}
          <div className="bg-surface p-6 rounded-lg">
            <h2 className="text-lg font-semibold text-text mb-4">Equipment Booked</h2>
            
            {equipment.length > 0 ? (
              <div className="space-y-3">
                {equipment.map((item, index) => (
                  <div key={index} className="bg-overlay p-4 rounded border">
                    <div className="flex justify-between items-start">
                      <div className="flex items-center gap-3">
                        <span className="text-lg">🔧</span>
                        <div>
                          <h3 className="font-medium text-text">{item.type_name}</h3>
                          <p className="text-sm text-subtle">Code: {item.type_code}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="text-sm text-subtle">Quantity:</span>
                          <span className="font-medium text-text">{item.booked_quantity}</span>
                        </div>
                        <div className="flex items-center gap-2 mb-1">
                          <span className="text-sm text-subtle">Allocated:</span>
                          <span className="font-medium text-text">{item.allocated_quantity}</span>
                        </div>
                        <span className={`px-2 py-1 rounded text-xs font-medium ${getBookingStatusColor(item.booking_status)}`}>
                          {item.booking_status.toUpperCase()}
                        </span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-subtle">No equipment items found.</p>
            )}
          </div>

          {/* Accessories List */}
          {accessories.length > 0 && (
            <div className="bg-surface p-6 rounded-lg">
              <h2 className="text-lg font-semibold text-text mb-4">Accessories</h2>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {accessories.map((item, index) => (
                  <div key={index} className="bg-overlay p-4 rounded border">
                    <div className="flex justify-between items-start">
                      <div className="flex items-center gap-3">
                        <span className="text-lg">📦</span>
                        <div>
                          <h3 className="font-medium text-text">{item.accessory_name}</h3>
                          {item.equipment_type_name && (
                            <p className="text-xs text-subtle">For: {item.equipment_type_name}</p>
                          )}
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="text-sm text-subtle">Qty:</span>
                          <span className="font-medium text-text">{item.quantity}</span>
                        </div>
                        <div className="flex gap-2">
                          <span className={`px-2 py-1 rounded text-xs font-medium ${
                            item.accessory_type === 'default' ? 'text-green bg-green/20' : 'text-blue bg-blue/20'
                          }`}>
                            {item.accessory_type.toUpperCase()}
                          </span>
                          {item.is_consumable && (
                            <span className="px-2 py-1 rounded text-xs font-medium text-yellow bg-yellow/20">
                              CONSUMABLE
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex justify-between items-center">
            <button
              onClick={() => router.push('/diary/new-interaction')}
              className="bg-green text-base px-6 py-3 rounded-lg hover:bg-blue transition-colors"
            >
              Create New Interaction
            </button>
            
            <div className="flex gap-4">
              <button
                onClick={() => router.push('/diary/drivers')}
                className="bg-pine text-base px-6 py-3 rounded-lg hover:bg-foam transition-colors"
              >
                View in Driver Taskboard
              </button>
              
              <button
                onClick={() => window.print()}
                className="bg-overlay text-text px-6 py-3 rounded-lg hover:bg-highlight-med transition-colors"
              >
                Print Details
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}