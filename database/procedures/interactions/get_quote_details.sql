-- syntax error at $, use $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION interactions.get_quote_details(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    reference_number VARCHAR(20),
    customer_name VARCHAR(255),
    contact_name TEXT,
    contact_email VARCHAR(255),
    equipment_name VARCHAR(255),
    equipment_code VARCHAR(20),
    quantity INTEGER,
    hire_duration INTEGER,
    hire_period_type VARCHAR(20),
    unit_rate DECIMAL(10,2),
    line_total DECIMAL(15,2),
    subtotal DECIMAL(15,2),
    tax_rate DECIMAL(5,2),
    tax_amount DECIMAL(15,2),
    total_amount DECIMAL(15,2),
    valid_until DATE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        i.reference_number,
        c.customer_name,
        ct.first_name || ' ' || ct.last_name as contact_name,
        ct.email,
        ec.category_name,
        ec.category_code,
        cel.quantity,
        cel.hire_duration,
        cel.hire_period_type,
        CASE 
            WHEN cel.hire_duration >= 28 THEN ep.price_per_month / 30
            WHEN cel.hire_duration >= 7 THEN ep.price_per_week / 7
            ELSE ep.price_per_day
        END as unit_rate,
        (CASE 
            WHEN cel.hire_duration >= 28 THEN (ep.price_per_month / 30) * cel.hire_duration
            WHEN cel.hire_duration >= 7 THEN (ep.price_per_week / 7) * cel.hire_duration
            ELSE ep.price_per_day * cel.hire_duration
        END * cel.quantity) as line_total,
        qt.subtotal,
        qt.tax_rate,
        qt.tax_amount,
        qt.total_amount,
        qt.valid_until,
        i.created_at
    FROM interactions.interactions i
    JOIN core.customers c ON i.customer_id = c.id
    JOIN core.contacts ct ON i.contact_id = ct.id
    LEFT JOIN interactions.component_equipment_list cel ON i.id = cel.interaction_id
    LEFT JOIN core.equipment_categories ec ON cel.equipment_category_id = ec.id
    LEFT JOIN core.equipment_pricing ep ON ec.id = ep.equipment_category_id 
        AND ep.customer_type = CASE WHEN c.is_company THEN 'company' ELSE 'individual' END
        AND ep.is_active = true
    LEFT JOIN interactions.component_quote_totals qt ON i.id = qt.interaction_id
    WHERE i.id = p_interaction_id
        AND i.interaction_type = 'quote'
    ORDER BY ec.category_name;
END;