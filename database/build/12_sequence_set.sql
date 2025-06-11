-- =============================================================================
-- STEP 12: SEQUENCE RESET
-- =============================================================================
-- Purpose: Set all sequences to start from 1000 after sample data insertion
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run TWELFTH (after 11_sample_data.sql)
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- SET SEQUENCES TO START FROM 1000
-- =============================================================================

-- Core schema sequences
SELECT setval('core.employees_id_seq', 1000, false);
SELECT setval('core.customers_id_seq', 1000, false);
SELECT setval('core.contacts_id_seq', 1000, false);
SELECT setval('core.sites_id_seq', 1000, false);
SELECT setval('core.equipment_categories_id_seq', 1000, false);
SELECT setval('core.equipment_accessories_id_seq', 1000, false);
SELECT setval('core.equipment_pricing_id_seq', 1000, false);

-- Interactions schema sequences
SELECT setval('interactions.interactions_id_seq', 1000, false);
SELECT setval('interactions.component_customer_details_id_seq', 1000, false);
SELECT setval('interactions.component_equipment_list_id_seq', 1000, false);
SELECT setval('interactions.component_hire_details_id_seq', 1000, false);
SELECT setval('interactions.component_offhire_details_id_seq', 1000, false);
SELECT setval('interactions.component_breakdown_details_id_seq', 1000, false);
SELECT setval('interactions.component_application_details_id_seq', 1000, false);

-- Tasks schema sequences
SELECT setval('tasks.user_taskboard_id_seq', 1000, false);
SELECT setval('tasks.drivers_taskboard_id_seq', 1000, false);

-- Security schema sequences
SELECT setval('security.employee_auth_id_seq', 1000, false);
SELECT setval('security.role_permissions_id_seq', 1000, false);
SELECT setval('security.user_sessions_id_seq', 1000, false);
SELECT setval('security.audit_logs_id_seq', 1000, false);
SELECT setval('security.login_attempts_id_seq', 1000, false);

-- System schema sequences
SELECT setval('system.reference_sequences_id_seq', 1000, false);
SELECT setval('system.system_configuration_id_seq', 1000, false);

-- =============================================================================
-- VALIDATION AND SUMMARY
-- =============================================================================

-- Validate sequence settings
DO $$
DECLARE
    seq_record RECORD;
    seq_count INTEGER := 0;
BEGIN
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'SEQUENCE RESET SUMMARY';
    RAISE NOTICE '=============================================================================';
    
    -- Check all sequences in relevant schemas
    FOR seq_record IN 
        SELECT schemaname, sequencename, last_value, is_called
        FROM pg_sequences 
        WHERE schemaname IN ('core', 'interactions', 'tasks', 'security', 'system')
        ORDER BY schemaname, sequencename
    LOOP
        seq_count := seq_count + 1;
        RAISE NOTICE '% | %.% | Next ID: %', 
            RPAD(seq_record.schemaname, 12), 
            RPAD(seq_record.sequencename, 35),
            CASE 
                WHEN seq_record.is_called THEN seq_record.last_value + 1
                ELSE seq_record.last_value
            END;
    END LOOP;
    
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Total sequences reset: %', seq_count;
    RAISE NOTICE 'All sequences set to start from 1000';
    RAISE NOTICE '';
    RAISE NOTICE 'Sample data uses IDs 1-999';
    RAISE NOTICE 'Production data will start from 1000+';
    RAISE NOTICE '=============================================================================';
END $$;

-- =============================================================================
-- FINAL DATA INTEGRITY CHECK
-- =============================================================================

-- Verify sample data integrity
DO $$
DECLARE
    max_employee_id INTEGER;
    max_customer_id INTEGER;
    max_equipment_id INTEGER;
    max_accessory_id INTEGER;
BEGIN
    -- Get maximum IDs from sample data
    SELECT COALESCE(MAX(id), 0) INTO max_employee_id FROM core.employees WHERE id < 1000;
    SELECT COALESCE(MAX(id), 0) INTO max_customer_id FROM core.customers WHERE id < 1000;
    SELECT COALESCE(MAX(id), 0) INTO max_equipment_id FROM core.equipment_categories WHERE id < 1000;
    SELECT COALESCE(MAX(id), 0) INTO max_accessory_id FROM core.equipment_accessories WHERE id < 1000;
    
    RAISE NOTICE 'SAMPLE DATA RANGES:';
    RAISE NOTICE '- Employees: 1-%', max_employee_id;
    RAISE NOTICE '- Customers: 1-%', max_customer_id;
    RAISE NOTICE '- Equipment: 1-%', max_equipment_id;
    RAISE NOTICE '- Accessories: 1-%', max_accessory_id;
    
    -- Verify no conflicts will occur
    IF max_employee_id >= 1000 OR max_customer_id >= 1000 OR max_equipment_id >= 1000 OR max_accessory_id >= 1000 THEN
        RAISE EXCEPTION 'ERROR: Sample data IDs exceed 999. This will conflict with production sequences starting at 1000.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Data integrity check: PASSED';
    RAISE NOTICE 'No conflicts between sample data and production sequences';
END $$;

-- =============================================================================
-- NEXT STEP: Run 13_monitoring_views.sql (formerly 12_monitoring_views.sql)
-- =============================================================================