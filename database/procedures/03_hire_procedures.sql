-- =============================================================================
-- HIRE CREATION AND MANAGEMENT PROCEDURES
-- =============================================================================

-- Validate hire request before creation
CREATE OR REPLACE FUNCTION sp_validate_hire_request(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_hire_start_date DATE,
    p_hire_end_date DATE DEFAULT NULL,
    p_equipment_types_json TEXT DEFAULT NULL,
    p_accessories_json TEXT DEFAULT NULL
)
RETURNS TABLE (
    is_valid BOOLEAN,
    error_message TEXT,
    warning_message TEXT
) AS $$
DECLARE
    v_customer_status VARCHAR(20);
    v_credit_limit DECIMAL(15,2);
    v_contact_customer_id INTEGER;
    v_site_customer_id INTEGER;
    v_equipment_data JSONB;
    v_equipment_item RECORD;
    v_availability_check RECORD;
    v_errors TEXT := '';
    v_warnings TEXT := '';
BEGIN
    -- Validate customer
    SELECT status, credit_limit INTO v_customer_status, v_credit_limit
    FROM core.customers
    WHERE id = p_customer_id;
    
    IF NOT FOUND THEN
        v_errors := v_errors || 'Customer not found. ';
    ELSIF v_customer_status != 'active' THEN
        v_errors := v_errors || 'Customer is not active. ';
    ELSIF v_customer_status = 'credit_hold' THEN
        v_errors := v_errors || 'Customer is on credit hold. ';
    END IF;
    
    -- Validate contact belongs to customer
    SELECT customer_id INTO v_contact_customer_id
    FROM core.contacts
    WHERE id = p_contact_id AND status = 'active';
    
    IF NOT FOUND THEN
        v_errors := v_errors || 'Contact not found or inactive. ';
    ELSIF v_contact_customer_id != p_customer_id THEN
        v_errors := v_errors || 'Contact does not belong to selected customer. ';
    END IF;
    
    -- Validate site belongs to customer
    SELECT customer_id INTO v_site_customer_id
    FROM core.sites
    WHERE id = p_site_id AND is_active = true;
    
    IF NOT FOUND THEN
        v_errors := v_errors || 'Site not found or inactive. ';
    ELSIF v_site_customer_id != p_customer_id THEN
        v_errors := v_errors || 'Site does not belong to selected customer. ';
    END IF;
    
    -- Validate dates
    IF p_hire_start_date < CURRENT_DATE THEN
        v_errors := v_errors || 'Hire start date cannot be in the past. ';
    END IF;
    
    IF p_hire_end_date IS NOT NULL AND p_hire_end_date < p_hire_start_date THEN
        v_errors := v_errors || 'Hire end date cannot be before start date. ';
    END IF;
    
    -- Validate equipment availability if provided
    IF p_equipment_types_json IS NOT NULL THEN
        v_equipment_data := p_equipment_types_json::JSONB;
        
        FOR v_equipment_item IN 
            SELECT 
                (item->>'equipment_type_id')::INTEGER as equipment_type_id,
                (item->>'quantity')::INTEGER as quantity
            FROM jsonb_array_elements(v_equipment_data) item
        LOOP
            -- Check availability for each equipment type
            SELECT * INTO v_availability_check
            FROM sp_check_equipment_availability(
                v_equipment_item.equipment_type_id,
                v_equipment_item.quantity,
                p_hire_start_date,
                p_hire_end_date
            );
            
            IF NOT v_availability_check.is_available THEN
                SELECT type_name INTO v_errors
                FROM equipment.equipment_types
                WHERE id = v_equipment_item.equipment_type_id;
                
                v_errors := v_errors || 'Insufficient ' || v_errors || ' available (' || 
                           v_availability_check.available_quantity || ' available, ' ||
                           v_equipment_item.quantity || ' requested). ';
            END IF;
        END LOOP;
    END IF;
    
    -- Add warnings
    IF p_hire_start_date = CURRENT_DATE THEN
        v_warnings := v_warnings || 'Same-day hire may require urgent processing. ';
    END IF;
    
    RETURN QUERY
    SELECT 
        (v_errors = '')::BOOLEAN,
        CASE WHEN v_errors = '' THEN NULL ELSE TRIM(v_errors) END,
        CASE WHEN v_warnings = '' THEN NULL ELSE TRIM(v_warnings) END;
END;
$$ LANGUAGE plpgsql;

-- Create hire interaction with equipment and accessories
CREATE OR REPLACE FUNCTION sp_create_hire_interaction(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_employee_id INTEGER,
    p_site_id INTEGER,
    p_contact_method VARCHAR(50),
    p_hire_start_date DATE,
    p_hire_end_date DATE DEFAULT NULL,
    p_delivery_date DATE DEFAULT NULL,
    p_delivery_time TIME DEFAULT NULL,
    p_special_instructions TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_equipment_types_json TEXT DEFAULT NULL, -- [{"equipment_type_id": 1, "quantity": 2}]
    p_accessories_json TEXT DEFAULT NULL -- [{"accessory_id": 1, "quantity": 5.0, "equipment_type_booking_id": null}]
)
RETURNS TABLE (
    success BOOLEAN,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    error_message TEXT,
    driver_task_id INTEGER
) AS $$
DECLARE
    v_interaction_id INTEGER;
    v_reference_number VARCHAR(20);
    v_equipment_data JSONB;
    v_accessories_data JSONB;
    v_equipment_item RECORD;
    v_accessory_item RECORD;
    v_booking_id INTEGER;
    v_driver_task_id INTEGER;
    v_customer_name VARCHAR(255);
    v_contact_name VARCHAR(255);
    v_contact_phone VARCHAR(20);
    v_contact_whatsapp VARCHAR(20);
    v_site_address TEXT;
    v_validation_result RECORD;
BEGIN
    -- Validate the hire request first
    SELECT * INTO v_validation_result
    FROM sp_validate_hire_request(
        p_customer_id, p_contact_id, p_site_id, p_hire_start_date, 
        p_hire_end_date, p_equipment_types_json, p_accessories_json
    );
    
    IF NOT v_validation_result.is_valid THEN
        RETURN QUERY
        SELECT false, NULL::INTEGER, NULL::VARCHAR(20), v_validation_result.error_message, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Generate reference number
    v_reference_number := sp_generate_reference_number('hire');
    
    -- Create interaction
    INSERT INTO interactions.interactions (
        customer_id, contact_id, employee_id, interaction_type, status,
        reference_number, contact_method, hire_start_date, hire_end_date,
        delivery_date, delivery_time, site_id, special_instructions, notes, created_by
    ) VALUES (
        p_customer_id, p_contact_id, p_employee_id, 'hire', 'pending',
        v_reference_number, p_contact_method, p_hire_start_date, p_hire_end_date,
        COALESCE(p_delivery_date, p_hire_start_date), p_delivery_time, p_site_id, 
        p_special_instructions, p_notes, p_employee_id
    ) RETURNING id INTO v_interaction_id;
    
    -- Add equipment type bookings (Phase 1)
    IF p_equipment_types_json IS NOT NULL THEN
        v_equipment_data := p_equipment_types_json::JSONB;
        
        FOR v_equipment_item IN 
            SELECT 
                (item->>'equipment_type_id')::INTEGER as equipment_type_id,
                (item->>'quantity')::INTEGER as quantity
            FROM jsonb_array_elements(v_equipment_data) item
        LOOP
            INSERT INTO interactions.interaction_equipment_types (
                interaction_id, equipment_type_id, quantity, hire_start_date, hire_end_date,
                booking_status, created_by
            ) VALUES (
                v_interaction_id, v_equipment_item.equipment_type_id, v_equipment_item.quantity,
                p_hire_start_date, p_hire_end_date, 'booked', p_employee_id
            ) RETURNING id INTO v_booking_id;
            
            -- Add default accessories for this equipment type
            INSERT INTO interactions.interaction_accessories (
                interaction_id, accessory_id, equipment_type_booking_id, quantity, 
                accessory_type, unit_rate, created_by
            )
            SELECT 
                v_interaction_id,
                ea.accessory_id,
                v_booking_id,
                ea.default_quantity * v_equipment_item.quantity,
                'default',
                a.unit_rate,
                p_employee_id
            FROM equipment.equipment_accessories ea
            JOIN equipment.accessories a ON ea.accessory_id = a.id
            WHERE ea.equipment_type_id = v_equipment_item.equipment_type_id
              AND ea.accessory_type = 'default'
              AND a.status = 'active';
        END LOOP;
    END IF;
    
    -- Add custom accessories
    IF p_accessories_json IS NOT NULL THEN
        v_accessories_data := p_accessories_json::JSONB;
        
        FOR v_accessory_item IN 
            SELECT 
                (item->>'accessory_id')::INTEGER as accessory_id,
                (item->>'quantity')::DECIMAL(8,2) as quantity,
                (item->>'equipment_type_booking_id')::INTEGER as equipment_type_booking_id
            FROM jsonb_array_elements(v_accessories_data) item
            WHERE (item->>'quantity')::DECIMAL(8,2) > 0
        LOOP
            INSERT INTO interactions.interaction_accessories (
                interaction_id, accessory_id, equipment_type_booking_id, quantity, 
                accessory_type, unit_rate, created_by
            )
            SELECT 
                v_interaction_id,
                v_accessory_item.accessory_id,
                v_accessory_item.equipment_type_booking_id,
                v_accessory_item.quantity,
                CASE WHEN v_accessory_item.equipment_type_booking_id IS NULL THEN 'standalone' ELSE 'optional' END,
                a.unit_rate,
                p_employee_id
            FROM equipment.accessories a
            WHERE a.id = v_accessory_item.accessory_id;
        END LOOP;
    END IF;
    
    -- Get customer and contact details for driver task
    SELECT c.customer_name, ct.first_name || ' ' || ct.last_name, ct.phone_number, ct.whatsapp_number
    INTO v_customer_name, v_contact_name, v_contact_phone, v_contact_whatsapp
    FROM core.customers c
    JOIN core.contacts ct ON c.id = ct.customer_id
    WHERE c.id = p_customer_id AND ct.id = p_contact_id;
    
    -- Get site address
    SELECT s.address_line1 || 
           CASE WHEN s.address_line2 IS NOT NULL THEN ', ' || s.address_line2 ELSE '' END ||
           ', ' || s.city || 
           CASE WHEN s.province IS NOT NULL THEN ', ' || s.province ELSE '' END ||
           CASE WHEN s.postal_code IS NOT NULL THEN ', ' || s.postal_code ELSE '' END
    INTO v_site_address
    FROM core.sites s
    WHERE s.id = p_site_id;
    
    -- Create driver task
    INSERT INTO tasks.drivers_taskboard (
        interaction_id, task_type, priority, status, customer_name, contact_name,
        contact_phone, contact_whatsapp, site_address, scheduled_date, scheduled_time,
        equipment_allocated, equipment_verified, created_by
    ) VALUES (
        v_interaction_id, 'delivery', 'medium', 'backlog', v_customer_name, v_contact_name,
        v_contact_phone, v_contact_whatsapp, v_site_address, 
        COALESCE(p_delivery_date, p_hire_start_date), p_delivery_time,
        false, false, p_employee_id
    ) RETURNING id INTO v_driver_task_id;
    
    -- Log activity
    PERFORM sp_log_activity(
        p_employee_id, 
        'CREATE_HIRE_INTERACTION', 
        'interactions.interactions', 
        v_interaction_id,
        NULL,
        jsonb_build_object(
            'reference_number', v_reference_number,
            'customer_id', p_customer_id,
            'hire_start_date', p_hire_start_date
        )
    );
    
    RETURN QUERY
    SELECT true, v_interaction_id, v_reference_number, NULL::TEXT, v_driver_task_id;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, NULL::INTEGER, NULL::VARCHAR(20), SQLERRM::TEXT, NULL::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- Get hire interaction details
CREATE OR REPLACE FUNCTION sp_get_hire_interaction_details(
    p_interaction_id INTEGER
)
RETURNS TABLE (
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    interaction_type VARCHAR(50),
    status VARCHAR(50),
    customer_id INTEGER,
    customer_name VARCHAR(255),
    contact_id INTEGER,
    contact_name VARCHAR(255),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    site_id INTEGER,
    site_name VARCHAR(255),
    site_address TEXT,
    hire_start_date DATE,
    hire_end_date DATE,
    delivery_date DATE,
    delivery_time TIME,
    special_instructions TEXT,
    notes TEXT,
    created_by INTEGER,
    created_by_name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.reference_number,
        i.interaction_type,
        i.status,
        i.customer_id,
        c.customer_name,
        i.contact_id,
        (ct.first_name || ' ' || ct.last_name)::VARCHAR(255),
        ct.phone_number,
        ct.email,
        i.site_id,
        s.site_name,
        (s.address_line1 || 
         CASE WHEN s.address_line2 IS NOT NULL THEN ', ' || s.address_line2 ELSE '' END ||
         ', ' || s.city || 
         CASE WHEN s.province IS NOT NULL THEN ', ' || s.province ELSE '' END ||
         CASE WHEN s.postal_code IS NOT NULL THEN ', ' || s.postal_code ELSE '' END
        )::TEXT,
        i.hire_start_date,
        i.hire_end_date,
        i.delivery_date,
        i.delivery_time,
        i.special_instructions,
        i.notes,
        i.created_by,
        (e.name || ' ' || e.surname)::VARCHAR(255),
        i.created_at,
        i.updated_at
    FROM interactions.interactions i
    JOIN core.customers c ON i.customer_id = c.id
    JOIN core.contacts ct ON i.contact_id = ct.id
    LEFT JOIN core.sites s ON i.site_id = s.id
    JOIN core.employees e ON i.created_by = e.id
    WHERE i.id = p_interaction_id;
END;
$$ LANGUAGE plpgsql;

-- Get hire equipment list (generic bookings and specific allocations)
CREATE OR REPLACE FUNCTION sp_get_hire_equipment_list(
    p_interaction_id INTEGER
)
RETURNS TABLE (
    booking_id INTEGER,
    equipment_type_id INTEGER,
    type_code VARCHAR(20),
    type_name VARCHAR(255),
    quantity_booked INTEGER,
    quantity_allocated INTEGER,
    booking_status VARCHAR(20),
    allocated_equipment TEXT, -- JSON array of allocated equipment
    hire_start_date DATE,
    hire_end_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        iet.id,
        iet.equipment_type_id,
        et.type_code,
        et.type_name,
        iet.quantity,
        COALESCE(
            (SELECT COUNT(*)::INTEGER 
             FROM interactions.interaction_equipment ie 
             WHERE ie.equipment_type_booking_id = iet.id), 0
        ),
        iet.booking_status,
        COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                    'equipment_id', ie.equipment_id,
                    'asset_code', e.asset_code,
                    'model', e.model,
                    'condition', e.condition,
                    'allocation_status', ie.allocation_status
                )
            )::TEXT
             FROM interactions.interaction_equipment ie
             JOIN equipment.equipment e ON ie.equipment_id = e.id
             WHERE ie.equipment_type_booking_id = iet.id), '[]'
        ),
        iet.hire_start_date,
        iet.hire_end_date
    FROM interactions.interaction_equipment_types iet
    JOIN equipment.equipment_types et ON iet.equipment_type_id = et.id
    WHERE iet.interaction_id = p_interaction_id
    ORDER BY et.type_name;
END;
$$ LANGUAGE plpgsql;

-- Get hire accessories list
CREATE OR REPLACE FUNCTION sp_get_hire_accessories_list(
    p_interaction_id INTEGER
)
RETURNS TABLE (
    accessory_assignment_id INTEGER,
    accessory_id INTEGER,
    accessory_code VARCHAR(50),
    accessory_name VARCHAR(255),
    quantity DECIMAL(8,2),
    unit_of_measure VARCHAR(20),
    unit_rate DECIMAL(10,2),
    total_amount DECIMAL(12,2),
    accessory_type VARCHAR(20),
    equipment_type_booking_id INTEGER,
    equipment_type_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ia.id,
        ia.accessory_id,
        a.accessory_code,
        a.accessory_name,
        ia.quantity,
        a.unit_of_measure,
        ia.unit_rate,
        (ia.quantity * ia.unit_rate)::DECIMAL(12,2),
        ia.accessory_type,
        ia.equipment_type_booking_id,
        et.type_name
    FROM interactions.interaction_accessories ia
    JOIN equipment.accessories a ON ia.accessory_id = a.id
    LEFT JOIN interactions.interaction_equipment_types iet ON ia.equipment_type_booking_id = iet.id
    LEFT JOIN equipment.equipment_types et ON iet.equipment_type_id = et.id
    WHERE ia.interaction_id = p_interaction_id
    ORDER BY 
        CASE ia.accessory_type 
            WHEN 'default' THEN 1 
            WHEN 'optional' THEN 2 
            ELSE 3 
        END,
        et.type_name NULLS LAST,
        a.accessory_name;
END;
$$ LANGUAGE plpgsql;
