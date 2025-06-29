SET search_path TO core, interactions, tasks, system, public;

-- 8.3 Get Quality Control Summary
CREATE OR REPLACE FUNCTION sp_get_qc_summary(
    p_date_from DATE DEFAULT CURRENT_DATE - INTERVAL '7 days',
    p_date_to DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    total_allocations INTEGER,
    pending_qc INTEGER,
    passed_qc INTEGER,
    failed_qc INTEGER,
    repaired_qc INTEGER,
    qc_completion_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER AS total_allocations,
        COUNT(CASE WHEN quality_check_status = 'pending' THEN 1 END)::INTEGER AS pending_qc,
        COUNT(CASE WHEN quality_check_status = 'passed' THEN 1 END)::INTEGER AS passed_qc,
        COUNT(CASE WHEN quality_check_status = 'failed' THEN 1 END)::INTEGER AS failed_qc,
        COUNT(CASE WHEN quality_check_status = 'repaired' THEN 1 END)::INTEGER AS repaired_qc,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(CASE WHEN quality_check_status != 'pending' THEN 1 END) * 100.0 / COUNT(*))::NUMERIC, 2)
            ELSE 0::DECIMAL(5,2)
        END AS qc_completion_rate
    FROM interactions.interaction_equipment ie
    JOIN interactions.interactions i ON ie.interaction_id = i.id
    WHERE i.created_at::DATE BETWEEN p_date_from AND p_date_to;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION sp_get_qc_summary IS 'Get quality control statistics and completion rates';