-- =============================================================================
-- STEP 04: CORE BUSINESS TABLES
-- =============================================================================
-- Purpose: Create core business entity tables
-- Run as: SYSTEM user
-- Database: task_management
-- Order: Must be run FOURTH
-- =============================================================================

-- Set search path
SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- EMPLOYEES TABLE (must be first for user management)
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
-- CUSTOMERS TABLE
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
-- CONTACTS TABLE
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
-- SITES TABLE
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
-- EQUIPMENT CATEGORIES TABLE
-- =============================================================================
CREATE TABLE core.equipment_categories (
    id SERIAL PRIMARY KEY,
    category_code VARCHAR(20) UNIQUE NOT NULL,
    category_name VARCHAR(255) NOT NULL,
    description TEXT,
    specifications TEXT,
    default_accessories TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE core.equipment_categories IS 'Equipment categories for rental (generic, not specific units)';

-- =============================================================================
-- EQUIPMENT PRICING TABLE
-- =============================================================================
CREATE TABLE core.equipment_pricing (
    id SERIAL PRIMARY KEY,
    equipment_category_id INTEGER NOT NULL,
    customer_type VARCHAR(20) NOT NULL CHECK (customer_type IN ('individual', 'company')),
    price_per_day DECIMAL(10,2) NOT NULL,
    price_per_week DECIMAL(10,2) NOT NULL,
    price_per_month DECIMAL(10,2) NOT NULL,
    deposit_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    minimum_hire_period INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_until DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (equipment_category_id) REFERENCES core.equipment_categories(id),
    UNIQUE(equipment_category_id, customer_type, effective_from)
);

COMMENT ON TABLE core.equipment_pricing IS 'Equipment pricing by customer type';

-- =============================================================================
-- GENERIC EMPLOYEE and CUSTOMER/CONTACT
-- =============================================================================

INSERT INTO core.employees (
    id, employee_code, name, surname, role, email, phone_number, hire_date, status, created_at
) VALUES (
    1, 'SYSTEM', 'System', 'User', 'owner', 'system@localhost', NULL, CURRENT_DATE, 'active', CURRENT_TIMESTAMP
);

INSERT INTO core.customers (
    id, customer_code, customer_name, is_company, credit_limit, payment_terms, 
    status, created_by, created_at
) VALUES (
    999, 'GENERIC', 'Generic Customer - Applications', false, 0.00, 'N/A', 
    'active', 1, CURRENT_TIMESTAMP
);

INSERT INTO core.contacts (
    id, customer_id, first_name, last_name, job_title, 
    is_primary_contact, is_billing_contact, status, created_at
) VALUES (
    999, 999, 'Generic', 'Contact', 'Application Contact', 
    true, false, 'active', CURRENT_TIMESTAMP
);


-- =============================================================================
-- NEXT STEP: Run 05_security_tables.sql
-- =============================================================================