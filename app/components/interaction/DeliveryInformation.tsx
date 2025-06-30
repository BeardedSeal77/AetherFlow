// app/components/interaction/DeliveryInformation.tsx
'use client'

import { useState, useEffect } from 'react'

interface DeliveryInformationProps {
  deliveryDate: string
  deliveryTime: string
  contactMethod: string
  notes: string
  onDeliveryDateChange: (date: string) => void
  onDeliveryTimeChange: (time: string) => void
  onContactMethodChange: (method: string) => void
  onNotesChange: (notes: string) => void
  hireStartDate?: string
  hireEndDate?: string
  onHireStartDateChange?: (date: string) => void
  onHireEndDateChange?: (date: string) => void
  requireDelivery?: boolean
  showHirePeriod?: boolean
}

export default function DeliveryInformation({
  deliveryDate,
  deliveryTime,
  contactMethod,
  notes,
  onDeliveryDateChange,
  onDeliveryTimeChange,
  onContactMethodChange,
  onNotesChange,
  hireStartDate,
  hireEndDate,
  onHireStartDateChange,
  onHireEndDateChange,
  requireDelivery = false,
  showHirePeriod = false
}: DeliveryInformationProps) {
  const [isUrgent, setIsUrgent] = useState(false)

  // Check if delivery is same-day or urgent
  useEffect(() => {
    if (deliveryDate) {
      const today = new Date().toISOString().split('T')[0]
      const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split('T')[0]
      setIsUrgent(deliveryDate === today || deliveryDate === tomorrow)
    }
  }, [deliveryDate])

  // Auto-set hire start date to delivery date if not specified
  useEffect(() => {
    if (deliveryDate && showHirePeriod && onHireStartDateChange && !hireStartDate) {
      onHireStartDateChange(deliveryDate)
    }
  }, [deliveryDate, showHirePeriod, onHireStartDateChange, hireStartDate])

  const getMinDate = () => {
    return new Date().toISOString().split('T')[0]
  }

  const formatDateForDisplay = (dateStr: string) => {
    if (!dateStr) return ''
    const date = new Date(dateStr)
    const today = new Date()
    const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000)
    
    if (date.toDateString() === today.toDateString()) {
      return 'Today'
    } else if (date.toDateString() === tomorrow.toDateString()) {
      return 'Tomorrow'
    } else {
      return date.toLocaleDateString('en-ZA', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    }
  }

  const getUrgencyWarning = () => {
    if (!deliveryDate) return null
    
    const today = new Date().toISOString().split('T')[0]
    const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split('T')[0]
    
    if (deliveryDate === today) {
      return {
        type: 'urgent',
        message: 'Same-day delivery requires manager approval'
      }
    } else if (deliveryDate === tomorrow) {
      return {
        type: 'warning',
        message: 'Next-day delivery - ensure equipment allocation and QC are prioritized'
      }
    }
    
    return null
  }

  const urgencyWarning = getUrgencyWarning()

  return (
    <div className="bg-surface p-6 rounded-lg">
      <h2 className="text-lg font-medium text-text mb-4">
        {requireDelivery ? 'Delivery Information' : 'Scheduling Information'}
      </h2>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
        {/* Delivery Date */}
        <div>
          <label className="block text-sm font-medium text-text mb-2">
            {requireDelivery ? 'Delivery Date' : 'Scheduled Date'} 
            {requireDelivery && <span className="text-red">*</span>}
          </label>
          <input
            type="date"
            value={deliveryDate}
            onChange={(e) => onDeliveryDateChange(e.target.value)}
            min={getMinDate()}
            className={`w-full p-3 bg-overlay border rounded text-text ${
              urgencyWarning?.type === 'urgent' 
                ? 'border-red' 
                : urgencyWarning?.type === 'warning' 
                ? 'border-yellow' 
                : 'border-highlight-med'
            }`}
            required={requireDelivery}
          />
          {deliveryDate && (
            <div className="text-xs text-subtle mt-1">
              {formatDateForDisplay(deliveryDate)}
            </div>
          )}
        </div>
        
        {/* Delivery Time */}
        <div>
          <label className="block text-sm font-medium text-text mb-2">
            {requireDelivery ? 'Delivery Time' : 'Scheduled Time'}
          </label>
          <input
            type="time"
            value={deliveryTime}
            onChange={(e) => onDeliveryTimeChange(e.target.value)}
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
          />
        </div>
        
        {/* Contact Method */}
        <div>
          <label className="block text-sm font-medium text-text mb-2">
            Contact Method <span className="text-red">*</span>
          </label>
          <select
            value={contactMethod}
            onChange={(e) => onContactMethodChange(e.target.value)}
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            required
          >
            <option value="phone">Phone</option>
            <option value="email">Email</option>
            <option value="whatsapp">WhatsApp</option>
            <option value="in_person">In Person</option>
            <option value="online">Online</option>
            <option value="other">Other</option>
          </select>
        </div>
      </div>

      {/* Hire Period (for hire interactions) */}
      {showHirePeriod && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label className="block text-sm font-medium text-text mb-2">
              Hire Start Date
            </label>
            <input
              type="date"
              value={hireStartDate || ''}
              onChange={(e) => onHireStartDateChange?.(e.target.value)}
              min={deliveryDate || getMinDate()}
              className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            />
            <div className="text-xs text-subtle mt-1">
              Usually same as delivery date
            </div>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-text mb-2">
              Estimated Hire End Date
            </label>
            <input
              type="date"
              value={hireEndDate || ''}
              onChange={(e) => onHireEndDateChange?.(e.target.value)}
              min={hireStartDate || deliveryDate || getMinDate()}
              className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            />
            <div className="text-xs text-subtle mt-1">
              Optional - for planning purposes
            </div>
          </div>
        </div>
      )}

      {/* Urgency Warning */}
      {urgencyWarning && (
        <div className={`p-3 rounded mb-4 ${
          urgencyWarning.type === 'urgent' 
            ? 'bg-red/20 border border-red text-red' 
            : 'bg-yellow/20 border border-yellow text-yellow'
        }`}>
          <div className="flex items-center gap-2">
            <span className="text-lg">
              {urgencyWarning.type === 'urgent' ? '🚨' : '⚠️'}
            </span>
            <span className="font-medium">{urgencyWarning.message}</span>
          </div>
        </div>
      )}

      {/* Special Instructions */}
      <div>
        <label className="block text-sm font-medium text-text mb-2">
          Special Instructions
        </label>
        <textarea
          value={notes}
          onChange={(e) => onNotesChange(e.target.value)}
          rows={3}
          className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
          placeholder={
            requireDelivery 
              ? "Any special delivery instructions, site access requirements, or notes..."
              : "Any special instructions or additional information..."
          }
        />
      </div>

      {/* Delivery Summary */}
      {deliveryDate && (
        <div className="mt-4 p-4 bg-overlay rounded">
          <h3 className="font-medium text-text mb-2">Schedule Summary</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-subtle">
                {requireDelivery ? 'Delivery' : 'Scheduled'}:
              </span>
              <div className="text-text font-medium">
                {formatDateForDisplay(deliveryDate)}
                {deliveryTime && ` at ${deliveryTime}`}
              </div>
            </div>
            
            <div>
              <span className="text-subtle">Contact Method:</span>
              <div className="text-text font-medium capitalize">{contactMethod}</div>
            </div>
            
            {showHirePeriod && hireStartDate && hireEndDate && (
              <div className="md:col-span-2">
                <span className="text-subtle">Hire Period:</span>
                <div className="text-text font-medium">
                  {new Date(hireStartDate).toLocaleDateString('en-ZA')} - {new Date(hireEndDate).toLocaleDateString('en-ZA')}
                  {' '}({Math.ceil((new Date(hireEndDate).getTime() - new Date(hireStartDate).getTime()) / (1000 * 60 * 60 * 24))} days)
                </div>
              </div>
            )}
            
            {notes && (
              <div className="md:col-span-2">
                <span className="text-subtle">Notes:</span>
                <div className="text-text">{notes}</div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}