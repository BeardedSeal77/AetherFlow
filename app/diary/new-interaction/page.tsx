'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'

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

export default function NewInteractionPage() {
  const router = useRouter()
  const [interactionType, setInteractionType] = useState<string>('')
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  
  // Hire-specific state
  const [customers, setCustomers] = useState<Customer[]>([])
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)
  const [contacts, setContacts] = useState<Contact[]>([])
  const [selectedContact, setSelectedContact] = useState<Contact | null>(null)
  const [sites, setSites] = useState<Site[]>([])
  const [selectedSite, setSelectedSite] = useState<Site | null>(null)
  
  const [equipmentTypes, setEquipmentTypes] = useState<EquipmentType[]>([])
  const [equipmentMode, setEquipmentMode] = useState<'generic' | 'specific'>('generic')
  const [equipmentSelections, setEquipmentSelections] = useState<EquipmentSelection[]>([])
  
  const [accessories, setAccessories] = useState<Accessory[]>([])
  const [accessorySelections, setAccessorySelections] = useState<AccessorySelection[]>([])
  
  const [deliveryDate, setDeliveryDate] = useState<string>('')
  const [deliveryTime, setDeliveryTime] = useState<string>('09:00')
  const [contactMethod, setContactMethod] = useState<string>('phone')
  const [notes, setNotes] = useState<string>('')
  
  const [isSubmitting, setIsSubmitting] = useState(false)

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

  useEffect(() => {
    if (interactionType === 'hire') {
      loadHireData()
    }
  }, [interactionType])

  const loadHireData = async () => {
    try {
      // Load customers and equipment types
      const [customersRes, equipmentRes, accessoriesRes] = await Promise.all([
        fetch('/api/hire/customers'),
        fetch('/api/hire/equipment/types'),
        fetch('/api/hire/equipment/accessories', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ equipment_type_ids: [] })
        })
      ])

      const customersData = await customersRes.json()
      const equipmentData = await equipmentRes.json()
      const accessoriesData = await accessoriesRes.json()

      if (customersData.success) setCustomers(customersData.data)
      if (equipmentData.success) setEquipmentTypes(equipmentData.data)
      if (accessoriesData.success) setAccessories(accessoriesData.data)

    } catch (err) {
      console.error('Failed to load hire data:', err)
      setError('Failed to load hire data')
    }
  }

  const handleCustomerChange = async (customerId: number) => {
    const customer = customers.find(c => c.customer_id === customerId)
    setSelectedCustomer(customer || null)
    setSelectedContact(null)
    setSelectedSite(null)
    setContacts([])
    setSites([])

    if (customer) {
      try {
        const [contactsRes, sitesRes] = await Promise.all([
          fetch(`/api/hire/customers/${customerId}/contacts`),
          fetch(`/api/hire/customers/${customerId}/sites`)
        ])

        const contactsData = await contactsRes.json()
        const sitesData = await sitesRes.json()

        if (contactsData.success) setContacts(contactsData.data)
        if (sitesData.success) setSites(sitesData.data)

      } catch (err) {
        console.error('Failed to load customer details:', err)
      }
    }
  }

  const handleContactChange = (contactId: number) => {
    const contact = contacts.find(c => c.contact_id === contactId)
    setSelectedContact(contact || null)
  }

  const handleSiteChange = (siteId: number) => {
    const site = sites.find(s => s.site_id === siteId)
    setSelectedSite(site || null)
  }

  const addEquipmentSelection = (equipmentTypeId: number) => {
    const equipmentType = equipmentTypes.find(et => et.equipment_type_id === equipmentTypeId)
    if (equipmentType) {
      const existing = equipmentSelections.find(es => es.equipment_type_id === equipmentTypeId)
      if (existing) {
        setEquipmentSelections(prev => 
          prev.map(es => 
            es.equipment_type_id === equipmentTypeId 
              ? { ...es, quantity: es.quantity + 1 }
              : es
          )
        )
      } else {
        setEquipmentSelections(prev => [...prev, {
          equipment_type_id: equipmentTypeId,
          quantity: 1,
          type_name: equipmentType.type_name,
          type_code: equipmentType.type_code
        }])
      }
      
      // Calculate auto accessories
      calculateAutoAccessories([...equipmentSelections, { equipment_type_id: equipmentTypeId, quantity: 1 }])
    }
  }

  const updateEquipmentQuantity = (equipmentTypeId: number, quantity: number) => {
    if (quantity <= 0) {
      setEquipmentSelections(prev => prev.filter(es => es.equipment_type_id !== equipmentTypeId))
    } else {
      setEquipmentSelections(prev => 
        prev.map(es => 
          es.equipment_type_id === equipmentTypeId 
            ? { ...es, quantity }
            : es
        )
      )
    }
    
    // Recalculate auto accessories
    const updatedSelections = equipmentSelections.map(es => 
      es.equipment_type_id === equipmentTypeId ? { ...es, quantity } : es
    ).filter(es => es.quantity > 0)
    calculateAutoAccessories(updatedSelections)
  }

  const calculateAutoAccessories = async (selections: EquipmentSelection[]) => {
    if (selections.length === 0) {
      setAccessorySelections([])
      return
    }

    try {
      const response = await fetch('/api/hire/equipment/auto-accessories', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ equipment_selections: selections })
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
        setAccessorySelections(prev => [
          ...prev.filter(as => as.accessory_type !== 'default'),
          ...autoAccessories
        ])
      }
    } catch (err) {
      console.error('Failed to calculate auto accessories:', err)
    }
  }

  const addOptionalAccessory = (accessoryId: number) => {
    const accessory = accessories.find(a => a.accessory_id === accessoryId)
    if (accessory) {
      const existing = accessorySelections.find(as => as.accessory_id === accessoryId)
      if (existing) {
        setAccessorySelections(prev => 
          prev.map(as => 
            as.accessory_id === accessoryId 
              ? { ...as, quantity: as.quantity + (accessory.is_consumable ? 5 : 1) }
              : as
          )
        )
      } else {
        setAccessorySelections(prev => [...prev, {
          accessory_id: accessoryId,
          quantity: accessory.default_quantity || (accessory.is_consumable ? 5 : 1),
          accessory_type: 'optional',
          accessory_name: accessory.accessory_name
        }])
      }
    }
  }

  const updateAccessoryQuantity = (accessoryId: number, quantity: number) => {
    if (quantity <= 0) {
      setAccessorySelections(prev => prev.filter(as => as.accessory_id !== accessoryId))
    } else {
      setAccessorySelections(prev => 
        prev.map(as => 
          as.accessory_id === accessoryId 
            ? { ...as, quantity }
            : as
        )
      )
    }
  }

  const handleSubmit = async () => {
    if (!selectedCustomer || !selectedContact || !selectedSite || equipmentSelections.length === 0 || !deliveryDate) {
      setError('Please complete all required fields')
      return
    }

    setIsSubmitting(true)
    setError(null)

    try {
      const hireData = {
        customer_id: selectedCustomer.customer_id,
        contact_id: selectedContact.contact_id,
        site_id: selectedSite.site_id,
        equipment_selections: equipmentSelections,
        accessory_selections: accessorySelections,
        delivery_date: deliveryDate,
        delivery_time: deliveryTime || null,
        contact_method: contactMethod,
        notes: notes
      }

      const response = await fetch('/api/hire/hires', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(hireData)
      })

      const result = await response.json()

      if (result.success) {
        // Redirect to the new view interactions page with the created interaction
        router.push(`/diary/interactions?id=${result.data.interaction_id}`)
      } else {
        setError(result.error || 'Failed to create hire interaction')
      }

    } catch (err) {
      console.error('Failed to create hire:', err)
      setError('Failed to create hire interaction')
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

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-2xl font-semibold text-text mb-6">Create New Interaction</h1>

      {error && (
        <div className="bg-red/20 border border-red text-red p-4 rounded mb-6">
          {error}
        </div>
      )}

      {/* Interaction Type Selection */}
      <div className="bg-surface p-6 rounded-lg mb-6">
        <h2 className="text-lg font-medium text-text mb-4">Select Interaction Type</h2>
        <div className="flex gap-4">
          <button
            onClick={() => setInteractionType('hire')}
            className={`px-6 py-3 rounded-lg font-medium transition-colors ${
              interactionType === 'hire' 
                ? 'bg-gold text-base' 
                : 'bg-overlay text-text hover:bg-highlight-med'
            }`}
          >
            New Hire
          </button>
          <button
            onClick={() => setInteractionType('quote')}
            className={`px-6 py-3 rounded-lg font-medium transition-colors ${
              interactionType === 'quote' 
                ? 'bg-gold text-base' 
                : 'bg-overlay text-text hover:bg-highlight-med'
            }`}
            disabled
          >
            Quote Request (Coming Soon)
          </button>
        </div>
      </div>

      {/* Hire Creation Form */}
      {interactionType === 'hire' && (
        <div className="space-y-6">
          {/* Customer Selection */}
          <div className="bg-surface p-6 rounded-lg">
            <h2 className="text-lg font-medium text-text mb-4">1. Customer Selection</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-text mb-2">Customer</label>
                <select
                  value={selectedCustomer?.customer_id || ''}
                  onChange={(e) => handleCustomerChange(Number(e.target.value))}
                  className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
                  required
                >
                  <option value="">Select Customer</option>
                  {customers.map(customer => (
                    <option key={customer.customer_id} value={customer.customer_id}>
                      {customer.customer_name} ({customer.customer_code})
                    </option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-text mb-2">Contact</label>
                <select
                  value={selectedContact?.contact_id || ''}
                  onChange={(e) => handleContactChange(Number(e.target.value))}
                  className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
                  disabled={!selectedCustomer}
                  required
                >
                  <option value="">Select Contact</option>
                  {contacts.map(contact => (
                    <option key={contact.contact_id} value={contact.contact_id}>
                      {contact.full_name} {contact.job_title && `(${contact.job_title})`}
                    </option>
                  ))}
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-text mb-2">Delivery Site</label>
                <select
                  value={selectedSite?.site_id || ''}
                  onChange={(e) => handleSiteChange(Number(e.target.value))}
                  className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
                  disabled={!selectedCustomer}
                  required
                >
                  <option value="">Select Site</option>
                  {sites.map(site => (
                    <option key={site.site_id} value={site.site_id}>
                      {site.site_name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            
            {selectedSite && (
              <div className="mt-4 p-3 bg-overlay rounded">
                <p className="text-sm text-subtle">
                  <strong>Address:</strong> {selectedSite.full_address}
                </p>
                {selectedSite.site_contact_name && (
                  <p className="text-sm text-subtle">
                    <strong>Site Contact:</strong> {selectedSite.site_contact_name} 
                    {selectedSite.site_contact_phone && ` - ${selectedSite.site_contact_phone}`}
                  </p>
                )}
                {selectedSite.delivery_instructions && (
                  <p className="text-sm text-subtle">
                    <strong>Instructions:</strong> {selectedSite.delivery_instructions}
                  </p>
                )}
              </div>
            )}
          </div>

          {/* Equipment Selection */}
          <div className="bg-surface p-6 rounded-lg">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-medium text-text">2. Equipment Selection</h2>
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

            {/* Equipment Types List */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              {equipmentTypes.map(equipment => (
                <div key={equipment.equipment_type_id} className="bg-overlay p-4 rounded border">
                  <div className="flex justify-between items-start mb-2">
                    <div>
                      <h3 className="font-medium text-text">{equipment.type_name}</h3>
                      <p className="text-sm text-subtle">{equipment.type_code}</p>
                      <p className="text-xs text-muted">{equipment.description}</p>
                    </div>
                    <span className="text-sm text-subtle">
                      {equipment.available_units}/{equipment.total_units} available
                    </span>
                  </div>
                  <button
                    onClick={() => addEquipmentSelection(equipment.equipment_type_id)}
                    className="w-full bg-green text-base py-2 rounded hover:bg-blue transition-colors"
                    disabled={equipment.available_units === 0}
                  >
                    Add to Selection
                  </button>
                </div>
              ))}
            </div>

            {/* Selected Equipment */}
            {equipmentSelections.length > 0 && (
              <div>
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
          </div>

          {/* Accessories Selection */}
          {accessorySelections.length > 0 && (
            <div className="bg-surface p-6 rounded-lg">
              <h2 className="text-lg font-medium text-text mb-4">3. Accessories</h2>
              
              {/* Auto-added accessories */}
              <div className="mb-6">
                <h3 className="font-medium text-text mb-3">Default Accessories (Auto-added)</h3>
                <div className="space-y-2">
                  {accessorySelections.filter(as => as.accessory_type === 'default').map(selection => (
                    <div key={selection.accessory_id} className="flex items-center justify-between bg-highlight-low p-3 rounded">
                      <div className="flex items-center gap-3">
                        <span className="text-lg">📦</span>
                        <span className="font-medium text-text">{selection.accessory_name}</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-sm text-subtle">Qty: {selection.quantity}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Optional accessories */}
              <div>
                <h3 className="font-medium text-text mb-3">Optional Accessories</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  {accessories.filter(acc => acc.accessory_type === 'optional' || !acc.equipment_type_id).map(accessory => (
                    <div key={accessory.accessory_id} className="bg-overlay p-4 rounded border">
                      <h4 className="font-medium text-text">{accessory.accessory_name}</h4>
                      <p className="text-xs text-muted mb-2">{accessory.description}</p>
                      <button
                        onClick={() => addOptionalAccessory(accessory.accessory_id)}
                        className="w-full bg-pine text-base py-2 rounded hover:bg-foam transition-colors"
                      >
                        Add Accessory
                      </button>
                    </div>
                  ))}
                </div>

                {/* Selected optional accessories */}
                {accessorySelections.filter(as => as.accessory_type === 'optional').length > 0 && (
                  <div className="space-y-2">
                    {accessorySelections.filter(as => as.accessory_type === 'optional').map(selection => (
                      <div key={selection.accessory_id} className="flex items-center justify-between bg-highlight-low p-3 rounded">
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
                )}
              </div>
            </div>
          )}

          {/* Delivery Information */}
          <div className="bg-surface p-6 rounded-lg">
            <h2 className="text-lg font-medium text-text mb-4">4. Delivery Information</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
              <div>
                <label className="block text-sm font-medium text-text mb-2">Delivery Date</label>
                <input
                  type="date"
                  value={deliveryDate}
                  onChange={(e) => setDeliveryDate(e.target.value)}
                  min={new Date().toISOString().split('T')[0]}
                  className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
                  required
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-text mb-2">Delivery Time</label>
                <input
                  type="time"
                  value={deliveryTime}
                  onChange={(e) => setDeliveryTime(e.target.value)}
                  className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-text mb-2">Contact Method</label>
                <select
                  value={contactMethod}
                  onChange={(e) => setContactMethod(e.target.value)}
                  className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
                >
                  <option value="phone">Phone</option>
                  <option value="email">Email</option>
                  <option value="whatsapp">WhatsApp</option>
                  <option value="in_person">In Person</option>
                </select>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-text mb-2">Special Instructions</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={3}
                className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
                placeholder="Any special delivery instructions or notes..."
              />
            </div>
          </div>

          {/* Submit Button */}
          <div className="flex justify-end gap-4">
            <button
              onClick={() => router.back()}
              className="px-6 py-3 bg-overlay text-text rounded-lg hover:bg-highlight-med transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={isSubmitting || !selectedCustomer || !selectedContact || !selectedSite || equipmentSelections.length === 0 || !deliveryDate}
              className="px-6 py-3 bg-green text-base rounded-lg hover:bg-blue transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? 'Creating...' : 'Create Hire Interaction'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}