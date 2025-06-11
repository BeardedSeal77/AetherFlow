-- =============================================================================
-- CUSTOMER MANAGEMENT: Search customers with fuzzy matching
-- =============================================================================
-- Purpose: Search customers with fuzzy matching
-- Dependencies: core.customers, core.contacts tables
-- Used by: Customer lookup in UI
-- Function: core.search_customers
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.search_customers;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION core.search_customers(
    -- Search parameters (all optional)
    p_search_term TEXT DEFAULT NULL,
    p_customer_type VARCHAR(20) DEFAULT NULL,  -- 'company', 'individual', or NULL for both
    p_status VARCHAR(20) DEFAULT 'active',     -- 'active', 'inactive', 'all'
    p_include_contacts BOOLEAN DEFAULT true,   -- Include primary contact info
    p_limit_results INTEGER DEFAULT 50,       -- Limit number of results
    p_offset_results INTEGER DEFAULT 0,       -- For pagination
    
    -- System authentication (optional)
    p_created_by INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    customer_id INTEGER,
    customer_code VARCHAR(20),
    customer_name VARCHAR(255),
    is_company BOOLEAN,
    status VARCHAR(20),
    credit_limit DECIMAL(15,2),
    payment_terms VARCHAR(50),
    registration_number VARCHAR(50),
    vat_number VARCHAR(20),
    
    -- Primary contact info (if requested)
    primary_contact_id INTEGER,
    primary_contact_name TEXT,
    primary_contact_email VARCHAR(255),
    primary_contact_phone VARCHAR(20),
    
    -- Additional info
    total_contacts INTEGER,
    total_sites INTEGER,
    last_interaction_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_search_query TEXT;
    v_where_conditions TEXT := '';
    v_authenticated_user INTEGER;
BEGIN
    -- =============================================================================
    -- OPTIONAL AUTHENTICATION CHECK
    -- =============================================================================
    
    -- Get employee ID from session or parameter (optional for search)
    IF p_session_token IS NOT NULL THEN
        SELECT ea.employee_id INTO v_authenticated_user
        FROM security.employee_auth ea
        WHERE ea.session_token = p_session_token
        AND ea.session_expires > CURRENT_TIMESTAMP;
    ELSE
        v_authenticated_user := COALESCE(p_created_by, 
            NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER);
    END IF;
    
    -- Note: Authentication is optional for search - allows public customer lookup
    
    -- =============================================================================
    -- BUILD SEARCH CONDITIONS
    -- =============================================================================
    
    -- Base WHERE condition for status
    IF p_status = 'active' THEN
        v_where_conditions := 'c.status = ''active''';
    ELSIF p_status = 'inactive' THEN
        v_where_conditions := 'c.status = ''inactive''';
    ELSIF p_status = 'all' THEN
        v_where_conditions := 'c.status IN (''active'', ''inactive'', ''suspended'', ''credit_hold'')';
    ELSE
        v_where_conditions := 'c.status = ''active''';  -- Default to active
    END IF;
    
    -- Customer type filter
    IF p_customer_type = 'company' THEN
        v_where_conditions := v_where_conditions || ' AND c.is_company = true';
    ELSIF p_customer_type = 'individual' THEN
        v_where_conditions := v_where_conditions || ' AND c.is_company = false';
    END IF;
    
    -- Search term filter (if provided)
    IF p_search_term IS NOT NULL AND TRIM(p_search_term) != '' THEN
        -- Clean and prepare search term
        v_search_query := TRIM(LOWER(p_search_term));
        
        -- Use multiple search strategies for best results
        v_where_conditions := v_where_conditions || ' AND (' ||
            -- Exact customer code match (highest priority)
            'LOWER(c.customer_code) = ''' || v_search_query || ''' OR ' ||
            -- Customer code starts with search term
            'LOWER(c.customer_code) LIKE ''' || v_search_query || '%'' OR ' ||
            -- Customer name starts with search term
            'LOWER(c.customer_name) LIKE ''' || v_search_query || '%'' OR ' ||
            -- Customer name contains search term
            'LOWER(c.customer_name) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Registration number match
            'LOWER(COALESCE(c.registration_number, '''')) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- VAT number match
            'LOWER(COALESCE(c.vat_number, '''')) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Full-text search on customer name (uses GIN index)
            'to_tsvector(''english'', c.customer_name) @@ plainto_tsquery(''english'', ''' || p_search_term || ''')' ||
        ')';
    END IF;
    
    -- =============================================================================
    -- EXECUTE SEARCH QUERY
    -- =============================================================================
    
    RETURN QUERY EXECUTE '
        SELECT 
            c.id,
            c.customer_code,
            c.customer_name,
            c.is_company,
            c.status,
            c.credit_limit,
            c.payment_terms,
            c.registration_number,
            c.vat_number,
            ' || CASE WHEN p_include_contacts THEN '
            pc.id,
            CASE WHEN pc.id IS NOT NULL THEN pc.first_name || '' '' || pc.last_name ELSE NULL END,
            pc.email,
            pc.phone_number,
            ' ELSE '
            NULL::INTEGER,
            NULL::TEXT,
            NULL::VARCHAR(255),
            NULL::VARCHAR(20),
            ' END || '
            contact_counts.total_contacts,
            site_counts.total_sites,
            latest_interaction.last_interaction_date,
            c.created_at
        FROM core.customers c
        ' || CASE WHEN p_include_contacts THEN '
        LEFT JOIN core.contacts pc ON c.id = pc.customer_id 
            AND pc.is_primary_contact = true 
            AND pc.status = ''active''
        ' ELSE '' END || '
        LEFT JOIN (
            SELECT 
                customer_id,
                COUNT(*) as total_contacts
            FROM core.contacts 
            WHERE status = ''active''
            GROUP BY customer_id
        ) contact_counts ON c.id = contact_counts.customer_id
        LEFT JOIN (
            SELECT 
                customer_id,
                COUNT(*) as total_sites
            FROM core.sites 
            WHERE is_active = true
            GROUP BY customer_id
        ) site_counts ON c.id = site_counts.customer_id
        LEFT JOIN (
            SELECT 
                customer_id,
                MAX(created_at) as last_interaction_date
            FROM interactions.interactions
            GROUP BY customer_id
        ) latest_interaction ON c.id = latest_interaction.customer_id
        WHERE ' || v_where_conditions || '
        ORDER BY 
            -- Prioritize exact code matches
            CASE WHEN LOWER(c.customer_code) = ''' || COALESCE(LOWER(TRIM(p_search_term)), '') || ''' THEN 1 ELSE 2 END,
            -- Then exact name matches
            CASE WHEN LOWER(c.customer_name) = ''' || COALESCE(LOWER(TRIM(p_search_term)), '') || ''' THEN 1 ELSE 2 END,
            -- Then code starts with
            CASE WHEN LOWER(c.customer_code) LIKE ''' || COALESCE(LOWER(TRIM(p_search_term)), '') || '%'' THEN 1 ELSE 2 END,
            -- Then name starts with
            CASE WHEN LOWER(c.customer_name) LIKE ''' || COALESCE(LOWER(TRIM(p_search_term)), '') || '%'' THEN 1 ELSE 2 END,
            -- Finally alphabetical by name
            c.customer_name
        LIMIT ' || p_limit_results || ' 
        OFFSET ' || p_offset_results;
        
EXCEPTION 
    WHEN OTHERS THEN
        -- Return empty result set on error
        RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Set appropriate permissions based on function purpose
-- GRANT EXECUTE ON FUNCTION core.search_customers TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.search_customers TO manager;
-- GRANT EXECUTE ON FUNCTION core.search_customers TO owner;

COMMENT ON FUNCTION core.search_customers IS 
'Search customers with fuzzy matching. Used by Customer lookup in UI.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.search_customers(parameter1, parameter2);

-- Additional examples based on function purpose...
*/
