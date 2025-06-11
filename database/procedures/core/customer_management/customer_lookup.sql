-- =============================================================================
-- CUSTOMER MANAGEMENT: Simple customer lookup by ID or code
-- =============================================================================
-- Purpose: Simple customer lookup by ID or code
-- Dependencies: core.customers table
-- Used by: Quick customer validation
-- Function: core.lookup_customer
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.lookup_customer;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.lookup_customer(p_customer_id INTEGER)
RETURNS TABLE(
    customer_id INTEGER,
    customer_code VARCHAR(20),
    customer_name VARCHAR(255),
    is_company BOOLEAN,
    status VARCHAR(20),
    credit_limit DECIMAL(15,2),
    payment_terms VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.customer_code,
        c.customer_name,
        c.is_company,
        c.status,
        c.credit_limit,
        c.payment_terms
    FROM core.customers c
    WHERE c.id = p_customer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Set appropriate permissions based on function purpose
-- GRANT EXECUTE ON FUNCTION core.lookup_customer TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.lookup_customer TO manager;
-- GRANT EXECUTE ON FUNCTION core.lookup_customer TO owner;

COMMENT ON FUNCTION core.lookup_customer IS 
'Simple customer lookup by ID or code. Used by Quick customer validation.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.lookup_customer(parameter1, parameter2);

-- Additional examples based on function purpose...
*/
