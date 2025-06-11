SET search_path TO system, public;

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

COMMENT ON FUNCTION system.get_prefix_for_interaction IS 
'Retrieves reference prefix for interaction type from system.reference_prefixes table.';

GRANT EXECUTE ON FUNCTION system.get_prefix_for_interaction TO PUBLIC;