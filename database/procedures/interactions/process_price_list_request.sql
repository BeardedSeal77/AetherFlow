-- =============================================================================
-- INTERACTIONS: Process price list requests from customers
-- =============================================================================
-- Purpose: Process price list requests from customers
-- Dependencies: interactions.component_equipment_list, core.equipment_pricing
-- Used by: Price list workflow, equipment pricing
-- Function: interactions.process_price_list_request
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.process_price_list_request;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.process_price_list_request(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_equipment_names TEXT[], -- Array of equipment names requested
    p_contact_method VARCHAR(50) DEFAULT 'phone',
    p_notes TEXT DEFAULT NULL,
    p_employee_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    task_id INTEGER,
    equipment_count INTEGER
) AS $$
DECLARE
    v_interaction_id INTEGER;
    v_reference_number VARCHAR(20);
    v_task_id INTEGER;
    v_employee_id INTEGER;
    v_equipment_list TEXT;
    v_task_title VARCHAR(255);
    v_task_description TEXT;
    v_customer_name VARCHAR(255);
    v_contact_name TEXT;
    v_contact_email VARCHAR(255);
    v_customer_type VARCHAR(20);
    v_equipment_count INTEGER := 0;
    equipment_name TEXT;
BEGIN
    -- Get employee ID from session if not provided
    v_employee_id := COALESCE(p_employee_id, current_setting('app.current_employee_id', true)::INTEGER);
    
    -- Validate inputs
    IF p_customer_id IS NULL THEN
        RETURN QUERY SELECT false, 'Customer ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    IF p_contact_id IS NULL THEN
        RETURN QUERY SELECT false, 'Contact ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    IF p_equipment_names IS NULL OR array_length(p_equipment_names, 1) = 0 THEN
        RETURN QUERY SELECT false, 'At least one equipment item must be specified'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not authenticated'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Get customer and contact details
    SELECT 
        c.customer_name,
        c.is_company,
        ct.first_name || ' ' || ct.last_name,
        ct.email
    INTO v_customer_name, v_customer_type, v_contact_name, v_contact_email
    FROM core.customers c
    JOIN core.contacts ct ON c.id = ct.customer_id
    WHERE c.id = p_customer_id 
        AND ct.id = p_contact_id
        AND c.status = 'active' 
        AND ct.status = 'active';
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT false, 'Customer or contact not found or inactive'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Convert equipment array to comma-separated string
    v_equipment_list := array_to_string(p_equipment_names, ', ');
    
    -- Verify that requested equipment exists
    SELECT COUNT(*) INTO v_equipment_count
    FROM core.equipment_categories
    WHERE LOWER(category_name) = ANY(SELECT LOWER(unnest(p_equipment_names)))
        AND is_active = true;
    
    -- Generate reference number
    v_reference_number := system.generate_reference_number('price_list');
    
    -- Create interaction record (Layer 1)
    INSERT INTO interactions.interactions (
        customer_id, contact_id, employee_id, interaction_type,
        status, reference_number, contact_method, notes
    ) VALUES (
        p_customer_id, p_contact_id, v_employee_id, 'price_list',
        'pending', v_reference_number, p_contact_method,
        COALESCE(p_notes, 'Price list request from ' || v_contact_name || ' at ' || v_customer_name || ' for ' || v_equipment_list)
    ) RETURNING id INTO v_interaction_id;
    
    -- Create equipment list components (Layer 2)
    FOREACH equipment_name IN ARRAY p_equipment_names
    LOOP
        INSERT INTO interactions.component_equipment_list (
            interaction_id, equipment_category_id, quantity, special_requirements
        )
        SELECT 
            v_interaction_id,
            ec.id,
            1,
            'Price inquiry - ' || ec.category_name
        FROM core.equipment_categories ec
        WHERE LOWER(ec.category_name) = LOWER(equipment_name)
            AND ec.is_active = true;
    END LOOP;
    
    -- Create user task for sending price list (Layer 3)
    v_task_title := 'Send price list to ' || v_contact_name || ' at ' || v_customer_name;
    v_task_description := 'Prepare and send price list for ' || v_equipment_list || ' to ' || v_contact_name || ' (' || v_contact_email || ') at ' || v_customer_name || '. Customer type: ' || 
        CASE WHEN v_customer_type::BOOLEAN THEN 'Company' ELSE 'Individual' END || 
        '. Contact method: Email preferred, phone available.';
    
    INSERT INTO tasks.user_taskboard (
        interaction_id, assigned_to, task_type, priority, status,
        title, description, due_date
    ) VALUES (
        v_interaction_id, v_employee_id, 'send_price_list', 'medium', 'pending',
        v_task_title, v_task_description, CURRENT_DATE + 1
    ) RETURNING id INTO v_task_id;
    
    -- Log audit entry
    INSERT INTO security.audit_log (employee_id, action, table_name, record_id, new_values)
    VALUES (v_employee_id, 'create_price_list', 'interactions', v_interaction_id,
            jsonb_build_object(
                'reference_number', v_reference_number,
                'customer_name', v_customer_name,
                'equipment_list', v_equipment_list,
                'equipment_count', v_equipment_count
            ));
    
    -- Return success
    RETURN QUERY SELECT 
        true,
        'Price list request created successfully'::TEXT,
        v_interaction_id,
        v_reference_number,
        v_task_id,
        v_equipment_count;
        
EXCEPTION WHEN OTHERS THEN
    -- Return error
    RETURN QUERY SELECT 
        false,
        ('Error processing price list request: ' || SQLERRM)::TEXT,
        NULL::INTEGER,
        NULL::VARCHAR(20),
        NULL::INTEGER,
        NULL::INTEGER;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.process_price_list_request TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.process_price_list_request TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.process_price_list_request TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.process_price_list_request TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.process_price_list_request IS 
'Process price list requests from customers. Used by Price list workflow, equipment pricing.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.process_price_list_request(param1, param2);

-- Additional examples for this specific function
*/
