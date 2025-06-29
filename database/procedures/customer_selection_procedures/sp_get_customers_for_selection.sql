SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_get_customers_for_selection(
    p_search_term TEXT DEFAULT NULL,
    p_include_inactive BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    customer_id INTEGER,
    customer_code VARCHAR(20),
    customer_name VARCHAR(255),
    is_company BOOLEAN,
    credit_limit DECIMAL(15,2),
    payment_terms VARCHAR(50),
    status VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.customer_code,
        c.customer_name,
        c.is_company,
        c.credit_limit,
        c.payment_terms,
        c.status
    FROM core.customers c
    WHERE 
        (p_include_inactive = TRUE OR c.status = 'active')
        AND (
            p_search_term IS NULL 
            OR c.customer_name ILIKE '%' || p_search_term || '%'
            OR c.customer_code ILIKE '%' || p_search_term || '%'
        )
    ORDER BY 
        CASE WHEN c.status = 'active' THEN 0 ELSE 1 END,
        c.customer_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_customers_for_selection IS 'Get filtered customer list for hire selection interface';