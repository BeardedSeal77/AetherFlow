SET search_path TO core, interactions, tasks, system, public;


CREATE OR REPLACE FUNCTION sp_validate_hire_request(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_site_id INTEGER,
    p_equipment_selections JSONB,
    p_delivery_date DATE,
    p_estimated_amount DECIMAL(15,2) DEFAULT 0
)
RETURNS TABLE(
    is_valid BOOLEAN,
    validation_errors JSONB,
    warnings JSONB
) AS $$
DECLARE
    errors JSONB := '[]'::JSONB;
    warnings JSONB := '[]'::JSONB;
    customer_check RECORD;
    availability_check RECORD;
    equipment_item JSONB;
BEGIN
    -- Validate customer exists and is active
    SELECT * INTO customer_check
    FROM sp_validate_customer_credit(p_customer_id, p_estimated_amount);
    
    IF NOT customer_check.is_valid THEN
        errors := errors || jsonb_build_object(
            'field', 'customer_id',
            'message', customer_check.message
        );
    END IF;
    
    -- Validate contact belongs to customer
    IF NOT EXISTS (
        SELECT 1 FROM core.contacts 
        WHERE id = p_contact_id AND customer_id = p_customer_id AND status = 'active'
    ) THEN
        errors := errors || jsonb_build_object(
            'field', 'contact_id',
            'message', 'Contact does not belong to selected customer or is inactive'
        );
    END IF;
    
    -- Validate site belongs to customer
    IF NOT EXISTS (
        SELECT 1 FROM core.sites 
        WHERE id = p_site_id AND customer_id = p_customer_id AND is_active = TRUE
    ) THEN
        errors := errors || jsonb_build_object(
            'field', 'site_id',
            'message', 'Site does not belong to selected customer or is inactive'
        );
    END IF;
    
    -- Validate delivery date
    IF p_delivery_date < CURRENT_DATE THEN
        errors := errors || jsonb_build_object(
            'field', 'delivery_date',
            'message', 'Delivery date cannot be in the past'
        );
    END IF;
    
    -- Validate equipment availability
    FOR availability_check IN 
        SELECT * FROM sp_check_equipment_availability(p_equipment_selections, p_delivery_date)
    LOOP
        IF NOT availability_check.is_available THEN
            errors := errors || jsonb_build_object(
                'field', 'equipment',
                'message', availability_check.type_name || ': ' || availability_check.message
            );
        END IF;
    END LOOP;
    
    -- Add warnings for same-day delivery
    IF p_delivery_date = CURRENT_DATE THEN
        warnings := warnings || jsonb_build_object(
            'field', 'delivery_date',
            'message', 'Same-day delivery requires manager approval'
        );
    END IF;
    
    RETURN QUERY SELECT 
        (jsonb_array_length(errors) = 0) AS is_valid,
        errors AS validation_errors,
        warnings;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_validate_hire_request IS 'Comprehensive validation of hire request before creation';