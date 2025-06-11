
SET search_path TO security, public;

-- Function to clear session context
CREATE OR REPLACE FUNCTION security.clear_session_context()
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_employee_id', '', false);
    PERFORM set_config('app.current_employee_role', '', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;