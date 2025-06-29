SET search_path TO core, interactions, tasks, system, public;

-- 4.1 Generate Reference Number
CREATE OR REPLACE FUNCTION sp_generate_reference_number(
    p_interaction_type VARCHAR(50)
)
RETURNS VARCHAR(20) AS $$
DECLARE
    prefix VARCHAR(10);
    date_part VARCHAR(6);
    sequence_num INTEGER;
    reference_number VARCHAR(20);
BEGIN
    -- Get prefix for interaction type
    SELECT rp.prefix INTO prefix
    FROM system.reference_prefixes rp
    WHERE rp.interaction_type = p_interaction_type
      AND rp.is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No reference prefix found for interaction type: %', p_interaction_type;
    END IF;
    
    -- Format date as YYMMDD
    date_part := TO_CHAR(CURRENT_DATE, 'YYMMDD');
    
    -- Get or create sequence for today
    INSERT INTO system.reference_sequences (prefix, date_part, last_sequence)
    VALUES (prefix, date_part, 1)
    ON CONFLICT (prefix, date_part) 
    DO UPDATE SET 
        last_sequence = reference_sequences.last_sequence + 1,
        updated_at = CURRENT_TIMESTAMP
    RETURNING last_sequence INTO sequence_num;
    
    -- Format final reference number
    reference_number := prefix || date_part || LPAD(sequence_num::TEXT, 3, '0');
    
    RETURN reference_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_generate_reference_number IS 'Generate unique reference number for interactions';