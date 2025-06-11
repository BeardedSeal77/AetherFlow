-- =============================================================================
-- 2. CREATE DRIVER TASK
-- =============================================================================

-- Helper function to create a driver task with standardized format
DROP FUNCTION IF EXISTS tasks.create_driver_task;

CREATE OR REPLACE FUNCTION tasks.create_driver_task(
    p_interaction_id INTEGER,
    p_task_type VARCHAR(50),        -- 'delivery', 'collection', 'repair', 'swap', 'coring', 'task'
    p_priority VARCHAR(20),
    p_customer_name VARCHAR(255),
    p_contact_name TEXT,
    p_contact_phone VARCHAR(20),
    p_site_address TEXT,
    p_equipment_summary TEXT,
    p_scheduled_date DATE,
    p_scheduled_time TIME,
    p_estimated_duration INTEGER,
    p_special_instructions TEXT,
    p_assigned_to INTEGER DEFAULT NULL,
    p_created_by INTEGER DEFAULT NULL
)
RETURNS TABLE(
    task_id INTEGER,
    assigned_driver_name TEXT,
    task_status VARCHAR(20)
) AS $CREATE_TASK$
DECLARE
    v_task_id INTEGER;
    v_task_status VARCHAR(20);
    v_assigned_driver_name TEXT;
    v_task_title TEXT;
    v_task_description TEXT;
    v_priority_adjustment INTEGER := 0;
BEGIN
    -- Validate interaction exists
    IF NOT EXISTS (SELECT 1 FROM interactions.interactions WHERE id = p_interaction_id) THEN
        RAISE EXCEPTION 'Interaction ID % does not exist', p_interaction_id;
    END IF;
    
    -- Build standardized task title and description
    v_task_title := UPPER(p_task_type) || ': ' || p_customer_name || 
                   ' - ' || COALESCE(p_equipment_summary, 'Equipment task');
    
    v_task_description := UPPER(p_task_type) || ' TASK' || E'\n\n' ||
                         'Customer: ' || p_customer_name || E'\n' ||
                         'Contact: ' || COALESCE(p_contact_name, 'N/A') || E'\n' ||
                         'Phone: ' || COALESCE(p_contact_phone, 'N/A') || E'\n' ||
                         'Address: ' || COALESCE(p_site_address, 'N/A') || E'\n' ||
                         'Equipment: ' || COALESCE(p_equipment_summary, 'See interaction for details') || E'\n';
    
    IF p_special_instructions IS NOT NULL THEN
        v_task_description := v_task_description || E'\nSpecial Instructions: ' || p_special_instructions;
    END IF;
    
    -- Set task status based on driver assignment
    IF p_assigned_to IS NOT NULL THEN
        v_task_status := 'assigned';
        
        -- Get driver name
        SELECT name || ' ' || surname INTO v_assigned_driver_name
        FROM core.employees
        WHERE id = p_assigned_to AND role = 'driver' AND status = 'active';
        
        IF v_assigned_driver_name IS NULL THEN
            RAISE EXCEPTION 'Driver ID % not found or not active', p_assigned_to;
        END IF;
    ELSE
        v_task_status := 'backlog';
        v_assigned_driver_name := 'Unassigned';
    END IF;
    
    -- Insert the driver task
    INSERT INTO tasks.drivers_taskboard (
        interaction_id,
        created_by,
        assigned_to,
        task_type,
        priority,
        status,
        scheduled_date,
        scheduled_time,
        estimated_duration,
        customer_name,
        contact_name,
        contact_phone,
        site_address,
        equipment_summary,
        special_instructions,
        task_title,
        task_description,
        created_at,
        updated_at
    ) VALUES (
        p_interaction_id,
        p_created_by,
        p_assigned_to,
        p_task_type,
        p_priority,
        v_task_status,
        p_scheduled_date,
        p_scheduled_time,
        p_estimated_duration,
        p_customer_name,
        p_contact_name,
        p_contact_phone,
        p_site_address,
        p_equipment_summary,
        p_special_instructions,
        v_task_title,
        v_task_description,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_task_id;
    
    -- Return task details
    RETURN QUERY SELECT v_task_id, v_assigned_driver_name, v_task_status;
    
END;
$CREATE_TASK$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION tasks.create_driver_task IS 
'Creates standardized driver tasks with proper formatting.
Validates interaction exists, builds task title/description, handles driver assignment.
Used by all interaction procedures creating driver tasks.';

GRANT EXECUTE ON FUNCTION tasks.create_driver_task TO PUBLIC;