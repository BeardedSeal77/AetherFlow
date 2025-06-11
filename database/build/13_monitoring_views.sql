-- =============================================================================
-- STEP 12: MONITORING VIEWS AND REPORTS
-- =============================================================================
-- Purpose: Create views for monitoring, reporting, and analytics
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run TWELFTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- DASHBOARD VIEWS
-- =============================================================================

-- Current system overview
CREATE VIEW system.dashboard_overview AS
SELECT 
    (SELECT COUNT(*) FROM core.customers WHERE status = 'active') as active_customers,
    (SELECT COUNT(*) FROM core.employees WHERE status = 'active') as active_employees,
    (SELECT COUNT(*) FROM interactions.interactions WHERE status = 'pending') as pending_interactions,
    (SELECT COUNT(*) FROM tasks.user_taskboard WHERE status IN ('pending', 'in_progress')) as active_user_tasks,
    (SELECT COUNT(*) FROM tasks.drivers_taskboard WHERE status NOT IN ('completed', 'cancelled')) as active_driver_tasks,
    (SELECT COUNT(*) FROM tasks.user_taskboard WHERE due_date < CURRENT_DATE AND status NOT IN ('completed', 'cancelled')) as overdue_user_tasks,
    (SELECT COUNT(*) FROM tasks.drivers_taskboard WHERE scheduled_date < CURRENT_DATE AND status NOT IN ('completed', 'cancelled')) as overdue_driver_tasks,
    (SELECT COUNT(*) FROM tasks.user_taskboard WHERE priority = 'urgent' AND status NOT IN ('completed', 'cancelled')) as urgent_user_tasks,
    (SELECT COUNT(*) FROM tasks.drivers_taskboard WHERE priority = 'urgent' AND status NOT IN ('completed', 'cancelled')) as urgent_driver_tasks;

-- Employee workload summary
CREATE VIEW system.employee_workload AS
SELECT 
    e.id as employee_id,
    e.name || ' ' || e.surname as employee_name,
    e.role,
    COALESCE(ut.user_tasks, 0) as user_tasks,
    COALESCE(dt.driver_tasks, 0) as driver_tasks,
    COALESCE(ut.urgent_user_tasks, 0) as urgent_user_tasks,
    COALESCE(dt.urgent_driver_tasks, 0) as urgent_driver_tasks,
    COALESCE(ut.overdue_user_tasks, 0) as overdue_user_tasks,
    COALESCE(dt.overdue_driver_tasks, 0) as overdue_driver_tasks
FROM core.employees e
LEFT JOIN (
    SELECT 
        assigned_to,
        COUNT(*) as user_tasks,
        COUNT(CASE WHEN priority = 'urgent' THEN 1 END) as urgent_user_tasks,
        COUNT(CASE WHEN due_date < CURRENT_DATE THEN 1 END) as overdue_user_tasks
    FROM tasks.user_taskboard 
    WHERE status NOT IN ('completed', 'cancelled')
    GROUP BY assigned_to
) ut ON e.id = ut.assigned_to
LEFT JOIN (
    SELECT 
        assigned_to,
        COUNT(*) as driver_tasks,
        COUNT(CASE WHEN priority = 'urgent' THEN 1 END) as urgent_driver_tasks,
        COUNT(CASE WHEN scheduled_date < CURRENT_DATE THEN 1 END) as overdue_driver_tasks
    FROM tasks.drivers_taskboard 
    WHERE status NOT IN ('completed', 'cancelled')
    GROUP BY assigned_to
) dt ON e.id = dt.assigned_to
WHERE e.status = 'active'
ORDER BY e.role, e.surname;

-- Customer interaction summary
CREATE VIEW system.customer_interaction_summary AS
SELECT 
    c.id as customer_id,
    c.customer_name,
    c.is_company,
    c.credit_limit,
    COUNT(i.id) as total_interactions,
    COUNT(CASE WHEN i.status = 'pending' THEN 1 END) as pending_interactions,
    COUNT(CASE WHEN i.interaction_type = 'quote' THEN 1 END) as quotes,
    COUNT(CASE WHEN i.interaction_type = 'hire' THEN 1 END) as hires,
    COUNT(CASE WHEN i.interaction_type = 'breakdown' THEN 1 END) as breakdowns,
    MAX(i.created_at) as last_interaction_date,
    STRING_AGG(DISTINCT i.interaction_type, ', ') as interaction_types
FROM core.customers c
LEFT JOIN interactions.interactions i ON c.id = i.customer_id
    AND i.created_at >= CURRENT_DATE - INTERVAL '90 days'
WHERE c.status = 'active'
GROUP BY c.id, c.customer_name, c.is_company, c.credit_limit
ORDER BY total_interactions DESC, last_interaction_date DESC;

-- =============================================================================
-- TASK MONITORING VIEWS
-- =============================================================================

-- Active user tasks with details
CREATE VIEW tasks.active_user_tasks AS
SELECT 
    ut.id,
    i.reference_number,
    ut.task_type,
    ut.title,
    ut.priority,
    ut.status,
    ut.due_date,
    CASE 
        WHEN ut.due_date < CURRENT_DATE THEN 'OVERDUE'
        WHEN ut.due_date = CURRENT_DATE THEN 'DUE TODAY'
        WHEN ut.due_date = CURRENT_DATE + 1 THEN 'DUE TOMORROW'
        ELSE 'ON SCHEDULE'
    END as urgency_status,
    e.name || ' ' || e.surname as assigned_to_name,
    e.role as assigned_to_role,
    c.customer_name,
    ct.first_name || ' ' || ct.last_name as customer_contact,
    ut.created_at,
    ut.started_at
FROM tasks.user_taskboard ut
JOIN interactions.interactions i ON ut.interaction_id = i.id
JOIN core.employees e ON ut.assigned_to = e.id
JOIN core.customers c ON i.customer_id = c.id
LEFT JOIN core.contacts ct ON i.contact_id = ct.id
WHERE ut.status NOT IN ('completed', 'cancelled')
ORDER BY 
    CASE ut.priority 
        WHEN 'urgent' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        WHEN 'low' THEN 4 
    END,
    ut.due_date ASC;

-- Active driver tasks with details
CREATE VIEW tasks.active_driver_tasks AS
SELECT 
    dt.id,
    i.reference_number,
    dt.task_type,
    dt.priority,
    dt.status,
    dt.customer_name,
    dt.contact_name,
    dt.contact_phone,
    dt.site_address,
    dt.equipment_summary,
    dt.scheduled_date,
    dt.scheduled_time,
    CASE 
        WHEN dt.scheduled_date < CURRENT_DATE THEN 'OVERDUE'
        WHEN dt.scheduled_date = CURRENT_DATE THEN 'TODAY'
        WHEN dt.scheduled_date = CURRENT_DATE + 1 THEN 'TOMORROW'
        ELSE 'FUTURE'
    END as schedule_status,
    COALESCE(e.name || ' ' || e.surname, 'UNASSIGNED') as assigned_driver,
    dt.status_booked,
    dt.status_driver,
    dt.status_quality_control,
    dt.status_whatsapp,
    dt.equipment_verified,
    dt.created_at
FROM tasks.drivers_taskboard dt
JOIN interactions.interactions i ON dt.interaction_id = i.id
LEFT JOIN core.employees e ON dt.assigned_to = e.id
WHERE dt.status NOT IN ('completed', 'cancelled')
ORDER BY 
    CASE dt.priority 
        WHEN 'urgent' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        WHEN 'low' THEN 4 
    END,
    dt.scheduled_date ASC,
    dt.scheduled_time ASC;

-- Task progress tracking
CREATE VIEW tasks.task_progress_summary AS
SELECT 
    'User Tasks' as task_category,
    COUNT(*) as total_tasks,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN status = 'in_progress' THEN 1 END) as in_progress,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN priority = 'urgent' THEN 1 END) as urgent,
    COUNT(CASE WHEN due_date < CURRENT_DATE AND status NOT IN ('completed', 'cancelled') THEN 1 END) as overdue
FROM tasks.user_taskboard
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT 
    'Driver Tasks',
    COUNT(*),
    COUNT(CASE WHEN status = 'backlog' THEN 1 END),
    COUNT(CASE WHEN status IN ('driver_1', 'driver_2', 'driver_3', 'driver_4') THEN 1 END),
    COUNT(CASE WHEN status = 'completed' THEN 1 END),
    COUNT(CASE WHEN priority = 'urgent' THEN 1 END),
    COUNT(CASE WHEN scheduled_date < CURRENT_DATE AND status NOT IN ('completed', 'cancelled') THEN 1 END)
FROM tasks.drivers_taskboard
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';

-- =============================================================================
-- PERFORMANCE ANALYTICS VIEWS
-- =============================================================================

-- Employee performance metrics
CREATE VIEW system.employee_performance AS
SELECT 
    e.id as employee_id,
    e.name || ' ' || e.surname as employee_name,
    e.role,
    ut.user_tasks_completed,
    ut.avg_user_completion_hours,
    ut.user_on_time_rate,
    dt.driver_tasks_completed,
    dt.avg_driver_completion_hours,
    dt.driver_on_time_rate
FROM core.employees e
LEFT JOIN (
    SELECT 
        assigned_to,
        COUNT(*) as user_tasks_completed,
        AVG(EXTRACT(EPOCH FROM (completed_at - created_at))/3600)::DECIMAL(10,2) as avg_user_completion_hours,
        ROUND(
            COUNT(CASE WHEN completed_at <= due_date THEN 1 END) * 100.0 / 
            NULLIF(COUNT(*), 0), 2
        ) as user_on_time_rate
    FROM tasks.user_taskboard
    WHERE status = 'completed' 
        AND completed_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY assigned_to
) ut ON e.id = ut.assigned_to
LEFT JOIN (
    SELECT 
        assigned_to,
        COUNT(*) as driver_tasks_completed,
        AVG(EXTRACT(EPOCH FROM (completed_at - created_at))/3600)::DECIMAL(10,2) as avg_driver_completion_hours,
        ROUND(
            COUNT(CASE WHEN completed_at <= (scheduled_date + scheduled_time)::TIMESTAMP THEN 1 END) * 100.0 / 
            NULLIF(COUNT(*), 0), 2
        ) as driver_on_time_rate
    FROM tasks.drivers_taskboard
    WHERE status = 'completed' 
        AND completed_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY assigned_to
) dt ON e.id = dt.assigned_to
WHERE e.status = 'active'
    AND (ut.user_tasks_completed > 0 OR dt.driver_tasks_completed > 0)
ORDER BY e.role, e.surname;

-- Customer service metrics
CREATE VIEW system.customer_service_metrics AS
SELECT 
    c.id as customer_id,
    c.customer_name,
    c.is_company,
    COUNT(i.id) as total_interactions,
    AVG(
        CASE WHEN ut.started_at IS NOT NULL THEN
            EXTRACT(EPOCH FROM (ut.started_at - i.created_at))/3600
        END
    )::DECIMAL(10,2) as avg_response_hours,
    AVG(
        CASE WHEN ut.completed_at IS NOT NULL THEN
            EXTRACT(EPOCH FROM (ut.completed_at - i.created_at))/3600
        END
    )::DECIMAL(10,2) as avg_completion_hours,
    COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) as completed_on_time,
    ROUND(
        COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN ut.status = 'completed' THEN 1 END), 0), 2
    ) as on_time_percentage
FROM core.customers c
JOIN interactions.interactions i ON c.id = i.customer_id
LEFT JOIN tasks.user_taskboard ut ON i.id = ut.interaction_id
WHERE i.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.id, c.customer_name, c.is_company
HAVING COUNT(i.id) >= 2
ORDER BY on_time_percentage DESC, avg_completion_hours ASC;

-- =============================================================================
-- EQUIPMENT AND OPERATIONAL VIEWS
-- =============================================================================

-- Equipment utilization
CREATE VIEW system.equipment_utilization AS
SELECT 
    ec.id as equipment_id,
    ec.category_code,
    ec.category_name,
    COUNT(cel.id) as total_requests,
    COUNT(CASE WHEN i.interaction_type = 'hire' THEN 1 END) as hire_requests,
    COUNT(CASE WHEN i.interaction_type = 'quote' THEN 1 END) as quote_requests,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs,
    AVG(cel.hire_duration) as avg_hire_duration
FROM core.equipment_categories ec
LEFT JOIN interactions.component_equipment_list cel ON ec.id = cel.equipment_category_id
LEFT JOIN interactions.interactions i ON cel.interaction_id = i.id
LEFT JOIN tasks.drivers_task_equipment dte ON ec.id = dte.equipment_category_id
LEFT JOIN tasks.drivers_taskboard dt ON dte.drivers_task_id = dt.id
WHERE ec.is_active = true
    AND (i.created_at >= CURRENT_DATE - INTERVAL '90 days' OR i.created_at IS NULL)
GROUP BY ec.id, ec.category_code, ec.category_name
ORDER BY total_requests DESC;

-- Daily operations schedule
CREATE VIEW system.daily_operations AS
SELECT 
    dt.scheduled_date,
    COUNT(dt.id) as total_scheduled,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks,
    COUNT(CASE WHEN dt.status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN dt.status IN ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4') THEN 1 END) as pending,
    SUM(dt.estimated_duration) as total_estimated_minutes,
    COUNT(DISTINCT dt.assigned_to) as drivers_required
FROM tasks.drivers_taskboard dt
WHERE dt.scheduled_date BETWEEN CURRENT_DATE - INTERVAL '7 days' AND CURRENT_DATE + INTERVAL '14 days'
GROUP BY dt.scheduled_date
ORDER BY dt.scheduled_date ASC;

-- =============================================================================
-- SECURITY AND AUDIT VIEWS
-- =============================================================================

-- Recent login activity
CREATE VIEW security.recent_login_activity AS
SELECT 
    la.username,
    e.name || ' ' || e.surname as employee_name,
    e.role,
    la.success,
    la.failure_reason,
    la.ip_address,
    la.created_at as login_time
FROM security.login_attempts la
LEFT JOIN security.employee_auth ea ON la.username = ea.username
LEFT JOIN core.employees e ON ea.employee_id = e.id
WHERE la.created_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY la.created_at DESC;

-- System audit trail
CREATE VIEW security.audit_trail AS
SELECT 
    al.id,
    e.name || ' ' || e.surname as employee_name,
    e.role,
    al.action,
    al.table_name,
    al.record_id,
    al.ip_address,
    al.created_at
FROM security.audit_log al
LEFT JOIN core.employees e ON al.employee_id = e.id
WHERE al.created_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY al.created_at DESC;

-- =============================================================================
-- BUSINESS INTELLIGENCE VIEWS
-- =============================================================================

-- Weekly performance trends
CREATE VIEW system.weekly_trends AS
SELECT 
    DATE_TRUNC('week', period_date)::DATE as week_starting,
    SUM(period_data.interactions_created) as interactions_created,
    SUM(period_data.user_tasks_completed) as user_tasks_completed,
    SUM(period_data.driver_tasks_completed) as driver_tasks_completed,
    COUNT(DISTINCT period_data.customers_served) as unique_customers_served,
    SUM(period_data.equipment_requests) as equipment_requests
FROM (
    SELECT 
        i.created_at::DATE as period_date,
        COUNT(DISTINCT i.id) as interactions_created,
        COUNT(DISTINCT CASE WHEN ut.status = 'completed' AND ut.completed_at::DATE = i.created_at::DATE THEN ut.id END) as user_tasks_completed,
        COUNT(DISTINCT CASE WHEN dt.status = 'completed' AND dt.completed_at::DATE = i.created_at::DATE THEN dt.id END) as driver_tasks_completed,
        COUNT(DISTINCT i.customer_id) as customers_served,
        COUNT(DISTINCT cel.id) as equipment_requests
    FROM interactions.interactions i
    LEFT JOIN tasks.user_taskboard ut ON i.id = ut.interaction_id
    LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
    LEFT JOIN interactions.component_equipment_list cel ON i.id = cel.interaction_id
    WHERE i.created_at >= CURRENT_DATE - INTERVAL '12 weeks'
    GROUP BY i.created_at::DATE
) period_data
GROUP BY DATE_TRUNC('week', period_data.period_date)
ORDER BY week_starting DESC;

-- =============================================================================
-- GRANT PERMISSIONS ON VIEWS
-- =============================================================================

-- Grant SELECT permissions to all users on monitoring views
GRANT SELECT ON ALL TABLES IN SCHEMA system TO PUBLIC;
GRANT SELECT ON tasks.active_user_tasks TO PUBLIC;
GRANT SELECT ON tasks.active_driver_tasks TO PUBLIC;
GRANT SELECT ON tasks.task_progress_summary TO PUBLIC;

-- Restrict security views to owners and managers
GRANT SELECT ON security.recent_login_activity TO PUBLIC;
GRANT SELECT ON security.audit_trail TO PUBLIC;

-- =============================================================================
-- NEXT STEP: Run 13_functions_procedures.sql
-- =============================================================================