-- =============================================================================
-- CUSTOMER MANAGEMENT: BUILD ALL PROCEDURES
-- =============================================================================
-- Purpose: Load all customer management procedures in dependency order
-- Run this script to recreate all customer management functions
-- =============================================================================

\echo 'Loading Customer Management Procedures...'

-- =============================================================================
-- 1. VALIDATION AND HELPER FUNCTIONS FIRST
-- =============================================================================

\echo '1. Loading validation helpers...'
\i database/procedures/customer_management/customer_validation.sql

-- =============================================================================  
-- 2. BASIC LOOKUP FUNCTIONS
-- =============================================================================

\echo '2. Loading lookup functions...'
\i database/procedures/customer_management/customer_lookup.sql
\i database/procedures/customer_management/contact_lookup_by_customer.sql

-- =============================================================================
-- 3. SEARCH FUNCTIONS
-- =============================================================================

\echo '3. Loading search functions...'
\i database/procedures/customer_management/customer_search.sql
\i database/procedures/customer_management/contact_search.sql
\i database/procedures/customer_management/contact_duplicate_detection.sql

-- =============================================================================
-- 4. CREATION FUNCTIONS
-- =============================================================================

\echo '4. Loading creation functions...'
\i database/procedures/customer_management/contact_create.sql
\i database/procedures/customer_management/customer_create_with_contact.sql
\i database/procedures/customer_management/customer_create.sql
\i database/procedures/customer_management/site_management.sql

-- =============================================================================
-- 5. UPDATE FUNCTIONS
-- =============================================================================

\echo '5. Loading update functions...'
\i database/procedures/customer_management/contact_update.sql
\i database/procedures/customer_management/customer_update.sql
\i database/procedures/customer_management/customer_status_update.sql

-- =============================================================================
-- VERIFICATION
-- =============================================================================

\echo 'Verifying customer management functions...'

DO $$
DECLARE
    function_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO function_count
    FROM information_schema.routines 
    WHERE routine_schema = 'core'
        AND routine_name LIKE '%customer%' 
        OR routine_name LIKE '%contact%';
ECHO is off.
    RAISE NOTICE 'Customer Management Functions Loaded: %', function_count;
ECHO is off.
    IF function_count < 10 THEN
        RAISE WARNING 'Expected at least 10 customer management functions, found %', function_count;
    ELSE
        RAISE NOTICE 'Customer management procedures loaded successfully';
    END IF;
END $$;

\echo 'Customer Management Procedures - COMPLETE'
