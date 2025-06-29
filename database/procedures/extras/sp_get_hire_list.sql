-- Fixed version of sp_get_hire_list
-- The issue is likely in the date filtering logic

SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_hire_list(
    p_date_from DATE DEFAULT NULL,  -- Changed: NULL instead of calculated default
    p_date_to DATE DEFAULT NULL,    -- Changed: NULL instead of calculated default
    p_status_filter VARCHAR(50) DEFAULT NULL,
    p_customer_filter VARCHAR(255) DEFAULT NULL,
    p_search_term VARCHAR(255) DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    customer_name VARCHAR(255),
    contact_name TEXT,
    interaction_status VARCHAR(50),
    equipment_summary TEXT,
    delivery_date DATE,
    delivery_time TIME,
    allocation_status TEXT,
    qc_status TEXT,
    driver_status VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE,
    total_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH hire_data AS (
        SELECT 
            i.id,
            i.reference_number,
            c.customer_name,
            (ct.first_name || ' ' || ct.last_name) AS contact_name,
            i.status,
            -- Equipment summary
            (SELECT string_agg(
                et.type_code || ' (' || iet.quantity || ')',
                ', ' ORDER BY et.type_name
            )
            FROM interactions.interaction_equipment_types iet
            JOIN core.equipment_types et ON iet.equipment_type_id = et.id
            WHERE iet.interaction_id = i.id
            ) AS equipment_summary,
            dt.scheduled_date,
            dt.scheduled_time,
            -- Allocation status
            CASE 
                WHEN COUNT(iet.id) = 0 THEN 'No equipment'
                WHEN COUNT(CASE WHEN iet.booking_status = 'allocated' THEN 1 END) = COUNT(iet.id) 
                    THEN 'Fully allocated'
                WHEN COUNT(CASE WHEN iet.booking_status = 'allocated' THEN 1 END) > 0 
                    THEN 'Partially allocated'
                ELSE 'Not allocated'
            END AS allocation_status,
            -- QC status
            CASE 
                WHEN COUNT(ie.id) = 0 THEN 'No equipment allocated'
                WHEN COUNT(CASE WHEN ie.quality_check_status = 'passed' THEN 1 END) = COUNT(ie.id)
                    THEN 'QC complete'
                WHEN COUNT(CASE WHEN ie.quality_check_status = 'pending' THEN 1 END) > 0
                    THEN 'QC pending'
                WHEN COUNT(CASE WHEN ie.quality_check_status = 'failed' THEN 1 END) > 0
                    THEN 'QC issues'
                ELSE 'QC not started'
            END AS qc_status,
            dt.status AS driver_status,
            i.created_at,
            COUNT(*) OVER() AS total_count
        FROM interactions.interactions i
        JOIN core.customers c ON i.customer_id = c.id
        JOIN core.contacts ct ON i.contact_id = ct.id
        LEFT JOIN interactions.interaction_equipment_types iet ON i.id = iet.interaction_id
        LEFT JOIN interactions.interaction_equipment ie ON iet.id = ie.equipment_type_booking_id
        LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
        WHERE 
            i.interaction_type = 'hire'
            -- Fixed date filtering: only apply if parameters are provided
            AND (p_date_from IS NULL OR i.created_at::DATE >= p_date_from)
            AND (p_date_to IS NULL OR i.created_at::DATE <= p_date_to)
            AND (p_status_filter IS NULL OR i.status = p_status_filter)
            AND (p_customer_filter IS NULL OR c.customer_name ILIKE '%' || p_customer_filter || '%')
            AND (p_search_term IS NULL OR 
                 i.reference_number ILIKE '%' || p_search_term || '%' OR
                 c.customer_name ILIKE '%' || p_search_term || '%' OR
                 (ct.first_name || ' ' || ct.last_name) ILIKE '%' || p_search_term || '%')
        GROUP BY i.id, i.reference_number, i.status, c.customer_name,
                 ct.first_name, ct.last_name, dt.scheduled_date, dt.scheduled_time,
                 dt.status, i.created_at
        ORDER BY i.created_at DESC
        LIMIT p_limit OFFSET p_offset
    )
    SELECT 
        hd.id,
        hd.reference_number,
        hd.customer_name,
        hd.contact_name,
        hd.status,
        hd.equipment_summary,
        hd.scheduled_date,
        hd.scheduled_time,
        hd.allocation_status,
        hd.qc_status,
        hd.driver_status,
        hd.created_at,
        COALESCE(hd.total_count, 0)::INTEGER
    FROM hire_data hd;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_hire_list IS 'Get paginated list of hire interactions with filters - FIXED version that handles NULL dates correctly';