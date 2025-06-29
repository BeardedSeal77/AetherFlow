SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_hire_interaction_details(
    p_interaction_id INTEGER
)
RETURNS TABLE(
    interaction_id INTEGER,
    reference_number VARCHAR(20),
    interaction_status VARCHAR(50),
    customer_name VARCHAR(255),
    contact_name TEXT,
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    site_name VARCHAR(255),
    site_address TEXT,
    hire_start_date DATE,
    hire_end_date DATE,
    delivery_date DATE,
    delivery_time TIME,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    employee_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.reference_number,
        i.status,
        c.customer_name,
        (ct.first_name || ' ' || ct.last_name) AS contact_name,
        ct.phone_number,
        ct.email,
        dt.site_address AS site_name,  -- From driver task
        dt.site_address,
        MIN(iet.hire_start_date) AS hire_start_date,
        MAX(iet.hire_end_date) AS hire_end_date,
        dt.scheduled_date,
        dt.scheduled_time,
        i.notes,
        i.created_at,
        (e.name || ' ' || e.surname) AS employee_name
    FROM interactions.interactions i
    JOIN core.customers c ON i.customer_id = c.id
    JOIN core.contacts ct ON i.contact_id = ct.id
    JOIN core.employees e ON i.employee_id = e.id
    LEFT JOIN interactions.interaction_equipment_types iet ON i.id = iet.interaction_id
    LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
    WHERE i.id = p_interaction_id
    GROUP BY i.id, i.reference_number, i.status, c.customer_name,
             ct.first_name, ct.last_name, ct.phone_number, ct.email,
             dt.site_address, dt.scheduled_date, dt.scheduled_time,
             i.notes, i.created_at, e.name, e.surname;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_hire_interaction_details IS 'Get complete hire interaction details for display';