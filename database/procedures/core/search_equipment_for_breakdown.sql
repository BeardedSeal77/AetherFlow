-- =============================================================================
-- HELPERS: Primary search function for breakdown workflow
-- =============================================================================
-- Purpose: Primary search function for breakdown workflow
-- Dependencies: Multiple interaction and equipment tables
-- Used by: Breakdown reporting workflow, equipment search
-- Function: core.search_equipment_for_breakdown
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.search_equipment_for_breakdown;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.search_equipment_for_breakdown(
    p_customer_id INTEGER,
    p_search_term TEXT DEFAULT NULL,
    p_site_filter INTEGER DEFAULT NULL,
    p_equipment_filter TEXT DEFAULT NULL
)
RETURNS TABLE(
    selectable_id VARCHAR(50),       -- Format: "site_id:equipment_id" for frontend
    display_text TEXT,               -- Human readable display
    site_id INTEGER,
    site_name VARCHAR(255),
    site_address TEXT,
    equipment_category_id INTEGER,
    equipment_name VARCHAR(255),
    equipment_code VARCHAR(20),
    equipment_quantity INTEGER,
    equipment_status VARCHAR(50),
    last_activity VARCHAR(100),
    can_report_breakdown BOOLEAN,
    site_contact_phone VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (cebs.site_id::TEXT || ':' || cebs.equipment_category_id::TEXT) as selectable_id,
        (cebs.site_name || ' - ' || cebs.equipment_name || 
         CASE WHEN cebs.equipment_quantity > 1 THEN ' (Qty: ' || cebs.equipment_quantity || ')' ELSE '' END) as display_text,
        cebs.site_id,
        cebs.site_name,
        cebs.site_address,
        cebs.equipment_category_id,
        cebs.equipment_name,
        cebs.equipment_code,
        cebs.equipment_quantity,
        cebs.equipment_status,
        (cebs.last_activity_type || ' on ' || cebs.last_activity_date::DATE::TEXT || ' (' || cebs.last_reference_number || ')') as last_activity,
        (cebs.equipment_status IN ('on_hire', 'breakdown_reported')) as can_report_breakdown,
        cebs.site_contact_phone
    FROM core.get_customer_equipment_by_site(
        p_customer_id, 
        p_search_term, 
        180,  -- Look back 6 months
        true  -- Active sites only
    ) AS cebs
    WHERE (p_site_filter IS NULL OR cebs.site_id = p_site_filter)
    AND (p_equipment_filter IS NULL OR 
         LOWER(cebs.equipment_name) LIKE '%' || LOWER(p_equipment_filter) || '%')
    AND cebs.equipment_status != 'returned'  -- Don't show returned equipment
    ORDER BY 
        cebs.site_name,
        cebs.equipment_name,
        cebs.last_activity_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.search_equipment_for_breakdown TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION core.search_equipment_for_breakdown TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.search_equipment_for_breakdown TO manager;
-- GRANT EXECUTE ON FUNCTION core.search_equipment_for_breakdown TO owner;

-- Add function documentation
COMMENT ON FUNCTION core.search_equipment_for_breakdown IS 
'Primary search function for breakdown workflow. Helper function used by Breakdown reporting workflow, equipment search.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.search_equipment_for_breakdown(param1, param2);

-- Additional examples for this specific function
*/
