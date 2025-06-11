SET search_path TO system, public;

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
