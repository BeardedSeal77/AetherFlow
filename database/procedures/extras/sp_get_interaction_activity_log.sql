SET search_path TO core, interactions, tasks, system, public;

-- Procedure to get interaction activity log
CREATE OR REPLACE FUNCTION sp_get_interaction_activity_log(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    activity_date TIMESTAMP WITH TIME ZONE,
    activity_type VARCHAR(50),
    description TEXT,
    employee_name TEXT,
    details JSONB
) AS $$
BEGIN
    RETURN QUERY
    -- Interaction creation
    SELECT 
        i.created_at,
        'interaction_created'::VARCHAR(50),
        'Hire interaction created',
        (e.name || ' ' || e.surname),
        jsonb_build_object(
            'reference_number', i.reference_number,
            'customer', c.customer_name,
            'contact_method', i.contact_method
        )
    FROM interactions.interactions i
    JOIN core.employees e ON i.employee_id = e.id
    JOIN core.customers c ON i.customer_id = c.id
    WHERE i.id = p_interaction_id
    
    UNION ALL
    
    -- Equipment allocations
    SELECT 
        ie.allocated_at,
        'equipment_allocated'::VARCHAR(50),
        'Equipment allocated: ' || e.asset_code,
        (emp.name || ' ' || emp.surname),
        jsonb_build_object(
            'equipment_id', ie.equipment_id,
            'asset_code', e.asset_code,
            'type', et.type_name
        )
    FROM interactions.interaction_equipment ie
    JOIN core.equipment e ON ie.equipment_id = e.id
    JOIN core.equipment_types et ON e.equipment_type_id = et.id
    JOIN core.employees emp ON ie.allocated_by = emp.id
    WHERE ie.interaction_id = p_interaction_id
    
    UNION ALL
    
    -- Quality control activities
    SELECT 
        ie.quality_checked_at,
        'quality_control'::VARCHAR(50),
        'QC ' || ie.quality_check_status || ': ' || e.asset_code,
        (emp.name || ' ' || emp.surname),
        jsonb_build_object(
            'equipment_id', ie.equipment_id,
            'asset_code', e.asset_code,
            'status', ie.quality_check_status,
            'notes', ie.quality_check_notes
        )
    FROM interactions.interaction_equipment ie
    JOIN core.equipment e ON ie.equipment_id = e.id
    LEFT JOIN core.employees emp ON ie.quality_checked_by = emp.id
    WHERE ie.interaction_id = p_interaction_id
      AND ie.quality_checked_at IS NOT NULL
    
    UNION ALL
    
    -- Driver task updates
    SELECT 
        dt.updated_at,
        'driver_task_updated'::VARCHAR(50),
        'Driver task status: ' || dt.status,
        COALESCE((emp.name || ' ' || emp.surname), 'System'),
        jsonb_build_object(
            'task_type', dt.task_type,
            'status', dt.status,
            'scheduled_date', dt.scheduled_date,
            'equipment_allocated', dt.equipment_allocated,
            'equipment_verified', dt.equipment_verified
        )
    FROM tasks.drivers_taskboard dt
    LEFT JOIN core.employees emp ON dt.assigned_to = emp.id
    WHERE dt.interaction_id = p_interaction_id
    
    ORDER BY activity_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_interaction_activity_log IS 'Get chronological activity log for an interaction';