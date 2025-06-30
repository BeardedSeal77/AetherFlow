-- =============================================================================
-- FIXED: sp_get_equipment_accessories - Updated for new accessories structure
-- =============================================================================

SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_equipment_accessories(
    p_equipment_type_ids INTEGER[] DEFAULT NULL
)
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
    JOIN core.equipment_accessories ea ON a.id = ea.accessory_id
    JOIN core.equipment_types et ON ea.equipment_type_id = et.id
    WHERE 
        a.status = 'active'
        AND et.is_active = true
        AND (
            p_equipment_type_ids IS NULL 
            OR ea.equipment_type_id = ANY(p_equipment_type_ids)
        )
    ORDER BY 
        et.type_name,
        CASE WHEN ea.accessory_type = 'default' THEN 0 ELSE 1 END,
        a.accessory_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_equipment_accessories IS 'Get accessories available for selected equipment types - UPDATED for new relationship structure';

-- =============================================================================
-- CHANGE NOTES:
-- =============================================================================
/*
MAJOR CHANGES MADE:

1. REMOVED OLD COLUMNS:
   - a.billing_method (no longer exists)
   - a.quantity (renamed to ea.default_quantity)

2. ADDED NEW COLUMNS:
   - a.accessory_code (new unique identifier)
   - ea.default_quantity (quantity from relationship table)
   - a.unit_of_measure (proper unit tracking)

3. UPDATED JOINS:
   - OLD: FROM core.accessories a LEFT JOIN core.equipment_types et ON a.equipment_type_id = et.id
   - NEW: FROM core.accessories a JOIN core.equipment_accessories ea ON a.id = ea.accessory_id
          JOIN core.equipment_types et ON ea.equipment_type_id = et.id

4. UPDATED WHERE CLAUSE:
   - OLD: a.equipment_type_id = ANY(p_equipment_type_ids)
   - NEW: ea.equipment_type_id = ANY(p_equipment_type_ids)

5. IMPROVED ORDERING:
   - Now orders by equipment type first, then default/optional, then accessory name
   - Ensures consistent display across all equipment types

COMPATIBILITY:
- Return table structure updated to include new fields
- Calling code may need updates to handle new column names
- Python services should be updated to use accessory_code instead of billing_method
*/