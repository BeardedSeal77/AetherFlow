-- =============================================================================
-- HELPERS: Check equipment availability for requested hire dates
-- =============================================================================
-- Purpose: Check equipment availability for requested hire dates
-- Dependencies: core.equipment_categories, booking system
-- Used by: Hire validation, availability checking
-- Function: interactions.check_equipment_availability
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.check_equipment_availability;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.check_equipment_availability(
    p_equipment_list JSONB,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE(
    equipment_category_id INTEGER,
    equipment_name VARCHAR(255),
    requested_quantity INTEGER,
    available_quantity INTEGER,
    availability_status VARCHAR(50),
    next_available_date DATE
) AS $$
DECLARE
    v_equipment_item JSONB;
    v_equipment_id INTEGER;
    v_requested_qty INTEGER;
    v_available_qty INTEGER;
    v_equipment_name VARCHAR(255);
BEGIN
    -- Process each equipment item
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        v_equipment_id := (v_equipment_item->>'equipment_category_id')::INTEGER;
        v_requested_qty := (v_equipment_item->>'quantity')::INTEGER;
        
        -- Get equipment name
        SELECT category_name INTO v_equipment_name
        FROM core.equipment_categories
        WHERE id = v_equipment_id;
        
        -- For now, assume unlimited availability
        -- TODO: Implement actual equipment availability checking
        -- This would involve:
        -- - Checking current hires that overlap with requested dates
        -- - Checking equipment maintenance schedules
        -- - Checking reserved equipment
        -- - Calculating actual available units
        
        v_available_qty := v_requested_qty; -- Assume available for now
        
        RETURN QUERY SELECT
            v_equipment_id,
            v_equipment_name,
            v_requested_qty,
            v_available_qty,
            CASE 
                WHEN v_available_qty >= v_requested_qty THEN 'available'
                WHEN v_available_qty > 0 THEN 'partial'
                ELSE 'unavailable'
            END as availability_status,
            NULL::DATE as next_available_date; -- TODO: Calculate next available date
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.check_equipment_availability TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.check_equipment_availability TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.check_equipment_availability TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.check_equipment_availability TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.check_equipment_availability IS 
'Check equipment availability for requested hire dates. Helper function used by Hire validation, availability checking.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.check_equipment_availability(param1, param2);

-- Additional examples for this specific function
*/
