SET search_path TO core, interactions, tasks, system, public;

-- 4.1 Generate Reference Number
CREATE OR REPLACE FUNCTION sp_generate_reference_number(
    p_interaction_type VARCHAR(50)
)
RETURNS VARCHAR(20) AS $$
DECLARE
    v_prefix VARCHAR(10);
    v_date_part VARCHAR(6);
    v_sequence_num INTEGER;
    v_reference_number VARCHAR(20);
BEGIN
    -- Get prefix for interaction type
    SELECT rp.prefix INTO v_prefix
    FROM system.reference_prefixes rp
    WHERE rp.interaction_type = p_interaction_type
      AND rp.is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No reference prefix found for interaction type: %', p_interaction_type;
    END IF;
    
    -- Format date as YYMMDD
    v_date_part := TO_CHAR(CURRENT_DATE, 'YYMMDD');
    
    -- Get or create sequence for today
    INSERT INTO system.reference_sequences (prefix, date_part, last_sequence)
    VALUES (v_prefix, v_date_part, 1)
    ON CONFLICT (prefix, date_part) 
    DO UPDATE SET 
        last_sequence = reference_sequences.last_sequence + 1,
        updated_at = CURRENT_TIMESTAMP
    RETURNING last_sequence INTO v_sequence_num;
    
    -- Format final reference number
    v_reference_number := v_prefix || v_date_part || LPAD(v_sequence_num::TEXT, 3, '0');
    
    RETURN v_reference_number;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_generate_reference_number IS 'Generate unique reference number for interactions';
