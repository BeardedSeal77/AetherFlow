-- =============================================================================
-- HELPERS: Get detailed equipment specifications with accessories
-- =============================================================================
-- Purpose: Get detailed equipment specifications with normalized accessories
-- Dependencies: core.equipment_categories, core.equipment_accessories
-- Used by: Equipment information display, form population
-- Function: core.get_equipment_details
-- Updated: 2025-06-11 - Now includes accessories from normalized table
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_equipment_details;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.get_equipment_details(p_equipment_category_id INTEGER)
RETURNS TABLE(
    equipment_id INTEGER,
    equipment_code VARCHAR(20),
    equipment_name VARCHAR(255),
    description TEXT,
    specifications TEXT,
    is_active BOOLEAN,
    default_accessories_summary TEXT,
    total_accessories_count INTEGER,
    consumable_accessories_count INTEGER
) AS $$
DECLARE
    v_accessories_summary TEXT := '';
    v_total_accessories INTEGER := 0;
    v_consumable_accessories INTEGER := 0;
BEGIN
    -- Get accessories summary
    SELECT 
        STRING_AGG(
            CASE 
                WHEN ea.accessory_type = 'default' THEN ea.accessory_name || ' (' || ea.quantity || ')'
                ELSE NULL
            END, 
            ', ' ORDER BY ea.accessory_name
        ),
        COUNT(*),
        COUNT(CASE WHEN ea.is_consumable THEN 1 END)
    INTO v_accessories_summary, v_total_accessories, v_consumable_accessories
    FROM core.equipment_accessories ea
    WHERE ea.equipment_category_id = p_equipment_category_id
      AND ea.is_active = true;
    
    -- Return equipment details with accessories summary
    RETURN QUERY
    SELECT 
        ec.id,
        ec.category_code,
        ec.category_name,
        ec.description,
        ec.specifications,
        ec.is_active,
        COALESCE(v_accessories_summary, 'No default accessories'),
        COALESCE(v_total_accessories, 0),
        COALESCE(v_consumable_accessories, 0)
    FROM core.equipment_categories ec
    WHERE ec.id = p_equipment_category_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.get_equipment_details TO PUBLIC;

-- Add function documentation
COMMENT ON FUNCTION core.get_equipment_details IS 
'Get detailed equipment specifications with accessories summary.
Returns equipment info plus summary of default accessories from normalized table.
Used by equipment information display and form population.
Updated to use new core.equipment_accessories table structure.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- Get complete equipment details with accessories
SELECT * FROM core.get_equipment_details(1);

-- Get equipment with accessories for multiple items
SELECT 
    equipment_name,
    default_accessories_summary,
    total_accessories_count
FROM core.get_equipment_details(1)
UNION ALL
SELECT 
    equipment_name,
    default_accessories_summary,
    total_accessories_count
FROM core.get_equipment_details(2);
*/