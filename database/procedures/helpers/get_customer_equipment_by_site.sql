-- =============================================================================
-- HELPERS: Combined view of equipment at each customer site
-- =============================================================================
-- Purpose: Combined view of equipment at each customer site
-- Dependencies: core.sites, interactions.component_equipment_list
-- Used by: Site-based equipment management, breakdown workflow
-- Function: core.get_customer_equipment_by_site
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_customer_equipment_by_site;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

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
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.get_customer_equipment_by_site TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION core.get_customer_equipment_by_site TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.get_customer_equipment_by_site TO manager;
-- GRANT EXECUTE ON FUNCTION core.get_customer_equipment_by_site TO owner;

-- Add function documentation
COMMENT ON FUNCTION core.get_customer_equipment_by_site IS 
'Combined view of equipment at each customer site. Helper function used by Site-based equipment management, breakdown workflow.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.get_customer_equipment_by_site(param1, param2);

-- Additional examples for this specific function
*/
