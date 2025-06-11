-- =============================================================================
-- INTERACTIONS: NORMALIZED EQUIPMENT HIRE PROCESSING 
-- =============================================================================
-- Purpose: Process equipment hire requests using standardized helper functions
-- Creates hire interaction with equipment list and delivery details
-- Uses normalized helper functions for consistency and maintainability
-- Updated: 2025-06-11 - Normalized to use helper functions
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_hire;

-- Create the normalized hire processing procedure
CREATE OR REPLACE FUNCTION interactions.create_hire(
    -- Required hire details (simplified per documentation)
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_list JSONB,         -- [{"equipment_category_id": 5, "quantity": 2}]
    p_hire_start_date DATE,
    p_delivery_date DATE,
    
    -- Optional details
    p_delivery_time TIME DEFAULT '09:00'::TIME,
    p_notes TEXT DEFAULT NULL,
    p_priority VARCHAR(20) DEFAULT 'medium',
    
    -- System details
    p_employee_id INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    driver_task_id INTEGER,
    assigned_driver_name TEXT,
    equipment_count INTEGER,
    total_quantity INTEGER
) AS $NORMALIZED_HIRE$
DECLARE
    v_interaction_id INTEGER;
    v_driver_task_id INTEGER;
    v_assigned_driver_name TEXT;
    v_reference_number VARCHAR(20);
    v_employee_id INTEGER;
    v_customer_name TEXT;
    v_contact_name TEXT;
    v_contact_phone TEXT;
    v_site_address TEXT;
    v_equipment_summary TEXT;
    v_validation_errors TEXT[] := '{}';
    v_equipment_item JSONB;
    v_equipment_count INTEGER := 0;
    v_total_quantity INTEGER := 0;
    v_task_status VARCHAR(50);
    
BEGIN
    -- =============================================================================
    -- AUTHENTICATION USING HELPER FUNCTION
    -- =============================================================================
    
    -- Use security helper for session validation if token provided
    IF p_session_token IS NOT NULL THEN
        SELECT valid, employee_id INTO v_employee_id, v_employee_id
        FROM security.validate_session(p_session_token);
        
        IF v_employee_id IS NULL THEN
            RETURN QUERY SELECT false, 'Invalid or expired session token'::TEXT, 
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            RETURN;
        END IF;
    ELSE
        v_employee_id := p_employee_id;
    END IF;
    
    -- Basic authentication check
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- INPUT VALIDATION
    -- =============================================================================
    
    -- Required field validation
    IF p_customer_id IS NULL OR p_contact_id IS NULL OR p_site_id IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer, contact, and site are required');
    END IF;
    
    IF p_equipment_list IS NULL OR jsonb_array_length(p_equipment_list) = 0 THEN
        v_validation_errors := array_append(v_validation_errors, 'At least one equipment item is required');
    END IF;
    
    IF p_hire_start_date IS NULL OR p_delivery_date IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Hire start date and delivery date are required');
    END IF;
    
    IF p_delivery_date < p_hire_start_date THEN
        v_validation_errors := array_append(v_validation_errors, 'Delivery date cannot be before hire start date');
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, array_to_string(v_validation_errors, '; ')::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GET CUSTOMER, CONTACT, AND SITE DETAILS
    -- =============================================================================
    
    -- Get customer details
    SELECT customer_name INTO v_customer_name
    FROM core.customers
    WHERE id = p_customer_id AND status = 'active';
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT false, 'Customer not found or inactive'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Get contact details
    SELECT first_name || ' ' || last_name, phone_number
    INTO v_contact_name, v_contact_phone
    FROM core.contacts
    WHERE id = p_contact_id AND customer_id = p_customer_id AND status = 'active';
    
    IF v_contact_name IS NULL THEN
        RETURN QUERY SELECT false, 'Contact not found or not associated with customer'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Get site details with proper address formatting
    SELECT site_name,
           TRIM(COALESCE(address_line1, '') || 
               CASE WHEN address_line2 IS NOT NULL AND TRIM(address_line2) != '' 
                    THEN ', ' || address_line2 ELSE '' END ||
               CASE WHEN city IS NOT NULL AND TRIM(city) != '' 
                    THEN ', ' || city ELSE '' END)
    INTO v_site_address, v_site_address
    FROM core.sites
    WHERE id = p_site_id AND customer_id = p_customer_id AND status = 'active';
    
    IF v_site_address IS NULL THEN
        RETURN QUERY SELECT false, 'Site not found or not associated with customer'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER USING HELPER
    -- =============================================================================
    
    v_reference_number := system.generate_reference_number('hire');
    
    -- =============================================================================
    -- CREATE INTERACTION RECORD (Layer 1)
    -- =============================================================================
    
    INSERT INTO interactions.interactions (
        customer_id, 
        contact_id, 
        employee_id, 
        interaction_type,
        status, 
        reference_number, 
        contact_method, 
        notes,
        created_at,
        updated_at
    ) VALUES (
        p_customer_id,
        p_contact_id,
        v_employee_id,
        'hire',
        'processing',
        v_reference_number,
        'system',
        p_notes,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_interaction_id;
    
    -- =============================================================================
    -- CREATE HIRE DETAILS COMPONENT (Layer 2)
    -- =============================================================================
    
    INSERT INTO interactions.component_hire_details (
        interaction_id,
        site_id,
        deliver_date,
        deliver_time,
        start_date,
        start_time,
        delivery_method,
        special_instructions,
        created_at
    ) VALUES (
        v_interaction_id,
        p_site_id,
        p_delivery_date,
        p_delivery_time,
        p_hire_start_date,
        p_delivery_time, -- Use delivery time as start time
        'deliver',
        p_notes,
        CURRENT_TIMESTAMP
    );
    
    -- =============================================================================
    -- CREATE EQUIPMENT LIST COMPONENT (Layer 2)
    -- =============================================================================
    
    -- Process equipment items and build summary
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        -- Insert equipment item
        INSERT INTO interactions.component_equipment_list (
            interaction_id,
            equipment_category_id,
            quantity,
            special_requirements,
            created_at
        ) VALUES (
            v_interaction_id,
            (v_equipment_item->>'equipment_category_id')::INTEGER,
            (v_equipment_item->>'quantity')::INTEGER,
            v_equipment_item->>'special_requirements',
            CURRENT_TIMESTAMP
        );
        
        -- Update counters
        v_equipment_count := v_equipment_count + 1;
        v_total_quantity := v_total_quantity + (v_equipment_item->>'quantity')::INTEGER;
    END LOOP;
    
    -- Build equipment summary for driver task
    SELECT string_agg(ec.category_name || ' (x' || el.quantity || ')', ', ')
    INTO v_equipment_summary
    FROM interactions.component_equipment_list el
    JOIN core.equipment_categories ec ON ec.id = el.equipment_category_id
    WHERE el.interaction_id = v_interaction_id;
    
    -- =============================================================================
    -- CREATE DRIVER TASK USING NORMALIZED HELPER (Layer 3)
    -- =============================================================================
    
    SELECT task_id, assigned_driver_name, task_status
    INTO v_driver_task_id, v_assigned_driver_name, v_task_status
    FROM tasks.create_driver_task(
        v_interaction_id,                   -- interaction_id
        'delivery',                         -- task_type
        p_priority,                         -- priority
        v_customer_name,                    -- customer_name
        v_contact_name,                     -- contact_name
        v_contact_phone,                    -- contact_phone
        v_site_address,                     -- site_address
        v_equipment_summary,                -- equipment_summary
        p_delivery_date,                    -- scheduled_date
        p_delivery_time,                    -- scheduled_time
        90,                                 -- estimated_duration (90 minutes)
        p_notes,                           -- special_instructions
        NULL,                              -- assigned_to (no driver assigned initially)
        v_employee_id                      -- created_by
    );
    
    -- =============================================================================
    -- UPDATE INTERACTION STATUS
    -- =============================================================================
    
    UPDATE interactions.interactions 
    SET status = 'active', updated_at = CURRENT_TIMESTAMP
    WHERE id = v_interaction_id;
    
    -- =============================================================================
    -- RETURN SUCCESS RESULT
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Hire request processed successfully. Reference: ' || v_reference_number || 
         '. Equipment: ' || v_equipment_count || ' items (' || v_total_quantity || ' total quantity). ' ||
         'Driver task created for delivery on ' || p_delivery_date || 
         ' at ' || p_delivery_time || '.')::TEXT,
        v_interaction_id,
        v_reference_number,
        v_driver_task_id,
        COALESCE(v_assigned_driver_name, 'Unassigned'),
        v_equipment_count,
        v_total_quantity;
        
EXCEPTION 
    WHEN unique_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Duplicate hire request detected. Reference number already exists.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            
    WHEN foreign_key_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Invalid reference data. Please verify customer, contact, site, and equipment selections.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
END;
$NORMALIZED_HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION interactions.create_hire TO PUBLIC;

COMMENT ON FUNCTION interactions.create_hire IS 
'Normalized equipment hire processing procedure using standardized helper functions.
Creates hire interaction with equipment list and delivery details.
Uses security.validate_session() for authentication, system.generate_reference_number() for references,
and tasks.create_driver_task() for driver task creation.
Simplified and consistent with hire_process.txt documentation.
Follows normalized approach for maintainability and consistency across procedures.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Standard hire request
SELECT * FROM interactions.create_hire(
    1000,                                   -- customer_id
    1000,                                   -- contact_id  
    1001,                                   -- site_id
    '[
        {
            "equipment_category_id": 5,
            "quantity": 1,
            "special_requirements": "Good working condition required"
        },
        {
            "equipment_category_id": 8,
            "quantity": 2,
            "special_requirements": null
        }
    ]'::jsonb,                             -- equipment_list
    '2025-06-12',                          -- hire_start_date
    '2025-06-12',                          -- delivery_date
    '09:00'::TIME,                         -- delivery_time
    'Please deliver to main gate',         -- notes
    'medium',                              -- priority
    1001,                                  -- employee_id
    NULL                                   -- session_token
);

-- Example 2: Urgent hire with session token
SELECT * FROM interactions.create_hire(
    1001,                                   -- customer_id
    1002,                                   -- contact_id
    1002,                                   -- site_id
    '[
        {
            "equipment_category_id": 3,
            "quantity": 1,
            "special_requirements": "URGENT: Needed immediately"
        }
    ]'::jsonb,                             -- equipment_list
    CURRENT_DATE,                          -- hire_start_date (today)
    CURRENT_DATE,                          -- delivery_date (today)
    '14:00'::TIME,                         -- delivery_time
    'URGENT delivery required',            -- notes
    'urgent',                              -- priority (will auto-assign driver)
    NULL,                                  -- employee_id (using session)
    'session_token_here'                   -- session_token
);
*/