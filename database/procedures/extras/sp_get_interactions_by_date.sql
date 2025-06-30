
SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_interactions_by_date(
    p_target_date DATE DEFAULT CURRENT_DATE,
    p_search_term VARCHAR(255) DEFAULT NULL
)
RETURNS TABLE(
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    customer_name VARCHAR(255),
    contact_name TEXT,
    interaction_status VARCHAR(50),
    equipment_count INTEGER,
    delivery_time TEXT,
    priority_score INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.reference_number,
        c.customer_name,
        (ct.first_name || ' ' || ct.last_name) AS contact_name,
        i.status,
        COALESCE((
            SELECT COUNT(*)::INTEGER
            FROM interactions.interaction_equipment_types iet
            WHERE iet.interaction_id = i.id
        ), 0) AS equipment_count,
        COALESCE(dt.scheduled_time::TEXT, '') AS delivery_time,
        -- Priority score for sorting (urgent items first)
        CASE 
            WHEN dt.priority = 'urgent' THEN 1
            WHEN dt.priority = 'high' THEN 2
            WHEN dt.priority = 'medium' THEN 3
            ELSE 4
        END AS priority_score,
        i.created_at
    FROM interactions.interactions i
    JOIN core.customers c ON i.customer_id = c.id
    JOIN core.contacts ct ON i.contact_id = ct.id
    LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
    WHERE 
        i.interaction_type = 'hire'
        AND (
            i.created_at::DATE = p_target_date OR 
            dt.scheduled_date = p_target_date
        )
        AND (
            p_search_term IS NULL OR 
            i.reference_number ILIKE '%' || p_search_term || '%' OR
            c.customer_name ILIKE '%' || p_search_term || '%' OR
            (ct.first_name || ' ' || ct.last_name) ILIKE '%' || p_search_term || '%'
        )
    ORDER BY priority_score, dt.scheduled_time NULLS LAST, i.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_interactions_by_date IS 'Get interactions for a specific date with search filtering - optimized for calendar view';
