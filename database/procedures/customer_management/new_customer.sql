-- =============================================================================
-- PROCEDURE: new_customer.sql
-- =============================================================================
-- Purpose: Add a new customer with primary contact
-- Use Case: Employee adds customer from primary hire system (if they are not already in this system)
-- Called by: Flask server when employee creates new customer account
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- FUNCTION: Add New Customer with Contact
-- =============================================================================

CREATE OR REPLACE FUNCTION core.add_new_customer(
    -- Customer details
    p_customer_name VARCHAR(255),
    p_is_company BOOLEAN,
    p_registration_number VARCHAR(50) DEFAULT NULL,
    p_vat_number VARCHAR(20) DEFAULT NULL,
    p_credit_limit DECIMAL(15,2) DEFAULT 5000.00,
    p_payment_terms VARCHAR(50) DEFAULT '30 days',
    
    -- Primary contact details
    p_contact_first_name VARCHAR(100),
    p_contact_last_name VARCHAR(100),
    p_contact_email VARCHAR(255),
    p_contact_phone VARCHAR(20),
    p_contact_whatsapp VARCHAR(20) DEFAULT NULL,
    p_job_title VARCHAR(100) DEFAULT NULL,
    p_department VARCHAR(100) DEFAULT NULL,
    
    -- Site details (optional)
    p_site_name VARCHAR(255) DEFAULT NULL,
    p_site_type VARCHAR(50) DEFAULT 'head_office',
    p_address_line1 VARCHAR(255) DEFAULT NULL,
    p_address_line2 VARCHAR(255) DEFAULT NULL,
    p_city VARCHAR(100) DEFAULT NULL,
    p_province VARCHAR(100) DEFAULT 'Gauteng',
    p_postal_code VARCHAR(10) DEFAULT NULL,
    p_delivery_instructions TEXT DEFAULT NULL,
    
    -- System details
    p_created_by INTEGER DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    customer_id INTEGER,
    customer_code VARCHAR(20),
    contact_id INTEGER,
    site_id INTEGER
) AS $$
DECLARE
    v_customer_id INTEGER;
    v_contact_id INTEGER;
    v_site_id INTEGER;
    v_customer_code VARCHAR(20);
    v_created_by INTEGER;
    v_prefix VARCHAR(3);
BEGIN
    -- Get creator ID from session if not provided
    v_created_by := COALESCE(p_created_by, current_setting('app.current_employee_id', true)::INTEGER);
    
    -- Validate required fields
    IF p_customer_name IS NULL OR TRIM(p_customer_name) = '' THEN
        RETURN QUERY SELECT false, 'Customer name is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    IF p_contact_first_name IS NULL OR TRIM(p_contact_first_name) = '' THEN
        RETURN QUERY SELECT false, 'Contact first name is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    IF p_contact_last_name IS NULL OR TRIM(p_contact_last_name) = '' THEN
        RETURN QUERY SELECT false, 'Contact last name is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    IF p_contact_email IS NULL OR TRIM(p_contact_email) = '' THEN
        RETURN QUERY SELECT false, 'Contact email is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    IF v_created_by IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not authenticated'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Check if customer already exists
    IF EXISTS (SELECT 1 FROM core.customers WHERE LOWER(customer_name) = LOWER(p_customer_name) AND status = 'active') THEN
        RETURN QUERY SELECT false, 'Customer with this name already exists'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM core.contacts WHERE LOWER(email) = LOWER(p_contact_email) AND status = 'active') THEN
        RETURN QUERY SELECT false, 'Contact email already exists in system'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Generate customer code (first 3 letters + sequence number)
    v_prefix := UPPER(LEFT(REGEXP_REPLACE(p_customer_name, '[^A-Za-z]', '', 'g'), 3));
    IF LENGTH(v_prefix) < 3 THEN
        v_prefix := LPAD(v_prefix, 3, 'X');
    END IF;
    
    -- Get next sequence and create customer code
    SELECT v_prefix || LPAD(nextval('core.customers_id_seq')::TEXT, 3, '0') INTO v_customer_code;
    
    -- Insert customer
    INSERT INTO core.customers (
        customer_code, customer_name, is_company, registration_number, 
        vat_number, credit_limit, payment_terms, created_by
    ) VALUES (
        v_customer_code, p_customer_name, p_is_company, p_registration_number,
        p_vat_number, p_credit_limit, p_payment_terms, v_created_by
    ) RETURNING id INTO v_customer_id;
    
    -- Insert primary contact
    INSERT INTO core.contacts (
        customer_id, first_name, last_name, job_title, department,
        email, phone_number, whatsapp_number,
        is_primary_contact, is_billing_contact
    ) VALUES (
        v_customer_id, p_contact_first_name, p_contact_last_name, 
        p_job_title, p_department, p_contact_email, p_contact_phone, 
        p_contact_whatsapp, true, true
    ) RETURNING id INTO v_contact_id;
    
    -- Insert site if address details provided
    IF p_address_line1 IS NOT NULL AND p_city IS NOT NULL THEN
        INSERT INTO core.sites (
            customer_id, site_code, site_name, site_type,
            address_line1, address_line2, city, province, postal_code,
            site_contact_name, site_contact_phone, delivery_instructions
        ) VALUES (
            v_customer_id, 
            v_customer_code || '-01',
            COALESCE(p_site_name, p_customer_name || ' - Main Office'),
            p_site_type,
            p_address_line1, p_address_line2, p_city, p_province, p_postal_code,
            p_contact_first_name || ' ' || p_contact_last_name,
            p_contact_phone,
            p_delivery_instructions
        ) RETURNING id INTO v_site_id;
    END IF;
    
    -- Log audit entry
    INSERT INTO security.audit_log (employee_id, action, table_name, record_id, new_values)
    VALUES (v_created_by, 'create_customer', 'customers', v_customer_id, 
            jsonb_build_object(
                'customer_name', p_customer_name,
                'customer_code', v_customer_code,
                'is_company', p_is_company,
                'contact_email', p_contact_email
            ));
    
    -- Return success
    RETURN QUERY SELECT 
        true, 
        'Customer and contact created successfully'::TEXT,
        v_customer_id,
        v_customer_code,
        v_contact_id,
        v_site_id;
        
EXCEPTION WHEN OTHERS THEN
    -- Return error
    RETURN QUERY SELECT 
        false, 
        ('Error creating customer: ' || SQLERRM)::TEXT,
        NULL::INTEGER,
        NULL::VARCHAR(20),
        NULL::INTEGER,
        NULL::INTEGER;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- USAGE EXAMPLE
-- =============================================================================

/*
-- Example: Add a new company customer
SELECT * FROM core.add_new_customer(
    -- Customer details
    p_customer_name := 'New Construction Ltd',
    p_is_company := true,
    p_registration_number := 'REG2025001',
    p_vat_number := 'VAT4001234567',
    p_credit_limit := 25000.00,
    p_payment_terms := '30 days',
    
    -- Contact details
    p_contact_first_name := 'Jane',
    p_contact_last_name := 'Smith',
    p_contact_email := 'jane.smith@newconstruction.com',
    p_contact_phone := '+27111234567',
    p_contact_whatsapp := '+27111234567',
    p_job_title := 'Project Manager',
    p_department := 'Operations',
    
    -- Site details
    p_site_name := 'Head Office',
    p_address_line1 := '123 Business Park',
    p_address_line2 := 'Suite 456',
    p_city := 'Johannesburg',
    p_province := 'Gauteng',
    p_postal_code := '2000',
    p_delivery_instructions := 'Reception will sign for deliveries'
);

-- Example: Add an individual customer (minimal info)
SELECT * FROM core.add_new_customer(
    p_customer_name := 'John Doe',
    p_is_company := false,
    p_credit_limit := 3000.00,
    p_payment_terms := 'COD',
    p_contact_first_name := 'John',
    p_contact_last_name := 'Doe',
    p_contact_email := 'john.doe@email.com',
    p_contact_phone := '+27119876543'
);
*/

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

-- Allow all authenticated users to create customers
GRANT EXECUTE ON FUNCTION core.add_new_customer TO PUBLIC;