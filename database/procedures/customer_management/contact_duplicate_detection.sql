-- =============================================================================
-- CUSTOMER MANAGEMENT: Detect potential duplicate contacts
-- =============================================================================
-- Purpose: Detect potential duplicate contacts
-- Dependencies: core.contacts table
-- Used by: Data quality management
-- Function: core.detect_duplicate_contacts
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.detect_duplicate_contacts;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.detect_duplicate_contacts(
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_first_name TEXT DEFAULT NULL,
    p_last_name TEXT DEFAULT NULL,
    p_exclude_contact_id INTEGER DEFAULT NULL  -- Exclude when updating existing contact
)
RETURNS TABLE(
    contact_id INTEGER,
    customer_name VARCHAR(255),
    customer_code VARCHAR(20),
    full_name TEXT,
    email VARCHAR(255),
    phone_number VARCHAR(20),
    duplicate_reason TEXT,
    confidence_score INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        cust.customer_name,
        cust.customer_code,
        c.first_name || ' ' || c.last_name as full_name,
        c.email,
        c.phone_number,
        CASE 
            WHEN p_email IS NOT NULL AND LOWER(c.email) = LOWER(p_email) THEN 'Exact email match'
            WHEN p_phone IS NOT NULL AND (
                REGEXP_REPLACE(c.phone_number, '[^0-9+]', '', 'g') = REGEXP_REPLACE(p_phone, '[^0-9+]', '', 'g') OR
                REGEXP_REPLACE(c.whatsapp_number, '[^0-9+]', '', 'g') = REGEXP_REPLACE(p_phone, '[^0-9+]', '', 'g')
            ) THEN 'Exact phone match'
            WHEN p_first_name IS NOT NULL AND p_last_name IS NOT NULL AND 
                LOWER(c.first_name) = LOWER(p_first_name) AND 
                LOWER(c.last_name) = LOWER(p_last_name) THEN 'Exact name match'
            WHEN p_email IS NOT NULL AND LOWER(c.email) LIKE '%' || LOWER(p_email) || '%' THEN 'Similar email'
            ELSE 'Similar contact'
        END as duplicate_reason,
        CASE 
            WHEN p_email IS NOT NULL AND LOWER(c.email) = LOWER(p_email) THEN 100
            WHEN p_phone IS NOT NULL AND (
                REGEXP_REPLACE(c.phone_number, '[^0-9+]', '', 'g') = REGEXP_REPLACE(p_phone, '[^0-9+]', '', 'g') OR
                REGEXP_REPLACE(c.whatsapp_number, '[^0-9+]', '', 'g') = REGEXP_REPLACE(p_phone, '[^0-9+]', '', 'g')
            ) THEN 90
            WHEN p_first_name IS NOT NULL AND p_last_name IS NOT NULL AND 
                LOWER(c.first_name) = LOWER(p_first_name) AND 
                LOWER(c.last_name) = LOWER(p_last_name) THEN 80
            WHEN p_email IS NOT NULL AND LOWER(c.email) LIKE '%' || LOWER(p_email) || '%' THEN 60
            ELSE 40
        END as confidence_score
    FROM core.contacts c
    JOIN core.customers cust ON c.customer_id = cust.id
    WHERE c.status = 'active'
    AND cust.status = 'active'
    AND (p_exclude_contact_id IS NULL OR c.id != p_exclude_contact_id)
    AND (
        (p_email IS NOT NULL AND LOWER(c.email) = LOWER(p_email)) OR
        (p_phone IS NOT NULL AND (
            REGEXP_REPLACE(c.phone_number, '[^0-9+]', '', 'g') = REGEXP_REPLACE(p_phone, '[^0-9+]', '', 'g') OR
            REGEXP_REPLACE(c.whatsapp_number, '[^0-9+]', '', 'g') = REGEXP_REPLACE(p_phone, '[^0-9+]', '', 'g')
        )) OR
        (p_first_name IS NOT NULL AND p_last_name IS NOT NULL AND 
            LOWER(c.first_name) = LOWER(p_first_name) AND 
            LOWER(c.last_name) = LOWER(p_last_name)) OR
        (p_email IS NOT NULL AND LOWER(c.email) LIKE '%' || LOWER(p_email) || '%')
    )
    ORDER BY confidence_score DESC, c.created_at DESC
    LIMIT 10;  -- Limit to top 10 potential duplicates
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Set appropriate permissions based on function purpose
-- GRANT EXECUTE ON FUNCTION core.detect_duplicate_contacts TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.detect_duplicate_contacts TO manager;
-- GRANT EXECUTE ON FUNCTION core.detect_duplicate_contacts TO owner;

COMMENT ON FUNCTION core.detect_duplicate_contacts IS 
'Detect potential duplicate contacts. Used by Data quality management.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.detect_duplicate_contacts(parameter1, parameter2);

-- Additional examples based on function purpose...
*/
