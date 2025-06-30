// app/diary/new-interaction/page.tsx
'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

// Import the reusable components
import InteractionTypeSelector, { INTERACTION_TYPES, InteractionType } from '@/components/interaction/InteractionTypeSelector'
import CustomerSelection from '@/components/interaction/CustomerSelection'
import EquipmentSelection from '@/components/interaction/EquipmentSelection'
import DeliveryInformation from '@/components/interaction/DeliveryInformation'

interface Customer {
  customer_id: number
  customer_code: string
  customer_name: string
  is_company: boolean
  credit_limit: number
  payment_terms: string
  status: string
}

interface Contact {
  contact_id: number
  first_name: string
  last_name: string
  full_name: string
  job_title: string
  email: string
  phone_number: string
  whatsapp_number: string
  is_primary_contact: boolean
  is_billing_contact: boolean
}

interface Site {
  site_id: number
  site_code: string
  site_name: string
  site_type: string
  full_address: string
  site_contact_name: string
  site_contact_phone: string
  delivery_instructions: string
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

export default function NewInteractionPage() {
  const router = useRouter()
  
  // Interaction type and progress
  const [selectedType, setSelectedType] = useState<string>('')
  const [currentStep, setCurrentStep] = useState(1)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  
  // Customer information
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)
  const [selectedContact, setSelectedContact] = useState<Contact | null>(null)
  const [selectedSite, setSelectedSite] = useState<Site | null>(null)
  
  // Equipment information (for hire and other equipment-requiring interactions)
  const [equipmentSelections, setEquipmentSelections] = useState<EquipmentSelection[]>([])
  const [accessorySelections, setAccessorySelections] = useState<AccessorySelection[]>([])
  
  // Delivery/scheduling information
  const [deliveryDate, setDeliveryDate] = useState<string>('')
  const [deliveryTime, setDeliveryTime] = useState<string>('09:00')
  const [hireStartDate, setHireStartDate] = useState<string>('')
  const [hireEndDate, setHireEndDate] = useState<string>('')
  const [contactMethod, setContactMethod] = useState<string>('phone')
  const [notes, setNotes] = useState<string>('')

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
      })
      .catch(err => {
        console.error('Failed to fetch session:', err)
        router.push('/login')
      })
  }, [router])

  // Get the current interaction type configuration
  const getSelectedTypeConfig = (): InteractionType | null => {
    return INTERACTION_TYPES.find(type => type.key === selectedType) || null
  }

  // Calculate total steps based on interaction type
  const getTotalSteps = (): number => {
    const typeConfig = getSelectedTypeConfig()
    if (!typeConfig) return 1
    
    let steps = 2 // Type selection + Customer selection
    if (typeConfig.requiresEquipment) steps++
    if (typeConfig.requiresDelivery) steps++
    steps++ // Review & Submit
    return steps
  }

  // Get step names
  const getStepName = (step: number): string => {
    const typeConfig = getSelectedTypeConfig()
    if (!typeConfig) return 'Select Type'
    
    switch (step) {
      case 1: return 'Interaction Type'
      case 2: return 'Customer Information'
      case 3: 
        if (typeConfig.requiresEquipment) return 'Equipment Selection'
        if (typeConfig.requiresDelivery) return 'Scheduling'
        return 'Review & Submit'
      case 4:
        if (typeConfig.requiresEquipment && typeConfig.requiresDelivery) return 'Delivery Information'
        return 'Review & Submit'
      case 5: return 'Review & Submit'
      default: return 'Unknown Step'
    }
  }

  // Check if current step is valid/complete
  const isStepComplete = (step: number): boolean => {
    const typeConfig = getSelectedTypeConfig()
    
    switch (step) {
      case 1: return !!selectedType
      case 2: return !!(selectedCustomer && selectedContact && (!typeConfig?.requiresDelivery || selectedSite))
      case 3:
        if (typeConfig?.requiresEquipment) return equipmentSelections.length > 0
        if (typeConfig?.requiresDelivery) return !!deliveryDate
        return true
      case 4:
        if (typeConfig?.requiresEquipment && typeConfig?.requiresDelivery) return !!deliveryDate
        return true
      default: return false
    }
  }

  // Navigation functions
  const goToNextStep = () => {
    if (currentStep < getTotalSteps()) {
      setCurrentStep(currentStep + 1)
    }
  }

  const goToPreviousStep = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1)
    }
  }

  const goToStep = (step: number) => {
    if (step >= 1 && step <= getTotalSteps()) {
      setCurrentStep(step)
    }
  }

  // Reset form when interaction type changes
  const handleTypeSelect = (type: string) => {
    setSelectedType(type)
    setSelectedCustomer(null)
    setSelectedContact(null)
    setSelectedSite(null)
    setEquipmentSelections([])
    setAccessorySelections([])
    setDeliveryDate('')
    setDeliveryTime('09:00')
    setHireStartDate('')
    setHireEndDate('')
    setNotes('')
    setCurrentStep(2) // Move to customer selection
  }

  // Submit the interaction
  const handleSubmit = async () => {
    const typeConfig = getSelectedTypeConfig()
    if (!typeConfig || !selectedCustomer || !selectedContact) {
      setError('Please complete all required information')
      return
    }

    if (typeConfig.requiresDelivery && !selectedSite) {
      setError('Please select a delivery site')
      return
    }

    if (typeConfig.requiresEquipment && equipmentSelections.length === 0) {
      setError('Please select at least one equipment item')
      return
    }

    if (typeConfig.requiresDelivery && !deliveryDate) {
      setError('Please select a delivery date')
      return
    }

    setIsSubmitting(true)
    setError(null)

    try {
      // Build the interaction data based on type
      const interactionData: any = {
        interaction_type: selectedType,
        customer_id: selectedCustomer.customer_id,
        contact_id: selectedContact.contact_id,
        contact_method: contactMethod,
        notes: notes
      }

      // Add type-specific data
      if (typeConfig.requiresDelivery && selectedSite) {
        interactionData.site_id = selectedSite.site_id
        interactionData.delivery_date = deliveryDate
        interactionData.delivery_time = deliveryTime || null
      }

      if (typeConfig.requiresEquipment) {
        interactionData.equipment_selections = equipmentSelections
        interactionData.accessory_selections = accessorySelections
      }

      if (selectedType === 'hire') {
        interactionData.hire_start_date = hireStartDate || deliveryDate
        interactionData.estimated_hire_end = hireEndDate
      }

      // Choose the appropriate API endpoint based on interaction type
      let apiEndpoint = '/api/hire/hires' // Default to hire endpoint
      
      // For now, only hire is implemented
      if (selectedType !== 'hire') {
        throw new Error(`${typeConfig.name} interactions are not yet implemented`)
      }

      const response = await fetch(apiEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(interactionData)
      })

      const result = await response.json()

      if (result.success) {
        // Redirect based on interaction type
        if (selectedType === 'hire' && result.data.interaction_id) {
          router.push(`/diary/interactions?id=${result.data.interaction_id}`)
        } else {
          router.push('/diary/interactions')
        }
      } else {
        setError(result.error || `Failed to create ${typeConfig.name.toLowerCase()}`)
      }

    } catch (err) {
      console.error('Failed to create interaction:', err)
      setError(`Failed to create ${typeConfig?.name.toLowerCase() || 'interaction'}`)
    } finally {
      setIsSubmitting(false)
    }
  }

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-rose"></div>
      </div>
    )
  }

  const typeConfig = getSelectedTypeConfig()
  const totalSteps = getTotalSteps()

  return (
    <div className="max-w-6xl mx-auto p-6">
      {/* Header with Progress */}
      <div className="mb-6">
        <h1 className="text-2xl font-semibold text-text mb-4">Create New Interaction</h1>
        
        {/* Progress Indicator */}
        <div className="flex items-center gap-4 mb-4">
          {Array.from({ length: totalSteps }, (_, index) => {
            const step = index + 1
            const isActive = step === currentStep
            const isComplete = step < currentStep || isStepComplete(step)
            
            return (
              <div key={step} className="flex items-center">
                <button
                  onClick={() => goToStep(step)}
                  className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium transition-colors ${
                    isActive 
                      ? 'bg-gold text-base' 
                      : isComplete 
                      ? 'bg-green text-base cursor-pointer' 
                      : 'bg-overlay text-subtle cursor-not-allowed'
                  }`}
                  disabled={!isComplete && step !== currentStep}
                >
                  {isComplete && step < currentStep ? '✓' : step}
                </button>
                <span className={`ml-2 text-sm ${isActive ? 'text-text font-medium' : 'text-subtle'}`}>
                  {getStepName(step)}
                </span>
                {step < totalSteps && (
                  <div className={`mx-4 h-px w-8 ${isComplete ? 'bg-green' : 'bg-overlay'}`} />
                )}
              </div>
            )
          })}
        </div>

        {typeConfig && (
          <div className="text-sm text-subtle">
            Creating: <span className="text-text font-medium">{typeConfig.name}</span>
          </div>
        )}
      </div>

      {error && (
        <div className="bg-red/20 border border-red text-red p-4 rounded mb-6">
          {error}
        </div>
      )}

      {/* Step Content */}
      <div className="space-y-6">
        {/* Step 1: Interaction Type Selection */}
        {currentStep === 1 && (
          <InteractionTypeSelector
            selectedType={selectedType}
            onTypeSelect={handleTypeSelect}
          />
        )}

        {/* Step 2: Customer Selection */}
        {currentStep === 2 && typeConfig && (
          <CustomerSelection
            onCustomerSelect={setSelectedCustomer}
            onContactSelect={setSelectedContact}
            onSiteSelect={setSelectedSite}
            selectedCustomer={selectedCustomer}
            selectedContact={selectedContact}
            selectedSite={selectedSite}
            requireSite={typeConfig.requiresDelivery}
          />
        )}

        {/* Step 3: Equipment Selection (if required) */}
        {currentStep === 3 && typeConfig?.requiresEquipment && (
          <EquipmentSelection
            onEquipmentChange={setEquipmentSelections}
            onAccessoriesChange={setAccessorySelections}
            equipmentSelections={equipmentSelections}
            accessorySelections={accessorySelections}
            deliveryDate={deliveryDate}
          />
        )}

        {/* Step 4: Delivery Information (if required) */}
        {((currentStep === 3 && typeConfig?.requiresDelivery && !typeConfig?.requiresEquipment) ||
          (currentStep === 4 && typeConfig?.requiresDelivery)) && (
          <DeliveryInformation
            deliveryDate={deliveryDate}
            deliveryTime={deliveryTime}
            contactMethod={contactMethod}
            notes={notes}
            onDeliveryDateChange={setDeliveryDate}
            onDeliveryTimeChange={setDeliveryTime}
            onContactMethodChange={setContactMethod}
            onNotesChange={setNotes}
            hireStartDate={hireStartDate}
            hireEndDate={hireEndDate}
            onHireStartDateChange={setHireStartDate}
            onHireEndDateChange={setHireEndDate}
            requireDelivery={typeConfig?.requiresDelivery}
            showHirePeriod={selectedType === 'hire'}
          />
        )}

        {/* Final Step: Review & Submit */}
        {currentStep === totalSteps && (
          <div className="bg-surface p-6 rounded-lg">
            <h2 className="text-lg font-medium text-text mb-4">Review & Submit</h2>
            
            <div className="space-y-6">
              {/* Interaction Summary */}
              <div className="bg-overlay p-4 rounded">
                <h3 className="font-medium text-text mb-3">Interaction Summary</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <span className="text-subtle">Type:</span>
                    <div className="text-text font-medium flex items-center gap-2">
                      <span>{typeConfig?.icon}</span>
                      {typeConfig?.name}
                    </div>
                  </div>
                  <div>
                    <span className="text-subtle">Contact Method:</span>
                    <div className="text-text font-medium capitalize">{contactMethod}</div>
                  </div>
                </div>
              </div>

              {/* Customer Summary */}
              <div className="bg-overlay p-4 rounded">
                <h3 className="font-medium text-text mb-3">Customer Information</h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                  <div>
                    <span className="text-subtle">Customer:</span>
                    <div className="text-text font-medium">{selectedCustomer?.customer_name}</div>
                    <div className="text-subtle">{selectedCustomer?.customer_code}</div>
                  </div>
                  <div>
                    <span className="text-subtle">Contact:</span>
                    <div className="text-text font-medium">{selectedContact?.full_name}</div>
                    <div className="text-subtle">{selectedContact?.phone_number}</div>
                  </div>
                  {selectedSite && (
                    <div>
                      <span className="text-subtle">Delivery Site:</span>
                      <div className="text-text font-medium">{selectedSite.site_name}</div>
                      <div className="text-subtle">{selectedSite.full_address}</div>
                    </div>
                  )}
                </div>
              </div>

              {/* Equipment Summary */}
              {typeConfig?.requiresEquipment && equipmentSelections.length > 0 && (
                <div className="bg-overlay p-4 rounded">
                  <h3 className="font-medium text-text mb-3">Equipment Summary</h3>
                  <div className="space-y-2">
                    {equipmentSelections.map(selection => (
                      <div key={selection.equipment_type_id} className="flex justify-between text-sm">
                        <span className="text-text">{selection.type_name} ({selection.type_code})</span>
                        <span className="text-subtle">Qty: {selection.quantity}</span>
                      </div>
                    ))}
                  </div>
                  {accessorySelections.length > 0 && (
                    <div className="mt-3 pt-3 border-t border-highlight-med">
                      <span className="text-subtle text-sm">
                        Accessories: {accessorySelections.length} items
                      </span>
                    </div>
                  )}
                </div>
              )}

              {/* Delivery Summary */}
              {typeConfig?.requiresDelivery && deliveryDate && (
                <div className="bg-overlay p-4 rounded">
                  <h3 className="font-medium text-text mb-3">Delivery Information</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                    <div>
                      <span className="text-subtle">Date:</span>
                      <div className="text-text font-medium">
                        {new Date(deliveryDate).toLocaleDateString('en-ZA', {
                          weekday: 'long',
                          year: 'numeric',
                          month: 'long',
                          day: 'numeric'
                        })}
                      </div>
                    </div>
                    {deliveryTime && (
                      <div>
                        <span className="text-subtle">Time:</span>
                        <div className="text-text font-medium">{deliveryTime}</div>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* Notes */}
              {notes && (
                <div className="bg-overlay p-4 rounded">
                  <h3 className="font-medium text-text mb-3">Special Instructions</h3>
                  <div className="text-text text-sm">{notes}</div>
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Navigation Buttons */}
      <div className="flex justify-between items-center mt-8">
        <div>
          {currentStep > 1 && (
            <button
              onClick={goToPreviousStep}
              className="px-6 py-3 bg-overlay text-text rounded-lg hover:bg-highlight-med transition-colors"
            >
              ← Previous
            </button>
          )}
        </div>

        <div className="flex gap-4">
          <button
            onClick={() => router.push('/diary')}
            className="px-6 py-3 bg-red/20 text-red rounded-lg hover:bg-red/30 transition-colors"
          >
            Cancel
          </button>

          {currentStep < totalSteps ? (
            <button
              onClick={goToNextStep}
              disabled={!isStepComplete(currentStep)}
              className="px-6 py-3 bg-green text-base rounded-lg hover:bg-blue transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next →
            </button>
          ) : (
            <button
              onClick={handleSubmit}
              disabled={isSubmitting || !isStepComplete(currentStep)}
              className="px-6 py-3 bg-green text-base rounded-lg hover:bg-blue transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? 'Creating...' : `Create ${typeConfig?.name || 'Interaction'}`}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}