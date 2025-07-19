-- =============================================================================
-- UTILITY STORED PROCEDURES
-- =============================================================================

-- Generate unique reference numbers
CREATE OR REPLACE FUNCTION sp_generate_reference_number(
    p_interaction_type VARCHAR(50)
)
RETURNS VARCHAR(20) AS $$
DECLARE
    v_prefix VARCHAR(10);
    v_date_part VARCHAR(6);
    v_sequence INTEGER;
    v_reference VARCHAR(20);
BEGIN
    -- Get prefix for interaction type
    SELECT prefix INTO v_prefix
    FROM system.reference_prefixes
    WHERE interaction_type = p_interaction_type;
    
    IF v_prefix IS NULL THEN
        RAISE EXCEPTION 'Unknown interaction type: %', p_interaction_type;
    END IF;
    
    -- Generate date part (YYMMDD)
    v_date_part := TO_CHAR(CURRENT_DATE, 'YYMMDD');
    
    -- Get and increment sequence
    UPDATE system.reference_prefixes
    SET current_sequence = current_sequence + 1
    WHERE interaction_type = p_interaction_type
    RETURNING current_sequence INTO v_sequence;
    
    -- Format reference number
    v_reference := v_prefix || v_date_part || LPAD(v_sequence::TEXT, 3, '0');
    
    RETURN v_reference;
END;
$$ LANGUAGE plpgsql;

-- Get customers for selection dropdown
CREATE OR REPLACE FUNCTION sp_get_customers_for_selection(
    p_search_term VARCHAR(100) DEFAULT NULL,
    p_active_only BOOLEAN DEFAULT true
)
RETURNS TABLE (
    customer_id INTEGER,
    customer_code VARCHAR(20),
    customer_name VARCHAR(255),
    is_company BOOLEAN,
    status VARCHAR(20),
    credit_limit DECIMAL(15,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.customer_code,
        c.customer_name,
        c.is_company,
        c.status,
        c.credit_limit
    FROM core.customers c
    WHERE 
        (NOT p_active_only OR c.status = 'active')
        AND (
            p_search_term IS NULL 
            OR c.customer_name ILIKE '%' || p_search_term || '%'
            OR c.customer_code ILIKE '%' || p_search_term || '%'
        )
    ORDER BY c.customer_name;
END;
$$ LANGUAGE plpgsql;

-- Get contacts for selected customer
CREATE OR REPLACE FUNCTION sp_get_customer_contacts(
    p_customer_id INTEGER
)
RETURNS TABLE (
    contact_id INTEGER,
    full_name VARCHAR(255),
    job_title VARCHAR(100),
    email VARCHAR(255),
    phone_number VARCHAR(20),
    whatsapp_number VARCHAR(20),
    is_primary_contact BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        (c.first_name || ' ' || c.last_name)::VARCHAR(255),
        c.job_title,
        c.email,
        c.phone_number,
        c.whatsapp_number,
        c.is_primary_contact
    FROM core.contacts c
    WHERE 
        c.customer_id = p_customer_id
        AND c.status = 'active'
    ORDER BY c.is_primary_contact DESC, c.first_name, c.last_name;
END;
$$ LANGUAGE plpgsql;

-- Get sites for selected customer
CREATE OR REPLACE FUNCTION sp_get_customer_sites(
    p_customer_id INTEGER
)
RETURNS TABLE (
    site_id INTEGER,
    site_code VARCHAR(20),
    site_name VARCHAR(255),
    site_type VARCHAR(50),
    full_address TEXT,
    site_contact_name VARCHAR(200),
    site_contact_phone VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.site_code,
        s.site_name,
        s.site_type,
        (s.address_line1 || 
         CASE WHEN s.address_line2 IS NOT NULL THEN ', ' || s.address_line2 ELSE '' END ||
         ', ' || s.city || 
         CASE WHEN s.province IS NOT NULL THEN ', ' || s.province ELSE '' END ||
         CASE WHEN s.postal_code IS NOT NULL THEN ', ' || s.postal_code ELSE '' END
        )::TEXT,
        s.site_contact_name,
        s.site_contact_phone
    FROM core.sites s
    WHERE 
        s.customer_id = p_customer_id
        AND s.is_active = true
    ORDER BY s.site_type, s.site_name;
END;
$$ LANGUAGE plpgsql;

-- Log system activity
CREATE OR REPLACE FUNCTION sp_log_activity(
    p_user_id INTEGER,
    p_action VARCHAR(100),
    p_table_name VARCHAR(100) DEFAULT NULL,
    p_record_id INTEGER DEFAULT NULL,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_log_id INTEGER;
BEGIN
    INSERT INTO system.activity_log (
        user_id, action, table_name, record_id, old_values, new_values
    ) VALUES (
        p_user_id, p_action, p_table_name, p_record_id, p_old_values, p_new_values
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Get hire dashboard summary
CREATE OR REPLACE FUNCTION sp_get_hire_dashboard_summary()
RETURNS TABLE (
    active_hires INTEGER,
    pending_allocations INTEGER,
    pending_deliveries INTEGER,
    pending_collections INTEGER,
    equipment_on_hire INTEGER,
    equipment_available INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        -- Active hires
        (SELECT COUNT(*) FROM interactions.interactions 
         WHERE interaction_type = 'hire' AND status IN ('pending', 'in_progress'))::INTEGER,
        
        -- Pending allocations (generic bookings not allocated)
        (SELECT COUNT(*) FROM interactions.interaction_equipment_types 
         WHERE booking_status = 'booked')::INTEGER,
        
        -- Pending deliveries
        (SELECT COUNT(*) FROM tasks.drivers_taskboard 
         WHERE task_type = 'delivery' AND status IN ('backlog', 'assigned'))::INTEGER,
        
        -- Pending collections
        (SELECT COUNT(*) FROM tasks.drivers_taskboard 
         WHERE task_type = 'collection' AND status IN ('backlog', 'assigned'))::INTEGER,
        
        -- Equipment on hire
        (SELECT COUNT(*) FROM equipment.equipment 
         WHERE status = 'rented')::INTEGER,
        
        -- Equipment available
        (SELECT COUNT(*) FROM equipment.equipment 
         WHERE status = 'available')::INTEGER;
END;
$$ LANGUAGE plpgsql;
