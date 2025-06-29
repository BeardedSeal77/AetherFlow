SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_hire_accessories_list(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    accessory_id INTEGER,
    accessory_name VARCHAR(255),
    quantity DECIMAL(8,2),
    accessory_type VARCHAR(20),
    billing_method VARCHAR(20),
    is_consumable BOOLEAN,
    equipment_type_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ia.accessory_id,
        a.accessory_name,
        ia.quantity,
        ia.accessory_type,
        a.billing_method,
        a.is_consumable,
        et.type_name
    FROM interactions.interaction_accessories ia
    JOIN core.accessories a ON ia.accessory_id = a.id
    LEFT JOIN core.equipment_types et ON a.equipment_type_id = et.id
    WHERE ia.interaction_id = p_interaction_id
    ORDER BY ia.accessory_type DESC, a.accessory_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_hire_accessories_list IS 'Get accessories list for hire interaction';