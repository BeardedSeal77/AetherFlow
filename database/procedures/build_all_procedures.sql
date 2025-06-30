-- =============================================================================
-- BUILD ALL STORED PROCEDURES - EQUIPMENT HIRE MANAGEMENT SYSTEM
-- =============================================================================
-- Purpose: Install all stored procedures and views in correct dependency order
-- Usage: Run this script to install/update all procedures and views
-- =============================================================================

\echo 'Starting Stored Procedures and Views Installation...'
\echo '==================================================='

-- Set search path for all procedures
SET search_path TO core, interactions, tasks, system, public;

-- =============================================================================
-- UTILITY PROCEDURES (No dependencies)
-- =============================================================================

\echo 'Installing utility procedures...'

-- Reference number generation
\i database/procedures/utility/sp_generate_reference_number.sql

-- =============================================================================
-- CUSTOMER SELECTION PROCEDURES
-- =============================================================================

\echo 'Installing customer selection procedures...'

\i database/procedures/customer_selection_procedures/sp_get_customers_for_selection.sql
\i database/procedures/customer_selection_procedures/sp_get_customer_contacts.sql
\i database/procedures/customer_selection_procedures/sp_get_customer_sites.sql

-- =============================================================================
-- EQUIPMENT SELECTION PROCEDURES
-- =============================================================================

\echo 'Installing equipment selection procedures...'

\i database/procedures/equipment_selection_procedures/sp_get_available_equipment_types.sql
\i database/procedures/equipment_selection_procedures/sp_get_available_individual_equipment.sql
\i database/procedures/equipment_selection_procedures/sp_get_equipment_accessories.sql
\i database/procedures/equipment_selection_procedures/sp_calculate_auto_accessories.sql

-- =============================================================================
-- HIRE VALIDATION PROCEDURES
-- =============================================================================

\echo 'Installing hire validation procedures...'

\i database/procedures/hire_validation_procedures/sp_validate_customer_credit.sql
\i database/procedures/hire_validation_procedures/sp_check_equipment_availability.sql
\i database/procedures/hire_validation_procedures/sp_validate_hire_request.sql

-- =============================================================================
-- HIRE CREATION PROCEDURES
-- =============================================================================

\echo 'Installing hire creation procedures...'

\i database/procedures/hire_creation_procedures/sp_create_hire_interaction.sql

-- =============================================================================
-- HIRE DISPLAY PROCEDURES
-- =============================================================================

\echo 'Installing hire display procedures...'

\i database/procedures/hire_display_procedures/sp_get_hire_interaction_details.sql
\i database/procedures/hire_display_procedures/sp_get_hire_equipment_list.sql
\i database/procedures/hire_display_procedures/sp_get_hire_accessories_list.sql

-- =============================================================================
-- EQUIPMENT ALLOCATION PROCEDURES
-- =============================================================================

\echo 'Installing equipment allocation procedures...'

\i database/procedures/equipment_allocation_procedures/sp_get_bookings_for_allocation.sql
\i database/procedures/equipment_allocation_procedures/sp_get_equipment_for_allocation.sql
\i database/procedures/equipment_allocation_procedures/sp_allocate_specific_equipment.sql
\i database/procedures/equipment_allocation_procedures/sp_get_allocation_status.sql

-- =============================================================================
-- QUALITY CONTROL PROCEDURES
-- =============================================================================

\echo 'Installing quality control procedures...'

\i database/procedures/quality_control_procedures/sp_get_equipment_pending_qc.sql
\i database/procedures/quality_control_procedures/sp_quality_control_signoff.sql
\i database/procedures/quality_control_procedures/sp_get_qc_summary.sql

-- =============================================================================
-- DRIVER TASK MANAGEMENT PROCEDURES
-- =============================================================================

\echo 'Installing driver task management procedures...'

\i database/procedures/driver_task_management/sp_get_driver_tasks.sql
\i database/procedures/driver_task_management/sp_update_driver_task_status.sql
\i database/procedures/driver_task_management/sp_get_driver_task_equipment.sql

-- =============================================================================
-- EXTRA UTILITY PROCEDURES
-- =============================================================================

\echo 'Installing extra utility procedures...'

\i database/procedures/extras/sp_calculate_hire_pricing.sql
\i database/procedures/extras/sp_get_hire_list.sql
\i database/procedures/extras/sp_get_interactions_by_date.sql
\i database/procedures/extras/sp_get_interaction_activity_log.sql
\i database/procedures/utility/sp_get_hire_dashboard_summary.sql

-- =============================================================================
-- SAMPLE DATA PROCEDURES (Optional)
-- =============================================================================

\echo 'Installing sample data procedures...'

\i database/procedures/sample/sp_create_sample_hire.sql

-- =============================================================================
-- DATABASE VIEWS (Install after procedures)
-- =============================================================================

\echo 'Installing database views...'
\echo 'Installing equipment-accessories relationship views...'

-- Core equipment-accessories views
\i database/views/core/v_equipment_default_accessories.sql
\i database/views/core/v_equipment_all_accessories.sql
\i database/views/core/v_accessories_with_equipment.sql
\i database/views/core/v_equipment_auto_accessories_summary.sql
\i database/views/core/v_hire_accessories_detailed.sql

\echo '✓ Views installation complete'

-- =============================================================================
-- PERMISSIONS
-- =============================================================================

\echo 'Setting permissions...'

\i database/procedures/permissions.sql

-- Grant SELECT permissions on views to all users
GRANT SELECT ON core.v_equipment_default_accessories TO PUBLIC;
GRANT SELECT ON core.v_equipment_all_accessories TO PUBLIC;
GRANT SELECT ON core.v_accessories_with_equipment TO PUBLIC;
GRANT SELECT ON core.v_equipment_auto_accessories_summary TO PUBLIC;
GRANT SELECT ON interactions.v_hire_accessories_detailed TO PUBLIC;

\echo '✓ View permissions granted'

-- =============================================================================
-- VERIFICATION
-- =============================================================================

\echo 'Verifying installation...'

-- Check procedure counts
SELECT 
    n.nspname as schema_name,
    COUNT(*) as procedure_count
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('core', 'interactions', 'tasks', 'system', 'public')
  AND p.prokind = 'f'  -- Functions only
  AND p.proname LIKE 'sp_%'
GROUP BY n.nspname
ORDER BY n.nspname;

-- Check view counts
\echo 'Checking installed views...'
SELECT 
    schemaname as schema_name,
    COUNT(*) as view_count
FROM pg_views 
WHERE schemaname IN ('core', 'interactions', 'tasks', 'system', 'public')
  AND viewname LIKE 'v_%'
GROUP BY schemaname
ORDER BY schemaname;

-- List all installed procedures
\echo 'Installed Procedures:'
\echo '===================='

SELECT 
    n.nspname as schema,
    p.proname as procedure_name,
    pg_get_function_identity_arguments(p.oid) as parameters
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('core', 'interactions', 'tasks', 'system', 'public')
  AND p.prokind = 'f'
  AND p.proname LIKE 'sp_%'
ORDER BY n.nspname, p.proname;

-- List all installed views
\echo 'Installed Views:'
\echo '================'

SELECT 
    schemaname as schema,
    viewname as view_name,
    definition as view_definition
FROM pg_views 
WHERE schemaname IN ('core', 'interactions', 'tasks', 'system', 'public')
  AND viewname LIKE 'v_%'
ORDER BY schemaname, viewname;

-- =============================================================================
-- TEST BASIC FUNCTIONALITY
-- =============================================================================

\echo 'Running basic functionality tests...'

-- Test reference number generation
SELECT 'Testing reference generation:' as test;
SELECT sp_generate_reference_number('hire') as sample_reference;

-- Test customer selection
SELECT 'Testing customer selection:' as test;
SELECT COUNT(*) as customer_count FROM sp_get_customers_for_selection();

-- Test equipment types
SELECT 'Testing equipment types:' as test;
SELECT COUNT(*) as equipment_type_count FROM sp_get_available_equipment_types();

-- Test views (if sample data exists)
\echo 'Testing views with sample data...'

-- Test equipment accessories view
SELECT 'Testing equipment accessories view:' as test;
SELECT COUNT(*) as accessories_count FROM core.v_equipment_default_accessories;

-- Test accessories summary view
SELECT 'Testing accessories summary view:' as test;
SELECT COUNT(*) as equipment_types_with_accessories FROM core.v_equipment_auto_accessories_summary 
WHERE default_accessories_count > 0;

-- =============================================================================
-- COMPLETION
-- =============================================================================

\echo ''
\echo 'Stored Procedures and Views Installation Complete!'
\echo '=================================================='
\echo ''
\echo 'Summary:'
\echo '- Customer Selection: 3 procedures'
\echo '- Equipment Selection: 4 procedures'  
\echo '- Hire Validation: 3 procedures'
\echo '- Hire Creation: 1 procedure'
\echo '- Hire Display: 3 procedures'
\echo '- Equipment Allocation: 4 procedures'
\echo '- Quality Control: 3 procedures'
\echo '- Driver Task Management: 3 procedures'
\echo '- Extra Utilities: 4 procedures'
\echo '- Sample Data: 1 procedure'
\echo '- Database Views: 5 views'
\echo ''
\echo 'Total: 29 stored procedures + 5 views installed'
\echo ''
\echo 'Views Available:'
\echo '- core.v_equipment_default_accessories'
\echo '- core.v_equipment_all_accessories'
\echo '- core.v_accessories_with_equipment'
\echo '- core.v_equipment_auto_accessories_summary'
\echo '- interactions.v_hire_accessories_detailed'
\echo ''
\echo 'Next Steps:'
\echo '1. Test procedures and views using sample data'
\echo '2. Integrate with Python Flask services'
\echo '3. Build frontend API endpoints'
\echo '4. Run sp_create_sample_hire() to create test data'
\echo ''

-- =============================================================================
-- QUICK START TEST
-- =============================================================================

\echo 'Quick Start Test Available:'
\echo '=========================='
\echo 'Run: SELECT * FROM sp_create_sample_hire();'
\echo 'This will create a complete sample hire interaction for testing'
\echo ''
\echo 'View Examples:'
\echo '- SELECT * FROM core.v_equipment_default_accessories LIMIT 5;'
\echo '- SELECT * FROM core.v_accessories_with_equipment LIMIT 5;'
\echo '- SELECT * FROM core.v_equipment_auto_accessories_summary LIMIT 5;'
\echo ''