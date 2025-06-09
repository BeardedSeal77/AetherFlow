-- =============================================================================
-- CUSTOMER MANAGEMENT: NEW CUSTOMER REGISTRATION
-- =============================================================================
-- Purpose: Complete customer registration procedure for data entry page
-- Creates customer, primary contact, and site records with full audit trail
-- Designed for Flask frontend data entry forms
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.create_new_customer;

-- Create the customer registration procedure
CREATE OR REPLACE FUNCTION core.create_new_customer(
    -- Required Customer Details
    p_customer_name VARCHAR(255),
    p_contact_first_name VARCHAR(100),
    p_contact_last_name VARCHAR(100),
    p_contact_email VARCHAR(255),
    
    -- Optional Customer Details (all with defaults)
    p_customer_code VARCHAR(20) DEFAULT NULL,  -- If NULL, will default to ID
    p_is_company BOOLEAN DEFAULT true,
    p_registration_number VARCHAR(50) DEFAULT NULL,
    p_vat_number VARCHAR(20) DEFAULT NULL,
    p_credit_limit DECIMAL(15,2) DEFAULT 0.00,
    p_payment_terms VARCHAR(50) DEFAULT '30 days',
    
    -- Optional Contact Details (all with defaults)
    p_contact_job_title VARCHAR(100) DEFAULT NULL,
    p_contact_department VARCHAR(100) DEFAULT NULL,
    p_contact_phone VARCHAR(20) DEFAULT NULL,
    p_contact_whatsapp VARCHAR(20) DEFAULT NULL,
    p_is_billing_contact BOOLEAN DEFAULT true,
    
    -- Optional Site/Address Details (all with defaults)
    p_site_name VARCHAR(255) DEFAULT NULL,
    p_site_type VARCHAR(50) DEFAULT 'delivery_site',
    p_address_line1 VARCHAR(255) DEFAULT NULL,
    p_address_line2 VARCHAR(255) DEFAULT NULL,
    p_city VARCHAR(100) DEFAULT NULL,
    p_province VARCHAR(100) DEFAULT NULL,
    p_postal_code VARCHAR(10) DEFAULT NULL,
    p_country VARCHAR(100) DEFAULT 'South Africa',
    p_delivery_instructions TEXT DEFAULT NULL,
    
    -- Optional System Details (all with defaults)
    p_created_by INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    customer_id INTEGER,
    customer_code VARCHAR(20),
    contact_id INTEGER,
    site_id INTEGER,
    validation_errors TEXT[]
) AS $$
DECLARE
    v_customer_id INTEGER;
    v_contact_id INTEGER;
    v_site_id INTEGER;
    v_customer_code VARCHAR(20);
    v_created_by INTEGER;
    v_employee_name TEXT;
    v_validation_errors TEXT[] := '{}';
    v_next_sequence INTEGER;
    v_company_prefix VARCHAR(3);
    v_existing_customer INTEGER;
    v_existing_email INTEGER;
BEGIN
    -- =============================================================================
    -- AUTHENTICATION & AUTHORIZATION
    -- =============================================================================
    
    -- Get employee ID from session or parameter
    IF p_session_token IS NOT NULL THEN
        SELECT ea.employee_id INTO v_created_by
        FROM security.employee_auth ea
        WHERE ea.session_token = p_session_token
        AND ea.session_expires > CURRENT_TIMESTAMP;
        
        IF v_created_by IS NULL THEN
            RETURN QUERY SELECT false, 'Invalid or expired session'::TEXT, 
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, 
                ARRAY['Invalid session token']::TEXT[];
            RETURN;
        END IF;
    ELSE
        v_created_by := COALESCE(p_created_by, 
            NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER);
    END IF;
    
    IF v_created_by IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, 
            ARRAY['No authenticated employee found']::TEXT[];
        RETURN;
    END IF;
    
    -- Get employee details for logging
    SELECT e.name || ' ' || e.surname INTO v_employee_name
    FROM core.employees e
    WHERE e.id = v_created_by AND e.status = 'active';
    
    IF v_employee_name IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not found or inactive'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, 
            ARRAY['Employee not found or inactive']::TEXT[];
        RETURN;
    END IF;
    
    -- =============================================================================
    -- INPUT VALIDATION
    -- =============================================================================
    
    -- Required customer fields
    IF p_customer_name IS NULL OR TRIM(p_customer_name) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer name is required');
    END IF;
    
    IF LENGTH(TRIM(p_customer_name)) < 2 THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer name must be at least 2 characters');
    END IF;
    
    -- Required contact fields
    IF p_contact_first_name IS NULL OR TRIM(p_contact_first_name) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Contact first name is required');
    END IF;
    
    IF p_contact_last_name IS NULL OR TRIM(p_contact_last_name) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Contact last name is required');
    END IF;
    
    IF p_contact_email IS NULL OR TRIM(p_contact_email) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Contact email is required');
    ELSIF p_contact_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        v_validation_errors := array_append(v_validation_errors, 'Contact email format is invalid');
    END IF;
    
    -- Company-specific validations
    IF p_is_company THEN
        IF p_vat_number IS NOT NULL AND LENGTH(TRIM(p_vat_number)) > 0 THEN
            -- Basic VAT number format validation for South Africa
            IF p_vat_number !~ '^[0-9]{10}$' AND p_vat_number !~ '^[0-9]{9}$' THEN
                v_validation_errors := array_append(v_validation_errors, 'VAT number should be 9 or 10 digits');
            END IF;
        END IF;
    END IF;
    
    -- Credit limit validation
    IF p_credit_limit < 0 THEN
        v_validation_errors := array_append(v_validation_errors, 'Credit limit cannot be negative');
    END IF;
    
    -- Site validation (if address provided)
    IF p_address_line1 IS NOT NULL AND TRIM(p_address_line1) != '' THEN
        IF p_city IS NULL OR TRIM(p_city) = '' THEN
            v_validation_errors := array_append(v_validation_errors, 'City is required when address is provided');
        END IF;
        
        IF p_site_type NOT IN ('delivery_site', 'billing_address', 'head_office', 'branch', 'warehouse', 'project_site') THEN
            v_validation_errors := array_append(v_validation_errors, 'Invalid site type');
        END IF;
    END IF;
    
    -- =============================================================================
    -- DUPLICATE CHECKS
    -- =============================================================================
    
    -- Check for duplicate customer name
    SELECT id INTO v_existing_customer
    FROM core.customers
    WHERE LOWER(TRIM(customer_name)) = LOWER(TRIM(p_customer_name))
    AND status != 'inactive'
    LIMIT 1;
    
    IF v_existing_customer IS NOT NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'A customer with this name already exists');
    END IF;
    
    -- Check for duplicate customer code (if provided)
    IF p_customer_code IS NOT NULL AND TRIM(p_customer_code) != '' THEN
        SELECT id INTO v_existing_customer
        FROM core.customers
        WHERE customer_code = TRIM(p_customer_code)
        LIMIT 1;
        
        IF v_existing_customer IS NOT NULL THEN
            v_validation_errors := array_append(v_validation_errors, 'Customer code already exists');
        END IF;
    END IF;
    
    -- Check for duplicate contact email
    SELECT customer_id INTO v_existing_email
    FROM core.contacts
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(p_contact_email))
    AND status = 'active'
    LIMIT 1;
    
    IF v_existing_email IS NOT NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'A contact with this email already exists');
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Validation failed'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, 
            v_validation_errors;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- CREATE CUSTOMER RECORD
    -- =============================================================================
    
    -- Insert customer without customer_code first to get the ID
    INSERT INTO core.customers (
        customer_code,  -- Will be set below
        customer_name,
        is_company,
        registration_number,
        vat_number,
        credit_limit,
        payment_terms,
        status,
        created_by,
        created_at,
        updated_at
    ) VALUES (
        '999999',  -- Temporary placeholder to satisfy NOT NULL constraint
        TRIM(p_customer_name),
        p_is_company,
        NULLIF(TRIM(p_registration_number), ''),
        NULLIF(TRIM(p_vat_number), ''),
        p_credit_limit,
        p_payment_terms,
        'active',
        v_created_by,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_customer_id;
    
    -- Set customer_code: use provided code or default to ID
    IF p_customer_code IS NOT NULL AND TRIM(p_customer_code) != '' THEN
        v_customer_code := TRIM(p_customer_code);
    ELSE
        v_customer_code := v_customer_id::VARCHAR(20);
    END IF;
    
    -- Update the customer record with the final customer_code
    UPDATE core.customers 
    SET customer_code = v_customer_code 
    WHERE id = v_customer_id;
    
    -- =============================================================================
    -- CREATE PRIMARY CONTACT
    -- =============================================================================
    
    INSERT INTO core.contacts (
        customer_id,
        first_name,
        last_name,
        job_title,
        department,
        email,
        phone_number,
        whatsapp_number,
        is_primary_contact,
        is_billing_contact,
        status,
        created_at,
        updated_at
    ) VALUES (
        v_customer_id,
        TRIM(p_contact_first_name),
        TRIM(p_contact_last_name),
        NULLIF(TRIM(p_contact_job_title), ''),
        NULLIF(TRIM(p_contact_department), ''),
        LOWER(TRIM(p_contact_email)),
        NULLIF(TRIM(p_contact_phone), ''),
        NULLIF(TRIM(p_contact_whatsapp), ''),
        true,  -- Primary contact
        p_is_billing_contact,
        'active',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_contact_id;
    
    -- =============================================================================
    -- CREATE SITE (IF ADDRESS PROVIDED)
    -- =============================================================================
    
    IF p_address_line1 IS NOT NULL AND TRIM(p_address_line1) != '' 
       AND p_city IS NOT NULL AND TRIM(p_city) != '' THEN
        
        INSERT INTO core.sites (
            customer_id,
            site_code,
            site_name,
            site_type,
            address_line1,
            address_line2,
            city,
            province,
            postal_code,
            country,
            site_contact_name,
            site_contact_phone,
            delivery_instructions,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            v_customer_id,
            v_customer_code || '-01',  -- First site
            COALESCE(NULLIF(TRIM(p_site_name), ''), 
                    TRIM(p_customer_name) || ' - Main ' || 
                    CASE p_site_type 
                        WHEN 'delivery_site' THEN 'Delivery'
                        WHEN 'billing_address' THEN 'Billing'
                        WHEN 'head_office' THEN 'Office'
                        WHEN 'branch' THEN 'Branch'
                        WHEN 'warehouse' THEN 'Warehouse'
                        WHEN 'project_site' THEN 'Project'
                        ELSE 'Site'
                    END),
            p_site_type,
            TRIM(p_address_line1),
            NULLIF(TRIM(p_address_line2), ''),
            TRIM(p_city),
            NULLIF(TRIM(p_province), ''),
            NULLIF(TRIM(p_postal_code), ''),
            p_country,
            TRIM(p_contact_first_name) || ' ' || TRIM(p_contact_last_name),
            NULLIF(TRIM(p_contact_phone), ''),
            NULLIF(TRIM(p_delivery_instructions), ''),
            true,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        ) RETURNING id INTO v_site_id;
    END IF;
    
    -- =============================================================================
    -- AUDIT LOGGING
    -- =============================================================================
    
    -- Log customer creation
    INSERT INTO security.audit_log (
        employee_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        created_at
    ) VALUES (
        v_created_by,
        'create_customer',
        'customers',
        v_customer_id,
        jsonb_build_object(
            'customer_code', v_customer_code,
            'customer_name', p_customer_name,
            'is_company', p_is_company,
            'created_by_name', v_employee_name
        ),
        inet_client_addr(),
        CURRENT_TIMESTAMP
    );
    
    -- Log contact creation
    INSERT INTO security.audit_log (
        employee_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        created_at
    ) VALUES (
        v_created_by,
        'create_contact',
        'contacts',
        v_contact_id,
        jsonb_build_object(
            'customer_id', v_customer_id,
            'customer_code', v_customer_code,
            'contact_name', p_contact_first_name || ' ' || p_contact_last_name,
            'email', p_contact_email,
            'is_primary', true
        ),
        inet_client_addr(),
        CURRENT_TIMESTAMP
    );
    
    -- Log site creation (if created)
    IF v_site_id IS NOT NULL THEN
        INSERT INTO security.audit_log (
            employee_id,
            action,
            table_name,
            record_id,
            new_values,
            ip_address,
            created_at
        ) VALUES (
            v_created_by,
            'create_site',
            'sites',
            v_site_id,
            jsonb_build_object(
                'customer_id', v_customer_id,
                'customer_code', v_customer_code,
                'site_type', p_site_type,
                'city', p_city
            ),
            inet_client_addr(),
            CURRENT_TIMESTAMP
        );
    END IF;
    
    -- =============================================================================
    -- RETURN SUCCESS
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Customer "' || p_customer_name || '" created successfully with ID ' || v_customer_id || ' and code ' || v_customer_code)::TEXT,
        v_customer_id,
        v_customer_code,
        v_contact_id,
        v_site_id,
        '{}'::TEXT[];  -- Empty validation errors array
        
EXCEPTION 
    WHEN unique_violation THEN
        -- Handle any unique constraint violations
        RETURN QUERY SELECT 
            false, 
            'Duplicate data detected. Please check customer name, email, or other unique fields.'::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::INTEGER,
            ARRAY['Duplicate data violation - customer may already exist']::TEXT[];
            
    WHEN OTHERS THEN
        -- Handle any other errors
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::INTEGER,
            ARRAY['Internal system error: ' || SQLERRM]::TEXT[];
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
-- These would be set in the permissions script, but documented here:
-- GRANT EXECUTE ON FUNCTION core.create_new_customer TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.create_new_customer TO manager;
-- GRANT EXECUTE ON FUNCTION core.create_new_customer TO owner;

COMMENT ON FUNCTION core.create_new_customer IS 
'Complete customer registration procedure for Flask frontend.
Creates customer, primary contact, and optional site records with full validation and audit trail.
Designed for data entry forms with comprehensive error handling and validation.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Company with custom customer code
SELECT * FROM core.create_new_customer(
    'Tech Solutions Ltd',                    -- p_customer_name
    'Sarah',                                 -- p_contact_first_name  
    'Williams',                              -- p_contact_last_name
    'sarah@techsolutions.co.za',            -- p_contact_email
    'TECH001'                               -- p_customer_code (custom)
);

-- Example 2: Individual customer, code will default to ID
SELECT * FROM core.create_new_customer(
    'John Smith',              -- p_customer_name
    'John',                    -- p_contact_first_name
    'Smith',                   -- p_contact_last_name
    'john.smith@email.com'     -- p_contact_email
    -- p_customer_code defaults to NULL, so will use ID
);

-- Example 3: Company, let code default to ID with additional details
SELECT * FROM core.create_new_customer(
    'ABC Manufacturing',       -- p_customer_name
    'Mike',                    -- p_contact_first_name
    'Johnson',                 -- p_contact_last_name
    'mike@abcmfg.co.za',      -- p_contact_email
    NULL,                      -- p_customer_code (will use ID)
    true,                      -- p_is_company
    '2023/654321/07',         -- p_registration_number
    '9876543210',             -- p_vat_number
    25000.00                  -- p_credit_limit
);
*/

/*
# Example Flask integration
result = db.execute("""
    SELECT * FROM core.create_new_customer(
        p_customer_name := %s,
        p_is_company := %s,
        p_contact_first_name := %s,
        p_contact_last_name := %s,
        p_contact_email := %s,
        p_contact_phone := %s,
        p_address_line1 := %s,
        p_city := %s,
        p_session_token := %s
    )
""", [customer_name, is_company, first_name, last_name, email, phone, address, city, session_token])

success, message, customer_id, customer_code, contact_id, site_id, validation_errors = result.fetchone()
*/