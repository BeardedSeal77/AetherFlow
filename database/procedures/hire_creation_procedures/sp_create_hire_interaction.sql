-- =============================================================================
-- FIXED: sp_create_hire_interaction - Updated for new accessories structure
-- =============================================================================

SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_create_hire_interaction(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_employee_id INTEGER,
    p_site_id INTEGER,
    p_contact_method VARCHAR(50),
    p_notes TEXT,
    p_equipment_selections JSONB,
    p_accessory_selections JSONB,
    p_delivery_date DATE,
    p_delivery_time TIME DEFAULT NULL,
    p_hire_start_date DATE DEFAULT NULL,
    p_estimated_hire_end DATE DEFAULT NULL
)
RETURNS TABLE(
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    driver_task_id INTEGER,
    success BOOLEAN,
    message TEXT
) AS $$
DECLARE
    new_interaction_id INTEGER;
    ref_number VARCHAR(20);
    new_task_id INTEGER;
    customer_name VARCHAR(255);
    contact_name VARCHAR(255);
    contact_phone VARCHAR(20);
    contact_whatsapp VARCHAR(20);
    site_address TEXT;
    site_instructions TEXT;
    equipment_item JSONB;
    accessory_item JSONB;
    accessory_exists BOOLEAN;
BEGIN
    -- Start transaction
    BEGIN
        -- Generate reference number
        ref_number := sp_generate_reference_number('hire');
        
        -- Create main interaction
        INSERT INTO interactions.interactions (
            customer_id, contact_id, employee_id, interaction_type,
            reference_number, contact_method, notes, status
        ) VALUES (
            p_customer_id, p_contact_id, p_employee_id, 'hire',
            ref_number, p_contact_method, p_notes, 'pending'
        ) RETURNING id INTO new_interaction_id;
        
        -- Add Phase 1: Generic Equipment Bookings
        FOR equipment_item IN SELECT jsonb_array_elements(p_equipment_selections)
        LOOP
            INSERT INTO interactions.interaction_equipment_types (
                interaction_id, equipment_type_id, quantity, 
                hire_start_date, hire_end_date, booking_status
            ) VALUES (
                new_interaction_id,
                (equipment_item->>'equipment_type_id')::INTEGER,
                (equipment_item->>'quantity')::INTEGER,
                COALESCE(p_hire_start_date, p_delivery_date),
                p_estimated_hire_end,
                'booked'
            );
        END LOOP;
        
        -- Add Accessories with validation
        FOR accessory_item IN SELECT jsonb_array_elements(p_accessory_selections)
        LOOP
            -- Validate accessory exists and is active
            SELECT EXISTS(
                SELECT 1 FROM core.accessories 
                WHERE id = (accessory_item->>'accessory_id')::INTEGER 
                AND status = 'active'
            ) INTO accessory_exists;
            
            IF accessory_exists THEN
                INSERT INTO interactions.interaction_accessories (
                    interaction_id, accessory_id, quantity, accessory_type,
                    hire_start_date, hire_end_date
                ) VALUES (
                    new_interaction_id,
                    (accessory_item->>'accessory_id')::INTEGER,
                    (accessory_item->>'quantity')::DECIMAL(8,2),
                    COALESCE((accessory_item->>'accessory_type')::VARCHAR(20), 'default'),
                    COALESCE(p_hire_start_date, p_delivery_date),
                    p_estimated_hire_end
                );
            ELSE
                -- Log warning but don't fail the entire transaction
                RAISE WARNING 'Accessory ID % does not exist or is inactive, skipping', 
                    (accessory_item->>'accessory_id')::INTEGER;
            END IF;
        END LOOP;
        
        -- Get customer and site details for driver task
        SELECT c.customer_name, ct.first_name || ' ' || ct.last_name,
               ct.phone_number, ct.whatsapp_number
        INTO customer_name, contact_name, contact_phone, contact_whatsapp
        FROM core.customers c
        JOIN core.contacts ct ON c.id = ct.customer_id
        WHERE c.id = p_customer_id AND ct.id = p_contact_id;
        
        SELECT s.address_line1 || 
               CASE WHEN s.address_line2 IS NOT NULL THEN ', ' || s.address_line2 ELSE '' END ||
               ', ' || s.city || 
               CASE WHEN s.province IS NOT NULL THEN ', ' || s.province ELSE '' END ||
               CASE WHEN s.postal_code IS NOT NULL THEN ', ' || s.postal_code ELSE '' END,
               s.delivery_instructions
        INTO site_address, site_instructions
        FROM core.sites s
        WHERE s.id = p_site_id;
        
        -- Create Driver Task
        INSERT INTO tasks.drivers_taskboard (
            interaction_id, task_type, priority, customer_name,
            contact_name, contact_phone, contact_whatsapp,
            site_address, site_delivery_instructions,
            scheduled_date, scheduled_time,
            equipment_allocated, equipment_verified, created_by
        ) VALUES (
            new_interaction_id, 'delivery', 'medium', customer_name,
            contact_name, contact_phone, contact_whatsapp,
            site_address, site_instructions,
            p_delivery_date, p_delivery_time,
            FALSE, FALSE, p_employee_id
        ) RETURNING id INTO new_task_id;
        
        -- Return success
        RETURN QUERY SELECT 
            new_interaction_id, ref_number, new_task_id, 
            TRUE, 'Hire interaction created successfully'::TEXT;
            
    EXCEPTION WHEN OTHERS THEN
        -- Return error
        RETURN QUERY SELECT 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER,
            FALSE, ('Error creating hire: ' || SQLERRM)::TEXT;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_create_hire_interaction IS 'Create complete hire interaction with equipment booking and driver task - UPDATED for new accessories structure';

-- =============================================================================
-- CHANGE NOTES:
-- =============================================================================
/*
MAJOR CHANGES MADE:

1. ADDED ACCESSORY VALIDATION:
   - Before inserting accessories, check they exist and are active
   - Prevents foreign key errors with invalid accessory IDs
   - Uses graceful warning instead of failing entire transaction

2. ENHANCED ACCESSORY INSERTION:
   - Added validation for accessory existence
   - Added default value for accessory_type if not provided
   - Better error handling for malformed accessory data

3. IMPROVED ERROR HANDLING:
   - Individual accessory failures don't break entire hire creation
   - Logs warnings for invalid accessories but continues
   - More detailed error messages

4. BETTER DATA CASTING:
   - Explicit casting for all JSONB extractions
   - Safer handling of optional accessory_type field
   - Default values for missing optional fields

5. TRANSACTION SAFETY:
   - Wrapped in proper transaction block
   - Rollback on major errors
   - Partial success handling for accessories

COMPATIBILITY NOTES:
- Input format unchanged (p_accessory_selections JSONB)
- Expected JSON structure: [{"accessory_id": 1, "quantity": 2.0, "accessory_type": "default"}]
- accessory_type is now optional and defaults to "default"
- Invalid accessories are skipped with warnings rather than failing

VALIDATION ADDED:
- Checks accessory exists in core.accessories
- Verifies accessory is active (status = 'active')
- Handles missing or invalid accessory_type gracefully
- Prevents orphaned references to non-existent accessories

RECOMMENDED CALLING PATTERN:
Before calling this procedure, consider using sp_calculate_auto_accessories 
to get the correct accessory IDs and quantities based on equipment selection.
*/