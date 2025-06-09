-- =============================================================================
-- CUSTOMER MANAGEMENT: SEARCH CONTACTS
-- =============================================================================
-- Purpose: Generic contact search function for interaction selection and duplicate detection
-- Supports searching across all customers or within specific customer
-- Optimized for fast search with full-text search capabilities
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.search_contacts;

-- Create the contact search procedure
CREATE OR REPLACE FUNCTION core.search_contacts(
    -- Search parameters (all optional)
    p_search_term TEXT DEFAULT NULL,
    p_customer_id INTEGER DEFAULT NULL,       -- Search within specific customer, or NULL for all
    p_email_search TEXT DEFAULT NULL,         -- Specific email search for duplicate detection
    p_phone_search TEXT DEFAULT NULL,         -- Specific phone search for duplicate detection
    p_contact_status VARCHAR(20) DEFAULT 'active',  -- 'active', 'inactive', 'all'
    p_customer_status VARCHAR(20) DEFAULT 'active', -- Filter by customer status too
    p_include_customer_info BOOLEAN DEFAULT true,   -- Include customer details
    p_primary_only BOOLEAN DEFAULT false,           -- Only primary contacts
    p_billing_only BOOLEAN DEFAULT false,           -- Only billing contacts
    p_limit_results INTEGER DEFAULT 50,             -- Limit number of results
    p_offset_results INTEGER DEFAULT 0,             -- For pagination
    
    -- System authentication (optional)
    p_created_by INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    contact_id INTEGER,
    customer_id INTEGER,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name TEXT,
    job_title VARCHAR(100),
    department VARCHAR(100),
    email VARCHAR(255),
    phone_number VARCHAR(20),
    whatsapp_number VARCHAR(20),
    is_primary_contact BOOLEAN,
    is_billing_contact BOOLEAN,
    contact_status VARCHAR(20),
    
    -- Customer info (if requested)
    customer_code VARCHAR(20),
    customer_name VARCHAR(255),
    customer_is_company BOOLEAN,
    customer_status VARCHAR(20),
    
    -- Additional info
    last_interaction_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    
    -- Duplicate detection fields
    duplicate_score INTEGER  -- Higher score = more likely duplicate
) AS $$
DECLARE
    v_search_query TEXT;
    v_where_conditions TEXT := '';
    v_authenticated_user INTEGER;
    v_email_pattern TEXT;
    v_phone_pattern TEXT;
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
    
    -- =============================================================================
    -- BUILD SEARCH CONDITIONS
    -- =============================================================================
    
    -- Base WHERE condition for contact status
    IF p_contact_status = 'active' THEN
        v_where_conditions := 'cont.status = ''active''';
    ELSIF p_contact_status = 'inactive' THEN
        v_where_conditions := 'cont.status = ''inactive''';
    ELSIF p_contact_status = 'all' THEN
        v_where_conditions := 'cont.status IN (''active'', ''inactive'')';
    ELSE
        v_where_conditions := 'cont.status = ''active''';  -- Default to active
    END IF;
    
    -- Customer status filter
    IF p_customer_status = 'active' THEN
        v_where_conditions := v_where_conditions || ' AND cust.status = ''active''';
    ELSIF p_customer_status = 'inactive' THEN
        v_where_conditions := v_where_conditions || ' AND cust.status = ''inactive''';
    ELSIF p_customer_status = 'all' THEN
        v_where_conditions := v_where_conditions || ' AND cust.status IN (''active'', ''inactive'', ''suspended'', ''credit_hold'')';
    ELSE
        v_where_conditions := v_where_conditions || ' AND cust.status = ''active''';
    END IF;
    
    -- Customer ID filter (search within specific customer)
    IF p_customer_id IS NOT NULL THEN
        v_where_conditions := v_where_conditions || ' AND cont.customer_id = ' || p_customer_id;
    END IF;
    
    -- Primary contact filter
    IF p_primary_only THEN
        v_where_conditions := v_where_conditions || ' AND cont.is_primary_contact = true';
    END IF;
    
    -- Billing contact filter
    IF p_billing_only THEN
        v_where_conditions := v_where_conditions || ' AND cont.is_billing_contact = true';
    END IF;
    
    -- Email search (exact and pattern matching for duplicate detection)
    IF p_email_search IS NOT NULL AND TRIM(p_email_search) != '' THEN
        v_email_pattern := LOWER(TRIM(p_email_search));
        v_where_conditions := v_where_conditions || ' AND (' ||
            -- Exact email match
            'LOWER(cont.email) = ''' || v_email_pattern || ''' OR ' ||
            -- Similar email patterns (for duplicate detection)
            'LOWER(cont.email) LIKE ''' || v_email_pattern || '%'' OR ' ||
            'LOWER(cont.email) LIKE ''%' || v_email_pattern || ''' OR ' ||
            -- Domain matching
            'LOWER(cont.email) LIKE ''%@' || SPLIT_PART(v_email_pattern, '@', 2) || ''' ' ||
        ')';
    END IF;
    
    -- Phone search (for duplicate detection)
    IF p_phone_search IS NOT NULL AND TRIM(p_phone_search) != '' THEN
        -- Clean phone number (remove common separators)
        v_phone_pattern := REGEXP_REPLACE(TRIM(p_phone_search), '[^0-9+]', '', 'g');
        v_where_conditions := v_where_conditions || ' AND (' ||
            'REGEXP_REPLACE(cont.phone_number, ''[^0-9+]'', '''', ''g'') LIKE ''%' || v_phone_pattern || '%'' OR ' ||
            'REGEXP_REPLACE(cont.whatsapp_number, ''[^0-9+]'', '''', ''g'') LIKE ''%' || v_phone_pattern || '%''' ||
        ')';
    END IF;
    
    -- General search term filter (name, job title, department)
    IF p_search_term IS NOT NULL AND TRIM(p_search_term) != '' THEN
        v_search_query := TRIM(LOWER(p_search_term));
        
        v_where_conditions := v_where_conditions || ' AND (' ||
            -- First name starts with
            'LOWER(cont.first_name) LIKE ''' || v_search_query || '%'' OR ' ||
            -- Last name starts with  
            'LOWER(cont.last_name) LIKE ''' || v_search_query || '%'' OR ' ||
            -- Full name contains
            'LOWER(cont.first_name || '' '' || cont.last_name) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Email contains
            'LOWER(COALESCE(cont.email, '''')) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Job title contains
            'LOWER(COALESCE(cont.job_title, '''')) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Department contains
            'LOWER(COALESCE(cont.department, '''')) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Customer name contains (helps find contacts by company)
            'LOWER(cust.customer_name) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Customer code contains
            'LOWER(cust.customer_code) LIKE ''%' || v_search_query || '%'' OR ' ||
            -- Full-text search on contact name (uses GIN index)
            'to_tsvector(''english'', cont.first_name || '' '' || cont.last_name) @@ plainto_tsquery(''english'', ''' || p_search_term || ''')' ||
        ')';
    END IF;
    
    -- =============================================================================
    -- EXECUTE SEARCH QUERY
    -- =============================================================================
    
    RETURN QUERY EXECUTE '
        SELECT 
            cont.id,
            cont.customer_id,
            cont.first_name,
            cont.last_name,
            cont.first_name || '' '' || cont.last_name as full_name,
            cont.job_title,
            cont.department,
            cont.email,
            cont.phone_number,
            cont.whatsapp_number,
            cont.is_primary_contact,
            cont.is_billing_contact,
            cont.status,
            ' || CASE WHEN p_include_customer_info THEN '
            cust.customer_code,
            cust.customer_name,
            cust.is_company,
            cust.status,
            ' ELSE '
            NULL::VARCHAR(20),
            NULL::VARCHAR(255),
            NULL::BOOLEAN,
            NULL::VARCHAR(20),
            ' END || '
            latest_interaction.last_interaction_date,
            cont.created_at,
            ' || 
            -- Calculate duplicate score for duplicate detection
            'CASE 
                WHEN ''' || COALESCE(p_email_search, '') || ''' != '''' AND LOWER(cont.email) = ''' || COALESCE(LOWER(TRIM(p_email_search)), '') || ''' THEN 100
                WHEN ''' || COALESCE(p_phone_search, '') || ''' != '''' AND (
                    REGEXP_REPLACE(cont.phone_number, ''[^0-9+]'', '''', ''g'') = ''' || COALESCE(REGEXP_REPLACE(TRIM(p_phone_search), '[^0-9+]', '', 'g'), '') || ''' OR
                    REGEXP_REPLACE(cont.whatsapp_number, ''[^0-9+]'', '''', ''g'') = ''' || COALESCE(REGEXP_REPLACE(TRIM(p_phone_search), '[^0-9+]', '', 'g'), '') || '''
                ) THEN 90
                WHEN ''' || COALESCE(p_search_term, '') || ''' != '''' AND LOWER(cont.first_name || '' '' || cont.last_name) = ''' || COALESCE(LOWER(TRIM(p_search_term)), '') || ''' THEN 80
                WHEN ''' || COALESCE(p_email_search, '') || ''' != '''' AND LOWER(cont.email) LIKE ''%' || COALESCE(LOWER(TRIM(p_email_search)), '') || '%'' THEN 70
                WHEN ''' || COALESCE(p_search_term, '') || ''' != '''' AND (
                    LOWER(cont.first_name) = ''' || COALESCE(LOWER(TRIM(p_search_term)), '') || ''' OR 
                    LOWER(cont.last_name) = ''' || COALESCE(LOWER(TRIM(p_search_term)), '') || '''
                ) THEN 60
                ELSE 0
            END as duplicate_score
        FROM core.contacts cont
        JOIN core.customers cust ON cont.customer_id = cust.id
        LEFT JOIN (
            SELECT 
                contact_id,
                MAX(created_at) as last_interaction_date
            FROM interactions.interactions
            GROUP BY contact_id
        ) latest_interaction ON cont.id = latest_interaction.contact_id
        WHERE ' || v_where_conditions || '
        ORDER BY 
            -- Prioritize exact matches for duplicate detection
            CASE 
                WHEN ''' || COALESCE(p_email_search, '') || ''' != '''' AND LOWER(cont.email) = ''' || COALESCE(LOWER(TRIM(p_email_search)), '') || ''' THEN 1
                WHEN ''' || COALESCE(p_phone_search, '') || ''' != '''' AND (
                    REGEXP_REPLACE(cont.phone_number, ''[^0-9+]'', '''', ''g'') = ''' || COALESCE(REGEXP_REPLACE(TRIM(p_phone_search), '[^0-9+]', '', 'g'), '') || ''' OR
                    REGEXP_REPLACE(cont.whatsapp_number, ''[^0-9+]'', '''', ''g'') = ''' || COALESCE(REGEXP_REPLACE(TRIM(p_phone_search), '[^0-9+]', '', 'g'), '') || '''
                ) THEN 1
                ELSE 2
            END,
            -- Then by duplicate score (higher first)
            CASE 
                WHEN ''' || COALESCE(p_email_search, '') || ''' != '''' AND LOWER(cont.email) = ''' || COALESCE(LOWER(TRIM(p_email_search)), '') || ''' THEN 100
                WHEN ''' || COALESCE(p_phone_search, '') || ''' != '''' AND (
                    REGEXP_REPLACE(cont.phone_number, ''[^0-9+]'', '''', ''g'') = ''' || COALESCE(REGEXP_REPLACE(TRIM(p_phone_search), '[^0-9+]', '', 'g'), '') || ''' OR
                    REGEXP_REPLACE(cont.whatsapp_number, ''[^0-9+]'', '''', ''g'') = ''' || COALESCE(REGEXP_REPLACE(TRIM(p_phone_search), '[^0-9+]', '', 'g'), '') || '''
                ) THEN 90
                ELSE 0
            END DESC,
            -- Then primary contacts first
            cont.is_primary_contact DESC,
            -- Then billing contacts
            cont.is_billing_contact DESC,
            -- Finally alphabetical by name
            cont.first_name, cont.last_name
        LIMIT ' || p_limit_results || ' 
        OFFSET ' || p_offset_results;
        
EXCEPTION 
    WHEN OTHERS THEN
        -- Return empty result set on error
        RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- HELPER FUNCTION: GET CONTACTS FOR SPECIFIC CUSTOMER
-- =============================================================================

-- Quick function to get all contacts for a specific customer (dropdown population)
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
-- HELPER FUNCTION: DETECT POTENTIAL DUPLICATES
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
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

COMMENT ON FUNCTION core.search_contacts IS 
'Generic contact search function with duplicate detection capabilities.
Supports searching within specific customers or across all customers.
Optimized for interaction selection and duplicate contact detection.';

COMMENT ON FUNCTION core.get_customer_contacts IS
'Quick lookup of all contacts for a specific customer. Used for dropdown population.';

COMMENT ON FUNCTION core.detect_duplicate_contacts IS
'Detect potential duplicate contacts based on email, phone, or name matching.
Returns confidence scores for duplicate likelihood.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Search all contacts named "John"
SELECT * FROM core.search_contacts('John');

-- Example 2: Search contacts within specific customer
SELECT * FROM core.search_contacts('Smith', 1001);

-- Example 3: Search by email (duplicate detection)
SELECT * FROM core.search_contacts(NULL, NULL, 'john@company.com');

-- Example 4: Search by phone (duplicate detection)
SELECT * FROM core.search_contacts(NULL, NULL, NULL, '+27112345678');

-- Example 5: Get all contacts for customer 1001
SELECT * FROM core.get_customer_contacts(1001);

-- Example 6: Get only primary contacts for customer 1001
SELECT * FROM core.search_contacts(NULL, 1001, NULL, NULL, 'active', 'active', true, true);

-- Example 7: Detect duplicates before creating new contact
SELECT * FROM core.detect_duplicate_contacts('new@email.com', '+27123456789', 'John', 'Smith');

-- Example 8: Search with pagination
SELECT * FROM core.search_contacts('Manager', NULL, NULL, NULL, 'active', 'active', true, false, false, 20, 40);

-- Example 9: Search contacts across inactive customers too
SELECT * FROM core.search_contacts('John', NULL, NULL, NULL, 'active', 'all');

-- Example 10: Search billing contacts only
SELECT * FROM core.search_contacts(NULL, NULL, NULL, NULL, 'active', 'active', true, false, true);
*/