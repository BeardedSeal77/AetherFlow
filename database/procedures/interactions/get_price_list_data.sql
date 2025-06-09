-- =============================================================================
-- INTERACTIONS: Get equipment pricing data for price list generation
-- =============================================================================
-- Purpose: Get equipment pricing data for price list generation
-- Dependencies: core.equipment_pricing, interactions.component_equipment_list
-- Used by: Price list generation, pricing display
-- Function: interactions.get_price_list_data
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.get_price_list_data;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.get_price_list_data(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    equipment_name VARCHAR(255),
    equipment_code VARCHAR(20),
    description TEXT,
    specifications TEXT,
    default_accessories TEXT,
    price_per_day DECIMAL(10,2),
    price_per_week DECIMAL(10,2),
    price_per_month DECIMAL(10,2),
    deposit_amount DECIMAL(10,2)
) AS $$
DECLARE
    v_customer_type VARCHAR(20);
BEGIN
    -- Get customer type for pricing
    SELECT CASE WHEN c.is_company THEN 'company' ELSE 'individual' END
    INTO v_customer_type
    FROM interactions.interactions i
    JOIN core.customers c ON i.customer_id = c.id
    WHERE i.id = p_interaction_id;
    
    -- Return pricing data for all equipment in the price list
    RETURN QUERY
    SELECT 
        ec.category_name,
        ec.category_code,
        ec.description,
        ec.specifications,
        ec.default_accessories,
        ep.price_per_day,
        ep.price_per_week,
        ep.price_per_month,
        ep.deposit_amount
    FROM interactions.component_equipment_list cel
    JOIN core.equipment_categories ec ON cel.equipment_category_id = ec.id
    JOIN core.equipment_pricing ep ON ec.id = ep.equipment_category_id
    WHERE cel.interaction_id = p_interaction_id
        AND ep.customer_type = v_customer_type
        AND ep.is_active = true
        AND (ep.effective_until IS NULL OR ep.effective_until >= CURRENT_DATE)
    ORDER BY ec.category_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.get_price_list_data TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.get_price_list_data TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.get_price_list_data TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.get_price_list_data TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.get_price_list_data IS 
'Get equipment pricing data for price list generation. Used by Price list generation, pricing display.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.get_price_list_data(param1, param2);

-- Additional examples for this specific function
*/
