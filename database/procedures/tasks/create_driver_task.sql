-- =============================================================================
-- TASKS: STANDARDIZED DRIVER TASK CREATION HELPER
-- =============================================================================
-- Purpose: Create standardized driver tasks with proper formatting
-- Used by: All interaction procedures creating driver tasks (hire, off-hire, breakdown)
-- Normalizes: Driver task creation across all procedures
-- Updated: 2025-06-11 - Enhanced to match actual table structure
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS tasks.create_driver_task;

-- Create the enhanced driver task creation helper
CREATE OR REPLACE FUNCTION tasks.create_driver_task(
    p_interaction_id INTEGER,
    p_task_type VARCHAR(50),        -- 'delivery', 'collection', 'repair', 'swap', 'coring', 'misc_driver_task'
    p_priority VARCHAR(20),         -- 'low', 'medium', 'high', 'urgent'
    p_customer_name VARCHAR(255),
    p_contact_name TEXT,
    p_contact_phone VARCHAR(20),
    p_site_address TEXT,
    p_equipment_summary TEXT,
    p_scheduled_date DATE,
    p_scheduled_time TIME DEFAULT '09:00'::TIME,
    p_estimated_duration INTEGER DEFAULT 90,  -- minutes
    p_special_instructions TEXT DEFAULT NULL,
    p_assigned_to INTEGER DEFAULT NULL,       -- driver employee ID
    p_created_by INTEGER DEFAULT NULL        -- creating employee ID
)
RETURNS TABLE(
    task_id INTEGER,
    assigned_driver_name TEXT,
    task_status VARCHAR(50)
) AS $CREATE_DRIVER_TASK$
DECLARE
    v_task_id INTEGER;
    v_task_status VARCHAR(50);
    v_assigned_driver_name TEXT;
    v_contact_whatsapp VARCHAR(20);
    v_site_delivery_instructions TEXT;
BEGIN
    -- =============================================================================
    -- VALIDATION
    -- =============================================================================
    
    -- Validate interaction exists
    IF NOT EXISTS (SELECT 1 FROM interactions.interactions WHERE id = p_interaction_id) THEN
        RAISE EXCEPTION 'Interaction ID % does not exist', p_interaction_id;
    END IF;
    
    -- Validate task type
    IF p_task_type NOT IN ('delivery', 'collection', 'swap', 'repair', 'coring', 'misc_driver_task') THEN
        RAISE EXCEPTION 'Invalid task type: %. Must be delivery, collection, swap, repair, coring, or misc_driver_task', p_task_type;
    END IF;
    
    -- Validate priority
    IF p_priority NOT IN ('low', 'medium', 'high', 'urgent') THEN
        RAISE EXCEPTION 'Invalid priority: %. Must be low, medium, high, or urgent', p_priority;
    END IF;
    
    -- =============================================================================
    -- DRIVER ASSIGNMENT AND STATUS
    -- =============================================================================
    
    -- Determine task status and get driver details
    IF p_assigned_to IS NOT NULL THEN
        -- Validate assigned driver exists and is active
        SELECT name || ' ' || surname 
        INTO v_assigned_driver_name
        FROM core.employees 
        WHERE id = p_assigned_to 
          AND role = 'driver' 
          AND status = 'active';
          
        IF v_assigned_driver_name IS NULL THEN
            RAISE EXCEPTION 'Driver ID % not found or not active', p_assigned_to;
        END IF;
        
        v_task_status := 'driver_1';  -- Assigned to specific driver
    ELSE
        -- No driver assigned - goes to backlog
        v_task_status := 'backlog';
        v_assigned_driver_name := NULL;
    END IF;
    
    -- =============================================================================
    -- ADDITIONAL DATA PREPARATION
    -- =============================================================================
    
    -- Try to extract WhatsApp number from phone (simple approach)
    v_contact_whatsapp := CASE 
        WHEN p_contact_phone IS NOT NULL AND p_contact_phone ~ '^\+27[0-9]{9}$' THEN p_contact_phone
        ELSE NULL
    END;
    
    -- Set site delivery instructions based on task type
    v_site_delivery_instructions := CASE p_task_type
        WHEN 'delivery' THEN 'Standard delivery procedure - check equipment condition before delivery'
        WHEN 'collection' THEN 'Standard collection procedure - document equipment condition'
        WHEN 'repair' THEN 'Repair task - bring necessary tools and parts'
        WHEN 'swap' THEN 'Equipment swap - bring replacement equipment'
        WHEN 'coring' THEN 'Coring service task - specialized equipment required'
        ELSE 'Standard driver task procedure'
    END;
    
    -- =============================================================================
    -- CREATE DRIVER TASK RECORD
    -- =============================================================================
    
    INSERT INTO tasks.drivers_taskboard (
        interaction_id,
        assigned_to,
        task_type,
        priority,
        status,
        customer_name,
        contact_name,
        contact_phone,
        contact_whatsapp,
        site_address,
        site_delivery_instructions,
        equipment_summary,
        equipment_verified,
        scheduled_date,
        scheduled_time,
        estimated_duration,
        -- Progress tracking columns (all default to 'no')
        status_booked,
        status_driver,
        status_quality_control,
        status_whatsapp,
        -- Timestamps and references
        created_by,
        created_at,
        updated_at
    ) VALUES (
        p_interaction_id,
        p_assigned_to,
        p_task_type,
        p_priority,
        v_task_status,
        p_customer_name,
        p_contact_name,
        p_contact_phone,
        v_contact_whatsapp,
        p_site_address,
        COALESCE(p_special_instructions, v_site_delivery_instructions),
        p_equipment_summary,
        false,  -- equipment not yet verified
        p_scheduled_date,
        p_scheduled_time,
        p_estimated_duration,
        -- Progress tracking defaults
        'no',   -- status_booked
        'no',   -- status_driver
        'no',   -- status_quality_control
        'no',   -- status_whatsapp
        -- Timestamps
        p_created_by,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_task_id;
    
    -- =============================================================================
    -- AUTO-ASSIGNMENT FOR URGENT TASKS
    -- =============================================================================
    
    -- For urgent tasks, try to auto-assign if no driver specified
    IF p_priority = 'urgent' AND p_assigned_to IS NULL THEN
        -- Find best available driver for urgent task
        SELECT driver_id, driver_name INTO p_assigned_to, v_assigned_driver_name
        FROM tasks.find_available_driver(p_scheduled_date, p_priority)
        LIMIT 1;
        
        -- Update task with assigned driver if found
        IF p_assigned_to IS NOT NULL THEN
            UPDATE tasks.drivers_taskboard 
            SET assigned_to = p_assigned_to,
                status = 'driver_1',
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_task_id;
            
            v_task_status := 'driver_1';
        END IF;
    END IF;
    
    -- =============================================================================
    -- RETURN TASK DETAILS
    -- =============================================================================
    
    RETURN QUERY SELECT 
        v_task_id,
        COALESCE(v_assigned_driver_name, 'Unassigned'),
        v_task_status;
        
EXCEPTION 
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Invalid reference data: interaction_id=%, assigned_to=%, created_by=%', 
            p_interaction_id, p_assigned_to, p_created_by;
    WHEN check_violation THEN
        RAISE EXCEPTION 'Invalid data values: task_type=%, priority=%, status=%', 
            p_task_type, p_priority, v_task_status;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Driver task creation failed: %', SQLERRM;
END;
$CREATE_DRIVER_TASK$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION tasks.create_driver_task TO PUBLIC;

COMMENT ON FUNCTION tasks.create_driver_task IS 
'Standardized driver task creation helper used by all interaction procedures.
Creates properly formatted driver tasks with automatic validation and driver assignment.
Handles all task types: delivery, collection, repair, swap, coring, misc_driver_task.
Includes progress tracking setup and urgent task auto-assignment.
Normalizes driver task creation across hire, off-hire, breakdown, and other procedures.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Standard delivery task (no driver assigned)
SELECT * FROM tasks.create_driver_task(
    1001,                                   -- interaction_id
    'delivery',                             -- task_type
    'medium',                               -- priority
    'ABC Construction Ltd',                 -- customer_name
    'John Smith',                           -- contact_name
    '+27123456789',                         -- contact_phone
    '123 Main St, Johannesburg, 2001',     -- site_address
    'Compactor (x1), Safety Barriers (x4)', -- equipment_summary
    '2025-06-12',                           -- scheduled_date
    '09:00'::TIME,                          -- scheduled_time
    90,                                     -- estimated_duration (minutes)
    'Deliver to main gate, ask for John',  -- special_instructions
    NULL,                                   -- assigned_to (no driver assigned)
    1001                                    -- created_by (employee_id)
);

-- Example 2: Urgent collection task with specific driver
SELECT * FROM tasks.create_driver_task(
    1002,                                   -- interaction_id
    'collection',                           -- task_type
    'urgent',                               -- priority (will auto-assign if no driver specified)
    'XYZ Mining Corp',                      -- customer_name
    'Sarah Johnson',                        -- contact_name
    '+27987654321',                         -- contact_phone
    '456 Industrial Ave, Germiston, 1401', -- site_address
    'Drill Rig (x1), Compressor (x1)',     -- equipment_summary
    CURRENT_DATE,                           -- scheduled_date (today - urgent)
    '14:00'::TIME,                          -- scheduled_time
    120,                                    -- estimated_duration (2 hours)
    'URGENT: Site closing for inspection',  -- special_instructions
    1003,                                   -- assigned_to (specific driver)
    1001                                    -- created_by (employee_id)
);
*/