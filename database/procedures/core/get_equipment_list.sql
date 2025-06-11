-- =============================================================================
-- CORE: Get basic equipment list for hire selection
-- =============================================================================
-- Purpose: Get simple equipment list for hire workflow (no availability checking)
-- Dependencies: core.equipment_categories, core.equipment_pricing
-- Used by: Hire workflow equipment selection dropdown
-- Function: core.get_equipment_list
-- Created: 2025-06-11
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_equipment_list;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.get_equipment_list(
    p_search_term TEXT DEFAULT NULL,
    p_customer_type VARCHAR(20) DEFAULT 'individual' -- 'individual' or 'company'
)
RETURNS TABLE(
    equipment_id INTEGER,
    equipment_code VARCHAR(20),
    equipment_name VARCHAR(255),
    description TEXT,
    specifications TEXT,
    daily_rate DECIMAL(10,2),
    weekly_rate DECIMAL(10,2),
    monthly_rate DECIMAL(10,2),
    deposit_amount DECIMAL(10,2),
    has_accessories BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.id,
        ec.category_code,
        ec.category_name,
        ec.description,
        ec.specifications,
        ep.price_per_day,
        ep.price_per_week,
        ep.price_per_month,
        ep.deposit_amount,
        EXISTS(
            SELECT 1 FROM core.equipment_accessories ea 
            WHERE ea.equipment_category_id = ec.id 
            AND ea.is_active = true
        ) as has_accessories
    FROM core.equipment_categories ec
    LEFT JOIN core.equipment_pricing ep ON ec.id = ep.equipment_category_id 
        AND ep.customer_type = p_customer_type
        AND ep.is_active = true
        AND (ep.effective_until IS NULL OR ep.effective_until >= CURRENT_DATE)
    WHERE ec.is_active = true
      AND (
          p_search_term IS NULL 
          OR ec.category_name ILIKE '%' || p_search_term || '%'
          OR ec.category_code ILIKE '%' || p_search_term || '%'
          OR ec.description ILIKE '%' || p_search_term || '%'
      )
    ORDER BY ec.category_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.get_equipment_list TO PUBLIC;

-- Add function documentation
COMMENT ON FUNCTION core.get_equipment_list IS 
'Get basic equipment list for hire workflow. No availability checking.
Returns equipment with pricing for specified customer type.
Used by hire workflow equipment selection dropdown.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- Get all equipment for individual customer
SELECT * FROM core.get_equipment_list();

-- Get all equipment for company customer
SELECT * FROM core.get_equipment_list(NULL, 'company');

-- Search equipment by name
SELECT * FROM core.get_equipment_list('compactor');

-- Get equipment with accessories indicator
SELECT equipment_name, daily_rate, has_accessories 
FROM core.get_equipment_list() 
WHERE has_accessories = true;
*/