// app/components/interaction/CustomerSelection.tsx
'use client'

import { useState, useEffect, useRef } from 'react'

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
  const [filteredCustomers, setFilteredCustomers] = useState<Customer[]>([])
  const [customerSearch, setCustomerSearch] = useState('')
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false)
  
  const [contacts, setContacts] = useState<Contact[]>([])
  const [filteredContacts, setFilteredContacts] = useState<Contact[]>([])
  const [contactSearch, setContactSearch] = useState('')
  const [showContactDropdown, setShowContactDropdown] = useState(false)
  
  const [sites, setSites] = useState<Site[]>([])
  const [filteredSites, setFilteredSites] = useState<Site[]>([])
  const [siteSearch, setSiteSearch] = useState('')
  const [showSiteDropdown, setShowSiteDropdown] = useState(false)
  
  const [isLoading, setIsLoading] = useState(false)
  
  const customerRef = useRef<HTMLDivElement>(null)
  const contactRef = useRef<HTMLDivElement>(null)
  const siteRef = useRef<HTMLDivElement>(null)

  // Load customers on mount
  useEffect(() => {
    loadCustomers()
  }, [])

  // Filter customers based on search
  useEffect(() => {
    if (customerSearch.length === 0) {
      setFilteredCustomers(customers.slice(0, 10)) // Show first 10 by default
    } else {
      const filtered = customers.filter(customer =>
        customer.customer_name.toLowerCase().includes(customerSearch.toLowerCase()) ||
        customer.customer_code.toLowerCase().includes(customerSearch.toLowerCase())
      ).slice(0, 10)
      setFilteredCustomers(filtered)
    }
  }, [customerSearch, customers])

  // Filter contacts based on search
  useEffect(() => {
    if (contactSearch.length === 0) {
      setFilteredContacts(contacts)
    } else {
      const filtered = contacts.filter(contact =>
        contact.full_name.toLowerCase().includes(contactSearch.toLowerCase()) ||
        (contact.job_title && contact.job_title.toLowerCase().includes(contactSearch.toLowerCase()))
      )
      setFilteredContacts(filtered)
    }
  }, [contactSearch, contacts])

  // Filter sites based on search
  useEffect(() => {
    if (siteSearch.length === 0) {
      setFilteredSites(sites)
    } else {
      const filtered = sites.filter(site =>
        site.site_name.toLowerCase().includes(siteSearch.toLowerCase()) ||
        site.full_address.toLowerCase().includes(siteSearch.toLowerCase())
      )
      setFilteredSites(filtered)
    }
  }, [siteSearch, sites])

  // Close dropdowns when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (customerRef.current && !customerRef.current.contains(event.target as Node)) {
        setShowCustomerDropdown(false)
      }
      if (contactRef.current && !contactRef.current.contains(event.target as Node)) {
        setShowContactDropdown(false)
      }
      if (siteRef.current && !siteRef.current.contains(event.target as Node)) {
        setShowSiteDropdown(false)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const loadCustomers = async () => {
    try {
      setIsLoading(true)
      const response = await fetch('/api/hire/customers')
      const data = await response.json()
      
      if (data.success) {
        setCustomers(data.data)
        setFilteredCustomers(data.data.slice(0, 10))
      }
    } catch (err) {
      console.error('Failed to load customers:', err)
    } finally {
      setIsLoading(false)
    }
  }

  const handleCustomerSelect = async (customer: Customer) => {
    onCustomerSelect(customer)
    setCustomerSearch(customer.customer_name)
    setShowCustomerDropdown(false)
    
    // Reset contact and site
    onContactSelect(null)
    onSiteSelect(null)
    setContactSearch('')
    setSiteSearch('')
    setContacts([])
    setSites([])

    // Load customer contacts and sites
    try {
      const [contactsRes, sitesRes] = await Promise.all([
        fetch(`/api/hire/customers/${customer.customer_id}/contacts`),
        fetch(`/api/hire/customers/${customer.customer_id}/sites`)
      ])

      const contactsData = await contactsRes.json()
      const sitesData = await sitesRes.json()

      if (contactsData.success) {
        setContacts(contactsData.data)
        setFilteredContacts(contactsData.data)
        
        // Auto-select primary contact if available
        const primaryContact = contactsData.data.find((c: Contact) => c.is_primary_contact)
        if (primaryContact) {
          handleContactSelect(primaryContact)
        }
      }
      
      if (sitesData.success) {
        setSites(sitesData.data)
        setFilteredSites(sitesData.data)
      }
    } catch (err) {
      console.error('Failed to load customer details:', err)
    }
  }

  const handleContactSelect = (contact: Contact) => {
    onContactSelect(contact)
    setContactSearch(contact.full_name)
    setShowContactDropdown(false)
  }

  const handleSiteSelect = (site: Site) => {
    onSiteSelect(site)
    setSiteSearch(site.site_name)
    setShowSiteDropdown(false)
  }

  return (
    <div className="bg-surface p-6 rounded-lg">
      <h2 className="text-lg font-medium text-text mb-4">Customer Selection</h2>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Customer Search */}
        <div className="relative" ref={customerRef}>
          <label className="block text-sm font-medium text-text mb-2">
            Customer <span className="text-red">*</span>
          </label>
          <input
            type="text"
            value={customerSearch}
            onChange={(e) => {
              setCustomerSearch(e.target.value)
              setShowCustomerDropdown(true)
            }}
            onFocus={() => setShowCustomerDropdown(true)}
            placeholder="Search customers..."
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            disabled={isLoading}
          />
          
          {showCustomerDropdown && (
            <div className="absolute z-50 w-full bg-surface border border-highlight-med rounded-md mt-1 max-h-60 overflow-y-auto shadow-lg">
              {filteredCustomers.length > 0 ? (
                filteredCustomers.map(customer => (
                  <div
                    key={customer.customer_id}
                    onClick={() => handleCustomerSelect(customer)}
                    className="p-3 hover:bg-overlay cursor-pointer border-b border-highlight-low last:border-b-0"
                  >
                    <div className="font-medium text-text">{customer.customer_name}</div>
                    <div className="text-sm text-subtle">
                      {customer.customer_code} • Credit: R{customer.credit_limit.toLocaleString()}
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-3 text-subtle">No customers found</div>
              )}
            </div>
          )}
        </div>

        {/* Contact Search */}
        <div className="relative" ref={contactRef}>
          <label className="block text-sm font-medium text-text mb-2">
            Contact <span className="text-red">*</span>
          </label>
          <input
            type="text"
            value={contactSearch}
            onChange={(e) => {
              setContactSearch(e.target.value)
              setShowContactDropdown(true)
            }}
            onFocus={() => setShowContactDropdown(true)}
            placeholder="Search contacts..."
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            disabled={!selectedCustomer}
          />
          
          {showContactDropdown && selectedCustomer && (
            <div className="absolute z-50 w-full bg-surface border border-highlight-med rounded-md mt-1 max-h-60 overflow-y-auto shadow-lg">
              {filteredContacts.length > 0 ? (
                filteredContacts.map(contact => (
                  <div
                    key={contact.contact_id}
                    onClick={() => handleContactSelect(contact)}
                    className="p-3 hover:bg-overlay cursor-pointer border-b border-highlight-low last:border-b-0"
                  >
                    <div className="font-medium text-text">{contact.full_name}</div>
                    <div className="text-sm text-subtle">
                      {contact.job_title && `${contact.job_title} • `}
                      {contact.phone_number}
                      {contact.is_primary_contact && ' • Primary'}
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-3 text-subtle">No contacts found</div>
              )}
            </div>
          )}
        </div>

        {/* Site Search */}
        <div className="relative" ref={siteRef}>
          <label className="block text-sm font-medium text-text mb-2">
            {requireSite ? 'Delivery Site' : 'Site'} {requireSite && <span className="text-red">*</span>}
          </label>
          <input
            type="text"
            value={siteSearch}
            onChange={(e) => {
              setSiteSearch(e.target.value)
              setShowSiteDropdown(true)
            }}
            onFocus={() => setShowSiteDropdown(true)}
            placeholder="Search sites..."
            className="w-full p-3 bg-overlay border border-highlight-med rounded text-text"
            disabled={!selectedCustomer}
          />
          
          {showSiteDropdown && selectedCustomer && (
            <div className="absolute z-50 w-full bg-surface border border-highlight-med rounded-md mt-1 max-h-60 overflow-y-auto shadow-lg">
              {filteredSites.length > 0 ? (
                filteredSites.map(site => (
                  <div
                    key={site.site_id}
                    onClick={() => handleSiteSelect(site)}
                    className="p-3 hover:bg-overlay cursor-pointer border-b border-highlight-low last:border-b-0"
                  >
                    <div className="font-medium text-text">{site.site_name}</div>
                    <div className="text-sm text-subtle">{site.full_address}</div>
                    {site.site_contact_name && (
                      <div className="text-xs text-muted">Contact: {site.site_contact_name}</div>
                    )}
                  </div>
                ))
              ) : (
                <div className="p-3 text-subtle">No sites found</div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Selected Customer Summary */}
      {selectedCustomer && (
        <div className="mt-4 p-4 bg-overlay rounded">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
            <div>
              <span className="text-subtle">Customer:</span>
              <div className="text-text font-medium">{selectedCustomer.customer_name}</div>
              <div className="text-subtle">{selectedCustomer.customer_code}</div>
            </div>
            
            {selectedContact && (
              <div>
                <span className="text-subtle">Contact:</span>
                <div className="text-text font-medium">{selectedContact.full_name}</div>
                <div className="text-subtle">
                  {selectedContact.job_title && `${selectedContact.job_title} • `}
                  {selectedContact.phone_number}
                </div>
              </div>
            )}
            
            {selectedSite && (
              <div>
                <span className="text-subtle">Site:</span>
                <div className="text-text font-medium">{selectedSite.site_name}</div>
                <div className="text-subtle">{selectedSite.full_address}</div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}