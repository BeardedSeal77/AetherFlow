SET search_path TO system, public;

CREATE OR REPLACE FUNCTION system.generate_reference_number(
    p_interaction_type VARCHAR(50)
)
RETURNS VARCHAR(20) AS $GENERATE_REF$
DECLARE
    v_prefix VARCHAR(10);
    v_date_part VARCHAR(6);
    v_sequence INTEGER;
    v_reference_number VARCHAR(20);
BEGIN
    -- Get prefix for interaction type
    v_prefix := system.get_prefix_for_interaction(p_interaction_type);
    
    -- Format current date as YYMMDD
    v_date_part := TO_CHAR(CURRENT_DATE, 'YYMMDD');
    
    -- Get next sequence number for this date
    v_sequence := system.get_next_sequence_for_date(v_prefix, v_date_part);
    
    -- Combine into final reference number
    v_reference_number := v_prefix || v_date_part || LPAD(v_sequence::TEXT, 3, '0');
    
    RETURN v_reference_number;
    
END;
$GENERATE_REF$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION system.generate_reference_number IS 
'Generates unique reference numbers in format PREFIX+YYMMDD+SEQUENCE.
Example: HR250609001 for first hire on June 9th, 2025.';

GRANT EXECUTE ON FUNCTION system.generate_reference_number TO PUBLIC;