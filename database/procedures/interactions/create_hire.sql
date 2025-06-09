-- =============================================================================
-- INTERACTIONS: Process new equipment hire requests
-- =============================================================================
-- Purpose: Process new equipment hire requests
-- Dependencies: interactions.component_hire_details, tasks.drivers_taskboard
-- Used by: Equipment hire workflow, delivery scheduling
-- Function: interactions.create_hire
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_hire;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

-- TODO: Move the interactions.create_hire function from the original file here
-- Look for this function in the original file and copy it here

-- Example structure:
-- CREATE OR REPLACE FUNCTION interactions.create_hire(
--     parameter1 INTEGER,
--     parameter2 TEXT DEFAULT NULL
-- )
-- RETURNS TABLE(
--     column1 INTEGER,
--     column2 TEXT
-- ) AS $$
-- DECLARE
--     -- Variables here
-- BEGIN
--     -- Function logic here
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.create_hire TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.create_hire TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.create_hire TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.create_hire TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.create_hire IS 
'Process new equipment hire requests. Used by Equipment hire workflow, delivery scheduling.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.create_hire(param1, param2);

-- Additional examples for this specific function
*/
