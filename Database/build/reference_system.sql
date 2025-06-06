-- =============================================================================
-- REFERENCE NUMBER SYSTEM - SIMPLE VERSION (NO DOLLAR QUOTES)
-- =============================================================================
-- This version avoids dollar-quoted strings which may not work in all PostgreSQL setups
-- =============================================================================

-- =============================================================================
-- 1. CREATE REFERENCE PREFIX LOOKUP TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS reference_prefixes (
    id SERIAL PRIMARY KEY,
    interaction_type VARCHAR(50) UNIQUE NOT NULL,
    prefix VARCHAR(2) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clear existing data and insert standard reference prefixes
DELETE FROM reference_prefixes;
INSERT INTO reference_prefixes (interaction_type, prefix, description, is_active) VALUES
('price_list', 'PL', 'Price List Request', true),
('quote', 'QT', 'Quote Request', true),
('application', 'AP', 'Application for Account', true),
('order', 'OR', 'Equipment Order', true),
('hire', 'HR', 'Equipment Hire', true),
('off_hire', 'OH', 'Equipment Return/Off-Hire', true),
('breakdown', 'BD', 'Equipment Breakdown Report', true),
('statement', 'ST', 'Account Statement Request', true),
('refund', 'RF', 'Refund Request', true),
('coring', 'CR', 'Coring Service Request', true),
('misc_task', 'MT', 'Miscellaneous Task', true);

-- =============================================================================
-- 2. UPDATE REFERENCE NUMBER CONSTRAINT WITH PROPER DOCUMENTATION
-- =============================================================================

-- Drop the existing constraint
ALTER TABLE interactions DROP CONSTRAINT IF EXISTS check_reference_format;

-- Add the new constraint with detailed documentation
ALTER TABLE interactions
ADD CONSTRAINT check_reference_format
CHECK (reference_number ~ '^[A-Z]{2}[0-9]{9}$');

-- =============================================================================
-- 3. CREATE SIMPLE HELPER FUNCTION (WITHOUT DOLLAR QUOTES)
-- =============================================================================

-- Drop function if exists
DROP FUNCTION IF EXISTS generate_reference_number(VARCHAR);

-- Create a simpler version that can be called from application
-- This version uses basic PostgreSQL syntax without complex function blocks
CREATE OR REPLACE FUNCTION get_next_sequence_for_date(
    p_prefix VARCHAR(2), 
    p_date_part VARCHAR(6)
) RETURNS INTEGER
LANGUAGE SQL
AS 
'SELECT COALESCE(COUNT(*), 0) + 1 
 FROM interactions 
 WHERE DATE(created_at) = CURRENT_DATE
 AND reference_number LIKE p_prefix || p_date_part || ''%''';

-- Create helper function to get prefix
CREATE OR REPLACE FUNCTION get_prefix_for_interaction(p_interaction_type VARCHAR(50)) 
RETURNS VARCHAR(2)
LANGUAGE SQL
AS 
'SELECT COALESCE(
    (SELECT prefix FROM reference_prefixes 
     WHERE interaction_type = p_interaction_type AND is_active = true), 
    ''IN''
 )';

-- =============================================================================
-- 4. ADD INDEXES FOR PERFORMANCE
-- =============================================================================

-- Index on reference_prefixes for lookups
CREATE INDEX IF NOT EXISTS idx_reference_prefixes_interaction_type ON reference_prefixes(interaction_type);
CREATE INDEX IF NOT EXISTS idx_reference_prefixes_prefix ON reference_prefixes(prefix);
CREATE INDEX IF NOT EXISTS idx_reference_prefixes_active ON reference_prefixes(is_active);

-- Improved index on interactions reference_number
DROP INDEX IF EXISTS idx_interactions_reference_number_pattern;
CREATE INDEX idx_interactions_reference_number_pattern ON interactions(reference_number);

-- =============================================================================
-- 5. TESTING AND VALIDATION QUERIES
-- =============================================================================

-- Test the helper functions
SELECT 
    interaction_type,
    prefix,
    get_prefix_for_interaction(interaction_type) as function_prefix
FROM reference_prefixes 
WHERE is_active = true
ORDER BY interaction_type;

-- Test sequence generation
SELECT get_next_sequence_for_date('HR', '250606') as next_sequence;

-- View all reference prefixes
SELECT 
    interaction_type,
    prefix,
    description,
    is_active
FROM reference_prefixes 
ORDER BY interaction_type;

-- =============================================================================
-- 6. SIMPLE REFERENCE NUMBER GENERATION QUERY
-- =============================================================================

-- Example query to generate a reference number manually:
-- This can be used in your Python application instead of a complex function

/*
WITH ref_data AS (
    SELECT 
        get_prefix_for_interaction('hire') as prefix,
        TO_CHAR(CURRENT_DATE, 'YYMMDD') as date_part
),
sequence_data AS (
    SELECT 
        prefix,
        date_part,
        get_next_sequence_for_date(prefix, date_part) as sequence_num
    FROM ref_data
)
SELECT 
    prefix || date_part || LPAD(sequence_num::TEXT, 3, '0') as reference_number
FROM sequence_data;
*/

-- =============================================================================
-- 7. UPDATED PYTHON INTEGRATION APPROACH
-- =============================================================================

/*
Since complex stored functions may not work in your environment, 
update your Python code to use this approach:

def generate_reference_number_python(self, interaction_type: str) -> str:
    try:
        # Get prefix
        prefix_query = "SELECT get_prefix_for_interaction(%s)"
        self.cursor.execute(prefix_query, (interaction_type,))
        prefix = self.cursor.fetchone()[0]
        
        # Get date part
        date_part = datetime.now().strftime('%y%m%d')
        
        # Get sequence
        seq_query = "SELECT get_next_sequence_for_date(%s, %s)"
        self.cursor.execute(seq_query, (prefix, date_part))
        sequence = self.cursor.fetchone()[0]
        
        # Format reference number
        reference = f"{prefix}{date_part}{sequence:03d}"
        return reference
        
    except Exception as e:
        # Fallback to manual generation
        today = datetime.now().strftime('%y%m%d')
        return f"HR{today}001"
*/

-- =============================================================================
-- 8. MANAGEMENT QUERIES
-- =============================================================================

-- Add new reference prefix (example)
/*
INSERT INTO reference_prefixes (interaction_type, prefix, description) 
VALUES ('inspection', 'IN', 'Equipment Inspection');
*/

-- View reference number usage statistics
SELECT 
    SUBSTRING(reference_number, 1, 2) as prefix,
    COUNT(*) as usage_count,
    MIN(created_at) as first_used,
    MAX(created_at) as last_used
FROM interactions 
WHERE reference_number IS NOT NULL
GROUP BY SUBSTRING(reference_number, 1, 2)
ORDER BY usage_count DESC;

-- View daily reference number sequences for current month
SELECT 
    DATE(created_at) as date,
    interaction_type,
    COUNT(*) as daily_count,
    MIN(reference_number) as first_ref,
    MAX(reference_number) as last_ref
FROM interactions 
WHERE DATE(created_at) >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY DATE(created_at), interaction_type
ORDER BY date DESC, interaction_type;

-- =============================================================================
-- DOCUMENTATION
-- =============================================================================

/*
REFERENCE NUMBER FORMAT: PPYYYYMMDDNNN

Components:
- PP: 2-letter prefix from reference_prefixes table (e.g., HR, QT, PL)
- YY: 2-digit year (e.g., 25 for 2025)
- MM: 2-digit month (01-12)
- DD: 2-digit day (01-31)
- NNN: 3-digit sequence number (001-999) - resets daily

Examples:
- HR250606001 = Hire request on June 6, 2025, first of the day
- QT250606023 = Quote request on June 6, 2025, 23rd of the day  
- PL250607001 = Price list request on June 7, 2025, first of the day

CONSTRAINT:
- check_reference_format: ^[A-Z]{2}[0-9]{9}$ (2 letters + 9 digits)
- Total length: 11 characters
- All letters must be uppercase
- All numbers must be digits 0-9

USAGE:
1. Use the simple helper functions in your application
2. Generate reference numbers in Python using the provided approach
3. The constraint will validate the format automatically
4. Add new interaction types by inserting into reference_prefixes table
*/