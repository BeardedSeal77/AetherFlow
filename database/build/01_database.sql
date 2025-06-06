-- ============================================================================
-- RESET SCHEMA CONTENTS WITHOUT DROPPING THE DATABASE
-- ============================================================================
-- This script will clean out the 'public' schema (or any custom schemas),
-- dropping all tables, views, sequences, functions, etc.
-- Run this inside the `task_management` database
-- ============================================================================

-- Optional: Clean all user-defined schemas (except system schemas)
DO $$
DECLARE
    schema_name text;
BEGIN
    FOR schema_name IN
        SELECT nspname
        FROM pg_namespace
        WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
          AND nspname NOT LIKE 'pg_temp_%'
          AND nspname NOT LIKE 'pg_toast_temp_%'
    LOOP
        EXECUTE format('DROP SCHEMA IF EXISTS %I CASCADE', schema_name);
        EXECUTE format('CREATE SCHEMA %I AUTHORIZATION CURRENT_USER', schema_name);
    END LOOP;
END
$$;

-- Optional: Regrant public permissions
GRANT ALL ON SCHEMA public TO CURRENT_USER;
GRANT USAGE ON SCHEMA public TO PUBLIC;
