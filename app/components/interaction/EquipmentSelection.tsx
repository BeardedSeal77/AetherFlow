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
  accessory_type: 'default' | 'optional'
  billing_method: string
  default_quantity: number
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
  const [equipmentTypes, setEquipmentTypes] = useState<EquipmentType[]>([])
  const [filteredEquipment, setFilteredEquipment] = useState<EquipmentType[]>([])
  const [equipmentSearch, setEquipmentSearch] = useState('')
  const [showEquipmentDropdown, setShowEquipmentDropdown] = useState(false)
  
  const [accessories, setAccessories] = useState<Accessory[]>([])
  const [filteredAccessories, setFilteredAccessories] = useState<Accessory[]>([])
  const [accessorySearch, setAccessorySearch] = useState('')
  const [showAccessoryDropdown, setShowAccessoryDropdown] = useState(false)
  
  const [equipmentMode, setEquipmentMode] = useState<'generic' | 'specific'>('generic')
  const [isLoading, setIsLoading] = useState(false)
  
  const equipmentRef = useRef<HTMLDivElement>(null)
  const accessoryRef = useRef<HTMLDivElement>(null)

  // Load equipment types and accessories on mount
  useEffect(() => {
    loadEquipmentData()
  }, [deliveryDate])

  // Filter equipment based on search
  useEffect(() => {
    if (equipmentSearch.length === 0) {
      setFilteredEquipment(equipmentTypes.slice(0, 10))
    } else {
      const filtered = equipmentTypes.filter(equipment =>
        equipment.type_name.toLowerCase().includes(equipmentSearch.toLowerCase()) ||
        equipment.type_code.toLowerCase().includes(equipmentSearch.toLowerCase()) ||
        equipment.description.toLowerCase().includes(equipmentSearch.toLowerCase())
      ).slice(0, 10)
      setFilteredEquipment(filtered)
    }
  }, [equipmentSearch, equipmentTypes])

  // Filter accessories based on search
  useEffect(() => {
    if (accessorySearch.length === 0) {
      setFilteredAccessories(accessories.filter(acc => acc.accessory_type === 'optional').slice(0, 10))
    } else {
      const filtered = accessories.filter(accessory =>
        accessory.accessory_type === 'optional' &&
        (accessory.accessory_name.toLowerCase().includes(accessorySearch.toLowerCase()) ||
         (accessory.description && accessory.description.toLowerCase().includes(accessorySearch.toLowerCase())))
      ).slice(0, 10)
      setFilteredAccessories(filtered)
    }
  }, [accessorySearch, accessories])

  // Calculate auto accessories when equipment changes
  useEffect(() => {
    if (equipmentSelections.length > 0) {
      calculateAutoAccessories()
    } else {
      // Remove default accessories when no equipment selected
      const optionalOnly = accessorySelections.filter(as => as.accessory_type !== 'default')
      onAccessoriesChange(optionalOnly)
    }
  }, [equipmentSelections])

  // Close dropdowns when clicking outside
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

  const loadEquipmentData = async () => {
    try {
      setIsLoading(true)
      const [equipmentRes, accessoriesRes] = await Promise.all([
        fetch(`/api/hire/equipment/types${deliveryDate ? `?delivery_date=${deliveryDate}` : ''}`),
        fetch('/api/hire/equipment/accessories', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ equipment_type_ids: [] })
        })
      ])

      const equipmentData = await equipmentRes.json()
      const accessoriesData = await accessoriesRes.json()

      if (equipmentData.success) {
        setEquipmentTypes(equipmentData.data)
        setFilteredEquipment(equipmentData.data.slice(0, 10))
      }
      
      if (accessoriesData.success) {
        setAccessories(accessoriesData.data)
        setFilteredAccessories(accessoriesData.data.filter((acc: Accessory) => acc.accessory_type === 'optional').slice(0, 10))
      }
    } catch (err) {
      console.error('Failed to load equipment data:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const calculateAutoAccessories = async () => {
    try {
      const response = await fetch('/api/hire/equipment/auto-accessories', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ equipment_selections: equipmentSelections })
      })

      const data = await response.json()
      if (data.success) {
        const autoAccessories = data.data.map((acc: any) => ({
          accessory_id: acc.accessory_id,
          quantity: acc.total_quantity,
          accessory_type: 'default',
          accessory_name: acc.accessory_name
        }))
        
        // Keep existing optional accessories, replace defaults
        const optionalAccessories = accessorySelections.filter(as => as.accessory_type !== 'default')
        onAccessoriesChange([...optionalAccessories, ...autoAccessories])
      }
    } catch (err) {
      console.error('Failed to calculate auto accessories:', err)
    }
  }

  const addEquipmentSelection = (equipment: EquipmentType) => {
    const existing = equipmentSelections.find(es => es.equipment_type_id === equipment.equipment_type_id)
    
    if (existing) {
      // Increase quantity
      const updated = equipmentSelections.map(es => 
        es.equipment_type_id === equipment.equipment_type_id 
          ? { ...es, quantity: es.quantity + 1 }
          : es
      )
      onEquipmentChange(updated)
    } else {
      // Add new selection
      const newSelection = {
        equipment_type_id: equipment.equipment_type_id,
        quantity: 1,
        type_name: equipment.type_name,
        type_code: equipment.type_code
      }
      onEquipmentChange([...equipmentSelections, newSelection])
    }
    
    setEquipmentSearch('')
    setShowEquipmentDropdown(false)
  }

  const updateEquipmentQuantity = (equipmentTypeId: number, quantity: number) => {
    if (quantity <= 0) {
      onEquipmentChange(equipmentSelections.filter(es => es.equipment_type_id !== equipmentTypeId))
    } else {
      onEquipmentChange(equipmentSelections.map(es => 
        es.equipment_type_id === equipmentTypeId ? { ...es, quantity } : es
      ))
    }
  }

  const addOptionalAccessory = (accessory: Accessory) => {
    const existing = accessorySelections.find(as => as.accessory_id === accessory.accessory_id)
    
    if (existing) {
      // Increase quantity
      const updated = accessorySelections.map(as => 
        as.accessory_id === accessory.accessory_id 
          ? { ...as, quantity: as.quantity + (accessory.is_consumable ? 5 : 1) }
          : as
      )
      onAccessoriesChange(updated)
    } else {
      // Add new selection
      const newSelection = {
        accessory_id: accessory.accessory_id,
        quantity: accessory.default_quantity || (accessory.is_consumable ? 5 : 1),
        accessory_type: 'optional',
        accessory_name: accessory.accessory_name
      }
      onAccessoriesChange([...accessorySelections, newSelection])
    }
    
    setAccessorySearch('')
    setShowAccessoryDropdown(false)
  }

  const updateAccessoryQuantity = (accessoryId: number, quantity: number) => {
    if (quantity <= 0) {
      onAccessoriesChange(accessorySelections.filter(as => as.accessory_id !== accessoryId))
    } else {
      onAccessoriesChange(accessorySelections.map(as => 
        as.accessory_id === accessoryId ? { ...as, quantity } : as
      ))
    }
  }

  return (
    <div className="bg-surface p-6 rounded-lg">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-lg font-medium text-text">Equipment Selection</h2>
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
            disabled
          >
            Specific Equipment
          </button>
        </div>
      </div>

      {/* Equipment Search */}
      <div className="mb-6">
        <div className="relative" ref={equipmentRef}>
          <label className="block text-sm font-medium text-text mb-2">
            Search Equipment <span className="text-red">*</span>
          </label>
          <input
            type="text"
            value={equipmentSearch}
            onChange={(e) => {
              setEquipmentSearch(e.target.value)
              setShowEquipmentDropdown(true)
            }}
            onFocus={() => setShowEquipmentDropdown(true)}
            placeholder="Search for equipment types..."
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            disabled={isLoading}
          />
          
          {showEquipmentDropdown && (
            <div className="absolute z-50 w-full bg-surface border border-highlight-med rounded-md mt-1 max-h-60 overflow-y-auto shadow-lg">
              {filteredEquipment.length > 0 ? (
                filteredEquipment.map(equipment => (
                  <div
                    key={equipment.equipment_type_id}
                    onClick={() => addEquipmentSelection(equipment)}
                    className="p-3 hover:bg-overlay cursor-pointer border-b border-highlight-low last:border-b-0"
                  >
                    <div className="flex justify-between items-start">
                      <div>
                        <div className="font-medium text-text">{equipment.type_name}</div>
                        <div className="text-sm text-subtle">{equipment.type_code}</div>
                        <div className="text-xs text-muted">{equipment.description}</div>
                      </div>
                      <div className="text-right">
                        <div className="text-sm text-subtle">
                          {equipment.available_units}/{equipment.total_units} available
                        </div>
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

      {/* Default Accessories */}
      {accessorySelections.filter(as => as.accessory_type === 'default').length > 0 && (
        <div className="mb-6">
          <h3 className="font-medium text-text mb-3">Default Accessories (Auto-added)</h3>
          <div className="space-y-2">
            {accessorySelections.filter(as => as.accessory_type === 'default').map(selection => (
              <div key={selection.accessory_id} className="flex items-center justify-between bg-green/10 p-3 rounded">
                <div className="flex items-center gap-3">
                  <span className="text-lg">📦</span>
                  <span className="font-medium text-text">{selection.accessory_name}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-sm text-subtle">Qty: {selection.quantity}</span>
                  <span className="text-xs px-2 py-1 rounded bg-green/20 text-green">DEFAULT</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Optional Accessories Search */}
      <div className="mb-6">
        <div className="relative" ref={accessoryRef}>
          <label className="block text-sm font-medium text-text mb-2">
            Add Optional Accessories
          </label>
          <input
            type="text"
            value={accessorySearch}
            onChange={(e) => {
              setAccessorySearch(e.target.value)
              setShowAccessoryDropdown(true)
            }}
            onFocus={() => setShowAccessoryDropdown(true)}
            placeholder="Search for accessories..."
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
          />
          
          {showAccessoryDropdown && (
            <div className="absolute z-50 w-full bg-surface border border-highlight-med rounded-md mt-1 max-h-60 overflow-y-auto shadow-lg">
              {filteredAccessories.length > 0 ? (
                filteredAccessories.map(accessory => (
                  <div
                    key={accessory.accessory_id}
                    onClick={() => addOptionalAccessory(accessory)}
                    className="p-3 hover:bg-overlay cursor-pointer border-b border-highlight-low last:border-b-0"
                  >
                    <div className="flex justify-between items-start">
                      <div>
                        <div className="font-medium text-text">{accessory.accessory_name}</div>
                        <div className="text-xs text-muted">{accessory.description}</div>
                        {accessory.type_name && (
                          <div className="text-xs text-subtle">For: {accessory.type_name}</div>
                        )}
                      </div>
                      <div className="text-right">
                        <div className={`text-xs px-2 py-1 rounded ${
                          accessory.is_consumable ? 'bg-yellow/20 text-yellow' : 'bg-blue/20 text-blue'
                        }`}>
                          {accessory.is_consumable ? 'Consumable' : 'Reusable'}
                        </div>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-3 text-subtle">No accessories found</div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Selected Optional Accessories */}
      {accessorySelections.filter(as => as.accessory_type === 'optional').length > 0 && (
        <div>
          <h3 className="font-medium text-text mb-3">Optional Accessories</h3>
          <div className="space-y-2">
            {accessorySelections.filter(as => as.accessory_type === 'optional').map(selection => (
              <div key={selection.accessory_id} className="flex items-center justify-between bg-blue/10 p-3 rounded">
                <div className="flex items-center gap-3">
                  <span className="text-lg">📦</span>
                  <span className="font-medium text-text">{selection.accessory_name}</span>
                </div>
                <div className="flex items-center gap-3">
                  <label className="text-sm text-subtle">Qty:</label>
                  <input
                    type="number"
                    min="1"
                    value={selection.quantity}
                    onChange={(e) => updateAccessoryQuantity(selection.accessory_id, Number(e.target.value))}
                    className="w-16 p-1 bg-overlay border border-highlight-med rounded text-center text-text"
                  />
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

      {/* Equipment Summary */}
      {equipmentSelections.length > 0 && (
        <div className="mt-6 p-4 bg-overlay rounded">
          <h3 className="font-medium text-text mb-2">Selection Summary</h3>
          <div className="text-sm text-subtle">
            <div>Equipment Items: {equipmentSelections.length}</div>
            <div>Total Accessories: {accessorySelections.length}</div>
            <div>Default Accessories: {accessorySelections.filter(as => as.accessory_type === 'default').length}</div>
            <div>Optional Accessories: {accessorySelections.filter(as => as.accessory_type === 'optional').length}</div>
          </div>
        </div>
      )}
    </div>
  )
}