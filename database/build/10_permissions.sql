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