SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_check_equipment_availability(
    p_equipment_requests JSONB,  -- Equipment type requests with dates
    p_check_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    equipment_type_id INTEGER,
    type_name VARCHAR(255),
    requested_quantity INTEGER,
    available_quantity INTEGER,
    is_available BOOLEAN,
    message TEXT
) AS $$
DECLARE
    request JSONB;
    type_id INTEGER;
    requested_qty INTEGER;
    available_qty INTEGER;
BEGIN
    FOR request IN SELECT jsonb_array_elements(p_equipment_requests)
    LOOP
        type_id := (request->>'equipment_type_id')::INTEGER;
        requested_qty := (request->>'quantity')::INTEGER;
        
        -- Count available equipment of this type
        SELECT COUNT(*)::INTEGER INTO available_qty
        FROM core.equipment e
        WHERE e.equipment_type_id = type_id
          AND e.status = 'available'
          AND e.condition IN ('excellent', 'good', 'fair');
        
        RETURN QUERY
        SELECT 
            type_id,
            et.type_name,
            requested_qty,
            available_qty,
            (available_qty >= requested_qty) AS is_available,
            CASE 
                WHEN available_qty >= requested_qty THEN 'Available'
                ELSE 'Only ' || available_qty || ' available, ' || requested_qty || ' requested'
            END AS message
        FROM core.equipment_types et
        WHERE et.id = type_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_check_equipment_availability IS 'Check equipment availability for requested dates and quantities';