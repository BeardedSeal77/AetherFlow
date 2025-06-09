CREATE OR REPLACE FUNCTION interactions.create_application(
    -- Application details (all required)
    p_application_type VARCHAR(20),        -- 'individual' or 'company'
    p_applicant_first_name VARCHAR(100),
    p_applicant_last_name VARCHAR(100),
    p_applicant_email VARCHAR(255),
    
    -- Optional application details
    p_contact_method VARCHAR(50) DEFAULT 'email',
    p_documents_required TEXT DEFAULT NULL,
    p_documents_received TEXT DEFAULT NULL,
    p_verification_notes TEXT DEFAULT NULL,
    p_initial_notes TEXT DEFAULT NULL,
    
    -- System details
    p_employee_id INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    task_id INTEGER,
    assigned_to TEXT
) AS $$
DECLARE
    v_interaction_id INTEGER;
    v_task_id INTEGER;
    v_reference_number VARCHAR(20);
    v_employee_id INTEGER;
    v_employee_name TEXT;
    v_hire_control_employee_id INTEGER;
    v_hire_control_employee_name TEXT;
    v_generic_customer_id INTEGER := 999;  -- Fixed generic customer ID
    v_generic_contact_id INTEGER := 999;   -- Fixed generic contact ID
    v_task_title TEXT;
    v_task_description TEXT;
    v_due_date DATE;
    v_validation_errors TEXT[] := '{}';
    v_applicant_name TEXT;
BEGIN
    -- =============================================================================
    -- AUTHENTICATION & AUTHORIZATION
    -- =============================================================================
    
    -- Get employee ID from session or parameter
    IF p_session_token IS NOT NULL THEN
        SELECT ea.employee_id INTO v_employee_id
        FROM security.employee_auth ea
        WHERE ea.session_token = p_session_token
        AND ea.session_expires > CURRENT_TIMESTAMP;
        
        IF v_employee_id IS NULL THEN
            RETURN QUERY SELECT false, 'Invalid or expired session'::TEXT, 
                NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
            RETURN;
        END IF;
    ELSE
        v_employee_id := COALESCE(p_employee_id, 
            NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER);
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Get employee details for logging
    SELECT e.name || ' ' || e.surname INTO v_employee_name
    FROM core.employees e
    WHERE e.id = v_employee_id AND e.status = 'active';
    
    IF v_employee_name IS NULL THEN
        RETURN QUERY SELECT false, 'Employee not found or inactive'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- INPUT VALIDATION
    -- =============================================================================
    
    -- Required field validation
    IF p_application_type IS NULL OR p_application_type NOT IN ('individual', 'company') THEN
        v_validation_errors := array_append(v_validation_errors, 'Application type must be "individual" or "company"');
    END IF;
    
    IF p_applicant_first_name IS NULL OR TRIM(p_applicant_first_name) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Applicant first name is required');
    END IF;
    
    IF p_applicant_last_name IS NULL OR TRIM(p_applicant_last_name) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Applicant last name is required');
    END IF;
    
    IF p_applicant_email IS NULL OR TRIM(p_applicant_email) = '' THEN
        v_validation_errors := array_append(v_validation_errors, 'Applicant email is required');
    ELSIF p_applicant_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        v_validation_errors := array_append(v_validation_errors, 'Applicant email format is invalid');
    END IF;
    
    IF p_contact_method NOT IN ('phone', 'email', 'in_person', 'whatsapp', 'online', 'other') THEN
        v_validation_errors := array_append(v_validation_errors, 'Invalid contact method');
    END IF;
    
    -- Return validation errors if any
    IF array_length(v_validation_errors, 1) > 0 THEN
        RETURN QUERY SELECT false, 'Validation failed: ' || array_to_string(v_validation_errors, ', ')::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- VERIFY GENERIC CUSTOMER/CONTACT EXISTS
    -- =============================================================================
    
    -- Verify generic customer exists
    IF NOT EXISTS (SELECT 1 FROM core.customers WHERE id = v_generic_customer_id AND status = 'active') THEN
        RETURN QUERY SELECT false, 'Generic customer for applications not found'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Verify generic contact exists
    IF NOT EXISTS (SELECT 1 FROM core.contacts WHERE id = v_generic_contact_id AND status = 'active') THEN
        RETURN QUERY SELECT false, 'Generic contact for applications not found'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- FIND HIRE CONTROL EMPLOYEE FOR TASK ASSIGNMENT
    -- =============================================================================
    
    -- Get a hire_control team member to assign the task
    SELECT id, name || ' ' || surname
    INTO v_hire_control_employee_id, v_hire_control_employee_name
    FROM core.employees
    WHERE role = 'hire_control' AND status = 'active'
    ORDER BY RANDOM()  -- Distribute workload randomly
    LIMIT 1;
    
    IF v_hire_control_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'No hire control team member available to process application'::TEXT, 
            NULL::INTEGER, NULL::VARCHAR(20), NULL::INTEGER, NULL::TEXT;
        RETURN;
    END IF;
    
    -- =============================================================================
    -- GENERATE REFERENCE NUMBER
    -- =============================================================================
    
    -- Generate reference number using system function
    v_reference_number := system.generate_reference_number('application');
    
    -- =============================================================================
    -- CREATE INTERACTION RECORD (Layer 1)
    -- =============================================================================
    
    v_applicant_name := TRIM(p_applicant_first_name) || ' ' || TRIM(p_applicant_last_name);
    
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
        v_generic_customer_id,
        v_generic_contact_id,
        v_employee_id,
        'application',
        'pending',
        v_reference_number,
        p_contact_method,
        COALESCE(p_initial_notes, 'New ' || p_application_type || ' application from ' || v_applicant_name || ' (' || p_applicant_email || ')'),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_interaction_id;
    
    -- =============================================================================
    -- CREATE APPLICATION COMPONENT (Layer 2)
    -- =============================================================================
    
    INSERT INTO interactions.component_application_details (
        interaction_id,
        application_type,
        applicant_first_name,
        applicant_last_name,
        applicant_email,
        verification_status,
        documents_required,
        documents_received,
        verification_notes,
        created_at
    ) VALUES (
        v_interaction_id,
        p_application_type,
        TRIM(p_applicant_first_name),
        TRIM(p_applicant_last_name),
        LOWER(TRIM(p_applicant_email)),
        'pending',  -- Initial status
        p_documents_required,
        p_documents_received,
        p_verification_notes,
        CURRENT_TIMESTAMP
    );
    
    -- =============================================================================
    -- CREATE USER TASK FOR HIRE CONTROL (Layer 3)
    -- =============================================================================
    
    -- Build task details
    v_task_title := 'Process ' || INITCAP(p_application_type) || ' Application: ' || v_applicant_name;
    v_task_description := 'Review and process new ' || p_application_type || ' customer application.' || E'\n\n' ||
                          'Applicant: ' || v_applicant_name || E'\n' ||
                          'Email: ' || p_applicant_email || E'\n' ||
                          'Type: ' || INITCAP(p_application_type) || E'\n' ||
                          'Reference: ' || v_reference_number || E'\n\n' ||
                          'Tasks to complete:' || E'\n' ||
                          '- Verify applicant information' || E'\n' ||
                          '- Request required documents' || E'\n' ||
                          '- Review submitted documentation' || E'\n' ||
                          '- Approve or reject application' || E'\n' ||
                          '- Create customer record if approved';
    
    -- Set due date (applications should be processed within 2 business days)
    v_due_date := CURRENT_DATE + INTERVAL '2 days';
    
    -- Create user task
    INSERT INTO tasks.user_taskboard (
        interaction_id,
        task_type,
        title,
        description,
        priority,
        status,
        assigned_to,
        created_by,
        due_date,
        created_at,
        updated_at
    ) VALUES (
        v_interaction_id,
        'process_application',
        v_task_title,
        v_task_description,
        'high',  -- Applications are high priority
        'pending',
        v_hire_control_employee_id,
        v_employee_id,
        v_due_date,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ) RETURNING id INTO v_task_id;
    
    -- =============================================================================
    -- AUDIT LOGGING
    -- =============================================================================
    
    -- Log application creation
    INSERT INTO security.audit_log (
        employee_id,
        action,
        table_name,
        record_id,
        new_values,
        ip_address,
        created_at
    ) VALUES (
        v_employee_id,
        'create_application',
        'interactions',
        v_interaction_id,
        jsonb_build_object(
            'reference_number', v_reference_number,
            'application_type', p_application_type,
            'applicant_name', v_applicant_name,
            'applicant_email', p_applicant_email,
            'assigned_to', v_hire_control_employee_name,
            'created_by_name', v_employee_name
        ),
        inet_client_addr(),
        CURRENT_TIMESTAMP
    );
    
    -- =============================================================================
    -- RETURN SUCCESS
    -- =============================================================================
    
    RETURN QUERY SELECT 
        true,
        ('Application ' || v_reference_number || ' created for ' || v_applicant_name || ' and assigned to ' || v_hire_control_employee_name)::TEXT,
        v_interaction_id,
        v_reference_number,
        v_task_id,
        v_hire_control_employee_name;
        
EXCEPTION 
    WHEN unique_violation THEN
        -- Handle any unique constraint violations
        RETURN QUERY SELECT 
            false, 
            'Duplicate application detected. Please check if this applicant already exists.'::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::TEXT;
            
    WHEN foreign_key_violation THEN
        -- Handle foreign key violations
        RETURN QUERY SELECT 
            false, 
            'Invalid reference data. Please contact system administrator.'::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::TEXT;
            
    WHEN OTHERS THEN
        -- Handle any other errors
        RETURN QUERY SELECT 
            false, 
            ('System error occurred: ' || SQLERRM)::TEXT,
            NULL::INTEGER,
            NULL::VARCHAR(20),
            NULL::INTEGER,
            NULL::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


COMMENT ON FUNCTION interactions.create_application IS 
'Process new customer applications (individual or company).
Uses generic customer (ID 999) and creates application interaction with component details.
Creates high-priority task for hire_control team to process application.
Designed for Flask frontend application processing workflow.';