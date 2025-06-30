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
  equipment_type_id?: number
  accessory_name: string
  accessory_code: string
  accessory_type: 'default' | 'optional'
  default_quantity: number
  unit_of_measure: string
  description: string
  is_consumable: boolean
  type_name?: string
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
  accessory_type: string
  accessory_name?: string
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
  const [equipmentMode, setEquipmentMode] = useState<'generic' | 'specific'>('generic')
  
  // Accessory state
  const [allAccessories, setAllAccessories] = useState<Accessory[]>([]) // All accessories (for standalone use)
  const [equipmentAccessories, setEquipmentAccessories] = useState<Accessory[]>([]) // Equipment-specific accessories
  const [accessorySearch, setAccessorySearch] = useState('')
  const [showAccessoryDropdown, setShowAccessoryDropdown] = useState(false)
  const [accessoryMode, setAccessoryMode] = useState<'equipment' | 'all'>('equipment')
  
  // Loading states
  const [isLoading, setIsLoading] = useState(false)
  const [accessoriesLoading, setAccessoriesLoading] = useState(false)
  
  // Refs for dropdown management
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

  // Use appropriate accessory list based on mode
  const accessoryList = accessoryMode === 'all' ? allAccessories : equipmentAccessories
  
  const filteredAccessories = accessoryList.filter(accessory => {
    const searchLower = accessorySearch.toLowerCase()
    // Don't show already selected accessories
    const isAlreadySelected = accessorySelections.some(as => as.accessory_id === accessory.accessory_id)
    
    return (
      !isAlreadySelected &&
      (
        accessory.accessory_name.toLowerCase().includes(searchLower) ||
        accessory.accessory_code?.toLowerCase().includes(searchLower) ||
        accessory.description?.toLowerCase().includes(searchLower)
      )
    )
  }).slice(0, 15)

  // Group accessories for display
  const defaultAccessories = accessorySelections.filter(as => as.accessory_type === 'default')
  const optionalAccessories = accessorySelections.filter(as => as.accessory_type === 'optional')
  const standaloneAccessories = accessorySelections.filter(as => as.accessory_type === 'standalone')

  // ============================================================================
  // EFFECTS
  // ============================================================================

  // Load initial data
  useEffect(() => {
    loadEquipmentTypes()
    loadAllAccessories() // Load all accessories for standalone use
  }, [deliveryDate])

  // Load equipment-specific accessories and calculate defaults when equipment changes
  useEffect(() => {
    if (equipmentSelections.length > 0) {
      loadEquipmentAccessories()
    } else {
      setEquipmentAccessories([])
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
      console.error('Failed to load all accessories:', error)
    }
  }

  const loadEquipmentAccessories = async () => {
    if (equipmentSelections.length === 0) return
    
    setAccessoriesLoading(true)
    
    try {
      const response = await fetch('/api/hire/equipment/accessories-with-defaults', {
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
          setEquipmentAccessories(result.data.available_accessories)
          
          // Update accessory selections with calculated defaults and zeros for optionals
          const calculatedAccessories = result.data.calculated_accessories
          const existingStandalone = standaloneAccessories
          
          onAccessoriesChange([...calculatedAccessories, ...existingStandalone])
        }
      }
    } catch (error) {
      console.error('Error loading equipment accessories:', error)
    } finally {
      setAccessoriesLoading(false)
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

  const addAccessory = (accessory: Accessory) => {
    const accessoryType = equipmentSelections.length > 0 ? 'optional' : 'standalone'
    
    const newAccessory: AccessorySelection = {
      accessory_id: accessory.accessory_id,
      quantity: accessory.default_quantity || (accessory.is_consumable ? 1 : 1),
      accessory_type: accessoryType,
      accessory_name: accessory.accessory_name
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

  const increaseAccessoryQuantity = (accessoryId: number, isConsumable: boolean) => {
    const increment = isConsumable ? 1 : 1 // User can adjust increment as needed
    const current = accessorySelections.find(acc => acc.accessory_id === accessoryId)
    if (current) {
      updateAccessoryQuantity(accessoryId, current.quantity + increment)
    }
  }

  // ============================================================================
  // RENDER HELPERS
  // ============================================================================

  const renderAccessoryItem = (selection: AccessorySelection, bgColor: string, showControls: boolean = true) => {
    // Find accessory details from either equipment or all accessories
    const accessory = equipmentAccessories.find(a => a.accessory_id === selection.accessory_id) ||
                     allAccessories.find(a => a.accessory_id === selection.accessory_id)

    return (
      <div key={selection.accessory_id} className={`flex items-center justify-between ${bgColor} p-3 rounded`}>
        <div className="flex items-center gap-3">
          <span className="text-lg">📦</span>
          <div>
            <span className="font-medium text-text">{selection.accessory_name}</span>
            {accessory?.is_consumable && (
              <span className="text-xs bg-yellow/20 text-yellow px-2 py-1 rounded ml-2">CONSUMABLE</span>
            )}
            {selection.accessory_type === 'standalone' && (
              <span className="text-xs bg-purple/20 text-purple px-2 py-1 rounded ml-2">STANDALONE</span>
            )}
          </div>
        </div>
        <div className="flex items-center gap-3">
          {showControls ? (
            <>
              <label className="text-sm text-subtle">Qty:</label>
              <input
                type="number"
                min="0"
                step={accessory?.is_consumable ? "0.1" : "1"}
                value={selection.quantity}
                onChange={(e) => updateAccessoryQuantity(selection.accessory_id, Number(e.target.value))}
                className="w-20 p-1 bg-overlay border border-highlight-med rounded text-center text-text"
              />
              <span className="text-sm text-subtle">{accessory?.unit_of_measure || 'item(s)'}</span>
              <button
                onClick={() => updateAccessoryQuantity(selection.accessory_id, 0)}
                className="text-red hover:text-love"
              >
                ✕
              </button>
            </>
          ) : (
            <>
              <span className="text-sm text-subtle">
                {selection.quantity} {accessory?.unit_of_measure || 'item(s)'}
              </span>
              <button
                onClick={() => increaseAccessoryQuantity(selection.accessory_id, accessory?.is_consumable || false)}
                className="text-green hover:text-blue text-lg"
                title="Increase quantity"
              >
                +
              </button>
            </>
          )}
        </div>
      </div>
    )
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
      {/* Header */}
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-lg font-medium text-text">Equipment & Accessories Selection</h2>
        <div className="flex gap-2">
          <button
            onClick={() => setEquipmentMode('generic')}
            className={`px-4 py-2 rounded text-sm font-medium transition-colors ${
              equipmentMode === 'generic' 
                ? 'bg-gold text-base' 
                : 'bg-overlay text-text hover:bg-highlight-med'
            }`}
          >
            Generic Equipment
          </button>
          <button
            onClick={() => setEquipmentMode('specific')}
            className={`px-4 py-2 rounded text-sm font-medium transition-colors ${
              equipmentMode === 'specific' 
                ? 'bg-gold text-base' 
                : 'bg-overlay text-text hover:bg-highlight-med'
            }`}
          >
            Specific Equipment
          </button>
        </div>
      </div>

      <div className="text-sm text-subtle mb-6">
        {equipmentMode === 'generic' 
          ? 'Select equipment types with quantities (Phase 1 booking - specific units allocated later)'
          : 'Select specific equipment units (Direct Phase 2 allocation - one unit per selection)'
        }
      </div>

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

      {/* Selected Equipment */}
      {equipmentSelections.length > 0 && (
        <div className="mb-6">
          <h3 className="font-medium text-text mb-3">Selected Equipment</h3>
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

      {/* Default Accessories (Auto-calculated from equipment) */}
      {defaultAccessories.length > 0 && (
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-3">
            <h3 className="font-medium text-text">Default Accessories (Auto-calculated)</h3>
            {accessoriesLoading && (
              <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-gold"></div>
            )}
          </div>
          <div className="space-y-2">
            {defaultAccessories.map(selection => renderAccessoryItem(selection, 'bg-green/10', false))}
          </div>
        </div>
      )}

      {/* Optional Equipment Accessories (quantity 0, user can increase) */}
      {optionalAccessories.length > 0 && (
        <div className="mb-6">
          <h3 className="font-medium text-text mb-3">Optional Equipment Accessories</h3>
          <div className="space-y-2">
            {optionalAccessories.map(selection => renderAccessoryItem(selection, 'bg-blue/10', true))}
          </div>
        </div>
      )}

      {/* Accessory Search */}
      <div className="mb-6">
        <div className="flex justify-between items-center mb-3">
          <h3 className="font-medium text-text">Add Accessories</h3>
          <div className="flex gap-2">
            <button
              onClick={() => setAccessoryMode('equipment')}
              className={`px-3 py-1 rounded text-xs font-medium transition-colors ${
                accessoryMode === 'equipment' 
                  ? 'bg-blue text-white' 
                  : 'bg-overlay text-text hover:bg-highlight-med'
              }`}
              disabled={equipmentSelections.length === 0}
            >
              Equipment Related
            </button>
            <button
              onClick={() => setAccessoryMode('all')}
              className={`px-3 py-1 rounded text-xs font-medium transition-colors ${
                accessoryMode === 'all' 
                  ? 'bg-purple text-white' 
                  : 'bg-overlay text-text hover:bg-highlight-med'
              }`}
            >
              All Accessories
            </button>
          </div>
        </div>
        
        <div className="relative" ref={accessoryRef}>
          <input
            type="text"
            value={accessorySearch}
            onChange={(e) => setAccessorySearch(e.target.value)}
            onFocus={() => setShowAccessoryDropdown(true)}
            placeholder={accessoryMode === 'all' ? "Search all accessories..." : "Search equipment accessories..."}
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
          />
          
          {showAccessoryDropdown && (
            <div className="absolute z-50 w-full mt-1 bg-surface border border-highlight-med rounded shadow-lg max-h-60 overflow-y-auto">
              {accessoriesLoading ? (
                <div className="p-3 text-center">
                  <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-b-2 border-gold mx-auto"></div>
                </div>
              ) : filteredAccessories.length > 0 ? (
                filteredAccessories.map((accessory, index) => (
                  <div
                    key={`${accessory.accessory_id}-${accessory.equipment_type_id || 'standalone'}-${index}`}
                    onClick={() => addAccessory(accessory)}
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
                          {accessoryMode === 'equipment' && accessory.type_name && (
                            <span className="text-xs bg-blue/20 text-blue px-2 py-1 rounded">{accessory.type_name}</span>
                          )}
                        </div>
                        <div className="text-sm text-subtle mt-1">{accessory.description}</div>
                        <div className="text-xs text-subtle mt-1">
                          Default: {accessory.default_quantity} {accessory.unit_of_measure}
                        </div>
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

      {/* Standalone Accessories (added without equipment) */}
      {standaloneAccessories.length > 0 && (
        <div className="mb-6">
          <h3 className="font-medium text-text mb-3">Standalone Accessories</h3>
          <div className="space-y-2">
            {standaloneAccessories.map(selection => renderAccessoryItem(selection, 'bg-purple/10', true))}
          </div>
        </div>
      )}

      {/* Summary */}
      {(equipmentSelections.length > 0 || accessorySelections.length > 0) && (
        <div className="bg-overlay p-4 rounded">
          <h3 className="font-medium text-text mb-2">Selection Summary</h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 text-sm">
            <div>
              <span className="text-subtle">Equipment Items:</span>
              <div className="text-text font-medium">{equipmentSelections.length}</div>
            </div>
            <div>
              <span className="text-subtle">Total Equipment Units:</span>
              <div className="text-text font-medium">
                {equipmentSelections.reduce((sum, eq) => sum + eq.quantity, 0)}
              </div>
            </div>
            <div>
              <span className="text-subtle">Equipment Accessories:</span>
              <div className="text-text font-medium">
                {defaultAccessories.length} default, {optionalAccessories.length} optional
              </div>
            </div>
            <div>
              <span className="text-subtle">Standalone Accessories:</span>
              <div className="text-text font-medium">{standaloneAccessories.length}</div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}