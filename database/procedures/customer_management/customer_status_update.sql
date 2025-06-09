-- =============================================================================
-- CUSTOMER MANAGEMENT: Activate/deactivate customer accounts
-- =============================================================================
-- Purpose: Activate/deactivate customer accounts
-- Dependencies: core.customers table
-- Used by: Account management
-- Function: core.update_customer_status
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.update_customer_status;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================



-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Set appropriate permissions based on function purpose
-- GRANT EXECUTE ON FUNCTION core.update_customer_status TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.update_customer_status TO manager;
-- GRANT EXECUTE ON FUNCTION core.update_customer_status TO owner;

COMMENT ON FUNCTION core.update_customer_status IS 
'Activate/deactivate customer accounts. Used by Account management.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.update_customer_status(parameter1, parameter2);

-- Additional examples based on function purpose...
*/
