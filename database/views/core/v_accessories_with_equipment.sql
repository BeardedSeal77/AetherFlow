SET search_path TO core, interactions, tasks, system, public;

-- =============================================================================
-- VIEW 3: Accessories with Equipment Type Summary
-- =============================================================================
CREATE OR REPLACE VIEW core.v_accessories_with_equipment AS
SELECT 
    a.id as accessory_id,
    a.accessory_name,
    a.accessory_code,
    a.unit_of_measure,
    a.is_consumable,
    a.description,
    -- Count how many equipment types use this accessory
    COUNT(ea.equipment_type_id) as equipment_type_count,
    -- List equipment types that use this accessory
    string_agg(DISTINCT et.type_name, ', ' ORDER BY et.type_name) as equipment_type_names,
    -- Show if used as default vs optional
    string_agg(DISTINCT ea.accessory_type, ', ') as relationship_types,
    -- Show quantity range
    MIN(ea.default_quantity) as min_quantity,
    MAX(ea.default_quantity) as max_quantity,
    CASE 
        WHEN MIN(ea.default_quantity) = MAX(ea.default_quantity) THEN 
            MIN(ea.default_quantity)::TEXT || ' ' || a.unit_of_measure
        ELSE 
            MIN(ea.default_quantity)::TEXT || '-' || MAX(ea.default_quantity)::TEXT || ' ' || a.unit_of_measure
    END as quantity_range
FROM core.accessories a
LEFT JOIN core.equipment_accessories ea ON a.id = ea.accessory_id
LEFT JOIN core.equipment_types et ON ea.equipment_type_id = et.id
WHERE a.status = 'active'
  AND (et.is_active = true OR et.id IS NULL)
GROUP BY a.id, a.accessory_name, a.accessory_code, a.unit_of_measure, 
         a.is_consumable, a.description
ORDER BY a.is_consumable DESC, a.accessory_name;

COMMENT ON VIEW core.v_accessories_with_equipment IS 'Accessories with summary of which equipment types use them';

GRANT SELECT ON core.v_accessories_with_equipment TO PUBLIC;