SET search_path TO core, interactions, tasks, system, public;

-- 10.1 Get Hire Dashboard Summary
CREATE OR REPLACE FUNCTION sp_get_hire_dashboard_summary(
    p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_date_to DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    total_hires INTEGER,
    pending_hires INTEGER,
    completed_hires INTEGER,
    pending_allocations INTEGER,
    pending_qc INTEGER,
    driver_tasks_backlog INTEGER,
    total_equipment_allocated INTEGER,
    equipment_utilization_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER 
         FROM interactions.interactions 
         WHERE interaction_type = 'hire' 
           AND created_at::DATE BETWEEN p_date_from AND p_date_to) AS total_hires,
           
        (SELECT COUNT(*)::INTEGER 
         FROM interactions.interactions 
         WHERE interaction_type = 'hire' 
           AND status = 'pending'
           AND created_at::DATE BETWEEN p_date_from AND p_date_to) AS pending_hires,
           
        (SELECT COUNT(*)::INTEGER 
         FROM interactions.interactions 
         WHERE interaction_type = 'hire' 
           AND status = 'completed'
           AND created_at::DATE BETWEEN p_date_from AND p_date_to) AS completed_hires,
           
        (SELECT COUNT(*)::INTEGER 
         FROM interactions.interaction_equipment_types iet
         JOIN interactions.interactions i ON iet.interaction_id = i.id
         WHERE iet.booking_status = 'booked'
           AND i.created_at::DATE BETWEEN p_date_from AND p_date_to) AS pending_allocations,
           
        (SELECT COUNT(*)::INTEGER 
         FROM interactions.interaction_equipment ie
         JOIN interactions.interactions i ON ie.interaction_id = i.id
         WHERE ie.quality_check_status = 'pending'
           AND i.created_at::DATE BETWEEN p_date_from AND p_date_to) AS pending_qc,
           
        (SELECT COUNT(*)::INTEGER 
         FROM tasks.drivers_taskboard dt
         JOIN interactions.interactions i ON dt.interaction_id = i.id
         WHERE dt.status = 'backlog'
           AND i.created_at::DATE BETWEEN p_date_from AND p_date_to) AS driver_tasks_backlog,
           
        (SELECT COUNT(*)::INTEGER 
         FROM interactions.interaction_equipment ie
         JOIN interactions.interactions i ON ie.interaction_id = i.id
         WHERE ie.allocation_status IN ('allocated', 'delivered')
           AND i.created_at::DATE BETWEEN p_date_from AND p_date_to) AS total_equipment_allocated,
           
        (SELECT 
            CASE 
                WHEN COUNT(*) > 0 THEN 
                    ROUND((COUNT(CASE WHEN status = 'rented' THEN 1 END) * 100.0 / COUNT(*))::NUMERIC, 2)
                ELSE 0::DECIMAL(5,2)
            END
         FROM core.equipment 
         WHERE status IN ('available', 'rented')) AS equipment_utilization_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_hire_dashboard_summary IS 'Get summary statistics for hire management dashboard';