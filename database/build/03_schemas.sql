-- =============================================================================
-- STEP 03: DATABASE SCHEMAS
-- =============================================================================
-- Purpose: Create logical schemas for organizing database objects
-- Run as: SYSTEM user
-- Database: task_management
-- Order: Must be run THIRD
-- =============================================================================

-- Core business schemas
CREATE SCHEMA IF NOT EXISTS core AUTHORIZATION "SYSTEM";
COMMENT ON SCHEMA core IS 'Core business entities - customers, employees, equipment';

CREATE SCHEMA IF NOT EXISTS interactions AUTHORIZATION "SYSTEM";
COMMENT ON SCHEMA interactions IS 'Customer interactions and components';

CREATE SCHEMA IF NOT EXISTS tasks AUTHORIZATION "SYSTEM";
COMMENT ON SCHEMA tasks IS 'Task management - user taskboard and drivers taskboard';

CREATE SCHEMA IF NOT EXISTS security AUTHORIZATION "SYSTEM";
COMMENT ON SCHEMA security IS 'Security and user management';

CREATE SCHEMA IF NOT EXISTS system AUTHORIZATION "SYSTEM";
COMMENT ON SCHEMA system IS 'System utilities and reference data';

-- Set default schema search path
ALTER DATABASE task_management SET search_path TO core, interactions, tasks, security, system, public;

-- Grant schema usage permissions
GRANT USAGE ON SCHEMA core TO PUBLIC;
GRANT USAGE ON SCHEMA interactions TO PUBLIC;
GRANT USAGE ON SCHEMA tasks TO PUBLIC;
GRANT USAGE ON SCHEMA security TO PUBLIC;
GRANT USAGE ON SCHEMA system TO PUBLIC;

-- Verify schemas created
SELECT 
    schema_name,
    schema_owner,
    'Created' AS status
FROM information_schema.schemata 
WHERE schema_name IN ('core', 'interactions', 'tasks', 'security', 'system')
ORDER BY schema_name;

-- =============================================================================
-- NEXT STEP: Run 04_core_tables.sql
-- =============================================================================