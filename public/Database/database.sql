-- TASK MANAGEMENT SYSTEM - 3 LAYER ARCHITECTURE
-- Layer 1: Interaction Recording
-- Layer 2: Component Storage (based on interaction type)
-- Layer 3: Taskboard Operations

-- =============================================================================
-- FOUNDATION TABLES
-- =============================================================================

-- Customer Structure - Clean Methodology
Table customers {
  id integer [primary key, increment]
  customer_name varchar(200) -- "ABC Works" for companies, "Bob Smith" for individuals
  is_company boolean [default: false]
  
  -- Company-specific fields (null for individuals)
  registration_number varchar(50)
  vat_number varchar(20)
  
  -- General business info (applies to both)
  credit_limit decimal(10,2) [default: 0.00] -- for reference only
  payment_terms varchar(100)
  
  status enum('active', 'inactive', 'blacklisted') [default: 'active']
  notes text
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table contacts {
  id integer [primary key, increment]
  customer_id integer [ref: > customers.id]
  
  first_name varchar(100)
  last_name varchar(100)
  job_title varchar(100)
  department varchar(100)
  
  phone_number varchar(20)
  whatsapp_number varchar(20)
  email varchar(150)
  
  is_primary_contact boolean [default: false]
  is_billing_contact boolean [default: false]
  
  status enum('active', 'inactive') [default: 'active']
  notes text
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table sites {
  id integer [primary key, increment]
  customer_id integer [ref: > customers.id] -- Always belongs to the customer
  
  site_name varchar(200) -- "Sandton Site", "Head Office", "John's House"
  site_code varchar(20) -- Optional: "SAND01", "HO001"
  
  address_line1 varchar(200)
  address_line2 varchar(200)
  city varchar(100)
  postal_code varchar(10)
  gps_coordinates varchar(50)
  
  site_type enum('office', 'construction', 'warehouse', 'residential', 'other')
  is_active boolean [default: true]
  
  access_instructions text -- "Gate code 1234", "Contact John on arrival"
  special_notes text
  
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table employees {
  id integer [primary key, increment]
  username varchar(50) [unique]
  email varchar(150) [unique]
  password_hash varchar(255)
  role enum('owner', 'manager', 'accounts', 'buyer', 'hire_control', 'driver', 'employee')
  name varchar(100)
  surname varchar(100)
  phone varchar(20)
  status enum('active', 'inactive') [default: 'active']
  last_login timestamp
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table equipment_categories {
  id integer [primary key, increment]
  category_name varchar(100) [unique] -- "Angle Grinder Large"
  category_code varchar(20) [unique] -- "AG104" 
  description text -- "ANGLE GRINDER 230MM 2200W"
  default_accessories text -- "Comes with 5L petrol, 2 chisels"
  is_active boolean [default: true]
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

-- =============================================================================
-- LAYER 1: INTERACTION RECORDING (Universal Entry Point)
-- =============================================================================

Table interactions {
  id integer [primary key, increment]
  customer_id integer [ref: > customers.id]
  contact_id integer [ref: > contacts.id]
  site_id integer [ref: > sites.id] -- nullable - which site is this about?
  
  employee_id integer [ref: > employees.id]
  interaction_type enum('price_list', 'quote', 'application', 'order', 'off_hire', 'breakdown', 'statement')
  status enum('pending', 'processed', 'completed') [default: 'pending']
  reference_number varchar(50) [unique]
  contact_method enum('phone', 'whatsapp', 'email', 'walk_in')
  notes text
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

-- =============================================================================
-- LAYER 2: COMPONENT STORAGE (Based on Components.txt)
-- =============================================================================

-- Application Details Component (application interaction type)
Table component_application_details {
  id integer [primary key, increment]
  interaction_id integer [ref: > interactions.id]
  application_type enum('individual', 'company')
  verification_status enum('pending', 'approved', 'rejected') [default: 'pending']
  verification_notes text
  documents_required text
  verification_date date
}

-- Equipment List Component (price_list, quote, order, off_hire, breakdown)
Table component_equipment_list {
  id integer [primary key, increment]
  interaction_id integer [ref: > interactions.id]
  equipment_category_id integer [ref: > equipment_categories.id]
  quantity integer [default: 1]
  special_requirements text
  accessories_needed text
}

-- Hire Date Details Component (order interaction type)
Table component_hire_date_details {
  id integer [primary key, increment]
  interaction_id integer [ref: > interactions.id]
  deliver_date date
  deliver_time time
  start_date date
  start_time time
  delivery_method enum('deliver', 'counter') [default: 'deliver']
  delivery_address text
  delivery_contact_name varchar(100)
  delivery_contact_number varchar(20)
  special_instructions text
}

-- Off-Hire Date Details Component (off_hire interaction type)
Table component_off_hire_date_details {
  id integer [primary key, increment]
  interaction_id integer [ref: > interactions.id]
  collect_date date
  collect_time time
  end_date date
  end_time time
  collection_method enum('collect', 'counter') [default: 'collect']
  collection_address text
  early_return boolean [default: false]
  return_reason text
}

-- Breakdown Date Details Component (breakdown interaction type)
Table component_breakdown_date_details {
  id integer [primary key, increment]
  interaction_id integer [ref: > interactions.id]
  breakdown_date date
  breakdown_time time
  resolution_type enum('swap', 'repair')
  urgency enum('low', 'medium', 'high', 'critical') [default: 'medium']
  issue_description text
  customer_location text
  equipment_condition text
}

-- =============================================================================
-- LAYER 3: TASKBOARD OPERATIONS (Where Work Gets Done)
-- =============================================================================

-- USER TASKBOARD (Current User + Accounts)
Table user_taskboard {
  id integer [primary key, increment]
  interaction_id integer [ref: > interactions.id]
  assigned_to integer [ref: > employees.id] -- who owns this task
  task_type enum('send_price_list', 'send_quote', 'process_application', 'send_statement', 'general')
  priority enum('low', 'medium', 'high', 'urgent') [default: 'medium']
  status enum('pending', 'in_progress', 'completed', 'cancelled') [default: 'pending']
  
  title varchar(200)
  description text
  due_date date
  
  -- Completion tracking
  started_at timestamp
  completed_at timestamp
  completion_notes text
  
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

-- DRIVERS TASKBOARD (Shared by multiple drivers)
Table drivers_taskboard {
  id integer [primary key, increment]
  interaction_id integer [ref: > interactions.id]
  assigned_to integer [ref: > employees.id] -- which driver
  created_by integer [ref: > employees.id] -- who created the task
  
  task_type enum('delivery', 'collection', 'swap', 'repair', 'coring', 'inspection', 'general_task')
  priority enum('low', 'medium', 'high', 'urgent') [default: 'medium']
  status enum('pending', 'assigned', 'in_progress', 'completed', 'cancelled') [default: 'pending']
  
  scheduled_date date
  scheduled_time time
  estimated_duration integer -- minutes
  
  title varchar(200)
  description text
  
  -- Location details
  address text
  contact_person varchar(100)
  contact_number varchar(20)
  gps_coordinates varchar(50)
  
  -- Equipment involved
  equipment_notes text
  
  -- Completion tracking
  started_at timestamp
  completed_at timestamp
  actual_duration integer -- minutes
  completion_notes text
  completion_photos text -- file paths
  
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

-- Equipment assignments for driver tasks
Table drivers_task_equipment {
  id integer [primary key, increment]
  drivers_task_id integer [ref: > drivers_taskboard.id]
  equipment_category_id integer [ref: > equipment_categories.id]
  quantity integer [default: 1]
  purpose enum('deliver', 'collect', 'swap_out', 'swap_in', 'repair')
  condition_notes text
}

-- =============================================================================
-- SUPPORTING TABLES
-- =============================================================================

-- File attachments
Table attachments {
  id integer [primary key, increment]
  related_table enum('interactions', 'user_taskboard', 'drivers_taskboard', 'customers')
  related_id integer
  file_name varchar(255)
  file_path varchar(500)
  file_size integer
  file_type varchar(100)
  uploaded_by integer [ref: > employees.id]
  description text
  created_at timestamp [default: `now()`]
}

-- Audit trail
Table audit_log {
  id integer [primary key, increment]
  table_name varchar(50)
  record_id integer
  action enum('INSERT', 'UPDATE', 'DELETE')
  old_values json
  new_values json
  changed_by integer [ref: > employees.id]
  ip_address varchar(45)
  user_agent text
  created_at timestamp [default: `now()`]
}

-- System settings
Table system_settings {
  id integer [primary key, increment]
  setting_key varchar(100) [unique]
  setting_value text
  setting_type enum('string', 'number', 'boolean', 'json')
  description text
  updated_by integer [ref: > employees.id]
  updated_at timestamp [default: `now()`]
}