SET search_path TO security, public;

CREATE OR REPLACE FUNCTION security.validate_session(
    p_session_token TEXT
)
RETURNS TABLE(
    employee_id INTEGER
) AS $VALIDATE_SESSION$
DECLARE
    v_employee_record RECORD;
BEGIN
    -- Look up session token in employee_auth table
    SELECT 
        ea.employee_id,
        ea.session_token_expires,
        e.status
    INTO v_employee_record
    FROM security.employee_auth ea
    JOIN core.employees e ON ea.employee_id = e.id
    WHERE ea.session_token = p_session_token;
    
    -- Check if session exists and is valid
    IF v_employee_record IS NULL THEN
        RETURN QUERY SELECT NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Check if session has expired
    IF v_employee_record.session_token_expires < CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Check if employee is still active
    IF v_employee_record.status != 'active' THEN
        RETURN QUERY SELECT NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Return valid employee ID
    RETURN QUERY SELECT v_employee_record.employee_id;
    
END;
$VALIDATE_SESSION$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION security.validate_session IS 
'Validates existing session tokens and returns employee ID if valid.
Checks token existence, expiration, and employee status.';

GRANT EXECUTE ON FUNCTION security.validate_session TO PUBLIC;