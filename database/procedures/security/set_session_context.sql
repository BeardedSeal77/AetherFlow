
SET search_path TO security, public;
-- Function to set session context (called after authentication)
CREATE OR REPLACE FUNCTION security.set_session_context(employee_id_param INTEGER, role_param VARCHAR(50))
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_employee_id', employee_id_param::TEXT, false);
    PERFORM set_config('app.current_employee_role', role_param, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;