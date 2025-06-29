SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_customer_contacts(
    p_customer_id INTEGER
)
RETURNS TABLE(
    contact_id INTEGER,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name TEXT,
    job_title VARCHAR(100),
    email VARCHAR(255),
    phone_number VARCHAR(20),
    whatsapp_number VARCHAR(20),
    is_primary_contact BOOLEAN,
    is_billing_contact BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ct.id,
        ct.first_name,
        ct.last_name,
        (ct.first_name || ' ' || ct.last_name) AS full_name,
        ct.job_title,
        ct.email,
        ct.phone_number,
        ct.whatsapp_number,
        ct.is_primary_contact,
        ct.is_billing_contact
    FROM core.contacts ct
    WHERE 
        ct.customer_id = p_customer_id
        AND ct.status = 'active'
    ORDER BY 
        ct.is_primary_contact DESC,
        ct.first_name, ct.last_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_customer_contacts IS 'Get active contacts for selected customer';