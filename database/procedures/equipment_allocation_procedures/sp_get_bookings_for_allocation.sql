SET search_path TO core, interactions, tasks, system, public;

-- 7.1 Get Generic Bookings Ready for Allocation
CREATE OR REPLACE FUNCTION sp_get_bookings_for_allocation(
    p_interaction_id INTEGER DEFAULT NULL,
    p_only_unallocated BOOLEAN DEFAULT TRUE
)
RETURNS TABLE(
    booking_id INTEGER,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    customer_name VARCHAR(255),
    equipment_type_id INTEGER,
    type_name VARCHAR(255),
    type_code VARCHAR(20),
    booked_quantity INTEGER,
    allocated_quantity INTEGER,
    remaining_quantity INTEGER,
    booking_status VARCHAR(20),
    hire_start_date DATE,
    hire_end_date DATE,
    delivery_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        iet.id,
        iet.interaction_id,
        i.reference_number,
        c.customer_name,
        iet.equipment_type_id,
        et.type_name,
        et.type_code,
        iet.quantity AS booked_quantity,
        COUNT(ie.id)::INTEGER AS allocated_quantity,
        (iet.quantity - COUNT(ie.id))::INTEGER AS remaining_quantity,
        iet.booking_status,
        iet.hire_start_date,
        iet.hire_end_date,
        dt.scheduled_date AS delivery_date
    FROM interactions.interaction_equipment_types iet
    JOIN interactions.interactions i ON iet.interaction_id = i.id
    JOIN core.customers c ON i.customer_id = c.id
    JOIN core.equipment_types et ON iet.equipment_type_id = et.id
    LEFT JOIN interactions.interaction_equipment ie ON iet.id = ie.equipment_type_booking_id
    LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
    WHERE 
        (p_interaction_id IS NULL OR iet.interaction_id = p_interaction_id)
        AND (p_only_unallocated = FALSE OR iet.booking_status = 'booked')
    GROUP BY iet.id, iet.interaction_id, i.reference_number, c.customer_name,
             iet.equipment_type_id, et.type_name, et.type_code, iet.quantity,
             iet.booking_status, iet.hire_start_date, iet.hire_end_date, dt.scheduled_date
    HAVING (p_only_unallocated = FALSE OR (iet.quantity - COUNT(ie.id)) > 0)
    ORDER BY dt.scheduled_date, i.reference_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_bookings_for_allocation IS 'Get generic equipment bookings ready for Phase 2 allocation';