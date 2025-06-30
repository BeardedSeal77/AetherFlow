// app/components/interaction/EquipmentSelection.tsx
'use client'

import { useState, useEffect, useRef } from 'react'

interface EquipmentType {
  equipment_type_id: number
  type_code: string
  type_name: string
  description: string
  total_units: number
  available_units: number
}

interface Accessory {
  accessory_id: number
  accessory_name: string
  accessory_code: string
  unit_of_measure: string
  description: string
  is_consumable: boolean
}

interface AutoAccessory {
  accessory_id: number
  accessory_name: string
  accessory_code: string
  quantity: number
  unit_of_measure: string
  is_consumable: boolean
  equipment_type_name: string
  is_default: boolean
}

interface EquipmentSelection {
  equipment_type_id: number
  quantity: number
  type_name?: string
  type_code?: string
}

interface AccessorySelection {
  accessory_id: number
  quantity: number
  accessory_type: string // 'equipment_default', 'equipment_optional', 'standalone'
  accessory_name?: string
  unit_of_measure?: string
  is_consumable?: boolean
  equipment_type_id?: number // For equipment accessories
}

interface EquipmentSelectionProps {
  onEquipmentChange: (selections: EquipmentSelection[]) => void
  onAccessoriesChange: (selections: AccessorySelection[]) => void
  equipmentSelections: EquipmentSelection[]
  accessorySelections: AccessorySelection[]
  deliveryDate?: string
}

export default function EquipmentSelection({
  onEquipmentChange,
  onAccessoriesChange,
  equipmentSelections,
  accessorySelections,
  deliveryDate
}: EquipmentSelectionProps) {
  // Equipment state
  const [equipmentTypes, setEquipmentTypes] = useState<EquipmentType[]>([])
  const [equipmentSearch, setEquipmentSearch] = useState('')
  const [showEquipmentDropdown, setShowEquipmentDropdown] = useState(false)
  
  // Accessory state
  const [allAccessories, setAllAccessories] = useState<Accessory[]>([])
  const [autoAccessories, setAutoAccessories] = useState<AutoAccessory[]>([])
  const [accessorySearch, setAccessorySearch] = useState('')
  const [showAccessoryDropdown, setShowAccessoryDropdown] = useState(false)
  
  // Loading states
  const [isLoading, setIsLoading] = useState(false)
  const [isCalculatingAccessories, setIsCalculatingAccessories] = useState(false)
  
  // Refs
  const equipmentRef = useRef<HTMLDivElement>(null)
  const accessoryRef = useRef<HTMLDivElement>(null)

  // ============================================================================
  // COMPUTED VALUES
  // ============================================================================
  
  const filteredEquipment = equipmentTypes.filter(equipment => {
    if (!equipmentSearch) return true
    const searchLower = equipmentSearch.toLowerCase()
    return (
      equipment.type_name.toLowerCase().includes(searchLower) ||
      equipment.type_code.toLowerCase().includes(searchLower) ||
      equipment.description.toLowerCase().includes(searchLower)
    )
  }).slice(0, 10)

  const filteredAccessories = allAccessories.filter(accessory => {
    if (!accessorySearch) return true
    const searchLower = accessorySearch.toLowerCase()
    // Don't show already selected standalone accessories
    const isAlreadySelected = accessorySelections.some(
      as => as.accessory_id === accessory.accessory_id && as.accessory_type === 'standalone'
    )
    
    return (
      !isAlreadySelected &&
      (accessory.accessory_name.toLowerCase().includes(searchLower) ||
       accessory.accessory_code?.toLowerCase().includes(searchLower) ||
       accessory.description?.toLowerCase().includes(searchLower))
    )
  }).slice(0, 15)

  // Group accessories for display
  const standaloneAccessories = accessorySelections.filter(as => as.accessory_type === 'standalone')

  // ============================================================================
  // EFFECTS
  // ============================================================================

  // Load initial data
  useEffect(() => {
    loadEquipmentTypes()
    loadAllAccessories()
  }, [deliveryDate])

  // When equipment selection changes, calculate auto-accessories
  useEffect(() => {
    console.log('=== EQUIPMENT SELECTION CHANGED ===')
    console.log('equipmentSelections:', equipmentSelections)
    console.log('equipmentSelections.length:', equipmentSelections.length)
    
    if (equipmentSelections.length > 0) {
      console.log('Calling calculateAutoAccessories...')
      calculateAutoAccessories()
    } else {
      console.log('No equipment selected, clearing auto-accessories')
      setAutoAccessories([])
      // Keep only standalone accessories when no equipment selected
      const newAccessories = accessorySelections.filter(as => as.accessory_type === 'standalone')
      onAccessoriesChange(newAccessories)
    }
  }, [equipmentSelections])

  // Handle outside clicks
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (equipmentRef.current && !equipmentRef.current.contains(event.target as Node)) {
        setShowEquipmentDropdown(false)
      }
      if (accessoryRef.current && !accessoryRef.current.contains(event.target as Node)) {
        setShowAccessoryDropdown(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // ============================================================================
  // API FUNCTIONS
  // ============================================================================

  const loadEquipmentTypes = async () => {
    try {
      setIsLoading(true)
      const response = await fetch(`/api/hire/equipment/types${deliveryDate ? `?delivery_date=${deliveryDate}` : ''}`)
      
      if (!response.ok) {
        throw new Error('Failed to load equipment types')
      }
      
      const data = await response.json()
      if (data.success) {
        setEquipmentTypes(data.data)
      } else {
        throw new Error(data.error || 'Failed to load equipment types')
      }
    } catch (error) {
      console.error('Error loading equipment types:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const loadAllAccessories = async () => {
  try {
    console.log('=== LOADING ALL ACCESSORIES ===')
    
    const response = await fetch('/api/hire/equipment/accessories')
    
    console.log('All accessories response status:', response.status)
    
    if (!response.ok) {
      throw new Error('Failed to load accessories')
    }
    
    const data = await response.json()
    console.log('All accessories response:', data)
    
    if (data.success) {
      console.log('Setting accessories:', data.data)
      setAllAccessories(data.data)
    } else {
      throw new Error(data.error || 'Failed to load accessories')
    }
  } catch (error) {
    console.error('Error loading accessories:', error)
  }
}

  const calculateAutoAccessories = async () => {
    try {
      setIsCalculatingAccessories(true)
      
      // Transform equipment selections for API - backend expects equipment_type_id, not id
      const equipmentSelectionsForAPI = equipmentSelections.map(eq => ({
        equipment_type_id: eq.equipment_type_id, // Use the correct field name
        quantity: eq.quantity || 1 // Default quantity if missing
      }))

      // Add validation
      const validSelections = equipmentSelectionsForAPI.filter(eq => 
        eq.equipment_type_id && eq.quantity > 0
      )

      if (validSelections.length === 0) {
        console.log('No valid equipment selections to process')
        setAutoAccessories([])
        return
      }

      console.log('Sending to auto-accessories API:', validSelections)

      const response = await fetch('/api/hire/equipment/auto-accessories', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          equipment_selections: validSelections
        }),
      })

      console.log('Auto-accessories response status:', response.status)

      if (!response.ok) {
        const errorText = await response.text()
        console.error('Auto-accessories API error:', errorText)
        throw new Error(`API returned ${response.status}: ${errorText}`)
      }

      const data = await response.json()
      console.log('Auto-accessories response data:', data)
      
      if (data.success) {
        setAutoAccessories(data.data || [])
        
        // Convert auto-accessories to accessory selections and merge with standalone
        const autoAccessorySelections: AccessorySelection[] = (data.data || []).map((auto: AutoAccessory) => ({
          accessory_id: auto.accessory_id,
          quantity: auto.quantity,
          accessory_type: 'equipment_default',
          accessory_name: auto.accessory_name,
          unit_of_measure: auto.unit_of_measure,
          is_consumable: auto.is_consumable
        }))
        
        // Combine with existing standalone accessories
        const combinedAccessories = [...autoAccessorySelections, ...standaloneAccessories]
        onAccessoriesChange(combinedAccessories)
      } else {
        throw new Error(data.error || 'Failed to calculate auto-accessories')
      }
    } catch (error) {
      console.error('Error calculating auto-accessories:', error)
      // Don't throw the error, just log it and continue
      setAutoAccessories([])
    } finally {
      setIsCalculatingAccessories(false)
    }
  }

  // ============================================================================
  // EQUIPMENT FUNCTIONS
  // ============================================================================

  const addEquipmentType = (equipment: EquipmentType) => {
    const existing = equipmentSelections.find(e => e.equipment_type_id === equipment.equipment_type_id)
    
    if (existing) {
      // Increase quantity if already selected
      updateEquipmentQuantity(equipment.equipment_type_id, existing.quantity + 1)
    } else {
      // Add new equipment
      const newSelection: EquipmentSelection = {
        equipment_type_id: equipment.equipment_type_id,
        quantity: 1,
        type_name: equipment.type_name,
        type_code: equipment.type_code
      }
      
      const updatedSelections = [...equipmentSelections, newSelection]
      onEquipmentChange(updatedSelections)
    }
    
    setEquipmentSearch('')
    setShowEquipmentDropdown(false)
  }

  const updateEquipmentQuantity = (equipmentTypeId: number, newQuantity: number) => {
    if (newQuantity <= 0) {
      // Remove equipment if quantity is 0
      const updatedSelections = equipmentSelections.filter(e => e.equipment_type_id !== equipmentTypeId)
      onEquipmentChange(updatedSelections)
    } else {
      // Update quantity
      const updatedSelections = equipmentSelections.map(e =>
        e.equipment_type_id === equipmentTypeId ? { ...e, quantity: newQuantity } : e
      )
      onEquipmentChange(updatedSelections)
    }
  }

  // ============================================================================
  // ACCESSORY FUNCTIONS
  // ============================================================================

  const addStandaloneAccessory = (accessory: Accessory) => {
    const newAccessorySelection: AccessorySelection = {
      accessory_id: accessory.accessory_id,
      quantity: 1,
      accessory_type: 'standalone',
      accessory_name: accessory.accessory_name,
      unit_of_measure: accessory.unit_of_measure,
      is_consumable: accessory.is_consumable
    }
    
    const updatedAccessories = [...accessorySelections, newAccessorySelection]
    onAccessoriesChange(updatedAccessories)
    
    setAccessorySearch('')
    setShowAccessoryDropdown(false)
  }

  const updateStandaloneAccessoryQuantity = (accessoryId: number, newQuantity: number) => {
    if (newQuantity <= 0) {
      // Remove accessory if quantity is 0
      const updatedAccessories = accessorySelections.filter(a => 
        !(a.accessory_id === accessoryId && a.accessory_type === 'standalone')
      )
      onAccessoriesChange(updatedAccessories)
    } else {
      // Update quantity
      const updatedAccessories = accessorySelections.map(a =>
        a.accessory_id === accessoryId && a.accessory_type === 'standalone' 
          ? { ...a, quantity: newQuantity } 
          : a
      )
      onAccessoriesChange(updatedAccessories)
    }
  }

  const updateAutoAccessoryQuantity = (accessoryId: number, newQuantity: number) => {
    // Update in auto-accessories state
    const updatedAutoAccessories = autoAccessories.map(a =>
      a.accessory_id === accessoryId ? { ...a, quantity: Math.max(0, newQuantity) } : a
    )
    setAutoAccessories(updatedAutoAccessories)
    
    // Update in accessory selections (keep standalone, update auto)
    const autoAccessorySelections: AccessorySelection[] = updatedAutoAccessories.map(auto => ({
      accessory_id: auto.accessory_id,
      quantity: auto.quantity,
      accessory_type: 'equipment_default',
      accessory_name: auto.accessory_name,
      unit_of_measure: auto.unit_of_measure,
      is_consumable: auto.is_consumable
    }))
    
    const combinedAccessories = [...autoAccessorySelections, ...standaloneAccessories]
    onAccessoriesChange(combinedAccessories)
  }

  // ============================================================================
  // RENDER
  // ============================================================================

  return (
    <div className="space-y-6">
      {/* Equipment Search */}
      <div className="mb-6">
        <h3 className="font-medium text-text mb-3">Add Equipment</h3>
        <div className="relative" ref={equipmentRef}>
          <input
            type="text"
            value={equipmentSearch}
            onChange={(e) => setEquipmentSearch(e.target.value)}
            onFocus={() => setShowEquipmentDropdown(true)}
            placeholder="Search equipment types..."
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            disabled={isLoading}
          />
          
          {showEquipmentDropdown && (
            <div className="absolute z-50 w-full mt-1 bg-surface border border-highlight-med rounded shadow-lg max-h-60 overflow-y-auto">
              {isLoading ? (
                <div className="p-3 text-subtle">Loading equipment...</div>
              ) : filteredEquipment.length > 0 ? (
                filteredEquipment.map((equipment, index) => (
                  <div
                    key={`equipment-${equipment.equipment_type_id}-${index}`}
                    onClick={() => addEquipmentType(equipment)}
                    className="p-3 hover:bg-highlight-low cursor-pointer border-b border-highlight-low last:border-0"
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-text">{equipment.type_name}</span>
                          <span className="text-sm text-subtle">({equipment.type_code})</span>
                        </div>
                        <div className="text-sm text-subtle mt-1">{equipment.description}</div>
                        <div className="text-xs text-subtle mt-1">
                          Available: {equipment.available_units} / {equipment.total_units} units
                        </div>
                      </div>
                      <div className="ml-3">
                        <div className={`text-xs px-2 py-1 rounded ${
                          equipment.available_units > 0 ? 'bg-green/20 text-green' : 'bg-red/20 text-red'
                        }`}>
                          {equipment.available_units > 0 ? 'Available' : 'Unavailable'}
                        </div>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-3 text-subtle">No equipment found</div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Accessory Search */}
      <div className="mb-6">
        <h3 className="font-medium text-text mb-3">Add Accessories</h3>
        <div className="text-sm text-subtle mb-2">
          Search all accessories (equipment-specific accessories are added automatically when you select equipment)
        </div>
        <div className="relative" ref={accessoryRef}>
          <input
            type="text"
            value={accessorySearch}
            onChange={(e) => setAccessorySearch(e.target.value)}
            onFocus={() => setShowAccessoryDropdown(true)}
            placeholder="Search all accessories..."
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
          />
          
          {showAccessoryDropdown && (
            <div className="absolute z-50 w-full mt-1 bg-surface border border-highlight-med rounded shadow-lg max-h-60 overflow-y-auto">
              {filteredAccessories.length > 0 ? (
                filteredAccessories.map(accessory => (
                  <div
                    key={accessory.accessory_id}
                    onClick={() => addStandaloneAccessory(accessory)}
                    className="p-3 hover:bg-highlight-low cursor-pointer border-b border-highlight-low last:border-0"
                  >
                    <div className="flex justify-between items-start">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <span className="font-medium text-text">{accessory.accessory_name}</span>
                          <span className="text-sm text-subtle">({accessory.accessory_code})</span>
                          {accessory.is_consumable && (
                            <span className="text-xs bg-yellow/20 text-yellow px-2 py-1 rounded">CONSUMABLE</span>
                          )}
                        </div>
                        <div className="text-sm text-subtle mt-1">{accessory.description}</div>
                        <div className="text-xs text-subtle mt-1">Unit: {accessory.unit_of_measure}</div>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-3 text-subtle">
                  {accessorySearch ? 'No matching accessories found' : 'Search for accessories to add'}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Selection Summary */}
      <div className="bg-overlay p-4 rounded">
        <h3 className="font-medium text-text mb-4">Selection Summary</h3>
        
        {/* Selected Equipment */}
        {equipmentSelections.length > 0 && (
          <div className="mb-6">
            <h4 className="text-sm font-medium text-text mb-3">Equipment</h4>
            <div className="space-y-4">
              {equipmentSelections.map((selection, index) => (
                <div key={`equipment-selection-${selection.equipment_type_id}-${index}`} className="bg-highlight-low p-4 rounded">
                  {/* Equipment Header */}
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-3">
                      <span className="text-lg">🔧</span>
                      <div>
                        <span className="font-medium text-text">{selection.type_name}</span>
                        <span className="text-sm text-subtle ml-2">({selection.type_code})</span>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <label className="text-sm text-subtle">Qty:</label>
                      <input
                        type="number"
                        min="1"
                        max="99"
                        value={selection.quantity}
                        onChange={(e) => updateEquipmentQuantity(selection.equipment_type_id, Number(e.target.value))}
                        className="w-16 p-1 bg-overlay border border-highlight-med rounded text-center text-text"
                      />
                      <button
                        onClick={() => updateEquipmentQuantity(selection.equipment_type_id, 0)}
                        className="text-red hover:text-love"
                      >
                        ✕
                      </button>
                    </div>
                  </div>
                  
                  {/* Auto-accessories for this equipment */}
                  {autoAccessories.length > 0 && (
                    <div className="ml-6 border-l-2 border-blue/30 pl-4">
                      <div className="flex items-center gap-2 mb-2">
                        <span className="text-sm font-medium text-text">Auto-included accessories:</span>
                        {isCalculatingAccessories && (
                          <span className="text-xs text-subtle">(calculating...)</span>
                        )}
                      </div>
                      <div className="space-y-2">
                        {autoAccessories.map(accessory => (
                          <div key={`auto-${accessory.accessory_id}-${selection.equipment_type_id}`} className="flex items-center justify-between py-1">
                            <div className="flex items-center gap-2">
                              <span className="text-sm text-text">{accessory.accessory_name}</span>
                              {accessory.is_consumable && (
                                <span className="text-xs bg-yellow/20 text-yellow px-1 py-0.5 rounded">CONSUMABLE</span>
                              )}
                            </div>
                            <div className="flex items-center gap-2">
                              <button 
                                onClick={() => updateAutoAccessoryQuantity(accessory.accessory_id, accessory.quantity - (accessory.is_consumable ? 0.5 : 1))}
                                className="w-6 h-6 rounded bg-surface border border-highlight-med flex items-center justify-center hover:bg-highlight-low text-text"
                                disabled={accessory.quantity <= 0}
                              >
                                −
                              </button>
                              <span className="w-12 text-center text-sm font-medium text-text">
                                {accessory.quantity}
                              </span>
                              <button 
                                onClick={() => updateAutoAccessoryQuantity(accessory.accessory_id, accessory.quantity + (accessory.is_consumable ? 0.5 : 1))}
                                className="w-6 h-6 rounded bg-surface border border-highlight-med flex items-center justify-center hover:bg-highlight-low text-text"
                              >
                                +
                              </button>
                              <span className="text-xs text-subtle ml-2 w-16">{accessory.unit_of_measure}</span>
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Standalone Accessories */}
        {standaloneAccessories.length > 0 && (
          <div className="mb-6">
            <h4 className="text-sm font-medium text-text mb-3">Additional Accessories</h4>
            <div className="bg-orange/10 p-3 rounded space-y-2">
              {standaloneAccessories.map(selection => (
                <div key={selection.accessory_id} className="flex items-center justify-between py-1">
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-text">{selection.accessory_name}</span>
                    {selection.is_consumable && (
                      <span className="text-xs bg-yellow/20 text-yellow px-2 py-1 rounded">CONSUMABLE</span>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    <button 
                      onClick={() => updateStandaloneAccessoryQuantity(selection.accessory_id, selection.quantity - (selection.is_consumable ? 0.5 : 1))}
                      className="w-6 h-6 rounded bg-surface border border-highlight-med flex items-center justify-center hover:bg-highlight-low text-text"
                    >
                      −
                    </button>
                    <span className="w-8 text-center text-sm font-medium text-text">{selection.quantity}</span>
                    <button 
                      onClick={() => updateStandaloneAccessoryQuantity(selection.accessory_id, selection.quantity + (selection.is_consumable ? 0.5 : 1))}
                      className="w-6 h-6 rounded bg-surface border border-highlight-med flex items-center justify-center hover:bg-highlight-low text-text"
                    >
                      +
                    </button>
                    <span className="text-xs text-subtle ml-2 w-16">{selection.unit_of_measure}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Empty State */}
        {equipmentSelections.length === 0 && standaloneAccessories.length === 0 && (
          <div className="text-center py-8 text-subtle">
            <div className="text-4xl mb-2">🔧</div>
            <p>No equipment or accessories selected yet.</p>
            <p className="text-sm">Start by selecting equipment from the search above.</p>
          </div>
        )}

        {/* Summary Stats */}
        {(equipmentSelections.length > 0 || standaloneAccessories.length > 0) && (
          <div className="border-t border-highlight-med pt-4">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="text-subtle">Equipment Items:</span>
                <span className="font-medium text-text ml-2">
                  {equipmentSelections.reduce((sum, eq) => sum + eq.quantity, 0)}
                </span>
              </div>
              <div>
                <span className="text-subtle">Accessory Items:</span>
                <span className="font-medium text-text ml-2">
                  {(autoAccessories.reduce((sum, acc) => sum + acc.quantity, 0) + 
                    standaloneAccessories.reduce((sum, acc) => sum + acc.quantity, 0)).toFixed(1)}
                </span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}