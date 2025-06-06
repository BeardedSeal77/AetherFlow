-- =============================================================================
-- PROCEDURE: 04_statement.sql
-- =============================================================================
-- Purpose: Process account statement request (based on database/test/statement.py)
-- Use Case: Customer calls requesting account statement
-- Called by: Flask server when hire controller takes statement request call
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- FUNCTION: Process Statement Request
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.process_statement_request(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
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
    assigned_to_name TEXT
) AS $$
DECLARE
    v_interaction_id INTEGER;
    v_reference_number VARCHAR(20);
    v_task_id INTEGER;
    v_employee_id INTEGER;
    v_accounts_employee_id INTEGER;
    v_customer_name VARCHAR(255);
    v_contact_name TEXT;
    v_contact_email VARCHAR(255);
    v_is_billing_contact BOOLEAN;
    v_credit_limit DECIMAL(15,2);
    v_payment_terms VARCHAR(50);
    v_task_title VARCHAR(255);
    v_task_description TEXT;
    v_accounts_employee_name TEXT;
BEGIN
    -- Get employee ID from session if not provided
    v_employee_id := COALESCE(p_employee_id, current_setting('app.current_employee_id', true)::INTEGER);
    
    -- Validate inputs
    IF p_customer_id IS NULL THEN
        RETURN QUERY SELECT false, 'Customer ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    IF p_contact_id IS NULL THEN
        RETURN QUERY SELECT false, 'Contact ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not authenticated'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Get customer and contact details
    SELECT 
        c.customer_name,
        c.credit_limit,
        c.payment_terms,
        ct.first_name || ' ' || ct.last_name,
        ct.email,
        ct.is_billing_contact
    INTO v_customer_name, v_credit_limit, v_payment_terms, v_contact_name, v_contact_email, v_is_billing_contact
    FROM core.customers c
    JOIN core.contacts ct ON c.id = ct.customer_id
    WHERE c.id = p_customer_id 
        AND ct.id = p_contact_id
        AND c.status = 'active' 
        AND ct.status = 'active';
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT false, 'Customer or contact not found or inactive'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Get an accounts team member to assign the task
    SELECT id, name || ' ' || surname
    INTO v_accounts_employee_id, v_accounts_employee_name
    FROM core.employees
    WHERE role = 'accounts' AND status = 'active'
    ORDER BY name
    LIMIT 1;
    
    IF v_accounts_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'No accounts team member available'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Generate reference number
    v_reference_number := system.generate_reference_number('statement');
    
    -- Create interaction record (Layer 1)
    INSERT INTO interactions.interactions (
        customer_id, contact_id, employee_id, interaction_type,
        status, reference_number, contact_method, notes
    ) VALUES (
        p_customer_id, p_contact_id, v_employee_id, 'statement',
        'pending', v_reference_number, p_contact_method,
        COALESCE(p_notes, 'Account statement request from ' || v_contact_name || ' at ' || v_customer_name)
    ) RETURNING id INTO v_interaction_id;
    
    -- Create user task for accounts team (Layer 3)
    v_task_title := 'Generate account statement for ' || v_contact