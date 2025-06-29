SET search_path TO core, interactions, tasks, system, public;

-- 8.1 Get Equipment Pending Quality Control
CREATE OR REPLACE FUNCTION sp_get_equipment_pending_qc(
    p_interaction_id INTEGER DEFAULT NULL,
    p_employee_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    allocation_id INTEGER,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    customer_name VARCHAR(255),
    equipment_id INTEGER,
    asset_code VARCHAR(20),
    type_name VARCHAR(255),
    model VARCHAR(100),
    condition VARCHAR(20),
    allocated_at TIMESTAMP WITH TIME ZONE,
    allocated_by_name TEXT,
    delivery_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.id,
        ie.interaction_id,
        i.reference_number,
        c.customer_name,
        ie.equipment_id,
        e.asset_code,
        et.type_name,
        e.model,
        e.condition,
        ie.allocated_at,
        (emp.name || ' ' || emp.surname) AS allocated_by_name,
        dt.scheduled_date AS delivery_date
    FROM interactions.interaction_equipment ie
    JOIN interactions.interactions i ON ie.interaction_id = i.id
    JOIN core.customers c ON i.customer_id = c.id
    JOIN core.equipment e ON ie.equipment_id = e.id
    JOIN core.equipment_types et ON e.equipment_type_id = et.id
    JOIN core.employees emp ON ie.allocated_by = emp.id
    LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
    WHERE 
        ie.quality_check_status = 'pending'
        AND (p_interaction_id IS NULL OR ie.interaction_id = p_interaction_id)
        AND (p_employee_id IS NULL OR ie.allocated_by = p_employee_id)
    ORDER BY dt.scheduled_date, i.reference_number, e.asset_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_equipment_pending_qc IS 'Get equipment allocations pending quality control';