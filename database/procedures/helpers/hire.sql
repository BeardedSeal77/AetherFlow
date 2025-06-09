-- =============================================================================
-- HIRE HELPER FUNCTIONS
-- =============================================================================
-- Purpose: Reusable helper functions for hire processing and validation
-- These can be used by hire, quote, and other equipment-related procedures
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- 1. CALCULATE HIRE COSTS (helper for future implementations)
-- =============================================================================

-- Helper function to calculate hire costs for equipment list
DROP FUNCTION IF EXISTS interactions.calculate_hire_costs;

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
-- 2. CHECK CUSTOMER CREDIT AVAILABILITY (helper for future implementations)
-- =============================================================================

-- Helper function to check if customer has sufficient credit for hire
DROP FUNCTION IF EXISTS interactions.check_customer_credit;

CREATE OR REPLACE FUNCTION interactions.check_customer_credit(
    p_customer_id INTEGER,
    p_required_amount DECIMAL(15,2)
)
RETURNS TABLE(
    credit_available BOOLEAN,
    credit_limit DECIMAL(15,2),
    current_usage DECIMAL(15,2),
    available_credit DECIMAL(15,2),
    required_amount DECIMAL(15,2),
    shortfall DECIMAL(15,2)
) AS $$
DECLARE
    v_customer_record RECORD;
    v_current_usage DECIMAL(15,2) := 0.00;
    v_available_credit DECIMAL(15,2);
    v_shortfall DECIMAL(15,2) := 0.00;
BEGIN
    -- Get customer credit limit and status
    SELECT credit_limit, status
    INTO v_customer_record
    FROM core.customers
    WHERE id = p_customer_id;
    
    IF v_customer_record IS NULL THEN
        RAISE EXCEPTION 'Customer not found: %', p_customer_id;
    END IF;
    
    IF v_customer_record.status NOT IN ('active') THEN
        RAISE EXCEPTION 'Customer account is not active: %', v_customer_record.status;
    END IF;
    
    -- Calculate current credit usage
    -- NOTE: This is a placeholder calculation - you'll need to implement
    -- actual outstanding hire calculations, pending invoices, etc.
    -- For now, we'll assume zero usage to allow all hires
    v_current_usage := 0.00;
    
    -- TODO: Implement actual credit usage calculation
    -- This might include:
    -- - Outstanding hire charges
    -- - Pending invoices
    -- - Unreturned equipment deposits
    -- - Other account balances
    
    -- Calculate available credit
    v_available_credit := v_customer_record.credit_limit - v_current_usage;
    
    -- Calculate shortfall if any
    IF v_available_credit < p_required_amount THEN
        v_shortfall := p_required_amount - v_available_credit;
    END IF;
    
    -- Return credit check results
    RETURN QUERY SELECT
        (v_available_credit >= p_required_amount) as credit_available,
        v_customer_record.credit_limit,
        v_current_usage,
        v_available_credit,
        p_required_amount,
        v_shortfall;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 3. VALIDATE HIRE EQUIPMENT AVAILABILITY (helper for future implementations)
-- =============================================================================

-- Helper function to check equipment availability for hire dates
DROP FUNCTION IF EXISTS interactions.check_equipment_availability;

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
-- 4. GET HIRE TOTALS SUMMARY
-- =============================================================================

-- Helper function to get total hire costs and deposit summary
DROP FUNCTION IF EXISTS interactions.get_hire_totals;

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
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

COMMENT ON FUNCTION interactions.calculate_hire_costs IS 
'Calculate hire costs for equipment list based on customer type and pricing.
Returns detailed cost breakdown for each equipment item.';

COMMENT ON FUNCTION interactions.check_customer_credit IS 
'Check customer credit availability for hire amount.
Returns credit status and availability details. 
NOTE: Currently allows all hires - implement actual credit checking as needed.';

COMMENT ON FUNCTION interactions.check_equipment_availability IS 
'Check equipment availability for requested hire period.
Returns availability status for each equipment item.
NOTE: Currently assumes availability - implement actual availability checking as needed.';

COMMENT ON FUNCTION interactions.get_hire_totals IS 
'Calculate total hire costs including rental, deposits, VAT, and grand total.
Returns summary totals for the entire hire.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Calculate costs for equipment list
SELECT * FROM interactions.calculate_hire_costs(
    1000,  -- customer_id
    '[
        {"equipment_category_id": 5, "quantity": 2, "hire_duration": 7, "hire_period_type": "days"},
        {"equipment_category_id": 8, "quantity": 1, "hire_duration": 2, "hire_period_type": "weeks"}
    ]'::jsonb
);

-- Example 2: Check customer credit
SELECT * FROM interactions.check_customer_credit(1000, 5000.00);

-- Example 3: Check equipment availability
SELECT * FROM interactions.check_equipment_availability(
    '[{"equipment_category_id": 5, "quantity": 2}]'::jsonb,
    '2025-06-10',
    '2025-06-17'
);

-- Example 4: Get hire totals
SELECT * FROM interactions.get_hire_totals(
    1000,
    '[
        {"equipment_category_id": 5, "quantity": 2, "hire_duration": 7, "hire_period_type": "days"},
        {"equipment_category_id": 8, "quantity": 1, "hire_duration": 2, "hire_period_type": "weeks"}
    ]'::jsonb
);
*/