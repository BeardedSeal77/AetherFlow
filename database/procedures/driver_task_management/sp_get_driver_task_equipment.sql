SET search_path TO core, interactions, tasks, system, public;

-- 9.3 Get Equipment List for Driver Task
CREATE OR REPLACE FUNCTION sp_get_driver_task_equipment(
    p_task_id INTEGER
)
RETURNS TABLE(
    equipment_type VARCHAR(255),
    asset_codes TEXT,
    quantity INTEGER,
    allocated_quantity INTEGER,
    verification_status TEXT,
    accessories TEXT
) AS $$
DECLARE
    task_interaction_id INTEGER;
BEGIN
    -- Get interaction ID for the task
    SELECT interaction_id INTO task_interaction_id
    FROM tasks.drivers_taskboard
    WHERE id = p_task_id;
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        et.type_name AS equipment_type,
        COALESCE(
            string_agg(e.asset_code, ', ' ORDER BY e.asset_code),
            'Not allocated'
        ) AS asset_codes,
        iet.quantity,
        COUNT(ie.id)::INTEGER AS allocated_quantity,
        CASE 
            WHEN COUNT(ie.id) = 0 THEN 'Not allocated'
            WHEN COUNT(ie.id) < iet.quantity THEN 'Partially allocated'
            WHEN COUNT(CASE WHEN ie.quality_check_status = 'passed' THEN 1 END) = iet.quantity THEN 'Ready'
            WHEN COUNT(CASE WHEN ie.quality_check_status = 'pending' THEN 1 END) > 0 THEN 'QC pending'
            ELSE 'QC issues'
        END AS verification_status,
        COALESCE(
            (SELECT string_agg(
                a.accessory_name || ' (' || ia.quantity || ')',
                ', ' ORDER BY a.accessory_name
            )
            FROM interactions.interaction_accessories ia
            JOIN core.accessories a ON ia.accessory_id = a.id
            WHERE ia.interaction_id = task_interaction_id
              AND (a.equipment_type_id = iet.equipment_type_id OR a.equipment_type_id IS NULL)
            ),
            'None'
        ) AS accessories
    FROM interactions.interaction_equipment_types iet
    JOIN core.equipment_types et ON iet.equipment_type_id = et.id
    LEFT JOIN interactions.interaction_equipment ie ON iet.id = ie.equipment_type_booking_id
    LEFT JOIN core.equipment e ON ie.equipment_id = e.id
    WHERE iet.interaction_id = task_interaction_id
    GROUP BY iet.id, et.type_name, iet.quantity, iet.equipment_type_id
    ORDER BY et.type_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_driver_task_equipment IS 'Get equipment and accessories list for a driver task';