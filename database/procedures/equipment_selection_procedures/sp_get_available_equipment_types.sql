SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_available_equipment_types(
    p_search_term TEXT DEFAULT NULL,
    p_delivery_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    equipment_type_id INTEGER,
    type_code VARCHAR(20),
    type_name VARCHAR(255),
    description TEXT,
    specifications TEXT,
    total_units INTEGER,
    available_units INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        et.id,
        et.type_code,
        et.type_name,
        et.description,
        et.specifications,
        COUNT(e.id)::INTEGER AS total_units,
        COUNT(CASE WHEN e.status = 'available' THEN 1 END)::INTEGER AS available_units
    FROM core.equipment_types et
    LEFT JOIN core.equipment e ON et.id = e.equipment_type_id
    WHERE 
        et.is_active = TRUE
        AND (
            p_search_term IS NULL 
            OR et.type_name ILIKE '%' || p_search_term || '%'
            OR et.type_code ILIKE '%' || p_search_term || '%'
            OR et.description ILIKE '%' || p_search_term || '%'
        )
    GROUP BY et.id, et.type_code, et.type_name, et.description, et.specifications
    HAVING COUNT(CASE WHEN e.status = 'available' THEN 1 END) > 0
    ORDER BY et.type_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_available_equipment_types IS 'Get equipment types with availability for generic booking';