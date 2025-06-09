-- =============================================================================
-- CUSTOMER EQUIPMENT & SITE HELPER PROCEDURES
-- =============================================================================
-- Purpose: Helper functions for breakdown workflow and equipment management
-- These support the scenario where employees need to find customer equipment/sites
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- 1. GET CUSTOMER SITES
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_customer_sites;

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
-- 2. GET CUSTOMER EQUIPMENT HISTORY
-- =============================================================================

-- Get equipment that has been hired/delivered to a customer based on interaction history
DROP FUNCTION IF EXISTS core.get_customer_equipment_history;

CREATE OR REPLACE FUNCTION core.get_customer_equipment_history(
    p_customer_id INTEGER,
    p_site_id INTEGER DEFAULT NULL,        -- Filter by specific site
    p_equipment_search TEXT DEFAULT NULL,  -- Search equipment names
    p_days_back INTEGER DEFAULT 365,       -- How far back to look
    p_active_hires_only BOOLEAN DEFAULT false -- Only equipment currently on hire
)
RETURNS TABLE(
    equipment_category_id INTEGER,
    equipment_code VARCHAR(20),
    equipment_name VARCHAR(255),
    equipment_description TEXT,
    total_hire_count INTEGER,
    last_hire_date TIMESTAMP WITH TIME ZONE,
    last_hire_reference VARCHAR(20),
    current_status VARCHAR(50),
    site_id INTEGER,
    site_name VARCHAR(255),
    site_address TEXT,
    total_quantity INTEGER,
    last_interaction_type VARCHAR(50)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.id,
        ec.category_code,
        ec.category_name,
        ec.description,
        COUNT(DISTINCT i.id)::INTEGER as total_hire_count,
        MAX(i.created_at) as last_hire_date,
        (SELECT i2.reference_number FROM interactions.interactions i2 
         JOIN interactions.component_equipment_list cel2 ON i2.id = cel2.interaction_id
         WHERE i2.customer_id = p_customer_id AND cel2.equipment_category_id = ec.id
         ORDER BY i2.created_at DESC LIMIT 1) as last_hire_reference,
        CASE 
            WHEN MAX(CASE WHEN i.interaction_type = 'off_hire' THEN i.created_at END) > 
                 MAX(CASE WHEN i.interaction_type = 'hire' THEN i.created_at END) 
            THEN 'returned'
            WHEN MAX(CASE WHEN i.interaction_type = 'hire' THEN i.created_at END) IS NOT NULL
            THEN 'on_hire'
            ELSE 'unknown'
        END as current_status,
        (SELECT hd.site_id FROM interactions.component_hire_details hd 
         JOIN interactions.interactions i3 ON hd.interaction_id = i3.id
         JOIN interactions.component_equipment_list cel3 ON i3.id = cel3.interaction_id
         WHERE i3.customer_id = p_customer_id AND cel3.equipment_category_id = ec.id
         ORDER BY i3.created_at DESC LIMIT 1) as site_id,
        (SELECT s.site_name FROM core.sites s
         JOIN interactions.component_hire_details hd ON s.id = hd.site_id
         JOIN interactions.interactions i4 ON hd.interaction_id = i4.id
         JOIN interactions.component_equipment_list cel4 ON i4.id = cel4.interaction_id
         WHERE i4.customer_id = p_customer_id AND cel4.equipment_category_id = ec.id
         ORDER BY i4.created_at DESC LIMIT 1) as site_name,
        (SELECT s.address_line1 || ', ' || s.city FROM core.sites s
         JOIN interactions.component_hire_details hd ON s.id = hd.site_id
         JOIN interactions.interactions i5 ON hd.interaction_id = i5.id
         JOIN interactions.component_equipment_list cel5 ON i5.id = cel5.interaction_id
         WHERE i5.customer_id = p_customer_id AND cel5.equipment_category_id = ec.id
         ORDER BY i5.created_at DESC LIMIT 1) as site_address,
        SUM(cel.quantity)::INTEGER as total_quantity,
        (SELECT i6.interaction_type FROM interactions.interactions i6 
         JOIN interactions.component_equipment_list cel6 ON i6.id = cel6.interaction_id
         WHERE i6.customer_id = p_customer_id AND cel6.equipment_category_id = ec.id
         ORDER BY i6.created_at DESC LIMIT 1) as last_interaction_type
    FROM core.equipment_categories ec
    JOIN interactions.component_equipment_list cel ON ec.id = cel.equipment_category_id
    JOIN interactions.interactions i ON cel.interaction_id = i.id
    LEFT JOIN interactions.component_hire_details hd ON i.id = hd.interaction_id
    WHERE i.customer_id = p_customer_id
    AND i.created_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
    AND (p_site_id IS NULL OR hd.site_id = p_site_id)
    AND (p_equipment_search IS NULL OR 
         LOWER(ec.category_name) LIKE '%' || LOWER(p_equipment_search) || '%' OR
         LOWER(ec.category_code) LIKE '%' || LOWER(p_equipment_search) || '%')
    AND (NOT p_active_hires_only OR 
         (SELECT COUNT(*) FROM interactions.interactions i_hire 
          JOIN interactions.component_equipment_list cel_hire ON i_hire.id = cel_hire.interaction_id
          WHERE i_hire.customer_id = p_customer_id 
          AND cel_hire.equipment_category_id = ec.id
          AND i_hire.interaction_type = 'hire'
          AND i_hire.created_at > COALESCE(
              (SELECT MAX(i_off.created_at) FROM interactions.interactions i_off
               JOIN interactions.component_equipment_list cel_off ON i_off.id = cel_off.interaction_id
               WHERE i_off.customer_id = p_customer_id 
               AND cel_off.equipment_category_id = ec.id
               AND i_off.interaction_type = 'off_hire'), 
              '1900-01-01'::timestamp)) > 0)
    GROUP BY ec.id, ec.category_code, ec.category_name, ec.description
    ORDER BY MAX(i.created_at) DESC, ec.category_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 3. GET CUSTOMER EQUIPMENT AND SITES COMBINED
-- =============================================================================

-- Combined view showing equipment at each site for breakdown workflow
DROP FUNCTION IF EXISTS core.get_customer_equipment_by_site;

CREATE OR REPLACE FUNCTION core.get_customer_equipment_by_site(
    p_customer_id INTEGER,
    p_search_term TEXT DEFAULT NULL,
    p_days_back INTEGER DEFAULT 180,
    p_active_only BOOLEAN DEFAULT true
)
RETURNS TABLE(
    site_id INTEGER,
    site_name VARCHAR(255),
    site_code VARCHAR(20),
    site_address TEXT,
    site_contact_name VARCHAR(200),
    site_contact_phone VARCHAR(20),
    equipment_category_id INTEGER,
    equipment_code VARCHAR(20),
    equipment_name VARCHAR(255),
    equipment_quantity INTEGER,
    equipment_status VARCHAR(50),
    last_activity_date TIMESTAMP WITH TIME ZONE,
    last_activity_type VARCHAR(50),
    last_reference_number VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    WITH site_equipment AS (
        SELECT DISTINCT
            COALESCE(hd.site_id, 
                     (SELECT s.id FROM core.sites s WHERE s.customer_id = i.customer_id 
                      AND s.site_type = 'head_office' LIMIT 1)) as site_id,
            cel.equipment_category_id,
            SUM(cel.quantity) as total_quantity,
            MAX(i.created_at) as last_activity_date,
            (SELECT i2.interaction_type FROM interactions.interactions i2 
             JOIN interactions.component_equipment_list cel2 ON i2.id = cel2.interaction_id
             LEFT JOIN interactions.component_hire_details hd2 ON i2.id = hd2.interaction_id
             WHERE i2.customer_id = p_customer_id 
             AND cel2.equipment_category_id = cel.equipment_category_id
             AND (hd2.site_id = COALESCE(hd.site_id, 
                  (SELECT s.id FROM core.sites s WHERE s.customer_id = i.customer_id 
                   AND s.site_type = 'head_office' LIMIT 1)) OR hd2.site_id IS NULL)
             ORDER BY i2.created_at DESC LIMIT 1) as last_activity_type,
            (SELECT i3.reference_number FROM interactions.interactions i3 
             JOIN interactions.component_equipment_list cel3 ON i3.id = cel3.interaction_id
             LEFT JOIN interactions.component_hire_details hd3 ON i3.id = hd3.interaction_id
             WHERE i3.customer_id = p_customer_id 
             AND cel3.equipment_category_id = cel.equipment_category_id
             AND (hd3.site_id = COALESCE(hd.site_id, 
                  (SELECT s.id FROM core.sites s WHERE s.customer_id = i.customer_id 
                   AND s.site_type = 'head_office' LIMIT 1)) OR hd3.site_id IS NULL)
             ORDER BY i3.created_at DESC LIMIT 1) as last_reference_number
        FROM interactions.interactions i
        JOIN interactions.component_equipment_list cel ON i.id = cel.interaction_id
        LEFT JOIN interactions.component_hire_details hd ON i.id = hd.interaction_id
        WHERE i.customer_id = p_customer_id
        AND i.created_at >= CURRENT_DATE - (p_days_back || ' days')::INTERVAL
        AND i.interaction_type IN ('hire', 'delivery', 'breakdown')
        GROUP BY COALESCE(hd.site_id, 
                         (SELECT s.id FROM core.sites s WHERE s.customer_id = i.customer_id 
                          AND s.site_type = 'head_office' LIMIT 1)), 
                 cel.equipment_category_id
    )
    SELECT 
        s.id,
        s.site_name,
        s.site_code,
        s.address_line1 || ', ' || s.city as site_address,
        s.site_contact_name,
        s.site_contact_phone,
        ec.id,
        ec.category_code,
        ec.category_name,
        se.total_quantity::INTEGER,
        CASE 
            WHEN se.last_activity_type = 'off_hire' THEN 'returned'
            WHEN se.last_activity_type = 'hire' THEN 'on_hire'
            WHEN se.last_activity_type = 'breakdown' THEN 'breakdown_reported'
            ELSE 'unknown'
        END as equipment_status,
        se.last_activity_date,
        se.last_activity_type,
        se.last_reference_number
    FROM site_equipment se
    JOIN core.sites s ON se.site_id = s.id
    JOIN core.equipment_categories ec ON se.equipment_category_id = ec.id
    WHERE (NOT p_active_only OR s.is_active = true)
    AND (p_search_term IS NULL OR 
         LOWER(s.site_name) LIKE '%' || LOWER(p_search_term) || '%' OR
         LOWER(ec.category_name) LIKE '%' || LOWER(p_search_term) || '%' OR
         LOWER(s.city) LIKE '%' || LOWER(p_search_term) || '%')
    ORDER BY s.site_name, ec.category_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 4. SEARCH EQUIPMENT FOR BREAKDOWN (Main function for your workflow)
-- =============================================================================

-- Primary function for the breakdown workflow
DROP FUNCTION IF EXISTS core.search_equipment_for_breakdown;

CREATE OR REPLACE FUNCTION core.search_equipment_for_breakdown(
    p_customer_id INTEGER,
    p_search_term TEXT DEFAULT NULL,
    p_site_filter INTEGER DEFAULT NULL,
    p_equipment_filter TEXT DEFAULT NULL
)
RETURNS TABLE(
    selectable_id VARCHAR(50),       -- Format: "site_id:equipment_id" for frontend
    display_text TEXT,               -- Human readable display
    site_id INTEGER,
    site_name VARCHAR(255),
    site_address TEXT,
    equipment_category_id INTEGER,
    equipment_name VARCHAR(255),
    equipment_code VARCHAR(20),
    equipment_quantity INTEGER,
    equipment_status VARCHAR(50),
    last_activity VARCHAR(100),
    can_report_breakdown BOOLEAN,
    site_contact_phone VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (cebs.site_id::TEXT || ':' || cebs.equipment_category_id::TEXT) as selectable_id,
        (cebs.site_name || ' - ' || cebs.equipment_name || 
         CASE WHEN cebs.equipment_quantity > 1 THEN ' (Qty: ' || cebs.equipment_quantity || ')' ELSE '' END) as display_text,
        cebs.site_id,
        cebs.site_name,
        cebs.site_address,
        cebs.equipment_category_id,
        cebs.equipment_name,
        cebs.equipment_code,
        cebs.equipment_quantity,
        cebs.equipment_status,
        (cebs.last_activity_type || ' on ' || cebs.last_activity_date::DATE::TEXT || ' (' || cebs.last_reference_number || ')') as last_activity,
        (cebs.equipment_status IN ('on_hire', 'breakdown_reported')) as can_report_breakdown,
        cebs.site_contact_phone
    FROM core.get_customer_equipment_by_site(
        p_customer_id, 
        p_search_term, 
        180,  -- Look back 6 months
        true  -- Active sites only
    ) AS cebs
    WHERE (p_site_filter IS NULL OR cebs.site_id = p_site_filter)
    AND (p_equipment_filter IS NULL OR 
         LOWER(cebs.equipment_name) LIKE '%' || LOWER(p_equipment_filter) || '%')
    AND cebs.equipment_status != 'returned'  -- Don't show returned equipment
    ORDER BY 
        cebs.site_name,
        cebs.equipment_name,
        cebs.last_activity_date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. HELPER FUNCTION: GET EQUIPMENT DETAILS
-- =============================================================================

-- Get detailed equipment information for breakdown forms
DROP FUNCTION IF EXISTS core.get_equipment_details;

CREATE OR REPLACE FUNCTION core.get_equipment_details(p_equipment_category_id INTEGER)
RETURNS TABLE(
    equipment_id INTEGER,
    equipment_code VARCHAR(20),
    equipment_name VARCHAR(255),
    description TEXT,
    specifications TEXT,
    default_accessories TEXT,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.id,
        ec.category_code,
        ec.category_name,
        ec.description,
        ec.specifications,
        ec.default_accessories,
        ec.is_active
    FROM core.equipment_categories ec
    WHERE ec.id = p_equipment_category_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

COMMENT ON FUNCTION core.get_customer_sites IS 
'Get all sites for a customer with optional filtering and search.
Used for site selection in breakdown and other workflows.';

COMMENT ON FUNCTION core.get_customer_equipment_history IS 
'Get equipment history for a customer showing what has been hired/delivered.
Tracks equipment status and location based on interaction history.';

COMMENT ON FUNCTION core.get_customer_equipment_by_site IS 
'Combined view of equipment at each customer site.
Shows current equipment status and location for operational workflows.';

COMMENT ON FUNCTION core.search_equipment_for_breakdown IS 
'Primary search function for breakdown workflow.
Returns equipment that can be reported as broken down, organized by site.';

COMMENT ON FUNCTION core.get_equipment_details IS 
'Get detailed equipment category information including specifications and accessories.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example 1: Get all sites for ABC Construction (customer_id = 1000)
SELECT * FROM core.get_customer_sites(1000);

-- Example 2: Get project sites only
SELECT * FROM core.get_customer_sites(1000, 'project_site');

-- Example 3: Search sites containing "sandton"
SELECT * FROM core.get_customer_sites(1000, NULL, 'sandton');

-- Example 4: Get equipment history for customer
SELECT * FROM core.get_customer_equipment_history(1000);

-- Example 5: Get only currently hired equipment
SELECT * FROM core.get_customer_equipment_history(1000, NULL, NULL, 365, true);

-- Example 6: Get equipment by site (for breakdown workflow)
SELECT * FROM core.get_customer_equipment_by_site(1000);

-- Example 7: Search for specific equipment
SELECT * FROM core.get_customer_equipment_by_site(1000, 'excavator');

-- Example 8: Main breakdown search function
SELECT * FROM core.search_equipment_for_breakdown(1000);

-- Example 9: Search for rammer at specific site
SELECT * FROM core.search_equipment_for_breakdown(1000, 'rammer', 1001);

-- Example 10: Get equipment details
SELECT * FROM core.get_equipment_details(5);

-- BREAKDOWN WORKFLOW EXAMPLE:
-- 1. Employee selects customer "ABC Construction" (customer_id = 1000)
-- 2. System calls: SELECT * FROM core.search_equipment_for_breakdown(1000);
-- 3. Employee sees list: "Sandton Project Site - Rammer (HR250606001)"
-- 4. Employee can search: SELECT * FROM core.search_equipment_for_breakdown(1000, 'rammer');
-- 5. Employee selects equipment using selectable_id: "1001:5"
-- 6. System creates breakdown interaction with site_id=1001, equipment_id=5
*/