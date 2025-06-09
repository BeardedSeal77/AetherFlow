-- =============================================================================
-- INTERACTIONS: EQUIPMENT HIRE/DELIVERY PROCESSING
-- =============================================================================
-- Purpose: Process equipment hire/delivery requests from customers
-- Creates hire interaction with equipment list and delivery details
-- Creates driver task for equipment delivery
-- Mirrors off-hire procedure structure but focuses on delivery/hire
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
    p_equipment_list JSONB,         -- [{"equipment_category_id": 5, "quantity": 2, "special_requirements": "..."}]
    p_deliver_date DATE,
    p_priority VARCHAR(20) DEFAULT 'medium',  -- Employee selects priority
    
    -- Optional delivery details
    p_deliver_time TIME DEFAULT '09:00'::TIME,
    p_start_date DATE DEFAULT NULL,
    p_start_time TIME DEFAULT NULL,
    p_delivery_method VARCHAR(50) DEFAULT 'deliver',
    p_hire_duration INTEGER DEFAULT NULL, -- in days
    p_hire_period_type VARCHAR(20) DEFAULT 'days',
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
    v_employee_name VARCHAR(255);
    v_customer_name VARCHAR(255);
    v_contact_name VARCHAR(255);
    v_site_name VARCHAR(255);
    v_site_address TEXT;
    v_equipment_summary TEXT;
    v_equipment_count INTEGER := 0;
    v_total_quantity INTEGER := 0;
    v_equipment_item JSONB;
    v_task_priority VARCHAR(20);
    v_estimated_duration INTEGER;
    v_scheduled_date DATE;
    v_scheduled_time TIME;
    v_driver_employee_id INTEGER;
    v_driver_employee_name TEXT;
BEGIN
    -- =============================================================================
    -- PARAMETER VALIDATION & DEFAULTS
    -- =============================================================================
    
    -- Set default employee (system user if not provided)
    v_employee_id := COALESCE(p_employee_id, 1000);
    
    -- Validate customer exists
    SELECT customer_name INTO v_customer_name
    FROM core.customers 
    WHERE id = p_customer_id AND status = 'active';
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'Customer not found or inactive.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Validate contact exists and belongs to customer
    SELECT first_name || ' ' || last_name INTO v_contact_name
    FROM core.contacts 
    WHERE id = p_contact_id AND customer_id = p_customer_id AND is_active = true;
    
    IF v_contact_name IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'Contact not found or does not belong to this customer.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Validate site exists and belongs to customer
    SELECT site_name, 
           address_line1 || CASE WHEN address_line2 IS NOT NULL THEN ', ' || address_line2 ELSE '' END ||
           ', ' || city || CASE WHEN postal_code IS NOT NULL THEN ' ' || postal_code ELSE '' END
    INTO v_site_name, v_site_address
    FROM core.sites 
    WHERE id = p_site_id AND customer_id = p_customer_id AND is_active = true;
    
    IF v_site_name IS NULL THEN
        RETURN QUERY SELECT 
            false, 
            'Site not found or does not belong to this customer.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Validate equipment list is not empty
    IF p_equipment_list IS NULL OR jsonb_array_length(p_equipment_list) = 0 THEN
        RETURN QUERY SELECT 
            false, 
            'Equipment list cannot be empty.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::INTEGER, NULL::TEXT,
            NULL::DATE, NULL::TIME, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Get employee name for audit trail
    SELECT first_name || ' ' || last_name INTO v_employee_name
    FROM core.employees WHERE id = v_employee_id;
    
    -- Count equipment items
    SELECT COUNT(*), SUM((item->>'quantity')::INTEGER)
    INTO v_equipment_count, v_total_quantity
    FROM jsonb_array_elements(p_equipment_list) item;
    
    -- Set delivery scheduling defaults
    v_scheduled_date := p_deliver_date;
    v_scheduled_time := p_deliver_time;
    
    -- Determine task priority and driver assignment
    v_task_priority := CASE 
        WHEN p_priority = 'urgent' THEN 'urgent'
        WHEN p_priority = 'high' THEN 'high'
        WHEN p_priority = 'critical' THEN 'urgent'
        ELSE 'medium'
    END;
    
    -- Estimate delivery duration based on equipment count
    v_estimated_duration := CASE 
        WHEN v_equipment_count <= 2 THEN 60  -- 1 hour for small deliveries
        WHEN v_equipment_count <= 5 THEN 90  -- 1.5 hours for medium deliveries
        ELSE 120                             -- 2 hours for large deliveries
    END;
    
    -- For critical/urgent deliveries, try to assign best available driver
    IF p_priority IN ('critical', 'urgent') THEN
        SELECT id, first_name || ' ' || last_name
        INTO v_driver_employee_id, v_driver_employee_name
        FROM core.employees 
        WHERE role = 'driver' AND status = 'active'
        ORDER BY id LIMIT 1; -- In real system, this would check availability
    END IF;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER
    -- =============================================================================
    
    SELECT system.generate_reference_number('hire') INTO v_reference_number;
    
    -- =============================================================================
    -- CREATE HIRE INTERACTION (Layer 1)
    -- =============================================================================
    
    INSERT INTO interactions.interactions (
        customer_id,
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
        v_employee_id,
        'hire',
        'pending',
        v_reference_number,
        p_contact_method,
        COALESCE(p_initial_notes, 'Equipment hire requested for ' || v_site_name || 
                 ' on ' || p_deliver_date || 
                 CASE WHEN p_hire_duration IS NOT NULL 
                      THEN ' (Duration: ' || p_hire_duration || ' ' || p_hire_period_type || ')'
                      ELSE '' END),
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
            'DELIVERY: ' || COALESCE(v_equipment_item->>'special_requirements', 'Standard delivery'),
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
        hire_duration,
        hire_period_type,
        special_instructions,
        created_at
    ) VALUES (
        v_interaction_id,
        p_site_id,
        p_deliver_date,
        p_deliver_time,
        COALESCE(p_start_date, p_deliver_date),
        COALESCE(p_start_time, p_deliver_time),
        p_delivery_method,
        p_hire_duration,
        p_hire_period_type,
        p_special_instructions,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_hire_component_id;
    
    -- =============================================================================
    -- CREATE DRIVER TASK (Layer 3)
    -- =============================================================================
    
    -- Create standard delivery instructions
    p_special_instructions := COALESCE(p_special_instructions, '') || E'\n' ||
                          'DELIVERY CHECKLIST:' || E'\n' ||
                          '- Confirm delivery address and contact details' || E'\n' ||
                          '- Check equipment condition before loading' || E'\n' ||
                          '- Load equipment safely and securely' || E'\n' ||
                          '- Contact customer upon arrival' || E'\n' ||
                          '- Inspect delivery area for safety' || E'\n' ||
                          '- Unload equipment in designated area' || E'\n' ||
                          '- Demonstrate equipment operation if required' || E'\n' ||
                          '- Get customer signature on delivery note' || E'\n' ||
                          '- Take photos of delivered equipment' || E'\n' ||
                          '- Update delivery status and notify office';
    
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
        'delivery',  -- Hire creates a delivery task
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
        CASE WHEN p_delivery_method = 'deliver' 
             THEN 'DELIVERY: ' || COALESCE(p_special_instructions, 'Standard delivery')
             ELSE 'COUNTER PICKUP: Customer collecting from depot' END ||
             CASE WHEN p_hire_duration IS NOT NULL 
                  THEN ' (Duration: ' || p_hire_duration || ' ' || p_hire_period_type || ')'
                  ELSE '' END,
        CASE WHEN p_priority = 'critical' THEN v_driver_employee_id ELSE NULL END,
        v_employee_id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_driver_task_id;
    
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
            'deliver',
            'FOR DELIVERY: ' ||
            CASE WHEN p_hire_duration IS NOT NULL 
                 THEN 'Hire duration: ' || p_hire_duration || ' ' || p_hire_period_type || ' - '
                 ELSE '' END ||
            COALESCE(v_equipment_item->>'special_requirements', 'Check condition before delivery'),
            CURRENT_TIMESTAMP
        );
    END LOOP;
    
    -- =============================================================================
    -- AUDIT LOGGING
    -- =============================================================================
    
    -- Log hire creation
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
        'create_hire',
        'interactions',
        v_interaction_id,
        jsonb_build_object(
            'reference_number', v_reference_number,
            'customer_name', v_customer_name,
            'site_name', v_site_name,
            'delivery_date', p_deliver_date,
            'equipment_count', v_equipment_count,
            'total_quantity', v_total_quantity,
            'hire_duration', p_hire_duration,
            'hire_period_type', p_hire_period_type,
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
        ('Hire ' || v_reference_number || ' created for ' || v_customer_name || '. ' ||
         'Delivery scheduled for ' || p_deliver_date || ' at ' || p_deliver_time || '. ' ||
         CASE WHEN p_priority = 'critical' 
              THEN 'Driver ' || v_driver_employee_name || ' assigned for critical delivery.'
              ELSE 'Delivery task created for assignment.'
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
        -- Handle any unique constraint violations
        RETURN QUERY SELECT 
            false, 
            'Duplicate hire request detected.'::TEXT,
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
$HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
-- These would be set in the permissions script, but documented here:
-- GRANT EXECUTE ON FUNCTION interactions.create_hire TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.create_hire TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.create_hire TO owner;

COMMENT ON FUNCTION interactions.create_hire IS 
'Process equipment hire/delivery requests from customers.
Creates hire interaction with equipment list and delivery details.
Automatically creates driver delivery task with appropriate priority.
Handles various delivery methods and hire duration specifications.
Designed to work with off-hire procedure for complete hire/off-hire workflow.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Standard hire (John Guy scenario)
SELECT * FROM interactions.create_hire(
    1000,                                   -- p_customer_id (ABC Construction)
    1000,                                   -- p_contact_id (John Guy)
    1001,                                   -- p_site_id (Sandton Project Site)
    '[
        {
            "equipment_category_id": 5,
            "quantity": 1,
            "special_requirements": "Include all accessories"
        },
        {
            "equipment_category_id": 8,
            "quantity": 2,
            "special_requirements": "Fuel tanks to be full"
        }
    ]'::jsonb,                             -- p_equipment_list
    '2025-06-10',                          -- p_deliver_date
    'medium',                              -- p_priority
    '08:00'::TIME,                         -- p_deliver_time
    '2025-06-10',                          -- p_start_date
    '08:30'::TIME,                         -- p_start_time
    'deliver',                             -- p_delivery_method
    14,                                    -- p_hire_duration
    'days',                                -- p_hire_period_type
    'Equipment needed for foundation work. Deliver to main gate, ask for site foreman.',
    'phone',                               -- p_contact_method
    'Customer called requesting equipment for new project starting Monday',
    1001                                   -- p_employee_id
);

-- Example 2: Critical/urgent hire (weekend delivery)
SELECT * FROM interactions.create_hire(
    1001,                                   -- p_customer_id
    1002,                                   -- p_contact_id
    1002,                                   -- p_site_id
    '[
        {
            "equipment_category_id": 3,
            "quantity": 1,
            "special_requirements": "Emergency delivery - equipment breakdown replacement"
        }
    ]'::jsonb,                             -- p_equipment_list
    '2025-06-08',                          -- p_deliver_date (weekend)
    'critical',                            -- p_priority (critical = urgent with driver assignment)
    '07:00'::TIME,                         -- p_deliver_time (early delivery)
    '2025-06-08',                          -- p_start_date
    '07:00'::TIME,                         -- p_start_time
    'deliver',                             -- p_delivery_method
    3,                                     -- p_hire_duration (short term)
    'days',                                -- p_hire_period_type
    'URGENT: Replace broken equipment. Customer waiting on site. Contact site manager on arrival.',
    'phone',                               -- p_contact_method
    'Emergency call - customer equipment breakdown, project halted',
    1001                                   -- p_employee_id
);

-- Example 3: Counter pickup (customer collecting)
SELECT * FROM interactions.create_hire(
    1002,                                   -- p_customer_id
    1003,                                   -- p_contact_id
    1003,                                   -- p_site_id (depot/head office)
    '[
        {
            "equipment_category_id": 7,
            "quantity": 1,
            "special_requirements": "Customer pickup - prepare for collection"
        }
    ]'::jsonb,                             -- p_equipment_list
    '2025-06-09',                          -- p_deliver_date (pickup date)
    'medium',                              -- p_priority
    '10:00'::TIME,                         -- p_deliver_time (pickup time)
    '2025-06-09',                          -- p_start_date
    '10:30'::TIME,                         -- p_start_time
    'counter',                             -- p_delivery_method (customer pickup)
    7,                                     -- p_hire_duration
    'days',                                -- p_hire_period_type
    'Customer collecting equipment. Ensure demonstration and safety briefing completed.',
    'email',                               -- p_contact_method
    'Customer requested pickup due to transportation availability',
    1002                                   -- p_employee_id
);

-- Example 4: Long-term hire with weekly equipment
SELECT * FROM interactions.create_hire(
    1003,                                   -- p_customer_id
    1004,                                   -- p_contact_id
    1004,                                   -- p_site_id
    '[
        {
            "equipment_category_id": 1,
            "quantity": 3,
            "special_requirements": "Long-term project hire"
        },
        {
            "equipment_category_id": 4,
            "quantity": 1,
            "special_requirements": "Weekly maintenance required"
        }
    ]'::jsonb,                             -- p_equipment_list
    '2025-06-12',                          -- p_deliver_date
    'medium',                              -- p_priority
    '09:00'::TIME,                         -- p_deliver_time
    '2025-06-12',                          -- p_start_date
    '09:00'::TIME,                         -- p_start_time
    'deliver',                             -- p_delivery_method
    12,                                    -- p_hire_duration
    'weeks',                               -- p_hire_period_type (weeks not days)
    'Major construction project. Equipment will be on site for extended period. Arrange for weekly inspections.',
    'email',                               -- p_contact_method
    'Long-term contract hire for major development project',
    1001                                   -- p_employee_id
);
*/