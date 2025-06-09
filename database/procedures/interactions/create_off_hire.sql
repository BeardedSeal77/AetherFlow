-- =============================================================================
-- INTERACTIONS: IMPROVED EQUIPMENT OFF-HIRE/COLLECTION PROCESSING
-- =============================================================================
-- Purpose: Process equipment off-hire/collection requests from customers
-- Creates off-hire interaction with equipment list and collection details
-- Creates driver task for equipment collection using helper functions
-- Simplified and optimized version using helper functions
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_off_hire;

-- Create the improved off-hire processing procedure
CREATE OR REPLACE FUNCTION interactions.create_off_hire(
    -- Required off-hire details
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_list JSONB,         -- [{"equipment_category_id": 5, "quantity": 2, "special_requirements": "..."}]
    p_collect_date DATE,
    p_priority VARCHAR(20) DEFAULT 'medium',  -- Employee selects priority
    
    -- Optional collection details
    p_collect_time TIME DEFAULT '14:00'::TIME,
    p_end_date DATE DEFAULT NULL,
    p_end_time TIME DEFAULT NULL,
    p_collection_method VARCHAR(50) DEFAULT 'collect',
    p_early_return BOOLEAN DEFAULT false,
    p_special_instructions TEXT DEFAULT NULL,
    p_contact_method VARCHAR(50) DEFAULT 'phone',
    p_initial_notes TEXT DEFAULT NULL,
    
    -- System details
    p_employee_id INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    offhire_component_id INTEGER,
    driver_task_id INTEGER,
    assigned_driver TEXT,
    collection_date DATE,
    estimated_collection_time TIME,
    equipment_count INTEGER,
    total_quantity INTEGER
) AS $OFF_HIRE$
DECLARE
    v_interaction_id INTEGER;
    v_offhire_component_id INTEGER;
    v_driver_task_id INTEGER;
    v_reference_number VARCHAR(20);
    v_employee_id INTEGER;
    v_employee_name TEXT;
    v_customer_name TEXT;
    v_contact_name TEXT;
    v_site_name TEXT;
    v_site_address TEXT;
    v_driver_employee_name TEXT;
    v_equipment_summary TEXT;
    v_validation_errors TEXT[] := '{}';
    v_equipment_item JSONB;
    v_equipment_count INTEGER := 0;
    v_total_quantity INTEGER := 0;
    
    -- Task scheduling variables
    v_estimated_duration INTEGER := 60; -- 1 hour default (shorter than delivery)
    v_scheduled_date DATE;
    v_scheduled_time TIME;
BEGIN
    -- =============================================================================
    -- AUTHENTICATION & AUTHORIZATION (simplified)
    -- =============================================================================
    
    -- Get employee ID (simplified authentication)
    v_employee_id := COALESCE(
        p_employee_id, 
        NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER
    );
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Get employee details
    SELECT e.name || ' ' || e.surname INTO v_employee_name
    FROM core.employees e WHERE e.id = v_employee_id;
    
    -- =============================================================================
    -- VALIDATION (simplified using helper pattern)
    -- =============================================================================
    
    -- Validate customer, contact, and site in one query
    SELECT 
        c.company_name,
        ct.name || ' ' || ct.surname,
        s.site_name,
        s.address
    INTO v_customer_name, v_contact_name, v_site_name, v_site_address
    FROM core.customers c
    JOIN core.contacts ct ON ct.id = p_contact_id AND ct.customer_id = c.id
    JOIN core.sites s ON s.id = p_site_id AND s.customer_id = c.id
    WHERE c.id = p_customer_id;
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT false, 
            'Invalid customer, contact, or site data. Please verify selections.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Quick validation checks
    IF jsonb_array_length(p_equipment_list) = 0 THEN
        v_validation_errors := v_validation_errors || 'Equipment list cannot be empty';
    END IF;
    
    IF p_collect_date < CURRENT_DATE THEN
        v_validation_errors := v_validation_errors || 'Collection date cannot be in the past';
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 
            ('Validation errors: ' || array_to_string(v_validation_errors, '; '))::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- BUILD EQUIPMENT SUMMARY AND COUNT (simplified)
    -- =============================================================================
    
    v_equipment_summary := '';
    
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        v_equipment_count := v_equipment_count + 1;
        v_total_quantity := v_total_quantity + (v_equipment_item->>'quantity')::INTEGER;
        
        -- Build summary efficiently
        SELECT category_name INTO v_equipment_summary
        FROM core.equipment_categories 
        WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER;
        
        v_equipment_summary := COALESCE(v_equipment_summary, '') || 
            CASE WHEN v_equipment_summary != '' THEN ', ' ELSE '' END ||
            v_equipment_summary || ' x' || (v_equipment_item->>'quantity');
    END LOOP;
    
    -- =============================================================================
    -- TASK SCHEDULING (simplified)
    -- =============================================================================
    
    -- Adjust duration for large collections
    IF v_total_quantity > 5 THEN
        v_estimated_duration := v_estimated_duration + 20;
    END IF;
    
    v_scheduled_date := p_collect_date;
    v_scheduled_time := p_collect_time;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER
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
        'pending',
        v_reference_number,
        p_contact_method,
        COALESCE(p_initial_notes, 'Equipment collection requested from ' || v_site_name || 
                 ' on ' || p_collect_date || 
                 CASE WHEN p_early_return THEN ' (Early return)' ELSE '' END),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_interaction_id;
    
    -- =============================================================================
    -- CREATE EQUIPMENT LIST COMPONENT (Layer 2) - simplified
    -- =============================================================================
    
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
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
            'COLLECTION: ' || COALESCE(v_equipment_item->>'special_requirements', 'Standard collection'),
            CURRENT_TIMESTAMP
        );
    END LOOP;
    
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
        special_instructions,
        created_at
    ) VALUES (
        v_interaction_id,
        p_site_id,
        p_collect_date,
        p_collect_time,
        p_end_date,
        p_end_time,
        p_collection_method,
        p_early_return,
        p_special_instructions,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_offhire_component_id;
    
    -- =============================================================================
    -- CREATE DRIVER TASK USING HELPER FUNCTION (Layer 3)
    -- =============================================================================
    
    SELECT task_id, assigned_driver_name 
    INTO v_driver_task_id, v_driver_employee_name
    FROM tasks.create_driver_task(
        v_interaction_id,
        'collection',
        p_priority,
        v_customer_name,
        v_contact_name,
        (SELECT phone_number FROM core.contacts WHERE id = p_contact_id),
        v_site_address,
        v_equipment_summary,
        v_scheduled_date,
        v_scheduled_time,
        v_estimated_duration,
        CASE WHEN p_collection_method = 'collect' 
             THEN 'COLLECTION: ' || COALESCE(p_special_instructions, 'Standard collection')
             ELSE 'COUNTER RETURN: Customer returning to depot' END ||
             CASE WHEN p_early_return THEN ' (EARLY RETURN)' ELSE '' END,
        CASE WHEN p_priority IN ('urgent', 'critical') THEN 
             (SELECT driver_id FROM tasks.find_available_driver(v_scheduled_date, p_priority) 
              ORDER BY availability_score DESC LIMIT 1)
             ELSE NULL END,
        v_employee_id
    );
    
    -- =============================================================================
    -- CREATE DRIVER TASK EQUIPMENT ASSIGNMENTS (simplified)
    -- =============================================================================
    
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        INSERT INTO tasks.drivers_task_equipment (
            drivers_task_id,
            equipment_category_id,
            quantity,
            purpose,
            condition_notes,
            created_at
        ) VALUES (
            v_driver_task_id,
            (v_equipment_item->>'equipment_category_id')::INTEGER,
            (v_equipment_item->>'quantity')::INTEGER,
            'collection',
            'FOR COLLECTION: ' ||
            CASE WHEN p_early_return THEN 'Early return - ' ELSE '' END ||
            COALESCE(v_equipment_item->>'special_requirements', 'Check condition on collection'),
            CURRENT_TIMESTAMP
        );
    END LOOP;
    
    -- =============================================================================
    -- AUDIT LOGGING (simplified)
    -- =============================================================================
    
    INSERT INTO security.audit_log (
        employee_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        created_at
    ) VALUES (
        v_employee_id,
        'create_off_hire',
        'interactions',
        v_interaction_id,
        jsonb_build_object(
            'reference_number', v_reference_number,
            'customer_name', v_customer_name,
            'equipment_count', v_equipment_count,
            'total_quantity', v_total_quantity,
            'collection_date', p_collect_date,
            'assigned_driver', v_driver_employee_name,
            'created_by', v_employee_name
        ),
        inet_client_addr(),
        CURRENT_TIMESTAMP
    );
    
    -- =============================================================================
    -- RETURN SUCCESS
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Off-hire ' || v_reference_number || ' created for ' || v_customer_name || '. ' ||
         'Collection scheduled for ' || p_collect_date || ' at ' || p_collect_time || '. ' ||
         CASE WHEN v_driver_employee_name IS NOT NULL
              THEN 'Driver ' || v_driver_employee_name || ' assigned.'
              ELSE 'Collection task created for assignment.'
         END)::TEXT,
        v_interaction_id,
        v_reference_number,
        v_offhire_component_id,
        v_driver_task_id,
        v_driver_employee_name,
        v_scheduled_date,
        v_scheduled_time,
        v_equipment_count,
        v_total_quantity;
        
EXCEPTION 
    WHEN unique_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Duplicate off-hire request detected.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
            
    WHEN foreign_key_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Invalid reference data. Please verify customer, contact, site, and equipment selections.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
            
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
END;
$OFF_HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

COMMENT ON FUNCTION interactions.create_off_hire IS 
'Improved equipment off-hire/collection processing using helper functions.
Creates off-hire interaction with equipment list and collection details.
Uses standardized driver task creation and assignment helpers.
Simplified validation and error handling for better maintainability.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Standard collection using improved procedure
SELECT * FROM interactions.create_off_hire(
    1000,                                   -- p_customer_id (ABC Construction)
    1000,                                   -- p_contact_id (John Guy)
    1001,                                   -- p_site_id (Sandton Project Site)
    '[
        {
            "equipment_category_id": 5,
            "quantity": 1,
            "special_requirements": "Check for damage"
        },
        {
            "equipment_category_id": 8,
            "quantity": 2,
            "special_requirements": "Clean before return"
        }
    ]'::jsonb,                             -- p_equipment_list
    '2025-06-10',                          -- p_collect_date
    'medium',                              -- p_priority
    '13:00'::TIME,                         -- p_collect_time
    '2025-06-10',                          -- p_end_date
    '12:00'::TIME,                         -- p_end_time
    'collect',                             -- p_collection_method
    false,                                 -- p_early_return
    'Equipment ready for collection at main gate.',
    'phone',                               -- p_contact_method
    'Customer called requesting collection - project completed',
    1001                                   -- p_employee_id
);

-- Example 2: Urgent collection with auto driver assignment
SELECT * FROM interactions.create_off_hire(
    1001,                                   -- p_customer_id
    1002,                                   -- p_contact_id
    1002,                                   -- p_site_id
    '[
        {
            "equipment_category_id": 3,
            "quantity": 1,
            "special_requirements": "URGENT: Site closing soon"
        }
    ]'::jsonb,                             -- p_equipment_list
    CURRENT_DATE,                          -- p_collect_date (today - urgent)
    'urgent',                              -- p_priority (auto-assigns driver)
    '15:00'::TIME,                         -- p_collect_time
    CURRENT_DATE,                          -- p_end_date
    '14:30'::TIME,                         -- p_end_time
    'collect',                             -- p_collection_method
    true,                                  -- p_early_return
    'URGENT: Site must be cleared immediately for inspection.',
    'phone',                               -- p_contact_method
    'URGENT COLLECTION: Customer needs immediate pickup',
    1001                                   -- p_employee_id
);
*/