-- database/procedures/equipment_selection_procedures/sp_get_all_accessories.sql
-- =============================================================================
-- NEW: sp_get_all_accessories - Get all accessories in the system
-- =============================================================================

SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_all_accessories()
RETURNS TABLE(
    accessory_id INTEGER,
    equipment_type_id INTEGER,
    accessory_name VARCHAR(255),
    accessory_code VARCHAR(50),
    accessory_type VARCHAR(20),
    default_quantity DECIMAL(8,2),
    unit_of_measure VARCHAR(20),
    description TEXT,
    is_consumable BOOLEAN,
    type_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        ea.equipment_type_id,
        a.accessory_name,
        a.accessory_code,
        ea.accessory_type,
        ea.default_quantity,
        a.unit_of_measure,
        a.description,
        a.is_consumable,
        et.type_name
    FROM core.accessories a
    LEFT JOIN core.equipment_accessories ea ON a.id = ea.accessory_id
    LEFT JOIN core.equipment_types et ON ea.equipment_type_id = et.id
    WHERE 
        a.status = 'active'
        AND (et.is_active = true OR et.id IS NULL)
    ORDER BY 
        a.is_consumable DESC,  -- Consumables first
        a.accessory_name;      -- Then alphabetical
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_all_accessories IS 'Get all accessories in the system for standalone accessory orders';

-- Grant permissions
GRANT EXECUTE ON FUNCTION sp_get_all_accessories TO PUBLIC;