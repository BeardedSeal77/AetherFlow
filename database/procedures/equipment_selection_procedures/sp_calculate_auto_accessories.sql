SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_calculate_auto_accessories(
    p_equipment_selections JSONB  -- [{"equipment_type_id": 1, "quantity": 2}, ...]
)
RETURNS TABLE(
    accessory_id INTEGER,
    accessory_name VARCHAR(255),
    total_quantity DECIMAL(8,2),
    is_consumable BOOLEAN,
    billing_method VARCHAR(20)
) AS $$
DECLARE
    selection JSONB;
    equipment_type_id INTEGER;
    equipment_quantity INTEGER;
BEGIN
    -- Loop through each equipment selection
    FOR selection IN SELECT jsonb_array_elements(p_equipment_selections)
    LOOP
        equipment_type_id := (selection->>'equipment_type_id')::INTEGER;
        equipment_quantity := (selection->>'quantity')::INTEGER;
        
        RETURN QUERY
        SELECT 
            a.id,
            a.accessory_name,
            (a.quantity * equipment_quantity)::DECIMAL(8,2) AS total_quantity,
            a.is_consumable,
            a.billing_method
        FROM core.accessories a
        WHERE 
            a.equipment_type_id = equipment_type_id
            AND a.accessory_type = 'default'
            AND a.status = 'active';
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_calculate_auto_accessories IS 'Calculate default accessories based on equipment selection';