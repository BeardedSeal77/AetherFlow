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
BEGIN
    -- Build standardized task title and description
    v_task_title := UPPER(p_task_type) || ': ' || p_customer_name || 
                   ' - ' || COALESCE(p_equipment_summary, 'Equipment task');
    
    v_task_description := UPPER(p_task_type) || ' TASK' || E'\n\n' ||
                         'Customer: ' || p_customer_name || E'\n' ||
                         'Contact: ' || COALESCE(p_contact_name, 'N/A') || E'\n' ||
                         'Phone: ' || COALESCE(p_contact_phone, 'N/A') || E'\n' ||
                         'Address: ' || COALESCE(p_site_address, 'N/A') || E'\n' ||
                         'Equipment: ' || COALESCE(p_equipment_summary, 'See task details') || E'\n' ||
                         'Scheduled: ' || p_scheduled_date || ' at ' || p_scheduled_time || E'\n\n' ||
                         CASE p_task_type
                           WHEN 'delivery' THEN 
                             '- Load equipment at depot' || E'\n' ||
                             '- Check equipment condition and safety' || E'\n' ||
                             '- Deliver to customer site on time' || E'\n' ||
                             '- Set up equipment as required' || E'\n' ||
                             '- Get customer signature on delivery note' || E'\n' ||
                             '- Update delivery status and notify office'
                           WHEN 'collection' THEN
                             '- Contact customer before collection' || E'\n' ||
                             '- Document any damage or issues' || E'\n' ||
                             '- Load equipment safely for transport' || E'\n' ||
                             '- Get customer signature on collection note' || E'\n' ||
                             '- Transport equipment back to depot' || E'\n' ||
                             '- Update collection status and notify office'
                           WHEN 'repair' THEN
                             '- Bring necessary tools and parts' || E'\n' ||
                             '- Diagnose equipment issue onsite' || E'\n' ||
                             '- Complete repair or arrange replacement' || E'\n' ||
                             '- Test equipment functionality' || E'\n' ||
                             '- Document work completed and parts used' || E'\n' ||
                             '- Get customer approval and signature'
                           WHEN 'swap' THEN
                             '- Bring replacement equipment' || E'\n' ||
                             '- Remove faulty equipment from site' || E'\n' ||
                             '- Install and test replacement equipment' || E'\n' ||
                             '- Ensure customer is satisfied with swap' || E'\n' ||
                             '- Transport faulty equipment to depot' || E'\n' ||
                             '- Update task status and notify office'
                           WHEN 'coring' THEN
                             '- Bring coring equipment and safety gear' || E'\n' ||
                             '- Set up coring equipment safely' || E'\n' ||
                             '- Complete coring work as specified' || E'\n' ||
                             '- Clean up work area thoroughly' || E'\n' ||
                             '- Document work completed and samples' || E'\n' ||
                             '- Get customer sign-off on completed work'
                           ELSE
                             '- Complete task as specified' || E'\n' ||
                             '- Follow all safety procedures' || E'\n' ||
                             '- Document work completed' || E'\n' ||
                             '- Update task status when finished'
                         END || E'\n\n' ||
                         'Special Instructions: ' || COALESCE(p_special_instructions, 'Standard procedure');
    
    -- Determine task status based on assignment
    IF p_assigned_to IS NOT NULL THEN
        v_task_status := 'assigned';
        SELECT name || ' ' || surname INTO v_assigned_driver_name
        FROM core.employees WHERE id = p_assigned_to;
    ELSE
        v_task_status := 'backlog';
        v_assigned_driver_name := NULL;
    END IF;
    
    -- Create the driver task
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
        p_interaction_id,
        p_task_type,
        v_task_status,
        p_priority,
        p_customer_name,
        p_contact_name,
        p_contact_phone,
        p_site_address,
        p_equipment_summary,
        p_scheduled_date,
        p_scheduled_time,
        p_estimated_duration,
        p_special_instructions,
        p_assigned_to,
        p_created_by,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_task_id;
    
    RETURN QUERY SELECT 
        v_task_id,
        v_assigned_driver_name,
        v_task_status;
END;
$CREATE_TASK$ LANGUAGE plpgsql SECURITY DEFINER;