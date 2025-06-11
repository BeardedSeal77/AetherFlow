SET search_path TO system, public;

CREATE OR REPLACE FUNCTION system.get_prefix_for_interaction(
    p_interaction_type VARCHAR(50)
)
RETURNS VARCHAR(10) AS $GET_PREFIX$
DECLARE
    v_prefix VARCHAR(10);
BEGIN
    -- Query reference_prefixes table for active prefix
    SELECT prefix INTO v_prefix
    FROM system.reference_prefixes
    WHERE interaction_type = p_interaction_type
      AND is_active = true
    LIMIT 1;
    
    -- Raise exception if no active prefix found
    IF v_prefix IS NULL THEN
        RAISE EXCEPTION 'No active prefix found for interaction type: %', p_interaction_type;
    END IF;
    
    RETURN v_prefix;
    
END;
$GET_PREFIX$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION system.get_prefix_for_interaction IS 
'Retrieves reference prefix for interaction type from system.reference_prefixes table.';

GRANT EXECUTE ON FUNCTION system.get_prefix_for_interaction TO PUBLIC;