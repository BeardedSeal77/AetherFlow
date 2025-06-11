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