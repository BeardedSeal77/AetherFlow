SET search_path TO core, interactions, tasks, system, public;

-- =============================================================================
-- VIEW 4: Equipment Auto-Accessories Summary
-- =============================================================================
CREATE OR REPLACE VIEW core.v_equipment_auto_accessories_summary AS
SELECT 
    et.id as equipment_type_id,
    et.type_code,
    et.type_name,
    COUNT(CASE WHEN ea.accessory_type = 'default' THEN 1 END) as default_accessories_count,
    COUNT(CASE WHEN ea.accessory_type = 'optional' THEN 1 END) as optional_accessories_count,
    COUNT(CASE WHEN ea.accessory_type = 'default' AND a.is_consumable = true THEN 1 END) as consumable_defaults_count,
    -- Create a formatted string of default accessories
    string_agg(
        CASE WHEN ea.accessory_type = 'default' THEN 
            ea.default_quantity::TEXT || ' ' || a.unit_of_measure || ' ' || a.accessory_name
        END, 
        ', ' 
        ORDER BY a.is_consumable DESC, a.accessory_name
    ) as default_accessories_summary
FROM core.equipment_types et
LEFT JOIN core.equipment_accessories ea ON et.id = ea.equipment_type_id
LEFT JOIN core.accessories a ON ea.accessory_id = a.id AND a.status = 'active'
WHERE et.is_active = true
GROUP BY et.id, et.type_code, et.type_name
ORDER BY et.type_name;

COMMENT ON VIEW core.v_equipment_auto_accessories_summary IS 'Summary of accessories automatically included with each equipment type';

GRANT SELECT ON core.v_equipment_auto_accessories_summary TO PUBLIC;