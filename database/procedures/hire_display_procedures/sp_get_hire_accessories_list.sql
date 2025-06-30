-- =============================================================================
-- FIXED: sp_get_hire_accessories_list - Updated for new accessories structure
-- =============================================================================

SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_hire_accessories_list(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    accessory_id INTEGER,
    accessory_name VARCHAR(255),
    accessory_code VARCHAR(50),
    quantity DECIMAL(8,2),
    unit_of_measure VARCHAR(20),
    accessory_type VARCHAR(20),
    is_consumable BOOLEAN,
    equipment_type_names TEXT,
    equipment_allocation_id INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ia.accessory_id,
        a.accessory_name,
        a.accessory_code,
        ia.quantity,
        a.unit_of_measure,
        ia.accessory_type,
        a.is_consumable,
        -- Get equipment types that use this accessory (for context)
        COALESCE(
            (SELECT string_agg(DISTINCT et.type_name, ', ' ORDER BY et.type_name)
             FROM core.equipment_accessories ea 
             JOIN core.equipment_types et ON ea.equipment_type_id = et.id
             WHERE ea.accessory_id = a.id),
            'Universal'
        ) as equipment_type_names,
        ia.equipment_allocation_id
    FROM interactions.interaction_accessories ia
    JOIN core.accessories a ON ia.accessory_id = a.id
    WHERE ia.interaction_id = p_interaction_id
    ORDER BY 
        ia.accessory_type DESC,  -- Default accessories first, then optional
        a.is_consumable DESC,    -- Consumables first within each type
        a.accessory_name;        -- Alphabetical
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_hire_accessories_list IS 'Get accessories list for hire interaction - UPDATED for new relationship structure';

-- =============================================================================
-- CHANGE NOTES:
-- =============================================================================
/*
MAJOR CHANGES MADE:

1. REMOVED PROBLEMATIC JOIN:
   - OLD: LEFT JOIN core.equipment_types et ON a.equipment_type_id = et.id
   - ISSUE: accessories no longer have direct equipment_type_id

2. ADDED DYNAMIC EQUIPMENT TYPE LOOKUP:
   - NEW: Subquery to find which equipment types use this accessory
   - Shows context like "4 Stroke Rammer, 2.5kVA Generator" for shared accessories
   - Shows "Universal" for accessories not linked to specific equipment types

3. ENHANCED RETURN DATA:
   - Added accessory_code for better identification
   - Added unit_of_measure for proper display ("2.0 litres", "1 item")
   - Added equipment_type_names to show context
   - Kept equipment_allocation_id for linking to specific equipment units

4. IMPROVED ORDERING:
   - Default accessories first (most important)
   - Consumables first within each type (fuel, oil before safety gear)
   - Alphabetical within each group

5. BETTER HANDLING OF SHARED ACCESSORIES:
   - Accessories like HELMET that are used by multiple equipment types
   - Shows all equipment types that use the accessory
   - Provides better context for display

EXAMPLE OUTPUT:
For a hire with 2x RAMMER-4S + 1x GEN-2.5KVA:
- PETROL-4S (4.0 litres) - "4 Stroke Rammer" [CONSUMABLE, DEFAULT]
- PETROL-GEN (5.0 litres) - "2.5kVA Generator" [CONSUMABLE, DEFAULT]  
- HELMET (3 items) - "4 Stroke Rammer, 2.5kVA Generator" [DEFAULT]
- FUNNEL (3 items) - "4 Stroke Rammer, 2.5kVA Generator" [DEFAULT]

COMPATIBILITY:
- Return structure updated with new columns
- Calling code should handle new equipment_type_names field
- Frontend can use this for better accessory context display
*/