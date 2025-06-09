-- =============================================================================
-- INTERACTIONS: Process refund requests from customers
-- =============================================================================
-- Purpose: Process refund requests from customers
-- Dependencies: interactions.component_refund_details, tasks.user_taskboard
-- Used by: Refund processing workflow, accounts management
-- Function: interactions.process_refund_request
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.process_refund_request;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.process_refund_request(
    p_customer_id INTEGER,
    p_contact_id INTEGER,
    p_refund_amount DECIMAL(15,2),
    p_refund_reason TEXT,
    p_refund_type VARCHAR(20) DEFAULT 'partial',
    p_refund_method VARCHAR(20) DEFAULT 'eft',
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
    assigned_to_name TEXT,
    priority VARCHAR(20)
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
    v_contact_phone VARCHAR(20);
    v_credit_limit DECIMAL(15,2);
    v_payment_terms VARCHAR(50);
    v_task_title VARCHAR(255);
    v_task_description TEXT;
    v_accounts_employee_name TEXT;
    v_priority VARCHAR(20);
    v_simulated_balance DECIMAL(15,2);
    v_balance_after DECIMAL(15,2);
BEGIN
    -- Get employee ID from session if not provided
    v_employee_id := COALESCE(p_employee_id, current_setting('app.current_employee_id', true)::INTEGER);
    
    -- Validate inputs
    IF p_customer_id IS NULL THEN
        RETURN QUERY SELECT false, 'Customer ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    IF p_contact_id IS NULL THEN
        RETURN QUERY SELECT false, 'Contact ID is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    IF p_refund_amount IS NULL OR p_refund_amount <= 0 THEN
        RETURN QUERY SELECT false, 'Valid refund amount is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    IF p_refund_reason IS NULL OR TRIM(p_refund_reason) = '' THEN
        RETURN QUERY SELECT false, 'Refund reason is required'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    IF p_refund_type NOT IN ('full', 'partial', 'deposit_only') THEN
        RETURN QUERY SELECT false, 'Invalid refund type. Must be: full, partial, or deposit_only'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    IF p_refund_method NOT IN ('eft', 'cash', 'cheque', 'credit_note') THEN
        RETURN QUERY SELECT false, 'Invalid refund method. Must be: eft, cash, cheque, or credit_note'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not authenticated'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    -- Get customer and contact details
    SELECT 
        c.customer_name,
        c.credit_limit,
        c.payment_terms,
        ct.first_name || ' ' || ct.last_name,
        ct.email,
        ct.phone_number
    INTO v_customer_name, v_credit_limit, v_payment_terms, v_contact_name, v_contact_email, v_contact_phone
    FROM core.customers c
    JOIN core.contacts ct ON c.id = ct.customer_id
    WHERE c.id = p_customer_id 
        AND ct.id = p_contact_id
        AND c.status = 'active' 
        AND ct.status = 'active';
    
    IF v_customer_name IS NULL THEN
        RETURN QUERY SELECT false, 'Customer or contact not found or inactive'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
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
        RETURN QUERY SELECT false, 'No accounts team member available'::TEXT, NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT, NULL::VARCHAR(20);
        RETURN;
    END IF;
    
    -- Set priority based on refund amount
    IF p_refund_amount > 10000 THEN
        v_priority := 'high';
    ELSIF p_refund_amount > 5000 THEN
        v_priority := 'medium';
    ELSE
        v_priority := 'medium';
    END IF;
    
    -- Simulate current account balance (30% of credit limit)
    v_simulated_balance := v_credit_limit * 0.3;
    v_balance_after := v_simulated_balance - p_refund_amount;
    
    -- Generate reference number
    v_reference_number := system.generate_reference_number('refund');
    
    -- Create interaction record (Layer 1)
    INSERT INTO interactions.interactions (
        customer_id, contact_id, employee_id, interaction_type,
        status, reference_number, contact_method, notes
    ) VALUES (
        p_customer_id, p_contact_id, v_employee_id, 'refund',
        'pending', v_reference_number, p_contact_method,
        COALESCE(p_notes, 'Refund request from ' || v_contact_name || ' at ' || v_customer_name || '. Amount: R' || p_refund_amount || '. Reason: ' || p_refund_reason)
    ) RETURNING id INTO v_interaction_id;
    
    -- Create refund details component (Layer 2)
    INSERT INTO interactions.component_refund_details (
        interaction_id, refund_type, refund_amount, refund_reason,
        account_balance_before, account_balance_after, refund_method,
        bank_details
    ) VALUES (
        v_interaction_id, p_refund_type, p_refund_amount, p_refund_reason,
        v_simulated_balance, v_balance_after, p_refund_method,
        'Customer banking details to be verified by accounts team'
    );
    
    -- Create user task for accounts team (Layer 3)
    v_task_title := 'Process refund request for ' || v_contact_name || ' at ' || v_customer_name;
    v_task_description := 'Refund request for ' || v_customer_name || ':

REFUND DETAILS:
Amount: R' || p_refund_amount || '
Type: ' || REPLACE(p_refund_type, '_', ' ') || '
Reason: ' || p_refund_reason || '
Method: ' || UPPER(p_refund_method) || '

CUSTOMER INFORMATION:
Contact: ' || v_contact_name || '
Email: ' || v_contact_email || '
Phone: ' || v_contact_phone || '
Credit Limit: R' || v_credit_limit || '
Payment Terms: ' || v_payment_terms || '

ACCOUNT BALANCE (ESTIMATED):
Balance Before: R' || v_simulated_balance || '
Balance After: R' || v_balance_after || '

REQUIRED ACTIONS:
1. Verify current account balance and transaction history
2. Confirm refund amount and eligibility
3. Obtain customer banking details for ' || UPPER(p_refund_method) || '
4. Process refund through banking system
5. Update customer account records
6. Email refund confirmation to customer
7. Update interaction status to completed

APPROVAL REQUIRED: ' || CASE WHEN p_refund_amount > 5000 THEN 'Yes - Manager approval needed for refunds over R5,000' ELSE 'Standard processing - no special approval needed' END || '

PRIORITY: ' || UPPER(v_priority) || ' - ' || CASE WHEN p_refund_amount > 10000 THEN 'Large refund amount' WHEN p_refund_amount > 5000 THEN 'Medium refund amount' ELSE 'Standard refund' END || '

REFERENCE: ' || v_reference_number;
    
    INSERT INTO tasks.user_taskboard (
        interaction_id, assigned_to, task_type, priority, status,
        title, description, due_date
    ) VALUES (
        v_interaction_id, v_accounts_employee_id, 'process_refund', v_priority, 'pending',
        v_task_title, v_task_description, CURRENT_DATE + 1
    ) RETURNING id INTO v_task_id;
    
    -- Log audit entry
    INSERT INTO security.audit_log (employee_id, action, table_name, record_id, new_values)
    VALUES (v_employee_id, 'create_refund_request', 'interactions', v_interaction_id,
            jsonb_build_object(
                'reference_number', v_reference_number,
                'customer_name', v_customer_name,
                'contact_name', v_contact_name,
                'refund_amount', p_refund_amount,
                'refund_type', p_refund_type,
                'priority', v_priority,
                'assigned_to', v_accounts_employee_name
            ));
    
    -- Return success
    RETURN QUERY SELECT 
        true,
        'Refund request created successfully'::TEXT,
        v_interaction_id,
        v_reference_number,
        v_task_id,
        v_accounts_employee_name,
        v_priority;
        
EXCEPTION WHEN OTHERS THEN
    -- Return error
    RETURN QUERY SELECT 
        false,
        ('Error processing refund request: ' || SQLERRM)::TEXT,
        NULL::INTEGER,
        NULL::VARCHAR(20),
        NULL::INTEGER,
        NULL::TEXT,
        NULL::VARCHAR(20);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.process_refund_request TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.process_refund_request TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.process_refund_request TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.process_refund_request TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.process_refund_request IS 
'Process refund requests from customers. Used by Refund processing workflow, accounts management.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.process_refund_request(param1, param2);

-- Additional examples for this specific function
*/
