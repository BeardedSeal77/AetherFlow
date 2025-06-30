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
  const [accessorySearch, setAccessorySearch] = useState('')
  const [showAccessoryDropdown, setShowAccessoryDropdown] = useState(false)
  
  // Loading states
  const [isLoading, setIsLoading] = useState(false)
  
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
  const equipmentAccessories = accessorySelections.filter(as => 
    as.accessory_type === 'equipment_default' || as.accessory_type === 'equipment_optional'
  )

  // ============================================================================
  // EFFECTS
  // ============================================================================

  // Load initial data
  useEffect(() => {
    loadEquipmentTypes()
    loadAllAccessories()
  }, [deliveryDate])

  // When equipment selection changes, update accessories automatically
  useEffect(() => {
    if (equipmentSelections.length > 0) {
      loadEquipmentAccessories()
    } else {
      // Keep only standalone accessories when no equipment selected
      onAccessoriesChange(standaloneAccessories)
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
      
      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          setEquipmentTypes(data.data)
        }
      }
    } catch (error) {
      console.error('Failed to load equipment types:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const loadAllAccessories = async () => {
    try {
      const response = await fetch('/api/hire/accessories/all')
      
      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          setAllAccessories(data.data)
        }
      }
    } catch (error) {
      console.error('Failed to load accessories:', error)
    }
  }

  const loadEquipmentAccessories = async () => {
    try {
      const response = await fetch('/api/hire/equipment/accessories-complete', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          equipment_selections: equipmentSelections.map(sel => ({
            equipment_type_id: sel.equipment_type_id,
            quantity: sel.quantity
          }))
        })
      })

      if (response.ok) {
        const result = await response.json()
        if (result.success) {
          // Combine equipment accessories with existing standalone accessories
          const equipmentAccessories = result.data
          const allAccessories = [...equipmentAccessories, ...standaloneAccessories]
          onAccessoriesChange(allAccessories)
        }
      }
    } catch (error) {
      console.error('Error loading equipment accessories:', error)
    }
  }

  // ============================================================================
  // EQUIPMENT FUNCTIONS
  // ============================================================================

  const addEquipmentType = (equipment: EquipmentType) => {
    // Check if already selected
    if (equipmentSelections.some(sel => sel.equipment_type_id === equipment.equipment_type_id)) {
      return
    }

    const newSelection: EquipmentSelection = {
      equipment_type_id: equipment.equipment_type_id,
      quantity: 1,
      type_name: equipment.type_name,
      type_code: equipment.type_code
    }
    
    onEquipmentChange([...equipmentSelections, newSelection])
    setEquipmentSearch('')
    setShowEquipmentDropdown(false)
  }

  const updateEquipmentQuantity = (equipmentTypeId: number, newQuantity: number) => {
    if (newQuantity <= 0) {
      // Remove equipment
      onEquipmentChange(equipmentSelections.filter(sel => sel.equipment_type_id !== equipmentTypeId))
    } else {
      // Update quantity
      onEquipmentChange(
        equipmentSelections.map(sel =>
          sel.equipment_type_id === equipmentTypeId
            ? { ...sel, quantity: newQuantity }
            : sel
        )
      )
    }
  }

  // ============================================================================
  // ACCESSORY FUNCTIONS
  // ============================================================================

  const addStandaloneAccessory = (accessory: Accessory) => {
    const newAccessory: AccessorySelection = {
      accessory_id: accessory.accessory_id,
      quantity: 1,
      accessory_type: 'standalone',
      accessory_name: accessory.accessory_name,
      unit_of_measure: accessory.unit_of_measure,
      is_consumable: accessory.is_consumable
    }
    
    onAccessoriesChange([...accessorySelections, newAccessory])
    setAccessorySearch('')
    setShowAccessoryDropdown(false)
  }

  const updateAccessoryQuantity = (accessoryId: number, newQuantity: number) => {
    if (newQuantity <= 0) {
      // Remove accessory
      onAccessoriesChange(accessorySelections.filter(acc => acc.accessory_id !== accessoryId))
    } else {
      // Update quantity
      onAccessoriesChange(
        accessorySelections.map(acc =>
          acc.accessory_id === accessoryId
            ? { ...acc, quantity: newQuantity }
            : acc
        )
      )
    }
  }

  // ============================================================================
  // RENDER
  // ============================================================================

  if (isLoading) {
    return (
      <div className="bg-surface p-6 rounded-lg">
        <div className="flex justify-center items-center h-32">
          <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-gold"></div>
        </div>
      </div>
    )
  }

  return (
    <div className="bg-surface p-6 rounded-lg">
      <h2 className="text-lg font-medium text-text mb-6">Equipment & Accessories Selection</h2>

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
          />
          
          {showEquipmentDropdown && (
            <div className="absolute z-50 w-full mt-1 bg-surface border border-highlight-med rounded shadow-lg max-h-60 overflow-y-auto">
              {filteredEquipment.length > 0 ? (
                filteredEquipment.map(equipment => (
                  <div
                    key={equipment.equipment_type_id}
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
        <div className="text-sm text-subtle mb-2">Search all accessories (equipment-specific accessories are added automatically when you select equipment)</div>
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
            <div className="space-y-2">
              {equipmentSelections.map(selection => (
                <div key={selection.equipment_type_id} className="flex items-center justify-between bg-highlight-low p-3 rounded">
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
              ))}
            </div>
          </div>
        )}

        {/* Equipment Accessories (Auto-added) */}
        {equipmentAccessories.length > 0 && (
          <div className="mb-6">
            <h4 className="text-sm font-medium text-text mb-3">Equipment Accessories (Auto-added)</h4>
            <div className="space-y-2">
              {equipmentAccessories.map(selection => (
                <div key={`${selection.accessory_id}-${selection.equipment_type_id}`} className="flex items-center justify-between bg-blue/10 p-3 rounded">
                  <div className="flex items-center gap-3">
                    <span className="text-lg">📦</span>
                    <div>
                      <span className="font-medium text-text">{selection.accessory_name}</span>
                      {selection.is_consumable && (
                        <span className="text-xs bg-yellow/20 text-yellow px-2 py-1 rounded ml-2">CONSUMABLE</span>
                      )}
                      {selection.accessory_type === 'equipment_default' && (
                        <span className="text-xs bg-green/20 text-green px-2 py-1 rounded ml-2">DEFAULT</span>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <label className="text-sm text-subtle">Qty:</label>
                    <input
                      type="number"
                      min="0"
                      step={selection.is_consumable ? "0.1" : "1"}
                      value={selection.quantity}
                      onChange={(e) => updateAccessoryQuantity(selection.accessory_id, Number(e.target.value))}
                      className="w-20 p-1 bg-overlay border border-highlight-med rounded text-center text-text"
                    />
                    <span className="text-sm text-subtle">{selection.unit_of_measure || 'item(s)'}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Standalone Accessories */}
        {standaloneAccessories.length > 0 && (
          <div className="mb-6">
            <h4 className="text-sm font-medium text-text mb-3">Standalone Accessories</h4>
            <div className="space-y-2">
              {standaloneAccessories.map(selection => (
                <div key={selection.accessory_id} className="flex items-center justify-between bg-purple/10 p-3 rounded">
                  <div className="flex items-center gap-3">
                    <span className="text-lg">📦</span>
                    <div>
                      <span className="font-medium text-text">{selection.accessory_name}</span>
                      {selection.is_consumable && (
                        <span className="text-xs bg-yellow/20 text-yellow px-2 py-1 rounded ml-2">CONSUMABLE</span>
                      )}
                      <span className="text-xs bg-purple/20 text-purple px-2 py-1 rounded ml-2">STANDALONE</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <label className="text-sm text-subtle">Qty:</label>
                    <input
                      type="number"
                      min="0"
                      step={selection.is_consumable ? "0.1" : "1"}
                      value={selection.quantity}
                      onChange={(e) => updateAccessoryQuantity(selection.accessory_id, Number(e.target.value))}
                      className="w-20 p-1 bg-overlay border border-highlight-med rounded text-center text-text"
                    />
                    <span className="text-sm text-subtle">{selection.unit_of_measure || 'item(s)'}</span>
                    <button
                      onClick={() => updateAccessoryQuantity(selection.accessory_id, 0)}
                      className="text-red hover:text-love"
                    >
                      ✕
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Summary Stats */}
        {(equipmentSelections.length > 0 || accessorySelections.length > 0) && (
          <div className="border-t border-highlight-med pt-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
              <div>
                <span className="text-subtle">Equipment Items:</span>
                <div className="text-text font-medium">{equipmentSelections.length}</div>
              </div>
              <div>
                <span className="text-subtle">Equipment Accessories:</span>
                <div className="text-text font-medium">{equipmentAccessories.length}</div>
              </div>
              <div>
                <span className="text-subtle">Standalone Accessories:</span>
                <div className="text-text font-medium">{standaloneAccessories.length}</div>
              </div>
            </div>
          </div>
        )}

        {equipmentSelections.length === 0 && accessorySelections.length === 0 && (
          <div className="text-center text-subtle py-8">
            No equipment or accessories selected yet
          </div>
        )}
      </div>
    </div>
  )
}