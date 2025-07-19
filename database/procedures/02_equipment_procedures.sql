-- =============================================================================
-- EQUIPMENT SELECTION AND MANAGEMENT PROCEDURES
-- =============================================================================

-- Get available equipment types for selection
CREATE OR REPLACE FUNCTION sp_get_available_equipment_types(
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_hire_start_date DATE DEFAULT CURRENT_DATE,
    p_hire_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    equipment_type_id INTEGER,
    type_code VARCHAR(20),
    type_name VARCHAR(255),
    description TEXT,
    specifications TEXT,
    daily_rate DECIMAL(10,2),
    weekly_rate DECIMAL(10,2),
    monthly_rate DECIMAL(10,2),
    available_units INTEGER,
    total_units INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        et.id,
        et.type_code,
        et.type_name,
        et.description,
        et.specifications,
        et.daily_rate,
        et.weekly_rate,
        et.monthly_rate,
        -- Available units calculation
        COALESCE(
            (SELECT COUNT(*)::INTEGER
             FROM equipment.equipment e
             WHERE e.equipment_type_id = et.id
               AND e.status = 'available'
               AND e.id NOT IN (
                   -- Exclude equipment already allocated for overlapping periods
                   SELECT ie.equipment_id
                   FROM interactions.interaction_equipment ie
                   JOIN interactions.interactions i ON ie.interaction_id = i.id
                   WHERE i.interaction_type = 'hire'
                     AND i.status NOT IN ('cancelled', 'completed')
                     AND (
                         (i.hire_start_date <= COALESCE(p_hire_end_date, p_hire_start_date))
                         AND (COALESCE(i.hire_end_date, i.hire_start_date + INTERVAL '30 days') >= p_hire_start_date)
                     )
               )), 0),
        -- Total units
        (SELECT COUNT(*)::INTEGER
         FROM equipment.equipment e
         WHERE e.equipment_type_id = et.id
           AND e.status IN ('available', 'rented'))
    FROM equipment.equipment_types et
    WHERE 
        et.is_active = true
        AND (
            p_search_term IS NULL 
            OR et.type_name ILIKE '%' || p_search_term || '%'
            OR et.type_code ILIKE '%' || p_search_term || '%'
            OR et.description ILIKE '%' || p_search_term || '%'
        )
    ORDER BY et.type_name;
END;
$$ LANGUAGE plpgsql;

-- Get individual equipment units for specific selection
CREATE OR REPLACE FUNCTION sp_get_available_individual_equipment(
    p_equipment_type_id INTEGER DEFAULT NULL,
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_hire_start_date DATE DEFAULT CURRENT_DATE,
    p_hire_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    equipment_id INTEGER,
    asset_code VARCHAR(20),
    equipment_type_id INTEGER,
    type_name VARCHAR(255),
    model VARCHAR(100),
    serial_number VARCHAR(50),
    condition VARCHAR(20),
    location VARCHAR(100),
    last_service_date DATE,
    next_service_due DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.asset_code,
        e.equipment_type_id,
        et.type_name,
        e.model,
        e.serial_number,
        e.condition,
        e.location,
        e.last_service_date,
        e.next_service_due
    FROM equipment.equipment e
    JOIN equipment.equipment_types et ON e.equipment_type_id = et.id
    WHERE 
        e.status = 'available'
        AND et.is_active = true
        AND (p_equipment_type_id IS NULL OR e.equipment_type_id = p_equipment_type_id)
        AND (
            p_search_term IS NULL 
            OR e.asset_code ILIKE '%' || p_search_term || '%'
            OR et.type_name ILIKE '%' || p_search_term || '%'
            OR e.model ILIKE '%' || p_search_term || '%'
        )
        AND e.id NOT IN (
            -- Exclude equipment already allocated for overlapping periods
            SELECT ie.equipment_id
            FROM interactions.interaction_equipment ie
            JOIN interactions.interactions i ON ie.interaction_id = i.id
            WHERE i.interaction_type = 'hire'
              AND i.status NOT IN ('cancelled', 'completed')
              AND (
                  (i.hire_start_date <= COALESCE(p_hire_end_date, p_hire_start_date))
                  AND (COALESCE(i.hire_end_date, i.hire_start_date + INTERVAL '30 days') >= p_hire_start_date)
              )
        )
    ORDER BY et.type_name, e.condition DESC, e.asset_code;
END;
$$ LANGUAGE plpgsql;

-- Get equipment accessories (both default and optional)
CREATE OR REPLACE FUNCTION sp_get_equipment_accessories(
    p_equipment_type_id INTEGER
)
RETURNS TABLE (
    accessory_id INTEGER,
    accessory_code VARCHAR(50),
    accessory_name VARCHAR(255),
    description TEXT,
    accessory_type VARCHAR(20),
    default_quantity DECIMAL(8,2),
    unit_of_measure VARCHAR(20),
    unit_rate DECIMAL(10,2),
    is_consumable BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.accessory_code,
        a.accessory_name,
        a.description,
        ea.accessory_type,
        ea.default_quantity,
        a.unit_of_measure,
        a.unit_rate,
        a.is_consumable
    FROM equipment.equipment_accessories ea
    JOIN equipment.accessories a ON ea.accessory_id = a.id
    WHERE 
        ea.equipment_type_id = p_equipment_type_id
        AND a.status = 'active'
    ORDER BY 
        CASE ea.accessory_type WHEN 'default' THEN 1 ELSE 2 END,
        a.accessory_name;
END;
$$ LANGUAGE plpgsql;

-- Calculate automatic accessories for equipment selection
CREATE OR REPLACE FUNCTION sp_calculate_auto_accessories(
    p_equipment_types_json TEXT -- JSON array of {equipment_type_id, quantity}
)
RETURNS TABLE (
    accessory_id INTEGER,
    accessory_code VARCHAR(50),
    accessory_name VARCHAR(255),
    total_quantity DECIMAL(8,2),
    unit_of_measure VARCHAR(20),
    unit_rate DECIMAL(10,2),
    accessory_type VARCHAR(20)
) AS $$
DECLARE
    v_equipment_type RECORD;
    v_equipment_data JSONB;
BEGIN
    -- Parse JSON input
    v_equipment_data := p_equipment_types_json::JSONB;
    
    -- Return aggregated accessories
    RETURN QUERY
    WITH equipment_selections AS (
        SELECT 
            (item->>'equipment_type_id')::INTEGER as equipment_type_id,
            (item->>'quantity')::INTEGER as quantity
        FROM jsonb_array_elements(v_equipment_data) item
    ),
    accessory_calculations AS (
        SELECT 
            a.id as accessory_id,
            a.accessory_code,
            a.accessory_name,
            SUM(ea.default_quantity * es.quantity) as total_quantity,
            a.unit_of_measure,
            a.unit_rate,
            'default' as accessory_type
        FROM equipment_selections es
        JOIN equipment.equipment_accessories ea ON es.equipment_type_id = ea.equipment_type_id
        JOIN equipment.accessories a ON ea.accessory_id = a.id
        WHERE ea.accessory_type = 'default'
          AND a.status = 'active'
        GROUP BY a.id, a.accessory_code, a.accessory_name, a.unit_of_measure, a.unit_rate
        
        UNION ALL
        
        -- Include optional accessories with 0 quantity for frontend selection
        SELECT DISTINCT
            a.id as accessory_id,
            a.accessory_code,
            a.accessory_name,
            0::DECIMAL(8,2) as total_quantity,
            a.unit_of_measure,
            a.unit_rate,
            'optional' as accessory_type
        FROM equipment_selections es
        JOIN equipment.equipment_accessories ea ON es.equipment_type_id = ea.equipment_type_id
        JOIN equipment.accessories a ON ea.accessory_id = a.id
        WHERE ea.accessory_type = 'optional'
          AND a.status = 'active'
    )
    SELECT 
        ac.accessory_id,
        ac.accessory_code,
        ac.accessory_name,
        ac.total_quantity,
        ac.unit_of_measure,
        ac.unit_rate,
        ac.accessory_type
    FROM accessory_calculations ac
    ORDER BY 
        CASE ac.accessory_type WHEN 'default' THEN 1 ELSE 2 END,
        ac.accessory_name;
END;
$$ LANGUAGE plpgsql;

-- Get standalone accessories (not tied to equipment)
CREATE OR REPLACE FUNCTION sp_get_standalone_accessories(
    p_search_term VARCHAR(100) DEFAULT NULL
)
RETURNS TABLE (
    accessory_id INTEGER,
    accessory_code VARCHAR(50),
    accessory_name VARCHAR(255),
    description TEXT,
    unit_of_measure VARCHAR(20),
    unit_rate DECIMAL(10,2),
    is_consumable BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.accessory_code,
        a.accessory_name,
        a.description,
        a.unit_of_measure,
        a.unit_rate,
        a.is_consumable
    FROM equipment.accessories a
    WHERE 
        a.status = 'active'
        AND (
            p_search_term IS NULL 
            OR a.accessory_name ILIKE '%' || p_search_term || '%'
            OR a.accessory_code ILIKE '%' || p_search_term || '%'
            OR a.description ILIKE '%' || p_search_term || '%'
        )
    ORDER BY a.accessory_name;
END;
$$ LANGUAGE plpgsql;

-- Check equipment availability for date range
CREATE OR REPLACE FUNCTION sp_check_equipment_availability(
    p_equipment_type_id INTEGER,
    p_quantity INTEGER,
    p_hire_start_date DATE,
    p_hire_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    is_available BOOLEAN,
    available_quantity INTEGER,
    next_available_date DATE,
    conflicts TEXT
) AS $$
DECLARE
    v_total_units INTEGER;
    v_available_units INTEGER;
    v_next_date DATE;
    v_conflicts TEXT := '';
BEGIN
    -- Get total units of this type
    SELECT COUNT(*) INTO v_total_units
    FROM equipment.equipment e
    WHERE e.equipment_type_id = p_equipment_type_id
      AND e.status IN ('available', 'rented');
    
    -- Calculate available units for the period
    SELECT COUNT(*) INTO v_available_units
    FROM equipment.equipment e
    WHERE e.equipment_type_id = p_equipment_type_id
      AND e.status = 'available'
      AND e.id NOT IN (
          SELECT ie.equipment_id
          FROM interactions.interaction_equipment ie
          JOIN interactions.interactions i ON ie.interaction_id = i.id
          WHERE i.interaction_type = 'hire'
            AND i.status NOT IN ('cancelled', 'completed')
            AND (
                (i.hire_start_date <= COALESCE(p_hire_end_date, p_hire_start_date))
                AND (COALESCE(i.hire_end_date, i.hire_start_date + INTERVAL '30 days') >= p_hire_start_date)
            )
      );
    
    -- Find next available date if insufficient units
    IF v_available_units < p_quantity THEN
        SELECT MIN(COALESCE(i.hire_end_date, i.hire_start_date + INTERVAL '30 days') + INTERVAL '1 day')
        INTO v_next_date
        FROM interactions.interactions i
        JOIN interactions.interaction_equipment ie ON i.id = ie.interaction_id
        JOIN equipment.equipment e ON ie.equipment_id = e.id
        WHERE e.equipment_type_id = p_equipment_type_id
          AND i.interaction_type = 'hire'
          AND i.status NOT IN ('cancelled', 'completed')
          AND i.hire_start_date <= COALESCE(p_hire_end_date, p_hire_start_date);
    END IF;
    
    RETURN QUERY
    SELECT 
        (v_available_units >= p_quantity)::BOOLEAN,
        v_available_units,
        v_next_date,
        v_conflicts;
END;
$$ LANGUAGE plpgsql;
