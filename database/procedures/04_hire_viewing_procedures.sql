-- =====================================================================================
-- HIRE VIEWING AND ALLOCATION PROCEDURES
-- Procedures for viewing hires, pending allocations, and equipment allocation
-- =====================================================================================

-- Get all hires for today with summary information
CREATE OR REPLACE FUNCTION sp_get_todays_hires(p_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
    interaction_id INTEGER,
    reference_number VARCHAR,
    customer_name VARCHAR,
    contact_name VARCHAR,
    site_name VARCHAR,
    hire_start_date DATE,
    hire_end_date DATE,
    delivery_date DATE,
    delivery_time TIME,
    status VARCHAR,
    allocation_status VARCHAR,
    has_generic_equipment BOOLEAN,
    equipment_count INTEGER,
    total_value DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id AS interaction_id,
        i.reference_number::VARCHAR,
        c.customer_name::VARCHAR,
        CONCAT(cc.first_name, ' ', cc.last_name)::VARCHAR AS contact_name,
        cs.site_name::VARCHAR,
        i.hire_start_date,
        i.hire_end_date,
        i.delivery_date,
        i.delivery_time,
        i.status::VARCHAR,
        i.allocation_status::VARCHAR,
        COALESCE(
            (SELECT TRUE FROM interactions.interaction_equipment_generic ieg 
             WHERE ieg.interaction_id = i.id LIMIT 1), 
            FALSE
        ) AS has_generic_equipment,
        COALESCE(
            (SELECT COUNT(*)::INTEGER FROM interactions.interaction_equipment_generic ieg 
             WHERE ieg.interaction_id = i.id), 
            0
        ) AS equipment_count,
        COALESCE(
            (SELECT SUM(ieg.quantity * et.daily_rate)::DECIMAL(10,2)
             FROM interactions.interaction_equipment_generic ieg
             JOIN equipment.equipment_generic eg ON ieg.equipment_generic_id = eg.id
             JOIN equipment.equipment_types et ON eg.equipment_type_id = et.id
             WHERE ieg.interaction_id = i.id), 
            0.00
        ) AS total_value
    FROM interactions.interactions i
    LEFT JOIN core.customers c ON i.customer_id = c.id
    LEFT JOIN core.contacts cc ON i.contact_id = cc.id
    LEFT JOIN core.sites cs ON i.site_id = cs.id
    WHERE i.delivery_date = p_date
    AND i.interaction_type = 'hire'
    ORDER BY i.delivery_time, i.reference_number;
END;
$$ LANGUAGE plpgsql;

-- Get hires with generic equipment that need allocation
CREATE OR REPLACE FUNCTION sp_get_pending_allocations()
RETURNS TABLE (
    interaction_id INTEGER,
    reference_number VARCHAR,
    customer_name VARCHAR,
    contact_name VARCHAR,
    site_name VARCHAR,
    hire_start_date DATE,
    delivery_date DATE,
    delivery_time TIME,
    priority VARCHAR,
    equipment_count INTEGER,
    total_value DECIMAL(10,2),
    generic_equipment JSON
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id AS interaction_id,
        i.reference_number::VARCHAR,
        c.customer_name::VARCHAR,
        cc.contact_name::VARCHAR,
        cs.site_name::VARCHAR,
        i.hire_start_date,
        i.delivery_date,
        i.delivery_time,
        CASE 
            WHEN i.delivery_date < CURRENT_DATE THEN 'urgent'
            WHEN i.delivery_date = CURRENT_DATE THEN 'today'
            ELSE 'future'
        END::VARCHAR AS priority,
        COALESCE(
            (SELECT COUNT(*)::INTEGER FROM interactions.interaction_equipment_generic ieg 
             WHERE ieg.interaction_id = i.id), 
            0
        ) AS equipment_count,
        COALESCE(
            (SELECT SUM(ieg.quantity * et.daily_rate)::DECIMAL(10,2)
             FROM interactions.interaction_equipment_generic ieg
             JOIN equipment.equipment_generic eg ON ieg.equipment_generic_id = eg.id
             JOIN equipment.equipment_types et ON eg.equipment_type_id = et.id
             WHERE ieg.interaction_id = i.id), 
            0.00
        ) AS total_value,
        COALESCE(
            (SELECT json_agg(
                json_build_object(
                    'equipment_type_id', et.id,
                    'type_name', et.type_name,
                    'type_code', et.type_code,
                    'quantity', ieg.quantity,
                    'daily_rate', et.daily_rate
                )
            )
             FROM interactions.interaction_equipment_generic ieg
             JOIN equipment.equipment_generic eg ON ieg.equipment_generic_id = eg.id
             JOIN equipment.equipment_types et ON eg.equipment_type_id = et.id
             WHERE ieg.interaction_id = i.id), 
            '[]'::json
        ) AS generic_equipment
    FROM interactions.interactions i
    LEFT JOIN core.customers c ON i.customer_id = c.id
    LEFT JOIN core.customer_contacts cc ON i.contact_id = cc.id
    LEFT JOIN core.customer_sites cs ON i.site_id = cs.id
    WHERE i.allocation_status = 'not_allocated'
    AND i.interaction_type = 'hire'
    AND EXISTS (
        SELECT 1 FROM interactions.interaction_equipment_generic ieg 
        WHERE ieg.interaction_id = i.id
    )
    ORDER BY 
        CASE 
            WHEN i.delivery_date < CURRENT_DATE THEN 1
            WHEN i.delivery_date = CURRENT_DATE THEN 2
            ELSE 3
        END,
        i.delivery_date,
        i.delivery_time;
END;
$$ LANGUAGE plpgsql;

-- Get detailed hire information including equipment and accessories
CREATE OR REPLACE FUNCTION sp_get_hire_details(p_hire_id INTEGER)
RETURNS TABLE (
    interaction_id INTEGER,
    reference_number VARCHAR,
    customer_name VARCHAR,
    contact_name VARCHAR,
    site_name VARCHAR,
    hire_start_date DATE,
    hire_end_date DATE,
    delivery_date DATE,
    delivery_time TIME,
    contact_method VARCHAR,
    special_instructions TEXT,
    notes TEXT,
    status VARCHAR,
    allocation_status VARCHAR,
    equipment JSON,
    accessories JSON
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id AS interaction_id,
        i.reference_number::VARCHAR,
        c.customer_name::VARCHAR,
        cc.contact_name::VARCHAR,
        cs.site_name::VARCHAR,
        i.hire_start_date,
        i.hire_end_date,
        i.delivery_date,
        i.delivery_time,
        i.contact_method::VARCHAR,
        i.special_instructions,
        i.notes,
        i.status::VARCHAR,
        i.allocation_status::VARCHAR,
        -- Equipment JSON
        COALESCE(
            (SELECT json_agg(
                json_build_object(
                    'id', eq_data.id,
                    'mode', eq_data.mode,
                    'equipment_type_id', eq_data.equipment_type_id,
                    'equipment_id', eq_data.equipment_id,
                    'name', eq_data.name,
                    'code', eq_data.code,
                    'quantity', eq_data.quantity,
                    'daily_rate', eq_data.daily_rate,
                    'asset_code', eq_data.asset_code,
                    'condition', eq_data.condition
                )
            )
             FROM (
                -- Generic equipment
                SELECT 
                    ieg.id,
                    'generic'::text AS mode,
                    et.id AS equipment_type_id,
                    NULL::integer AS equipment_id,
                    et.type_name AS name,
                    et.type_code AS code,
                    ieg.quantity,
                    et.daily_rate,
                    NULL::text AS asset_code,
                    NULL::text AS condition
                FROM interactions.interaction_equipment_generic ieg
                JOIN equipment.equipment_generic eg ON ieg.equipment_generic_id = eg.id
                JOIN equipment.equipment_types et ON eg.equipment_type_id = et.id
                WHERE ieg.interaction_id = p_hire_id
                
                UNION ALL
                
                -- Specific equipment
                SELECT 
                    ie.id,
                    'specific'::text AS mode,
                    et.id AS equipment_type_id,
                    e.id AS equipment_id,
                    et.type_name AS name,
                    e.asset_code AS code,
                    1 AS quantity,
                    et.daily_rate,
                    e.asset_code,
                    e.condition
                FROM interactions.interaction_equipment ie
                JOIN equipment.equipment e ON ie.equipment_id = e.id
                JOIN equipment.equipment_types et ON e.equipment_type_id = et.id
                WHERE ie.interaction_id = p_hire_id
             ) eq_data),
            '[]'::json
        ) AS equipment,
        -- Accessories JSON
        COALESCE(
            (SELECT json_agg(
                json_build_object(
                    'accessory_id', a.id,
                    'accessory_name', a.accessory_name,
                    'accessory_code', a.accessory_code,
                    'quantity', ia.quantity,
                    'unit_of_measure', a.unit_of_measure,
                    'unit_rate', a.unit_rate
                )
            )
             FROM interactions.interaction_accessories ia
             JOIN equipment.accessories a ON ia.accessory_id = a.id
             WHERE ia.interaction_id = p_hire_id),
            '[]'::json
        ) AS accessories
    FROM interactions.interactions i
    LEFT JOIN core.customers c ON i.customer_id = c.id
    LEFT JOIN core.customer_contacts cc ON i.contact_id = cc.id
    LEFT JOIN core.customer_sites cs ON i.site_id = cs.id
    WHERE i.id = p_hire_id
    AND i.interaction_type = 'hire';
END;
$$ LANGUAGE plpgsql;

-- Get available equipment for allocation by equipment type
CREATE OR REPLACE FUNCTION sp_get_available_equipment_for_allocation(p_equipment_type_id INTEGER)
RETURNS TABLE (
    equipment_id INTEGER,
    asset_code VARCHAR,
    model VARCHAR,
    condition VARCHAR,
    type_name VARCHAR,
    daily_rate DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id AS equipment_id,
        e.asset_code::VARCHAR,
        e.model::VARCHAR,
        e.condition::VARCHAR,
        et.type_name::VARCHAR,
        et.daily_rate
    FROM equipment.equipment e
    JOIN equipment.equipment_types et ON e.equipment_type_id = et.id
    WHERE e.equipment_type_id = p_equipment_type_id
    AND e.status = 'available'
    AND e.is_active = true
    AND et.is_active = true
    -- Add availability check - not already allocated for overlapping periods
    AND NOT EXISTS (
        SELECT 1 FROM interactions.interaction_equipment ie
        JOIN interactions.interactions i ON ie.interaction_id = i.id
        WHERE ie.equipment_id = e.id
        AND i.allocation_status IN ('allocated', 'delivered')
        AND i.hire_end_date >= CURRENT_DATE
    )
    ORDER BY e.asset_code;
END;
$$ LANGUAGE plpgsql;

-- Allocate specific equipment to replace generic equipment
CREATE OR REPLACE FUNCTION sp_allocate_equipment(
    p_hire_id INTEGER,
    p_equipment_type_id INTEGER,
    p_equipment_ids INTEGER[]
)
RETURNS BOOLEAN AS $$
DECLARE
    equipment_id INTEGER;
    generic_booking_id INTEGER;
    remaining_quantity INTEGER;
BEGIN
    -- Find the generic equipment booking
    SELECT ieg.id, ieg.quantity INTO generic_booking_id, remaining_quantity
    FROM interactions.interaction_equipment_generic ieg
    JOIN equipment.equipment_generic eg ON ieg.equipment_generic_id = eg.id
    WHERE ieg.interaction_id = p_hire_id
    AND eg.equipment_type_id = p_equipment_type_id
    LIMIT 1;
    
    IF generic_booking_id IS NULL THEN
        RAISE EXCEPTION 'Generic equipment booking not found';
    END IF;
    
    -- Check if we have enough equipment IDs
    IF array_length(p_equipment_ids, 1) != remaining_quantity THEN
        RAISE EXCEPTION 'Equipment count mismatch: needed %, provided %', 
            remaining_quantity, array_length(p_equipment_ids, 1);
    END IF;
    
    -- Insert specific equipment allocations
    FOREACH equipment_id IN ARRAY p_equipment_ids
    LOOP
        INSERT INTO interactions.interaction_equipment (
            interaction_id,
            equipment_id,
            allocated_date,
            allocation_notes
        ) VALUES (
            p_hire_id,
            equipment_id,
            CURRENT_TIMESTAMP,
            'Allocated from generic booking'
        );
    END LOOP;
    
    -- Remove the generic equipment booking
    DELETE FROM interactions.interaction_equipment_generic
    WHERE id = generic_booking_id;
    
    -- Update hire allocation status if no more generic equipment
    IF NOT EXISTS (
        SELECT 1 FROM interactions.interaction_equipment_generic ieg
        WHERE ieg.interaction_id = p_hire_id
    ) THEN
        UPDATE interactions.interactions 
        SET allocation_status = 'allocated'
        WHERE id = p_hire_id;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Remove equipment from a hire
CREATE OR REPLACE FUNCTION sp_remove_hire_equipment(
    p_hire_id INTEGER,
    p_equipment_type_id INTEGER,
    p_equipment_id INTEGER DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_equipment_id IS NOT NULL THEN
        -- Remove specific equipment
        DELETE FROM interactions.interaction_equipment
        WHERE interaction_id = p_hire_id
        AND equipment_id = p_equipment_id;
    ELSE
        -- Remove generic equipment
        DELETE FROM interactions.interaction_equipment_generic ieg
        USING equipment.equipment_generic eg
        WHERE ieg.equipment_generic_id = eg.id
        AND ieg.interaction_id = p_hire_id
        AND eg.equipment_type_id = p_equipment_type_id;
    END IF;
    
    -- Update allocation status
    IF NOT EXISTS (
        SELECT 1 FROM interactions.interaction_equipment_generic ieg
        WHERE ieg.interaction_id = p_hire_id
    ) AND NOT EXISTS (
        SELECT 1 FROM interactions.interaction_equipment ie
        WHERE ie.interaction_id = p_hire_id
    ) THEN
        UPDATE interactions.interactions 
        SET allocation_status = 'not_allocated'
        WHERE id = p_hire_id;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;