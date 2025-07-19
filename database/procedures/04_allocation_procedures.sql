-- =============================================================================
-- EQUIPMENT ALLOCATION PROCEDURES (Phase 2)
-- =============================================================================

-- Get bookings ready for allocation
CREATE OR REPLACE FUNCTION sp_get_bookings_for_allocation(
    p_interaction_id INTEGER DEFAULT NULL,
    p_status_filter VARCHAR(20) DEFAULT 'booked'
)
RETURNS TABLE (
    booking_id INTEGER,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    customer_name VARCHAR(255),
    equipment_type_id INTEGER,
    type_code VARCHAR(20),
    type_name VARCHAR(255),
    quantity_booked INTEGER,
    quantity_allocated INTEGER,
    quantity_remaining INTEGER,
    booking_status VARCHAR(20),
    hire_start_date DATE,
    hire_end_date DATE,
    delivery_date DATE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        iet.id,
        iet.interaction_id,
        i.reference_number,
        c.customer_name,
        iet.equipment_type_id,
        et.type_code,
        et.type_name,
        iet.quantity,
        COALESCE(
            (SELECT COUNT(*)::INTEGER 
             FROM interactions.interaction_equipment ie 
             WHERE ie.equipment_type_booking_id = iet.id), 0
        ),
        iet.quantity - COALESCE(
            (SELECT COUNT(*)::INTEGER 
             FROM interactions.interaction_equipment ie 
             WHERE ie.equipment_type_booking_id = iet.id), 0
        ),
        iet.booking_status,
        iet.hire_start_date,
        iet.hire_end_date,
        i.delivery_date,
        iet.created_at
    FROM interactions.interaction_equipment_types iet
    JOIN interactions.interactions i ON iet.interaction_id = i.id
    JOIN core.customers c ON i.customer_id = c.id
    JOIN equipment.equipment_types et ON iet.equipment_type_id = et.id
    WHERE 
        (p_interaction_id IS NULL OR iet.interaction_id = p_interaction_id)
        AND (p_status_filter IS NULL OR iet.booking_status = p_status_filter)
        AND iet.quantity > COALESCE(
            (SELECT COUNT(*) 
             FROM interactions.interaction_equipment ie 
             WHERE ie.equipment_type_booking_id = iet.id), 0
        )
    ORDER BY i.delivery_date, iet.created_at;
END;
$$ LANGUAGE plpgsql;

-- Get equipment available for allocation
CREATE OR REPLACE FUNCTION sp_get_equipment_for_allocation(
    p_equipment_type_id INTEGER,
    p_hire_start_date DATE,
    p_hire_end_date DATE DEFAULT NULL,
    p_exclude_interaction_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    equipment_id INTEGER,
    asset_code VARCHAR(20),
    model VARCHAR(100),
    serial_number VARCHAR(50),
    condition VARCHAR(20),
    location VARCHAR(100),
    last_service_date DATE,
    next_service_due DATE,
    is_overdue_service BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.asset_code,
        e.model,
        e.serial_number,
        e.condition,
        e.location,
        e.last_service_date,
        e.next_service_due,
        (e.next_service_due IS NOT NULL AND e.next_service_due < CURRENT_DATE)::BOOLEAN
    FROM equipment.equipment e
    WHERE 
        e.equipment_type_id = p_equipment_type_id
        AND e.status = 'available'
        AND e.id NOT IN (
            -- Exclude equipment already allocated for overlapping periods
            SELECT ie.equipment_id
            FROM interactions.interaction_equipment ie
            JOIN interactions.interactions i ON ie.interaction_id = i.id
            WHERE i.interaction_type = 'hire'
              AND i.status NOT IN ('cancelled', 'completed')
              AND (p_exclude_interaction_id IS NULL OR i.id != p_exclude_interaction_id)
              AND (
                  (i.hire_start_date <= COALESCE(p_hire_end_date, p_hire_start_date))
                  AND (COALESCE(i.hire_end_date, i.hire_start_date + INTERVAL '30 days') >= p_hire_start_date)
              )
        )
    ORDER BY 
        e.condition DESC, -- Excellent condition first
        e.next_service_due DESC NULLS LAST, -- Recently serviced first
        e.asset_code;
END;
$$ LANGUAGE plpgsql;

-- Allocate specific equipment to booking
CREATE OR REPLACE FUNCTION sp_allocate_specific_equipment(
    p_booking_id INTEGER,
    p_equipment_ids INTEGER[], -- Array of equipment IDs to allocate
    p_allocated_by INTEGER,
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    allocated_count INTEGER,
    error_message TEXT,
    allocation_ids INTEGER[]
) AS $$
DECLARE
    v_interaction_id INTEGER;
    v_equipment_type_id INTEGER;
    v_quantity_booked INTEGER;
    v_quantity_allocated INTEGER;
    v_hire_start_date DATE;
    v_hire_end_date DATE;
    v_equipment_id INTEGER;
    v_allocated_count INTEGER := 0;
    v_allocation_ids INTEGER[] := ARRAY[]::INTEGER[];
    v_allocation_id INTEGER;
    v_equipment_type_check INTEGER;
    v_availability_check INTEGER;
BEGIN
    -- Get booking details
    SELECT 
        iet.interaction_id, iet.equipment_type_id, iet.quantity, iet.hire_start_date, iet.hire_end_date,
        COALESCE((SELECT COUNT(*) FROM interactions.interaction_equipment ie WHERE ie.equipment_type_booking_id = iet.id), 0)
    INTO v_interaction_id, v_equipment_type_id, v_quantity_booked, v_hire_start_date, v_hire_end_date, v_quantity_allocated
    FROM interactions.interaction_equipment_types iet
    WHERE iet.id = p_booking_id;
    
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT false, 0, 'Booking not found'::TEXT, ARRAY[]::INTEGER[];
        RETURN;
    END IF;
    
    -- Check if we have room for more allocations
    IF v_quantity_allocated + array_length(p_equipment_ids, 1) > v_quantity_booked THEN
        RETURN QUERY
        SELECT false, 0, 'Cannot allocate more equipment than booked quantity'::TEXT, ARRAY[]::INTEGER[];
        RETURN;
    END IF;
    
    -- Validate and allocate each equipment
    FOREACH v_equipment_id IN ARRAY p_equipment_ids
    LOOP
        -- Check equipment type matches
        SELECT equipment_type_id INTO v_equipment_type_check
        FROM equipment.equipment
        WHERE id = v_equipment_id AND status = 'available';
        
        IF NOT FOUND THEN
            RETURN QUERY
            SELECT false, v_allocated_count, ('Equipment ' || v_equipment_id || ' not found or not available')::TEXT, v_allocation_ids;
            RETURN;
        END IF;
        
        IF v_equipment_type_check != v_equipment_type_id THEN
            RETURN QUERY
            SELECT false, v_allocated_count, ('Equipment ' || v_equipment_id || ' is not of the correct type')::TEXT, v_allocation_ids;
            RETURN;
        END IF;
        
        -- Check availability for date range
        SELECT COUNT(*) INTO v_availability_check
        FROM interactions.interaction_equipment ie
        JOIN interactions.interactions i ON ie.interaction_id = i.id
        WHERE ie.equipment_id = v_equipment_id
          AND i.interaction_type = 'hire'
          AND i.status NOT IN ('cancelled', 'completed')
          AND i.id != v_interaction_id -- Exclude current interaction
          AND (
              (i.hire_start_date <= COALESCE(v_hire_end_date, v_hire_start_date))
              AND (COALESCE(i.hire_end_date, i.hire_start_date + INTERVAL '30 days') >= v_hire_start_date)
          );
        
        IF v_availability_check > 0 THEN
            RETURN QUERY
            SELECT false, v_allocated_count, ('Equipment ' || v_equipment_id || ' is not available for the requested period')::TEXT, v_allocation_ids;
            RETURN;
        END IF;
        
        -- Allocate the equipment
        INSERT INTO interactions.interaction_equipment (
            interaction_id, equipment_id, equipment_type_booking_id, allocation_status,
            allocated_by, allocated_at
        ) VALUES (
            v_interaction_id, v_equipment_id, p_booking_id, 'allocated',
            p_allocated_by, CURRENT_TIMESTAMP
        ) RETURNING id INTO v_allocation_id;
        
        -- Update equipment status
        UPDATE equipment.equipment
        SET status = 'rented', updated_at = CURRENT_TIMESTAMP
        WHERE id = v_equipment_id;
        
        v_allocated_count := v_allocated_count + 1;
        v_allocation_ids := array_append(v_allocation_ids, v_allocation_id);
    END LOOP;
    
    -- Update booking status if fully allocated
    IF v_quantity_allocated + v_allocated_count >= v_quantity_booked THEN
        UPDATE interactions.interaction_equipment_types
        SET booking_status = 'allocated', updated_at = CURRENT_TIMESTAMP
        WHERE id = p_booking_id;
    END IF;
    
    -- Update driver task equipment allocation flag
    UPDATE tasks.drivers_taskboard
    SET equipment_allocated = true, updated_at = CURRENT_TIMESTAMP
    WHERE interaction_id = v_interaction_id
      AND task_type = 'delivery'
      AND status IN ('backlog', 'assigned');
    
    -- Log activity
    PERFORM sp_log_activity(
        p_allocated_by, 
        'ALLOCATE_EQUIPMENT', 
        'interactions.interaction_equipment', 
        NULL,
        NULL,
        jsonb_build_object(
            'booking_id', p_booking_id,
            'equipment_ids', p_equipment_ids,
            'allocated_count', v_allocated_count
        )
    );
    
    RETURN QUERY
    SELECT true, v_allocated_count, NULL::TEXT, v_allocation_ids;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, v_allocated_count, SQLERRM::TEXT, v_allocation_ids;
END;
$$ LANGUAGE plpgsql;

-- Get allocation status for interaction
CREATE OR REPLACE FUNCTION sp_get_allocation_status(
    p_interaction_id INTEGER
)
RETURNS TABLE (
    total_bookings INTEGER,
    fully_allocated_bookings INTEGER,
    partially_allocated_bookings INTEGER,
    unallocated_bookings INTEGER,
    total_equipment_booked INTEGER,
    total_equipment_allocated INTEGER,
    allocation_percentage DECIMAL(5,2),
    is_fully_allocated BOOLEAN
) AS $$
DECLARE
    v_stats RECORD;
BEGIN
    SELECT 
        COUNT(*) as total_bookings,
        SUM(CASE WHEN iet.booking_status = 'allocated' THEN 1 ELSE 0 END) as fully_allocated,
        SUM(CASE WHEN iet.booking_status = 'booked' AND EXISTS(
            SELECT 1 FROM interactions.interaction_equipment ie WHERE ie.equipment_type_booking_id = iet.id
        ) THEN 1 ELSE 0 END) as partially_allocated,
        SUM(CASE WHEN iet.booking_status = 'booked' AND NOT EXISTS(
            SELECT 1 FROM interactions.interaction_equipment ie WHERE ie.equipment_type_booking_id = iet.id
        ) THEN 1 ELSE 0 END) as unallocated,
        SUM(iet.quantity) as total_booked,
        SUM(COALESCE((
            SELECT COUNT(*) FROM interactions.interaction_equipment ie WHERE ie.equipment_type_booking_id = iet.id
        ), 0)) as total_allocated
    INTO v_stats
    FROM interactions.interaction_equipment_types iet
    WHERE iet.interaction_id = p_interaction_id;
    
    RETURN QUERY
    SELECT 
        v_stats.total_bookings::INTEGER,
        v_stats.fully_allocated::INTEGER,
        v_stats.partially_allocated::INTEGER,
        v_stats.unallocated::INTEGER,
        v_stats.total_booked::INTEGER,
        v_stats.total_allocated::INTEGER,
        CASE 
            WHEN v_stats.total_booked > 0 THEN 
                ROUND((v_stats.total_allocated::DECIMAL / v_stats.total_booked::DECIMAL) * 100, 2)
            ELSE 0::DECIMAL(5,2)
        END,
        (v_stats.total_allocated >= v_stats.total_booked)::BOOLEAN;
END;
$$ LANGUAGE plpgsql;

-- Quality control sign-off for allocated equipment
CREATE OR REPLACE FUNCTION sp_quality_control_signoff(
    p_allocation_id INTEGER,
    p_qc_approved_by INTEGER,
    p_qc_notes TEXT DEFAULT NULL,
    p_approved BOOLEAN DEFAULT true
)
RETURNS TABLE (
    success BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    v_allocation_status VARCHAR(20);
    v_interaction_id INTEGER;
BEGIN
    -- Get current allocation status
    SELECT ie.allocation_status, ie.interaction_id 
    INTO v_allocation_status, v_interaction_id
    FROM interactions.interaction_equipment ie
    WHERE ie.id = p_allocation_id;
    
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT false, 'Allocation not found'::TEXT;
        RETURN;
    END IF;
    
    IF v_allocation_status NOT IN ('allocated', 'qc_pending') THEN
        RETURN QUERY
        SELECT false, 'Equipment not ready for quality control'::TEXT;
        RETURN;
    END IF;
    
    -- Update allocation with QC status
    UPDATE interactions.interaction_equipment
    SET 
        allocation_status = CASE WHEN p_approved THEN 'qc_approved' ELSE 'allocated' END,
        qc_approved_by = p_qc_approved_by,
        qc_approved_at = CURRENT_TIMESTAMP,
        qc_notes = p_qc_notes
    WHERE id = p_allocation_id;
    
    -- Check if all equipment for this interaction is QC approved
    IF p_approved THEN
        -- Update driver task if all equipment is QC approved
        IF NOT EXISTS (
            SELECT 1 
            FROM interactions.interaction_equipment ie
            WHERE ie.interaction_id = v_interaction_id
              AND ie.allocation_status NOT IN ('qc_approved', 'delivered')
        ) THEN
            UPDATE tasks.drivers_taskboard
            SET equipment_verified = true, updated_at = CURRENT_TIMESTAMP
            WHERE interaction_id = v_interaction_id
              AND task_type = 'delivery'
              AND status IN ('backlog', 'assigned');
        END IF;
    END IF;
    
    -- Log activity
    PERFORM sp_log_activity(
        p_qc_approved_by, 
        'QC_SIGNOFF', 
        'interactions.interaction_equipment', 
        p_allocation_id,
        NULL,
        jsonb_build_object(
            'approved', p_approved,
            'qc_notes', p_qc_notes
        )
    );
    
    RETURN QUERY
    SELECT true, NULL::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Get equipment pending quality control
CREATE OR REPLACE FUNCTION sp_get_equipment_pending_qc(
    p_interaction_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    allocation_id INTEGER,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    customer_name VARCHAR(255),
    equipment_id INTEGER,
    asset_code VARCHAR(20),
    type_name VARCHAR(255),
    model VARCHAR(100),
    condition VARCHAR(20),
    allocation_status VARCHAR(20),
    allocated_at TIMESTAMP WITH TIME ZONE,
    delivery_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ie.id,
        ie.interaction_id,
        i.reference_number,
        c.customer_name,
        ie.equipment_id,
        e.asset_code,
        et.type_name,
        e.model,
        e.condition,
        ie.allocation_status,
        ie.allocated_at,
        i.delivery_date
    FROM interactions.interaction_equipment ie
    JOIN interactions.interactions i ON ie.interaction_id = i.id
    JOIN core.customers c ON i.customer_id = c.id
    JOIN equipment.equipment e ON ie.equipment_id = e.id
    JOIN equipment.equipment_types et ON e.equipment_type_id = et.id
    WHERE 
        ie.allocation_status IN ('allocated', 'qc_pending')
        AND (p_interaction_id IS NULL OR ie.interaction_id = p_interaction_id)
    ORDER BY i.delivery_date, ie.allocated_at;
END;
$$ LANGUAGE plpgsql;
