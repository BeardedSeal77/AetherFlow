-- =============================================================================
-- HELPERS: Calculate total hire costs including VAT and deposits
-- =============================================================================
-- Purpose: Calculate total hire costs including VAT and deposits
-- Dependencies: interactions.calculate_hire_costs
-- Used by: Quote totals, hire summaries
-- Function: interactions.get_hire_totals
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.get_hire_totals;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.get_hire_totals(
    p_customer_id INTEGER,
    p_equipment_list JSONB
)
RETURNS TABLE(
    total_rental_cost DECIMAL(15,2),
    total_deposit DECIMAL(15,2),
    total_amount DECIMAL(15,2),
    vat_amount DECIMAL(15,2),
    grand_total DECIMAL(15,2),
    equipment_count INTEGER,
    total_quantity INTEGER
) AS $$
DECLARE
    v_total_rental DECIMAL(15,2) := 0.00;
    v_total_deposit DECIMAL(15,2) := 0.00;
    v_equipment_count INTEGER := 0;
    v_total_quantity INTEGER := 0;
    v_vat_rate DECIMAL(5,4) := 0.15; -- 15% VAT (configurable)
    v_vat_amount DECIMAL(15,2);
    v_subtotal DECIMAL(15,2);
    v_grand_total DECIMAL(15,2);
    v_cost_record RECORD;
BEGIN
    -- Calculate costs for each equipment item
    FOR v_cost_record IN 
        SELECT * FROM interactions.calculate_hire_costs(p_customer_id, p_equipment_list)
    LOOP
        v_total_rental := v_total_rental + v_cost_record.calculated_rental_cost;
        v_total_deposit := v_total_deposit + v_cost_record.line_deposit_total;
        v_equipment_count := v_equipment_count + 1;
        v_total_quantity := v_total_quantity + v_cost_record.quantity;
    END LOOP;
    
    -- Calculate totals
    v_subtotal := v_total_rental + v_total_deposit;
    v_vat_amount := v_total_rental * v_vat_rate; -- VAT only on rental, not deposit
    v_grand_total := v_total_rental + v_vat_amount + v_total_deposit;
    
    RETURN QUERY SELECT
        v_total_rental,
        v_total_deposit,
        v_subtotal,
        v_vat_amount,
        v_grand_total,
        v_equipment_count,
        v_total_quantity;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.get_hire_totals TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.get_hire_totals TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.get_hire_totals TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.get_hire_totals TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.get_hire_totals IS 
'Calculate total hire costs including VAT and deposits. Helper function used by Quote totals, hire summaries.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.get_hire_totals(param1, param2);

-- Additional examples for this specific function
*/
