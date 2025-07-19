'use client'

import { useState } from 'react'

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
  equipment_generic_id?: number
  quantity: number
  type_name: string
  accessories?: any[]
}

interface DeliveryFormData {
  hire_start_date: string
  hire_end_date: string
  delivery_date: string
  delivery_time: string
  special_instructions: string
  notes: string
  contact_method: string
}

interface DeliveryInformationProps {
  formData: DeliveryFormData
  onFormChange: (data: DeliveryFormData) => void
  selectedCustomer: Customer | null
  selectedContact: Contact | null
  selectedSite: Site | null
  equipmentSelections: EquipmentSelection[]
}

export default function DeliveryInformation({
  formData,
  onFormChange,
  selectedCustomer,
  selectedContact,
  selectedSite,
  equipmentSelections
}: DeliveryInformationProps) {
  const handleChange = (field: keyof DeliveryFormData, value: string) => {
    onFormChange({
      ...formData,
      [field]: value
    })
  }

  const validateDates = () => {
    const today = new Date()
    const hireStart = new Date(formData.hire_start_date)
    const hireEnd = formData.hire_end_date ? new Date(formData.hire_end_date) : null
    const delivery = new Date(formData.delivery_date)

    const warnings = []

    if (hireStart < today) {
      warnings.push('Hire start date is in the past')
    }
    if (delivery < today) {
      warnings.push('Delivery date is in the past')
    }
    if (hireEnd && hireEnd < hireStart) {
      warnings.push('Hire end date cannot be before start date')
    }

    return warnings
  }

  const dateWarnings = validateDates()

  return (
    <div className="space-y-6">
      {/* Summary */}
      <div className="bg-surface rounded-lg border border-highlight-low p-6">
        <h3 className="text-lg font-semibold text-gold mb-4">Hire Summary</h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <h4 className="font-medium text-text mb-2">Customer Details</h4>
            <div className="text-sm space-y-1">
              <p><span className="text-subtle">Customer:</span> {selectedCustomer?.customer_name}</p>
              <p><span className="text-subtle">Contact:</span> {selectedContact?.full_name}</p>
              <p><span className="text-subtle">Site:</span> {selectedSite?.site_name}</p>
            </div>
          </div>
          
          <div>
            <h4 className="font-medium text-text mb-2">Equipment Summary</h4>
            <div className="text-sm space-y-1">
              {equipmentSelections.map((item, index) => (
                <p key={index}>
                  <span className="text-gold">{item.quantity}x</span> {item.type_name}
                </p>
              ))}
              {equipmentSelections.length === 0 && (
                <p className="text-subtle">No equipment selected</p>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Delivery Details */}
      <div className="bg-surface rounded-lg border border-highlight-low p-6">
        <h3 className="text-lg font-semibold text-gold mb-4">Delivery Details</h3>
        
        <div className="space-y-4">
          {/* Date Fields */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-sm font-medium text-text mb-2">
                Hire Start Date *
              </label>
              <input
                type="date"
                value={formData.hire_start_date}
                onChange={(e) => handleChange('hire_start_date', e.target.value)}
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
                required
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-text mb-2">
                Hire End Date
              </label>
              <input
                type="date"
                value={formData.hire_end_date}
                onChange={(e) => handleChange('hire_end_date', e.target.value)}
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-text mb-2">
                Delivery Date *
              </label>
              <input
                type="date"
                value={formData.delivery_date}
                onChange={(e) => handleChange('delivery_date', e.target.value)}
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
                required
              />
            </div>
          </div>

          {/* Time and Contact Method */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-text mb-2">
                Delivery Time
              </label>
              <input
                type="time"
                value={formData.delivery_time}
                onChange={(e) => handleChange('delivery_time', e.target.value)}
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
              />
            </div>
            
            <div>
              <label className="block text-sm font-medium text-text mb-2">
                Contact Method
              </label>
              <select
                value={formData.contact_method}
                onChange={(e) => handleChange('contact_method', e.target.value)}
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none"
              >
                <option value="phone">Phone</option>
                <option value="email">Email</option>
                <option value="whatsapp">WhatsApp</option>
                <option value="in_person">In Person</option>
                <option value="online">Online</option>
              </select>
            </div>
          </div>

          {/* Date Warnings */}
          {dateWarnings.length > 0 && (
            <div className="bg-gold/20 border border-gold/30 rounded-md p-3">
              <h4 className="font-medium text-gold mb-2">Date Warnings:</h4>
              <ul className="text-sm text-gold space-y-1">
                {dateWarnings.map((warning, index) => (
                  <li key={index}>• {warning}</li>
                ))}
              </ul>
            </div>
          )}

          {/* Instructions */}
          <div>
            <label className="block text-sm font-medium text-text mb-2">
              Special Instructions
            </label>
            <textarea
              value={formData.special_instructions}
              onChange={(e) => handleChange('special_instructions', e.target.value)}
              rows={3}
              className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
              placeholder="Any special delivery or handling instructions..."
            />
          </div>

          {/* Internal Notes */}
          <div>
            <label className="block text-sm font-medium text-text mb-2">
              Internal Notes
            </label>
            <textarea
              value={formData.notes}
              onChange={(e) => handleChange('notes', e.target.value)}
              rows={3}
              className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
              placeholder="Internal notes about this hire..."
            />
          </div>
        </div>
      </div>

      {/* Site Information Display */}
      {selectedSite && (
        <div className="bg-surface rounded-lg border border-highlight-low p-6">
          <h3 className="text-lg font-semibold text-gold mb-4">Delivery Site Information</h3>
          
          <div className="text-sm space-y-2">
            <p><span className="text-subtle">Site Name:</span> {selectedSite.site_name}</p>
            <p><span className="text-subtle">Address:</span> {selectedSite.full_address}</p>
            {selectedSite.site_contact_name && (
              <p><span className="text-subtle">Site Contact:</span> {selectedSite.site_contact_name}</p>
            )}
            {selectedSite.site_contact_phone && (
              <p><span className="text-subtle">Site Phone:</span> {selectedSite.site_contact_phone}</p>
            )}
            {selectedSite.delivery_instructions && (
              <div>
                <span className="text-subtle">Delivery Instructions:</span>
                <p className="mt-1 text-text">{selectedSite.delivery_instructions}</p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}