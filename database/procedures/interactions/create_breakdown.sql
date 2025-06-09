-- =============================================================================
-- INTERACTIONS: Process equipment breakdown reports from customers
-- =============================================================================
-- Purpose: Process equipment breakdown reports from customers
-- Dependencies: interactions.component_breakdown_details, tasks.drivers_taskboard
-- Used by: Breakdown reporting workflow, emergency repairs
-- Function: interactions.create_breakdown
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_breakdown;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.create_breakdown(
    -- Required breakdown details
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_list JSONB,                -- Array of {equipment_category_id, quantity, issue_description}
    p_issue_description TEXT,
    p_urgency_level VARCHAR(20) DEFAULT 'medium',
    
    -- Optional breakdown details  
    p_resolution_type VARCHAR(50) DEFAULT 'swap',
    p_work_impact TEXT DEFAULT NULL,
    p_customer_contact_onsite VARCHAR(255) DEFAULT NULL,
    p_customer_phone_onsite VARCHAR(20) DEFAULT NULL,
    p_breakdown_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
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
    breakdown_component_id INTEGER,
    driver_task_id INTEGER,
    assigned_driver TEXT,
    estimated_response_time TEXT
) AS $$
DECLARE
    v_interaction_id INTEGER;
    v_breakdown_component_id INTEGER;
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
    v_response_time TEXT;
    v_task_priority VARCHAR(20);
    v_estimated_duration INTEGER;
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
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT, NULL::TEXT;
            RETURN;
        END IF;
    ELSE
        v_employee_id := COALESCE(p_employee_id, 
            NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER);
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Get employee details for logging
    SELECT e.name || ' ' || e.surname INTO v_employee_name
    FROM core.employees e
    WHERE e.id = v_employee_id AND e.status = 'active';
    
    IF v_employee_name IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not found or inactive'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT, NULL::TEXT;
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
        v_validation_errors := array_append(v_validation_errors, 'At least one piece of equipment must be selected');
    END IF;
    
    IF p_issue_description IS NULL OR TRIM(p_issue_description) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Issue description is required');
    END IF;
    
    -- Validate urgency level
    IF p_urgency_level NOT IN ('low', 'medium', 'high', 'critical') THEN
        v_validation_errors := array_append(v_validation_errors, 'Invalid urgency level');
    END IF;
    
    -- Validate resolution type
    IF p_resolution_type NOT IN ('swap', 'repair_onsite', 'collect_repair') THEN
        v_validation_errors := array_append(v_validation_errors, 'Invalid resolution type');
    END IF;
    
    -- Validate contact method
    IF p_contact_method NOT IN ('phone', 'email', 'in_person', 'whatsapp', 'online', 'other') THEN
        v_validation_errors := array_append(v_validation_errors, 'Invalid contact method');
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Validation failed: ' || array_to_string(v_validation_errors, ', ')::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- VALIDATE CUSTOMER, CONTACT, AND SITE
    -- =============================================================================
    
    -- Validate customer, contact, and site using helper function
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
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- VALIDATE EQUIPMENT LIST
    -- =============================================================================
    
    -- Validate each equipment item in the list
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
    END LOOP;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Equipment validation failed: ' || array_to_string(v_validation_errors, ', ')::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- DETERMINE TASK PRIORITY AND RESPONSE TIME
    -- =============================================================================
    
    -- Set task priority and response time based on urgency
    CASE p_urgency_level
        WHEN 'critical' THEN
            v_task_priority := 'urgent';
            v_response_time := '30 minutes';
            v_estimated_duration := 60;  -- 1 hour for critical
        WHEN 'high' THEN
            v_task_priority := 'high';
            v_response_time := '1 hour';
            v_estimated_duration := 90;  -- 1.5 hours
        WHEN 'medium' THEN
            v_task_priority := 'medium';
            v_response_time := '4 hours';
            v_estimated_duration := 120; -- 2 hours
        WHEN 'low' THEN
            v_task_priority := 'low';
            v_response_time := 'next business day';
            v_estimated_duration := 90;  -- 1.5 hours
    END CASE;
    
    -- =============================================================================
    -- FIND AVAILABLE DRIVER FOR ASSIGNMENT
    -- =============================================================================
    
    -- Get an available driver for emergency response
    SELECT id, name || ' ' || surname
    INTO v_driver_employee_id, v_driver_employee_name
    FROM core.employees
    WHERE role = 'driver' AND status = 'active'
    ORDER BY RANDOM()  -- Distribute workload randomly among drivers
    LIMIT 1;
    
    IF v_driver_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'No drivers available for breakdown response'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER
    -- =============================================================================
    
    -- Generate reference number using system function
    v_reference_number := system.generate_reference_number('breakdown');
    
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
        'breakdown',
        'in_progress',  -- Breakdown is immediately in progress
        v_reference_number,
        p_contact_method,
        COALESCE(p_initial_notes, 'Equipment breakdown reported at ' || v_site_name || '. Issue: ' || 
                 LEFT(p_issue_description, 100) || CASE WHEN LENGTH(p_issue_description) > 100 THEN '...' ELSE '' END),
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
            'BREAKDOWN: ' || COALESCE(v_equipment_item->>'issue_description', p_issue_description),
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
    -- CREATE BREAKDOWN DETAILS COMPONENT (Layer 2)
    -- =============================================================================
    
    INSERT INTO interactions.component_breakdown_details (
        interaction_id,
        site_id,
        breakdown_date,
        issue_description,
        urgency_level,
        resolution_type,
        work_impact,
        customer_contact_onsite,
        customer_phone_onsite,
        created_at
    ) VALUES (
        v_interaction_id,
        p_site_id,
        p_breakdown_date,
        p_issue_description,
        p_urgency_level,
        p_resolution_type,
        p_work_impact,
        p_customer_contact_onsite,
        p_customer_phone_onsite,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_breakdown_component_id;
    
    -- =============================================================================
    -- CREATE DRIVER TASK FOR BREAKDOWN RESPONSE (Layer 3)
    -- =============================================================================
    
    -- Build task details
    v_task_title := UPPER(p_urgency_level) || ' Breakdown Response: ' || v_customer_name || ' - ' || v_site_name;
    v_task_description := 'EQUIPMENT BREAKDOWN - ' || UPPER(p_urgency_level) || ' PRIORITY' || E'\n\n' ||
                          'Customer: ' || v_customer_name || E'\n' ||
                          'Contact: ' || v_contact_name || E'\n' ||
                          'Site: ' || v_site_name || E'\n' ||
                          'Address: ' || v_site_address || E'\n' ||
                          'Equipment: ' || v_equipment_summary || E'\n' ||
                          'Issue: ' || p_issue_description || E'\n' ||
                          'Resolution: ' || UPPER(p_resolution_type) || E'\n\n' ||
                          'RESPONSE TIME TARGET: ' || v_response_time || E'\n\n' ||
                          CASE p_resolution_type
                            WHEN 'swap' THEN 'Actions: Bring replacement equipment, swap broken unit, collect for repair'
                            WHEN 'repair_onsite' THEN 'Actions: Bring tools/parts, repair equipment onsite'
                            WHEN 'collect_repair' THEN 'Actions: Collect broken equipment, arrange replacement delivery'
                          END;
    
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
        'repair',  -- Breakdown response is a repair task
        CASE WHEN p_urgency_level IN ('critical', 'high') THEN 'assigned' ELSE 'backlog' END,
        v_task_priority,
        v_customer_name,
        v_contact_name,
        COALESCE(p_customer_phone_onsite, 
                (SELECT phone_number FROM core.contacts WHERE id = p_contact_id)),
        v_site_address,
        v_equipment_summary,
        CASE WHEN p_urgency_level IN ('critical', 'high') THEN CURRENT_DATE ELSE CURRENT_DATE + 1 END,
        CASE WHEN p_urgency_level = 'critical' THEN CURRENT_TIME + INTERVAL '30 minutes'
             WHEN p_urgency_level = 'high' THEN CURRENT_TIME + INTERVAL '1 hour'
             ELSE '08:00'::TIME END,
        v_estimated_duration,
        'BREAKDOWN RESPONSE - ' || UPPER(p_urgency_level) || ' PRIORITY. Target response: ' || v_response_time,
        CASE WHEN p_urgency_level IN ('critical', 'high') THEN v_driver_employee_id ELSE NULL END,
        v_employee_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_driver_task_id;
    
    -- =============================================================================
    -- CREATE DRIVER TASK EQUIPMENT ASSIGNMENTS
    -- =============================================================================
    
    -- Add broken equipment to driver task (for swap out)
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
            'swap_out',
            'BROKEN: ' || COALESCE(v_equipment_item->>'issue_description', p_issue_description),
            CURRENT_TIMESTAMP
        );
        
        -- If resolution is swap, also add replacement equipment
        IF p_resolution_type = 'swap' THEN
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
                'swap_in',
                'REPLACEMENT: Prepare working unit for customer',
                CURRENT_TIMESTAMP
            );
        END IF;
    END LOOP;
    
    -- =============================================================================
    -- AUDIT LOGGING
    -- =============================================================================
    
    -- Log breakdown creation
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
        'create_breakdown',
        'interactions',
        v_interaction_id,
        jsonb_build_object(
            'reference_number', v_reference_number,
            'customer_name', v_customer_name,
            'site_name', v_site_name,
            'urgency_level', p_urgency_level,
            'equipment_count', v_equipment_count,
            'assigned_driver', v_driver_employee_name,
            'response_time_target', v_response_time,
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
        ('Breakdown ' || v_reference_number || ' created for ' || v_customer_name || '. ' ||
         CASE WHEN p_urgency_level IN ('critical', 'high') 
              THEN 'Driver ' || v_driver_employee_name || ' assigned for ' || v_response_time || ' response.'
              ELSE 'Breakdown logged for assignment. Target response: ' || v_response_time
         END)::TEXT,
        v_interaction_id,
        v_reference_number,
        v_breakdown_component_id,
        v_driver_task_id,
        v_driver_employee_name,
        v_response_time;
        
EXCEPTION 
    WHEN unique_violation THEN
        -- Handle any unique constraint violations
        RETURN QUERY SELECT 
            false, 
            'Duplicate breakdown report detected.'::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::TEXT,
            NULL::TEXT;
            
    WHEN foreign_key_violation THEN
        -- Handle foreign key violations
        RETURN QUERY SELECT 
            false, 
            'Invalid reference data. Please verify customer, contact, site, and equipment selections.'::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::TEXT,
            NULL::TEXT;
            
    WHEN OTHERS THEN
        -- Handle any other errors
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::TEXT,
            NULL::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.create_breakdown TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.create_breakdown TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.create_breakdown TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.create_breakdown TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.create_breakdown IS 
'Process equipment breakdown reports from customers.
Creates breakdown interaction with equipment list and breakdown component details.
Automatically creates urgent driver task for repair/swap response with appropriate priority.
Handles multiple equipment items and various resolution types (swap, repair onsite, collect for repair).
Designed for Flask frontend breakdown reporting workflow.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.create_breakdown(param1, param2);

-- Additional examples for this specific function
*/
