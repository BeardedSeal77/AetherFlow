-- =============================================================================
-- STEP 06: INTERACTIONS AND COMPONENTS TABLES
-- =============================================================================
-- Purpose: Create interaction tables and component tables (Layer 1 & 2)
-- Run as: SYSTEM user
-- Database: task_management
-- Order: Must be run SIXTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- INTERACTIONS TABLE (Layer 1)
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

COMMENT ON TABLE interactions.interactions IS 'Layer 1: All customer interactions - universal entry point';

-- =============================================================================
-- COMPONENT TABLES (Layer 2)
-- =============================================================================

-- Customer Details Component (shared by multiple interaction types)
CREATE TABLE interactions.component_customer_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_surname VARCHAR(255),
    company_name VARCHAR(255),
    contact_number VARCHAR(20),
    whatsapp_number VARCHAR(20),
    email VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE
);

-- Equipment List Component (used by price_list, quote, hire, off_hire, breakdown)
CREATE TABLE interactions.component_equipment_list (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    equipment_category_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    hire_duration INTEGER,
    hire_period_type VARCHAR(20) CHECK (hire_period_type IN ('days', 'weeks', 'months')),
    special_requirements TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_category_id) REFERENCES core.equipment_categories(id)
);

-- Hire Details Component (for hire interactions)
CREATE TABLE interactions.component_hire_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    site_id INTEGER,
    deliver_date DATE NOT NULL,
    deliver_time TIME,
    start_date DATE,
    start_time TIME,
    delivery_method VARCHAR(50) NOT NULL DEFAULT 'deliver' CHECK (delivery_method IN ('deliver', 'counter_collection')),
    special_instructions TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (site_id) REFERENCES core.sites(id)
);

-- Off-Hire Details Component (for off_hire interactions)
CREATE TABLE interactions.component_offhire_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    site_id INTEGER,
    collect_date DATE NOT NULL,
    collect_time TIME,
    end_date DATE,
    end_time TIME,
    collection_method VARCHAR(50) NOT NULL DEFAULT 'collect' CHECK (collection_method IN ('collect', 'counter_return')),
    early_return BOOLEAN NOT NULL DEFAULT false,
    condition_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (site_id) REFERENCES core.sites(id)
);

-- Breakdown Details Component (for breakdown interactions)
CREATE TABLE interactions.component_breakdown_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    site_id INTEGER,
    breakdown_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    issue_description TEXT NOT NULL,
    urgency_level VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (urgency_level IN ('low', 'medium', 'high', 'critical')),
    resolution_type VARCHAR(50) NOT NULL DEFAULT 'swap' CHECK (resolution_type IN ('swap', 'repair_onsite', 'collect_repair')),
    work_impact TEXT,
    customer_contact_onsite VARCHAR(255),
    customer_phone_onsite VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (site_id) REFERENCES core.sites(id)
);

-- Application Details Component (for application interactions)
CREATE TABLE interactions.component_application_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    application_type VARCHAR(20) NOT NULL CHECK (application_type IN ('individual', 'company')),
    applicant_first_name VARCHAR(100) NOT NULL,
    applicant_last_name VARCHAR(100) NOT NULL,
    applicant_email VARCHAR(255) NOT NULL,
    verification_status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (verification_status IN 
        ('pending', 'documents_requested', 'documents_received', 'under_review', 'approved', 'rejected')),
    documents_required TEXT,
    documents_received TEXT,
    verification_notes TEXT,
    approved_by INTEGER,
    approval_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (approved_by) REFERENCES core.employees(id)
);

-- Quote Totals Component (for quote interactions)
CREATE TABLE interactions.component_quote_totals (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    subtotal DECIMAL(15,2) NOT NULL,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 15.00,
    tax_amount DECIMAL(15,2) NOT NULL,
    total_amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'ZAR',
    valid_until DATE NOT NULL,
    quote_version INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE
);

-- Refund Details Component (for refund interactions)
CREATE TABLE interactions.component_refund_details (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    refund_type VARCHAR(20) NOT NULL CHECK (refund_type IN ('full', 'partial', 'deposit_only')),
    refund_amount DECIMAL(15,2) NOT NULL,
    refund_reason TEXT NOT NULL,
    account_balance_before DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    account_balance_after DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    refund_method VARCHAR(20) NOT NULL DEFAULT 'eft' CHECK (refund_method IN ('eft', 'cash', 'cheque', 'credit_note')),
    bank_details TEXT,
    processed_by INTEGER,
    processed_date TIMESTAMP WITH TIME ZONE,
    transaction_reference VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (processed_by) REFERENCES core.employees(id)
);

-- =============================================================================
-- TRIGGERS FOR UPDATED_AT
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER interactions_updated_at 
    BEFORE UPDATE ON interactions.interactions
    FOR EACH ROW EXECUTE FUNCTION interactions.update_timestamp();

-- =============================================================================
-- NEXT STEP: Run 07_tasks_tables.sql
-- =============================================================================