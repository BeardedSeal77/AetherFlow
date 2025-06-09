-- =============================================================================
-- CUSTOMER MANAGEMENT: Customer site creation and management
-- =============================================================================
-- Purpose: Customer site creation and management
-- Dependencies: core.sites table
-- Used by: Delivery address management
-- Function: core.create_site, core.update_site
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.create_site, core.update_site;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================



-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Set appropriate permissions based on function purpose
-- GRANT EXECUTE ON FUNCTION core.create_site, core.update_site TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.create_site, core.update_site TO manager;
-- GRANT EXECUTE ON FUNCTION core.create_site, core.update_site TO owner;

COMMENT ON FUNCTION core.create_site, core.update_site IS 
'Customer site creation and management. Used by Delivery address management.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.create_site, core.update_site(parameter1, parameter2);

-- Additional examples based on function purpose...
*/
