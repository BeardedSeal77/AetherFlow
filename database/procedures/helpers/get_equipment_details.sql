-- =============================================================================
-- HELPERS: Get detailed equipment specifications and accessories
-- =============================================================================
-- Purpose: Get detailed equipment specifications and accessories
-- Dependencies: core.equipment_categories
-- Used by: Equipment information display, form population
-- Function: core.get_equipment_details
-- Created: 2025-09-06
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
    default_accessories TEXT,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.id,
        ec.category_code,
        ec.category_name,
        ec.description,
        ec.specifications,
        ec.default_accessories,
        ec.is_active
    FROM core.equipment_categories ec
    WHERE ec.id = p_equipment_category_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.get_equipment_details TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION core.get_equipment_details TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.get_equipment_details TO manager;
-- GRANT EXECUTE ON FUNCTION core.get_equipment_details TO owner;

-- Add function documentation
COMMENT ON FUNCTION core.get_equipment_details IS 
'Get detailed equipment specifications and accessories. Helper function used by Equipment information display, form population.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.get_equipment_details(param1, param2);

-- Additional examples for this specific function
*/
