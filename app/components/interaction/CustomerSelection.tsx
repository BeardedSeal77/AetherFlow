'use client'

import { useState, useEffect } from 'react'

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

interface CustomerSelectionProps {
  onCustomerSelect: (customer: Customer | null) => void
  onContactSelect: (contact: Contact | null) => void
  onSiteSelect: (site: Site | null) => void
  selectedCustomer: Customer | null
  selectedContact: Contact | null
  selectedSite: Site | null
  requireSite?: boolean
}

export default function CustomerSelection({
  onCustomerSelect,
  onContactSelect,
  onSiteSelect,
  selectedCustomer,
  selectedContact,
  selectedSite,
  requireSite = false
}: CustomerSelectionProps) {
  const [customers, setCustomers] = useState<Customer[]>([])
  const [contacts, setContacts] = useState<Contact[]>([])
  const [sites, setSites] = useState<Site[]>([])
  const [loading, setLoading] = useState(false)
  const [searchTerm, setSearchTerm] = useState('')

  useEffect(() => {
    loadCustomers()
  }, [])

  useEffect(() => {
    if (selectedCustomer) {
      loadCustomerData(selectedCustomer.customer_id)
    } else {
      setContacts([])
      setSites([])
      onContactSelect(null)
      onSiteSelect(null)
    }
  }, [selectedCustomer])

  const loadCustomers = async () => {
    try {
      setLoading(true)
      const response = await fetch('/api/customers', {
        credentials: 'include'
      })
      const data = await response.json()
      if (data.success) {
        setCustomers(data.customers || [])
      }
    } catch (error) {
      console.error('Error loading customers:', error)
    } finally {
      setLoading(false)
    }
  }

  const loadCustomerData = async (customerId: number) => {
    try {
      setLoading(true)
      const [contactsResponse, sitesResponse] = await Promise.all([
        fetch(`/api/customers/${customerId}/contacts`, { credentials: 'include' }),
        fetch(`/api/customers/${customerId}/sites`, { credentials: 'include' })
      ])

      const contactsData = await contactsResponse.json()
      const sitesData = await sitesResponse.json()

      if (contactsData.success) {
        setContacts(contactsData.contacts || [])
      }
      if (sitesData.success) {
        setSites(sitesData.sites || [])
      }
    } catch (error) {
      console.error('Error loading customer data:', error)
    } finally {
      setLoading(false)
    }
  }

  const filteredCustomers = customers.filter(customer =>
    customer.customer_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    customer.customer_code.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <div className="space-y-6">
      {/* Customer Selection */}
      <div className="bg-surface rounded-lg border border-highlight-low p-6">
        <h3 className="text-lg font-semibold text-gold mb-4">Customer Information</h3>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-text mb-2">
              Search Customer *
            </label>
            <div className="space-y-2">
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none focus:ring-1 focus:ring-gold"
                placeholder="Search by customer name or code..."
              />
              
              {searchTerm && (
                <div className="max-h-48 overflow-y-auto border border-highlight-med rounded-md bg-overlay">
                  {filteredCustomers.length > 0 ? (
                    filteredCustomers.map((customer) => (
                      <button
                        key={customer.customer_id}
                        onClick={() => {
                          onCustomerSelect(customer)
                          setSearchTerm('')
                        }}
                        className="w-full text-left p-3 hover:bg-highlight-low border-b border-highlight-low last:border-b-0"
                      >
                        <div className="font-medium text-text">{customer.customer_name}</div>
                        <div className="text-sm text-subtle">{customer.customer_code}</div>
                      </button>
                    ))
                  ) : (
                    <div className="p-3 text-subtle text-center">No customers found</div>
                  )}
                </div>
              )}
            </div>
            
            {selectedCustomer && (
              <div className="mt-2 p-3 bg-highlight-low rounded-md">
                <div className="font-medium text-text">{selectedCustomer.customer_name}</div>
                <div className="text-sm text-subtle">{selectedCustomer.customer_code}</div>
                <div className="text-xs text-subtle mt-1">
                  Credit Limit: ${selectedCustomer.credit_limit.toLocaleString()} | 
                  Terms: {selectedCustomer.payment_terms}
                </div>
              </div>
            )}
          </div>

          {/* Contact Selection */}
          <div>
            <label className="block text-sm font-medium text-text mb-2">
              Contact Person *
            </label>
            <select
              value={selectedContact?.contact_id || ''}
              onChange={(e) => {
                const contactId = parseInt(e.target.value)
                const contact = contacts.find(c => c.contact_id === contactId)
                onContactSelect(contact || null)
              }}
              disabled={!selectedCustomer || loading}
              className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none disabled:opacity-50"
            >
              <option value="">Select Contact...</option>
              {contacts.map((contact) => (
                <option key={contact.contact_id} value={contact.contact_id}>
                  {contact.full_name} - {contact.job_title}
                </option>
              ))}
            </select>
            
            {selectedContact && (
              <div className="mt-2 p-3 bg-highlight-low rounded-md">
                <div className="text-sm space-y-1">
                  <div><span className="text-subtle">Phone:</span> {selectedContact.phone_number}</div>
                  <div><span className="text-subtle">Email:</span> {selectedContact.email}</div>
                  {selectedContact.whatsapp_number && (
                    <div><span className="text-subtle">WhatsApp:</span> {selectedContact.whatsapp_number}</div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Site Selection */}
          <div>
            <label className="block text-sm font-medium text-text mb-2">
              Delivery Site {requireSite ? '*' : ''}
            </label>
            <select
              value={selectedSite?.site_id || ''}
              onChange={(e) => {
                const siteId = parseInt(e.target.value)
                const site = sites.find(s => s.site_id === siteId)
                onSiteSelect(site || null)
              }}
              disabled={!selectedCustomer || loading}
              className="w-full p-3 bg-overlay border border-highlight-med rounded-md text-text focus:border-gold focus:outline-none disabled:opacity-50"
            >
              <option value="">Select Site...</option>
              {sites.map((site) => (
                <option key={site.site_id} value={site.site_id}>
                  {site.site_name} - {site.site_code}
                </option>
              ))}
            </select>
            
            {selectedSite && (
              <div className="mt-2 p-3 bg-highlight-low rounded-md">
                <div className="text-sm space-y-1">
                  <div><span className="text-subtle">Address:</span> {selectedSite.full_address}</div>
                  {selectedSite.site_contact_name && (
                    <div><span className="text-subtle">Site Contact:</span> {selectedSite.site_contact_name}</div>
                  )}
                  {selectedSite.site_contact_phone && (
                    <div><span className="text-subtle">Site Phone:</span> {selectedSite.site_contact_phone}</div>
                  )}
                  {selectedSite.delivery_instructions && (
                    <div><span className="text-subtle">Instructions:</span> {selectedSite.delivery_instructions}</div>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}