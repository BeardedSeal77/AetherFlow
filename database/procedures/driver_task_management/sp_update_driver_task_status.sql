SET search_path TO core, interactions, tasks, system, public;

-- 9.2 Update Driver Task Status
CREATE OR REPLACE FUNCTION sp_update_driver_task_status(
    p_task_id INTEGER,
    p_status VARCHAR(50) DEFAULT NULL,
    p_status_booked VARCHAR(10) DEFAULT NULL,
    p_status_driver VARCHAR(10) DEFAULT NULL,
    p_status_quality_control VARCHAR(10) DEFAULT NULL,
    p_status_whatsapp VARCHAR(10) DEFAULT NULL,
    p_assigned_to INTEGER DEFAULT NULL,
    p_completion_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    updated_status VARCHAR(50)
) AS $$
DECLARE
    current_task RECORD;
    new_status VARCHAR(50);
BEGIN
    -- Get current task
    SELECT * INTO current_task
    FROM tasks.drivers_taskboard
    WHERE id = p_task_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Driver task not found', NULL::VARCHAR(50);
        RETURN;
    END IF;
    
    -- Determine new status if not explicitly provided
    new_status := COALESCE(p_status, current_task.status);
    
    BEGIN
        -- Update the task
        UPDATE tasks.drivers_taskboard
        SET 
            status = new_status,
            status_booked = COALESCE(p_status_booked, status_booked),
            status_driver = COALESCE(p_status_driver, status_driver),
            status_quality_control = COALESCE(p_status_quality_control, status_quality_control),
            status_whatsapp = COALESCE(p_status_whatsapp, status_whatsapp),
            assigned_to = COALESCE(p_assigned_to, assigned_to),
            completion_notes = COALESCE(p_completion_notes, completion_notes),
            completed_at = CASE WHEN new_status = 'completed' THEN CURRENT_TIMESTAMP ELSE completed_at END,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_task_id;
        
        -- Update interaction status if task completed
        IF new_status = 'completed' THEN
            UPDATE interactions.interactions
            SET status = 'completed', completed_at = CURRENT_TIMESTAMP
            WHERE id = current_task.interaction_id;
        END IF;
        
        RETURN QUERY SELECT TRUE, 'Driver task updated successfully', new_status;
        
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, 'Error updating driver task: ' || SQLERRM, NULL::VARCHAR(50);
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_update_driver_task_status IS 'Update driver task status and progress indicators';