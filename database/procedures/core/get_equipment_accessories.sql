-- =============================================================================
-- HELPERS: Get equipment accessories from normalized table
-- =============================================================================
-- Purpose: Retrieve accessories for selected equipment from new accessories table
-- Dependencies: core.equipment_accessories, core.equipment_categories
-- Used by: Equipment selection UI, hire/off-hire workflows
-- Function: core.get_equipment_accessories
-- Updated: 2025-06-11 - Now uses normalized accessories table
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_equipment_accessories;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.get_equipment_accessories(p_equipment_category_id INTEGER)
RETURNS TABLE(
    accessory_id INTEGER,
    equipment_category_id INTEGER,
    accessory_name VARCHAR(100),
    accessory_type VARCHAR(50),
    quantity INTEGER,
    description TEXT,
    is_consumable BOOLEAN,
    unit_cost DECIMAL(8,2),
    is_default BOOLEAN,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ea.id,
        ea.equipment_category_id,
        ea.accessory_name,
        ea.accessory_type,
        ea.quantity,
        ea.description,
        ea.is_consumable,
        ea.unit_cost,
        (ea.accessory_type = 'default') as is_default,
        ea.is_active
    FROM core.equipment_accessories ea
    WHERE ea.equipment_category_id = p_equipment_category_id
      AND ea.is_active = true
    ORDER BY 
        CASE ea.accessory_type 
            WHEN 'default' THEN 1 
            WHEN 'optional' THEN 2 
            WHEN 'replacement' THEN 3 
            ELSE 4 
        END,
        ea.accessory_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.get_equipment_accessories TO PUBLIC;

-- Add function documentation
COMMENT ON FUNCTION core.get_equipment_accessories IS 
'Retrieve accessories for selected equipment from normalized accessories table. 
Returns all accessories for an equipment category ordered by type (default first).
Used by equipment selection UI to show default and optional accessories.
Updated to use new core.equipment_accessories table structure.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- Get all accessories for Rammer (equipment_category_id = 1)
SELECT * FROM core.get_equipment_accessories(1);

-- Get just default accessories for equipment
SELECT * FROM core.get_equipment_accessories(1) WHERE is_default = true;

-- Get accessories with costs for pricing calculations
SELECT accessory_name, quantity, unit_cost, (quantity * unit_cost) as total_cost
FROM core.get_equipment_accessories(1) 
WHERE accessory_type = 'optional';
*/