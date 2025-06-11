-- =============================================================================
-- INTERACTIONS: Get accessories for specific interaction
-- =============================================================================
-- Purpose: Retrieve all accessories selected for a specific interaction
-- Dependencies: interactions.component_accessories_list, core.equipment_accessories
-- Used by: Interaction display, driver tasks, billing
-- Function: interactions.get_interaction_accessories
-- Created: 2025-06-11
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.get_interaction_accessories;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.get_interaction_accessories(p_interaction_id INTEGER)
RETURNS TABLE(
    accessory_id INTEGER,
    accessory_name VARCHAR(100),
    accessory_type VARCHAR(50),
    equipment_category_name VARCHAR(255),
    quantity_selected INTEGER,
    unit_cost DECIMAL(8,2),
    total_cost DECIMAL(8,2),
    is_default_selection BOOLEAN,
    is_consumable BOOLEAN,
    notes TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cal.accessory_id,
        ea.accessory_name,
        ea.accessory_type,
        ec.category_name,
        cal.quantity,
        cal.unit_cost_at_time,
        (cal.quantity * cal.unit_cost_at_time) as total_cost,
        cal.is_default_selection,
        ea.is_consumable,
        cal.notes
    FROM interactions.component_accessories_list cal
    JOIN core.equipment_accessories ea ON cal.accessory_id = ea.id
    JOIN core.equipment_categories ec ON ea.equipment_category_id = ec.id
    WHERE cal.interaction_id = p_interaction_id
    ORDER BY 
        ec.category_name,
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
GRANT EXECUTE ON FUNCTION interactions.get_interaction_accessories TO PUBLIC;

-- Add function documentation
COMMENT ON FUNCTION interactions.get_interaction_accessories IS 
'Retrieve all accessories selected for a specific interaction.
Returns accessories with equipment context, costs, and selection details.
Used by interaction display, driver tasks, and billing processes.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- Get all accessories for interaction ID 1001
SELECT * FROM interactions.get_interaction_accessories(1001);

-- Get just default accessories for an interaction
SELECT * FROM interactions.get_interaction_accessories(1001) 
WHERE is_default_selection = true;

-- Get accessories with total cost summary
SELECT 
    equipment_category_name,
    COUNT(*) as accessory_count,
    SUM(total_cost) as equipment_accessories_cost
FROM interactions.get_interaction_accessories(1001)
GROUP BY equipment_category_name;
*/