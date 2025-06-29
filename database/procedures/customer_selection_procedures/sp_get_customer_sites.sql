SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_customer_sites(
    p_customer_id INTEGER
)
RETURNS TABLE(
    site_id INTEGER,
    site_code VARCHAR(20),
    site_name VARCHAR(255),
    site_type VARCHAR(50),
    full_address TEXT,
    site_contact_name VARCHAR(200),
    site_contact_phone VARCHAR(20),
    delivery_instructions TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.id,
        s.site_code,
        s.site_name,
        s.site_type,
        (s.address_line1 || 
         CASE WHEN s.address_line2 IS NOT NULL THEN ', ' || s.address_line2 ELSE '' END ||
         ', ' || s.city || 
         CASE WHEN s.province IS NOT NULL THEN ', ' || s.province ELSE '' END ||
         CASE WHEN s.postal_code IS NOT NULL THEN ', ' || s.postal_code ELSE '' END) AS full_address,
        s.site_contact_name,
        s.site_contact_phone,
        s.delivery_instructions
    FROM core.sites s
    WHERE 
        s.customer_id = p_customer_id
        AND s.is_active = TRUE
    ORDER BY 
        CASE WHEN s.site_type = 'project_site' THEN 0 ELSE 1 END,
        s.site_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_customer_sites IS 'Get delivery sites for selected customer';