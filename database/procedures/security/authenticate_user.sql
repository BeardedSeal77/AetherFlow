-- Function to authenticate user and set session context
CREATE OR REPLACE FUNCTION security.authenticate_user(
    username_param VARCHAR(50),
    password_param TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    employee_id INTEGER,
    employee_name TEXT,
    employee_role VARCHAR(50),
    session_token TEXT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    auth_record RECORD;
    new_session_token TEXT;
    policy_record RECORD;
BEGIN
    -- Get password policy
    SELECT * INTO policy_record 
    FROM security.password_policy 
    WHERE is_active = true 
    LIMIT 1;

    -- Get employee authentication record
    SELECT 
        ea.employee_id,
        ea.username,
        ea.password_hash,
        ea.failed_login_attempts,
        ea.locked_until,
        e.name || ' ' || e.surname AS full_name,
        e.role,
        e.status
    INTO auth_record
    FROM security.employee_auth ea
    JOIN core.employees e ON ea.employee_id = e.id
    WHERE ea.username = username_param
      AND e.status = 'active';

    -- Check if user exists
    IF NOT FOUND THEN
        INSERT INTO security.login_attempts (username, success, failure_reason)
        VALUES (username_param, false, 'User not found');

        RETURN QUERY SELECT false, NULL, NULL, NULL, NULL, 'Invalid username or password';
        RETURN;
    END IF;

    -- Check if account is locked
    IF auth_record.locked_until IS NOT NULL AND auth_record.locked_until > CURRENT_TIMESTAMP THEN
        INSERT INTO security.login_attempts (username, success, failure_reason)
        VALUES (username_param, false, 'Account locked');

        RETURN QUERY SELECT false, NULL, NULL, NULL, NULL, 'Account is locked. Please try again later.';
        RETURN;
    END IF;

    -- Verify password
    IF NOT security.verify_password(password_param, auth_record.password_hash) THEN
        UPDATE security.employee_auth
        SET 
            failed_login_attempts = failed_login_attempts + 1,
            locked_until = CASE 
                WHEN failed_login_attempts + 1 >= policy_record.max_failed_attempts 
                THEN CURRENT_TIMESTAMP + (policy_record.lockout_duration_minutes || ' minutes')::INTERVAL
                ELSE NULL
            END
        WHERE employee_id = auth_record.employee_id;

        INSERT INTO security.login_attempts (username, success, failure_reason)
        VALUES (username_param, false, 'Invalid password');

        RETURN QUERY SELECT false, NULL, NULL, NULL, NULL, 'Invalid username or password';
        RETURN;
    END IF;

    -- Generate new session token
    new_session_token := security.generate_token();

    -- Update authentication record
    UPDATE security.employee_auth
    SET 
        failed_login_attempts = 0,
        locked_until = NULL,
        session_token = new_session_token,
        session_expires = CURRENT_TIMESTAMP + INTERVAL '8 hours'
    WHERE employee_id = auth_record.employee_id;

    -- Update last login
    UPDATE core.employees
    SET last_login = CURRENT_TIMESTAMP
    WHERE id = auth_record.employee_id;

    -- Log successful login
    INSERT INTO security.login_attempts (username, success)
    VALUES (username_param, true);

    -- Log audit
    INSERT INTO security.audit_log (employee_id, action, table_name)
    VALUES (auth_record.employee_id, 'login', 'employee_auth');

    RETURN QUERY SELECT 
        true,
        auth_record.employee_id,
        auth_record.full_name,
        auth_record.role,
        new_session_token,
        'Login successful';
END;
$$;