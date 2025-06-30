SET search_path TO core, interactions, tasks, system, public;

-- =============================================================================
-- VIEW 2: All Equipment-Accessory Relationships
-- =============================================================================
CREATE OR REPLACE VIEW core.v_equipment_all_accessories AS
SELECT 
    et.id as equipment_type_id,
    et.type_code,
    et.type_name,
    a.id as accessory_id,
    a.accessory_name,
    a.accessory_code,
    ea.accessory_type,
    ea.default_quantity,
    a.unit_of_measure,
    a.is_consumable,
    a.description as accessory_description,
    CASE 
        WHEN ea.accessory_type = 'default' THEN 'Automatically included'
        ELSE 'Optional add-on'
    END as relationship_description
FROM core.equipment_types et
JOIN core.equipment_accessories ea ON et.id = ea.equipment_type_id
JOIN core.accessories a ON ea.accessory_id = a.id
WHERE et.is_active = true
  AND a.status = 'active'
ORDER BY et.type_name, 
         CASE WHEN ea.accessory_type = 'default' THEN 0 ELSE 1 END,
         a.is_consumable DESC, 
         a.accessory_name;

COMMENT ON VIEW core.v_equipment_all_accessories IS 'All equipment-accessory relationships (default and optional)';

GRANT SELECT ON core.v_equipment_all_accessories TO PUBLIC;