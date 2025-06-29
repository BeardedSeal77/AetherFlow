SET search_path TO core, interactions, tasks, system, public;

-- 7.4 Get Allocation Status for Interaction
CREATE OR REPLACE FUNCTION sp_get_allocation_status(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    equipment_type_id INTEGER,
    type_name VARCHAR(255),
    booked_quantity INTEGER,
    allocated_quantity INTEGER,
    allocation_complete BOOLEAN,
    allocated_equipment JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        iet.equipment_type_id,
        et.type_name,
        iet.quantity AS booked_quantity,
        COUNT(ie.id)::INTEGER AS allocated_quantity,
        (iet.quantity = COUNT(ie.id)) AS allocation_complete,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'equipment_id', ie.equipment_id,
                    'asset_code', e.asset_code,
                    'model', e.model,
                    'condition', e.condition,
                    'quality_status', ie.quality_check_status
                ) ORDER BY e.asset_code
            ) FILTER (WHERE ie.id IS NOT NULL),
            '[]'::JSONB
        ) AS allocated_equipment
    FROM interactions.interaction_equipment_types iet
    JOIN core.equipment_types et ON iet.equipment_type_id = et.id
    LEFT JOIN interactions.interaction_equipment ie ON iet.id = ie.equipment_type_booking_id
    LEFT JOIN core.equipment e ON ie.equipment_id = e.id
    WHERE iet.interaction_id = p_interaction_id
    GROUP BY iet.id, iet.equipment_type_id, et.type_name, iet.quantity
    ORDER BY et.type_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_allocation_status IS 'Get allocation status and progress for an interaction';