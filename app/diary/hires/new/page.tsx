"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import AuthCheck from "../../../auth/AuthCheck";

interface Customer {
  id: number;
  name: string;
  customer_code: string;
}

interface Contact {
  contact_id: number;
  full_name: string;
  email: string;
  phone_number: string;
  job_title: string;
  is_primary_contact: boolean;
}

interface Site {
  site_id: number;
  site_name: string;
  full_address: string;
  site_contact_name: string;
  site_contact_phone: string;
}

interface EquipmentType {
  equipment_type_id: number;
  type_code: string;
  type_name: string;
  description: string;
  daily_rate: number;
  available_units: number;
  total_units: number;
}

interface Equipment {
  equipment_id: number;
  equipment_type_id: number;
  asset_code: string;
  type_name: string;
  model: string;
  condition: string;
  is_overdue_service: boolean;
}

interface SelectedEquipment {
  id: number;
  mode: "generic" | "specific";
  equipment_type_id: number;
  equipment_id?: number;
  name: string;
  code: string;
  quantity: number;
  daily_rate: number;
  attached_accessories?: AutoAccessory[];
}

interface AutoAccessory {
  accessory_id: number;
  accessory_code: string;
  accessory_name: string;
  total_quantity: number;
  unit_of_measure: string;
  unit_rate: number;
  accessory_type: string;
}

export default function NewHirePage() {
  const router = useRouter();

  // Form state
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [sites, setSites] = useState<Site[]>([]);
  const [selectedCustomer, setSelectedCustomer] = useState("");
  const [selectedContact, setSelectedContact] = useState("");
  const [selectedSite, setSelectedSite] = useState("");

  // Search states for dropdowns
  const [customerSearch, setCustomerSearch] = useState("");
  const [contactSearch, setContactSearch] = useState("");
  const [siteSearch, setSiteSearch] = useState("");
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [showContactDropdown, setShowContactDropdown] = useState(false);
  const [showSiteDropdown, setShowSiteDropdown] = useState(false);

  // Equipment state
  const [equipmentMode, setEquipmentMode] = useState<"generic" | "specific">(
    "generic",
  );
  const [equipmentSearch, setEquipmentSearch] = useState("");
  const [equipmentResults, setEquipmentResults] = useState<
    EquipmentType[] | Equipment[]
  >([]);
  const [selectedEquipment, setSelectedEquipment] = useState<
    SelectedEquipment[]
  >([]);
  const [autoAccessories, setAutoAccessories] = useState<AutoAccessory[]>([]);

  // Date state
  const [hireStartDate, setHireStartDate] = useState("");
  const [hireEndDate, setHireEndDate] = useState("");
  const [deliveryDate, setDeliveryDate] = useState("");
  const [deliveryTime, setDeliveryTime] = useState("09:00");
  const [contactMethod, setContactMethod] = useState("phone");
  const [specialInstructions, setSpecialInstructions] = useState("");
  const [notes, setNotes] = useState("");

  // Loading states
  const [isLoading, setIsLoading] = useState(false);
  const [isSearching, setIsSearching] = useState(false);

  useEffect(() => {
    // Set default dates
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split("T")[0];

    setHireStartDate(tomorrowStr);
    setDeliveryDate(tomorrowStr);

    // Load initial data
    loadCustomers();

    // Close dropdowns when clicking outside
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest(".relative")) {
        setShowCustomerDropdown(false);
        setShowContactDropdown(false);
        setShowSiteDropdown(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const loadCustomers = async (search = "") => {
    try {
      const url = search
        ? `/api/customers?search=${encodeURIComponent(search)}`
        : "/api/customers";
      const response = await fetch(url, { credentials: "include" });
      if (response.ok) {
        const data = await response.json();
        setCustomers(data);
      }
    } catch (error) {
      console.error("Error loading customers:", error);
    }
  };

  const onCustomerChange = async (customerId: string) => {
    setSelectedCustomer(customerId);
    setSelectedContact("");
    setSelectedSite("");
    setContactSearch("");
    setSiteSearch("");

    if (!customerId) {
      setContacts([]);
      setSites([]);
      return;
    }

    try {
      const [contactsRes, sitesRes] = await Promise.all([
        fetch(`/api/customers/${customerId}/contacts`, {
          credentials: "include",
        }),
        fetch(`/api/customers/${customerId}/sites`, { credentials: "include" }),
      ]);

      if (contactsRes.ok) {
        const contactsData = await contactsRes.json();
        setContacts(contactsData);
      }

      if (sitesRes.ok) {
        const sitesData = await sitesRes.json();
        setSites(sitesData);
      }
    } catch (error) {
      console.error("Error loading customer data:", error);
    }
  };

  // Clear functions
  const clearCustomerInfo = () => {
    setCustomerSearch("");
    setContactSearch("");
    setSiteSearch("");
    setSelectedCustomer("");
    setSelectedContact("");
    setSelectedSite("");
    setContacts([]);
    setSites([]);
    setShowCustomerDropdown(false);
    setShowContactDropdown(false);
    setShowSiteDropdown(false);
    setContactMethod("phone");
  };

  const clearHireDetails = () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split("T")[0];

    setHireStartDate(tomorrowStr);
    setHireEndDate("");
    setDeliveryDate(tomorrowStr);
    setDeliveryTime("09:00");
    setSpecialInstructions("");
    setNotes("");
  };

  const clearSelectedEquipment = () => {
    setSelectedEquipment([]);
    setAutoAccessories([]);
    setEquipmentSearch("");
    setEquipmentResults([]);
  };

  const clearEntirePage = () => {
    clearCustomerInfo();
    clearHireDetails();
    clearSelectedEquipment();
  };

  // Helper functions for searchable dropdowns
  const handleCustomerSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setCustomerSearch(value);
    setShowCustomerDropdown(true);
    loadCustomers(value);
  };

  const selectCustomer = (customer: Customer) => {
    setCustomerSearch(`${customer.name} (${customer.customer_code})`);
    setShowCustomerDropdown(false);
    onCustomerChange(customer.id.toString());
  };

  const handleContactSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setContactSearch(value);
    setShowContactDropdown(true);
    if (selectedCustomer) {
      loadCustomerContacts(selectedCustomer, value);
    }
  };

  const selectContact = (contact: Contact) => {
    setContactSearch(contact.full_name);
    setShowContactDropdown(false);
    setSelectedContact(contact.contact_id.toString());
  };

  const handleSiteSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSiteSearch(value);
    setShowSiteDropdown(true);
    if (selectedCustomer) {
      loadCustomerSites(selectedCustomer, value);
    }
  };

  const selectSite = (site: Site) => {
    setSiteSearch(site.site_name);
    setShowSiteDropdown(false);
    setSelectedSite(site.site_id.toString());
  };

  const loadCustomerContacts = async (customerId: string, search = "") => {
    try {
      const response = await fetch(`/api/customers/${customerId}/contacts`, {
        credentials: "include",
      });
      if (response.ok) {
        const data = await response.json();
        const filtered = search
          ? data.filter(
              (contact: Contact) =>
                contact.full_name
                  .toLowerCase()
                  .includes(search.toLowerCase()) ||
                contact.job_title.toLowerCase().includes(search.toLowerCase()),
            )
          : data;
        setContacts(filtered);
      }
    } catch (error) {
      console.error("Error loading contacts:", error);
    }
  };

  const loadCustomerSites = async (customerId: string, search = "") => {
    try {
      const response = await fetch(`/api/customers/${customerId}/sites`, {
        credentials: "include",
      });
      if (response.ok) {
        const data = await response.json();
        const filtered = search
          ? data.filter(
              (site: Site) =>
                site.site_name.toLowerCase().includes(search.toLowerCase()) ||
                site.full_address.toLowerCase().includes(search.toLowerCase()),
            )
          : data;
        setSites(filtered);
      }
    } catch (error) {
      console.error("Error loading sites:", error);
    }
  };

  const searchEquipment = async () => {
    if (!equipmentSearch.trim()) {
      setEquipmentResults([]);
      return;
    }

    setIsSearching(true);
    try {
      const endpoint =
        equipmentMode === "generic" ? "/api/equipment-types" : "/api/equipment";
      const params = new URLSearchParams({
        search: equipmentSearch,
        hire_start_date: hireStartDate,
      });

      const response = await fetch(`${endpoint}?${params}`, {
        credentials: "include",
      });

      if (response.ok) {
        const data = await response.json();
        console.log(`${equipmentMode} search results:`, data);
        setEquipmentResults(data);
      } else {
        console.error("Equipment search failed:", response.status);
        setEquipmentResults([]);
      }
    } catch (error) {
      console.error("Error searching equipment:", error);
      setEquipmentResults([]);
    } finally {
      setIsSearching(false);
    }
  };

  const setEquipmentModeAndClearResults = (mode: "generic" | "specific") => {
    setEquipmentMode(mode);
    setEquipmentResults([]); // Clear results when switching modes
    // Keep search term so user doesn't have to retype
  };

  const addEquipment = async (item: EquipmentType | Equipment) => {
    const isGeneric = equipmentMode === "generic";
    const equipment = item as any;

    // For specific equipment, allow multiple units of the same type
    // For generic equipment, check if already selected
    if (isGeneric) {
      const isAlreadySelected = selectedEquipment.some(
        (selected) =>
          selected.equipment_type_id === equipment.equipment_type_id &&
          selected.mode === "generic",
      );

      if (isAlreadySelected) {
        alert("Equipment type already selected");
        return;
      }
    }

    const newEquipment: SelectedEquipment = {
      id: isGeneric ? equipment.equipment_type_id : equipment.equipment_id,
      mode: equipmentMode,
      equipment_type_id: equipment.equipment_type_id,
      equipment_id: isGeneric ? undefined : equipment.equipment_id,
      name: isGeneric
        ? equipment.type_name
        : `${equipment.asset_code} - ${equipment.type_name}`,
      code: isGeneric ? equipment.type_code : equipment.asset_code,
      quantity: 1,
      daily_rate: equipment.daily_rate || 0,
      attached_accessories: [],
    };

    setSelectedEquipment((prev) => [...prev, newEquipment]);

    // Load accessories for this equipment
    if (isGeneric) {
      await calculateAutoAccessories([...selectedEquipment, newEquipment]);
    } else {
      // For specific equipment, attach accessories directly to this equipment
      const specificAccessories = await loadSpecificEquipmentAccessories(
        equipment.equipment_type_id,
      );
      newEquipment.attached_accessories = specificAccessories;
    }
  };

  const calculateAutoAccessories = async (equipment: SelectedEquipment[]) => {
    try {
      const equipmentTypes = equipment
        .filter((item) => item.mode === "generic")
        .map((item) => ({
          equipment_type_id: item.equipment_type_id,
          quantity: item.quantity,
        }));

      if (equipmentTypes.length === 0) return;

      const response = await fetch("/api/accessories/auto-calculate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({ equipment_types: equipmentTypes }),
      });

      if (response.ok) {
        const accessories = await response.json();
        setAutoAccessories(accessories);
      }
    } catch (error) {
      console.error("Error calculating accessories:", error);
    }
  };

  const removeEquipment = async (index: number) => {
    const newEquipment = selectedEquipment.filter((_, i) => i !== index);
    setSelectedEquipment(newEquipment);
    await calculateAutoAccessories(newEquipment);
  };

  const updateQuantity = async (index: number, newQuantity: number) => {
    if (newQuantity < 1) return;

    const newEquipment = [...selectedEquipment];
    newEquipment[index].quantity = newQuantity;
    setSelectedEquipment(newEquipment);
    await calculateAutoAccessories(newEquipment);
  };

  const removeAccessory = (accessoryId: number) => {
    setAutoAccessories((prev) =>
      prev.filter((acc) => acc.accessory_id !== accessoryId),
    );
  };

  const updateAccessoryQuantity = (
    accessoryId: number,
    newQuantity: number,
  ) => {
    setAutoAccessories((prev) =>
      prev.map((acc) =>
        acc.accessory_id === accessoryId
          ? { ...acc, total_quantity: Math.max(0, newQuantity) }
          : acc,
      ),
    );
  };

  const loadSpecificEquipmentAccessories = async (
    equipmentTypeId: number,
  ): Promise<AutoAccessory[]> => {
    try {
      // Get accessories for this specific equipment's type
      const response = await fetch(
        `/api/equipment-types/${equipmentTypeId}/accessories`,
        {
          credentials: "include",
        },
      );

      if (response.ok) {
        const typeAccessories = await response.json();

        return typeAccessories.map((acc: any) => ({
          accessory_id: acc.accessory_id,
          accessory_code: acc.accessory_code,
          accessory_name: acc.accessory_name,
          total_quantity: parseFloat(acc.default_quantity) || 1,
          unit_of_measure: acc.unit_of_measure || "each",
          unit_rate: acc.unit_rate || 0,
          accessory_type: acc.accessory_type || "default",
        }));
      }
    } catch (error) {
      console.error("Error loading specific equipment accessories:", error);
    }
    return [];
  };

  // Aggregate all accessories for display and hire creation
  const getAllAccessories = (): AutoAccessory[] => {
    const aggregatedAccessories: { [key: number]: AutoAccessory } = {};

    // Add global auto accessories (from generic equipment)
    autoAccessories.forEach((acc) => {
      aggregatedAccessories[acc.accessory_id] = { ...acc };
    });

    // Add accessories attached to specific equipment
    selectedEquipment.forEach((equipment) => {
      if (equipment.attached_accessories) {
        equipment.attached_accessories.forEach((acc) => {
          if (aggregatedAccessories[acc.accessory_id]) {
            aggregatedAccessories[acc.accessory_id].total_quantity +=
              acc.total_quantity;
          } else {
            aggregatedAccessories[acc.accessory_id] = { ...acc };
          }
        });
      }
    });

    return Object.values(aggregatedAccessories);
  };

  const submitHire = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!selectedCustomer || !selectedContact || !selectedSite) {
      alert("Please select customer, contact, and site");
      return;
    }

    if (selectedEquipment.length === 0) {
      alert("Please select at least one equipment item");
      return;
    }

    setIsLoading(true);
    try {
      const hireData = {
        customer_id: parseInt(selectedCustomer),
        contact_id: parseInt(selectedContact),
        site_id: parseInt(selectedSite),
        hire_start_date: hireStartDate,
        hire_end_date: hireEndDate || null,
        delivery_date: deliveryDate,
        delivery_time: deliveryTime,
        contact_method: contactMethod,
        special_instructions: specialInstructions,
        notes: notes,
        equipment_types: selectedEquipment
          .filter((item) => item.mode === "generic")
          .map((item) => ({
            equipment_type_id: item.equipment_type_id,
            quantity: item.quantity,
          })),
        specific_equipment: selectedEquipment
          .filter((item) => item.mode === "specific")
          .map((item) => ({
            equipment_id: item.equipment_id,
          })),
        accessories: getAllAccessories()
          .filter((acc) => acc.total_quantity > 0)
          .map((acc) => ({
            accessory_id: acc.accessory_id,
            quantity: acc.total_quantity,
          })),
      };

      const response = await fetch("/api/hire/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify(hireData),
      });

      if (response.ok) {
        const result = await response.json();
        alert(
          `Hire created successfully! Reference: ${result.reference_number}`,
        );
        router.push("/diary/hires");
      } else {
        const error = await response.json();
        alert(`Error creating hire: ${error.error || "Unknown error"}`);
      }
    } catch (error) {
      console.error("Error creating hire:", error);
      alert("Error creating hire");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <AuthCheck>
      <div className="min-h-screen bg-base">
        {/* Header */}
        <div className="bg-surface border-b border-highlight-low">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
            <div className="flex justify-between items-center">
              <h1 className="text-2xl font-bold text-gold">
                New Equipment Hire
              </h1>
              <button
                onClick={() => router.push("/diary/hires")}
                className="px-4 py-2 bg-overlay text-text rounded-lg hover:bg-highlight-low transition-colors"
              >
                ← Back to Hires
              </button>
            </div>
          </div>
        </div>

        <form
          onSubmit={submitHire}
          className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8"
        >
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* Customer Information */}
            <div className="bg-surface border border-highlight-low rounded-lg p-6 relative">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold text-text">
                  Customer Information
                </h2>
                <button
                  type="button"
                  onClick={clearCustomerInfo}
                  className="p-2 bg-blue text-white rounded-lg hover:bg-blue/80 transition-colors"
                  title="Clear Customer Information"
                >
                  ♻
                </button>
              </div>

              <div className="space-y-4">
                {/* Customer Search */}
                <div className="relative">
                  <label className="block text-sm font-medium text-text mb-2">
                    Customer *
                  </label>
                  <input
                    type="text"
                    value={customerSearch}
                    onChange={handleCustomerSearch}
                    onFocus={() => setShowCustomerDropdown(true)}
                    placeholder="Search customers..."
                    className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                    required
                  />
                  {showCustomerDropdown && customers.length > 0 && (
                    <div className="absolute z-10 w-full mt-1 bg-surface border border-highlight-med rounded-lg shadow-lg max-h-60 overflow-y-auto">
                      {customers.map((customer) => (
                        <div
                          key={customer.id}
                          onClick={() => selectCustomer(customer)}
                          className="p-3 hover:bg-highlight-low cursor-pointer border-b border-highlight-low last:border-b-0"
                        >
                          <div className="font-medium text-text">
                            {customer.name}
                          </div>
                          <div className="text-sm text-subtle">
                            {customer.customer_code}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Contact Search */}
                <div className="relative">
                  <label className="block text-sm font-medium text-text mb-2">
                    Contact Person *
                  </label>
                  <input
                    type="text"
                    value={contactSearch}
                    onChange={handleContactSearch}
                    onFocus={() => setShowContactDropdown(true)}
                    placeholder="Search contacts..."
                    className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                    disabled={!selectedCustomer}
                    required
                  />
                  {showContactDropdown &&
                    contacts.length > 0 &&
                    selectedCustomer && (
                      <div className="absolute z-10 w-full mt-1 bg-surface border border-highlight-med rounded-lg shadow-lg max-h-60 overflow-y-auto">
                        {contacts.map((contact) => (
                          <div
                            key={contact.contact_id}
                            onClick={() => selectContact(contact)}
                            className="p-3 hover:bg-highlight-low cursor-pointer border-b border-highlight-low last:border-b-0"
                          >
                            <div className="font-medium text-text">
                              {contact.full_name}
                            </div>
                            <div className="text-sm text-subtle">
                              {contact.job_title} • {contact.email}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                </div>

                {/* Site Search */}
                <div className="relative">
                  <label className="block text-sm font-medium text-text mb-2">
                    Delivery Site *
                  </label>
                  <input
                    type="text"
                    value={siteSearch}
                    onChange={handleSiteSearch}
                    onFocus={() => setShowSiteDropdown(true)}
                    placeholder="Search sites..."
                    className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                    disabled={!selectedCustomer}
                    required
                  />
                  {showSiteDropdown && sites.length > 0 && selectedCustomer && (
                    <div className="absolute z-10 w-full mt-1 bg-surface border border-highlight-med rounded-lg shadow-lg max-h-60 overflow-y-auto">
                      {sites.map((site) => (
                        <div
                          key={site.site_id}
                          onClick={() => selectSite(site)}
                          className="p-3 hover:bg-highlight-low cursor-pointer border-b border-highlight-low last:border-b-0"
                        >
                          <div className="font-medium text-text">
                            {site.site_name}
                          </div>
                          <div className="text-sm text-subtle">
                            {site.full_address}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-text mb-2">
                    Contact Method
                  </label>
                  <select
                    value={contactMethod}
                    onChange={(e) => setContactMethod(e.target.value)}
                    className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                  >
                    <option value="phone">Phone</option>
                    <option value="email">Email</option>
                    <option value="whatsapp">WhatsApp</option>
                    <option value="in_person">In Person</option>
                    <option value="online">Online</option>
                  </select>
                </div>
              </div>
            </div>

            {/* Hire Details */}
            <div className="bg-surface border border-highlight-low rounded-lg p-6 relative">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold text-text">
                  Hire Details
                </h2>
                <button
                  type="button"
                  onClick={clearHireDetails}
                  className="p-2 bg-blue text-white rounded-lg hover:bg-blue/80 transition-colors"
                  title="Clear Hire Details"
                >
                  ♻
                </button>
              </div>

              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-text mb-2">
                      Hire Start Date *
                    </label>
                    <input
                      type="date"
                      value={hireStartDate}
                      onChange={(e) => setHireStartDate(e.target.value)}
                      className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-text mb-2">
                      Hire End Date
                    </label>
                    <input
                      type="date"
                      value={hireEndDate}
                      onChange={(e) => setHireEndDate(e.target.value)}
                      className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-text mb-2">
                      Delivery Date *
                    </label>
                    <input
                      type="date"
                      value={deliveryDate}
                      onChange={(e) => setDeliveryDate(e.target.value)}
                      className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-text mb-2">
                      Delivery Time
                    </label>
                    <input
                      type="time"
                      value={deliveryTime}
                      onChange={(e) => setDeliveryTime(e.target.value)}
                      className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-text mb-2">
                    Special Instructions
                  </label>
                  <textarea
                    value={specialInstructions}
                    onChange={(e) => setSpecialInstructions(e.target.value)}
                    rows={3}
                    className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                    placeholder="Any special delivery or handling instructions..."
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-text mb-2">
                    Internal Notes
                  </label>
                  <textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    rows={3}
                    className="w-full p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                    placeholder="Internal notes about this hire..."
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Equipment Selection */}
          <div className="mt-8 grid grid-cols-1 lg:grid-cols-3 gap-8">
            {/* Equipment Search */}
            <div className="lg:col-span-2 bg-surface border border-highlight-low rounded-lg p-6">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold text-text">
                  Equipment Selection
                </h2>

                {/* Mode Toggle */}
                <div className="flex bg-overlay rounded-lg p-1">
                  <button
                    type="button"
                    onClick={() => setEquipmentModeAndClearResults("generic")}
                    className={`px-4 py-2 rounded-md text-sm transition-colors ${
                      equipmentMode === "generic"
                        ? "bg-gold text-base"
                        : "text-text hover:bg-highlight-low"
                    }`}
                  >
                    Generic
                  </button>
                  <button
                    type="button"
                    onClick={() => setEquipmentModeAndClearResults("specific")}
                    className={`px-4 py-2 rounded-md text-sm transition-colors ${
                      equipmentMode === "specific"
                        ? "bg-gold text-base"
                        : "text-text hover:bg-highlight-low"
                    }`}
                  >
                    Specific
                  </button>
                </div>
              </div>

              {/* Search Bar */}
              <div className="flex gap-3 mb-4">
                <input
                  type="text"
                  value={equipmentSearch}
                  onChange={(e) => setEquipmentSearch(e.target.value)}
                  onKeyPress={(e) => e.key === "Enter" && searchEquipment()}
                  placeholder={`Search ${equipmentMode} equipment...`}
                  className="flex-1 p-3 bg-overlay border border-highlight-med rounded-lg text-text"
                />
                <button
                  type="button"
                  onClick={searchEquipment}
                  disabled={isSearching}
                  className="px-6 py-3 bg-blue text-base rounded-lg hover:bg-blue/80 transition-colors disabled:opacity-50"
                >
                  {isSearching ? "Searching..." : "Search"}
                </button>
              </div>

              {/* Equipment Results */}
              <div className="max-h-80 overflow-y-auto space-y-3">
                {equipmentResults.length === 0 ? (
                  <div className="text-center py-8 text-subtle">
                    <div className="text-4xl mb-3">🔍</div>
                    <p>Search for equipment to add to hire</p>
                  </div>
                ) : (
                  equipmentResults.map((item: any, index: number) => (
                    <div
                      key={
                        equipmentMode === "generic"
                          ? `type-${item.equipment_type_id}`
                          : `unit-${item.equipment_id}`
                      }
                      onClick={() => addEquipment(item)}
                      className="p-4 bg-overlay border border-highlight-med rounded-lg cursor-pointer hover:border-gold transition-colors"
                    >
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <h3 className="font-semibold text-text">
                            {equipmentMode === "generic"
                              ? item.type_name
                              : `${item.asset_code} - ${item.type_name}`}
                          </h3>
                          <p className="text-sm text-subtle">
                            {equipmentMode === "generic"
                              ? item.type_code
                              : item.model}
                          </p>
                          {equipmentMode === "generic" && (
                            <p className="text-sm text-subtle mt-1">
                              Available: {item.available_units}/
                              {item.total_units}
                            </p>
                          )}
                          {item.daily_rate > 0 && (
                            <p className="text-sm text-green mt-1">
                              £{item.daily_rate}/day
                            </p>
                          )}
                        </div>
                        <button
                          type="button"
                          className="px-3 py-1 bg-green text-base rounded-md hover:bg-green/80 transition-colors"
                        >
                          Add
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* Selected Items */}
            <div className="bg-surface border border-highlight-low rounded-lg p-6 relative">
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-semibold text-text">
                  Selected Items
                </h2>
                <button
                  type="button"
                  onClick={clearSelectedEquipment}
                  className="p-2 bg-blue text-white rounded-lg hover:bg-blue/80 transition-colors"
                  title="Clear Selected Equipment"
                >
                  ♻
                </button>
              </div>

              <div className="max-h-80 overflow-y-auto space-y-3">
                {selectedEquipment.length === 0 &&
                getAllAccessories().length === 0 ? (
                  <div className="text-center py-8 text-subtle">
                    <div className="text-4xl mb-3">📦</div>
                    <p>No items selected</p>
                  </div>
                ) : (
                  <>
                    {/* Equipment Items */}
                    {selectedEquipment.map((item, index) => (
                      <div
                        key={index}
                        className="p-3 bg-overlay border border-highlight-med rounded-lg"
                      >
                        <div className="flex justify-between items-start mb-2">
                          <div className="flex-1">
                            <h4 className="font-medium text-text">
                              {item.name}
                            </h4>
                            <p className="text-sm text-subtle">{item.code}</p>
                          </div>
                          <button
                            type="button"
                            onClick={() => removeEquipment(index)}
                            className="text-red hover:text-red/80 transition-colors"
                          >
                            ✕
                          </button>
                        </div>

                        {item.mode === "generic" && (
                          <div className="flex items-center gap-2">
                            <button
                              type="button"
                              onClick={() =>
                                updateQuantity(index, item.quantity - 1)
                              }
                              disabled={item.quantity <= 1}
                              className="px-2 py-1 bg-overlay border border-highlight-med rounded text-sm disabled:opacity-50"
                            >
                              -
                            </button>
                            <span className="px-3 py-1 bg-base text-center min-w-[3rem]">
                              {item.quantity}
                            </span>
                            <button
                              type="button"
                              onClick={() =>
                                updateQuantity(index, item.quantity + 1)
                              }
                              className="px-2 py-1 bg-overlay border border-highlight-med rounded text-sm"
                            >
                              +
                            </button>
                          </div>
                        )}
                      </div>
                    ))}

                    {/* Accessories */}
                    {getAllAccessories()
                      .filter((acc) => acc.total_quantity > 0)
                      .map((accessory) => (
                        <div
                          key={`acc-${accessory.accessory_id}`}
                          className="p-3 bg-overlay/50 border border-highlight-low rounded-lg"
                        >
                          <div className="flex justify-between items-start mb-2">
                            <div className="flex-1">
                              <h4 className="font-medium text-text text-sm">
                                {accessory.accessory_name}
                              </h4>
                              <p className="text-xs text-subtle">
                                {accessory.accessory_code}
                              </p>
                            </div>
                            <button
                              type="button"
                              onClick={() =>
                                removeAccessory(accessory.accessory_id)
                              }
                              className="text-red hover:text-red/80 transition-colors text-sm"
                            >
                              ✕
                            </button>
                          </div>
                          <div className="flex items-center gap-2">
                            <button
                              type="button"
                              onClick={() =>
                                updateAccessoryQuantity(
                                  accessory.accessory_id,
                                  Math.max(0, accessory.total_quantity - 1),
                                )
                              }
                              disabled={accessory.total_quantity <= 0}
                              className="px-2 py-1 bg-overlay border border-highlight-med rounded text-xs disabled:opacity-50"
                            >
                              -
                            </button>
                            <span className="px-2 py-1 bg-base text-center min-w-[2.5rem] text-xs">
                              {accessory.total_quantity}{" "}
                              {accessory.unit_of_measure}
                            </span>
                            <button
                              type="button"
                              onClick={() =>
                                updateAccessoryQuantity(
                                  accessory.accessory_id,
                                  accessory.total_quantity + 1,
                                )
                              }
                              className="px-2 py-1 bg-overlay border border-highlight-med rounded text-xs"
                            >
                              +
                            </button>
                          </div>
                        </div>
                      ))}
                  </>
                )}
              </div>
            </div>
          </div>

          {/* Form Actions */}
          <div className="mt-8 bg-surface border border-highlight-low rounded-lg p-6 relative">
            {/* Clear All Button - Top Right */}

            <div className="flex justify-between items-center">
              <div className="text-sm text-subtle">
                Equipment: {selectedEquipment.length} items • Accessories:{" "}
                {
                  getAllAccessories().filter((acc) => acc.total_quantity > 0)
                    .length
                }{" "}
                items
              </div>
              <div className="flex gap-4">
                <button
                  type="button"
                  onClick={clearEntirePage}
                  className="px-6 py-3 bg-blue text-white rounded-lg hover:bg-red/80 transition-colors"
                  title="Clear Entire Page"
                >
                  ♻
                </button>

                <button
                  type="button"
                  onClick={() => router.push("/diary/hires")}
                  className="px-6 py-3 bg-red text-white rounded-lg hover:bg-red/80 transition-colors"
                >
                  Cancel
                </button>

                <button
                  type="submit"
                  disabled={isLoading}
                  className="px-6 py-3 bg-gold text-base rounded-lg hover:bg-gold/80 transition-colors disabled:opacity-50"
                >
                  {isLoading ? "Creating..." : "Create Hire"}
                </button>
              </div>
            </div>
          </div>
        </form>
      </div>
    </AuthCheck>
  );
}
