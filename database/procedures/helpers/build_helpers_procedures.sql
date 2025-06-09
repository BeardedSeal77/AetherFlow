-- =============================================================================
-- BUILD ALL HELPER PROCEDURES
-- =============================================================================
-- Purpose: Load all helper procedures in dependency order
-- =============================================================================

\echo 'Loading Helper Procedures...'

-- =============================================================================
-- EQUIPMENT & SITE HELPERS
-- =============================================================================

\echo 'Loading equipment and site helpers...'
\i database/procedures/helpers/get_equipment_details.sql
\i database/procedures/helpers/get_customer_sites.sql
\i database/procedures/helpers/get_customer_equipment_history.sql
\i database/procedures/helpers/get_customer_equipment_by_site.sql
\i database/procedures/helpers/search_equipment_for_breakdown.sql

-- =============================================================================
-- HIRE CALCULATION HELPERS
-- =============================================================================

\echo 'Loading hire calculation helpers...'
\i database/procedures/helpers/calculate_hire_costs.sql
\i database/procedures/helpers/check_customer_credit.sql
\i database/procedures/helpers/check_equipment_availability.sql
\i database/procedures/helpers/get_hire_totals.sql

\echo 'Helper Procedures - COMPLETE'

-- Verify functions loaded
SELECT 'Helper functions loaded: ' 
FROM information_schema.routines 
WHERE routine_schema IN ('core', 'interactions')
  AND (routine_name LIKE 'get_customer%' 
       OR routine_name LIKE 'search_equipment%'
       OR routine_name LIKE 'calculate_hire%'
       OR routine_name LIKE 'check_%'
       OR routine_name LIKE 'get_hire%'
       OR routine_name LIKE 'get_equipment%');
