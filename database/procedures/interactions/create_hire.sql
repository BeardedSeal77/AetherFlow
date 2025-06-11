-- =============================================================================
-- INTERACTIONS: EQUIPMENT HIRE PROCESSING (Using Existing Procedures)
-- =============================================================================
-- Purpose: Process equipment hire requests following hire_process.txt documentation
-- Creates hire interaction with equipment list and delivery details
-- Updated to use existing procedures in core/customer_management/ and system/
-- Updated: 2025-06-11 - Uses existing helper procedures
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.create_hire;

-- Create the hire processing procedure using existing helpers
CREATE OR REPLACE FUNCTION interactions.create_hire(
    -- Required hire details (per hire_process.txt documentation)
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_list JSONB,         -- [{"equipment_category_id": 5, "quantity": 2}]
    p_hire_start_date DATE,
    p_delivery_date DATE,
    
    -- Optional details
    p_delivery_time TIME DEFAULT '09:00'::TIME,
    p_notes TEXT DEFAULT NULL,
    p_priority VARCHAR(20) DEFAULT 'medium',
    
    -- Session/authentication (simplified)
    p_employee_id INTEGER DEFAULT 1  -- Default to first employee for now
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    driver_task_id INTEGER,
    assigned_driver_name TEXT,
    equipment_count INTEGER,
    total_quantity INTEGER
) AS $CREATE_HIRE$
DECLARE
    v_interaction_id INTEGER;
    v_driver_task_id INTEGER;
    v_assigned_driver_name TEXT;
    v_reference_number VARCHAR(20);
    v_employee_id INTEGER;
    v_customer_name TEXT;
    v_contact_name TEXT;
    v_contact_phone TEXT;
    v_site_address TEXT;
    v_equipment_summary TEXT;
    v_equipment_item JSONB;
    v_equipment_count INTEGER := 0;
    v_total_quantity INTEGER := 0;
    v_equipment_names TEXT[] := '{}';
    
BEGIN
    -- =============================================================================
    -- VALIDATION USING EXISTING CUSTOMER_MANAGEMENT PROCEDURES
    -- =============================================================================
    
    -- Set employee ID (simplified for now)
    v_employee_id := COALESCE(p_employee_id, 1);
    
    -- Validate customer exists using existing core.lookup_customer procedure
    DECLARE
        v_customer_lookup RECORD;
    BEGIN
        SELECT * INTO v_customer_lookup FROM core.lookup_customer(p_customer_id);
        
        IF v_customer_lookup.customer_id IS NULL OR v_customer_lookup.status != 'active' THEN
            RETURN QUERY SELECT 
                false, 
                'Invalid customer ID or customer is not active'::TEXT,
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            RETURN;
        END IF;
    END;
    
    -- Validate contact belongs to customer using existing core.get_customer_contacts procedure
    DECLARE
        v_contact_found BOOLEAN := false;
    BEGIN
        -- Check if contact exists in customer's contact list
        SELECT EXISTS(
            SELECT 1 FROM core.get_customer_contacts(p_customer_id) 
            WHERE contact_id = p_contact_id
        ) INTO v_contact_found;
        
        IF NOT v_contact_found THEN
            RETURN QUERY SELECT 
                false, 
                'Contact does not belong to the selected customer'::TEXT,
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            RETURN;
        END IF;
    END;
    
    -- Validate site belongs to customer (direct table check since site_management.sql has nothing yet)
    IF NOT EXISTS (SELECT 1 FROM core.sites WHERE id = p_site_id AND customer_id = p_customer_id AND is_active = true) THEN
        RETURN QUERY SELECT 
            false, 
            'Site does not belong to the selected customer or is not active'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Validate equipment list is not empty
    IF p_equipment_list IS NULL OR jsonb_array_length(p_equipment_list) = 0 THEN
        RETURN QUERY SELECT 
            false, 
            'Equipment list cannot be empty'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GATHER CUSTOMER/CONTACT/SITE INFORMATION USING EXISTING PROCEDURES
    -- =============================================================================
    
    -- Get customer name using existing core.lookup_customer procedure
    DECLARE
        v_customer_lookup RECORD;
    BEGIN
        SELECT * INTO v_customer_lookup FROM core.lookup_customer(p_customer_id);
        v_customer_name := v_customer_lookup.customer_name;
    END;
    
    -- Get contact information using existing core.get_customer_contacts procedure
    DECLARE
        v_contact_record RECORD;
    BEGIN
        SELECT * INTO v_contact_record 
        FROM core.get_customer_contacts(p_customer_id) 
        WHERE contact_id = p_contact_id;
        
        v_contact_name := v_contact_record.full_name;
        v_contact_phone := v_contact_record.phone_number;
    END;
    
    -- Get site address (direct table lookup since site_management.sql has nothing yet)
    SELECT s.address_line1 || COALESCE(', ' || s.address_line2, '') || ', ' || s.city
    INTO v_site_address
    FROM core.sites s WHERE s.id = p_site_id;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER USING EXISTING SYSTEM PROCEDURES
    -- =============================================================================
    
    -- Use existing system procedures for reference number generation
    -- Assuming these exist: system.get_prefix_for_interaction() and system.get_next_sequence_for_date()
    SELECT system.generate_reference_number('hire') INTO v_reference_number;
    
    -- =============================================================================
    -- CREATE INTERACTION RECORD (Layer 1)
    -- =============================================================================
    
    INSERT INTO interactions.interactions (
        customer_id, 
        contact_id, 
        employee_id, 
        interaction_type,
        status, 
        reference_number, 
        contact_method, 
        notes,
        created_at,
        updated_at
    ) VALUES (
        p_customer_id,
        p_contact_id,
        v_employee_id,
        'hire',
        'processing',
        v_reference_number,
        'system',
        p_notes,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_interaction_id;
    
    -- =============================================================================
    -- CREATE HIRE DETAILS COMPONENT (Layer 2)
    -- =============================================================================
    
    INSERT INTO interactions.component_hire_details (
        interaction_id,
        site_id,
        deliver_date,
        deliver_time,
        start_date,
        start_time,
        delivery_method,
        special_instructions,
        created_at
    ) VALUES (
        v_interaction_id,
        p_site_id,
        p_delivery_date,
        p_delivery_time,
        p_hire_start_date,
        p_delivery_time, -- Use delivery time as start time
        'deliver',
        p_notes,
        CURRENT_TIMESTAMP
    );
    
    -- =============================================================================
    -- CREATE EQUIPMENT LIST COMPONENT (Layer 2)
    -- =============================================================================
    
    -- Process equipment items and build summary
    FOR v_equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_list)
    LOOP
        -- Validate equipment exists (could use existing equipment validation)
        IF NOT EXISTS (
            SELECT 1 FROM core.equipment_categories 
            WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER 
            AND is_active = true
        ) THEN
            RETURN QUERY SELECT 
                false, 
                ('Equipment category ID ' || (v_equipment_item->>'equipment_category_id') || ' does not exist or is not active')::TEXT,
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            RETURN;
        END IF;
        
        -- Insert equipment item into component table
        INSERT INTO interactions.component_equipment_list (
            interaction_id,
            equipment_category_id,
            quantity,
            special_requirements,
            created_at
        ) VALUES (
            v_interaction_id,
            (v_equipment_item->>'equipment_category_id')::INTEGER,
            (v_equipment_item->>'quantity')::INTEGER,
            v_equipment_item->>'special_requirements',
            CURRENT_TIMESTAMP
        );
        
        -- Build equipment summary for driver task
        DECLARE
            v_equipment_name TEXT;
        BEGIN
            SELECT category_name INTO v_equipment_name 
            FROM core.equipment_categories 
            WHERE id = (v_equipment_item->>'equipment_category_id')::INTEGER;
            
            v_equipment_names := v_equipment_names || 
                (v_equipment_item->>'quantity' || 'x ' || v_equipment_name);
        END;
        
        -- Update counters
        v_equipment_count := v_equipment_count + 1;
        v_total_quantity := v_total_quantity + (v_equipment_item->>'quantity')::INTEGER;
    END LOOP;
    
    -- Build equipment summary text for driver
    v_equipment_summary := array_to_string(v_equipment_names, ', ');
    
    -- =============================================================================
    -- CREATE DRIVER TASK USING EXISTING HELPER FUNCTION (Layer 3)
    -- =============================================================================
    
    -- Use existing tasks.create_driver_task helper function
    SELECT dt.task_id, dt.assigned_driver_name
    INTO v_driver_task_id, v_assigned_driver_name
    FROM tasks.create_driver_task(
        v_interaction_id,           -- interaction_id
        'delivery',                 -- task_type
        p_priority,                 -- priority
        v_customer_name,            -- customer_name
        v_contact_name,             -- contact_name
        v_contact_phone,            -- contact_phone
        v_site_address,             -- site_address
        v_equipment_summary,        -- equipment_summary
        p_delivery_date,            -- scheduled_date
        p_delivery_time,            -- scheduled_time
        90,                         -- estimated_duration (minutes)
        p_notes,                    -- special_instructions
        NULL,                       -- assigned_to (let system find driver)
        v_employee_id               -- created_by
    ) dt;
    
    -- =============================================================================
    -- UPDATE INTERACTION STATUS TO ACTIVE
    -- =============================================================================
    
    UPDATE interactions.interactions 
    SET status = 'active', updated_at = CURRENT_TIMESTAMP
    WHERE id = v_interaction_id;
    
    -- =============================================================================
    -- RETURN SUCCESS RESULT
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Hire request ' || v_reference_number || ' created successfully. ' ||
         'Equipment: ' || v_equipment_count || ' items (' || v_total_quantity || ' total quantity). ' ||
         'Driver task created for delivery on ' || p_delivery_date || 
         ' at ' || p_delivery_time || '.')::TEXT,
        v_interaction_id,
        v_reference_number,
        v_driver_task_id,
        COALESCE(v_assigned_driver_name, 'Unassigned'),
        v_equipment_count,
        v_total_quantity;
        
EXCEPTION 
    WHEN unique_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Duplicate hire request detected. Reference number already exists.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            
    WHEN foreign_key_violation THEN
        RETURN QUERY SELECT 
            false, 
            'Invalid reference data. Please verify customer, contact, site, and equipment selections.'::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
            
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::INTEGER, NULL::INTEGER;
END;
$CREATE_HIRE$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions to appropriate roles
GRANT EXECUTE ON FUNCTION interactions.create_hire TO PUBLIC;

COMMENT ON FUNCTION interactions.create_hire IS 
'Equipment hire processing procedure using existing customer_management procedures.
Uses core.lookup_customer() for customer validation, core.get_customer_contacts() for contact validation.
Creates hire interaction with equipment list and delivery details.
Uses existing system.generate_reference_number() for references and tasks.create_driver_task() for driver task creation.
Follows hire_process.txt documentation and leverages existing customer_management procedures.
Supports open-ended hire requests (no duration required per business requirements).';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage with existing customer_management procedures:

-- 1. Search for customers using existing core.search_customers procedure
SELECT * FROM core.search_customers(
    'ABC Construction',  -- p_search_term
    'company',          -- p_customer_type  
    'active',           -- p_status
    true,               -- p_include_contacts
    10,                 -- p_limit_results
    0                   -- p_offset_results
);

-- 2. Get customer details using existing core.lookup_customer procedure
SELECT * FROM core.lookup_customer(1);

-- 3. Get contacts for selected customer using existing core.get_customer_contacts procedure  
SELECT * FROM core.get_customer_contacts(1);

-- 4. Get sites for selected customer (direct table query until site_management is implemented)
SELECT id as site_id, site_name, 
       address_line1 || COALESCE(', ' || address_line2, '') || ', ' || city as address,
       delivery_instructions, site_type, site_contact_name, site_contact_phone
FROM core.sites 
WHERE customer_id = 1 AND is_active = true
ORDER BY CASE WHEN site_type = 'head_office' THEN 1 
              WHEN site_type = 'delivery_site' THEN 2 
              ELSE 3 END, site_name;

-- 5. Get equipment list (direct table query until equipment procedures are implemented)
SELECT id as equipment_id, category_name as equipment_name, category_code, description,
       (SELECT price_per_day FROM core.equipment_pricing ep WHERE ep.equipment_category_id = ec.id AND customer_type = 'company') as daily_rate_company,
       (SELECT price_per_day FROM core.equipment_pricing ep WHERE ep.equipment_category_id = ec.id AND customer_type = 'individual') as daily_rate_individual
FROM core.equipment_categories ec
WHERE is_active = true
ORDER BY category_name;

-- 6. Get accessories for equipment (direct table query until equipment procedures are implemented)
SELECT id as accessory_id, accessory_name, accessory_type, quantity as default_quantity, description, is_consumable
FROM core.equipment_accessories 
WHERE equipment_category_id = 1 AND status = 'active'
ORDER BY CASE WHEN accessory_type = 'default' THEN 1 ELSE 2 END, accessory_name;

-- 7. Create the hire request using the validated data
SELECT * FROM interactions.create_hire(
    1,                                              -- customer_id (from step 1)
    1,                                              -- contact_id (from step 3)
    1,                                              -- site_id (from step 4)
    '[{"equipment_category_id": 1, "quantity": 2}, 
      {"equipment_category_id": 3, "quantity": 1}]'::JSONB,  -- equipment_list (from step 5)
    '2025-06-12'::DATE,                            -- hire_start_date
    '2025-06-12'::DATE,                            -- delivery_date
    '09:00'::TIME,                                 -- delivery_time
    'Special delivery instructions'                 -- notes
);

-- This creates:
-- - Interaction record with reference number HR250612001 (using system.generate_reference_number)
-- - Equipment list component with selected equipment
-- - Hire details component with delivery information  
-- - Driver task for equipment delivery (using tasks.create_driver_task)
*/