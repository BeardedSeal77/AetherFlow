-- =============================================================================
-- STEP 05: SECURITY AND USER MANAGEMENT TABLES
-- =============================================================================
-- Purpose: Create security tables for user authentication and authorization
-- Run as: SYSTEM user
-- Database: task_management
-- Order: Must be run FIFTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- EMPLOYEE AUTHENTICATION TABLE
-- =============================================================================
CREATE TABLE security.employee_auth (
    employee_id INTEGER PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    password_reset_token TEXT,
    password_reset_expires TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    last_password_change TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_token TEXT,
    session_expires TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES core.employees(id) ON DELETE CASCADE
);

COMMENT ON TABLE security.employee_auth IS 'Employee authentication data - encrypted passwords and session management';
COMMENT ON COLUMN security.employee_auth.password_hash IS 'Bcrypt hash of password';
COMMENT ON COLUMN security.employee_auth.password_salt IS 'Salt used for password hashing';

-- =============================================================================
-- ROLE PERMISSIONS TABLE
-- =============================================================================
CREATE TABLE security.role_permissions (
    id SERIAL PRIMARY KEY,
    role VARCHAR(50) NOT NULL,
    permission VARCHAR(100) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role, permission, resource)
);

COMMENT ON TABLE security.role_permissions IS 'Role-based permissions matrix';

-- =============================================================================
-- AUDIT LOG TABLE
-- =============================================================================
CREATE TABLE security.audit_log (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER,
    action VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id INTEGER,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employee_id) REFERENCES core.employees(id)
);

COMMENT ON TABLE security.audit_log IS 'Audit trail for all system changes';

-- =============================================================================
-- LOGIN ATTEMPTS TABLE
-- =============================================================================
CREATE TABLE security.login_attempts (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50),
    ip_address INET,
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE security.login_attempts IS 'Track all login attempts for security monitoring';

-- =============================================================================
-- PASSWORD POLICY TABLE
-- =============================================================================
CREATE TABLE security.password_policy (
    id SERIAL PRIMARY KEY,
    min_length INTEGER NOT NULL DEFAULT 8,
    require_uppercase BOOLEAN NOT NULL DEFAULT true,
    require_lowercase BOOLEAN NOT NULL DEFAULT true,
    require_numbers BOOLEAN NOT NULL DEFAULT true,
    require_special_chars BOOLEAN NOT NULL DEFAULT true,
    password_expiry_days INTEGER NOT NULL DEFAULT 90,
    max_failed_attempts INTEGER NOT NULL DEFAULT 5,
    lockout_duration_minutes INTEGER NOT NULL DEFAULT 30,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE security.password_policy IS 'Password policy configuration';

-- Insert default password policy
INSERT INTO security.password_policy (
    min_length, require_uppercase, require_lowercase, require_numbers, 
    require_special_chars, password_expiry_days, max_failed_attempts, 
    lockout_duration_minutes, is_active
) VALUES (
    8, true, true, true, false, 90, 5, 30, true
);

-- =============================================================================
-- SECURITY FUNCTIONS
-- =============================================================================

-- Function to hash passwords
CREATE OR REPLACE FUNCTION security.hash_password(password TEXT, salt TEXT DEFAULT NULL)
RETURNS TABLE(hash TEXT, salt_used TEXT) AS $$
DECLARE
    password_salt TEXT;
BEGIN
    -- Generate salt if not provided
    IF salt IS NULL THEN
        password_salt := gen_salt('bf', 12);
    ELSE
        password_salt := salt;
    END IF;
    
    -- Return hash and salt
    RETURN QUERY SELECT crypt(password, password_salt), password_salt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify passwords
CREATE OR REPLACE FUNCTION security.verify_password(password TEXT, hash TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN crypt(password, hash) = hash;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate secure tokens
CREATE OR REPLACE FUNCTION security.generate_token()
RETURNS TEXT AS $$
BEGIN
    RETURN encode(gen_random_bytes(32), 'hex');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check role permissions
CREATE OR REPLACE FUNCTION security.has_permission(
    user_role VARCHAR(50), 
    permission_name VARCHAR(100), 
    resource_name VARCHAR(100)
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM security.role_permissions 
        WHERE role = user_role 
        AND permission = permission_name 
        AND resource = resource_name 
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- ROW LEVEL SECURITY POLICIES (will be defined later)
-- =============================================================================

-- Enable RLS on sensitive tables
ALTER TABLE security.employee_auth ENABLE ROW LEVEL SECURITY;
ALTER TABLE security.audit_log ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- NEXT STEP: Run 06_interactions_tables.sql
-- =============================================================================