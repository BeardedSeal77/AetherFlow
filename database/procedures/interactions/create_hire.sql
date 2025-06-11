-- =============================================================================
-- INTERACTIONS: EQUIPMENT HIRE/DELIVERY PROCESSING
-- =============================================================================
-- Purpose: Process equipment hire requests from customers
-- Creates hire interaction with equipment list and delivery details
-- Creates driver task for equipment delivery
-- Uses helper functions for authentication, validation, and driver assignment
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_hire;

-- Create the hire processing procedure
CREATE OR REPLACE FUNCTION interactions.create_hire(
    -- Required hire details
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_list JSONB,         -- [{"equipment_category_id": 5, "quantity": 2, "hire_duration": 7, "hire_period_type": "days", "special_requirements": "..."}]
    p_delivery_date DATE,
    p_priority VARCHAR(20) DEFAULT 'medium',  -- Employee selects priority
    
    -- Optional delivery details
    p_delivery_time TIME DEFAULT '09:00'::TIME,
    p_delivery_method VARCHAR(50) DEFAULT 'deliver',
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
    hire_component_id INTEGER,
    driver_task_id INTEGER,
    assigned_driver TEXT,
    delivery_date DATE,
    estimated_delivery_time TIME,
    equipment_count INTEGER,
    total_quantity INTEGER
) AS $HIRE$
DECLARE
    v_interaction_id INTEGER;
    v_hire_component_id INTEGER;
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
    v_task_priority VARCHAR(20);
    v_estimated_duration INTEGER := 90; -- Default 90 minutes for delivery
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
    
    -- Verify employee exists and is active
    SELECT e.name || ' ' || e.surname, e.role
    INTO v_employee_name, v_task_priority
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
    
    -- Validate customer exists
    SELECT customer_name INTO v_customer_name
    FROM core.customers 
    WHERE id = p_customer_id AND status = 'active';
    
    IF v_customer_name IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Customer not found or inactive');
    END IF;
    
    -- Validate contact exists and belongs to customer
    SELECT first_name || ' ' || last_name INTO v_contact_name
    FROM core.contacts 
    WHERE id = p_contact_id AND customer_id = p_customer_id AND status = 'active';
    
    IF v_contact_name IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Contact not found or does not belong to customer');
    END IF;
    
    -- Validate site exists and belongs to customer
    SELECT site_name, site_address INTO v_site_name, v_site_address
    FROM core.sites 
    WHERE id = p_site_id AND customer_id = p_customer_id AND status = 'active';
    
    IF v_site_name IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Site not found or does not belong to customer');
    END IF;
    
    -- Validate equipment list
    IF p_equipment_list IS NULL OR jsonb_array_length(p_equipment_list) = 0 THEN
        v_validation_errors := array_append(v_validation_errors, 'Equipment list is required');
    ELSE
        -- Validate each equipment item
        FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
        LOOP
            -- Check required fields
            IF (v_equipment_item->>'equipment_category_id') IS NULL THEN
                v_validation_errors := array_append(v_validation_errors, 'Equipment category ID is required for all items');
            END IF;
            
            IF (v_equipment_item->>'quantity') IS NULL OR (v_equipment_item->>'quantity')::INTEGER <= 0 THEN
                v_validation_errors := array_append(v_validation_errors, 'Valid quantity is required for all equipment items');
            END IF;
            
            IF (v_equipment_item->>'hire_duration') IS NULL OR (v_equipment_item->>'hire_duration')::INTEGER <= 0 THEN
                v_validation_errors := array_append(v_validation_errors, 'Valid hire duration is required for all equipment items');
            END IF;
            
            IF (v_equipment_item->>'hire_period_type') NOT IN ('days', 'weeks', 'months') THEN
                v_validation_errors := array_append(v_validation_errors, 'Hire period type must be days, weeks, or months');
            END IF;
            
            -- Verify equipment category exists
            IF NOT EXISTS (SELECT 1 FROM core.equipment_categories WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER) THEN
                v_validation_errors := array_append(v_validation_errors, 'Invalid equipment category: ' || (v_equipment_item->>'equipment_category_id'));
            END IF;
            
            -- Count equipment items and quantities
            v_equipment_count := v_equipment_count + 1;
            v_total_quantity := v_total_quantity + (v_equipment_item->>'quantity')::INTEGER;
        END LOOP;
    END IF;
    
    -- Validate delivery date
    IF p_delivery_date IS NULL THEN
        v_validation_errors := array_append(v_validation_errors, 'Delivery date is required');
    ELSIF p_delivery_date < CURRENT_DATE THEN
        v_validation_errors := array_append(v_validation_errors, 'Delivery date cannot be in the past');
    END IF;
    
    -- Validate priority
    IF p_priority NOT IN ('low', 'medium', 'high', 'urgent') THEN
        v_validation_errors := array_append(v_validation_errors, 'Priority must be low, medium, high, or urgent');
    END IF;
    
    -- Validate delivery method
    IF p_delivery_method NOT IN ('deliver', 'counter_collection') THEN
        v_validation_errors := array_append(v_validation_errors, 'Delivery method must be deliver or counter_collection');
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Validation failed: ' || array_to_string(v_validation_errors, '; ')::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- TASK PRIORITY AND SCHEDULING LOGIC
    -- =============================================================================
    
    -- Determine task priority based on delivery date and user priority
    v_task_priority := CASE 
        WHEN p_priority = 'urgent' OR p_delivery_date = CURRENT_DATE THEN 'urgent'
        WHEN p_priority = 'high' OR p_delivery_date = CURRENT_DATE + 1 THEN 'high'
        ELSE 'medium'
    END;
    
    -- Estimate delivery duration based on equipment quantity and complexity
    IF v_total_quantity > 5 THEN
        v_estimated_duration := v_estimated_duration + 30; -- Extra 30 minutes for large deliveries
    END IF;
    
    -- Set delivery scheduling
    v_scheduled_date := p_delivery_date;
    v_scheduled_time := p_delivery_time;
    
    -- =============================================================================
    -- FIND AVAILABLE DRIVER FOR ASSIGNMENT
    -- =============================================================================
    
    -- Get an available driver for delivery (use helper function)
    SELECT driver_id, driver_name 
    INTO v_driver_employee_id, v_driver_employee_name
    FROM tasks.find_available_driver(v_scheduled_date, v_task_priority);
    
    IF v_driver_employee_id IS NULL THEN
        -- Fall back to random driver assignment
        SELECT id, name || ' ' || surname
        INTO v_driver_employee_id, v_driver_employee_name
        FROM core.employees
        WHERE role = 'driver' AND status = 'active'
        ORDER BY RANDOM()
        LIMIT 1;
    END IF;
    
    IF v_driver_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'No drivers available for delivery assignment'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER
    -- =============================================================================
    
    -- Generate reference number using system function
    v_reference_number := system.generate_reference_number('hire');
    
    -- =============================================================================
    -- BUILD EQUIPMENT SUMMARY FOR DISPLAY
    -- =============================================================================
    
    v_equipment_summary := '';
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        SELECT category_name INTO v_equipment_summary
        FROM core.equipment_categories 
        WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER;
        
        v_equipment_summary := v_equipment_summary || 
            CASE WHEN v_equipment_summary != '' THEN ', ' ELSE '' END ||
            v_equipment_summary || ' x' || (v_equipment_item->>'quantity');
    END LOOP;
    
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
        'pending',  -- Hire starts as pending until delivery
        v_reference_number,
        p_contact_method,
        COALESCE(p_initial_notes, 'Equipment hire requested for delivery to ' || v_site_name || 
                 ' on ' || p_delivery_date || ' at ' || p_delivery_time),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_interaction_id;
    
    -- =============================================================================
    -- CREATE EQUIPMENT LIST COMPONENT (Layer 2)
    -- =============================================================================
    
    -- Insert each equipment item
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        INSERT INTO interactions.component_equipment_list (
            interaction_id,
            equipment_category_id,
            quantity,
            hire_duration,
            hire_period_type,
            special_requirements,
            created_at
        ) VALUES (
            v_interaction_id,
            (v_equipment_item->>'equipment_category_id')::INTEGER,
            (v_equipment_item->>'quantity')::INTEGER,
            (v_equipment_item->>'hire_duration')::INTEGER,
            (v_equipment_item->>'hire_period_type')::VARCHAR,
            v_equipment_item->>'special_requirements',
            CURRENT_TIMESTAMP
        );
    END LOOP;
    
    -- =============================================================================
    -- CREATE HIRE DETAILS COMPONENT (Layer 2)
    -- =============================================================================
    
    INSERT INTO interactions.component_hire_details (
        interaction_id,
        site_id,
        deliver_date,
        deliver_time,
        delivery_method,
        special_instructions,
        created_at
    ) VALUES (
        v_interaction_id,
        p_site_id,
        p_delivery_date,
        p_delivery_time,
        p_delivery_method,
        p_special_instructions,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_hire_component_id;
    
    -- =============================================================================
    -- CREATE DRIVER TASK USING HELPER FUNCTION (Layer 3)
    -- =============================================================================
    
    SELECT task_id INTO v_driver_task_id
    FROM tasks.create_driver_task(
        v_interaction_id,
        'delivery',
        v_task_priority,
        v_customer_name,
        v_contact_name,
        (SELECT phone_number FROM core.contacts WHERE id = p_contact_id),
        v_site_address,
        v_equipment_summary,
        v_scheduled_date,
        v_scheduled_time,
        v_estimated_duration,
        CASE WHEN p_delivery_method = 'deliver' 
             THEN 'DELIVERY: ' || COALESCE(p_special_instructions, 'Standard delivery and setup')
             ELSE 'COUNTER COLLECTION: Customer collecting from depot' END,
        CASE WHEN p_priority IN ('urgent', 'high') THEN v_driver_employee_id ELSE NULL END,
        v_employee_id
    );
    
    -- =============================================================================
    -- CREATE DRIVER TASK EQUIPMENT ASSIGNMENTS
    -- =============================================================================
    
    -- Add equipment to driver task for delivery preparation
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
            'delivery',
            'FOR DELIVERY: Duration ' || (v_equipment_item->>'hire_duration') || ' ' || 
            (v_equipment_item->>'hire_period_type') || 
            CASE WHEN v_equipment_item->>'special_requirements' IS NOT NULL 
                 THEN '. Special: ' || (v_equipment_item->>'special_requirements') 
                 ELSE '' END,
            CURRENT_TIMESTAMP
        );
    END LOOP;
    
    -- =============================================================================
    -- RETURN SUCCESS RESPONSE
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Hire request processed successfully. Driver task created for ' || 
         CASE WHEN v_driver_employee_name IS NOT NULL 
              THEN v_driver_employee_name 
              ELSE 'assignment.' 
         END)::TEXT,
        v_interaction_id,
        v_reference_number,
        v_hire_component_id,
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
            'Duplicate hire request detected. Reference number already exists.'::TEXT,
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
$HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION interactions.create_hire TO PUBLIC;

COMMENT ON FUNCTION interactions.create_hire IS 
'Process equipment hire/delivery requests from customers.
Creates hire interaction with equipment list and delivery details.
Automatically creates driver delivery task with appropriate priority.
Uses helper functions for authentication, validation, and driver assignment.
Designed for task management workflow without cost calculations.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Standard hire delivery (John Guy scenario)
SELECT * FROM interactions.create_hire(
    1000,                                   -- p_customer_id (ABC Construction)
    1000,                                   -- p_contact_id (John Guy)
    1001,                                   -- p_site_id (Sandton Project Site)
    '[
        {
            "equipment_category_id": 5,
            "quantity": 1,
            "hire_duration": 7,
            "hire_period_type": "days",
            "special_requirements": "Check equipment is in good condition"
        },
        {
            "equipment_category_id": 8,
            "quantity": 2,
            "hire_duration": 14,
            "hire_period_type": "days",
            "special_requirements": "Deliver with safety equipment"
        }
    ]'::jsonb,                             -- p_equipment_list
    '2025-06-10',                          -- p_delivery_date
    'medium',                              -- p_priority
    '09:00'::TIME,                         -- p_delivery_time
    'deliver',                             -- p_delivery_method
    'Equipment needed at main gate. Ask for site foreman John Guy.',
    'phone',                               -- p_contact_method
    'Customer called requesting equipment hire for new project',
    1001                                   -- p_employee_id
);

-- Example 2: Urgent same-day delivery
SELECT * FROM interactions.create_hire(
    1001,                                   -- p_customer_id
    1002,                                   -- p_contact_id
    1002,                                   -- p_site_id
    '[
        {
            "equipment_category_id": 3,
            "quantity": 1,
            "hire_duration": 3,
            "hire_period_type": "days",
            "special_requirements": "URGENT: Site ready for immediate use"
        }
    ]'::jsonb,                             -- p_equipment_list
    CURRENT_DATE,                          -- p_delivery_date (today - urgent)
    'urgent',                              -- p_priority (same-day delivery)
    '14:00'::TIME,                         -- p_delivery_time
    'deliver',                             -- p_delivery_method
    'URGENT DELIVERY: Customer site ready and waiting. Priority delivery required.',
    'phone',                               -- p_contact_method
    'URGENT: Customer needs equipment today',
    1001                                   -- p_employee_id
);

-- Example 3: Counter collection
SELECT * FROM interactions.create_hire(
    1002,                                   -- p_customer_id
    1003,                                   -- p_contact_id
    1003,                                   -- p_site_id
    '[
        {
            "equipment_category_id": 2,
            "quantity": 1,
            "hire_duration": 5,
            "hire_period_type": "days"
        }
    ]'::jsonb,                             -- p_equipment_list
    '2025-06-12',                          -- p_delivery_date
    'low',                                 -- p_priority
    '10:00'::TIME,                         -- p_delivery_time
    'counter_collection',                  -- p_delivery_method
    'Customer will collect from depot',
    'email',                               -- p_contact_method
    'Customer prefers to collect equipment themselves',
    1001                                   -- p_employee_id
);
*/