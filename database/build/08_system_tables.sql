-- =============================================================================
-- STEP 08: SYSTEM TABLES AND REFERENCE DATA
-- =============================================================================
-- Purpose: Create system tables for reference numbers and configuration
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run EIGHTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- REFERENCE NUMBER CONFIGURATION TABLE
-- =============================================================================
CREATE TABLE system.reference_prefixes (
    id SERIAL PRIMARY KEY,
    interaction_type VARCHAR(50) UNIQUE NOT NULL,
    prefix VARCHAR(10) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system.reference_prefixes IS 'Reference number prefixes for each interaction type';

-- Insert reference prefixes
INSERT INTO system.reference_prefixes (interaction_type, prefix, description) VALUES
('price_list', 'PL', 'Price List Request'),
('quote', 'QT', 'Quote Request'),
('statement', 'ST', 'Account Statement'),
('refund', 'RF', 'Refund Request'),
('hire', 'HR', 'Equipment Hire'),
('off_hire', 'OH', 'Off-Hire/Collection'),
('breakdown', 'BD', 'Equipment Breakdown'),
('application', 'AP', 'Account Application'),
('coring', 'CR', 'Coring Services'),
('misc_task', 'MT', 'Miscellaneous Task');

-- =============================================================================
-- REFERENCE NUMBER SEQUENCES TABLE
-- =============================================================================
CREATE TABLE system.reference_sequences (
    id SERIAL PRIMARY KEY,
    prefix VARCHAR(10) NOT NULL,
    date_part VARCHAR(10) NOT NULL, -- YYMMDD format
    last_sequence INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(prefix, date_part)
);

COMMENT ON TABLE system.reference_sequences IS 'Daily sequence counters for reference numbers';

-- =============================================================================
-- SYSTEM CONFIGURATION TABLE
-- =============================================================================
CREATE TABLE system.system_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    config_type VARCHAR(20) NOT NULL DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system.system_config IS 'System-wide configuration settings';

-- Insert default system configuration
INSERT INTO system.system_config (config_key, config_value, config_type, description) VALUES
('company_name', 'Equipment Hire Company', 'string', 'Company name for documents'),
('company_vat_number', 'VAT123456789', 'string', 'Company VAT registration number'),
('default_vat_rate', '15.0', 'number', 'Default VAT rate percentage'),
('quote_validity_days', '30', 'number', 'Default quote validity period in days'),
('max_login_attempts', '5', 'number', 'Maximum failed login attempts before lockout'),
('session_timeout_hours', '8', 'number', 'Session timeout in hours'),
('backup_retention_days', '90', 'number', 'Database backup retention period'),
('maintenance_mode', 'false', 'boolean', 'System maintenance mode flag');

-- =============================================================================
-- TRIGGERS FOR UPDATED_AT
-- =============================================================================

CREATE TRIGGER reference_sequences_updated_at 
    BEFORE UPDATE ON system.reference_sequences
    FOR EACH ROW EXECUTE FUNCTION interactions.update_timestamp();

CREATE TRIGGER system_config_updated_at 
    BEFORE UPDATE ON system.system_config
    FOR EACH ROW EXECUTE FUNCTION interactions.update_timestamp();

-- =============================================================================
-- NEXT STEP: Run 09_indexes.sql
-- =============================================================================