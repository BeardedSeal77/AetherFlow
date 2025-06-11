SET search_path TO system, public;

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

COMMENT ON FUNCTION system.get_next_sequence_for_date IS 
'Gets next sequence number for specific date with concurrent access handling.';


GRANT EXECUTE ON FUNCTION system.get_next_sequence_for_date TO PUBLIC;