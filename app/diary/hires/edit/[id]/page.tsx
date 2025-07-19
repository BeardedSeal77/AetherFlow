'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import AuthCheck from '../../../../auth/AuthCheck'

interface HireDetails {
  interaction_id: number
  reference_number: string
  customer_name: string
  contact_name: string
  site_name: string
  hire_start_date: string
  hire_end_date: string
  delivery_date: string
  delivery_time: string
  contact_method: string
  special_instructions: string
  notes: string
  status: string
  allocation_status: string
  equipment: Array<{
    id: number
    mode: 'generic' | 'specific'
    equipment_type_id: number
    equipment_id?: number
    name: string
    code: string
    quantity: number
    daily_rate: number
    asset_code?: string
    condition?: string
  }>
  accessories: Array<{
    accessory_id: number
    accessory_name: string
    accessory_code: string
    quantity: number
    unit_of_measure: string
    unit_rate: number
  }>
}

interface AvailableEquipment {
  equipment_id: number
  asset_code: string
  model: string
  condition: string
  type_name: string
  daily_rate: number
}

const ribbonSections = [
  { key: 'view', url: '/diary/hires/view', displayName: 'View All' },
  { key: 'allocate', url: '/diary/hires/allocate', displayName: 'Allocate' },
  { key: 'new', url: '/diary/hires/new', displayName: 'New Hire' }
]

export default function EditHirePage({ params }: { params: Promise<{ id: string }> }) {
  const router = useRouter()
  const searchParams = useSearchParams()
  const focusAllocation = searchParams.get('focus') === 'allocation'
  
  const [hire, setHire] = useState<HireDetails | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)
  const [activeTab, setActiveTab] = useState<'details' | 'equipment' | 'allocation'>('details')
  const [hireId, setHireId] = useState<string>('')
  
  // Allocation state
  const [allocatingEquipment, setAllocatingEquipment] = useState<any>(null)
  const [availableEquipment, setAvailableEquipment] = useState<AvailableEquipment[]>([])
  const [selectedEquipment, setSelectedEquipment] = useState<number[]>([])

  useEffect(() => {
    // Unwrap params using React.use()
    const unwrapParams = async () => {
      const resolvedParams = await params
      setHireId(resolvedParams.id)
    }
    unwrapParams()
  }, [params])

  useEffect(() => {
    if (hireId) {
      loadHireDetails()
      if (focusAllocation) {
        setActiveTab('allocation')
      }
    }
  }, [hireId, focusAllocation])

  const loadHireDetails = async () => {
    try {
      setIsLoading(true)
      const response = await fetch(`/api/hires/${hireId}`, {
        credentials: 'include'
      })
      if (response.ok) {
        const data = await response.json()
        setHire(data)
      }
    } catch (error) {
      console.error('Error loading hire details:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const startAllocation = async (equipment: any) => {
    setAllocatingEquipment(equipment)
    setSelectedEquipment([])
    
    try {
      const response = await fetch(`/api/hires/equipment/${equipment.equipment_type_id}/available`, {
        method: 'GET',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        setAvailableEquipment(data)
      }
    } catch (error) {
      console.error('Error loading available equipment:', error)
    }
  }

  const toggleEquipmentSelection = (equipmentId: number) => {
    setSelectedEquipment(prev => {
      const isSelected = prev.includes(equipmentId)
      if (isSelected) {
        return prev.filter(id => id !== equipmentId)
      } else {
        // Check if we can select more based on quantity needed
        if (prev.length >= (allocatingEquipment?.quantity || 1)) {
          return prev
        }
        return [...prev, equipmentId]
      }
    })
  }

  const confirmAllocation = async () => {
    if (!allocatingEquipment || selectedEquipment.length === 0) return
    
    try {
      setIsSaving(true)
      const response = await fetch('/api/hires/allocate-equipment', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify({
          hire_id: hire?.interaction_id,
          equipment_type_id: allocatingEquipment.equipment_type_id,
          equipment_ids: selectedEquipment,
          quantity: selectedEquipment.length
        })
      })
      
      if (response.ok) {
        // Refresh hire details
        await loadHireDetails()
        setAllocatingEquipment(null)
        setSelectedEquipment([])
      }
    } catch (error) {
      console.error('Error confirming allocation:', error)
    } finally {
      setIsSaving(false)
    }
  }

  const removeEquipment = async (equipmentIndex: number) => {
    if (!hire) return
    
    try {
      setIsSaving(true)
      const equipment = hire.equipment[equipmentIndex]
      
      const response = await fetch('/api/hires/remove-equipment', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',
        body: JSON.stringify({
          hire_id: hire.interaction_id,
          equipment_type_id: equipment.equipment_type_id,
          equipment_id: equipment.equipment_id
        })
      })
      
      if (response.ok) {
        await loadHireDetails()
      }
    } catch (error) {
      console.error('Error removing equipment:', error)
    } finally {
      setIsSaving(false)
    }
  }

  if (isLoading) {
    return (
      <AuthCheck>
        <div className="min-h-screen bg-base flex items-center justify-center">
          <div className="text-center">
            <div className="text-4xl mb-4">⏳</div>
            <p className="text-subtle">Loading hire details...</p>
          </div>
        </div>
      </AuthCheck>
    )
  }

  if (!hire) {
    return (
      <AuthCheck>
        <div className="min-h-screen bg-base flex items-center justify-center">
          <div className="text-center">
            <div className="text-4xl mb-4">❌</div>
            <p className="text-subtle">Hire not found</p>
          </div>
        </div>
      </AuthCheck>
    )
  }

  const hasGenericEquipment = hire.equipment.some(eq => eq.mode === 'generic')

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        
        
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div className="flex justify-between items-center">
              <div>
                <h1 className="text-2xl font-bold text-gold">Edit Hire: {hire.reference_number}</h1>
                <p className="text-subtle mt-1">{hire.customer_name} • {hire.delivery_date}</p>
              </div>
              <div className="flex gap-4">
                <button
                  onClick={() => router.push('/diary/hires/view')}
                  className="px-4 py-2 bg-overlay text-text rounded-lg hover:bg-highlight-low transition-colors"
                >
                  ← Back to Hires
                </button>
                {hasGenericEquipment && (
                  <button
                    onClick={() => setActiveTab('allocation')}
                    className="px-4 py-2 bg-blue text-white rounded-lg hover:bg-blue/80 transition-colors"
                  >
                    Allocate Equipment
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>

        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          {/* Tabs */}
          <div className="mb-6 flex gap-2">
            {[
              { key: 'details', label: 'Hire Details' },
              { key: 'equipment', label: 'Equipment & Accessories' },
              ...(hasGenericEquipment ? [{ key: 'allocation', label: 'Allocation' }] : [])
            ].map(tab => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key as any)}
                className={`px-4 py-2 rounded-lg transition-colors ${
                  activeTab === tab.key
                    ? 'bg-gold text-base'
                    : 'bg-surface text-text hover:bg-highlight-low'
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Tab Content */}
          {activeTab === 'details' && (
            <div className="bg-surface border border-highlight-low rounded-lg p-6">
              <h2 className="text-xl font-semibold text-text mb-4">Hire Information</h2>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <div>
                    <label className="text-sm text-subtle">Customer</label>
                    <p className="text-text font-medium">{hire.customer_name}</p>
                  </div>
                  <div>
                    <label className="text-sm text-subtle">Contact</label>
                    <p className="text-text">{hire.contact_name}</p>
                  </div>
                  <div>
                    <label className="text-sm text-subtle">Site</label>
                    <p className="text-text">{hire.site_name}</p>
                  </div>
                  <div>
                    <label className="text-sm text-subtle">Contact Method</label>
                    <p className="text-text">{hire.contact_method}</p>
                  </div>
                </div>
                
                <div className="space-y-4">
                  <div>
                    <label className="text-sm text-subtle">Hire Period</label>
                    <p className="text-text">{hire.hire_start_date} to {hire.hire_end_date || 'TBC'}</p>
                  </div>
                  <div>
                    <label className="text-sm text-subtle">Delivery</label>
                    <p className="text-text">{hire.delivery_date} at {hire.delivery_time}</p>
                  </div>
                  <div>
                    <label className="text-sm text-subtle">Status</label>
                    <p className="text-text">{hire.status} / {hire.allocation_status}</p>
                  </div>
                </div>
              </div>
              
              {hire.special_instructions && (
                <div className="mt-6">
                  <label className="text-sm text-subtle">Special Instructions</label>
                  <p className="text-text">{hire.special_instructions}</p>
                </div>
              )}
              
              {hire.notes && (
                <div className="mt-4">
                  <label className="text-sm text-subtle">Internal Notes</label>
                  <p className="text-text">{hire.notes}</p>
                </div>
              )}
            </div>
          )}

          {activeTab === 'equipment' && (
            <div className="space-y-6">
              {/* Equipment */}
              <div className="bg-surface border border-highlight-low rounded-lg p-6">
                <h2 className="text-xl font-semibold text-text mb-4">Equipment</h2>
                
                <div className="space-y-3">
                  {hire.equipment.map((equipment, index) => (
                    <div key={index} className="p-4 bg-overlay border border-highlight-med rounded-lg">
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <div className="flex items-center gap-3 mb-2">
                            <h4 className="font-medium text-text">{equipment.name}</h4>
                            <span className={`px-2 py-1 rounded text-xs ${
                              equipment.mode === 'generic' 
                                ? 'bg-yellow text-base' 
                                : 'bg-green text-white'
                            }`}>
                              {equipment.mode.toUpperCase()}
                            </span>
                            {equipment.mode === 'generic' && (
                              <span className="text-xs text-yellow">NEEDS ALLOCATION</span>
                            )}
                          </div>
                          <p className="text-sm text-subtle">{equipment.code}</p>
                          {equipment.mode === 'specific' && equipment.condition && (
                            <p className="text-sm text-subtle">Condition: {equipment.condition}</p>
                          )}
                          <div className="flex gap-4 text-sm mt-2">
                            <span>Quantity: {equipment.quantity}</span>
                            <span className="text-green">£{equipment.daily_rate}/day</span>
                          </div>
                        </div>
                        <div className="flex gap-2">
                          {equipment.mode === 'generic' && hasGenericEquipment && (
                            <button
                              onClick={() => {
                                setActiveTab('allocation')
                                startAllocation(equipment)
                              }}
                              className="px-3 py-1 bg-blue text-white rounded hover:bg-blue/80 transition-colors text-sm"
                            >
                              Allocate
                            </button>
                          )}
                          <button
                            onClick={() => removeEquipment(index)}
                            disabled={isSaving}
                            className="px-3 py-1 bg-red text-white rounded hover:bg-red/80 transition-colors text-sm disabled:opacity-50"
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Accessories */}
              <div className="bg-surface border border-highlight-low rounded-lg p-6">
                <h2 className="text-xl font-semibold text-text mb-4">Accessories</h2>
                
                <div className="space-y-2">
                  {hire.accessories.map((accessory, index) => (
                    <div key={index} className="p-3 bg-overlay/50 border border-highlight-low rounded-lg">
                      <div className="flex justify-between items-center">
                        <div>
                          <span className="text-text font-medium">{accessory.accessory_name}</span>
                          <span className="text-subtle ml-2">({accessory.accessory_code})</span>
                        </div>
                        <div className="flex gap-4 text-sm">
                          <span>{accessory.quantity} {accessory.unit_of_measure}</span>
                          <span className="text-green">£{accessory.unit_rate}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {activeTab === 'allocation' && hasGenericEquipment && (
            <div className="space-y-6">
              {!allocatingEquipment ? (
                <div className="bg-surface border border-highlight-low rounded-lg p-6">
                  <h2 className="text-xl font-semibold text-text mb-4">Select Equipment to Allocate</h2>
                  
                  <div className="space-y-3">
                    {hire.equipment.filter(eq => eq.mode === 'generic').map((equipment, index) => (
                      <div key={index} className="p-4 bg-overlay border border-highlight-med rounded-lg">
                        <div className="flex justify-between items-center">
                          <div>
                            <h4 className="font-medium text-text">{equipment.name}</h4>
                            <p className="text-sm text-subtle">Quantity needed: {equipment.quantity}</p>
                          </div>
                          <button
                            onClick={() => startAllocation(equipment)}
                            className="px-4 py-2 bg-blue text-white rounded-lg hover:bg-blue/80 transition-colors"
                          >
                            Start Allocation
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* Available Equipment */}
                  <div className="bg-surface border border-highlight-low rounded-lg p-6">
                    <h2 className="text-xl font-semibold text-text mb-4">
                      Available {allocatingEquipment.name}
                    </h2>
                    <p className="text-sm text-subtle mb-4">
                      Select {allocatingEquipment.quantity} unit(s)
                    </p>
                    
                    <div className="space-y-2 max-h-80 overflow-y-auto">
                      {availableEquipment.map(equipment => (
                        <div
                          key={equipment.equipment_id}
                          onClick={() => toggleEquipmentSelection(equipment.equipment_id)}
                          className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                            selectedEquipment.includes(equipment.equipment_id)
                              ? 'border-gold bg-gold/10'
                              : 'border-highlight-med bg-overlay hover:border-gold'
                          }`}
                        >
                          <div className="flex justify-between items-start">
                            <div>
                              <h4 className="font-medium text-text">{equipment.asset_code}</h4>
                              <p className="text-sm text-subtle">{equipment.model}</p>
                              <p className="text-sm text-subtle">Condition: {equipment.condition}</p>
                            </div>
                            <div className="text-right">
                              <p className="text-sm text-green">£{equipment.daily_rate}/day</p>
                              {selectedEquipment.includes(equipment.equipment_id) && (
                                <span className="text-xs text-gold">✓ Selected</span>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Allocation Summary */}
                  <div className="bg-surface border border-highlight-low rounded-lg p-6">
                    <h2 className="text-xl font-semibold text-text mb-4">Allocation Summary</h2>
                    
                    <div className="space-y-4">
                      <div>
                        <label className="text-sm text-subtle">Equipment Type</label>
                        <p className="text-text font-medium">{allocatingEquipment.name}</p>
                      </div>
                      
                      <div>
                        <label className="text-sm text-subtle">Required Quantity</label>
                        <p className="text-text">{allocatingEquipment.quantity}</p>
                      </div>
                      
                      <div>
                        <label className="text-sm text-subtle">Selected</label>
                        <p className="text-text">{selectedEquipment.length} / {allocatingEquipment.quantity}</p>
                      </div>
                      
                      {selectedEquipment.length > 0 && (
                        <div>
                          <label className="text-sm text-subtle">Selected Equipment</label>
                          <div className="space-y-1 mt-1">
                            {selectedEquipment.map(equipmentId => {
                              const equipment = availableEquipment.find(eq => eq.equipment_id === equipmentId)
                              return equipment ? (
                                <p key={equipmentId} className="text-sm text-text">
                                  {equipment.asset_code} - {equipment.condition}
                                </p>
                              ) : null
                            })}
                          </div>
                        </div>
                      )}
                    </div>
                    
                    <div className="flex gap-3 mt-6">
                      <button
                        onClick={() => {
                          setAllocatingEquipment(null)
                          setSelectedEquipment([])
                        }}
                        className="flex-1 px-4 py-2 bg-overlay text-text rounded-lg hover:bg-highlight-low transition-colors"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={confirmAllocation}
                        disabled={selectedEquipment.length !== allocatingEquipment.quantity || isSaving}
                        className="flex-1 px-4 py-2 bg-gold text-base rounded-lg hover:bg-gold/80 transition-colors disabled:opacity-50"
                      >
                        {isSaving ? 'Allocating...' : 'Confirm Allocation'}
                      </button>
                    </div>
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