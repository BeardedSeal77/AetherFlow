-- =============================================================================
-- HELPERS: Check customer credit availability for hire amount
-- =============================================================================
-- Purpose: Check customer credit availability for hire amount
-- Dependencies: core.customers
-- Used by: Credit validation, hire approval process
-- Function: interactions.check_customer_credit
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.check_customer_credit;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

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
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.check_customer_credit TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.check_customer_credit TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.check_customer_credit TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.check_customer_credit TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.check_customer_credit IS 
'Check customer credit availability for hire amount. Helper function used by Credit validation, hire approval process.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.check_customer_credit(param1, param2);

-- Additional examples for this specific function
*/
