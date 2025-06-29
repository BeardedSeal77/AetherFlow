SET search_path TO core, interactions, tasks, system, public;

-- Procedure to create sample hire interaction for testing
CREATE OR REPLACE FUNCTION sp_create_sample_hire()
RETURNS TABLE(
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    message TEXT
) AS $$
DECLARE
    sample_equipment JSONB;
    sample_accessories JSONB;
    result RECORD;
BEGIN
    -- Sample equipment selection (2 rammers, 1 plate compactor)
    sample_equipment := '[
        {"equipment_type_id": 1, "quantity": 2},
        {"equipment_type_id": 3, "quantity": 1}
    ]'::JSONB;
    
    -- Sample accessories (petrol and safety equipment)
    sample_accessories := '[
        {"accessory_id": 1, "quantity": 14.0, "accessory_type": "default"},
        {"accessory_id": 4, "quantity": 3, "accessory_type": "default"}
    ]'::JSONB;
    
    -- Create the hire interaction
    SELECT * INTO result
    FROM sp_create_hire_interaction(
        p_customer_id := 1000,
        p_contact_id := 1000,
        p_employee_id := 2,
        p_site_id := (SELECT id FROM core.sites WHERE customer_id = 1000 LIMIT 1),
        p_contact_method := 'phone',
        p_notes := 'Sample hire for testing - 2 rammers and 1 plate compactor',
        p_equipment_selections := sample_equipment,
        p_accessory_selections := sample_accessories,
        p_delivery_date := CURRENT_DATE + 1,
        p_delivery_time := '09:00:00'::TIME
    );
    
    RETURN QUERY SELECT result.interaction_id, result.reference_number, result.message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_create_sample_hire IS 'Create sample hire interaction for testing purposes';