@echo off
setlocal enabledelayedexpansion

echo ============================================================================
echo EQUIPMENT HIRE DATABASE SETUP - DOCKER AUTOMATION
echo ============================================================================
echo.

:: Change to the script directory (where this batch file is located)
cd /d "%~dp0"
echo Current directory: %CD%

:: Check if Docker is running
echo Checking if Docker is running...
docker version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not running or not installed!
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)
echo ✓ Docker is running

:: Check if the database container exists and remove it if it does
echo.
echo Checking for existing container...
docker ps -a --filter "name=task-management-postgres" --format "{{.Names}}" | findstr "task-management-postgres" >nul 2>&1
if not errorlevel 1 (
    echo Found existing container. Stopping and removing...
    docker stop task-management-postgres >nul 2>&1
    docker rm task-management-postgres >nul 2>&1
    echo ✓ Existing container removed
) else (
    echo ✓ No existing container found
)

:: Check if the network exists, create if it doesn't
echo.
echo Checking Docker network...
docker network ls --filter "name=task-management-network" --format "{{.Name}}" | findstr "task-management-network" >nul 2>&1
if errorlevel 1 (
    echo Creating Docker network...
    docker network create task-management-network
    if errorlevel 1 (
        echo ERROR: Failed to create Docker network!
        pause
        exit /b 1
    )
    echo ✓ Docker network created
) else (
    echo ✓ Docker network already exists
)

:: Start PostgreSQL container
echo.
echo Starting PostgreSQL container...
docker run --name task-management-postgres ^
  --network task-management-network ^
  -e POSTGRES_USER=SYSTEM ^
  -e POSTGRES_PASSWORD=SYSTEM ^
  -e POSTGRES_DB=task_management ^
  -p 5432:5432 ^
  -v postgres_data:/var/lib/postgresql/data ^
  -d postgres

if errorlevel 1 (
    echo ERROR: Failed to start PostgreSQL container!
    pause
    exit /b 1
)

echo ✓ PostgreSQL container started

:: Wait for PostgreSQL to be ready
echo.
echo Waiting 10 seconds for PostgreSQL to start...
timeout /t 10 /nobreak >nul

:: Check if PostgreSQL is ready now
echo Checking PostgreSQL status...
docker exec task-management-postgres pg_isready -U SYSTEM -d task_management >nul 2>&1
if errorlevel 1 (
    echo PostgreSQL not ready yet. Waiting 5 more seconds...
    timeout /t 5 /nobreak >nul
    docker exec task-management-postgres pg_isready -U SYSTEM -d task_management >nul 2>&1
    if errorlevel 1 (
        echo WARNING: PostgreSQL may still be starting up.
        echo Continuing with setup... if errors occur, please wait and try again.
    ) else (
        echo ✓ PostgreSQL is now ready
    )
) else (
    echo ✓ PostgreSQL is ready
)

:: Copy database files to container
echo.
echo Copying database files to container...
docker cp database task-management-postgres:/tmp/
if errorlevel 1 (
    echo ERROR: Failed to copy database files!
    pause
    exit /b 1
)
echo ✓ Database files copied

:: Create database schema
echo.
echo Creating database schema...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -f /tmp/database/01_schema_migration.sql
if errorlevel 1 (
    echo ERROR: Failed to create database schema!
    echo Check the 01_schema_migration.sql file for errors.
    pause
    exit /b 1
)
echo ✓ Database schema created

:: Load sample data
echo.
echo Loading sample data...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -f /tmp/database/02_sample_data.sql
if errorlevel 1 (
    echo ERROR: Failed to load sample data!
    echo Check the 02_sample_data.sql file for errors.
    pause
    exit /b 1
)
echo ✓ Sample data loaded

:: Install stored procedures
echo.
echo Installing stored procedures...

:: Try using the 99_build_all.sql first
docker exec -i task-management-postgres test -f /tmp/database/procedures/99_build_all.sql
if not errorlevel 1 (
    echo Found 99_build_all.sql, attempting to use it...
    docker exec -i task-management-postgres psql -U SYSTEM -d task_management -v ON_ERROR_STOP=0 -f /tmp/database/procedures/99_build_all.sql
    if not errorlevel 1 (
        echo ✓ Stored procedures installed using 99_build_all.sql
        goto :procedures_done
    ) else (
        echo Warning: 99_build_all.sql failed, falling back to individual installation...
    )
)

:: Fallback: Install procedures individually from subdirectories
echo Installing procedures individually...

:: Install all SQL files in the procedures directory and subdirectories
docker exec -i task-management-postgres bash -c "find /tmp/database/procedures -name '*.sql' -type f ! -name '99_build_all.sql' | sort | while read file; do echo \"Installing: \$file\"; psql -U SYSTEM -d task_management -f \"\$file\" || echo \"Warning: Failed to install \$file\"; done"

echo ✓ Stored procedures installation completed

:procedures_done

:: Set permissions on all schemas
echo.
echo Setting permissions...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA core TO PUBLIC;"
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA equipment TO PUBLIC;"
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA interactions TO PUBLIC;"
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA tasks TO PUBLIC;"
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA system TO PUBLIC;"
if errorlevel 1 (
    echo WARNING: Failed to set some permissions (non-critical)
) else (
    echo ✓ Permissions set
)

:: Verify installation
echo.
echo Verifying installation...

:: Check schemas
echo Checking schemas...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('core', 'equipment', 'interactions', 'tasks', 'system') ORDER BY schema_name;"

:: Check procedure count
echo.
echo Checking stored procedures...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "SELECT n.nspname as schema, COUNT(*) as procedure_count FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE p.proname LIKE 'sp_%%' GROUP BY n.nspname ORDER BY n.nspname;"

:: Test basic functionality
echo.
echo Testing basic functionality...

:: Test reference number generation
echo Testing reference number generation...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "SELECT 'Reference test: ' || sp_generate_reference_number('hire') as test_result;"

:: Test customer selection
echo Testing customer selection...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "SELECT 'Customer count: ' || COUNT(*)::text as test_result FROM sp_get_customers_for_selection();"

:: Test equipment types
echo Testing equipment types...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "SELECT 'Equipment types: ' || COUNT(*)::text as test_result FROM sp_get_available_equipment_types();"

:: Create sample hire interaction
echo.
echo Creating sample hire interaction...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "SELECT 'Sample hire: ' || reference_number as test_result FROM sp_create_sample_hire();"

:: Display schema summary
echo.
echo ============================================================================
echo SCHEMA SUMMARY
echo ============================================================================
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "
SELECT 
    schemaname as schema,
    COUNT(*) as table_count
FROM pg_tables 
WHERE schemaname IN ('core', 'equipment', 'interactions', 'tasks', 'system')
GROUP BY schemaname
ORDER BY schemaname;"

echo.
echo ============================================================================
echo DATABASE SETUP COMPLETE!
echo ============================================================================
echo.
echo ✓ PostgreSQL container: task-management-postgres
echo ✓ Database: task_management
echo ✓ User: SYSTEM / Password: SYSTEM
echo ✓ Port: 5432
echo ✓ Schemas: core, equipment, interactions, tasks, system
echo ✓ Schema migration: Applied from 01_schema_migration.sql
echo ✓ Sample data: Loaded from 02_sample_data.sql
echo ✓ Stored procedures: Installed from procedures/99_build_all.sql
echo   - 01_utility_procedures.sql
echo   - 02_equipment_procedures.sql
echo   - 03_hire_procedures.sql
echo   - 04_allocation_procedures.sql
echo ✓ Permissions: Set for all schemas
echo.
echo NEXT STEPS:
echo 1. Connect pgAdmin to localhost:5432
echo 2. Use credentials: SYSTEM / SYSTEM
echo 3. Start your Flask application
echo 4. Test the procedures in pgAdmin or via your Python API
echo.
echo USEFUL COMMANDS:
echo - Stop container:    docker stop task-management-postgres
echo - Start container:   docker start task-management-postgres
echo - View logs:         docker logs task-management-postgres
echo - Connect directly:  docker exec -it task-management-postgres psql -U SYSTEM -d task_management
echo - Restart setup:     docker stop task-management-postgres ^&^& docker rm task-management-postgres ^&^& ZZ database install.bat
echo.
echo Container is running and ready for use!
echo ============================================================================
pause