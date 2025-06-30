// app/components/interaction/InteractionTypeSelector.tsx
'use client'

interface InteractionType {
  key: string
  name: string
  description: string
  icon: string
  requiresEquipment: boolean
  requiresDelivery: boolean
  isComingSoon?: boolean
  color: string
}

interface InteractionTypeSelectorProps {
  selectedType: string
  onTypeSelect: (type: string) => void
}

const INTERACTION_TYPES: InteractionType[] = [
  {
    key: 'hire',
    name: 'Equipment Hire',
    description: 'Rent equipment to customers with delivery and collection',
    icon: '🔧',
    requiresEquipment: true,
    requiresDelivery: true,
    color: 'green'
  },
  {
    key: 'quote',
    name: 'Quote Request',
    description: 'Provide pricing quotation for equipment hire',
    icon: '💰',
    requiresEquipment: true,
    requiresDelivery: false,
    isComingSoon: true,
    color: 'blue'
  },
  {
    key: 'price_list',
    name: 'Price List Request',
    description: 'Send current pricing information to customer',
    icon: '📋',
    requiresEquipment: false,
    requiresDelivery: false,
    isComingSoon: true,
    color: 'pine'
  },
  {
    key: 'statement',
    name: 'Account Statement',
    description: 'Generate and send customer account statement',
    icon: '📊',
    requiresEquipment: false,
    requiresDelivery: false,
    isComingSoon: true,
    color: 'iris'
  },
  {
    key: 'refund',
    name: 'Refund Request',
    description: 'Process customer refund or credit note',
    icon: '💸',
    requiresEquipment: false,
    requiresDelivery: false,
    isComingSoon: true,
    color: 'love'
  },
  {
    key: 'off_hire',
    name: 'Off-Hire/Collection',
    description: 'Schedule equipment collection from customer',
    icon: '🚛',
    requiresEquipment: true,
    requiresDelivery: true,
    isComingSoon: true,
    color: 'foam'
  },
  {
    key: 'breakdown',
    name: 'Equipment Breakdown',
    description: 'Report and manage equipment breakdown or repair',
    icon: '🔨',
    requiresEquipment: true,
    requiresDelivery: false,
    isComingSoon: true,
    color: 'rose'
  },
  {
    key: 'application',
    name: 'Account Application',
    description: 'New customer account application and setup',
    icon: '📝',
    requiresEquipment: false,
    requiresDelivery: false,
    isComingSoon: true,
    color: 'gold'
  }
]

export default function InteractionTypeSelector({
  selectedType,
  onTypeSelect
}: InteractionTypeSelectorProps) {
  const getTypeColor = (type: InteractionType, isSelected: boolean) => {
    if (type.isComingSoon) {
      return 'bg-muted/20 text-muted'
    }
    
    if (isSelected) {
      return `bg-${type.color} text-base`
    }
    
    return 'bg-overlay text-text hover:bg-highlight-med'
  }

  const getSelectedTypeInfo = () => {
    return INTERACTION_TYPES.find(type => type.key === selectedType)
  }

  const selectedTypeInfo = getSelectedTypeInfo()

  return (
    <div className="bg-surface p-6 rounded-lg">
      <h2 className="text-lg font-medium text-text mb-4">Select Interaction Type</h2>
      
      {/* Type Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        {INTERACTION_TYPES.map(type => (
          <button
            key={type.key}
            onClick={() => !type.isComingSoon && onTypeSelect(type.key)}
            disabled={type.isComingSoon}
            className={`p-4 rounded-lg font-medium transition-colors text-left relative ${
              getTypeColor(type, selectedType === type.key)
            } ${type.isComingSoon ? 'cursor-not-allowed' : 'cursor-pointer'}`}
          >
            <div className="flex items-center gap-3 mb-2">
              <span className="text-2xl">{type.icon}</span>
              <div>
                <div className="font-semibold">{type.name}</div>
                {type.isComingSoon && (
                  <span className="text-xs bg-muted/30 px-2 py-1 rounded">Coming Soon</span>
                )}
              </div>
            </div>
            <div className="text-sm opacity-75">{type.description}</div>
            
            {/* Feature indicators */}
            <div className="flex gap-2 mt-3">
              {type.requiresEquipment && (
                <span className="text-xs bg-black/20 px-2 py-1 rounded">Equipment</span>
              )}
              {type.requiresDelivery && (
                <span className="text-xs bg-black/20 px-2 py-1 rounded">Delivery</span>
              )}
            </div>
          </button>
        ))}
      </div>

      {/* Selected Type Details */}
      {selectedTypeInfo && (
        <div className="p-4 bg-overlay rounded">
          <div className="flex items-center gap-3 mb-3">
            <span className="text-3xl">{selectedTypeInfo.icon}</span>
            <div>
              <h3 className="text-lg font-semibold text-text">{selectedTypeInfo.name}</h3>
              <p className="text-subtle">{selectedTypeInfo.description}</p>
            </div>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
            <div>
              <span className="text-subtle">Process Requirements:</span>
              <div className="mt-1">
                <div className="flex items-center gap-2">
                  <span className={selectedTypeInfo.requiresEquipment ? 'text-green' : 'text-muted'}>
                    {selectedTypeInfo.requiresEquipment ? '✓' : '✗'}
                  </span>
                  <span>Equipment Selection</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className={selectedTypeInfo.requiresDelivery ? 'text-green' : 'text-muted'}>
                    {selectedTypeInfo.requiresDelivery ? '✓' : '✗'}
                  </span>
                  <span>Delivery Scheduling</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-green">✓</span>
                  <span>Customer Information</span>
                </div>
              </div>
            </div>
            
            <div>
              <span className="text-subtle">Expected Workflow:</span>
              <div className="mt-1 space-y-1">
                <div>1. Customer & Contact Selection</div>
                {selectedTypeInfo.requiresEquipment && <div>2. Equipment Selection</div>}
                {selectedTypeInfo.requiresDelivery && <div>3. Delivery Information</div>}
                <div>{selectedTypeInfo.requiresEquipment && selectedTypeInfo.requiresDelivery ? '4' : selectedTypeInfo.requiresEquipment || selectedTypeInfo.requiresDelivery ? '3' : '2'}. Review & Submit</div>
              </div>
            </div>
            
            <div>
              <span className="text-subtle">Creates:</span>
              <div className="mt-1 space-y-1">
                <div>• Interaction Record ({selectedTypeInfo.key.toUpperCase()})</div>
                {selectedTypeInfo.requiresEquipment && <div>• Equipment Booking</div>}
                {selectedTypeInfo.requiresDelivery && <div>• Driver Task</div>}
                <div>• Communication Log</div>
              </div>
            </div>
          </div>
        </div>
      )}
      
      {/* Help Text */}
      <div className="mt-4 p-3 bg-highlight-low rounded text-sm text-subtle">
        <span className="font-medium">Tip:</span> Each interaction type follows a different workflow. 
        Equipment hires require the full process including equipment selection and delivery scheduling, 
        while administrative tasks like price lists or statements only need customer information.
      </div>
    </div>
  )
}

// Export the interaction types for use in other components
export { INTERACTION_TYPES }
export type { InteractionType }