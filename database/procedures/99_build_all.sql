-- =============================================================================
-- BUILD ALL STORED PROCEDURES
-- =============================================================================
-- This script builds all stored procedures in the correct order
-- Run this after creating the schema and loading sample data

\echo 'Building Equipment Hire System Stored Procedures...'

-- Set search path
SET search_path TO core, equipment, interactions, tasks, system, public;

-- 1. Utility procedures (dependencies for others)
\echo 'Building utility procedures...'
\i database/procedures/01_utility_procedures.sql

-- 2. Equipment procedures (equipment selection and management)
\echo 'Building equipment procedures...'
\i database/procedures/02_equipment_procedures.sql

-- 3. Hire procedures (hire creation and management)
\echo 'Building hire procedures...'
\i database/procedures/03_hire_procedures.sql

-- 4. Allocation procedures (Phase 2 equipment allocation)
\echo 'Building allocation procedures...'
\i database/procedures/04_allocation_procedures.sql

-- 5. Hire viewing procedures (hire display and viewing functionality)
\echo 'Building hire viewing procedures...'
\i database/procedures/05_hire_viewing_procedures.sql

-- =============================================================================
-- CREATE VIEWS AND FINALIZE
-- =============================================================================

\echo 'Creating database views...'
\i database/procedures/database_views.sql

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

\echo 'Setting up permissions...'

-- Grant execute permissions on all functions to appropriate roles
-- (In a production environment, you would create specific roles)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC;

-- Grant select permissions on views
GRANT SELECT ON ALL TABLES IN SCHEMA equipment TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA interactions TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA tasks TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA system TO PUBLIC;

\echo 'All stored procedures and views created successfully!'

-- =============================================================================
-- TEST THE INSTALLATION
-- =============================================================================

\echo 'Testing installation...'

-- Test reference number generation
SELECT 'Testing reference number generation:' as test;
SELECT sp_generate_reference_number('hire') as sample_reference;

-- Test customer selection
SELECT 'Testing customer selection:' as test;
SELECT COUNT(*) as customer_count FROM sp_get_customers_for_selection();

-- Test equipment types
SELECT 'Testing equipment types:' as test;
SELECT COUNT(*) as equipment_types_count FROM sp_get_available_equipment_types();

-- Test dashboard summary
SELECT 'Testing dashboard summary:' as test;
SELECT * FROM sp_get_hire_dashboard_summary();

\echo 'Installation test completed successfully!'
\echo '==================================================================='
\echo 'Equipment Hire System Database Setup Complete!'
\echo '==================================================================='
\echo 'Next steps:'
\echo '1. Run: SELECT * FROM sp_get_hire_dashboard_summary();'
\echo '2. Create a test hire: Use the web interface or call stored procedures'
\echo '3. Test equipment allocation workflow'
\echo '4. Verify driver taskboard functionality'
\echo '==================================================================='