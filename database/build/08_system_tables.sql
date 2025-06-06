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
-- REFERENCE NUMBER FUNCTIONS
-- =============================================================================

-- Function to get prefix for interaction type
CREATE OR REPLACE FUNCTION system.get_prefix_for_interaction(interaction_type_param VARCHAR(50))
RETURNS VARCHAR(10) AS $$
DECLARE
    prefix_result VARCHAR(10);
BEGIN
    SELECT prefix INTO prefix_result
    FROM system.reference_prefixes
    WHERE interaction_type = interaction_type_param
    AND is_active = true;
    
    IF prefix_result IS NULL THEN
        RAISE EXCEPTION 'No active prefix found for interaction type: %', interaction_type_param;
    END IF;
    
    RETURN prefix_result;
END;
$$ LANGUAGE plpgsql;

-- Function to get next sequence number for date
CREATE OR REPLACE FUNCTION system.get_next_sequence_for_date(prefix_param VARCHAR(10), date_part_param VARCHAR(10))
RETURNS INTEGER AS $$
DECLARE
    next_sequence INTEGER;
BEGIN
    -- Insert or update sequence record
    INSERT INTO system.reference_sequences (prefix, date_part, last_sequence)
    VALUES (prefix_param, date_part_param, 1)
    ON CONFLICT (prefix, date_part)
    DO UPDATE SET 
        last_sequence = system.reference_sequences.last_sequence + 1,
        updated_at = CURRENT_TIMESTAMP;
    
    -- Get the current sequence
    SELECT last_sequence INTO next_sequence
    FROM system.reference_sequences
    WHERE prefix = prefix_param AND date_part = date_part_param;
    
    RETURN next_sequence;
END;
$$ LANGUAGE plpgsql;

-- Function to generate complete reference number
CREATE OR REPLACE FUNCTION system.generate_reference_number(interaction_type_param VARCHAR(50))
RETURNS VARCHAR(20) AS $$
DECLARE
    prefix_val VARCHAR(10);
    date_part VARCHAR(10);
    sequence_num INTEGER;
    reference_number VARCHAR(20);
BEGIN
    -- Get prefix
    prefix_val := system.get_prefix_for_interaction(interaction_type_param);
    
    -- Get date part (YYMMDD)
    date_part := to_char(CURRENT_DATE, 'YYMMDD');
    
    -- Get next sequence
    sequence_num := system.get_next_sequence_for_date(prefix_val, date_part);
    
    -- Format reference number: PPYYMMDDNNN
    reference_number := prefix_val || date_part || lpad(sequence_num::text, 3, '0');
    
    RETURN reference_number;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- SYSTEM UTILITY FUNCTIONS
-- =============================================================================

-- Function to get system configuration
CREATE OR REPLACE FUNCTION system.get_config(key_name VARCHAR(100))
RETURNS TEXT AS $$
DECLARE
    config_val TEXT;
BEGIN
    SELECT config_value INTO config_val
    FROM system.system_config
    WHERE config_key = key_name
    AND is_active = true;
    
    RETURN config_val;
END;
$$ LANGUAGE plpgsql;

-- Function to set system configuration
CREATE OR REPLACE FUNCTION system.set_config(key_name VARCHAR(100), value_param TEXT, type_param VARCHAR(20) DEFAULT 'string')
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO system.system_config (config_key, config_value, config_type)
    VALUES (key_name, value_param, type_param)
    ON CONFLICT (config_key)
    DO UPDATE SET 
        config_value = value_param,
        config_type = type_param,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

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