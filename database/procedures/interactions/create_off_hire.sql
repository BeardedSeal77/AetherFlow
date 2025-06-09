-- =============================================================================
-- INTERACTIONS: Process equipment off-hire/collection requests
-- =============================================================================
-- Purpose: Process equipment off-hire/collection requests
-- Dependencies: interactions.component_offhire_details, tasks.drivers_taskboard
-- Used by: Equipment return workflow, collection scheduling
-- Function: interactions.create_off_hire
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_off_hire;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

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
    v_driver_employee_id INTEGER;
    v_driver_employee_name TEXT;
    v_task_title TEXT;
    v_task_description TEXT;
    v_equipment_summary TEXT;
    v_validation_errors TEXT[] := '{}';
    v_equipment_item JSONB;
    v_equipment_count INTEGER := 0;
    v_total_quantity INTEGER := 0;
    
    -- Task scheduling variables
    v_task_priority VARCHAR(20);
    v_estimated_duration INTEGER := 60; -- 1 hour default (shorter than delivery)
    v_scheduled_date DATE;
    v_scheduled_time TIME;
BEGIN
    -- =============================================================================
    -- AUTHENTICATION & AUTHORIZATION
    -- =============================================================================
    
    -- Get employee ID from session or parameter
    IF p_session_token IS NOT NULL THEN
        SELECT ea.employee_id INTO v_employee_id
        FROM security.employee_auth ea
        WHERE ea.session_token = p_session_token
        AND ea.session_expires > CURRENT_TIMESTAMP;
        
        IF v_employee_id IS NULL THEN
            RETURN QUERY SELECT false, 'Invalid or expired session'::TEXT, 
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
                NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
            RETURN;
        END IF;
    ELSE
        v_employee_id := COALESCE(p_employee_id, 
            NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER);
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Get employee details for logging
    SELECT e.name || ' ' || e.surname INTO v_employee_name
    FROM core.employees e
    WHERE e.id = v_employee_id AND e.status = 'active';
    
    IF v_employee_name IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not found or inactive'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- INPUT VALIDATION
    -- =============================================================================
    
    -- Required field validation
    IF p_customer_id IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer ID is required');
    END IF;
    
    IF p_contact_id IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Contact ID is required');
    END IF;
    
    IF p_site_id IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Site ID is required');
    END IF;
    
    IF p_equipment_list IS NULL OR jsonb_array_length(p_equipment_list) = 0 THEN
        v_validation_errors := array_append(v_validation_errors, 'At least one piece of equipment must be selected for collection');
    END IF;
    
    IF p_collect_date IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Collection date is required');
    END IF;
    
    IF p_collect_date < CURRENT_DATE THEN
        v_validation_errors := array_append(v_validation_errors, 'Collection date cannot be in the past');
    END IF;
    
    -- Validate collection method
    IF p_collection_method NOT IN ('collect', 'counter_return') THEN
        v_validation_errors := array_append(v_validation_errors, 'Invalid collection method');
    END IF;
    
    -- Validate priority level
    IF p_priority NOT IN ('low', 'medium', 'high', 'critical') THEN
        v_validation_errors := array_append(v_validation_errors, 'Invalid priority level');
    END IF;
    
    -- Validate contact method
    IF p_contact_method NOT IN ('phone', 'email', 'in_person', 'whatsapp', 'online', 'other') THEN
        v_validation_errors := array_append(v_validation_errors, 'Invalid contact method');
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Validation failed: ' || array_to_string(v_validation_errors, ', ')::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- VALIDATE CUSTOMER, CONTACT, AND SITE
    -- =============================================================================
    
    -- Validate customer, contact, and site
    SELECT c.customer_name, cont.first_name || ' ' || cont.last_name, s.site_name,
           s.address_line1 || ', ' || s.city
    INTO v_customer_name, v_contact_name, v_site_name, v_site_address
    FROM core.customers c
    JOIN core.contacts cont ON c.id = cont.customer_id
    JOIN core.sites s ON c.id = s.customer_id
    WHERE c.id = p_customer_id AND c.status = 'active'
    AND cont.id = p_contact_id AND cont.status = 'active'
    AND s.id = p_site_id AND s.is_active = true;
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT false, 'Customer, contact, or site not found or inactive'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- VALIDATE EQUIPMENT LIST
    -- =============================================================================
    
    -- Validate each equipment item and count them
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        -- Check required fields in equipment item
        IF NOT (v_equipment_item ? 'equipment_category_id') THEN
            v_validation_errors := array_append(v_validation_errors, 'Equipment category ID missing in equipment list');
        END IF;
        
        IF NOT (v_equipment_item ? 'quantity') THEN
            v_validation_errors := array_append(v_validation_errors, 'Quantity missing in equipment list');
        END IF;
        
        -- Validate equipment category exists
        IF NOT EXISTS (
            SELECT 1 FROM core.equipment_categories 
            WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER 
            AND is_active = true
        ) THEN
            v_validation_errors := array_append(v_validation_errors, 
                'Equipment category ' || (v_equipment_item->>'equipment_category_id') || ' not found or inactive');
        END IF;
        
        v_equipment_count := v_equipment_count + 1;
        v_total_quantity := v_total_quantity + (v_equipment_item->>'quantity')::INTEGER;
    END LOOP;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Equipment validation failed: ' || array_to_string(v_validation_errors, ', ')::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- DETERMINE TASK SCHEDULING (separate from priority)
    -- =============================================================================
    
    -- Use the priority provided by employee (not calculated from dates)
    v_task_priority := p_priority;
    
    -- Set estimated duration based on equipment quantity and priority
    -- Collections are generally faster than deliveries
    CASE p_priority
        WHEN 'critical' THEN
            v_estimated_duration := 45;   -- 45 minutes for critical collection
        WHEN 'high' THEN
            v_estimated_duration := 60;   -- 1 hour for high priority
        WHEN 'medium' THEN
            v_estimated_duration := 60;   -- 1 hour standard
        WHEN 'low' THEN
            v_estimated_duration := 90;   -- 1.5 hours for low priority
    END CASE;
    
    -- Adjust duration based on equipment quantity
    IF v_total_quantity > 5 THEN
        v_estimated_duration := v_estimated_duration + 20; -- Extra 20 minutes for large collections
    END IF;
    
    -- Set collection scheduling (times come from employee input)
    v_scheduled_date := p_collect_date;
    v_scheduled_time := p_collect_time;
    
    -- =============================================================================
    -- FIND AVAILABLE DRIVER FOR ASSIGNMENT
    -- =============================================================================
    
    -- Get an available driver for collection
    SELECT id, name || ' ' || surname
    INTO v_driver_employee_id, v_driver_employee_name
    FROM core.employees
    WHERE role = 'driver' AND status = 'active'
    ORDER BY RANDOM()  -- Distribute workload randomly among drivers
    LIMIT 1;
    
    IF v_driver_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'No drivers available for collection assignment'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER
    -- =============================================================================
    
    -- Generate reference number using system function
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
        'pending',  -- Off-hire starts as pending until collection
        v_reference_number,
        p_contact_method,
        COALESCE(p_initial_notes, 'Equipment collection requested from ' || v_site_name || 
                 ' on ' || p_collect_date || 
                 CASE WHEN p_early_return THEN ' (Early return)' ELSE '' END),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_interaction_id;
    
    -- =============================================================================
    -- CREATE EQUIPMENT LIST COMPONENT (Layer 2)
    -- =============================================================================
    
    -- Build equipment summary for display
    v_equipment_summary := '';
    
    -- Insert each equipment item
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
        
        -- Build equipment summary
        SELECT category_name INTO v_equipment_summary
        FROM core.equipment_categories 
        WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER;
        
        v_equipment_summary := v_equipment_summary || 
            CASE WHEN v_equipment_summary != '' THEN ', ' ELSE '' END ||
            v_equipment_summary || ' x' || (v_equipment_item->>'quantity');
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
        condition_notes,
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
    -- CREATE DRIVER TASK FOR COLLECTION (Layer 3)
    -- =============================================================================
    
    -- Build task details
    v_task_title := 'Equipment Collection: ' || v_customer_name || ' - ' || v_site_name;
    v_task_description := 'EQUIPMENT COLLECTION - ' || UPPER(v_task_priority) || ' PRIORITY' || E'\n\n' ||
                          'Customer: ' || v_customer_name || E'\n' ||
                          'Contact: ' || v_contact_name || E'\n' ||
                          'Site: ' || v_site_name || E'\n' ||
                          'Address: ' || v_site_address || E'\n' ||
                          'Collection Date: ' || p_collect_date || E'\n' ||
                          'Collection Time: ' || p_collect_time || E'\n' ||
                          'Method: ' || UPPER(p_collection_method) || E'\n' ||
                          'Equipment: ' || v_equipment_summary || E'\n' ||
                          'Total Items: ' || v_total_quantity || E'\n' ||
                          CASE WHEN p_early_return THEN 'EARLY RETURN: Yes' || E'\n' ELSE '' END ||
                          CASE WHEN p_special_instructions IS NOT NULL 
                               THEN 'Special Instructions: ' || p_special_instructions || E'\n\n' 
                               ELSE E'\n' END ||
                          'Collection Checklist:' || E'\n' ||
                          '- Contact customer before departure' || E'\n' ||
                          '- Arrive at specified site and time' || E'\n' ||
                          '- Check equipment condition before collection' || E'\n' ||
                          '- Document any damage or issues' || E'\n' ||
                          '- Load equipment safely for transport' || E'\n' ||
                          '- Get customer signature on collection note' || E'\n' ||
                          '- Transport equipment back to depot' || E'\n' ||
                          '- Update collection status and notify office';
    
    -- Create driver task
    INSERT INTO tasks.drivers_taskboard (
        interaction_id,
        task_type,
        status,
        priority,
        customer_name,
        contact_name,
        contact_phone,
        site_address,
        equipment_summary,
        scheduled_date,
        scheduled_time,
        estimated_duration,
        special_instructions,
        assigned_to,
        created_by,
        created_at,
        updated_at
    ) VALUES (
        v_interaction_id,
        'collection',  -- Off-hire creates a collection task
        CASE WHEN p_priority = 'critical' THEN 'assigned' ELSE 'backlog' END,
        v_task_priority,
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
        CASE WHEN p_priority = 'critical' THEN v_driver_employee_id ELSE NULL END,
        v_employee_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_driver_task_id;
    
    -- =============================================================================
    -- CREATE DRIVER TASK EQUIPMENT ASSIGNMENTS
    -- =============================================================================
    
    -- Add equipment to driver task for collection preparation
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
    -- AUDIT LOGGING
    -- =============================================================================
    
    -- Log off-hire creation
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
            'site_name', v_site_name,
            'collection_date', p_collect_date,
            'equipment_count', v_equipment_count,
            'total_quantity', v_total_quantity,
            'early_return', p_early_return,
            'assigned_driver', v_driver_employee_name,
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
        ('Off-hire ' || v_reference_number || ' created for ' || v_customer_name || '. ' ||
         'Collection scheduled for ' || p_collect_date || ' at ' || p_collect_time || '. ' ||
         CASE WHEN p_priority = 'critical' 
              THEN 'Driver ' || v_driver_employee_name || ' assigned for critical collection.'
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
        -- Handle any unique constraint violations
        RETURN QUERY SELECT 
            false, 
            'Duplicate off-hire request detected.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
            
    WHEN foreign_key_violation THEN
        -- Handle foreign key violations
        RETURN QUERY SELECT 
            false, 
            'Invalid reference data. Please verify customer, contact, site, and equipment selections.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
            
    WHEN OTHERS THEN
        -- Handle any other errors
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
END;
$OFF_HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.create_off_hire TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.create_off_hire TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.create_off_hire TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.create_off_hire TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.create_off_hire IS 
'Process equipment off-hire/collection requests from customers.
Creates off-hire interaction with equipment list and collection details.
Automatically creates driver collection task with appropriate priority.
Handles early returns and various collection methods (collect vs counter return).
Designed to work with hire procedure for complete hire/off-hire workflow.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.create_off_hire(param1, param2);

-- Additional examples for this specific function
*/
