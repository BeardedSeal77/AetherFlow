-- =============================================================================
-- HELPERS: Calculate hire costs for equipment lists based on customer type
-- =============================================================================
-- Purpose: Calculate hire costs for equipment lists based on customer type
-- Dependencies: core.equipment_pricing, core.customers
-- Used by: Quote generation, hire processing, cost calculations
-- Function: interactions.calculate_hire_costs
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.calculate_hire_costs;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.calculate_hire_costs(
    p_customer_id INTEGER,
    p_equipment_list JSONB  -- [{"equipment_category_id": 5, "quantity": 2, "hire_duration": 7, "hire_period_type": "days"}]
)
RETURNS TABLE(
    equipment_category_id INTEGER,
    equipment_name VARCHAR(255),
    quantity INTEGER,
    hire_duration INTEGER,
    hire_period_type VARCHAR(20),
    daily_rate DECIMAL(10,2),
    weekly_rate DECIMAL(10,2),
    monthly_rate DECIMAL(10,2),
    deposit_amount DECIMAL(10,2),
    line_total_daily DECIMAL(10,2),
    line_total_weekly DECIMAL(10,2),
    line_total_monthly DECIMAL(10,2),
    line_deposit_total DECIMAL(10,2),
    calculated_rental_cost DECIMAL(10,2),
    period_used VARCHAR(20)
) AS $$
DECLARE
    v_equipment_item JSONB;
    v_customer_type VARCHAR(20);
    v_equipment_id INTEGER;
    v_quantity INTEGER;
    v_duration INTEGER;
    v_period_type VARCHAR(20);
    v_pricing RECORD;
    v_calculated_cost DECIMAL(10,2);
    v_period_used VARCHAR(20);
BEGIN
    -- Get customer type for pricing
    SELECT CASE WHEN is_company THEN 'company' ELSE 'individual' END
    INTO v_customer_type
    FROM core.customers
    WHERE id = p_customer_id;
    
    IF v_customer_type IS NULL THEN
        RAISE EXCEPTION 'Customer not found: %', p_customer_id;
    END IF;
    
    -- Process each equipment item
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        -- Extract equipment details
        v_equipment_id := (v_equipment_item->>'equipment_category_id')::INTEGER;
        v_quantity := (v_equipment_item->>'quantity')::INTEGER;
        v_duration := (v_equipment_item->>'hire_duration')::INTEGER;
        v_period_type := v_equipment_item->>'hire_period_type';
        
        -- Get pricing for this equipment and customer type
        SELECT 
            ec.category_name,
            ep.price_per_day,
            ep.price_per_week,
            ep.price_per_month,
            ep.deposit_amount
        INTO v_pricing
        FROM core.equipment_categories ec
        JOIN core.equipment_pricing ep ON ec.id = ep.equipment_category_id
        WHERE ec.id = v_equipment_id
        AND ep.customer_type = v_customer_type
        AND ep.is_active = true
        AND ep.effective_from <= CURRENT_DATE
        AND (ep.effective_until IS NULL OR ep.effective_until >= CURRENT_DATE);
        
        IF v_pricing IS NULL THEN
            RAISE EXCEPTION 'Pricing not found for equipment % and customer type %', v_equipment_id, v_customer_type;
        END IF;
        
        -- Calculate rental cost based on period type and duration
        CASE v_period_type
            WHEN 'days' THEN
                v_calculated_cost := v_pricing.price_per_day * v_duration * v_quantity;
                v_period_used := 'daily';
            WHEN 'weeks' THEN
                v_calculated_cost := v_pricing.price_per_week * v_duration * v_quantity;
                v_period_used := 'weekly';
            WHEN 'months' THEN
                v_calculated_cost := v_pricing.price_per_month * v_duration * v_quantity;
                v_period_used := 'monthly';
            ELSE
                RAISE EXCEPTION 'Invalid hire period type: %', v_period_type;
        END CASE;
        
        -- Return calculated costs for this equipment item
        RETURN QUERY SELECT
            v_equipment_id,
            v_pricing.category_name,
            v_quantity,
            v_duration,
            v_period_type,
            v_pricing.price_per_day,
            v_pricing.price_per_week,
            v_pricing.price_per_month,
            v_pricing.deposit_amount,
            (v_pricing.price_per_day * v_quantity) as line_total_daily,
            (v_pricing.price_per_week * v_quantity) as line_total_weekly,
            (v_pricing.price_per_month * v_quantity) as line_total_monthly,
            (v_pricing.deposit_amount * v_quantity) as line_deposit_total,
            v_calculated_cost,
            v_period_used;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.calculate_hire_costs TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.calculate_hire_costs TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.calculate_hire_costs TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.calculate_hire_costs TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.calculate_hire_costs IS 
'Calculate hire costs for equipment lists based on customer type. Helper function used by Quote generation, hire processing, cost calculations.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.calculate_hire_costs(param1, param2);

-- Additional examples for this specific function
*/
