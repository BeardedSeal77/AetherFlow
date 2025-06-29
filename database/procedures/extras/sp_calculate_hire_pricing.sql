SET search_path TO core, interactions, tasks, system, public;

-- Procedure to get equipment pricing (placeholder for future pricing module)
CREATE OR REPLACE FUNCTION sp_calculate_hire_pricing(
    p_customer_id INTEGER,
    p_equipment_selections JSONB,
    p_accessory_selections JSONB,
    p_hire_duration_days INTEGER DEFAULT 1
)
RETURNS TABLE(
    equipment_type_id INTEGER,
    type_name VARCHAR(255),
    quantity INTEGER,
    daily_rate DECIMAL(10,2),
    subtotal DECIMAL(10,2),
    accessory_charges DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    vat_amount DECIMAL(10,2),
    grand_total DECIMAL(10,2)
) AS $$
DECLARE
    equipment_item JSONB;
    base_rate DECIMAL(10,2) := 100.00; -- Placeholder daily rate
    vat_rate DECIMAL(5,4) := 0.15; -- 15% VAT
BEGIN
    -- This is a placeholder implementation
    -- In production, this would integrate with a pricing module
    
    FOR equipment_item IN SELECT jsonb_array_elements(p_equipment_selections)
    LOOP
        RETURN QUERY
        SELECT 
            (equipment_item->>'equipment_type_id')::INTEGER,
            et.type_name,
            (equipment_item->>'quantity')::INTEGER,
            base_rate AS daily_rate,
            (base_rate * (equipment_item->>'quantity')::INTEGER * p_hire_duration_days) AS subtotal,
            0.00 AS accessory_charges, -- Placeholder
            (base_rate * (equipment_item->>'quantity')::INTEGER * p_hire_duration_days) AS total_amount,
            (base_rate * (equipment_item->>'quantity')::INTEGER * p_hire_duration_days * vat_rate) AS vat_amount,
            (base_rate * (equipment_item->>'quantity')::INTEGER * p_hire_duration_days * (1 + vat_rate)) AS grand_total
        FROM core.equipment_types et
        WHERE et.id = (equipment_item->>'equipment_type_id')::INTEGER;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_calculate_hire_pricing IS 'Calculate hire pricing (placeholder for pricing module integration)';