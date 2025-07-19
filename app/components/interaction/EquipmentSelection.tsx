'use client'

import { useState, useEffect } from 'react'

interface EquipmentType {
  equipment_type_id: number
  type_code: string
  type_name: string
  description: string
  daily_rate: number
  available_units: number
  total_units: number
}

interface Equipment {
  equipment_id: number
  equipment_type_id: number
  asset_code: string
  type_name: string
  model: string
  condition: string
  is_overdue_service: boolean
}

interface EquipmentSelection {
  equipment_type_id: number
  equipment_generic_id?: number
  quantity: number
  type_name: string
  accessories?: any[]
}

interface EquipmentSelectionProps {
  selectedEquipment: EquipmentSelection[]
  onEquipmentChange: (equipment: EquipmentSelection[]) => void
}

export default function EquipmentSelection({
  selectedEquipment,
  onEquipmentChange
}: EquipmentSelectionProps) {
  const [searchMode, setSearchMode] = useState<'generic' | 'specific'>('generic')
  const [searchTerm, setSearchTerm] = useState('')
  const [searchResults, setSearchResults] = useState<(EquipmentType | Equipment)[]>([])
  const [loading, setLoading] = useState(false)

  const searchEquipment = async () => {
    if (!searchTerm.trim()) return

    try {
      setLoading(true)
      
      const endpoint = searchMode === 'generic' ? '/api/equipment-types' : '/api/equipment'
      const response = await fetch(`${endpoint}?search=${encodeURIComponent(searchTerm)}`, {
        credentials: 'include'
      })
      
      const data = await response.json()
      if (data.success) {
        setSearchResults(data[searchMode === 'generic' ? 'equipment_types' : 'equipment'] || [])
      }
    } catch (error) {
      console.error('Error searching equipment:', error)
    } finally {
      setLoading(false)
    }
  }

  const addEquipment = (item: EquipmentType | Equipment) => {
    const isEquipmentType = 'type_code' in item
    
    if (isEquipmentType) {
      const equipmentType = item as EquipmentType
      
      // Check if already selected
      const existing = selectedEquipment.find(
        eq => eq.equipment_type_id === equipmentType.equipment_type_id
      )
      
      if (existing) {
        // Increase quantity
        const updated = selectedEquipment.map(eq =>
          eq.equipment_type_id === equipmentType.equipment_type_id
            ? { ...eq, quantity: eq.quantity + 1 }
            : eq
        )
        onEquipmentChange(updated)
      } else {
        // Add new
        const newSelection: EquipmentSelection = {
          equipment_type_id: equipmentType.equipment_type_id,
          quantity: 1,
          type_name: equipmentType.type_name,
          accessories: []
        }
        onEquipmentChange([...selectedEquipment, newSelection])
      }
    } else {
      const equipment = item as Equipment
      
      // For specific equipment, always add as new entry
      const newSelection: EquipmentSelection = {
        equipment_type_id: equipment.equipment_type_id,
        quantity: 1,
        type_name: `${equipment.asset_code} - ${equipment.type_name}`,
        accessories: []
      }
      onEquipmentChange([...selectedEquipment, newSelection])
    }
  }

  const removeEquipment = (index: number) => {
    const updated = selectedEquipment.filter((_, i) => i !== index)
    onEquipmentChange(updated)
  }

  const updateQuantity = (index: number, quantity: number) => {
    if (quantity <= 0) {
      removeEquipment(index)
      return
    }
    
    const updated = selectedEquipment.map((eq, i) =>
      i === index ? { ...eq, quantity } : eq
    )
    onEquipmentChange(updated)
  }

  const renderEquipmentTypeCard = (equipmentType: EquipmentType) => (
    <div
      key={equipmentType.equipment_type_id}
      className="bg-overlay border border-highlight-med rounded-md p-4 hover:border-gold cursor-pointer transition-colors"
      onClick={() => addEquipment(equipmentType)}
    >
      <div className="flex justify-between items-start">
        <div className="flex-1">
          <h4 className="font-medium text-text">{equipmentType.type_name}</h4>
          <p className="text-sm text-subtle">{equipmentType.type_code}</p>
          {equipmentType.description && (
            <p className="text-xs text-subtle mt-1">{equipmentType.description}</p>
          )}
          <div className="flex justify-between mt-2 text-xs">
            <span className="text-subtle">
              Available: {equipmentType.available_units}/{equipmentType.total_units}
            </span>
            <span className="text-gold font-medium">
              ${equipmentType.daily_rate}/day
            </span>
          </div>
        </div>
        <button className="ml-3 bg-blue text-text px-3 py-1 rounded text-sm hover:bg-gold transition-colors">
          Add
        </button>
      </div>
    </div>
  )

  const renderEquipmentCard = (equipment: Equipment) => (
    <div
      key={equipment.equipment_id}
      className="bg-overlay border border-highlight-med rounded-md p-4 hover:border-gold cursor-pointer transition-colors"
      onClick={() => addEquipment(equipment)}
    >
      <div className="flex justify-between items-start">
        <div className="flex-1">
          <h4 className="font-medium text-text">{equipment.asset_code}</h4>
          <p className="text-sm text-subtle">{equipment.type_name}</p>
          {equipment.model && (
            <p className="text-xs text-subtle mt-1">{equipment.model}</p>
          )}
          <div className="flex gap-2 mt-2">
            <span className={`px-2 py-1 rounded text-xs ${
              equipment.condition === 'excellent' ? 'bg-green/20 text-green' :
              equipment.condition === 'good' ? 'bg-blue/20 text-blue' :
              equipment.condition === 'fair' ? 'bg-gold/20 text-gold' :
              'bg-red/20 text-red'
            }`}>
              {equipment.condition}
            </span>
            {equipment.is_overdue_service && (
              <span className="px-2 py-1 rounded text-xs bg-red/20 text-red">
                Service Overdue
              </span>
            )}
          </div>
        </div>
        <button className="ml-3 bg-blue text-text px-3 py-1 rounded text-sm hover:bg-gold transition-colors">
          Add
        </button>
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      {/* Equipment Search */}
      <div className="bg-surface rounded-lg border border-highlight-low p-6">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gold">Equipment Selection</h3>
          
          {/* Mode Toggle */}
          <div className="flex bg-overlay rounded-md border border-highlight-med overflow-hidden">
            <button
              onClick={() => setSearchMode('generic')}
              className={`px-4 py-2 text-sm font-medium transition-colors ${
                searchMode === 'generic'
                  ? 'bg-gold text-base'
                  : 'text-subtle hover:text-text'
              }`}
            >
              Generic Types
            </button>
            <button
              onClick={() => setSearchMode('specific')}
              className={`px-4 py-2 text-sm font-medium transition-colors ${
                searchMode === 'specific'
                  ? 'bg-gold text-base'
                  : 'text-subtle hover:text-text'
              }`}
            >
              Specific Units
            </button>
          </div>
        </div>

        {/* Search Input */}
        <div className="flex gap-2 mb-4">
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && searchEquipment()}
            className="flex-1 p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
            placeholder={`Search ${searchMode} equipment...`}
          />
          <button
            onClick={searchEquipment}
            disabled={loading || !searchTerm.trim()}
            className="bg-blue text-text px-6 py-3 rounded-md font-medium hover:bg-gold transition-colors disabled:opacity-50"
          >
            {loading ? 'Searching...' : 'Search'}
          </button>
        </div>

        {/* Search Results */}
        <div className="space-y-3 max-h-96 overflow-y-auto">
          {searchResults.length === 0 && searchTerm && !loading && (
            <div className="text-center py-8 text-subtle">
              No equipment found matching your search
            </div>
          )}
          
          {searchResults.map((item) =>
            searchMode === 'generic'
              ? renderEquipmentTypeCard(item as EquipmentType)
              : renderEquipmentCard(item as Equipment)
          )}
        </div>
      </div>

      {/* Selected Equipment */}
      <div className="bg-surface rounded-lg border border-highlight-low p-6">
        <h3 className="text-lg font-semibold text-gold mb-4">Selected Equipment</h3>
        
        {selectedEquipment.length === 0 ? (
          <div className="text-center py-8 text-subtle">
            No equipment selected yet
          </div>
        ) : (
          <div className="space-y-3">
            {selectedEquipment.map((item, index) => (
              <div
                key={index}
                className="bg-overlay border border-highlight-med rounded-md p-4 flex justify-between items-center"
              >
                <div className="flex-1">
                  <h4 className="font-medium text-text">{item.type_name}</h4>
                </div>
                
                <div className="flex items-center gap-3">
                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => updateQuantity(index, item.quantity - 1)}
                      className="w-8 h-8 bg-red text-text rounded-full flex items-center justify-center hover:bg-red/80 transition-colors"
                    >
                      -
                    </button>
                    <span className="w-8 text-center text-text">{item.quantity}</span>
                    <button
                      onClick={() => updateQuantity(index, item.quantity + 1)}
                      className="w-8 h-8 bg-green text-text rounded-full flex items-center justify-center hover:bg-green/80 transition-colors"
                    >
                      +
                    </button>
                  </div>
                  
                  <button
                    onClick={() => removeEquipment(index)}
                    className="text-red hover:text-red/80 transition-colors ml-2"
                  >
                    Remove
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}