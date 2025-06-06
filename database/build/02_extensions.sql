-- =============================================================================
-- STEP 02: DATABASE EXTENSIONS
-- =============================================================================
-- Purpose: Install required PostgreSQL extensions
-- Run as: SYSTEM user
-- Database: task_management
-- Order: Must be run SECOND (after database creation)
-- =============================================================================

-- Connect to task_management database first
\c task_management;

-- Enable UUID generation (for unique IDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for password hashing and encryption
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable fuzzy string matching (for customer/contact searches)
CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";

-- Enable advanced text search capabilities
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Verify extensions are installed
SELECT 
    extname AS extension_name,
    extversion AS version,
    'Installed' AS status
FROM pg_extension 
WHERE extname IN ('uuid-ossp', 'pgcrypto', 'fuzzystrmatch', 'pg_trgm')
ORDER BY extname;

-- =============================================================================
-- NEXT STEP: Run 03_schemas.sql
-- =============================================================================