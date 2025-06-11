SET search_path TO system, public;

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

COMMENT ON FUNCTION system.generate_reference_number IS 
'Generates unique reference numbers in format PREFIX+YYMMDD+SEQUENCE.
Example: HR250609001 for first hire on June 9th, 2025.';

GRANT EXECUTE ON FUNCTION system.generate_reference_number TO PUBLIC;