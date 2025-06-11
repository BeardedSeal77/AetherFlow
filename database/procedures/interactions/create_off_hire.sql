-- =============================================================================
-- INTERACTIONS: NORMALIZED EQUIPMENT OFF-HIRE/COLLECTION PROCESSING
-- =============================================================================
-- Purpose: Process equipment off-hire/collection requests using standardized helpers
-- Creates off-hire interaction with equipment list and collection details
-- Uses normalized helper functions for consistency with hire process
-- Updated: 2025-06-11 - Normalized to match create_hire approach
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_off_hire;

-- Create the normalized off-hire processing procedure
CREATE OR REPLACE FUNCTION interactions.create_off_hire(
    -- Required off-hire details (matching hire pattern)
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_list JSONB,         -- [{"equipment_category_id": 5, "quantity": 2}]
    p_hire_end_date DATE,
    p_collection_date DATE,
    
    -- Optional details
    p_collection_time TIME DEFAULT '14:00'::TIME,
    p_notes TEXT DEFAULT NULL,
    p_priority VARCHAR(20) DEFAULT 'medium',
    p_early_return BOOLEAN DEFAULT false,
    
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
) AS $NORMALIZED_OFF_HIRE$
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
    -- AUTHENTICATION USING HELPER FUNCTION (same as hire)
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
    
    IF p_hire_end_date IS NULL OR p_collection_date IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Hire end date and collection date are required');
    END IF;
    
    IF p_collection_date < p_hire_end_date THEN
        v_validation_errors := array_append(v_validation_errors, 'Collection date cannot be before hire end date');
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, array_to_string(v_validation_errors, '; ')::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GET CUSTOMER, CONTACT, AND SITE DETAILS (same as hire)
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
    
    v_reference_number := system.generate_reference_number('off_hire');
    
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
        'off_hire',
        'processing',
        v_reference_number,
        'system',
        p_notes,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_interaction_id;
    
    -- =============================================================================
    -- CREATE OFF-HIRE DETAILS COMPONENT (Layer 2)
    -- =============================================================================
    
    INSERT INTO interactions.component_offhire_details (
        interaction_id,
        site_id,
        collect_date,
        collect_time,
        end_date,
        end_time,
        collection_method,
        early_return,
        condition_notes,
        created_at
    ) VALUES (
        v_interaction_id,
        p_site_id,
        p_collection_date,
        p_collection_time,
        p_hire_end_date,
        p_collection_time, -- Use collection time as end time
        'collect',
        p_early_return,
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
            COALESCE(v_equipment_item->>'special_requirements', 'COLLECTION: Standard equipment return'),
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
        'collection',                       -- task_type (different from hire)
        p_priority,                         -- priority
        v_customer_name,                    -- customer_name
        v_contact_name,                     -- contact_name
        v_contact_phone,                    -- contact_phone
        v_site_address,                     -- site_address
        v_equipment_summary,                -- equipment_summary
        p_collection_date,                  -- scheduled_date
        p_collection_time,                  -- scheduled_time
        60,                                 -- estimated_duration (60 minutes - shorter than delivery)
        CASE WHEN p_early_return THEN 'EARLY RETURN: ' || COALESCE(p_notes, 'Equipment return ahead of schedule')
             ELSE p_notes END,              -- special_instructions
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
        ('Off-hire request processed successfully. Reference: ' || v_reference_number || 
         '. Equipment: ' || v_equipment_count || ' items (' || v_total_quantity || ' total quantity). ' ||
         'Driver task created for collection on ' || p_collection_date || 
         ' at ' || p_collection_time || 
         CASE WHEN p_early_return THEN ' (Early return)' ELSE '' END || '.')::TEXT,
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
            'Duplicate off-hire request detected. Reference number already exists.'::TEXT,
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
$NORMALIZED_OFF_HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION interactions.create_off_hire TO PUBLIC;

COMMENT ON FUNCTION interactions.create_off_hire IS 
'Normalized equipment off-hire/collection processing procedure using standardized helper functions.
Creates off-hire interaction with equipment list and collection details.
Uses same helper pattern as create_hire for consistency: security.validate_session(),
system.generate_reference_number(), and tasks.create_driver_task().
Handles early returns and equipment condition documentation.
Reference prefix: OH (Off-Hire), task type: collection.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Standard off-hire request
SELECT * FROM interactions.create_off_hire(
    1000,                                   -- customer_id
    1000,                                   -- contact_id  
    1001,                                   -- site_id
    '[
        {
            "equipment_category_id": 5,
            "quantity": 1,
            "special_requirements": "Check for any damage"
        },
        {
            "equipment_category_id": 8,
            "quantity": 2,
            "special_requirements": "Clean before return"
        }
    ]'::jsonb,                             -- equipment_list
    '2025-06-15',                          -- hire_end_date
    '2025-06-15',                          -- collection_date
    '14:00'::TIME,                         -- collection_time
    'Equipment ready at main gate',        -- notes
    'medium',                              -- priority
    false,                                 -- early_return
    1001,                                  -- employee_id
    NULL                                   -- session_token
);

-- Example 2: Urgent early return
SELECT * FROM interactions.create_off_hire(
    1001,                                   -- customer_id
    1002,                                   -- contact_id
    1002,                                   -- site_id
    '[
        {
            "equipment_category_id": 3,
            "quantity": 1,
            "special_requirements": "Project completed early"
        }
    ]'::jsonb,                             -- equipment_list
    '2025-06-20',                          -- hire_end_date (originally scheduled)
    CURRENT_DATE,                          -- collection_date (today - early)
    '10:00'::TIME,                         -- collection_time
    'Project finished ahead of schedule',   -- notes
    'high',                                -- priority
    true,                                  -- early_return
    NULL,                                  -- employee_id (using session)
    'session_token_here'                   -- session_token
);
*/