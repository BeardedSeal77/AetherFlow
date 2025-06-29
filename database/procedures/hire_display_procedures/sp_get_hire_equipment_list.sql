SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_hire_equipment_list(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    equipment_type_id INTEGER,
    type_name VARCHAR(255),
    type_code VARCHAR(20),
    booked_quantity INTEGER,
    allocated_quantity INTEGER,
    booking_status VARCHAR(20),
    hire_start_date DATE,
    hire_end_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        iet.equipment_type_id,
        et.type_name,
        et.type_code,
        iet.quantity AS booked_quantity,
        COUNT(ie.id)::INTEGER AS allocated_quantity,
        iet.booking_status,
        iet.hire_start_date,
        iet.hire_end_date
    FROM interactions.interaction_equipment_types iet
    JOIN core.equipment_types et ON iet.equipment_type_id = et.id
    LEFT JOIN interactions.interaction_equipment ie ON iet.id = ie.equipment_type_booking_id
    WHERE iet.interaction_id = p_interaction_id
    GROUP BY iet.id, iet.equipment_type_id, et.type_name, et.type_code,
             iet.quantity, iet.booking_status, iet.hire_start_date, iet.hire_end_date
    ORDER BY et.type_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_hire_equipment_list IS 'Get equipment list with booking and allocation status';