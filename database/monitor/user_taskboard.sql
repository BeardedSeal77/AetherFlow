-- =============================================================================
-- USER TASKBOARD MONITORING QUERIES
-- =============================================================================
-- Database: task_management
-- Purpose: Monitor user taskboard performance, workload distribution, and task analytics
-- Created: 2025-06-06
-- =============================================================================

-- =============================================================================
-- 1. EMPLOYEE WORKLOAD ANALYSIS
-- =============================================================================

-- Current workload by employee (active tasks only)
SELECT 
    e.name || ' ' || e.surname as employee_name,
    e.role,
    COUNT(ut.id) as total_tasks,
    COUNT(CASE WHEN ut.status = 'pending' THEN 1 END) as pending_tasks,
    COUNT(CASE WHEN ut.status = 'in_progress' THEN 1 END) as in_progress_tasks,
    COUNT(CASE WHEN ut.priority = 'urgent' THEN 1 END) as urgent_tasks,
    COUNT(CASE WHEN ut.priority = 'high' THEN 1 END) as high_priority_tasks,
    COUNT(CASE WHEN ut.due_date < CURRENT_DATE THEN 1 END) as overdue_tasks,
    COUNT(CASE WHEN ut.due_date = CURRENT_DATE THEN 1 END) as due_today_tasks
FROM employees e
LEFT JOIN user_taskboard ut ON e.id = ut.assigned_to 
    AND ut.status NOT IN ('completed', 'cancelled')
WHERE e.status = 'active'
GROUP BY e.id, e.name, e.surname, e.role
ORDER BY total_tasks DESC, urgent_tasks DESC;

-- Employee performance over time (last 30 days)
SELECT 
    e.name || ' ' || e.surname as employee_name,
    e.role,
    COUNT(ut.id) as total_completed,
    AVG(EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600)::decimal(10,2) as avg_completion_hours,
    COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) as completed_on_time,
    COUNT(CASE WHEN ut.completed_at > ut.due_date THEN 1 END) as completed_late,
    ROUND(
        COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) * 100.0 / 
        NULLIF(COUNT(ut.id), 0), 2
    ) as on_time_percentage
FROM employees e
LEFT JOIN user_taskboard ut ON e.id = ut.assigned_to 
    AND ut.status = 'completed'
    AND ut.completed_at >= CURRENT_DATE - INTERVAL '30 days'
WHERE e.status = 'active'
GROUP BY e.id, e.name, e.surname, e.role
HAVING COUNT(ut.id) > 0
ORDER BY on_time_percentage DESC, total_completed DESC;

-- Individual employee task details
-- Replace {EMPLOYEE_ID} with actual employee ID
/*
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
    c.customer_name,
    ct.first_name || ' ' || ct.last_name as customer_contact,
    ut.created_at,
    ut.started_at,
    CASE 
        WHEN ut.started_at IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (COALESCE(ut.completed_at, CURRENT_TIMESTAMP) - ut.started_at))/3600
        ELSE NULL
    END::decimal(10,2) as hours_worked
FROM user_taskboard ut
JOIN interactions i ON ut.interaction_id = i.id
JOIN customers c ON i.customer_id = c.id
LEFT JOIN contacts ct ON i.contact_id = ct.id
WHERE ut.assigned_to = {EMPLOYEE_ID}
    AND ut.status NOT IN ('completed', 'cancelled')
ORDER BY 
    CASE ut.priority 
        WHEN 'urgent' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        WHEN 'low' THEN 4 
    END,
    ut.due_date ASC;
*/

-- =============================================================================
-- 2. CUSTOMER-FOCUSED TASK ANALYSIS
-- =============================================================================

-- Tasks by customer (current and recent)
SELECT 
    c.customer_name,
    c.is_company,
    COUNT(ut.id) as total_tasks,
    COUNT(CASE WHEN ut.status = 'pending' THEN 1 END) as pending_tasks,
    COUNT(CASE WHEN ut.status = 'in_progress' THEN 1 END) as in_progress_tasks,
    COUNT(CASE WHEN ut.status = 'completed' THEN 1 END) as completed_tasks,
    MAX(ut.created_at) as last_task_created,
    STRING_AGG(DISTINCT ut.task_type, ', ') as task_types
FROM customers c
JOIN interactions i ON c.id = i.customer_id
JOIN user_taskboard ut ON i.id = ut.interaction_id
WHERE ut.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.id, c.customer_name, c.is_company
ORDER BY total_tasks DESC, last_task_created DESC;

-- Customer service response times
SELECT 
    c.customer_name,
    COUNT(ut.id) as total_requests,
    AVG(EXTRACT(EPOCH FROM (ut.started_at - ut.created_at))/3600)::decimal(10,2) as avg_response_hours,
    AVG(EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600)::decimal(10,2) as avg_completion_hours,
    COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) as completed_on_time,
    ROUND(
        COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN ut.status = 'completed' THEN 1 END), 0), 2
    ) as on_time_percentage
FROM customers c
JOIN interactions i ON c.id = i.customer_id
JOIN user_taskboard ut ON i.id = ut.interaction_id
WHERE ut.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND ut.status = 'completed'
GROUP BY c.id, c.customer_name
HAVING COUNT(ut.id) >= 2
ORDER BY on_time_percentage DESC, avg_completion_hours ASC;

-- Tasks for specific customer (replace {CUSTOMER_NAME} with actual name)
/*
SELECT 
    ut.id,
    i.reference_number,
    ut.task_type,
    ut.title,
    ut.priority,
    ut.status,
    ut.due_date,
    e.name || ' ' || e.surname as assigned_to,
    ct.first_name || ' ' || ct.last_name as customer_contact,
    ct.phone_number,
    ct.email,
    ut.created_at,
    ut.completed_at,
    ut.completion_notes
FROM user_taskboard ut
JOIN interactions i ON ut.interaction_id = i.id
JOIN customers c ON i.customer_id = c.id
JOIN employees e ON ut.assigned_to = e.id
LEFT JOIN contacts ct ON i.contact_id = ct.id
WHERE LOWER(c.customer_name) LIKE LOWER('%{CUSTOMER_NAME}%')
ORDER BY ut.created_at DESC;
*/

-- =============================================================================
-- 3. TASK TYPE AND PRIORITY ANALYSIS
-- =============================================================================

-- Task distribution by type and status
SELECT 
    ut.task_type,
    COUNT(ut.id) as total_tasks,
    COUNT(CASE WHEN ut.status = 'pending' THEN 1 END) as pending,
    COUNT(CASE WHEN ut.status = 'in_progress' THEN 1 END) as in_progress,
    COUNT(CASE WHEN ut.status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN ut.status = 'cancelled' THEN 1 END) as cancelled,
    ROUND(
        COUNT(CASE WHEN ut.status = 'completed' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(ut.id), 0), 2
    ) as completion_rate,
    AVG(
        CASE WHEN ut.status = 'completed' THEN 
            EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600
        END
    )::decimal(10,2) as avg_completion_hours
FROM user_taskboard ut
WHERE ut.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY ut.task_type
ORDER BY total_tasks DESC;

-- Priority distribution and performance
SELECT 
    ut.priority,
    COUNT(ut.id) as total_tasks,
    COUNT(CASE WHEN ut.status NOT IN ('completed', 'cancelled') THEN 1 END) as active_tasks,
    COUNT(CASE WHEN ut.due_date < CURRENT_DATE AND ut.status NOT IN ('completed', 'cancelled') THEN 1 END) as overdue_tasks,
    AVG(
        CASE WHEN ut.status = 'completed' THEN 
            EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600
        END
    )::decimal(10,2) as avg_completion_hours,
    COUNT(CASE WHEN ut.status = 'completed' AND ut.completed_at <= ut.due_date THEN 1 END) as completed_on_time,
    ROUND(
        COUNT(CASE WHEN ut.status = 'completed' AND ut.completed_at <= ut.due_date THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN ut.status = 'completed' THEN 1 END), 0), 2
    ) as on_time_percentage
FROM user_taskboard ut
WHERE ut.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY ut.priority
ORDER BY 
    CASE ut.priority 
        WHEN 'urgent' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        WHEN 'low' THEN 4 
    END;

-- Task aging analysis (how long tasks have been pending)
SELECT 
    ut.task_type,
    ut.priority,
    COUNT(ut.id) as task_count,
    MIN(CURRENT_DATE - ut.created_at::date) as min_age_days,
    MAX(CURRENT_DATE - ut.created_at::date) as max_age_days,
    AVG(CURRENT_DATE - ut.created_at::date)::decimal(10,1) as avg_age_days,
    COUNT(CASE WHEN CURRENT_DATE - ut.created_at::date > 7 THEN 1 END) as over_week_old,
    COUNT(CASE WHEN CURRENT_DATE - ut.created_at::date > 30 THEN 1 END) as over_month_old
FROM user_taskboard ut
WHERE ut.status IN ('pending', 'in_progress')
GROUP BY ut.task_type, ut.priority
ORDER BY avg_age_days DESC;

-- =============================================================================
-- 4. OPERATIONAL DASHBOARDS
-- =============================================================================

-- Daily task dashboard
SELECT 
    'TODAY OVERVIEW' as metric_type,
    COUNT(ut.id) as total_tasks
FROM user_taskboard ut
WHERE ut.created_at::date = CURRENT_DATE

UNION ALL

SELECT 
    'DUE TODAY',
    COUNT(ut.id)
FROM user_taskboard ut
WHERE ut.due_date = CURRENT_DATE
    AND ut.status NOT IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'OVERDUE',
    COUNT(ut.id)
FROM user_taskboard ut
WHERE ut.due_date < CURRENT_DATE
    AND ut.status NOT IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'URGENT PENDING',
    COUNT(ut.id)
FROM user_taskboard ut
WHERE ut.priority = 'urgent'
    AND ut.status = 'pending'

UNION ALL

SELECT 
    'COMPLETED TODAY',
    COUNT(ut.id)
FROM user_taskboard ut
WHERE ut.completed_at::date = CURRENT_DATE

ORDER BY metric_type;

-- Weekly summary dashboard
SELECT 
    DATE_TRUNC('week', ut.created_at)::date as week_starting,
    COUNT(ut.id) as tasks_created,
    COUNT(CASE WHEN ut.status = 'completed' THEN 1 END) as tasks_completed,
    COUNT(CASE WHEN ut.status = 'pending' THEN 1 END) as tasks_pending,
    COUNT(CASE WHEN ut.priority = 'urgent' THEN 1 END) as urgent_tasks,
    AVG(
        CASE WHEN ut.status = 'completed' THEN 
            EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600
        END
    )::decimal(10,2) as avg_completion_hours
FROM user_taskboard ut
WHERE ut.created_at >= CURRENT_DATE - INTERVAL '8 weeks'
GROUP BY DATE_TRUNC('week', ut.created_at)
ORDER BY week_starting DESC;

-- Task backlog analysis
SELECT 
    e.name || ' ' || e.surname as employee_name,
    e.role,
    COUNT(ut.id) as backlog_count,
    COUNT(CASE WHEN ut.priority = 'urgent' THEN 1 END) as urgent_backlog,
    COUNT(CASE WHEN ut.due_date < CURRENT_DATE THEN 1 END) as overdue_backlog,
    MIN(ut.created_at::date) as oldest_task_date,
    MAX(ut.due_date) as latest_due_date
FROM employees e
JOIN user_taskboard ut ON e.id = ut.assigned_to
WHERE ut.status IN ('pending', 'in_progress')
    AND e.status = 'active'
GROUP BY e.id, e.name, e.surname, e.role
HAVING COUNT(ut.id) > 0
ORDER BY urgent_backlog DESC, overdue_backlog DESC, backlog_count DESC;

-- =============================================================================
-- 5. INTERACTION TYPE CORRELATION
-- =============================================================================

-- Task creation by interaction type
SELECT 
    i.interaction_type,
    COUNT(ut.id) as total_tasks,
    COUNT(DISTINCT ut.task_type) as unique_task_types,
    STRING_AGG(DISTINCT ut.task_type, ', ') as task_types_created,
    AVG(
        CASE WHEN ut.status = 'completed' THEN 
            EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600
        END
    )::decimal(10,2) as avg_completion_hours,
    COUNT(CASE WHEN ut.status = 'completed' THEN 1 END) as completed_tasks,
    ROUND(
        COUNT(CASE WHEN ut.status = 'completed' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(ut.id), 0), 2
    ) as completion_rate
FROM interactions i
JOIN user_taskboard ut ON i.id = ut.interaction_id
WHERE i.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY i.interaction_type
ORDER BY total_tasks DESC;

-- Customer interaction pattern analysis
SELECT 
    c.customer_name,
    c.is_company,
    COUNT(DISTINCT i.id) as total_interactions,
    COUNT(ut.id) as total_tasks,
    ROUND(COUNT(ut.id)::decimal / NULLIF(COUNT(DISTINCT i.id), 0), 2) as tasks_per_interaction,
    STRING_AGG(DISTINCT i.interaction_type, ', ') as interaction_types,
    STRING_AGG(DISTINCT ut.task_type, ', ') as task_types,
    MAX(i.created_at) as last_interaction
FROM customers c
JOIN interactions i ON c.id = i.customer_id
LEFT JOIN user_taskboard ut ON i.id = ut.interaction_id
WHERE i.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY c.id, c.customer_name, c.is_company
HAVING COUNT(DISTINCT i.id) > 1
ORDER BY total_interactions DESC, tasks_per_interaction DESC;

-- =============================================================================
-- 6. TASK DEPENDENCY AND PARENT-CHILD ANALYSIS
-- =============================================================================

-- Parent-child task relationships
SELECT 
    parent.id as parent_task_id,
    parent.title as parent_task_title,
    parent.status as parent_status,
    COUNT(child.id) as child_task_count,
    COUNT(CASE WHEN child.status = 'completed' THEN 1 END) as completed_children,
    COUNT(CASE WHEN child.status = 'pending' THEN 1 END) as pending_children,
    STRING_AGG(child.task_type, ', ') as child_task_types
FROM user_taskboard parent
LEFT JOIN user_taskboard child ON parent.id = child.parent_task_id
WHERE parent.parent_task_id IS NULL  -- Only root parents
GROUP BY parent.id, parent.title, parent.status
HAVING COUNT(child.id) > 0
ORDER BY child_task_count DESC;

-- Orphaned tasks (should have parents but don't)
SELECT 
    ut.id,
    ut.title,
    ut.task_type,
    ut.status,
    ut.created_at,
    i.interaction_type,
    c.customer_name
FROM user_taskboard ut
JOIN interactions i ON ut.interaction_id = i.id
JOIN customers c ON i.customer_id = c.id
WHERE ut.parent_task_id IS NULL
    AND ut.task_type IN ('send_quote', 'process_refund')  -- Tasks that typically should have parents
    AND ut.created_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY ut.created_at DESC;

-- =============================================================================
-- 7. PERFORMANCE METRICS AND KPIs
-- =============================================================================

-- Overall system performance metrics
SELECT 
    'TOTAL ACTIVE TASKS' as kpi,
    COUNT(ut.id)::text as value,
    'Tasks currently in pending or in_progress status' as description
FROM user_taskboard ut
WHERE ut.status IN ('pending', 'in_progress')

UNION ALL

SELECT 
    'AVERAGE COMPLETION TIME',
    AVG(EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600)::decimal(10,2)::text || ' hours',
    'Average time from task creation to completion (last 30 days)'
FROM user_taskboard ut
WHERE ut.status = 'completed' 
    AND ut.completed_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT 
    'ON-TIME COMPLETION RATE',
    ROUND(
        COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) * 100.0 / 
        NULLIF(COUNT(ut.id), 0), 2
    )::text || '%',
    'Percentage of tasks completed by their due date (last 30 days)'
FROM user_taskboard ut
WHERE ut.status = 'completed' 
    AND ut.completed_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT 
    'OVERDUE TASKS',
    COUNT(ut.id)::text,
    'Tasks past their due date and still active'
FROM user_taskboard ut
WHERE ut.due_date < CURRENT_DATE
    AND ut.status NOT IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'MOST BUSY EMPLOYEE',
    e.name || ' ' || e.surname || ' (' || COUNT(ut.id)::text || ' tasks)',
    'Employee with most active tasks'
FROM employees e
JOIN user_taskboard ut ON e.id = ut.assigned_to
WHERE ut.status NOT IN ('completed', 'cancelled')
GROUP BY e.id, e.name, e.surname
ORDER BY COUNT(ut.id) DESC
LIMIT 1;

-- Task completion trends (last 12 weeks)
SELECT 
    DATE_TRUNC('week', ut.completed_at)::date as completion_week,
    COUNT(ut.id) as tasks_completed,
    AVG(EXTRACT(EPOCH FROM (ut.completed_at - ut.created_at))/3600)::decimal(10,2) as avg_completion_hours,
    COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) as completed_on_time,
    ROUND(
        COUNT(CASE WHEN ut.completed_at <= ut.due_date THEN 1 END) * 100.0 / 
        NULLIF(COUNT(ut.id), 0), 2
    ) as on_time_percentage
FROM user_taskboard ut
WHERE ut.status = 'completed'
    AND ut.completed_at >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', ut.completed_at)
ORDER BY completion_week DESC;

-- =============================================================================
-- 8. ALERTS AND CRITICAL TASKS
-- =============================================================================

-- Critical attention needed
SELECT 
    'CRITICAL ALERTS' as alert_type,
    ut.id as task_id,
    i.reference_number,
    ut.title,
    ut.priority,
    ut.due_date,
    CURRENT_DATE - ut.due_date as days_overdue,
    e.name || ' ' || e.surname as assigned_to,
    c.customer_name,
    ct.phone_number as customer_phone
FROM user_taskboard ut
JOIN interactions i ON ut.interaction_id = i.id
JOIN customers c ON i.customer_id = c.id
JOIN employees e ON ut.assigned_to = e.id
LEFT JOIN contacts ct ON i.contact_id = ct.id
WHERE (
    (ut.priority = 'urgent' AND ut.status = 'pending' AND ut.created_at < CURRENT_TIMESTAMP - INTERVAL '2 hours')
    OR (ut.due_date < CURRENT_DATE AND ut.status NOT IN ('completed', 'cancelled'))
    OR (ut.priority = 'high' AND ut.status = 'pending' AND ut.created_at < CURRENT_TIMESTAMP - INTERVAL '24 hours')
)
ORDER BY 
    CASE 
        WHEN ut.priority = 'urgent' AND ut.status = 'pending' THEN 1
        WHEN ut.due_date < CURRENT_DATE THEN 2
        ELSE 3
    END,
    ut.due_date ASC;

-- Stale tasks (no activity for extended periods)
SELECT 
    ut.id,
    ut.title,
    ut.task_type,
    ut.status,
    ut.created_at,
    ut.updated_at,
    CURRENT_DATE - ut.updated_at::date as days_since_update,
    e.name || ' ' || e.surname as assigned_to,
    c.customer_name
FROM user_taskboard ut
JOIN interactions i ON ut.interaction_id = i.id
JOIN customers c ON i.customer_id = c.id
JOIN employees e ON ut.assigned_to = e.id
WHERE ut.status IN ('pending', 'in_progress')
    AND ut.updated_at < CURRENT_TIMESTAMP - INTERVAL '7 days'
ORDER BY ut.updated_at ASC;

-- =============================================================================
-- USAGE INSTRUCTIONS
-- =============================================================================

/*
USAGE EXAMPLES:

1. Check specific employee workload:
   - Uncomment the "Individual employee task details" query
   - Replace {EMPLOYEE_ID} with actual employee ID (e.g., 1, 2, 3)

2. View tasks for specific customer:
   - Uncomment the "Tasks for specific customer" query
   - Replace {CUSTOMER_NAME} with customer name (e.g., "ABC Construction")

3. Monitor daily operations:
   - Run "Daily task dashboard" query each morning
   - Check "Critical attention needed" for urgent items

4. Weekly reporting:
   - Use "Weekly summary dashboard" for management reports
   - Review "Task completion trends" for performance analysis

5. Performance monitoring:
   - Run "Overall system performance metrics" for KPIs
   - Use "Employee performance over time" for reviews

MAINTENANCE NOTES:
- Run these queries regularly to monitor system health
- Adjust time intervals based on business needs
- Add indexes if queries become slow with large datasets
- Consider creating views for frequently used queries
*/