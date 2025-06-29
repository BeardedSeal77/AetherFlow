SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_equipment_accessories(
    p_equipment_type_ids INTEGER[] DEFAULT NULL
)
RETURNS TABLE(
    accessory_id INTEGER,
    equipment_type_id INTEGER,
    accessory_name VARCHAR(255),
    accessory_type VARCHAR(20),
    billing_method VARCHAR(20),
    default_quantity INTEGER,
    description TEXT,
    is_consumable BOOLEAN,
    type_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.equipment_type_id,
        a.accessory_name,
        a.accessory_type,
        a.billing_method,
        a.quantity,
        a.description,
        a.is_consumable,
        et.type_name
    FROM core.accessories a
    LEFT JOIN core.equipment_types et ON a.equipment_type_id = et.id
    WHERE 
        a.status = 'active'
        AND (
            p_equipment_type_ids IS NULL 
            OR a.equipment_type_id = ANY(p_equipment_type_ids)
            OR a.equipment_type_id IS NULL  -- Generic accessories
        )
    ORDER BY 
        CASE WHEN a.accessory_type = 'default' THEN 0 ELSE 1 END,
        a.accessory_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_equipment_accessories IS 'Get accessories available for selected equipment types';