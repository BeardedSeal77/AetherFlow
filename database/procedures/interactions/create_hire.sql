-- =============================================================================
-- INTERACTIONS: UPDATED EQUIPMENT HIRE/DELIVERY PROCESSING WITH ACCESSORIES
-- =============================================================================
-- Purpose: Process equipment hire requests with proper accessories handling
-- Creates hire interaction with equipment list, accessories, and delivery details
-- Creates driver task for equipment delivery
-- Updated: 2025-06-11 - Now handles accessories from normalized table
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_hire;

-- Create the updated hire processing procedure
CREATE OR REPLACE FUNCTION interactions.create_hire(
    -- Required hire details
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_list JSONB,         -- [{"equipment_category_id": 5, "quantity": 2, "hire_duration": 7, "hire_period_type": "days", "special_requirements": "...", "accessories": [...]}]
    p_delivery_date DATE,
    p_priority VARCHAR(20) DEFAULT 'medium',
    
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
    total_quantity INTEGER,
    total_accessories_count INTEGER
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
    v_driver_employee_name TEXT;
    v_equipment_summary TEXT;
    v_validation_errors TEXT[] := '{}';
    v_equipment_item JSONB;
    v_accessory_item JSONB;
    v_equipment_count INTEGER := 0;
    v_total_quantity INTEGER := 0;
    v_total_accessories INTEGER := 0;
    v_equipment_list_id INTEGER;
    
    -- Task scheduling variables
    v_estimated_duration INTEGER := 90;
    v_scheduled_date DATE;
    v_scheduled_time TIME;
BEGIN
    -- =============================================================================
    -- AUTHENTICATION & VALIDATION
    -- =============================================================================
    
    -- Get employee info (simplified authentication)
    SELECT id, name || ' ' || surname INTO v_employee_id, v_employee_name
    FROM core.employees 
    WHERE id = COALESCE(p_employee_id, 1) AND status = 'active';
    
    -- Basic validation
    SELECT customer_name INTO v_customer_name
    FROM core.customers 
    WHERE id = p_customer_id AND status = 'active';
    
    SELECT first_name || ' ' || last_name INTO v_contact_name
    FROM core.contacts 
    WHERE id = p_contact_id AND customer_id = p_customer_id AND status = 'active';
    
    SELECT site_name, address_line1 || COALESCE(', ' || address_line2, '') || ', ' || city 
    INTO v_site_name, v_site_address
    FROM core.sites 
    WHERE id = p_site_id AND customer_id = p_customer_id AND is_active = true;
    
    -- Return early if basic validation fails
    IF v_customer_name IS NULL OR v_contact_name IS NULL OR v_site_name IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'Invalid customer, contact, or site selection. Please verify selections.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Validate equipment list
    IF p_equipment_list IS NULL OR jsonb_array_length(p_equipment_list) = 0 THEN
        RETURN QUERY SELECT 
            false, 
            'Equipment list cannot be empty.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- BUILD EQUIPMENT SUMMARY AND COUNTS
    -- =============================================================================
    
    v_equipment_summary := '';
    
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        v_equipment_count := v_equipment_count + 1;
        v_total_quantity := v_total_quantity + (v_equipment_item->>'quantity')::INTEGER;
        
        -- Count accessories if provided
        IF v_equipment_item ? 'accessories' AND jsonb_array_length(v_equipment_item->'accessories') > 0 THEN
            v_total_accessories := v_total_accessories + jsonb_array_length(v_equipment_item->'accessories');
        END IF;
        
        -- Build equipment summary
        SELECT category_name INTO v_equipment_summary
        FROM core.equipment_categories 
        WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER;
        
        v_equipment_summary := COALESCE(v_equipment_summary, '') || 
            CASE WHEN v_equipment_summary != '' THEN ', ' ELSE '' END ||
            v_equipment_summary || ' x' || (v_equipment_item->>'quantity');
    END LOOP;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER
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
        'pending',
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
    
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        -- Insert equipment item
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
        ) RETURNING id INTO v_equipment_list_id;
        
        -- =============================================================================
        -- PROCESS ACCESSORIES FOR THIS EQUIPMENT ITEM
        -- =============================================================================
        
        -- If no accessories provided, add default accessories automatically
        IF NOT (v_equipment_item ? 'accessories') OR jsonb_array_length(v_equipment_item->'accessories') = 0 THEN
            -- Insert default accessories for this equipment
            INSERT INTO interactions.component_equipment_accessories (
                interaction_id,
                equipment_list_component_id,
                accessory_id,
                quantity_selected,
                is_default_selection,
                unit_cost_at_time,
                created_at
            )
            SELECT 
                v_interaction_id,
                v_equipment_list_id,
                ea.id,
                ea.quantity, -- Use default quantity
                true, -- This is a default selection
                ea.unit_cost,
                CURRENT_TIMESTAMP
            FROM core.equipment_accessories ea
            WHERE ea.equipment_category_id = (v_equipment_item->>'equipment_category_id')::INTEGER
              AND ea.accessory_type = 'default'
              AND ea.is_active = true;
        ELSE
            -- Process provided accessories
            FOR v_accessory_item IN SELECT * FROM jsonb_array_elements(v_equipment_item->'accessories')
            LOOP
                INSERT INTO interactions.component_equipment_accessories (
                    interaction_id,
                    equipment_list_component_id,
                    accessory_id,
                    quantity_selected,
                    is_default_selection,
                    unit_cost_at_time,
                    notes,
                    created_at
                ) 
                SELECT 
                    v_interaction_id,
                    v_equipment_list_id,
                    (v_accessory_item->>'accessory_id')::INTEGER,
                    COALESCE((v_accessory_item->>'quantity')::INTEGER, ea.quantity),
                    COALESCE((v_accessory_item->>'is_default')::BOOLEAN, ea.accessory_type = 'default'),
                    ea.unit_cost,
                    v_accessory_item->>'notes',
                    CURRENT_TIMESTAMP
                FROM core.equipment_accessories ea
                WHERE ea.id = (v_accessory_item->>'accessory_id')::INTEGER
                  AND ea.is_active = true;
            END LOOP;
        END IF;
    END LOOP;
    
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
        p_delivery_date, -- Assuming start date same as delivery date
        p_delivery_time,
        p_delivery_method,
        p_special_instructions,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_hire_component_id;
    
    -- =============================================================================
    -- TASK SCHEDULING
    -- =============================================================================
    
    -- Adjust duration based on quantity and complexity
    IF v_total_quantity > 5 THEN
        v_estimated_duration := v_estimated_duration + 30;
    END IF;
    
    IF v_total_accessories > 10 THEN
        v_estimated_duration := v_estimated_duration + 15; -- Extra time for many accessories
    END IF;
    
    v_scheduled_date := p_delivery_date;
    v_scheduled_time := p_delivery_time;
    
    -- =============================================================================
    -- CREATE DRIVER TASK (Layer 3)
    -- =============================================================================
    
    -- Build task description
    v_task_description := 'DELIVERY TASK' || E'\n' ||
                         'Customer: ' || v_customer_name || E'\n' ||
                         'Contact: ' || v_contact_name || E'\n' ||
                         'Site: ' || v_site_name || E'\n' ||
                         'Address: ' || v_site_address || E'\n' ||
                         'Equipment: ' || v_equipment_summary || E'\n' ||
                         'Accessories: ' || v_total_accessories || ' items' || E'\n' ||
                         'Scheduled: ' || v_scheduled_date || ' at ' || v_scheduled_time || E'\n' ||
                         COALESCE('Instructions: ' || p_special_instructions, '');
    
    -- Create driver task
    INSERT INTO tasks.drivers_taskboard (
        interaction_id,
        assigned_driver_id,
        task_type,
        priority,
        status,
        title,
        description,
        customer_name,
        site_name,
        site_address,
        scheduled_date,
        scheduled_time,
        estimated_duration_minutes,
        equipment_summary,
        created_by,
        created_at
    ) VALUES (
        v_interaction_id,
        NULL, -- Will be assigned later
        'delivery',
        p_priority,
        'backlog',
        'Equipment Delivery - ' || v_customer_name,
        v_task_description,
        v_customer_name,
        v_site_name,
        v_site_address,
        v_scheduled_date,
        v_scheduled_time,
        v_estimated_duration,
        v_equipment_summary,
        v_employee_id,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_driver_task_id;
    
    -- =============================================================================
    -- SUCCESS RESPONSE
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Hire request created successfully. Reference: ' || v_reference_number || 
         '. Equipment count: ' || v_equipment_count || 
         ', Total quantity: ' || v_total_quantity ||
         ', Accessories: ' || v_total_accessories ||
         '. Driver task created for delivery on ' || v_scheduled_date || 
         ' at ' || v_scheduled_time || '.')::TEXT,
        v_interaction_id,
        v_reference_number,
        v_hire_component_id,
        v_driver_task_id,
        COALESCE(v_driver_employee_name, 'Unassigned'),
        v_scheduled_date,
        v_scheduled_time,
        v_equipment_count,
        v_total_quantity,
        v_total_accessories;
        
EXCEPTION 
    WHEN unique_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Duplicate hire request detected. Reference number already exists.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER, NULL::INTEGER;
            
    WHEN foreign_key_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Invalid reference data. Please verify customer, contact, site, equipment, and accessory selections.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER, NULL::INTEGER;
            
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER, NULL::INTEGER;
END;
$HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION interactions.create_hire TO PUBLIC;

COMMENT ON FUNCTION interactions.create_hire IS 
'Process equipment hire/delivery requests with accessories support.
Creates hire interaction with equipment list, accessories, and delivery details.
Automatically adds default accessories if none specified.
Creates driver delivery task with appropriate priority and scheduling.
Updated to handle accessories from normalized core.equipment_accessories table.
Designed for task management workflow with complete accessory tracking.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage with accessories:
SELECT * FROM interactions.create_hire(
    p_customer_id := 1,
    p_contact_id := 1, 
    p_site_id := 1,
    p_equipment_list := '[
        {
            "equipment_category_id": 1, 
            "quantity": 1, 
            "hire_duration": 7, 
            "hire_period_type": "days",
            "special_requirements": "Handle with care",
            "accessories": [
                {"accessory_id": 1, "quantity": 1, "is_default": true},
                {"accessory_id": 2, "quantity": 2, "is_default": false, "notes": "Extra fuel requested"}
            ]
        }
    ]'::jsonb,
    p_delivery_date := CURRENT_DATE + 1,
    p_priority := 'medium'
);

-- Example usage without specifying accessories (will auto-add defaults):
SELECT * FROM interactions.create_hire(
    p_customer_id := 1,
    p_contact_id := 1, 
    p_site_id := 1,
    p_equipment_list := '[
        {
            "equipment_category_id": 1, 
            "quantity": 1, 
            "hire_duration": 7, 
            "hire_period_type": "days"
        }
    ]'::jsonb,
    p_delivery_date := CURRENT_DATE + 1
);
*/