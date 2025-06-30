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
echo Waiting 5 seconds for PostgreSQL to start...
timeout /t 5 /nobreak >nul

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
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -f /tmp/database/build/tables.sql
if errorlevel 1 (
    echo ERROR: Failed to create database schema!
    echo Check the tables.sql file for errors.
    pause
    exit /b 1
)
echo ✓ Database schema created

:: Load sample data
echo.
echo Loading sample data...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -f /tmp/database/build/sample_data.sql
if errorlevel 1 (
    echo ERROR: Failed to load sample data!
    echo Check the sample_data.sql file for errors.
    pause
    exit /b 1
)
echo ✓ Sample data loaded

:: Install stored procedures
echo.
echo Installing stored procedures...
docker exec -it task-management-postgres bash -c "cd /tmp && psql -U SYSTEM -d task_management -v ON_ERROR_STOP=1 -f database/procedures/build_all_procedures.sql"
if errorlevel 1 (
    echo ERROR: Failed to install stored procedures!
    echo Check the procedure files for syntax errors.
    pause
    exit /b 1
)

:: Fix permissions
echo.
echo Setting permissions...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA core TO PUBLIC;"
if errorlevel 1 (
    echo WARNING: Failed to set permissions (non-critical)
) else (
    echo ✓ Permissions set
)

:: Verify installation
echo.
echo Verifying installation...

:: Check schemas
echo Checking schemas...
docker exec -i task-management-postgres psql -U SYSTEM -d task_management -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('core', 'interactions', 'tasks', 'system') ORDER BY schema_name;"

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

echo.
echo ============================================================================
echo DATABASE SETUP COMPLETE!
echo ============================================================================
echo.
echo ✓ PostgreSQL container: task-management-postgres
echo ✓ Database: task_management
echo ✓ User: SYSTEM / Password: SYSTEM
echo ✓ Port: 5432
echo ✓ Schemas: core, interactions, tasks, system
echo ✓ Stored procedures: ~30 procedures installed
echo ✓ Sample data: Customers, equipment, and test hire created
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
echo.
echo Container is running and ready for use!
echo ============================================================================
pause