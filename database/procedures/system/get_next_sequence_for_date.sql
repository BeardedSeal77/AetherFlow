SET search_path TO system, public;

CREATE OR REPLACE FUNCTION system.get_next_sequence_for_date(
    p_prefix VARCHAR(10),
    p_date_part VARCHAR(6)
)
RETURNS INTEGER AS $GET_SEQUENCE$
DECLARE
    v_sequence INTEGER;
BEGIN
    -- Use UPSERT to increment sequence counter for prefix+date combination
    INSERT INTO system.reference_sequences (prefix, date_part, sequence_number, last_updated)
    VALUES (p_prefix, p_date_part, 1, CURRENT_TIMESTAMP)
    ON CONFLICT (prefix, date_part)
    DO UPDATE SET 
        sequence_number = system.reference_sequences.sequence_number + 1,
        last_updated = CURRENT_TIMESTAMP
    RETURNING sequence_number INTO v_sequence;
    
    RETURN v_sequence;
    
END;
$GET_SEQUENCE$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION system.get_next_sequence_for_date IS 
'Gets next sequence number for specific date with concurrent access handling.';


GRANT EXECUTE ON FUNCTION system.get_next_sequence_for_date TO PUBLIC;