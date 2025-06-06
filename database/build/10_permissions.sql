-- =============================================================================
-- STEP 10: ROLE-BASED PERMISSIONS AND SECURITY
-- =============================================================================
-- Purpose: Set up role-based permissions and row-level security
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run TENTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- POPULATE ROLE PERMISSIONS
-- =============================================================================

-- Clear existing permissions
DELETE FROM security.role_permissions;

-- Owner permissions (full access)
INSERT INTO security.role_permissions (role, permission, resource) VALUES
-- Core entities
('owner', 'read', 'employees'),
('owner', 'create', 'employees'),
('owner', 'update', 'employees'),
('owner', 'delete', 'employees'),
('owner', 'read', 'customers'),
('owner', 'create', 'customers'),
('owner', 'update', 'customers'),
('owner', 'delete', 'customers'),
('owner', 'read', 'equipment'),
('owner', 'create', 'equipment'),
('owner', 'update', 'equipment'),
('owner', 'delete', 'equipment'),
-- Interactions
('owner', 'read', 'interactions'),
('owner', 'create', 'interactions'),
('owner', 'update', 'interactions'),
('owner', 'delete', 'interactions'),
-- Tasks
('owner', 'read', 'user_tasks'),
('owner', 'create', 'user_tasks'),
('owner', 'update', 'user_tasks'),
('owner', 'delete', 'user_tasks'),
('owner', 'assign', 'user_tasks'),
('owner', 'read', 'driver_tasks'),
('owner', 'create', 'driver_tasks'),
('owner', 'update', 'driver_tasks'),
('owner', 'delete', 'driver_tasks'),
('owner', 'assign', 'driver_tasks'),
-- Security and admin
('owner', 'read', 'security'),
('owner', 'update', 'security'),
('owner', 'read', 'system_config'),
('owner', 'update', 'system_config'),
('owner', 'read', 'audit_log'),
('owner', 'read', 'reports');

-- Manager permissions (administrative access)
INSERT INTO security.role_permissions (role, permission, resource) VALUES
-- Core entities
('manager', 'read', 'employees'),
('manager', 'create', 'employees'),
('manager', 'update', 'employees'),
('manager', 'read', 'customers'),
('manager', 'create', 'customers'),
('manager', 'update', 'customers'),
('manager', 'read', 'equipment'),
('manager', 'create', 'equipment'),
('manager', 'update', 'equipment'),
-- Interactions
('manager', 'read', 'interactions'),
('manager', 'create', 'interactions'),
('manager', 'update', 'interactions'),
-- Tasks
('manager', 'read', 'user_tasks'),
('manager', 'create', 'user_tasks'),
('manager', 'update', 'user_tasks'),
('manager', 'assign', 'user_tasks'),
('manager', 'read', 'driver_tasks'),
('manager', 'create', 'driver_tasks'),
('manager', 'update', 'driver_tasks'),
('manager', 'assign', 'driver_tasks'),
-- Reports and audit
('manager', 'read', 'audit_log'),
('manager', 'read', 'reports'),
('manager', 'read', 'system_config');

-- Buyer permissions (purchasing and supplier management)
INSERT INTO security.role_permissions (role, permission, resource) VALUES
('buyer', 'read', 'customers'),
('buyer', 'read', 'equipment'),
('buyer', 'update', 'equipment'),
('buyer', 'read', 'interactions'),
('buyer', 'create', 'interactions'),
('buyer', 'update', 'interactions'),
('buyer', 'read', 'user_tasks'),
('buyer', 'update', 'user_tasks'),
('buyer', 'read', 'reports');

-- Accounts permissions (financial operations)
INSERT INTO security.role_permissions (role, permission, resource) VALUES
('accounts', 'read', 'customers'),
('accounts', 'update', 'customers'),
('accounts', 'read', 'interactions'),
('accounts', 'create', 'interactions'),
('accounts', 'update', 'interactions'),
('accounts', 'read', 'user_tasks'),
('accounts', 'update', 'user_tasks'),
('accounts', 'read', 'reports');

-- Hire Controller permissions (customer service and task management)
INSERT INTO security.role_permissions (role, permission, resource) VALUES
('hire_control', 'read', 'customers'),
('hire_control', 'create', 'customers'),
('hire_control', 'update', 'customers'),
('hire_control', 'read', 'equipment'),
('hire_control', 'read', 'interactions'),
('hire_control', 'create', 'interactions'),
('hire_control', 'update', 'interactions'),
('hire_control', 'read', 'user_tasks'),
('hire_control', 'create', 'user_tasks'),
('hire_control', 'update', 'user_tasks'),
('hire_control', 'read', 'driver_tasks'),
('hire_control', 'create', 'driver_tasks'),
('hire_control', 'update', 'driver_tasks'),
('hire_control', 'assign', 'driver_tasks');

-- Driver permissions (field operations)
INSERT INTO security.role_permissions (role, permission, resource) VALUES
('driver', 'read', 'customers'),
('driver', 'read', 'equipment'),
('driver', 'read', 'interactions'),
('driver', 'read', 'driver_tasks'),
('driver', 'update', 'driver_tasks');

-- Mechanic permissions (equipment maintenance)
INSERT INTO security.role_permissions (role, permission, resource) VALUES
('mechanic', 'read', 'equipment'),
('mechanic', 'update', 'equipment'),
('mechanic', 'read', 'interactions'),
('mechanic', 'read', 'driver_tasks'),
('mechanic', 'update', 'driver_tasks');

-- =============================================================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================================================

-- Employee authentication - users can only see their own auth data
CREATE POLICY employee_auth_self_access ON security.employee_auth
    FOR ALL TO PUBLIC
    USING (employee_id = current_setting('app.current_employee_id')::INTEGER)
    WITH CHECK (employee_id = current_setting('app.current_employee_id')::INTEGER);

-- Audit log - users can read audit entries, but owners can see all
CREATE POLICY audit_log_read_policy ON security.audit_log
    FOR SELECT TO PUBLIC
    USING (
        employee_id = current_setting('app.current_employee_id')::INTEGER
        OR current_setting('app.current_employee_role') = 'owner'
        OR current_setting('app.current_employee_role') = 'manager'
    );

-- User tasks - users can see tasks assigned to them, managers can see all
CREATE POLICY user_tasks_access_policy ON tasks.user_taskboard
    FOR ALL TO PUBLIC
    USING (
        assigned_to = current_setting('app.current_employee_id')::INTEGER
        OR current_setting('app.current_employee_role') IN ('owner', 'manager')
        OR current_setting('app.current_employee_role') = 'hire_control'
    );

-- Driver tasks - drivers see their own tasks, others see based on role
CREATE POLICY driver_tasks_access_policy ON tasks.drivers_taskboard
    FOR ALL TO PUBLIC
    USING (
        (assigned_to = current_setting('app.current_employee_id')::INTEGER AND current_setting('app.current_employee_role') = 'driver')
        OR current_setting('app.current_employee_role') IN ('owner', 'manager', 'hire_control')
    );

-- =============================================================================
-- AUTHENTICATION FUNCTIONS
-- =============================================================================

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


-- Function to validate session token
CREATE OR REPLACE FUNCTION security.validate_session(token_param TEXT)
RETURNS TABLE(
    valid BOOLEAN,
    employee_id INTEGER,
    employee_role VARCHAR(50),
    expires_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    session_record RECORD;
BEGIN
    SELECT 
        ea.employee_id,
        ea.session_expires,
        e.role
    INTO session_record
    FROM security.employee_auth ea
    JOIN core.employees e ON ea.employee_id = e.id
    WHERE ea.session_token = token_param
    AND ea.session_expires > CURRENT_TIMESTAMP
    AND e.status = 'active';
    
    IF session_record IS NULL THEN
        RETURN QUERY SELECT false, NULL::INTEGER, NULL::VARCHAR(50), NULL::TIMESTAMP WITH TIME ZONE;
    ELSE
        -- Extend session by 1 hour on valid access
        UPDATE security.employee_auth 
        SET session_expires = CURRENT_TIMESTAMP + '1 hour'::INTERVAL
        WHERE session_token = token_param;
        
        RETURN QUERY SELECT 
            true, 
            session_record.employee_id, 
            session_record.role, 
            session_record.session_expires;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to logout user
CREATE OR REPLACE FUNCTION security.logout_user(token_param TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE security.employee_auth 
    SET 
        session_token = NULL,
        session_expires = NULL
    WHERE session_token = token_param;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SESSION CONTEXT FUNCTIONS
-- =============================================================================

-- Function to set session context (called after authentication)
CREATE OR REPLACE FUNCTION security.set_session_context(employee_id_param INTEGER, role_param VARCHAR(50))
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_employee_id', employee_id_param::TEXT, false);
    PERFORM set_config('app.current_employee_role', role_param, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clear session context
CREATE OR REPLACE FUNCTION security.clear_session_context()
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_employee_id', '', false);
    PERFORM set_config('app.current_employee_role', '', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SECURITY VIEWS FOR APPLICATION USE
-- =============================================================================

-- View for current user context
CREATE VIEW security.current_user_context AS
SELECT 
    current_setting('app.current_employee_id', true)::INTEGER as employee_id,
    current_setting('app.current_employee_role', true) as employee_role,
    e.name || ' ' || e.surname as full_name,
    e.email
FROM core.employees e
WHERE e.id = current_setting('app.current_employee_id', true)::INTEGER;

-- =============================================================================
-- NEXT STEP: Run 11_sample_data.sql
-- =============================================================================