SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_available_individual_equipment(
    p_equipment_type_id INTEGER DEFAULT NULL,
    p_delivery_date DATE DEFAULT CURRENT_DATE,
    p_return_date DATE DEFAULT NULL
)
RETURNS TABLE(
    equipment_id INTEGER,
    equipment_type_id INTEGER,
    asset_code VARCHAR(20),
    type_name VARCHAR(255),
    model VARCHAR(100),
    condition VARCHAR(20),
    serial_number VARCHAR(50),
    last_service_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.equipment_type_id,
        e.asset_code,
        et.type_name,
        e.model,
        e.condition,
        e.serial_number,
        e.last_service_date
    FROM core.equipment e
    JOIN core.equipment_types et ON e.equipment_type_id = et.id
    WHERE 
        e.status = 'available'
        AND e.condition IN ('excellent', 'good', 'fair')
        AND (p_equipment_type_id IS NULL OR e.equipment_type_id = p_equipment_type_id)
        -- TODO: Add date range availability checking against existing hires
    ORDER BY 
        et.type_name,
        e.condition DESC,
        e.asset_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_available_individual_equipment IS 'Get individual equipment units for specific allocation';