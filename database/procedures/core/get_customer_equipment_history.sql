-- =============================================================================
-- HELPERS: Get equipment history for customer showing hire/delivery status
-- =============================================================================
-- Purpose: Get equipment history for customer showing hire/delivery status
-- Dependencies: interactions.interactions, component_equipment_list
-- Used by: Equipment status tracking, breakdown workflow
-- Function: core.get_customer_equipment_history
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS core.get_customer_equipment_history;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

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
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION core.get_customer_equipment_history TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION core.get_customer_equipment_history TO hire_control;
-- GRANT EXECUTE ON FUNCTION core.get_customer_equipment_history TO manager;
-- GRANT EXECUTE ON FUNCTION core.get_customer_equipment_history TO owner;

-- Add function documentation
COMMENT ON FUNCTION core.get_customer_equipment_history IS 
'Get equipment history for customer showing hire/delivery status. Helper function used by Equipment status tracking, breakdown workflow.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM core.get_customer_equipment_history(param1, param2);

-- Additional examples for this specific function
*/
