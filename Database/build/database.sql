-- TASK MANAGEMENT SYSTEM - 3 LAYER ARCHITECTURE (UPDATED)
-- Layer 1: Interaction Recording (Data Input)
-- Layer 2: Component Storage (based on interaction type)
-- Layer 3: Taskboard Operations (Workspaces - where all users collaborate)

-- =============================================================================
-- FOUNDATION TABLES
-- =============================================================================

-- Customer Structure - Clean Methodology
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    customer_name VARCHAR(200),
    is_company BOOLEAN DEFAULT FALSE,
    
    -- Company-specific fields (null for individuals)
    registration_number VARCHAR(50),
    vat_number VARCHAR(20),
    
    -- General business info (applies to both)
    credit_limit DECIMAL(10,2) DEFAULT 0.00,
    payment_terms VARCHAR(100),
    
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'blacklisted')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE contacts (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    job_title VARCHAR(100),
    department VARCHAR(100),
    
    phone_number VARCHAR(20),
    whatsapp_number VARCHAR(20),
    email VARCHAR(150),
    
    is_primary_contact BOOLEAN DEFAULT FALSE,
    is_billing_contact BOOLEAN DEFAULT FALSE,
    
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sites (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    
    site_name VARCHAR(200), -- "Sandton Site", "Head Office", "John's House"
    site_code VARCHAR(20), -- Optional: "SAND01", "HO001"
    
    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),
    city VARCHAR(100),
    postal_code VARCHAR(10),
    gps_coordinates VARCHAR(50),
    
    site_type VARCHAR(50) CHECK (site_type IN ('office', 'construction', 'warehouse', 'residential', 'other')),
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Enhanced site information for better delivery/collection support
    site_contact_name VARCHAR(100), -- On-site contact person
    site_contact_phone VARCHAR(20), -- On-site contact number
    access_instructions TEXT, -- "Gate code 1234", "Contact John on arrival"
    delivery_instructions TEXT, -- Specific delivery/access instructions
    special_notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    email VARCHAR(150) UNIQUE,
    password_hash VARCHAR(255),
    role VARCHAR(50) CHECK (role IN ('owner', 'manager', 'accounts', 'buyer', 'hire_control', 'driver', 'employee')),
    name VARCHAR(100),
    surname VARCHAR(100),
    phone VARCHAR(20),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE equipment_categories (
    id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) UNIQUE, -- "Angle Grinder Large"
    category_code VARCHAR(20) UNIQUE, -- "AG104"
    description TEXT, -- "ANGLE GRINDER 230MM 2200W"
    default_accessories TEXT, -- "Comes with 5L petrol, 2 chisels"
    specifications TEXT, -- Technical specifications
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NEW: Equipment Pricing Table
CREATE TABLE equipment_pricing (
    id SERIAL PRIMARY KEY,
    equipment_category_id INTEGER REFERENCES equipment_categories(id),
    customer_type VARCHAR(50) DEFAULT 'standard' CHECK (customer_type IN ('individual', 'company', 'standard')),
    price_per_day DECIMAL(10,2),
    price_per_week DECIMAL(10,2),
    price_per_month DECIMAL(10,2),
    minimum_hire_period INTEGER DEFAULT 1, -- Minimum days
    deposit_amount DECIMAL(10,2),
    effective_from DATE,
    effective_to DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NEW: Price List Templates
CREATE TABLE price_list_templates (
    id SERIAL PRIMARY KEY,
    template_name VARCHAR(100),
    equipment_category_filter TEXT, -- JSON array of category IDs or "all"
    customer_type VARCHAR(50) DEFAULT 'both' CHECK (customer_type IN ('individual', 'company', 'both')),
    include_pricing BOOLEAN DEFAULT TRUE,
    include_specifications BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- LAYER 1: INTERACTION RECORDING (Universal Entry Point - Data Input Layer)
-- =============================================================================

CREATE TABLE interactions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    contact_id INTEGER REFERENCES contacts(id),
    
    employee_id INTEGER REFERENCES employees(id),
    interaction_type VARCHAR(50) CHECK (interaction_type IN ('price_list', 'quote', 'application', 'order', 'hire', 'off_hire', 'breakdown', 'statement', 'refund', 'coring', 'misc_task')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'completed')),
    reference_number VARCHAR(50) UNIQUE,
    contact_method VARCHAR(50) CHECK (contact_method IN ('phone', 'whatsapp', 'email', 'walk_in')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- LAYER 2: COMPONENT STORAGE (Based on Components.txt)
-- =============================================================================

-- Application Details Component (application interaction type)
-- Application Details Component (application interaction type)
CREATE TABLE component_application_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    application_type VARCHAR(50) CHECK (application_type IN ('individual', 'company')),
    
    -- NEW: Applicant contact details for emailing application forms
    applicant_first_name VARCHAR(100),
    applicant_last_name VARCHAR(100),
    applicant_email VARCHAR(150),
    
    -- Existing verification fields
    verification_status VARCHAR(50) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected')),
    verification_notes TEXT,
    documents_required TEXT,
    verification_date DATE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add email format validation constraint
ALTER TABLE component_application_details
ADD CONSTRAINT check_applicant_email_format
CHECK (applicant_email IS NULL OR applicant_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Add index for email lookups
CREATE INDEX idx_component_application_details_email ON component_application_details(applicant_email);

-- Equipment List Component (price_list, quote, order, hire, off_hire, breakdown, coring)
CREATE TABLE component_equipment_list (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    equipment_category_id INTEGER REFERENCES equipment_categories(id),
    quantity INTEGER DEFAULT 1,
    -- NEW: Hire duration tracking for quotes/orders/hires
    hire_duration INTEGER, -- Duration in specified period units
    hire_period_type VARCHAR(50) DEFAULT 'days' CHECK (hire_period_type IN ('days', 'weeks', 'months')),
    special_requirements TEXT,
    accessories_needed TEXT
);

-- NEW: Quote Totals Component (quote interaction type)
CREATE TABLE component_quote_totals (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    subtotal DECIMAL(10,2) DEFAULT 0.00,
    tax_rate DECIMAL(5,2) DEFAULT 15.00, -- Tax percentage
    tax_amount DECIMAL(10,2) DEFAULT 0.00,
    total_amount DECIMAL(10,2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'ZAR',
    valid_until DATE, -- Quote expiry date
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NEW: Refund Details Component (refund interaction type)
CREATE TABLE component_refund_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    refund_type VARCHAR(50) DEFAULT 'partial' CHECK (refund_type IN ('full', 'partial', 'deposit_only')),
    refund_amount DECIMAL(10,2),
    refund_reason TEXT,
    account_balance_before DECIMAL(10,2),
    account_balance_after DECIMAL(10,2),
    refund_method VARCHAR(50) DEFAULT 'eft' CHECK (refund_method IN ('cash', 'eft', 'credit_note')),
    bank_details TEXT, -- Customer bank details for EFT
    processed_by INTEGER REFERENCES employees(id),
    processed_at TIMESTAMP
);

-- Hire Details Component (order, hire interaction types)
CREATE TABLE component_hire_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    site_id INTEGER REFERENCES sites(id), -- Which site for delivery/pickup
    deliver_date DATE,
    deliver_time TIME,
    start_date DATE,
    start_time TIME,
    delivery_method VARCHAR(50) DEFAULT 'deliver' CHECK (delivery_method IN ('deliver', 'counter')),
    special_instructions TEXT
);

-- Off-Hire Details Component (off_hire interaction type)
CREATE TABLE component_offhire_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    site_id INTEGER REFERENCES sites(id), -- Which site for collection
    collect_date DATE,
    collect_time TIME,
    end_date DATE,
    end_time TIME,
    collection_method VARCHAR(50) DEFAULT 'collect' CHECK (collection_method IN ('collect', 'counter')),
    early_return BOOLEAN DEFAULT FALSE,
    return_reason TEXT
);

-- Breakdown Details Component (breakdown interaction type)
CREATE TABLE component_breakdown_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    site_id INTEGER REFERENCES sites(id), -- Which site has the breakdown
    breakdown_date DATE,
    breakdown_time TIME,
    resolution_type VARCHAR(50) CHECK (resolution_type IN ('swap', 'repair')),
    urgency VARCHAR(50) DEFAULT 'medium' CHECK (urgency IN ('low', 'medium', 'high', 'critical')),
    issue_description TEXT,
    equipment_condition TEXT
);

-- NEW: Coring Details Component (coring interaction type)
CREATE TABLE component_coring_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    site_id INTEGER REFERENCES sites(id), -- Which site needs coring
    coring_date DATE,
    coring_time TIME,
    core_diameter VARCHAR(20), -- "100mm", "150mm", etc.
    core_depth VARCHAR(20), -- "300mm", "500mm", etc.
    number_of_cores INTEGER DEFAULT 1,
    surface_type VARCHAR(100), -- "concrete", "asphalt", "brick", etc.
    access_method VARCHAR(100), -- "handheld", "truck-mounted", etc.
    special_requirements TEXT,
    urgency VARCHAR(50) DEFAULT 'medium' CHECK (urgency IN ('low', 'medium', 'high', 'critical'))
);

-- NEW: Misc Task Details Component (misc_task interaction type)
CREATE TABLE component_misc_task_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    site_id INTEGER REFERENCES sites(id), -- Optional: Which site (if applicable)
    task_date DATE,
    task_time TIME,
    task_description TEXT,
    task_category VARCHAR(100), -- "spare_parts_purchase", "equipment_inspection", "delivery_only", etc.
    estimated_duration INTEGER, -- minutes
    special_requirements TEXT,
    urgency VARCHAR(50) DEFAULT 'medium' CHECK (urgency IN ('low', 'medium', 'high', 'critical'))
);

-- NEW: Rental Agreement Component (order, hire interaction types)
CREATE TABLE component_rental_agreements (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    agreement_number VARCHAR(50) UNIQUE,
    rental_start_date DATE,
    rental_end_date DATE,
    total_rental_days INTEGER,
    daily_rate DECIMAL(10,2),
    weekly_rate DECIMAL(10,2),
    deposit_paid DECIMAL(10,2),
    insurance_required BOOLEAN DEFAULT FALSE,
    terms_accepted BOOLEAN DEFAULT FALSE,
    terms_accepted_at TIMESTAMP
);

-- =============================================================================
-- LAYER 3: TASKBOARD OPERATIONS (Collaborative Workspaces)
-- =============================================================================

-- USER TASKBOARD (Current User + Accounts) - Individual Task Management
CREATE TABLE user_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    assigned_to INTEGER REFERENCES employees(id), -- who owns this task
    task_type VARCHAR(50) CHECK (task_type IN ('send_price_list', 'send_quote', 'process_application', 'send_statement', 'process_refund', 'general')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    
    title VARCHAR(200),
    description TEXT,
    due_date DATE,
    
    -- NEW: Task dependency tracking
    parent_task_id INTEGER REFERENCES user_taskboard(id),
    
    -- Completion tracking
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    completion_notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DRIVERS TASKBOARD (Shared Collaborative Workspace - All Users Can See & Work)
-- This is where all driver-related tasks are managed collaboratively
CREATE TABLE drivers_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id), -- Links back to original data input
    assigned_to INTEGER REFERENCES employees(id), -- which driver (nullable - starts unassigned in backlog)
    created_by INTEGER REFERENCES employees(id), -- who created the task
    
    -- Task Classification
    task_type VARCHAR(50) CHECK (task_type IN ('delivery', 'collection', 'swap', 'repair', 'coring', 'misc_task')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(50) DEFAULT 'backlog' CHECK (status IN ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4', 'completed', 'cancelled')),
    
    -- Scheduling Information
    scheduled_date DATE,
    scheduled_time TIME,
    estimated_duration INTEGER, -- minutes
    
    -- Customer & Site Information (denormalized for easy access in workspace)
    customer_name VARCHAR(200), -- From customers table
    contact_name VARCHAR(200), -- From contacts table (first_name + last_name)
    contact_phone VARCHAR(20), -- From contacts table
    contact_whatsapp VARCHAR(20), -- From contacts table
    site_address TEXT, -- Full formatted address from sites table
    site_delivery_instructions TEXT, -- From sites table
    
    -- Task Status Tracking (Your Required Fields)
    status_booked VARCHAR(3) DEFAULT 'no' CHECK (status_booked IN ('yes', 'no')), -- Has this been properly scheduled/booked
    status_driver VARCHAR(3) DEFAULT 'no' CHECK (status_driver IN ('yes', 'no')), -- Has driver been assigned and confirmed
    status_quality_control VARCHAR(3) DEFAULT 'no' CHECK (status_quality_control IN ('yes', 'no')), -- Has QC been done (equipment verified, etc.)
    status_whatsapp VARCHAR(3) DEFAULT 'no' CHECK (status_whatsapp IN ('yes', 'no')), -- Has customer been notified via WhatsApp
    
    -- Equipment Notes (categorical, not unique items)
    equipment_summary TEXT, -- "Rammer, Breaker, Poker" - summary for quick reference
    equipment_verified BOOLEAN DEFAULT FALSE, -- All equipment items verified for QC
     
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Equipment assignments for driver tasks (detailed breakdown from equipment list)
CREATE TABLE drivers_task_equipment (
    id SERIAL PRIMARY KEY,
    drivers_task_id INTEGER REFERENCES drivers_taskboard(id),
    equipment_category_id INTEGER REFERENCES equipment_categories(id),
    quantity INTEGER DEFAULT 1,
    purpose VARCHAR(50) CHECK (purpose IN ('deliver', 'collect', 'swap_out', 'swap_in', 'repair', 'coring')),
    condition_notes TEXT,
    verified BOOLEAN DEFAULT FALSE, -- For quality control
    verified_by INTEGER REFERENCES employees(id),
    verified_at TIMESTAMP
);

-- NEW: Driver Task Status History (Track status changes for audit/workflow)
CREATE TABLE drivers_task_status_history (
    id SERIAL PRIMARY KEY,
    drivers_task_id INTEGER REFERENCES drivers_taskboard(id),
    from_status VARCHAR(50),
    to_status VARCHAR(50),
    changed_by INTEGER REFERENCES employees(id),
    change_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NEW: Driver Assignment History (Track who worked on what)
CREATE TABLE drivers_assignment_history (
    id SERIAL PRIMARY KEY,
    drivers_task_id INTEGER REFERENCES drivers_taskboard(id),
    assigned_to INTEGER REFERENCES employees(id),
    assigned_by INTEGER REFERENCES employees(id),
    assignment_notes TEXT,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    unassigned_at TIMESTAMP
);

-- =============================================================================
-- SUPPORTING TABLES
-- =============================================================================

-- File attachments
CREATE TABLE attachments (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    drivers_task_id INTEGER REFERENCES drivers_taskboard(id), -- NEW: Also link to driver tasks
    file_name VARCHAR(255),
    file_path VARCHAR(500),
    file_size INTEGER,
    file_type VARCHAR(100),
    uploaded_by INTEGER REFERENCES employees(id),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit trail
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    record_id INTEGER,
    action VARCHAR(10) CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by INTEGER REFERENCES employees(id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System settings
CREATE TABLE system_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE,
    setting_value TEXT,
    setting_type VARCHAR(50) CHECK (setting_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    updated_by INTEGER REFERENCES employees(id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);