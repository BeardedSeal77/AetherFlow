-- =============================================================================
-- INTERACTIONS: Update application verification status and add notes
-- =============================================================================
-- Purpose: Update application verification status and add notes
-- Dependencies: interactions.component_application_details
-- Used by: Application processing workflow, status management
-- Function: interactions.update_application_status
-- Created: 2025-09-06
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS interactions.update_application_status;

-- =============================================================================
-- FUNCTION IMPLEMENTATION
-- =============================================================================

CREATE OR REPLACE FUNCTION interactions.update_application_status(
    p_interaction_id INTEGER,
    p_verification_status VARCHAR(50),
    p_verification_notes TEXT DEFAULT NULL,
    p_approved_by INTEGER DEFAULT NULL,
    p_employee_id INTEGER DEFAULT NULL,
    p_session_token TEXT DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    reference_number VARCHAR(20),
    new_status VARCHAR(50)
) AS $$
DECLARE
    v_employee_id INTEGER;
    v_employee_name TEXT;
    v_reference_number VARCHAR(20);
    v_applicant_name TEXT;
    v_old_status VARCHAR(50);
BEGIN
    -- Get employee ID from session or parameter
    IF p_session_token IS NOT NULL THEN
        SELECT ea.employee_id INTO v_employee_id
        FROM security.employee_auth ea
        WHERE ea.session_token = p_session_token
        AND ea.session_expires > CURRENT_TIMESTAMP;
    ELSE
        v_employee_id := COALESCE(p_employee_id, 
            NULLIF(current_setting('app.current_employee_id', true), '')::INTEGER);
    END IF;
    
    IF v_employee_id IS NULL THEN
        RETURN QUERY SELECT false, 'Employee authentication required'::TEXT, 
            NULL::VARCHAR(20), NULL::VARCHAR(50);
        RETURN;
    END IF;
    
    -- Get employee and application details
    SELECT e.name || ' ' || e.surname, i.reference_number, ad.verification_status,
           ad.applicant_first_name || ' ' || ad.applicant_last_name
    INTO v_employee_name, v_reference_number, v_old_status, v_applicant_name
    FROM core.employees e
    CROSS JOIN interactions.interactions i
    JOIN interactions.component_application_details ad ON i.id = ad.interaction_id
    WHERE e.id = v_employee_id AND e.status = 'active'
    AND i.id = p_interaction_id AND i.interaction_type = 'application';
    
    IF v_reference_number IS NULL THEN
        RETURN QUERY SELECT false, 'Application not found or employee not authorized'::TEXT, 
            NULL::VARCHAR(20), NULL::VARCHAR(50);
        RETURN;
    END IF;
    
    -- Validate status transition
    IF p_verification_status NOT IN ('pending', 'documents_requested', 'documents_received', 'under_review', 'approved', 'rejected') THEN
        RETURN QUERY SELECT false, 'Invalid verification status'::TEXT, 
            v_reference_number, v_old_status;
        RETURN;
    END IF;
    
    -- Update application details
    UPDATE interactions.component_application_details
    SET 
        verification_status = p_verification_status,
        verification_notes = COALESCE(p_verification_notes, verification_notes),
        approved_by = CASE WHEN p_verification_status IN ('approved', 'rejected') THEN COALESCE(p_approved_by, v_employee_id) ELSE approved_by END,
        approval_date = CASE WHEN p_verification_status IN ('approved', 'rejected') THEN CURRENT_TIMESTAMP ELSE approval_date END
    WHERE interaction_id = p_interaction_id;
    
    -- Update interaction status if approved/rejected
    IF p_verification_status = 'approved' THEN
        UPDATE interactions.interactions
        SET status = 'completed', completed_at = CURRENT_TIMESTAMP
        WHERE id = p_interaction_id;
    ELSIF p_verification_status = 'rejected' THEN
        UPDATE interactions.interactions
        SET status = 'cancelled', completed_at = CURRENT_TIMESTAMP
        WHERE id = p_interaction_id;
    ELSE
        UPDATE interactions.interactions
        SET status = 'in_progress'
        WHERE id = p_interaction_id;
    END IF;
    
    -- Log status change
    INSERT INTO security.audit_log (
        employee_id, action, table_name, record_id,
        old_values, new_values, created_at
    ) VALUES (
        v_employee_id, 'update_application_status', 'component_application_details', p_interaction_id,
        jsonb_build_object('old_status', v_old_status),
        jsonb_build_object('new_status', p_verification_status, 'updated_by', v_employee_name),
        CURRENT_TIMESTAMP
    );
    
    RETURN QUERY SELECT 
        true,
        ('Application ' || v_reference_number || ' status updated to ' || p_verification_status || ' for ' || v_applicant_name)::TEXT,
        v_reference_number,
        p_verification_status;
        
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        false, 
        ('Error updating application: ' || SQLERRM)::TEXT,
        v_reference_number,
        v_old_status;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERMISSIONS & COMMENTS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION interactions.update_application_status TO PUBLIC;
-- -- OR more restrictive:
-- GRANT EXECUTE ON FUNCTION interactions.update_application_status TO hire_control;
-- GRANT EXECUTE ON FUNCTION interactions.update_application_status TO manager;
-- GRANT EXECUTE ON FUNCTION interactions.update_application_status TO owner;

-- Add function documentation
COMMENT ON FUNCTION interactions.update_application_status IS
'Update application verification status and add notes.
Handles status transitions and automatically updates interaction status when approved/rejected.
Provides audit trail for application processing workflow.';

-- =============================================================================
-- USAGE EXAMPLES
-- =============================================================================

/*
-- Example usage:
-- SELECT * FROM interactions.update_application_status(param1, param2);

-- Additional examples for this specific function
*/
