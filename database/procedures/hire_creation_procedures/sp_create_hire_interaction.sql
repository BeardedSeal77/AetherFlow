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
        
        -- Add Accessories
        FOR accessory_item IN SELECT jsonb_array_elements(p_accessory_selections)
        LOOP
            INSERT INTO interactions.interaction_accessories (
                interaction_id, accessory_id, quantity, accessory_type,
                hire_start_date, hire_end_date
            ) VALUES (
                new_interaction_id,
                (accessory_item->>'accessory_id')::INTEGER,
                (accessory_item->>'quantity')::DECIMAL(8,2),
                (accessory_item->>'accessory_type')::VARCHAR(20),
                COALESCE(p_hire_start_date, p_delivery_date),
                p_estimated_hire_end
            );
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
            TRUE, 'Hire interaction created successfully';
            
    EXCEPTION WHEN OTHERS THEN
        -- Return error
        RETURN QUERY SELECT 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER,
            FALSE, 'Error creating hire: ' || SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_create_hire_interaction IS 'Create complete hire interaction with equipment booking and driver task';