SET search_path TO core, interactions, tasks, system, public;

-- 7.3 Allocate Specific Equipment to Booking
CREATE OR REPLACE FUNCTION sp_allocate_specific_equipment(
    p_booking_id INTEGER,
    p_equipment_ids INTEGER[],
    p_allocated_by INTEGER
)
RETURNS TABLE(
    success BOOLEAN,
    equipment_id INTEGER,
    asset_code VARCHAR(20),
    allocation_id INTEGER,
    message TEXT
) AS $$
DECLARE
    booking_record RECORD;
    equipment_id INTEGER;
    allocated_count INTEGER;
    remaining_quantity INTEGER;
    new_allocation_id INTEGER;
BEGIN
    -- Get booking details
    SELECT * INTO booking_record
    FROM interactions.interaction_equipment_types
    WHERE id = p_booking_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, 
                           'Booking not found';
        RETURN;
    END IF;
    
    -- Check how many already allocated
    SELECT COUNT(*) INTO allocated_count
    FROM interactions.interaction_equipment
    WHERE equipment_type_booking_id = p_booking_id;
    
    remaining_quantity := booking_record.quantity - allocated_count;
    
    -- Process each equipment ID
    FOREACH equipment_id IN ARRAY p_equipment_ids
    LOOP
        IF remaining_quantity <= 0 THEN
            RETURN QUERY SELECT FALSE, equipment_id, NULL::VARCHAR(20), NULL::INTEGER,
                               'Booking is already fully allocated';
            CONTINUE;
        END IF;
        
        -- Validate equipment availability
        IF NOT EXISTS (
            SELECT 1 FROM core.equipment 
            WHERE id = equipment_id 
              AND equipment_type_id = booking_record.equipment_type_id
              AND status = 'available'
        ) THEN
            RETURN QUERY SELECT FALSE, equipment_id, NULL::VARCHAR(20), NULL::INTEGER,
                               'Equipment not available for allocation';
            CONTINUE;
        END IF;
        
        -- Check if already allocated to another booking
        IF EXISTS (
            SELECT 1 FROM interactions.interaction_equipment
            WHERE equipment_id = equipment_id
              AND allocation_status IN ('allocated', 'delivered')
        ) THEN
            RETURN QUERY SELECT FALSE, equipment_id, NULL::VARCHAR(20), NULL::INTEGER,
                               'Equipment already allocated to another booking';
            CONTINUE;
        END IF;
        
        BEGIN
            -- Create allocation record
            INSERT INTO interactions.interaction_equipment (
                interaction_id, equipment_id, equipment_type_booking_id,
                hire_start_date, hire_end_date, allocation_status,
                allocated_by, allocated_at
            ) VALUES (
                booking_record.interaction_id, equipment_id, p_booking_id,
                booking_record.hire_start_date, booking_record.hire_end_date,
                'allocated', p_allocated_by, CURRENT_TIMESTAMP
            ) RETURNING id INTO new_allocation_id;
            
            -- Update equipment status
            UPDATE core.equipment 
            SET status = 'rented', updated_at = CURRENT_TIMESTAMP
            WHERE id = equipment_id;
            
            remaining_quantity := remaining_quantity - 1;
            
            RETURN QUERY SELECT TRUE, equipment_id, 
                               (SELECT asset_code FROM core.equipment WHERE id = equipment_id),
                               new_allocation_id,
                               'Equipment allocated successfully';
                               
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY SELECT FALSE, equipment_id, NULL::VARCHAR(20), NULL::INTEGER,
                               'Error allocating equipment: ' || SQLERRM;
        END;
    END LOOP;
    
    -- Update booking status if fully allocated
    IF remaining_quantity = 0 THEN
        UPDATE interactions.interaction_equipment_types
        SET booking_status = 'allocated', updated_at = CURRENT_TIMESTAMP
        WHERE id = p_booking_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_allocate_specific_equipment IS 'Allocate specific equipment units to generic bookings';