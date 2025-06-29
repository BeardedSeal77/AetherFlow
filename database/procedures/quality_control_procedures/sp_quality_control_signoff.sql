SET search_path TO core, interactions, tasks, system, public;

-- 8.2 Quality Control Sign-off
CREATE OR REPLACE FUNCTION sp_quality_control_signoff(
    p_allocation_ids INTEGER[],
    p_employee_id INTEGER,
    p_qc_status VARCHAR(20) DEFAULT 'passed',
    p_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    allocation_id INTEGER,
    equipment_id INTEGER,
    asset_code VARCHAR(20),
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    allocation_id INTEGER;
    equipment_record RECORD;
    interaction_id INTEGER;
    all_equipment_verified BOOLEAN;
BEGIN
    -- Validate QC status
    IF p_qc_status NOT IN ('passed', 'failed', 'repaired') THEN
        RETURN QUERY SELECT NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR(20), 
                           FALSE, 'Invalid QC status: ' || p_qc_status;
        RETURN;
    END IF;
    
    -- Process each allocation
    FOREACH allocation_id IN ARRAY p_allocation_ids
    LOOP
        -- Get allocation details
        SELECT ie.equipment_id, e.asset_code, ie.interaction_id
        INTO equipment_record
        FROM interactions.interaction_equipment ie
        JOIN core.equipment e ON ie.equipment_id = e.id
        WHERE ie.id = allocation_id;
        
        IF NOT FOUND THEN
            RETURN QUERY SELECT allocation_id, NULL::INTEGER, NULL::VARCHAR(20),
                               FALSE, 'Allocation not found';
            CONTINUE;
        END IF;
        
        BEGIN
            -- Update allocation QC status
            UPDATE interactions.interaction_equipment
            SET 
                quality_check_status = p_qc_status,
                quality_check_notes = p_notes,
                quality_checked_by = p_employee_id,
                quality_checked_at = CURRENT_TIMESTAMP
            WHERE id = allocation_id;
            
            -- If failed, update equipment condition and status
            IF p_qc_status = 'failed' THEN
                UPDATE core.equipment
                SET 
                    condition = 'poor',
                    status = 'repair',
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = equipment_record.equipment_id;
                
                -- Remove from allocation (equipment needs repair)
                UPDATE interactions.interaction_equipment
                SET allocation_status = 'cancelled'
                WHERE id = allocation_id;
            END IF;
            
            RETURN QUERY SELECT allocation_id, equipment_record.equipment_id, 
                               equipment_record.asset_code, TRUE,
                               'QC status updated: ' || p_qc_status;
                               
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY SELECT allocation_id, equipment_record.equipment_id,
                               equipment_record.asset_code, FALSE,
                               'Error updating QC status: ' || SQLERRM;
        END;
    END LOOP;
    
    -- Check if all equipment for the interaction is now QC verified
    -- This is done for the last interaction processed
    IF equipment_record.interaction_id IS NOT NULL THEN
        SELECT NOT EXISTS (
            SELECT 1 FROM interactions.interaction_equipment
            WHERE interaction_id = equipment_record.interaction_id
              AND quality_check_status = 'pending'
              AND allocation_status = 'allocated'
        ) INTO all_equipment_verified;
        
        -- Update driver task equipment_verified flag
        IF all_equipment_verified THEN
            UPDATE tasks.drivers_taskboard
            SET equipment_verified = TRUE, updated_at = CURRENT_TIMESTAMP
            WHERE interaction_id = equipment_record.interaction_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_quality_control_signoff IS 'Process quality control sign-off for allocated equipment';