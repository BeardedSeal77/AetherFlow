SET search_path TO core, interactions, tasks, system, public;

CREATE OR REPLACE FUNCTION sp_validate_customer_credit(
    p_customer_id INTEGER,
    p_estimated_amount DECIMAL(15,2) DEFAULT 0
)
RETURNS TABLE(
    is_valid BOOLEAN,
    credit_limit DECIMAL(15,2),
    current_balance DECIMAL(15,2),
    available_credit DECIMAL(15,2),
    message TEXT
) AS $$
DECLARE
    customer_record RECORD;
    current_balance DECIMAL(15,2) := 0; -- TODO: Calculate from invoices/payments
BEGIN
    -- Get customer details
    SELECT * INTO customer_record 
    FROM core.customers 
    WHERE id = p_customer_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 0::DECIMAL(15,2), 0::DECIMAL(15,2), 0::DECIMAL(15,2), 'Customer not found';
        RETURN;
    END IF;
    
    IF customer_record.status != 'active' THEN
        RETURN QUERY SELECT FALSE, customer_record.credit_limit, current_balance, 
                           0::DECIMAL(15,2), 'Customer account is not active';
        RETURN;
    END IF;
    
    -- Check credit limit
    IF (current_balance + p_estimated_amount) > customer_record.credit_limit THEN
        RETURN QUERY SELECT FALSE, customer_record.credit_limit, current_balance,
                           (customer_record.credit_limit - current_balance),
                           'Credit limit would be exceeded';
        RETURN;
    END IF;
    
    -- All good
    RETURN QUERY SELECT TRUE, customer_record.credit_limit, current_balance,
                       (customer_record.credit_limit - current_balance),
                       'Credit check passed';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_validate_customer_credit IS 'Validate customer credit limit against estimated hire value';