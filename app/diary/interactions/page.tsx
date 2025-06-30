'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'

interface InteractionSummary {
  interaction_id: number
  reference_number: string
  customer_name: string
  contact_name: string
  interaction_status: string
  equipment_count: number
  delivery_time: string
  priority_score: number
  created_at: string
}

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
  
  // Calendar and list state
  const [selectedDate, setSelectedDate] = useState<string>(new Date().toISOString().split('T')[0])
  const [searchTerm, setSearchTerm] = useState<string>('')
  const [interactions, setInteractions] = useState<InteractionSummary[]>([])
  
  // Modal state
  const [selectedInteraction, setSelectedInteraction] = useState<HireInteraction | null>(null)
  const [showModal, setShowModal] = useState(false)
  const [modalLoading, setModalLoading] = useState(false)

  useEffect(() => {
    // Check if user is logged in
    fetch('/api/auth/session')
      .then(res => res.json())
      .then(data => {
        if (!data.user) {
          router.push('/login')
          return
        }
        setIsLoading(false)
        loadInteractionsForDate(selectedDate)
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
      const interaction = interactions.find(i => i.interaction_id === Number(interactionId))
      if (interaction) {
        handleInteractionDoubleClick(interaction)
      }
    }
  }, [searchParams, interactions])

  useEffect(() => {
    if (!isLoading) {
      loadInteractionsForDate(selectedDate)
    }
  }, [selectedDate, searchTerm, isLoading])

  const loadInteractionsForDate = async (targetDate: string) => {
    try {
      setError(null)
      console.log(`Loading interactions for date: ${targetDate}`)
      
      // Use the new date-specific endpoint
      const params = new URLSearchParams({
        target_date: targetDate
      })
      
      if (searchTerm) {
        params.append('search', searchTerm)
      }
      
      const response = await fetch(`/api/hire/interactions-by-date?${params}`)
      console.log('Response status:', response.status)
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const data = await response.json()
      console.log('API response:', data)

      if (data.success) {
        setInteractions(data.data || [])
      } else {
        setError(data.error || 'Failed to load interactions')
      }
    } catch (err) {
      console.error('Failed to load interactions:', err)
      setError(`Failed to load interactions: ${err}`)
    }
  }

  const handleInteractionDoubleClick = async (interaction: InteractionSummary) => {
    try {
      setModalLoading(true)
      setShowModal(true)
      
      // Load full interaction details
      const response = await fetch(`/api/hire/hires/${interaction.interaction_id}`)
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const data = await response.json()
      
      if (data.success && data.data) {
        setSelectedInteraction(data.data.raw_details || data.data)
      } else {
        setError(`Failed to load interaction details: ${data.error || 'Unknown error'}`)
      }
    } catch (err) {
      console.error('Failed to load interaction details:', err)
      setError(`Failed to load interaction details: ${err}`)
    } finally {
      setModalLoading(false)
    }
  }

  const handleCloseModal = () => {
    setShowModal(false)
    setSelectedInteraction(null)
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

  const getPriorityIcon = (priorityScore: number) => {
    switch (priorityScore) {
      case 1: return '🔴' // urgent
      case 2: return '🟡' // high
      case 3: return '🟢' // medium
      default: return '⚪' // low
    }
  }

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-rose"></div>
      </div>
    )
  }

  return (
    <>
      <div className="max-w-6xl mx-auto p-6">
        {/* Header with Calendar */}
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-2xl font-semibold text-text">Hire Interactions</h1>
          
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <label className="text-sm text-subtle">Date:</label>
              <input
                type="date"
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                className="p-2 bg-overlay border border-highlight-med rounded text-text"
              />
            </div>
            
            <div className="flex items-center gap-2">
              <label className="text-sm text-subtle">Search:</label>
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Reference, customer, contact..."
                className="p-2 bg-overlay border border-highlight-med rounded text-text w-48"
              />
            </div>
          </div>
        </div>

        {error && (
          <div className="bg-red/20 border border-red text-red p-4 rounded mb-6">
            {error}
          </div>
        )}

        {/* Interactions List */}
        <div className="bg-surface p-6 rounded-lg">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-lg font-semibold text-text">
              Interactions for {formatDate(selectedDate)}
            </h2>
            <span className="text-sm text-subtle">
              {interactions.length} interaction{interactions.length !== 1 ? 's' : ''}
            </span>
          </div>

          {interactions.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-subtle mb-4">No interactions found for this date.</p>
              <button
                onClick={() => router.push('/diary/new-interaction')}
                className="bg-green text-base px-6 py-3 rounded-lg hover:bg-blue transition-colors"
              >
                Create New Interaction
              </button>
            </div>
          ) : (
            <div className="space-y-2">
              {interactions.map((interaction) => (
                <div
                  key={interaction.interaction_id}
                  className="bg-overlay p-4 rounded border hover:bg-highlight-low cursor-pointer transition-colors"
                  onDoubleClick={() => handleInteractionDoubleClick(interaction)}
                >
                  <div className="flex justify-between items-start">
                    <div className="flex items-center gap-3">
                      <span className="text-lg">{getPriorityIcon(interaction.priority_score)}</span>
                      <div>
                        <div className="flex items-center gap-3 mb-1">
                          <span className="font-medium text-text">{interaction.reference_number}</span>
                          <span className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(interaction.interaction_status)}`}>
                            {interaction.interaction_status.toUpperCase()}
                          </span>
                        </div>
                        <div className="text-sm text-text">
                          <span className="font-medium">{interaction.customer_name}</span>
                          <span className="text-subtle ml-2">• {interaction.contact_name}</span>
                        </div>
                        <div className="text-xs text-subtle mt-1">
                          {interaction.equipment_count} equipment item{interaction.equipment_count !== 1 ? 's' : ''}
                          {interaction.delivery_time && (
                            <span className="ml-2">• Delivery: {interaction.delivery_time}</span>
                          )}
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <div className="text-xs text-subtle">
                        Created: {formatDateTime(interaction.created_at)}
                      </div>
                      <div className="text-xs text-blue mt-1">
                        Double-click to view details
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex justify-between items-center mt-6 pt-4 border-t border-highlight-med">
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
                Driver Taskboard
              </button>
              
              <button
                onClick={() => setSelectedDate(new Date().toISOString().split('T')[0])}
                className="bg-overlay text-text px-6 py-3 rounded-lg hover:bg-highlight-med transition-colors"
              >
                Today
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Modal Overlay */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-base rounded-lg max-w-6xl w-full max-h-[90vh] overflow-y-auto">
            <div className="sticky top-0 bg-base p-6 border-b border-highlight-med flex justify-between items-center">
              <h2 className="text-xl font-semibold text-text">
                {selectedInteraction?.interaction?.reference_number || 'Interaction Details'}
              </h2>
              <button
                onClick={handleCloseModal}
                className="text-subtle hover:text-text text-2xl font-bold"
              >
                ×
              </button>
            </div>

            <div className="p-6">
              {modalLoading ? (
                <div className="flex justify-center items-center h-64">
                  <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-rose"></div>
                </div>
              ) : selectedInteraction?.interaction ? (
                <div className="space-y-6">
                  {/* Interaction Details */}
                  <div className="bg-surface p-6 rounded-lg">
                    <div className="flex justify-between items-start mb-4">
                      <div>
                        <h3 className="text-lg font-semibold text-text">{selectedInteraction.interaction.reference_number}</h3>
                        <p className="text-subtle">Interaction ID: {selectedInteraction.interaction.interaction_id}</p>
                      </div>
                      <div className="flex items-center gap-4">
                        <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(selectedInteraction.interaction.interaction_status)}`}>
                          {selectedInteraction.interaction.interaction_status.toUpperCase()}
                        </span>
                        <span className="text-sm text-subtle">
                          Created: {formatDateTime(selectedInteraction.interaction.created_at)}
                        </span>
                      </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      {/* Customer & Contact Information */}
                      <div>
                        <h4 className="font-medium text-text mb-3">Customer & Contact</h4>
                        <div className="space-y-2 text-sm">
                          <div>
                            <span className="text-subtle">Customer:</span>
                            <span className="ml-2 text-text font-medium">{selectedInteraction.interaction.customer_name}</span>
                          </div>
                          <div>
                            <span className="text-subtle">Contact:</span>
                            <span className="ml-2 text-text">{selectedInteraction.interaction.contact_name}</span>
                          </div>
                          {selectedInteraction.interaction.contact_phone && (
                            <div>
                              <span className="text-subtle">Phone:</span>
                              <span className="ml-2 text-text">{selectedInteraction.interaction.contact_phone}</span>
                            </div>
                          )}
                          {selectedInteraction.interaction.contact_email && (
                            <div>
                              <span className="text-subtle">Email:</span>
                              <span className="ml-2 text-text">{selectedInteraction.interaction.contact_email}</span>
                            </div>
                          )}
                          <div>
                            <span className="text-subtle">Created by:</span>
                            <span className="ml-2 text-text">{selectedInteraction.interaction.employee_name}</span>
                          </div>
                        </div>
                      </div>

                      {/* Delivery Information */}
                      <div>
                        <h4 className="font-medium text-text mb-3">Delivery Information</h4>
                        <div className="space-y-2 text-sm">
                          <div>
                            <span className="text-subtle">Address:</span>
                            <span className="ml-2 text-text">{selectedInteraction.interaction.site_address}</span>
                          </div>
                          <div>
                            <span className="text-subtle">Delivery Date:</span>
                            <span className="ml-2 text-text">{formatDate(selectedInteraction.interaction.delivery_date)}</span>
                          </div>
                          {selectedInteraction.interaction.delivery_time && (
                            <div>
                              <span className="text-subtle">Delivery Time:</span>
                              <span className="ml-2 text-text">{selectedInteraction.interaction.delivery_time}</span>
                            </div>
                          )}
                          {selectedInteraction.interaction.hire_start_date && (
                            <div>
                              <span className="text-subtle">Hire Period:</span>
                              <span className="ml-2 text-text">
                                {formatDate(selectedInteraction.interaction.hire_start_date)} 
                                {selectedInteraction.interaction.hire_end_date && ` - ${formatDate(selectedInteraction.interaction.hire_end_date)}`}
                              </span>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>

                    {selectedInteraction.interaction.notes && (
                      <div className="mt-4 pt-4 border-t border-highlight-med">
                        <h4 className="font-medium text-text mb-2">Notes</h4>
                        <p className="text-subtle text-sm">{selectedInteraction.interaction.notes}</p>
                      </div>
                    )}
                  </div>

                  {/* Equipment List */}
                  <div className="bg-surface p-6 rounded-lg">
                    <h3 className="text-lg font-semibold text-text mb-4">Equipment Booked</h3>
                    
                    {selectedInteraction.equipment.length > 0 ? (
                      <div className="space-y-3">
                        {selectedInteraction.equipment.map((item, index) => (
                          <div key={index} className="bg-overlay p-4 rounded border">
                            <div className="flex justify-between items-start">
                              <div className="flex items-center gap-3">
                                <span className="text-lg">🔧</span>
                                <div>
                                  <h4 className="font-medium text-text">{item.type_name}</h4>
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
                  {selectedInteraction.accessories.length > 0 && (
                    <div className="bg-surface p-6 rounded-lg">
                      <h3 className="text-lg font-semibold text-text mb-4">Accessories</h3>
                      
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        {selectedInteraction.accessories.map((item, index) => (
                          <div key={index} className="bg-overlay p-4 rounded border">
                            <div className="flex justify-between items-start">
                              <div className="flex items-center gap-3">
                                <span className="text-lg">📦</span>
                                <div>
                                  <h4 className="font-medium text-text">{item.accessory_name}</h4>
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

                  {/* Modal Action Buttons */}
                  <div className="flex justify-end gap-4 pt-4 border-t border-highlight-med">
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
                    
                    <button
                      onClick={handleCloseModal}
                      className="bg-red text-base px-6 py-3 rounded-lg hover:bg-love transition-colors"
                    >
                      Close
                    </button>
                  </div>
                </div>
              ) : (
                <div className="text-center py-8">
                  <p className="text-subtle">Failed to load interaction details.</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  )
}