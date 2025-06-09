-- =============================================================================
-- INTERACTIONS: Process quote requests for equipment hire
-- =============================================================================
-- Purpose: Process quote requests for equipment hire
-- Dependencies: interactions.component_quote_totals, core.equipment_pricing
-- Used by: Quote generation workflow, formal pricing
-- Function: interactions.process_quote_request
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.process_quote_request;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.process_quote_request(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_equipment_requests JSONB, -- Array of {name: "Rammer", quantity: 1, duration: 3}
    p_hire_duration INTEGER,
    p_hire_period_type VARCHAR(20) DEFAULT 'days',
    p_contact_method VARCHAR(50) DEFAULT 'phone',
    p_notes TEXT DEFAULT NULL,
    p_employee_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    task_id INTEGER,
    subtotal DECIMAL(15,2),
    tax_amount DECIMAL(15,2),
    total_amount DECIMAL(15,2),
    quote_valid_until DATE
) AS $
DECLARE
    v_interaction_id INTEGER;
    v_reference_number VARCHAR(20);
    v_task_id INTEGER;
    v_employee_id INTEGER;
    v_customer_name VARCHAR(255);
    v_contact_name TEXT;
    v_contact_email VARCHAR(255);
    v_customer_type VARCHAR(20);
    v_subtotal DECIMAL(15,2) := 0.00;
    v_tax_rate DECIMAL(5,2) := 15.00;
    v_tax_amount DECIMAL(15,2);
    v_total_amount DECIMAL(15,2);
    v_valid_until DATE;
    v_task_title VARCHAR(255);
    v_task_description TEXT;
    v_equipment_summary TEXT := '';
    equipment_item JSONB;
    v_equipment_id INTEGER;
    v_pricing RECORD;
    v_item_cost DECIMAL(15,2);
    v_priority VARCHAR(20) := 'medium';
BEGIN
    -- Get employee ID from session if not provided
    v_employee_id := COALESCE(p_employee_id, current_setting('app.current_employee_id', true)::INTEGER);
    
    -- Validate inputs
    IF p_customer_id IS NULL THEN
        RETURN QUERY SELECT false, 'Customer ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
        RETURN;
    END IF;
    
    IF p_contact_id IS NULL THEN
        RETURN QUERY SELECT false, 'Contact ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
        RETURN;
    END IF;
    
    IF p_equipment_requests IS NULL OR jsonb_array_length(p_equipment_requests) = 0 THEN
        RETURN QUERY SELECT false, 'At least one equipment item must be specified'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
        RETURN;
    END IF;
    
    IF p_hire_duration IS NULL OR p_hire_duration <= 0 THEN
        RETURN QUERY SELECT false, 'Valid hire duration is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
        RETURN;
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not authenticated'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
        RETURN;
    END IF;
    
    -- Get customer and contact details
    SELECT 
        c.customer_name,
        CASE WHEN c.is_company THEN 'company' ELSE 'individual' END,
        ct.first_name || ' ' || ct.last_name,
        ct.email
    INTO v_customer_name, v_customer_type, v_contact_name, v_contact_email
    FROM core.customers c
    JOIN core.contacts ct ON c.id = ct.customer_id
    WHERE c.id = p_customer_id 
        AND ct.id = p_contact_id
        AND c.status = 'active' 
        AND ct.status = 'active';
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT false, 'Customer or contact not found or inactive'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
        RETURN;
    END IF;
    
    -- Generate reference number
    v_reference_number := system.generate_reference_number('quote');
    
    -- Set quote validity (30 days from today)
    v_valid_until := CURRENT_DATE + INTERVAL '30 days';
    
    -- Create interaction record (Layer 1)
    INSERT INTO interactions.interactions (
        customer_id, contact_id, employee_id, interaction_type,
        status, reference_number, contact_method, notes
    ) VALUES (
        p_customer_id, p_contact_id, v_employee_id, 'quote',
        'pending', v_reference_number, p_contact_method,
        COALESCE(p_notes, 'Quote request from ' || v_contact_name || ' at ' || v_customer_name || ' for ' || p_hire_duration || ' ' || p_hire_period_type)
    ) RETURNING id INTO v_interaction_id;
    
    -- Process each equipment item
    FOR equipment_item IN SELECT * FROM jsonb_array_elements(p_equipment_requests)
    LOOP
        -- Get equipment ID
        SELECT id INTO v_equipment_id
        FROM core.equipment_categories
        WHERE LOWER(category_name) = LOWER(equipment_item->>'name')
            AND is_active = true;
        
        IF v_equipment_id IS NULL THEN
            RETURN QUERY SELECT false, ('Equipment not found: ' || (equipment_item->>'name'))::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
            RETURN;
        END IF;
        
        -- Get pricing for this equipment
        SELECT * INTO v_pricing
        FROM core.get_equipment_pricing(v_equipment_id, p_customer_id, p_hire_duration);
        
        IF v_pricing IS NULL THEN
            RETURN QUERY SELECT false, ('No pricing found for: ' || (equipment_item->>'name'))::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::DECIMAL, NULL::DECIMAL, NULL::DECIMAL, NULL::DATE;
            RETURN;
        END IF;
        
        -- Calculate item cost
        v_item_cost := v_pricing.total_cost * COALESCE((equipment_item->>'quantity')::INTEGER, 1);
        v_subtotal := v_subtotal + v_item_cost;
        
        -- Add to equipment summary
        IF v_equipment_summary != '' THEN
            v_equipment_summary := v_equipment_summary || ', ';
        END IF;
        v_equipment_summary := v_equipment_summary || (equipment_item->>'name') || 
            CASE WHEN COALESCE((equipment_item->>'quantity')::INTEGER, 1) > 1 
                THEN ' (x' || (equipment_item->>'quantity') || ')'
                ELSE ''
            END;
        
        -- Create equipment list component (Layer 2)
        INSERT INTO interactions.component_equipment_list (
            interaction_id, equipment_category_id, quantity, 
            hire_duration, hire_period_type, special_requirements
        ) VALUES (
            v_interaction_id, v_equipment_id, COALESCE((equipment_item->>'quantity')::INTEGER, 1),
            p_hire_duration, p_hire_period_type,
            'Quote for ' || p_hire_duration || ' ' || p_hire_period_type || ' hire. Rate: R' || v_pricing.best_rate || ' per ' || v_pricing.best_rate_type || '. Total: R' || v_item_cost
        );
    END LOOP;
    
    -- Calculate tax and total
    v_tax_amount := v_subtotal * (v_tax_rate / 100);
    v_total_amount := v_subtotal + v_tax_amount;
    
    -- Set priority based on quote value
    IF v_total_amount > 10000 THEN
        v_priority := 'high';
    ELSIF v_total_amount > 5000 THEN
        v_priority := 'medium';
    ELSE
        v_priority := 'medium';
    END IF;
    
    -- Create quote totals component (Layer 2)
    INSERT INTO interactions.component_quote_totals (
        interaction_id, subtotal, tax_rate, tax_amount, total_amount,
        currency, valid_until, notes
    ) VALUES (
        v_interaction_id, v_subtotal, v_tax_rate, v_tax_amount, v_total_amount,
        'ZAR', v_valid_until,
        'Quote includes ' || jsonb_array_length(p_equipment_requests) || ' equipment item(s). VAT included at ' || v_tax_rate || '%. Quote valid for 30 days from issue date.'
    );
    
    -- Create user task for sending quote (Layer 3)
    v_task_title := 'Send quote to ' || v_contact_name || ' at ' || v_customer_name;
    v_task_description := 'Quote request for ' || v_customer_name || ':

QUOTE DETAILS:
Equipment: ' || v_equipment_summary || '
Duration: ' || p_hire_duration || ' ' || p_hire_period_type || '
Subtotal: R' || v_subtotal || '
VAT (15%): R' || v_tax_amount || '
Total: R' || v_total_amount || '

CUSTOMER INFORMATION:
Contact: ' || v_contact_name || '
Email: ' || v_contact_email || '
Customer Type: ' || CASE WHEN v_customer_type = 'company' THEN 'Company' ELSE 'Individual' END || '

REQUIRED ACTIONS:
1. Generate formal quote document (PDF)
2. Include all equipment specifications and pricing
3. Add standard terms and conditions
4. Email quote to customer contact
5. Follow up within 3 business days if no response
6. Update interaction status when quote is sent

Quote Valid Until: ' || v_valid_until;
    
    INSERT INTO tasks.user_taskboard (
        interaction_id, assigned_to, task_type, priority, status,
        title, description, due_date
    ) VALUES (
        v_interaction_id, v_employee_id, 'send_quote', v_priority, 'pending',
        v_task_title, v_task_description, CURRENT_DATE + 1
    ) RETURNING id INTO v_task_id;
    
    -- Log audit entry
    INSERT INTO security.audit_log (employee_id, action, table_name, record_id, new_values)
    VALUES (v_employee_id, 'create_quote', 'interactions', v_interaction_id,
            jsonb_build_object(
                'reference_number', v_reference_number,
                'customer_name', v_customer_name,
                'equipment_summary', v_equipment_summary,
                'total_amount', v_total_amount,
                'valid_until', v_valid_until
            ));
    
    -- Return success
    RETURN QUERY SELECT 
        true,
        'Quote request created successfully'::TEXT,
        v_interaction_id,
        v_reference_number,
        v_task_id,
        v_subtotal,
        v_tax_amount,
        v_total_amount,
        v_valid_until;
        
EXCEPTION WHEN OTHERS THEN
    -- Return error
    RETURN QUERY SELECT 
        false,
        ('Error processing quote request: ' || SQLERRM)::TEXT,
        NULL::INTEGER,
        NULL::VARCHAR(20),
        NULL::INTEGER,
        NULL::DECIMAL,
        NULL::DECIMAL,
        NULL::DECIMAL,
        NULL::DATE;
END;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.process_quote_request TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.process_quote_request TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.process_quote_request TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.process_quote_request TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.process_quote_request IS 
'Process quote requests for equipment hire. Used by Quote generation workflow, formal pricing.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.process_quote_request(param1, param2);

-- Additional examples for this specific function
*/
