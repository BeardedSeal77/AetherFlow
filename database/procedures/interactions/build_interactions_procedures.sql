-- =============================================================================
-- BUILD ALL INTERACTIONS PROCEDURES
-- =============================================================================
-- Purpose: Load all interaction procedures in dependency order
-- =============================================================================

\echo 'Loading Interactions Procedures...'

-- =============================================================================
-- BASIC INTERACTION FUNCTIONS
-- =============================================================================

\echo 'Loading basic interaction functions...'
\i database/procedures/interactions/process_price_list_request.sql
\i database/procedures/interactions/get_price_list_data.sql
\i database/procedures/interactions/process_statement_request.sql

-- =============================================================================
-- APPLICATION FUNCTIONS
-- =============================================================================

\echo 'Loading application functions...'
\i database/procedures/interactions/create_application.sql
\i database/procedures/interactions/update_application_status.sql

-- =============================================================================
-- EQUIPMENT INTERACTION FUNCTIONS
-- =============================================================================

\echo 'Loading equipment interaction functions...'
\i database/procedures/interactions/create_hire.sql
\i database/procedures/interactions/create_off_hire.sql
\i database/procedures/interactions/create_breakdown.sql

-- =============================================================================
-- FINANCIAL INTERACTION FUNCTIONS
-- =============================================================================

\echo 'Loading financial interaction functions...'
\i database/procedures/interactions/process_quote_request.sql
\i database/procedures/interactions/process_refund_request.sql

\echo 'Interactions Procedures - COMPLETE'

-- Verify functions loaded
SELECT 'Interaction functions loaded: ' 
FROM information_schema.routines 
WHERE routine_schema = 'interactions'
  AND (routine_name LIKE 'create_%' 
       OR routine_name LIKE 'process_%'
       OR routine_name LIKE 'update_%'
       OR routine_name LIKE 'calculate_%'
       OR routine_name LIKE 'get_%');
