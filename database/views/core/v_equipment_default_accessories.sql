SET search_path TO core, interactions, tasks, system, public;

-- =============================================================================
-- VIEW 1: Equipment Types with Default Accessories
-- =============================================================================
CREATE OR REPLACE VIEW core.v_equipment_default_accessories AS
SELECT 
    et.id as equipment_type_id,
    et.type_code,
    et.type_name,
    a.id as accessory_id,
    a.accessory_name,
    a.accessory_code,
    ea.default_quantity,
    a.unit_of_measure,
    a.is_consumable,
    a.description as accessory_description
FROM core.equipment_types et
JOIN core.equipment_accessories ea ON et.id = ea.equipment_type_id
JOIN core.accessories a ON ea.accessory_id = a.id
WHERE ea.accessory_type = 'default'
  AND et.is_active = true
  AND a.status = 'active'
ORDER BY et.type_name, a.is_consumable DESC, a.accessory_name;

COMMENT ON VIEW core.v_equipment_default_accessories IS 'Equipment types with their default accessories and quantities';

GRANT SELECT ON core.v_equipment_default_accessories TO PUBLIC;