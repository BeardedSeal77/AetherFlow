@echo off
setlocal enabledelayedexpansion

echo ============================================================================
echo Creating Individual Interactions Procedure Files
echo ============================================================================
echo.

:: Check if interactions directory exists
if not exist "database\procedures\interactions\" (
    echo Creating interactions directory...
    mkdir "database\procedures\interactions" 2>nul
)

echo Found/Created interactions directory.
echo.

:: Create backup directory
mkdir "database\procedures\interactions\_backup" 2>nul

:: Get current date for backup
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do (
    set "backup_date=%%c-%%a-%%b"
)

echo Backing up original files (if they exist)...

:: Backup all original files
for %%f in (application.sql breakdown.sql new_hire.sql off_hire.sql price_list.sql quote.sql refund.sql statement.sql) do (
    if exist "database\procedures\interactions\%%f" (
        copy "database\procedures\interactions\%%f" "database\procedures\interactions\_backup\%%~nf_original_%backup_date%.sql" >nul
        echo - Backed up %%f
    )
)

echo.
echo Creating individual procedure files...

:: ===========================
:: APPLICATION.SQL FUNCTIONS
:: ===========================

echo Creating application procedure files...

call :create_file "database\procedures\interactions\create_application.sql" "INTERACTIONS" "Process new customer applications (individual or company)" "core.customers, interactions.component_application_details" "Customer application workflow, account setup" "interactions.create_application"

call :create_file "database\procedures\interactions\update_application_status.sql" "INTERACTIONS" "Update application verification status and add notes" "interactions.component_application_details" "Application processing workflow, status management" "interactions.update_application_status"

:: ===========================
:: BREAKDOWN.SQL FUNCTIONS
:: ===========================

echo Creating breakdown procedure files...

call :create_file "database\procedures\interactions\create_breakdown.sql" "INTERACTIONS" "Process equipment breakdown reports from customers" "interactions.component_breakdown_details, tasks.drivers_taskboard" "Breakdown reporting workflow, emergency repairs" "interactions.create_breakdown"

:: ===========================
:: NEW_HIRE.SQL FUNCTIONS
:: ===========================

echo Creating new_hire procedure files...

call :create_file "database\procedures\interactions\create_hire.sql" "INTERACTIONS" "Process new equipment hire requests" "interactions.component_hire_details, tasks.drivers_taskboard" "Equipment hire workflow, delivery scheduling" "interactions.create_hire"

:: ===========================
:: OFF_HIRE.SQL FUNCTIONS
:: ===========================

echo Creating off_hire procedure files...

call :create_file "database\procedures\interactions\create_off_hire.sql" "INTERACTIONS" "Process equipment off-hire/collection requests" "interactions.component_offhire_details, tasks.drivers_taskboard" "Equipment return workflow, collection scheduling" "interactions.create_off_hire"

:: ===========================
:: PRICE_LIST.SQL FUNCTIONS
:: ===========================

echo Creating price_list procedure files...

call :create_file "database\procedures\interactions\process_price_list_request.sql" "INTERACTIONS" "Process price list requests from customers" "interactions.component_equipment_list, core.equipment_pricing" "Price list workflow, equipment pricing" "interactions.process_price_list_request"

call :create_file "database\procedures\interactions\get_price_list_data.sql" "INTERACTIONS" "Get equipment pricing data for price list generation" "core.equipment_pricing, interactions.component_equipment_list" "Price list generation, pricing display" "interactions.get_price_list_data"

:: ===========================
:: QUOTE.SQL FUNCTIONS
:: ===========================

echo Creating quote procedure files...

call :create_file "database\procedures\interactions\process_quote_request.sql" "INTERACTIONS" "Process quote requests for equipment hire" "interactions.component_quote_totals, core.equipment_pricing" "Quote generation workflow, formal pricing" "interactions.process_quote_request"



:: ===========================
:: REFUND.SQL FUNCTIONS
:: ===========================

echo Creating refund procedure files...

call :create_file "database\procedures\interactions\process_refund_request.sql" "INTERACTIONS" "Process refund requests from customers" "interactions.component_refund_details, tasks.user_taskboard" "Refund processing workflow, accounts management" "interactions.process_refund_request"

:: ===========================
:: STATEMENT.SQL FUNCTIONS
:: ===========================

echo Creating statement procedure files...

call :create_file "database\procedures\interactions\process_statement_request.sql" "INTERACTIONS" "Process account statement requests" "interactions.interactions, tasks.user_taskboard" "Statement generation workflow, account management" "interactions.process_statement_request"

:: Create build script
call :create_build_script

echo.
echo ============================================================================
echo Individual interaction procedure files created successfully!
echo ============================================================================
echo.
echo Created Files:
echo.
echo Application Functions:
echo - create_application.sql (interactions.create_application)
echo - update_application_status.sql (interactions.update_application_status)
echo.
echo Breakdown Functions:
echo - create_breakdown.sql (interactions.create_breakdown)
echo.
echo Hire Functions:
echo - create_hire.sql (interactions.create_hire)
echo.
echo Off-Hire Functions:
echo - create_off_hire.sql (interactions.create_off_hire)
echo.
echo Price List Functions:
echo - process_price_list_request.sql (interactions.process_price_list_request)
echo - get_price_list_data.sql (interactions.get_price_list_data)
echo.
echo Quote Functions:
echo - process_quote_request.sql (interactions.process_quote_request)
echo.
echo Refund Functions:
echo - process_refund_request.sql (interactions.process_refund_request)
echo.
echo Statement Functions:
echo - process_statement_request.sql (interactions.process_statement_request)
echo.
echo Additional:
echo - build_interactions_procedures.sql (master build script)
echo.
echo Next steps:
echo 1. Move each specific function from the original files to the new files
echo 2. Each function is clearly identified by its DROP/CREATE statements
echo 3. Test with the build script
echo.
pause
goto :eof

:: Function to create SQL file with proper header template
:create_file
set "filepath=%~1"
set "schema_name=%~2"
set "description=%~3"
set "dependencies=%~4"
set "used_by=%~5"
set "function_name=%~6"

:: Get current date
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do (
    set "current_date=%%c-%%a-%%b"
)

:: Create the file with complete header template
(
echo -- =============================================================================
echo -- INTERACTIONS: %description%
echo -- =============================================================================
echo -- Purpose: %description%
echo -- Dependencies: %dependencies%
echo -- Used by: %used_by%
echo -- Function: %function_name%
echo -- Created: %current_date%
echo -- =============================================================================
echo.
echo SET search_path TO core, interactions, tasks, security, system, public;
echo.
echo -- Drop existing function if it exists
echo DROP FUNCTION IF EXISTS %function_name%;
echo.
echo -- =============================================================================
echo -- FUNCTION IMPLEMENTATION
echo -- =============================================================================
echo.
echo -- TODO: Move the %function_name% function from the original file here
echo -- Look for this function in the original file and copy it here
echo.
echo -- Example structure:
echo -- CREATE OR REPLACE FUNCTION %function_name%^(
echo --     parameter1 INTEGER,
echo --     parameter2 TEXT DEFAULT NULL
echo -- ^)
echo -- RETURNS TABLE^(
echo --     column1 INTEGER,
echo --     column2 TEXT
echo -- ^) AS $$
echo -- DECLARE
echo --     -- Variables here
echo -- BEGIN
echo --     -- Function logic here
echo -- END;
echo -- $$ LANGUAGE plpgsql SECURITY DEFINER;
echo.
echo -- =============================================================================
echo -- PERMISSIONS ^& COMMENTS
echo -- =============================================================================
echo.
echo -- Grant execute permissions
echo GRANT EXECUTE ON FUNCTION %function_name% TO PUBLIC;
echo -- -- OR more restrictive:
echo -- GRANT EXECUTE ON FUNCTION %function_name% TO hire_control;
echo -- GRANT EXECUTE ON FUNCTION %function_name% TO manager;
echo -- GRANT EXECUTE ON FUNCTION %function_name% TO owner;
echo.
echo -- Add function documentation
echo COMMENT ON FUNCTION %function_name% IS 
echo '%description%. Used by %used_by%.';
echo.
echo -- =============================================================================
echo -- USAGE EXAMPLES
echo -- =============================================================================
echo.
echo /*
echo -- Example usage:
echo -- SELECT * FROM %function_name%^(param1, param2^);
echo.
echo -- Additional examples for this specific function
echo */
) > "%filepath%"

exit /b

:create_build_script
set "filepath=database\procedures\interactions\build_interactions_procedures.sql"

(
echo -- =============================================================================
echo -- BUILD ALL INTERACTIONS PROCEDURES
echo -- =============================================================================
echo -- Purpose: Load all interaction procedures in dependency order
echo -- =============================================================================
echo.
echo \echo 'Loading Interactions Procedures...'
echo.
echo -- =============================================================================
echo -- BASIC INTERACTION FUNCTIONS
echo -- =============================================================================
echo.
echo \echo 'Loading basic interaction functions...'
echo \i database/procedures/interactions/process_price_list_request.sql
echo \i database/procedures/interactions/get_price_list_data.sql
echo \i database/procedures/interactions/process_statement_request.sql
echo.
echo -- =============================================================================
echo -- APPLICATION FUNCTIONS
echo -- =============================================================================
echo.
echo \echo 'Loading application functions...'
echo \i database/procedures/interactions/create_application.sql
echo \i database/procedures/interactions/update_application_status.sql
echo.
echo -- =============================================================================
echo -- EQUIPMENT INTERACTION FUNCTIONS
echo -- =============================================================================
echo.
echo \echo 'Loading equipment interaction functions...'
echo \i database/procedures/interactions/create_hire.sql
echo \i database/procedures/interactions/create_off_hire.sql
echo \i database/procedures/interactions/create_breakdown.sql
echo.
echo -- =============================================================================
echo -- FINANCIAL INTERACTION FUNCTIONS
echo -- =============================================================================
echo.
echo \echo 'Loading financial interaction functions...'
echo \i database/procedures/interactions/process_quote_request.sql
echo \i database/procedures/interactions/process_refund_request.sql
echo.
echo \echo 'Interactions Procedures - COMPLETE!'
echo.
echo -- Verify functions loaded
echo SELECT 'Interaction functions loaded: ' || COUNT^(^*^) as status
echo FROM information_schema.routines 
echo WHERE routine_schema = 'interactions'
echo   AND ^(routine_name LIKE 'create_%%' 
echo        OR routine_name LIKE 'process_%%'
echo        OR routine_name LIKE 'update_%%'
echo        OR routine_name LIKE 'calculate_%%'
echo        OR routine_name LIKE 'get_%%'^);
) > "%filepath%"

exit /b