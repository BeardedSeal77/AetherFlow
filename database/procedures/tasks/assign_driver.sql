-- =============================================================================
-- 3. ASSIGN DRIVER TO TASK
-- =============================================================================
SET search_path TO core, interactions, tasks, security, system, public;


-- Helper function to assign a driver to an existing task
DROP FUNCTION IF EXISTS tasks.assign_driver_to_task;

CREATE OR REPLACE FUNCTION tasks.assign_driver_to_task(
    p_task_id INTEGER,
    p_driver_id INTEGER DEFAULT NULL,  -- If NULL, find best available driver
    p_assigned_by INTEGER DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    assigned_driver_name TEXT,
    assigned_driver_id INTEGER
) AS $ASSIGN_DRIVER$
DECLARE
    v_task_record RECORD;
    v_driver_id INTEGER;
    v_driver_name TEXT;
    v_assigned_by_name TEXT;
BEGIN
    -- Get task details
    SELECT dt.*, i.reference_number
    INTO v_task_record
    FROM tasks.drivers_taskboard dt
    JOIN interactions.interactions i ON i.id = dt.interaction_id
    WHERE dt.id = p_task_id;
    
    IF v_task_record IS NULL THEN
        RETURN QUERY SELECT false, 'Task not found'::TEXT, NULL::TEXT, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- If driver not specified, find the best available driver
    IF p_driver_id IS NULL THEN
        SELECT driver_id, driver_name 
        INTO v_driver_id, v_driver_name
        FROM tasks.find_available_driver(v_task_record.scheduled_date, v_task_record.priority