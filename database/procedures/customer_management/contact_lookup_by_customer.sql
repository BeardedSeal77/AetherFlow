-- =============================================================================
-- CUSTOMER MANAGEMENT: Get all contacts for specific customer
-- =============================================================================
-- Purpose: Get all contacts for specific customer
-- Dependencies: core.contacts table
-- Used by: Dropdown population
-- Function: core.get_customer_contacts
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_customer_contacts;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.get_customer_contacts(
    p_customer_id INTEGER,
    p_active_only BOOLEAN DEFAULT true
)
RETURNS TABLE(
    contact_id INTEGER,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name TEXT,
    job_title VARCHAR(100),
    email VARCHAR(255),
    phone_number VARCHAR(20),
    is_primary_contact BOOLEAN,
    is_billing_contact BOOLEAN,
    status VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.first_name,
        c.last_name,
        c.first_name || ' ' || c.last_name as full_name,
        c.job_title,
        c.email,
        c.phone_number,
        c.is_primary_contact,
        c.is_billing_contact,
        c.status
    FROM core.contacts c
    WHERE c.customer_id = p_customer_id
    AND (NOT p_active_only OR c.status = 'active')
    ORDER BY 
        c.is_primary_contact DESC,
        c.is_billing_contact DESC,
        c.first_name, c.last_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Set appropriate permissions based on function purpose
-- GRANT EXECUTE ON FUNCTION core.get_customer_contacts TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.get_customer_contacts TO manager;
-- GRANT EXECUTE ON FUNCTION core.get_customer_contacts TO owner;

COMMENT ON FUNCTION core.get_customer_contacts IS 
'Get all contacts for specific customer. Used by Dropdown population.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.get_customer_contacts(parameter1, parameter2);

-- Additional examples based on function purpose...
*/
