-- =============================================================================
-- HELPERS: Get all sites for a customer with optional filtering
-- =============================================================================
-- Purpose: Get all sites for a customer with optional filtering
-- Dependencies: core.sites table
-- Used by: Breakdown workflow, delivery management, site selection
-- Function: core.get_customer_sites
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_customer_sites;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.get_customer_sites(
    p_customer_id INTEGER,
    p_site_type VARCHAR(50) DEFAULT NULL,  -- Filter by site type
    p_search_term TEXT DEFAULT NULL,       -- Search site names/addresses
    p_active_only BOOLEAN DEFAULT true
)
RETURNS TABLE(
    site_id INTEGER,
    site_code VARCHAR(20),
    site_name VARCHAR(255),
    site_type VARCHAR(50),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    postal_code VARCHAR(10),
    full_address TEXT,
    site_contact_name VARCHAR(200),
    site_contact_phone VARCHAR(20),
    delivery_instructions TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.site_code,
        s.site_name,
        s.site_type,
        s.address_line1,
        s.address_line2,
        s.city,
        s.province,
        s.postal_code,
        CASE 
            WHEN s.address_line2 IS NOT NULL AND s.address_line2 != '' 
            THEN s.address_line1 || ', ' || s.address_line2 || ', ' || s.city || 
                 CASE WHEN s.postal_code IS NOT NULL THEN ', ' || s.postal_code ELSE '' END
            ELSE s.address_line1 || ', ' || s.city || 
                 CASE WHEN s.postal_code IS NOT NULL THEN ', ' || s.postal_code ELSE '' END
        END as full_address,
        s.site_contact_name,
        s.site_contact_phone,
        s.delivery_instructions,
        s.is_active,
        s.created_at
    FROM core.sites s
    WHERE s.customer_id = p_customer_id
    AND (NOT p_active_only OR s.is_active = true)
    AND (p_site_type IS NULL OR s.site_type = p_site_type)
    AND (p_search_term IS NULL OR 
         LOWER(s.site_name) LIKE '%' || LOWER(p_search_term) || '%' OR
         LOWER(s.address_line1) LIKE '%' || LOWER(p_search_term) || '%' OR
         LOWER(s.city) LIKE '%' || LOWER(p_search_term) || '%')
    ORDER BY 
        CASE s.site_type 
            WHEN 'head_office' THEN 1
            WHEN 'project_site' THEN 2
            WHEN 'warehouse' THEN 3
            WHEN 'delivery_site' THEN 4
            WHEN 'branch' THEN 5
            ELSE 6
        END,
        s.site_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.get_customer_sites TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION core.get_customer_sites TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.get_customer_sites TO manager;
-- GRANT EXECUTE ON FUNCTION core.get_customer_sites TO owner;

-- Add function documentation
COMMENT ON FUNCTION core.get_customer_sites IS 
'Get all sites for a customer with optional filtering. Helper function used by Breakdown workflow, delivery management, site selection.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.get_customer_sites(param1, param2);

-- Additional examples for this specific function
*/
