-- =============================================================================
-- EQUIPMENT HIRE DATABASE SCHEMA - INTERACTIONS HUB DESIGN WITH 2-PHASE BOOKING
-- =============================================================================
-- Architecture: Clean interactions table as central hub for easy procedures
-- Two taskboards: drivers_taskboard (user agnostic) and user_taskboard (user specific)
-- 2-Phase Booking: Generic equipment types → Specific equipment allocation
-- =============================================================================

-- =============================================================================
-- DROP AND CREATE SCHEMAS FOR CLEAN DEVELOPMENT
-- =============================================================================

-- Drop schemas (CASCADE removes all contained objects)
DROP SCHEMA IF EXISTS tasks CASCADE;
DROP SCHEMA IF EXISTS interactions CASCADE;
DROP SCHEMA IF EXISTS system CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;

-- Create schemas
CREATE SCHEMA core;
CREATE SCHEMA interactions;
CREATE SCHEMA tasks;
CREATE SCHEMA system;

-- Set search path
SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- EMPLOYEES TABLE (unchanged - must be first for user management)
-- =============================================================================
CREATE TABLE core.employees (
    id SERIAL PRIMARY KEY,
    employee_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    surname VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('owner', 'manager', 'buyer', 'accounts', 'hire_control', 'driver', 'mechanic')),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20),
    whatsapp_number VARCHAR(20),
    emergency_contact_name VARCHAR(200),
    emergency_contact_phone VARCHAR(20),
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'terminated')),
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.employees IS 'Employee master data - also serves as system users';
COMMENT ON COLUMN core.employees.role IS 'System role: owner, manager, buyer, accounts, hire_control, driver, mechanic';
COMMENT ON COLUMN core.employees.employee_code IS 'Unique employee identifier for login';

-- =============================================================================
-- CUSTOMERS TABLE (unchanged)
-- =============================================================================
CREATE TABLE core.customers (
    id SERIAL PRIMARY KEY,
    customer_code VARCHAR(20) UNIQUE NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    is_company BOOLEAN NOT NULL DEFAULT true,
    registration_number VARCHAR(50),
    vat_number VARCHAR(20),
    credit_limit DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    payment_terms VARCHAR(50) NOT NULL DEFAULT '30 days',
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended', 'credit_hold')),
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE core.customers IS 'Customer master data - companies and individuals';

-- =============================================================================
-- CONTACTS TABLE (unchanged)
-- =============================================================================
CREATE TABLE core.contacts (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    job_title VARCHAR(100),
    department VARCHAR(100),
    email VARCHAR(255),
    phone_number VARCHAR(20),
    whatsapp_number VARCHAR(20),
    is_primary_contact BOOLEAN NOT NULL DEFAULT false,
    is_billing_contact BOOLEAN NOT NULL DEFAULT false,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES core.customers(id) ON DELETE CASCADE
);

COMMENT ON TABLE core.contacts IS 'Customer contact persons';

-- =============================================================================
-- SITES TABLE (unchanged)
-- =============================================================================
CREATE TABLE core.sites (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    site_code VARCHAR(20),
    site_name VARCHAR(255) NOT NULL,
    site_type VARCHAR(50) NOT NULL DEFAULT 'delivery_site' 
        CHECK (site_type IN ('delivery_site', 'billing_address', 'head_office', 'branch', 'warehouse', 'project_site')),
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    province VARCHAR(100),
    postal_code VARCHAR(10),
    country VARCHAR(100) NOT NULL DEFAULT 'South Africa',
    site_contact_name VARCHAR(200),
    site_contact_phone VARCHAR(20),
    delivery_instructions TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES core.customers(id) ON DELETE CASCADE
);

COMMENT ON TABLE core.sites IS 'Customer sites for delivery and billing';

-- =============================================================================
-- EQUIPMENT TYPES TABLE (generic equipment categories)
-- =============================================================================
CREATE TABLE core.equipment_types (
    id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    type_name VARCHAR(255) NOT NULL,
    description TEXT,
    specifications TEXT,
    default_accessories TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.equipment_types IS 'Generic equipment categories/types for rental (used in Phase 1 booking)';

-- =============================================================================
-- INDIVIDUAL EQUIPMENT TABLE (specific equipment units)
-- =============================================================================
CREATE TABLE core.equipment (
    id SERIAL PRIMARY KEY,
    equipment_type_id INTEGER NOT NULL,
    asset_code VARCHAR(20) UNIQUE NOT NULL,  -- R1001, P1002, etc.
    serial_number VARCHAR(50) UNIQUE,
    model VARCHAR(100),
    year_manufactured INTEGER,
    date_acquired DATE,
    condition VARCHAR(20) NOT NULL DEFAULT 'good' 
        CHECK (condition IN ('excellent', 'good', 'fair', 'poor', 'out_of_service')),
    location VARCHAR(100) DEFAULT 'depot',
    status VARCHAR(20) NOT NULL DEFAULT 'available' 
        CHECK (status IN ('available', 'rented', 'maintenance', 'repair', 'sold')),
    last_service_date DATE,
    next_service_due DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equipment_type_id) REFERENCES core.equipment_types(id)
);

COMMENT ON TABLE core.equipment IS 'Individual equipment units with unique asset codes (used in Phase 2 allocation)';
COMMENT ON COLUMN core.equipment.asset_code IS 'Unique asset identifier (R1001, P1002, etc.)';

-- =============================================================================
-- ACCESSORIES TABLE
-- =============================================================================
CREATE TABLE core.accessories (
    id SERIAL PRIMARY KEY,
    equipment_type_id INTEGER,
    accessory_name VARCHAR(255) NOT NULL,
    accessory_type VARCHAR(20) DEFAULT 'default' CHECK (accessory_type IN ('default', 'optional')),
    billing_method VARCHAR(20) DEFAULT 'daily' CHECK (billing_method IN ('daily', 'consumption', 'fixed')),
    quantity INTEGER DEFAULT 1,
    description TEXT,
    is_consumable BOOLEAN DEFAULT false,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equipment_type_id) REFERENCES core.equipment_types(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE core.accessories IS 'Accessories available for equipment types';
COMMENT ON COLUMN core.accessories.accessory_type IS 'default = included with equipment, optional = customer choice';
COMMENT ON COLUMN core.accessories.billing_method IS 'daily = track hire period, consumption = track quantity used, fixed = one-time charge';
COMMENT ON COLUMN core.accessories.is_consumable IS 'true for items like fuel, oil, cutting discs that get used up';

-- =============================================================================
-- INTERACTIONS TABLE (unchanged - Layer 1)
-- =============================================================================
CREATE TABLE interactions.interactions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    contact_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    interaction_type VARCHAR(50) NOT NULL CHECK (interaction_type IN 
        ('price_list', 'quote', 'statement', 'refund', 'hire', 'off_hire', 'breakdown', 'application', 'coring', 'misc_task')),
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN 
        ('pending', 'in_progress', 'completed', 'cancelled', 'on_hold')),
    reference_number VARCHAR(20) UNIQUE NOT NULL,
    contact_method VARCHAR(50) NOT NULL CHECK (contact_method IN 
        ('phone', 'email', 'in_person', 'whatsapp', 'online', 'other')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (customer_id) REFERENCES core.customers(id),
    FOREIGN KEY (contact_id) REFERENCES core.contacts(id),
    FOREIGN KEY (employee_id) REFERENCES core.employees(id)
);

-- =============================================================================
-- PHASE 1: GENERIC EQUIPMENT BOOKING (NEW TABLE)
-- =============================================================================
CREATE TABLE interactions.interaction_equipment_types (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    equipment_type_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    hire_start_date DATE,
    hire_end_date DATE,
    booking_status VARCHAR(20) NOT NULL DEFAULT 'booked' 
        CHECK (booking_status IN ('booked', 'allocated', 'cancelled')),
    booking_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_type_id) REFERENCES core.equipment_types(id)
);

COMMENT ON TABLE interactions.interaction_equipment_types IS 'Phase 1: Generic equipment booking - reserves equipment types with quantities';
COMMENT ON COLUMN interactions.interaction_equipment_types.quantity IS 'Number of units requested (e.g., 2 rammers)';
COMMENT ON COLUMN interactions.interaction_equipment_types.booking_status IS 'booked = reserved, allocated = specific units assigned, cancelled = booking cancelled';

-- =============================================================================
-- PHASE 2: SPECIFIC EQUIPMENT ALLOCATION (UPDATED TABLE)
-- =============================================================================
CREATE TABLE interactions.interaction_equipment (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,  -- Links to specific core.equipment units
    equipment_type_booking_id INTEGER, -- Links back to the generic booking record
    hire_start_date DATE,
    hire_end_date DATE,
    actual_off_hire_date DATE,
    allocation_status VARCHAR(20) NOT NULL DEFAULT 'allocated' 
        CHECK (allocation_status IN ('allocated', 'delivered', 'collected', 'swapped_out')),
    -- Quality Control fields
    quality_check_status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (quality_check_status IN ('pending', 'passed', 'failed', 'repaired')),
    quality_check_notes TEXT,
    quality_checked_by INTEGER,
    quality_checked_at TIMESTAMP WITH TIME ZONE,
    allocated_by INTEGER NOT NULL,
    allocated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES core.equipment(id),
    FOREIGN KEY (equipment_type_booking_id) REFERENCES interactions.interaction_equipment_types(id),
    FOREIGN KEY (quality_checked_by) REFERENCES core.employees(id),
    FOREIGN KEY (allocated_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE interactions.interaction_equipment IS 'Phase 2: Specific equipment allocation - assigns actual equipment units with quality control';
COMMENT ON COLUMN interactions.interaction_equipment.equipment_type_booking_id IS 'Links back to the original generic booking record';
COMMENT ON COLUMN interactions.interaction_equipment.allocation_status IS 'Tracks the lifecycle of the allocated equipment';

-- =============================================================================
-- INTERACTION ACCESSORIES JUNCTION (updated with allocation linking)
-- =============================================================================
CREATE TABLE interactions.interaction_accessories (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    accessory_id INTEGER NOT NULL,
    equipment_allocation_id INTEGER, -- Links to specific equipment allocation if accessory is tied to specific unit
    quantity DECIMAL(8,2) NOT NULL DEFAULT 1, -- DECIMAL for litres, kg, etc.
    accessory_type VARCHAR(20) DEFAULT 'default' CHECK (accessory_type IN ('default', 'optional', 'custom')),
    hire_start_date DATE,  -- Only for non-consumable accessories
    hire_end_date DATE,    -- Only for non-consumable accessories
    actual_off_hire_date DATE,
    -- Quality Control fields (for non-consumable accessories only)
    quality_check_status VARCHAR(20) DEFAULT 'pending' 
        CHECK (quality_check_status IN ('pending', 'passed', 'failed', 'n/a')),
    quality_check_notes TEXT,
    quality_checked_by INTEGER,
    quality_checked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (accessory_id) REFERENCES core.accessories(id),
    FOREIGN KEY (equipment_allocation_id) REFERENCES interactions.interaction_equipment(id),
    FOREIGN KEY (quality_checked_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE interactions.interaction_accessories IS 'Accessories for interactions - can be linked to specific equipment allocations';
COMMENT ON COLUMN interactions.interaction_accessories.equipment_allocation_id IS 'Links accessory to specific equipment unit when relevant';

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- USER TASKBOARD TABLE (unchanged - Layer 3)
-- =============================================================================
CREATE TABLE tasks.user_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    parent_task_id INTEGER,
    assigned_to INTEGER NOT NULL,
    task_type VARCHAR(50) NOT NULL CHECK (task_type IN 
        ('send_price_list', 'send_quote', 'send_statement', 'process_refund', 'process_application', 
         'follow_up', 'verification', 'approval', 'documentation', 'misc_admin')),
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN 
        ('pending', 'in_progress', 'waiting_approval', 'completed', 'cancelled', 'on_hold')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date DATE,
    estimated_hours DECIMAL(5,2),
    actual_hours DECIMAL(5,2),
    completion_notes TEXT,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_task_id) REFERENCES tasks.user_taskboard(id),
    FOREIGN KEY (assigned_to) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.user_taskboard IS 'Layer 3: User tasks for office staff (hire controllers, accounts team)';

-- =============================================================================
-- DRIVERS TASKBOARD TABLE (updated - equipment list retrieved via both junction tables)
-- =============================================================================
CREATE TABLE tasks.drivers_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    assigned_to INTEGER,
    task_type VARCHAR(50) NOT NULL CHECK (task_type IN 
        ('delivery', 'collection', 'swap', 'repair', 'coring', 'misc_driver_task')),
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(50) NOT NULL DEFAULT 'backlog' CHECK (status IN 
        ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4', 'completed', 'cancelled')),
    customer_name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    contact_phone VARCHAR(20),
    contact_whatsapp VARCHAR(20),
    site_address TEXT,
    site_delivery_instructions TEXT,
    -- Equipment allocation status
    equipment_allocated BOOLEAN NOT NULL DEFAULT false, -- Phase 2 complete
    equipment_verified BOOLEAN NOT NULL DEFAULT false,  -- Quality control complete
    scheduled_date DATE,
    scheduled_time TIME,
    estimated_duration INTEGER DEFAULT 90, -- minutes
    -- Progress tracking
    status_booked VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_booked IN ('yes', 'no')),
    status_driver VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_driver IN ('yes', 'no')),
    status_quality_control VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_quality_control IN ('yes', 'no')),
    status_whatsapp VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_whatsapp IN ('yes', 'no')),
    -- Completion tracking
    completed_at TIMESTAMP WITH TIME ZONE,
    completion_notes TEXT,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES core.employees(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.drivers_taskboard IS 'Layer 3: Driver tasks - equipment list retrieved via interaction_id junction tables';
COMMENT ON COLUMN tasks.drivers_taskboard.equipment_allocated IS 'Set to true when Phase 2 allocation is complete (specific units assigned)';
COMMENT ON COLUMN tasks.drivers_taskboard.equipment_verified IS 'Set to true when all allocated equipment passes quality control';

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- SYSTEM TABLES
-- =============================================================================

-- REFERENCE NUMBER PREFIXES
CREATE TABLE system.reference_prefixes (
    id SERIAL PRIMARY KEY,
    interaction_type VARCHAR(50) UNIQUE NOT NULL,
    prefix VARCHAR(10) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- REFERENCE NUMBER SEQUENCES
CREATE TABLE system.reference_sequences (
    id SERIAL PRIMARY KEY,
    prefix VARCHAR(10) NOT NULL,
    date_part VARCHAR(10) NOT NULL, -- YYMMDD format
    last_sequence INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(prefix, date_part)
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

CREATE INDEX idx_interactions_type ON interactions.interactions(interaction_type);
CREATE INDEX idx_interactions_status ON interactions.interactions(status);
CREATE INDEX idx_interactions_customer ON interactions.interactions(customer_id);
CREATE INDEX idx_interactions_date ON interactions.interactions(created_at);

-- Phase 1 booking indexes
CREATE INDEX idx_equipment_types_interaction ON interactions.interaction_equipment_types(interaction_id);
CREATE INDEX idx_equipment_types_booking_status ON interactions.interaction_equipment_types(booking_status);

-- Phase 2 allocation indexes
CREATE INDEX idx_equipment_interaction ON interactions.interaction_equipment(interaction_id);
CREATE INDEX idx_equipment_allocation_status ON interactions.interaction_equipment(allocation_status);
CREATE INDEX idx_equipment_type_booking ON interactions.interaction_equipment(equipment_type_booking_id);

CREATE INDEX idx_accessories_interaction ON interactions.interaction_accessories(interaction_id);
CREATE INDEX idx_accessories_equipment_allocation ON interactions.interaction_accessories(equipment_allocation_id);

CREATE INDEX idx_user_tasks_assigned ON tasks.user_taskboard(assigned_to, status);
CREATE INDEX idx_driver_tasks_status ON tasks.drivers_taskboard(status);
CREATE INDEX idx_driver_tasks_assigned ON tasks.drivers_taskboard(assigned_to);
CREATE INDEX idx_driver_tasks_equipment_status ON tasks.drivers_taskboard(equipment_allocated, equipment_verified);

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE interactions.interactions IS 'Central hub table - all business interactions with clean procedural structure';
COMMENT ON TABLE interactions.interaction_equipment_types IS 'Phase 1: Generic equipment booking - reserves equipment types with quantities';
COMMENT ON TABLE interactions.interaction_equipment IS 'Phase 2: Specific equipment allocation - assigns actual equipment units';
COMMENT ON TABLE interactions.interaction_accessories IS 'Accessories for interactions - can be linked to specific equipment or general';
COMMENT ON TABLE tasks.user_taskboard IS 'User-specific administrative tasks';
COMMENT ON TABLE tasks.drivers_taskboard IS 'Driver tasks - supports 2-phase equipment workflow';

-- =============================================================================
-- END OF SCHEMA
-- =============================================================================