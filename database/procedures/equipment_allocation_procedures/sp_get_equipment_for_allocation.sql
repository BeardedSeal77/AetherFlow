SET search_path TO core, interactions, tasks, system, public;

-- 7.2 Get Available Equipment for Allocation
CREATE OR REPLACE FUNCTION sp_get_equipment_for_allocation(
    p_equipment_type_id INTEGER,
    p_delivery_date DATE DEFAULT CURRENT_DATE,
    p_return_date DATE DEFAULT NULL
)
RETURNS TABLE(
    equipment_id INTEGER,
    asset_code VARCHAR(20),
    model VARCHAR(100),
    condition VARCHAR(20),
    serial_number VARCHAR(50),
    last_service_date DATE,
    next_service_due DATE,
    location VARCHAR(100),
    is_available BOOLEAN,
    conflict_reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.asset_code,
        e.model,
        e.condition,
        e.serial_number,
        e.last_service_date,
        e.next_service_due,
        e.location,
        (e.status = 'available' AND 
         (e.next_service_due IS NULL OR e.next_service_due > p_delivery_date)) AS is_available,
        CASE 
            WHEN e.status != 'available' THEN 'Equipment status: ' || e.status
            WHEN e.next_service_due IS NOT NULL AND e.next_service_due <= p_delivery_date 
                THEN 'Service due: ' || e.next_service_due::TEXT
            ELSE NULL
        END AS conflict_reason
    FROM core.equipment e
    WHERE e.equipment_type_id = p_equipment_type_id
    ORDER BY 
        (e.status = 'available' AND 
         (e.next_service_due IS NULL OR e.next_service_due > p_delivery_date)) DESC,
        e.condition DESC,
        e.asset_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_equipment_for_allocation IS 'Get available equipment units for allocation to bookings';