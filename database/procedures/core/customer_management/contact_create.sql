-- =============================================================================
-- CUSTOMER MANAGEMENT: Add new contact to existing customer
-- =============================================================================
-- Purpose: Add new contact to existing customer
-- Dependencies: core.contacts table
-- Used by: Contact management workflow
-- Function: core.create_new_contact
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.create_new_contact;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.create_new_contact(
    -- Required fields
    p_customer_id INTEGER,
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_email VARCHAR(255),
    
    -- Optional contact details (all with defaults)
    p_job_title VARCHAR(100) DEFAULT NULL,
    p_department VARCHAR(100) DEFAULT NULL,
    p_phone_number VARCHAR(20) DEFAULT NULL,
    p_whatsapp_number VARCHAR(20) DEFAULT NULL,
    p_is_primary_contact BOOLEAN DEFAULT false,
    p_is_billing_contact BOOLEAN DEFAULT false,
    
    -- Optional system details (all with defaults)
    p_created_by INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    contact_id INTEGER,
    customer_name TEXT,
    customer_code VARCHAR(20),
    validation_errors TEXT[]
) AS $$
DECLARE
    v_contact_id INTEGER;
    v_created_by INTEGER;
    v_employee_name TEXT;
    v_customer_name TEXT;
    v_customer_code VARCHAR(20);
    v_customer_status VARCHAR(20);
    v_validation_errors TEXT[] := '{}';
    v_existing_email INTEGER;
    v_existing_primary INTEGER;
    v_existing_billing INTEGER;
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
                NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20), 
                ARRAY['Invalid session token']::TEXT[];
            RETURN;
        END IF;
    ELSE
        v_created_by := COALESCE(p_created_by, 
            NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER);
    END IF;
    
    IF v_created_by IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20), 
            ARRAY['No authenticated employee found']::TEXT[];
        RETURN;
    END IF;
    
    -- Get employee details for logging
    SELECT e.name || ' ' || e.surname INTO v_employee_name
    FROM core.employees e
    WHERE e.id = v_created_by AND e.status = 'active';
    
    IF v_employee_name IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not found or inactive'::TEXT, 
            NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20), 
            ARRAY['Employee not found or inactive']::TEXT[];
        RETURN;
    END IF;
    
    -- =============================================================================
    -- INPUT VALIDATION
    -- =============================================================================
    
    -- Required field validation
    IF p_customer_id IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer ID is required');
    END IF;
    
    IF p_first_name IS NULL OR TRIM(p_first_name) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'First name is required');
    END IF;
    
    IF p_last_name IS NULL OR TRIM(p_last_name) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Last name is required');
    END IF;
    
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Email is required');
    ELSIF p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        v_validation_errors := array_append(v_validation_errors, 'Email format is invalid');
    END IF;
    
    -- Name length validation
    IF LENGTH(TRIM(p_first_name)) < 1 THEN
        v_validation_errors := array_append(v_validation_errors, 'First name must be at least 1 character');
    END IF;
    
    IF LENGTH(TRIM(p_last_name)) < 1 THEN
        v_validation_errors := array_append(v_validation_errors, 'Last name must be at least 1 character');
    END IF;
    
    -- =============================================================================
    -- CUSTOMER VALIDATION (using helper function)
    -- =============================================================================
    
    -- Use the customer lookup helper function
    SELECT customer_name, customer_code, status 
    INTO v_customer_name, v_customer_code, v_customer_status
    FROM core.get_customer_by_id(p_customer_id);
    
    IF v_customer_name IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer not found');
    ELSIF v_customer_status != 'active' THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer is not active');
    END IF;
    
    -- =============================================================================
    -- DUPLICATE DETECTION (using search procedure)
    -- =============================================================================
    
    -- Use the duplicate detection function to check for conflicts
    -- This replaces all the manual duplicate checking logic
    DECLARE
        duplicate_check RECORD;
        duplicate_found BOOLEAN := false;
    BEGIN
        -- Check for duplicates using the dedicated function
        FOR duplicate_check IN 
            SELECT * FROM core.detect_duplicate_contacts(
                p_email, 
                p_phone_number, 
                p_first_name, 
                p_last_name
            )
        LOOP
            -- If we find exact matches (high confidence), it's an error
            IF duplicate_check.confidence_score >= 90 THEN
                IF duplicate_check.confidence_score = 100 THEN
                    v_validation_errors := array_append(v_validation_errors, 
                        'Email already exists: ' || duplicate_check.full_name || ' at ' || duplicate_check.customer_name);
                ELSE
                    v_validation_errors := array_append(v_validation_errors, 
                        'Phone number already exists: ' || duplicate_check.full_name || ' at ' || duplicate_check.customer_name);
                END IF;
                duplicate_found := true;
            END IF;
        END LOOP;
    END;
    
    -- Check primary/billing contact conflicts within the customer
    IF p_is_primary_contact THEN
        SELECT id INTO v_existing_primary
        FROM core.contacts
        WHERE customer_id = p_customer_id
        AND is_primary_contact = true
        AND status = 'active'
        LIMIT 1;
        
        IF v_existing_primary IS NOT NULL THEN
            v_validation_errors := array_append(v_validation_errors, 'Customer already has a primary contact. Set existing primary to false first.');
        END IF;
    END IF;
    
    IF p_is_billing_contact THEN
        SELECT id INTO v_existing_billing
        FROM core.contacts
        WHERE customer_id = p_customer_id
        AND is_billing_contact = true
        AND status = 'active'
        LIMIT 1;
        
        IF v_existing_billing IS NOT NULL THEN
            v_validation_errors := array_append(v_validation_errors, 'Customer already has a billing contact. Set existing billing contact to false first.');
        END IF;
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Validation failed'::TEXT, 
            NULL::INTEGER, v_customer_name, v_customer_code, 
            v_validation_errors;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- CREATE CONTACT RECORD
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
        p_customer_id,
        TRIM(p_first_name),
        TRIM(p_last_name),
        NULLIF(TRIM(p_job_title), ''),
        NULLIF(TRIM(p_department), ''),
        LOWER(TRIM(p_email)),
        NULLIF(TRIM(p_phone_number), ''),
        NULLIF(TRIM(p_whatsapp_number), ''),
        p_is_primary_contact,
        p_is_billing_contact,
        'active',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_contact_id;
    
    -- =============================================================================
    -- AUDIT LOGGING
    -- =============================================================================
    
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
            'customer_id', p_customer_id,
            'customer_name', v_customer_name,
            'customer_code', v_customer_code,
            'contact_name', p_first_name || ' ' || p_last_name,
            'email', p_email,
            'is_primary', p_is_primary_contact,
            'is_billing', p_is_billing_contact,
            'created_by_name', v_employee_name
        ),
        inet_client_addr(),
        CURRENT_TIMESTAMP
    );
    
    -- =============================================================================
    -- RETURN SUCCESS
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Contact "' || p_first_name || ' ' || p_last_name || '" added to customer "' || v_customer_name || '"')::TEXT,
        v_contact_id,
        v_customer_name,
        v_customer_code,
        '{}'::TEXT[];  -- Empty validation errors array
        
EXCEPTION 
    WHEN unique_violation THEN
        -- Handle any unique constraint violations
        RETURN QUERY SELECT 
            false, 
            'Duplicate data detected. Contact may already exist.'::TEXT,
            NULL::INTEGER,
            v_customer_name,
            v_customer_code,
            ARRAY['Duplicate data violation - contact may already exist']::TEXT[];
            
    WHEN foreign_key_violation THEN
        -- Handle foreign key violations (invalid customer_id)
        RETURN QUERY SELECT 
            false, 
            'Invalid customer reference.'::TEXT,
            NULL::INTEGER,
            NULL::TEXT,
            NULL::VARCHAR(20),
            ARRAY['Invalid customer ID']::TEXT[];
            
    WHEN OTHERS THEN
        -- Handle any other errors
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER,
            v_customer_name,
            v_customer_code,
            ARRAY['Internal system error: ' || SQLERRM]::TEXT[];
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Set appropriate permissions based on function purpose
-- GRANT EXECUTE ON FUNCTION core.create_new_contact TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.create_new_contact TO manager;
-- GRANT EXECUTE ON FUNCTION core.create_new_contact TO owner;

COMMENT ON FUNCTION core.create_new_contact IS 
'Add new contact to existing customer. Used by Contact management workflow.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.create_new_contact(parameter1, parameter2);

-- Additional examples based on function purpose...
*/
