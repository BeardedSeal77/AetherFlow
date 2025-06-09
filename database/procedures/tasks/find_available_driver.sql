SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- 1. FIND AVAILABLE DRIVER
-- =============================================================================

-- Helper function to find the best available driver for a task
DROP FUNCTION IF EXISTS tasks.find_available_driver;

CREATE OR REPLACE FUNCTION tasks.find_available_driver(
    p_required_date DATE,
    p_priority VARCHAR(20) DEFAULT 'medium'
)
RETURNS TABLE(
    driver_id INTEGER,
    driver_name TEXT,
    current_workload INTEGER,
    availability_score INTEGER
) AS $FIND_DRIVER$
DECLARE
    v_driver_record RECORD;
    v_workload INTEGER;
    v_score INTEGER;
BEGIN
    -- Find drivers with their current workload for the required date
    FOR v_driver_record IN 
        SELECT 
            e.id,
            e.name || ' ' || e.surname as full_name,
            COUNT(dt.id) as task_count
        FROM core.employees e
        LEFT JOIN tasks.drivers_taskboard dt ON dt.assigned_to = e.id 
            AND dt.scheduled_date = p_required_date 
            AND dt.status NOT IN ('completed', 'cancelled')
        WHERE e.role = 'driver' 
        AND e.status = 'active'
        GROUP BY e.id, e.name, e.surname
        ORDER BY COUNT(dt.id) ASC, RANDOM() -- Least busy first, then random
    LOOP
        v_workload := v_driver_record.task_count;
        
        -- Calculate availability score (higher is better)
        v_score := CASE 
            WHEN v_workload = 0 THEN 100  -- Completely free
            WHEN v_workload <= 2 THEN 80  -- Light workload
            WHEN v_workload <= 4 THEN 60  -- Medium workload
            WHEN v_workload <= 6 THEN 40  -- Heavy workload
            ELSE 20                       -- Overloaded
        END;
        
        -- Boost score for high priority tasks if driver is not overloaded
        IF p_priority IN ('urgent', 'critical') AND v_workload <= 4 THEN
            v_score := v_score + 20;
        END IF;
        
        RETURN QUERY SELECT 
            v_driver_record.id,
            v_driver_record.full_name,
            v_workload,
            v_score;
    END LOOP;
    
    RETURN;
END;
$FIND_DRIVER$ LANGUAGE plpgsql SECURITY DEFINER;