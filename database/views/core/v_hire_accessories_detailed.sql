SET search_path TO core, interactions, tasks, system, public;

-- =============================================================================
-- VIEW 5: Hire Accessories with Context (for hire display)
-- =============================================================================
CREATE OR REPLACE VIEW interactions.v_hire_accessories_detailed AS
SELECT 
    ia.id as interaction_accessory_id,
    ia.interaction_id,
    ia.accessory_id,
    a.accessory_name,
    a.accessory_code,
    ia.quantity,
    a.unit_of_measure,
    ia.accessory_type,
    a.is_consumable,
    -- Show which equipment types typically use this accessory
    COALESCE(
        (SELECT string_agg(DISTINCT et.type_name, ', ' ORDER BY et.type_name)
         FROM core.equipment_accessories ea 
         JOIN core.equipment_types et ON ea.equipment_type_id = et.id
         WHERE ea.accessory_id = a.id),
        'Universal'
    ) as typical_equipment_types,
    -- Format quantity for display
    ia.quantity::TEXT || ' ' || a.unit_of_measure as quantity_display,
    -- Show if this is over/under the typical default
    CASE 
        WHEN ia.accessory_type = 'default' THEN
            (SELECT AVG(ea.default_quantity) 
             FROM core.equipment_accessories ea 
             WHERE ea.accessory_id = a.id AND ea.accessory_type = 'default')
    END as typical_default_quantity,
    ia.equipment_allocation_id,
    ia.hire_start_date,
    ia.hire_end_date
FROM interactions.interaction_accessories ia
JOIN core.accessories a ON ia.accessory_id = a.id
ORDER BY 
    ia.interaction_id,
    ia.accessory_type DESC,  -- Default first
    a.is_consumable DESC,    -- Consumables first
    a.accessory_name;

COMMENT ON VIEW interactions.v_hire_accessories_detailed IS 'Detailed hire accessories with context and formatting for display';

GRANT SELECT ON interactions.v_hire_accessories_detailed TO PUBLIC;