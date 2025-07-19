-- =============================================================================
-- EQUIPMENT HIRE DATABASE SCHEMA REDESIGN - CLEANER ARCHITECTURE
-- =============================================================================
-- Updated design with proper junction table relationships
-- Equipment Types as central hub connecting to Generic/Specific equipment and accessories
-- =============================================================================

-- Drop existing schemas for clean redesign
DROP SCHEMA IF EXISTS equipment CASCADE;
DROP SCHEMA IF EXISTS interactions CASCADE;
DROP SCHEMA IF EXISTS tasks CASCADE;
DROP SCHEMA IF EXISTS system CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;

-- Create new schemas
CREATE SCHEMA core;
CREATE SCHEMA equipment;
CREATE SCHEMA interactions;
CREATE SCHEMA tasks;
CREATE SCHEMA system;

-- Set search path
SET search_path TO core, equipment, interactions, tasks, system, public;

-- =============================================================================
-- CORE SCHEMA - Master Data
-- =============================================================================

-- Employees table (system users)
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
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE core.employees IS 'System users and employees';

-- Customers table
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

COMMENT ON TABLE core.customers IS 'Customer master data';

-- Customer contacts
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
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES core.employees(id),
    FOREIGN KEY (customer_id) REFERENCES core.customers(id) ON DELETE CASCADE
);

COMMENT ON TABLE core.contacts IS 'Customer contact persons';

-- Customer sites
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
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES core.employees(id),
    FOREIGN KEY (customer_id) REFERENCES core.customers(id) ON DELETE CASCADE
);

COMMENT ON TABLE core.sites IS 'Customer delivery and billing sites';

-- =============================================================================
-- EQUIPMENT SCHEMA - Redesigned Equipment Management System
-- =============================================================================

-- Equipment types (central hub) - connects to both generic and specific equipment
CREATE TABLE equipment.equipment_types (
    id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) UNIQUE NOT NULL,
    type_name VARCHAR(255) NOT NULL,
    description TEXT,
    specifications TEXT,
    daily_rate DECIMAL(10,2) DEFAULT 0.00,
    weekly_rate DECIMAL(10,2) DEFAULT 0.00,
    monthly_rate DECIMAL(10,2) DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE equipment.equipment_types IS 'Equipment categories - central hub for generic/specific equipment and accessories';

-- Generic equipment - for Phase 1 booking (conceptual inventory)
CREATE TABLE equipment.equipment_generic (
    id SERIAL PRIMARY KEY,
    equipment_type_id INTEGER NOT NULL,
    generic_code VARCHAR(20) UNIQUE NOT NULL, -- GEN-RAM-001, GEN-PLT-001
    description TEXT,
    virtual_stock INTEGER NOT NULL DEFAULT 0, -- Available units for booking
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equipment_type_id) REFERENCES equipment.equipment_types(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE equipment.equipment_generic IS 'Generic equipment units for Phase 1 booking - connects to equipment_types';

-- Specific equipment - for Phase 2 allocation (physical assets)
CREATE TABLE equipment.equipment (
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
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equipment_type_id) REFERENCES equipment.equipment_types(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE equipment.equipment IS 'Specific equipment units for Phase 2 allocation - connects to equipment_types';

-- Accessories master table
CREATE TABLE equipment.accessories (
    id SERIAL PRIMARY KEY,
    accessory_name VARCHAR(255) NOT NULL,
    accessory_code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    is_consumable BOOLEAN DEFAULT false,
    unit_of_measure VARCHAR(20) DEFAULT 'item',
    unit_rate DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE equipment.accessories IS 'Master accessories catalog';

-- Equipment-Accessories relationship (connects accessories to equipment types)
-- This serves both generic and specific equipment through equipment_types
CREATE TABLE equipment.equipment_accessories (
    id SERIAL PRIMARY KEY,
    equipment_type_id INTEGER NOT NULL,
    accessory_id INTEGER NOT NULL,
    accessory_type VARCHAR(20) DEFAULT 'default' CHECK (accessory_type IN ('default', 'optional')),
    default_quantity DECIMAL(8,2) NOT NULL DEFAULT 1,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equipment_type_id) REFERENCES equipment.equipment_types(id) ON DELETE CASCADE,
    FOREIGN KEY (accessory_id) REFERENCES equipment.accessories(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES core.employees(id),
    UNIQUE(equipment_type_id, accessory_id)
);

COMMENT ON TABLE equipment.equipment_accessories IS 'Links equipment types to accessories - serves both generic and specific equipment';

-- =============================================================================
-- INTERACTIONS SCHEMA - Business Transactions
-- =============================================================================

-- Main interactions table
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
    hire_start_date DATE,
    hire_end_date DATE,
    delivery_date DATE,
    delivery_time TIME,
    site_id INTEGER,
    special_instructions TEXT,
    notes TEXT,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (created_by) REFERENCES core.employees(id),
    FOREIGN KEY (customer_id) REFERENCES core.customers(id),
    FOREIGN KEY (contact_id) REFERENCES core.contacts(id),
    FOREIGN KEY (employee_id) REFERENCES core.employees(id),
    FOREIGN KEY (site_id) REFERENCES core.sites(id)
);

COMMENT ON TABLE interactions.interactions IS 'Main business interactions hub';

-- Phase 1: Generic equipment bookings (renamed from interaction_equipment_types)
CREATE TABLE interactions.interaction_equipment_generic (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    equipment_generic_id INTEGER NOT NULL, -- Now connects to equipment_generic instead of equipment_types
    quantity INTEGER NOT NULL DEFAULT 1,
    hire_start_date DATE NOT NULL,
    hire_end_date DATE,
    booking_status VARCHAR(20) NOT NULL DEFAULT 'booked' 
        CHECK (booking_status IN ('booked', 'allocated', 'delivered', 'returned', 'cancelled')),
    notes TEXT,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_generic_id) REFERENCES equipment.equipment_generic(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE interactions.interaction_equipment_generic IS 'Phase 1: Generic equipment bookings - connects to equipment_generic';

-- Phase 2: Specific equipment allocations
CREATE TABLE interactions.interaction_equipment (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,
    equipment_generic_booking_id INTEGER, -- Links to Phase 1 generic booking
    allocation_status VARCHAR(20) NOT NULL DEFAULT 'allocated' 
        CHECK (allocation_status IN ('allocated', 'qc_pending', 'qc_approved', 'delivered', 'returned', 'damaged')),
    allocated_by INTEGER NOT NULL,
    allocated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    qc_approved_by INTEGER,
    qc_approved_at TIMESTAMP WITH TIME ZONE,
    qc_notes TEXT,
    delivery_notes TEXT,
    return_notes TEXT,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES equipment.equipment(id),
    FOREIGN KEY (equipment_generic_booking_id) REFERENCES interactions.interaction_equipment_generic(id),
    FOREIGN KEY (allocated_by) REFERENCES core.employees(id),
    FOREIGN KEY (qc_approved_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE interactions.interaction_equipment IS 'Phase 2: Specific equipment allocations - links to generic bookings';

-- Accessory assignments
CREATE TABLE interactions.interaction_accessories (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    accessory_id INTEGER NOT NULL,
    equipment_generic_booking_id INTEGER, -- Links to specific generic equipment booking if applicable
    quantity DECIMAL(8,2) NOT NULL DEFAULT 1,
    accessory_type VARCHAR(20) DEFAULT 'default' CHECK (accessory_type IN ('default', 'optional', 'standalone')),
    unit_rate DECIMAL(10,2) DEFAULT 0.00,
    notes TEXT,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (accessory_id) REFERENCES equipment.accessories(id),
    FOREIGN KEY (equipment_generic_booking_id) REFERENCES interactions.interaction_equipment_generic(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE interactions.interaction_accessories IS 'Accessories assigned to hire interactions - links to generic bookings';

-- =============================================================================
-- TASKS SCHEMA - Driver and User Task Management
-- =============================================================================

-- Driver taskboard
CREATE TABLE tasks.drivers_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    task_type VARCHAR(50) NOT NULL CHECK (task_type IN ('delivery', 'collection', 'service', 'inspection', 'transfer')),
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) NOT NULL DEFAULT 'backlog' CHECK (status IN ('backlog', 'assigned', 'in_progress', 'completed', 'cancelled')),
    assigned_driver_id INTEGER,
    customer_name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    contact_phone VARCHAR(20),
    contact_whatsapp VARCHAR(20),
    site_address TEXT,
    scheduled_date DATE,
    scheduled_time TIME,
    actual_start_time TIMESTAMP WITH TIME ZONE,
    actual_completion_time TIMESTAMP WITH TIME ZONE,
    equipment_allocated BOOLEAN NOT NULL DEFAULT false,
    equipment_verified BOOLEAN NOT NULL DEFAULT false,
    driver_notes TEXT,
    completion_notes TEXT,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_driver_id) REFERENCES core.employees(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.drivers_taskboard IS 'Driver task management for deliveries and collections';

-- User taskboard (for office staff tasks)
CREATE TABLE tasks.user_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    assigned_user_id INTEGER NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date DATE,
    completed_at TIMESTAMP WITH TIME ZONE,
    completion_notes TEXT,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_user_id) REFERENCES core.employees(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.user_taskboard IS 'User-specific task management';

-- =============================================================================
-- SYSTEM SCHEMA - Configuration and Utilities
-- =============================================================================

-- Reference number prefixes
CREATE TABLE system.reference_prefixes (
    id SERIAL PRIMARY KEY,
    interaction_type VARCHAR(50) UNIQUE NOT NULL,
    prefix VARCHAR(10) NOT NULL,
    description VARCHAR(255),
    current_sequence INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system.reference_prefixes IS 'Reference number generation configuration';

-- System activity log
CREATE TABLE system.activity_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id INTEGER,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES core.employees(id)
);

COMMENT ON TABLE system.activity_log IS 'System activity and audit trail';

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Core indexes
CREATE INDEX idx_customers_code ON core.customers(customer_code);
CREATE INDEX idx_customers_name ON core.customers(customer_name);
CREATE INDEX idx_contacts_customer ON core.contacts(customer_id);
CREATE INDEX idx_sites_customer ON core.sites(customer_id);

-- Equipment indexes
CREATE INDEX idx_equipment_types_code ON equipment.equipment_types(type_code);
CREATE INDEX idx_equipment_type ON equipment.equipment(equipment_type_id);
CREATE INDEX idx_equipment_status ON equipment.equipment(status);
CREATE INDEX idx_equipment_code ON equipment.equipment(asset_code);
CREATE INDEX idx_generic_equipment_type ON equipment.equipment_generic(equipment_type_id);
CREATE INDEX idx_accessories_code ON equipment.accessories(accessory_code);
CREATE INDEX idx_equipment_accessories_type ON equipment.equipment_accessories(equipment_type_id);

-- Interaction indexes
CREATE INDEX idx_interactions_customer ON interactions.interactions(customer_id);
CREATE INDEX idx_interactions_type ON interactions.interactions(interaction_type);
CREATE INDEX idx_interactions_status ON interactions.interactions(status);
CREATE INDEX idx_interactions_ref ON interactions.interactions(reference_number);
CREATE INDEX idx_interactions_date ON interactions.interactions(hire_start_date);
CREATE INDEX idx_equipment_generic_interaction ON interactions.interaction_equipment_generic(interaction_id);
CREATE INDEX idx_equipment_interaction ON interactions.interaction_equipment(interaction_id);
CREATE INDEX idx_accessories_interaction ON interactions.interaction_accessories(interaction_id);

-- Task indexes
CREATE INDEX idx_driver_tasks_driver ON tasks.drivers_taskboard(assigned_driver_id);
CREATE INDEX idx_driver_tasks_status ON tasks.drivers_taskboard(status);
CREATE INDEX idx_driver_tasks_date ON tasks.drivers_taskboard(scheduled_date);
CREATE INDEX idx_user_tasks_user ON tasks.user_taskboard(assigned_user_id);
CREATE INDEX idx_user_tasks_status ON tasks.user_taskboard(status);

-- =============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =============================================================================

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to relevant tables
CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON core.employees FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON core.customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON core.contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON core.sites FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_equipment_types_updated_at BEFORE UPDATE ON equipment.equipment_types FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_equipment_updated_at BEFORE UPDATE ON equipment.equipment FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_generic_equipment_updated_at BEFORE UPDATE ON equipment.equipment_generic FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_interactions_updated_at BEFORE UPDATE ON interactions.interactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_equipment_generic_bookings_updated_at BEFORE UPDATE ON interactions.interaction_equipment_generic FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_driver_tasks_updated_at BEFORE UPDATE ON tasks.drivers_taskboard FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_tasks_updated_at BEFORE UPDATE ON tasks.user_taskboard FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();