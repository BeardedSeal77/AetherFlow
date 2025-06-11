-- =============================================================================
-- STEP 14: FINAL SETUP AND VALIDATION
-- =============================================================================
-- Purpose: Final setup, validation, and system readiness checks
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run LAST (FOURTEENTH)
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- CREATE DEFAULT SYSTEM USER
-- =============================================================================

-- Create default system owner if it doesn't exist
DO $$
BEGIN
    -- Check if system owner exists
    IF NOT EXISTS (SELECT 1 FROM core.employees WHERE id = 1) THEN
        -- Insert default system owner
        INSERT INTO core.employees (id, employee_code, name, surname, role, email, phone_number, hire_date, status) 
        VALUES (1, 'SYS001', 'System', 'Administrator', 'owner', 'admin@system.local', '+27000000000', CURRENT_DATE, 'active');
        
        -- Create authentication for system owner (password: "admin123")
        INSERT INTO security.employee_auth (employee_id, username, password_hash, password_salt)
        SELECT 1, 'SYS001', result.hash, result.salt_used
        FROM security.hash_password('admin123') as result;
    END IF;
END $$;

-- =============================================================================
-- INITIAL SYSTEM CONFIGURATION
-- =============================================================================

-- Update system configuration with installation details
INSERT INTO system.system_config (config_key, config_value, config_type, description) VALUES
('installation_date', CURRENT_TIMESTAMP::TEXT, 'string', 'Database installation timestamp'),
('version', '1.0.0', 'string', 'System version'),
('database_name', 'task_management', 'string', 'Database name'),
('environment', 'development', 'string', 'Environment type'),
('auto_backup_enabled', 'true', 'boolean', 'Automatic backup enabled flag'),
('max_concurrent_users', '50', 'number', 'Maximum concurrent users allowed')
ON CONFLICT (config_key) DO UPDATE SET 
    config_value = EXCLUDED.config_value,
    updated_at = CURRENT_TIMESTAMP;

-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Validate database structure
DO $$
DECLARE
    table_count INTEGER;
    function_count INTEGER;
    view_count INTEGER;
    index_count INTEGER;
BEGIN
    -- Count tables
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema IN ('core', 'interactions', 'tasks', 'security', 'system');
    
    -- Count functions
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines 
    WHERE routine_schema IN ('core', 'interactions', 'tasks', 'security', 'system');
    
    -- Count views
    SELECT COUNT(*) INTO view_count
    FROM information_schema.views 
    WHERE table_schema IN ('core', 'interactions', 'tasks', 'security', 'system');
    
    -- Count indexes
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes 
    WHERE schemaname IN ('core', 'interactions', 'tasks', 'security', 'system');
    
    RAISE NOTICE 'Database Structure Summary:';
    RAISE NOTICE '- Tables: %', table_count;
    RAISE NOTICE '- Functions: %', function_count;
    RAISE NOTICE '- Views: %', view_count;
    RAISE NOTICE '- Indexes: %', index_count;
    
    -- Validate minimum structure
    IF table_count < 15 THEN
        RAISE EXCEPTION 'Insufficient tables created. Expected at least 15, found %', table_count;
    END IF;
    
    IF function_count < 10 THEN
        RAISE EXCEPTION 'Insufficient functions created. Expected at least 10, found %', function_count;
    END IF;
    
    RAISE NOTICE 'Database structure validation: PASSED';
END $$;

-- =============================================================================
-- SAMPLE DATA VALIDATION
-- =============================================================================

-- Test sample data
DO $$
DECLARE
    employee_count INTEGER;
    customer_count INTEGER;
    equipment_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO employee_count FROM core.employees WHERE status = 'active';
    SELECT COUNT(*) INTO customer_count FROM core.customers WHERE status = 'active';
    SELECT COUNT(*) INTO equipment_count FROM core.equipment_categories WHERE is_active = true;
    
    RAISE NOTICE 'Sample Data Summary:';
    RAISE NOTICE '- Active Employees: %', employee_count;
    RAISE NOTICE '- Active Customers: %', customer_count;
    RAISE NOTICE '- Equipment Categories: %', equipment_count;
    
    IF employee_count = 0 THEN
        RAISE EXCEPTION 'No active employees found. Sample data may not have loaded correctly.';
    END IF;
    
    RAISE NOTICE 'Sample data validation: PASSED';
END $$;

-- =============================================================================
-- PERFORMANCE VALIDATION
-- =============================================================================

-- Test critical query performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    duration_ms INTEGER;
BEGIN
    -- Test dashboard overview query
    start_time := clock_timestamp();
    PERFORM * FROM system.dashboard_overview;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM (end_time - start_time));
    
    RAISE NOTICE 'Dashboard query performance: % ms', duration_ms;
    
    IF duration_ms > 1000 THEN
        RAISE WARNING 'Dashboard query is slow (% ms). Consider optimizing indexes.', duration_ms;
    END IF;
    
    -- Test employee workload query
    start_time := clock_timestamp();
    PERFORM * FROM system.employee_workload;
    end_time := clock_timestamp();
    duration_ms := EXTRACT(MILLISECONDS FROM (end_time - start_time));
    
    RAISE NOTICE 'Employee workload query performance: % ms', duration_ms;
    
    RAISE NOTICE 'Performance validation: COMPLETED';
END $$;

-- =============================================================================
-- CREATE MAINTENANCE SCHEDULE
-- =============================================================================

-- Note: In production, these should be run as scheduled jobs
-- Example maintenance tasks:

-- Daily maintenance task comments
-- COMMENT: Run daily at 2 AM: SELECT security.cleanup_expired_sessions();
-- COMMENT: Run daily at 3 AM: VACUUM ANALYZE;

-- Weekly maintenance task comments  
-- COMMENT: Run weekly: REINDEX DATABASE task_management;
-- COMMENT: Run weekly: SELECT security.archive_old_audit_logs(365);

-- Monthly maintenance task comments
-- COMMENT: Run monthly: VACUUM FULL; (during maintenance window)
-- COMMENT: Run monthly: pg_dump for backup

-- =============================================================================
-- FINAL SYSTEM STATUS
-- =============================================================================

-- Display final system status
DO $$
DECLARE
    system_status TEXT;
BEGIN
    -- Set system as ready
    PERFORM system.set_config('system_status', 'ready', 'string');
    PERFORM system.set_config('maintenance_mode', 'false', 'boolean');
    
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'TASK MANAGEMENT SYSTEM - DATABASE SETUP COMPLETE';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Installation Date: %', CURRENT_TIMESTAMP;
    RAISE NOTICE 'Database: task_management';
    RAISE NOTICE 'Version: 1.0.0';
    RAISE NOTICE 'Status: READY FOR USE';
    RAISE NOTICE '';
    RAISE NOTICE 'Default Login Credentials:';
    RAISE NOTICE 'Username: SYS001';
    RAISE NOTICE 'Password: admin123';
    RAISE NOTICE 'Role: owner';
    RAISE NOTICE '';
    RAISE NOTICE 'Important Security Notes:';
    RAISE NOTICE '1. Change the default admin password immediately';
    RAISE NOTICE '2. Create proper employee accounts for your team';
    RAISE NOTICE '3. Review and customize role permissions as needed';
    RAISE NOTICE '4. Set up regular database backups';
    RAISE NOTICE '5. Configure SSL/TLS for production use';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Connect your application to the database';
    RAISE NOTICE '2. Test all functionality with sample data';
    RAISE NOTICE '3. Import your real customer and equipment data';
    RAISE NOTICE '4. Configure scheduled maintenance tasks';
    RAISE NOTICE '5. Set up monitoring and alerting';
    RAISE NOTICE '';
    RAISE NOTICE 'Documentation:';
    RAISE NOTICE '- API Functions: Use the functions in schemas core, interactions, tasks';
    RAISE NOTICE '- Monitoring: Query views in system schema';
    RAISE NOTICE '- Security: Functions in security schema';
    RAISE NOTICE '- Sample Queries: Check database/monitor/ folder';
    RAISE NOTICE '=============================================================================';
END $$;

-- =============================================================================
-- SETUP COMPLETE
-- =============================================================================

-- Final validation that everything is working
SELECT 
    'SETUP COMPLETE' as status,
    CURRENT_TIMESTAMP as completion_time,
    (SELECT COUNT(*) FROM core.employees WHERE status = 'active') as active_employees,
    (SELECT COUNT(*) FROM core.customers WHERE status = 'active') as active_customers,
    (SELECT COUNT(*) FROM core.equipment_categories WHERE is_active = true) as equipment_categories,
    (SELECT system.get_config('system_status')) as system_status;