SET search_path TO core, interactions, tasks, system, public;

-- 9.1 Get Driver Tasks (for drivers taskboard)
CREATE OR REPLACE FUNCTION sp_get_driver_tasks(
    p_driver_id INTEGER DEFAULT NULL,
    p_status_filter VARCHAR(50) DEFAULT NULL,
    p_date_from DATE DEFAULT CURRENT_DATE,
    p_date_to DATE DEFAULT CURRENT_DATE + INTERVAL '7 days'
)
RETURNS TABLE(
    task_id INTEGER,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    task_type VARCHAR(50),
    priority VARCHAR(20),
    status VARCHAR(50),
    customer_name VARCHAR(255),
    contact_name VARCHAR(255),
    contact_phone VARCHAR(20),
    contact_whatsapp VARCHAR(20),
    site_address TEXT,
    scheduled_date DATE,
    scheduled_time TIME,
    equipment_allocated BOOLEAN,
    equipment_verified BOOLEAN,
    status_booked VARCHAR(10),
    status_driver VARCHAR(10),
    status_quality_control VARCHAR(10),
    status_whatsapp VARCHAR(10),
    equipment_summary TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dt.id,
        dt.interaction_id,
        i.reference_number,
        dt.task_type,
        dt.priority,
        dt.status,
        dt.customer_name,
        dt.contact_name,
        dt.contact_phone,
        dt.contact_whatsapp,
        dt.site_address,
        dt.scheduled_date,
        dt.scheduled_time,
        dt.equipment_allocated,
        dt.equipment_verified,
        dt.status_booked,
        dt.status_driver,
        dt.status_quality_control,
        dt.status_whatsapp,
        -- Generate equipment summary
        (SELECT string_agg(
            et.type_code || ' (' || iet.quantity || ')',
            ', ' ORDER BY et.type_name
        )
        FROM interactions.interaction_equipment_types iet
        JOIN core.equipment_types et ON iet.equipment_type_id = et.id
        WHERE iet.interaction_id = dt.interaction_id
        ) AS equipment_summary
    FROM tasks.drivers_taskboard dt
    JOIN interactions.interactions i ON dt.interaction_id = i.id
    WHERE 
        (p_driver_id IS NULL OR dt.assigned_to = p_driver_id)
        AND (p_status_filter IS NULL OR dt.status = p_status_filter)
        AND (dt.scheduled_date BETWEEN p_date_from AND p_date_to OR dt.scheduled_date IS NULL)
    ORDER BY 
        CASE dt.priority
            WHEN 'urgent' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            WHEN 'low' THEN 4
        END,
        dt.scheduled_date NULLS LAST,
        dt.scheduled_time NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_driver_tasks IS 'Get driver tasks for the drivers taskboard';