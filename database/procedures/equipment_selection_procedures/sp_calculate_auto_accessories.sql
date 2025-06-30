-- =============================================================================
-- FIXED: sp_calculate_auto_accessories - Updated for new accessories structure
-- =============================================================================

SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_calculate_auto_accessories(
    p_equipment_selections JSONB  -- [{"equipment_type_id": 1, "quantity": 2}, ...]
)
RETURNS TABLE(
    accessory_id INTEGER,
    accessory_name VARCHAR(255),
    accessory_code VARCHAR(50),
    total_quantity DECIMAL(8,2),
    unit_of_measure VARCHAR(20),
    is_consumable BOOLEAN,
    equipment_type_name VARCHAR(255)
) AS $$
DECLARE
    selection JSONB;
    equipment_type_id INTEGER;
    equipment_quantity INTEGER;
BEGIN
    -- Create a temporary table to aggregate accessories across multiple equipment types
    CREATE TEMP TABLE temp_auto_accessories (
        accessory_id INTEGER,
        accessory_name VARCHAR(255),
        accessory_code VARCHAR(50),
        total_quantity DECIMAL(8,2),
        unit_of_measure VARCHAR(20),
        is_consumable BOOLEAN,
        equipment_type_names TEXT[]
    ) ON COMMIT DROP;

    -- Loop through each equipment selection
    FOR selection IN SELECT jsonb_array_elements(p_equipment_selections)
    LOOP
        equipment_type_id := (selection->>'equipment_type_id')::INTEGER;
        equipment_quantity := (selection->>'quantity')::INTEGER;
        
        -- Insert/update accessories for this equipment type
        INSERT INTO temp_auto_accessories (
            accessory_id, accessory_name, accessory_code, total_quantity, 
            unit_of_measure, is_consumable, equipment_type_names
        )
        SELECT 
            a.id,
            a.accessory_name,
            a.accessory_code,
            (ea.default_quantity * equipment_quantity)::DECIMAL(8,2) AS calculated_quantity,
            a.unit_of_measure,
            a.is_consumable,
            ARRAY[et.type_name]
        FROM core.accessories a
        JOIN core.equipment_accessories ea ON a.id = ea.accessory_id
        JOIN core.equipment_types et ON ea.equipment_type_id = et.id
        WHERE 
            ea.equipment_type_id = equipment_type_id
            AND ea.accessory_type = 'default'
            AND a.status = 'active'
            AND et.is_active = true
        
        ON CONFLICT (accessory_id) DO UPDATE SET
            total_quantity = temp_auto_accessories.total_quantity + EXCLUDED.total_quantity,
            equipment_type_names = temp_auto_accessories.equipment_type_names || EXCLUDED.equipment_type_names;
    END LOOP;

    -- Return aggregated results
    RETURN QUERY
    SELECT 
        ta.accessory_id,
        ta.accessory_name,
        ta.accessory_code,
        ta.total_quantity,
        ta.unit_of_measure,
        ta.is_consumable,
        array_to_string(ta.equipment_type_names, ', ') as equipment_type_name
    FROM temp_auto_accessories ta
    ORDER BY 
        ta.is_consumable DESC,  -- Consumables first (fuel, oil, etc.)
        ta.accessory_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_calculate_auto_accessories IS 'Calculate default accessories based on equipment selection - UPDATED for new relationship structure';

-- =============================================================================
-- CHANGE NOTES:
-- =============================================================================
/*
MAJOR CHANGES MADE:

1. UPDATED CORE QUERY:
   - OLD: FROM core.accessories a WHERE a.equipment_type_id = equipment_type_id
   - NEW: FROM core.accessories a 
          JOIN core.equipment_accessories ea ON a.id = ea.accessory_id
          JOIN core.equipment_types et ON ea.equipment_type_id = et.id

2. QUANTITY CALCULATION:
   - OLD: (a.quantity * equipment_quantity)
   - NEW: (ea.default_quantity * equipment_quantity)

3. IMPROVED AGGREGATION:
   - Added temp table to handle cases where same accessory is used by multiple equipment types
   - Example: HELMET used by both RAMMER-4S and GEN-2.5KVA
   - Properly sums quantities and tracks which equipment types contribute

4. ENHANCED RETURN DATA:
   - Added accessory_code for better identification
   - Added unit_of_measure for proper display
   - Added equipment_type_name to show which equipment requires the accessory

5. BETTER ORDERING:
   - Consumables first (fuel, oil, etc.) as they're most important
   - Then alphabetical by accessory name

EXAMPLE OUTPUT:
For 2x RAMMER-4S + 1x GEN-2.5KVA:
- PETROL-4S: 4.0 litres (2x2L from rammers)
- PETROL-GEN: 5.0 litres (1x5L from generator)  
- HELMET: 3 items (from both equipment types)
- FUNNEL: 3 items (from both equipment types)

COMPATIBILITY:
- Return structure updated with new columns
- Python services need updates to handle new fields
- Frontend may need updates for new data format
*/