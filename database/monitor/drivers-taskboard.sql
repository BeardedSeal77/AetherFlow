-- =============================================================================
-- DRIVERS TASKBOARD MONITORING QUERIES
-- =============================================================================
-- Database: task_management
-- Purpose: Monitor driver tasks, route optimization, equipment tracking, and field operations
-- Created: 2025-06-06
-- =============================================================================

-- =============================================================================
-- 1. DRIVER WORKLOAD AND ASSIGNMENT ANALYSIS
-- =============================================================================

-- Current driver workload (active tasks by driver)
SELECT 
    COALESCE(e.name || ' ' || e.surname, 'UNASSIGNED') as driver_name,
    e.role,
    COUNT(dt.id) as total_tasks,
    COUNT(CASE WHEN dt.status = 'backlog' THEN 1 END) as backlog_tasks,
    COUNT(CASE WHEN dt.status IN ('driver_1', 'driver_2', 'driver_3', 'driver_4') THEN 1 END) as assigned_tasks,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks,
    COUNT(CASE WHEN dt.priority = 'high' THEN 1 END) as high_priority_tasks,
    COUNT(CASE WHEN dt.scheduled_date = CURRENT_DATE THEN 1 END) as scheduled_today,
    COUNT(CASE WHEN dt.scheduled_date < CURRENT_DATE AND dt.status NOT IN ('completed', 'cancelled') THEN 1 END) as overdue_tasks,
    STRING_AGG(DISTINCT dt.task_type, ', ') as task_types
FROM drivers_taskboard dt
LEFT JOIN employees e ON dt.assigned_to = e.id AND e.role = 'driver'
WHERE dt.status NOT IN ('completed', 'cancelled')
GROUP BY dt.assigned_to, e.name, e.surname, e.role
ORDER BY urgent_tasks DESC, assigned_tasks DESC;

-- Driver performance metrics (last 30 days)
SELECT 
    e.name || ' ' || e.surname as driver_name,
    COUNT(dt.id) as total_completed,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs,
    COUNT(CASE WHEN dt.task_type = 'swap' THEN 1 END) as swaps,
    AVG(dt.estimated_duration) as avg_estimated_duration,
    COUNT(CASE WHEN dt.status_whatsapp = 'yes' THEN 1 END) as customer_notifications_sent,
    ROUND(
        COUNT(CASE WHEN dt.status_whatsapp = 'yes' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dt.id), 0), 2
    ) as notification_rate,
    MIN(dt.scheduled_date) as earliest_task,
    MAX(dt.scheduled_date) as latest_task
FROM employees e
JOIN drivers_taskboard dt ON e.id = dt.assigned_to
WHERE e.role = 'driver' 
    AND e.status = 'active'
    AND dt.status = 'completed'
    AND dt.updated_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY e.id, e.name, e.surname
ORDER BY total_completed DESC;

-- Individual driver schedule (replace {DRIVER_ID} with actual driver ID)
/*
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
    dt.estimated_duration,
    CASE 
        WHEN dt.scheduled_date < CURRENT_DATE THEN 'OVERDUE'
        WHEN dt.scheduled_date = CURRENT_DATE THEN 'TODAY'
        WHEN dt.scheduled_date = CURRENT_DATE + 1 THEN 'TOMORROW'
        ELSE 'FUTURE'
    END as schedule_status,
    dt.status_booked,
    dt.status_driver,
    dt.status_quality_control,
    dt.status_whatsapp,
    dt.equipment_verified,
    dt.site_delivery_instructions
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
WHERE dt.assigned_to = {DRIVER_ID}
    AND dt.status NOT IN ('completed', 'cancelled')
ORDER BY dt.scheduled_date ASC, dt.scheduled_time ASC;
*/

-- Unassigned tasks in backlog (needs immediate attention)
SELECT 
    dt.id,
    i.reference_number,
    dt.task_type,
    dt.priority,
    dt.customer_name,
    dt.contact_name,
    dt.contact_phone,
    dt.site_address,
    dt.equipment_summary,
    dt.scheduled_date,
    dt.scheduled_time,
    dt.estimated_duration,
    CURRENT_DATE - dt.scheduled_date as days_overdue,
    dt.created_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - dt.created_at))/3600 as hours_in_backlog
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
WHERE dt.status = 'backlog'
    AND dt.assigned_to IS NULL
ORDER BY 
    CASE dt.priority 
        WHEN 'urgent' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        WHEN 'low' THEN 4 
    END,
    dt.scheduled_date ASC,
    dt.created_at ASC;

-- =============================================================================
-- 2. TASK TYPE AND OPERATIONAL ANALYSIS
-- =============================================================================

-- Task distribution by type and status
SELECT 
    dt.task_type,
    COUNT(dt.id) as total_tasks,
    COUNT(CASE WHEN dt.status = 'backlog' THEN 1 END) as backlog,
    COUNT(CASE WHEN dt.status IN ('driver_1', 'driver_2', 'driver_3', 'driver_4') THEN 1 END) as assigned,
    COUNT(CASE WHEN dt.status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN dt.status = 'cancelled' THEN 1 END) as cancelled,
    ROUND(
        COUNT(CASE WHEN dt.status = 'completed' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dt.id), 0), 2
    ) as completion_rate,
    AVG(dt.estimated_duration) as avg_estimated_duration,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY dt.task_type
ORDER BY total_tasks DESC;

-- Daily operations schedule
SELECT 
    dt.scheduled_date,
    COUNT(dt.id) as total_scheduled,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs,
    COUNT(CASE WHEN dt.task_type = 'swap' THEN 1 END) as swaps,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks,
    COUNT(CASE WHEN dt.status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN dt.status IN ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4') THEN 1 END) as pending,
    SUM(dt.estimated_duration) as total_estimated_duration,
    COUNT(DISTINCT dt.assigned_to) as drivers_required
FROM drivers_taskboard dt
WHERE dt.scheduled_date BETWEEN CURRENT_DATE - INTERVAL '7 days' AND CURRENT_DATE + INTERVAL '14 days'
GROUP BY dt.scheduled_date
ORDER BY dt.scheduled_date ASC;

-- Equipment tracking across tasks
SELECT 
    ec.category_name,
    ec.category_code,
    COUNT(dte.id) as total_assignments,
    COUNT(CASE WHEN dte.purpose = 'deliver' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dte.purpose = 'collect' THEN 1 END) as collections,
    COUNT(CASE WHEN dte.purpose = 'swap_out' THEN 1 END) as swap_outs,
    COUNT(CASE WHEN dte.purpose = 'swap_in' THEN 1 END) as swap_ins,
    COUNT(CASE WHEN dte.purpose = 'repair' THEN 1 END) as repairs,
    COUNT(CASE WHEN dte.verified = true THEN 1 END) as verified_assignments,
    ROUND(
        COUNT(CASE WHEN dte.verified = true THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dte.id), 0), 2
    ) as verification_rate
FROM equipment_categories ec
JOIN drivers_task_equipment dte ON ec.id = dte.equipment_category_id
JOIN drivers_taskboard dt ON dte.drivers_task_id = dt.id
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY ec.id, ec.category_name, ec.category_code
ORDER BY total_assignments DESC;

-- =============================================================================
-- 3. CUSTOMER SERVICE AND COMMUNICATION TRACKING
-- =============================================================================

-- Customer communication status
SELECT 
    dt.customer_name,
    COUNT(dt.id) as total_tasks,
    COUNT(CASE WHEN dt.contact_whatsapp IS NOT NULL THEN 1 END) as whatsapp_available,
    COUNT(CASE WHEN dt.status_whatsapp = 'yes' THEN 1 END) as whatsapp_sent,
    COUNT(CASE WHEN dt.status_whatsapp = 'no' AND dt.contact_whatsapp IS NOT NULL THEN 1 END) as whatsapp_pending,
    ROUND(
        COUNT(CASE WHEN dt.status_whatsapp = 'yes' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN dt.contact_whatsapp IS NOT NULL THEN 1 END), 0), 2
    ) as whatsapp_completion_rate,
    MAX(dt.scheduled_date) as latest_scheduled_task,
    STRING_AGG(DISTINCT dt.task_type, ', ') as service_types
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY dt.customer_name
HAVING COUNT(dt.id) > 1
ORDER BY whatsapp_completion_rate ASC, total_tasks DESC;

-- Site visit frequency and patterns
SELECT 
    dt.site_address,
    COUNT(dt.id) as total_visits,
    COUNT(DISTINCT dt.customer_name) as unique_customers,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs,
    MIN(dt.scheduled_date) as first_visit,
    MAX(dt.scheduled_date) as last_visit,
    STRING_AGG(DISTINCT dt.customer_name, ', ') as customers
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '90 days'
    AND dt.site_address IS NOT NULL
GROUP BY dt.site_address
HAVING COUNT(dt.id) > 2
ORDER BY total_visits DESC;

-- Customer tasks by specific customer (replace {CUSTOMER_NAME} with actual name)
/*
SELECT 
    dt.id,
    i.reference_number,
    dt.task_type,
    dt.priority,
    dt.status,
    dt.contact_name,
    dt.contact_phone,
    dt.contact_whatsapp,
    dt.site_address,
    dt.equipment_summary,
    dt.scheduled_date,
    dt.scheduled_time,
    dt.status_booked,
    dt.status_driver,
    dt.status_quality_control,
    dt.status_whatsapp,
    COALESCE(e.name || ' ' || e.surname, 'UNASSIGNED') as assigned_driver,
    dt.created_at,
    dt.updated_at
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
LEFT JOIN employees e ON dt.assigned_to = e.id
WHERE LOWER(dt.customer_name) LIKE LOWER('%{CUSTOMER_NAME}%')
ORDER BY dt.scheduled_date DESC, dt.created_at DESC;
*/

-- =============================================================================
-- 4. QUALITY CONTROL AND EQUIPMENT VERIFICATION
-- =============================================================================

-- Quality control progress tracking
SELECT 
    dt.status,
    COUNT(dt.id) as total_tasks,
    COUNT(CASE WHEN dt.status_booked = 'yes' THEN 1 END) as booked_tasks,
    COUNT(CASE WHEN dt.status_driver = 'yes' THEN 1 END) as driver_assigned_tasks,
    COUNT(CASE WHEN dt.status_quality_control = 'yes' THEN 1 END) as qc_completed_tasks,
    COUNT(CASE WHEN dt.status_whatsapp = 'yes' THEN 1 END) as customer_notified_tasks,
    COUNT(CASE WHEN dt.equipment_verified = true THEN 1 END) as equipment_verified_tasks,
    ROUND(
        COUNT(CASE WHEN dt.status_booked = 'yes' AND dt.status_driver = 'yes' AND 
                   dt.status_quality_control = 'yes' AND dt.status_whatsapp = 'yes' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dt.id), 0), 2
    ) as fully_completed_percentage
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND dt.status NOT IN ('cancelled')
GROUP BY dt.status
ORDER BY 
    CASE dt.status 
        WHEN 'backlog' THEN 1 
        WHEN 'driver_1' THEN 2 
        WHEN 'driver_2' THEN 3 
        WHEN 'driver_3' THEN 4 
        WHEN 'driver_4' THEN 5 
        WHEN 'completed' THEN 6 
    END;

-- Equipment verification status by task
SELECT 
    dt.id,
    i.reference_number,
    dt.customer_name,
    dt.task_type,
    dt.equipment_summary,
    COUNT(dte.id) as total_equipment_items,
    COUNT(CASE WHEN dte.verified = true THEN 1 END) as verified_items,
    COUNT(CASE WHEN dte.verified = false THEN 1 END) as unverified_items,
    CASE 
        WHEN COUNT(dte.id) = COUNT(CASE WHEN dte.verified = true THEN 1 END) THEN 'FULLY VERIFIED'
        WHEN COUNT(CASE WHEN dte.verified = true THEN 1 END) = 0 THEN 'NOT VERIFIED'
        ELSE 'PARTIALLY VERIFIED'
    END as verification_status,
    dt.equipment_verified as task_verified_flag,
    dt.status_quality_control,
    dt.scheduled_date
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
LEFT JOIN drivers_task_equipment dte ON dt.id = dte.drivers_task_id
WHERE dt.status NOT IN ('completed', 'cancelled')
GROUP BY dt.id, i.reference_number, dt.customer_name, dt.task_type, dt.equipment_summary, 
         dt.equipment_verified, dt.status_quality_control, dt.scheduled_date
ORDER BY dt.scheduled_date ASC, verification_status ASC;

-- Equipment verification by employee
SELECT 
    e.name || ' ' || e.surname as verifier_name,
    e.role,
    COUNT(dte.id) as total_verifications,
    COUNT(DISTINCT dte.drivers_task_id) as tasks_verified,
    COUNT(DISTINCT dte.equipment_category_id) as unique_equipment_types,
    MIN(dte.verified_at) as first_verification,
    MAX(dte.verified_at) as latest_verification,
    STRING_AGG(DISTINCT ec.category_name, ', ') as equipment_types_verified
FROM employees e
JOIN drivers_task_equipment dte ON e.id = dte.verified_by
JOIN equipment_categories ec ON dte.equipment_category_id = ec.id
WHERE dte.verified = true
    AND dte.verified_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY e.id, e.name, e.surname, e.role
ORDER BY total_verifications DESC;

-- =============================================================================
-- 5. SCHEDULING AND ROUTE OPTIMIZATION
-- =============================================================================

-- Daily driver capacity analysis
SELECT 
    dt.scheduled_date,
    COALESCE(e.name || ' ' || e.surname, 'UNASSIGNED') as driver_name,
    COUNT(dt.id) as scheduled_tasks,
    SUM(dt.estimated_duration) as total_estimated_minutes,
    ROUND(SUM(dt.estimated_duration) / 60.0, 2) as total_estimated_hours,
    MIN(dt.scheduled_time) as earliest_task,
    MAX(dt.scheduled_time) as latest_task,
    STRING_AGG(dt.task_type, ', ') as task_types,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks
FROM drivers_taskboard dt
LEFT JOIN employees e ON dt.assigned_to = e.id
WHERE dt.scheduled_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
    AND dt.status NOT IN ('completed', 'cancelled')
GROUP BY dt.scheduled_date, dt.assigned_to, e.name, e.surname
ORDER BY dt.scheduled_date ASC, total_estimated_hours DESC;

-- Geographic distribution of tasks (by address patterns)
SELECT 
    SPLIT_PART(dt.site_address, ',', -1) as area_city,
    COUNT(dt.id) as total_tasks,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.status = 'completed' THEN 1 END) as completed_tasks,
    COUNT(DISTINCT dt.customer_name) as unique_customers,
    AVG(dt.estimated_duration) as avg_duration_minutes
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND dt.site_address IS NOT NULL
GROUP BY SPLIT_PART(dt.site_address, ',', -1)
HAVING COUNT(dt.id) > 2
ORDER BY total_tasks DESC;

-- Task timing patterns
SELECT 
    EXTRACT(HOUR FROM dt.scheduled_time) as scheduled_hour,
    COUNT(dt.id) as total_tasks,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks,
    AVG(dt.estimated_duration) as avg_duration_minutes
FROM drivers_taskboard dt
WHERE dt.scheduled_time IS NOT NULL
    AND dt.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY EXTRACT(HOUR FROM dt.scheduled_time)
ORDER BY scheduled_hour ASC;

-- =============================================================================
-- 6. OPERATIONAL DASHBOARDS
-- =============================================================================

-- Today's operations dashboard
SELECT 
    'TODAY OVERVIEW' as metric_type,
    COUNT(dt.id)::text as value,
    'Total tasks scheduled for today' as description
FROM drivers_taskboard dt
WHERE dt.scheduled_date = CURRENT_DATE

UNION ALL

SELECT 
    'URGENT TODAY',
    COUNT(dt.id)::text,
    'Urgent priority tasks scheduled today'
FROM drivers_taskboard dt
WHERE dt.scheduled_date = CURRENT_DATE 
    AND dt.priority = 'urgent'

UNION ALL

SELECT 
    'COMPLETED TODAY',
    COUNT(dt.id)::text,
    'Tasks completed today'
FROM drivers_taskboard dt
WHERE dt.updated_at::date = CURRENT_DATE 
    AND dt.status = 'completed'

UNION ALL

SELECT 
    'OVERDUE TASKS',
    COUNT(dt.id)::text,
    'Tasks past scheduled date and still active'
FROM drivers_taskboard dt
WHERE dt.scheduled_date < CURRENT_DATE 
    AND dt.status NOT IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'DRIVERS ACTIVE',
    COUNT(DISTINCT dt.assigned_to)::text,
    'Drivers with tasks assigned today'
FROM drivers_taskboard dt
WHERE dt.scheduled_date = CURRENT_DATE 
    AND dt.assigned_to IS NOT NULL
    AND dt.status NOT IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'BACKLOG COUNT',
    COUNT(dt.id)::text,
    'Unassigned tasks in backlog'
FROM drivers_taskboard dt
WHERE dt.status = 'backlog'

ORDER BY metric_type;

-- Weekly operations summary
SELECT 
    DATE_TRUNC('week', dt.scheduled_date)::date as week_starting,
    COUNT(dt.id) as tasks_scheduled,
    COUNT(CASE WHEN dt.status = 'completed' THEN 1 END) as tasks_completed,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks,
    COUNT(DISTINCT dt.assigned_to) as drivers_utilized,
    SUM(dt.estimated_duration) as total_estimated_minutes
FROM drivers_taskboard dt
WHERE dt.scheduled_date >= CURRENT_DATE - INTERVAL '8 weeks'
GROUP BY DATE_TRUNC('week', dt.scheduled_date)
ORDER BY week_starting DESC;

-- Driver utilization overview
SELECT 
    e.name || ' ' || e.surname as driver_name,
    COUNT(dt.id) as tasks_assigned,
    COUNT(CASE WHEN dt.status = 'completed' THEN 1 END) as tasks_completed,
    COUNT(CASE WHEN dt.scheduled_date = CURRENT_DATE THEN 1 END) as tasks_today,
    COUNT(CASE WHEN dt.scheduled_date > CURRENT_DATE THEN 1 END) as future_tasks,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks,
    SUM(CASE WHEN dt.scheduled_date = CURRENT_DATE THEN dt.estimated_duration ELSE 0 END) as today_workload_minutes,
    MAX(dt.scheduled_date) as latest_scheduled_task
FROM employees e
LEFT JOIN drivers_taskboard dt ON e.id = dt.assigned_to 
    AND dt.status NOT IN ('cancelled')
    AND dt.created_at >= CURRENT_DATE - INTERVAL '30 days'
WHERE e.role = 'driver' AND e.status = 'active'
GROUP BY e.id, e.name, e.surname
ORDER BY tasks_assigned DESC;

-- =============================================================================
-- 7. ALERTS AND CRITICAL MONITORING
-- =============================================================================

-- Critical alerts requiring immediate attention
SELECT 
    'CRITICAL ALERTS' as alert_type,
    dt.id as task_id,
    i.reference_number,
    dt.task_type,
    dt.priority,
    dt.customer_name,
    dt.contact_name,
    dt.contact_phone,
    dt.scheduled_date,
    dt.scheduled_time,
    CASE 
        WHEN dt.priority = 'urgent' AND dt.status = 'backlog' AND dt.assigned_to IS NULL THEN 'URGENT UNASSIGNED'
        WHEN dt.scheduled_date < CURRENT_DATE AND dt.status NOT IN ('completed', 'cancelled') THEN 'OVERDUE'
        WHEN dt.priority = 'urgent' AND dt.status_driver = 'no' THEN 'URGENT NO DRIVER'
        WHEN dt.contact_whatsapp IS NOT NULL AND dt.status_whatsapp = 'no' AND dt.scheduled_date <= CURRENT_DATE + 1 THEN 'CUSTOMER NOT NOTIFIED'
        ELSE 'ATTENTION NEEDED'
    END as alert_reason,
    COALESCE(e.name || ' ' || e.surname, 'UNASSIGNED') as assigned_driver
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
LEFT JOIN employees e ON dt.assigned_to = e.id
WHERE (
    (dt.priority = 'urgent' AND dt.status = 'backlog' AND dt.assigned_to IS NULL)
    OR (dt.scheduled_date < CURRENT_DATE AND dt.status NOT IN ('completed', 'cancelled'))
    OR (dt.priority = 'urgent' AND dt.status_driver = 'no')
    OR (dt.contact_whatsapp IS NOT NULL AND dt.status_whatsapp = 'no' AND dt.scheduled_date <= CURRENT_DATE + 1)
)
ORDER BY 
    CASE 
        WHEN dt.priority = 'urgent' AND dt.status = 'backlog' THEN 1
        WHEN dt.scheduled_date < CURRENT_DATE THEN 2
        WHEN dt.priority = 'urgent' THEN 3
        ELSE 4
    END,
    dt.scheduled_date ASC;

-- Equipment verification alerts
SELECT 
    dt.id,
    i.reference_number,
    dt.customer_name,
    dt.task_type,
    dt.scheduled_date,
    dt.equipment_summary,
    COUNT(dte.id) as total_equipment,
    COUNT(CASE WHEN dte.verified = false THEN 1 END) as unverified_equipment,
    dt.status_quality_control,
    CASE 
        WHEN dt.status_quality_control = 'yes' AND COUNT(CASE WHEN dte.verified = false THEN 1 END) > 0 THEN 'QC MARKED BUT EQUIPMENT UNVERIFIED'
        WHEN dt.scheduled_date <= CURRENT_DATE + 1 AND COUNT(CASE WHEN dte.verified = false THEN 1 END) > 0 THEN 'VERIFICATION NEEDED SOON'
        ELSE 'NEEDS VERIFICATION'
    END as alert_reason
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
LEFT JOIN drivers_task_equipment dte ON dt.id = dte.drivers_task_id
WHERE dt.status NOT IN ('completed', 'cancelled')
    AND dt.equipment_verified = false
GROUP BY dt.id, i.reference_number, dt.customer_name, dt.task_type, 
         dt.scheduled_date, dt.equipment_summary, dt.status_quality_control
HAVING COUNT(CASE WHEN dte.verified = false THEN 1 END) > 0
    OR (dt.status_quality_control = 'yes' AND COUNT(CASE WHEN dte.verified = false THEN 1 END) > 0)
ORDER BY dt.scheduled_date ASC;

-- Communication gaps (customers not notified)
SELECT 
    dt.customer_name,
    dt.contact_name,
    dt.contact_phone,
    dt.contact_whatsapp,
    COUNT(dt.id) as pending_notifications,
    MIN(dt.scheduled_date) as earliest_task_date,
    STRING_AGG(dt.task_type, ', ') as task_types,
    STRING_AGG(i.reference_number, ', ') as reference_numbers
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
WHERE dt.status_whatsapp = 'no'
    AND dt.contact_whatsapp IS NOT NULL
    AND dt.scheduled_date <= CURRENT_DATE + 2  -- Tasks within 2 days
    AND dt.status NOT IN ('completed', 'cancelled')
GROUP BY dt.customer_name, dt.contact_name, dt.contact_phone, dt.contact_whatsapp
ORDER BY earliest_task_date ASC, pending_notifications DESC;

-- =============================================================================
-- 8. PERFORMANCE METRICS AND TRENDS
-- =============================================================================

-- Overall driver operations KPIs
SELECT 
    'TOTAL ACTIVE TASKS' as kpi,
    COUNT(dt.id)::text as value,
    'Tasks in backlog or assigned to drivers' as description
FROM drivers_taskboard dt
WHERE dt.status NOT IN ('completed', 'cancelled')

UNION ALL

SELECT 
    'AVERAGE TASK DURATION',
    AVG(dt.estimated_duration)::decimal(10,1)::text || ' minutes',
    'Average estimated duration for driver tasks'
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT 
    'EQUIPMENT VERIFICATION RATE',
    ROUND(
        COUNT(CASE WHEN dt.equipment_verified = true THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dt.id), 0), 2
    )::text || '%',
    'Percentage of tasks with verified equipment (last 30 days)'
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND dt.status NOT IN ('cancelled')

UNION ALL

SELECT 
    'CUSTOMER NOTIFICATION RATE',
    ROUND(
        COUNT(CASE WHEN dt.status_whatsapp = 'yes' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN dt.contact_whatsapp IS NOT NULL THEN 1 END), 0), 2
    )::text || '%',
    'Percentage of customers notified via WhatsApp (where available)'
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '30 days'

UNION ALL

SELECT 
    'BUSIEST DRIVER',
    (SELECT e.name || ' ' || e.surname || ' (' || COUNT(dt.id)::text || ' tasks)'
     FROM employees e
     JOIN drivers_taskboard dt ON e.id = dt.assigned_to
     WHERE dt.status NOT IN ('completed', 'cancelled')
     GROUP BY e.id, e.name, e.surname
     ORDER BY COUNT(dt.id) DESC
     LIMIT 1),
    'Driver with most active tasks currently assigned'

UNION ALL

SELECT 
    'URGENT BACKLOG',
    COUNT(dt.id)::text,
    'Urgent priority tasks still in backlog (unassigned)'
FROM drivers_taskboard dt
WHERE dt.status = 'backlog' 
    AND dt.priority = 'urgent';

-- Task completion trends by week (last 12 weeks)
SELECT 
    DATE_TRUNC('week', dt.updated_at)::date as completion_week,
    COUNT(dt.id) as tasks_completed,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries_completed,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections_completed,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs_completed,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_completed,
    AVG(dt.estimated_duration) as avg_task_duration,
    COUNT(CASE WHEN dt.status_whatsapp = 'yes' THEN 1 END) as customers_notified
FROM drivers_taskboard dt
WHERE dt.status = 'completed'
    AND dt.updated_at >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', dt.updated_at)
ORDER BY completion_week DESC;

-- Equipment utilization trends
SELECT 
    ec.category_name,
    COUNT(dte.id) as total_usage,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as delivery_usage,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collection_usage,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repair_usage,
    COUNT(CASE WHEN dte.purpose = 'swap_out' THEN 1 END) as breakdown_swaps,
    ROUND(
        COUNT(CASE WHEN dte.verified = true THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dte.id), 0), 2
    ) as verification_rate
FROM equipment_categories ec
JOIN drivers_task_equipment dte ON ec.id = dte.equipment_category_id
JOIN drivers_taskboard dt ON dte.drivers_task_id = dt.id
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '8 weeks'
GROUP BY ec.id, ec.category_name
ORDER BY total_usage DESC;

-- =============================================================================
-- 9. ASSIGNMENT HISTORY AND WORKFLOW TRACKING
-- =============================================================================

-- Task status progression analysis
SELECT 
    dt.id,
    i.reference_number,
    dt.customer_name,
    dt.task_type,
    dt.priority,
    dt.status,
    dt.created_at,
    dt.updated_at,
    EXTRACT(EPOCH FROM (dt.updated_at - dt.created_at))/3600 as total_lifecycle_hours,
    CASE 
        WHEN dt.status = 'backlog' THEN 'Waiting for assignment'
        WHEN dt.status IN ('driver_1', 'driver_2', 'driver_3', 'driver_4') THEN 'Assigned to driver'
        WHEN dt.status = 'completed' THEN 'Completed'
        WHEN dt.status = 'cancelled' THEN 'Cancelled'
        ELSE 'Unknown status'
    END as status_description,
    COALESCE(e.name || ' ' || e.surname, 'UNASSIGNED') as current_driver
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
LEFT JOIN employees e ON dt.assigned_to = e.id
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY dt.created_at DESC;

-- Driver assignment changes (if using assignment history table)
/*
SELECT 
    dt.id,
    i.reference_number,
    dt.customer_name,
    e_old.name || ' ' || e_old.surname as previous_driver,
    e_new.name || ' ' || e_new.surname as new_driver,
    dah.assignment_notes,
    dah.assigned_at,
    dah.unassigned_at,
    EXTRACT(EPOCH FROM (COALESCE(dah.unassigned_at, CURRENT_TIMESTAMP) - dah.assigned_at))/3600 as assignment_duration_hours
FROM drivers_assignment_history dah
JOIN drivers_taskboard dt ON dah.drivers_task_id = dt.id
JOIN interactions i ON dt.interaction_id = i.id
LEFT JOIN employees e_old ON dah.assigned_to = e_old.id
LEFT JOIN employees e_new ON dah.assigned_by = e_new.id
WHERE dah.assigned_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY dah.assigned_at DESC;
*/

-- Task creation patterns by day and time
SELECT 
    EXTRACT(DOW FROM dt.created_at) as day_of_week,
    CASE EXTRACT(DOW FROM dt.created_at)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_name,
    COUNT(dt.id) as tasks_created,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repairs,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_tasks,
    AVG(EXTRACT(HOUR FROM dt.created_at)) as avg_creation_hour
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '8 weeks'
GROUP BY EXTRACT(DOW FROM dt.created_at)
ORDER BY day_of_week;

-- =============================================================================
-- 10. CUSTOMER PATTERNS AND SITE ANALYSIS
-- =============================================================================

-- High-maintenance customers (frequent service calls)
SELECT 
    dt.customer_name,
    COUNT(dt.id) as total_tasks,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repair_calls,
    COUNT(CASE WHEN dt.task_type = 'delivery' THEN 1 END) as deliveries,
    COUNT(CASE WHEN dt.task_type = 'collection' THEN 1 END) as collections,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_calls,
    ROUND(
        COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dt.id), 0), 2
    ) as repair_percentage,
    COUNT(DISTINCT dt.site_address) as unique_sites,
    MIN(dt.created_at) as first_service,
    MAX(dt.created_at) as latest_service
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY dt.customer_name
HAVING COUNT(dt.id) >= 3
ORDER BY repair_percentage DESC, total_tasks DESC;

-- Site complexity analysis (sites requiring multiple visits)
SELECT 
    dt.site_address,
    dt.customer_name,
    COUNT(dt.id) as total_visits,
    COUNT(DISTINCT DATE(dt.scheduled_date)) as unique_visit_dates,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repair_visits,
    COUNT(CASE WHEN dt.priority = 'urgent' THEN 1 END) as urgent_visits,
    STRING_AGG(DISTINCT dt.equipment_summary, ' | ') as equipment_types,
    AVG(dt.estimated_duration) as avg_visit_duration,
    MAX(dt.scheduled_date) as last_scheduled_visit
FROM drivers_taskboard dt
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '60 days'
    AND dt.site_address IS NOT NULL
GROUP BY dt.site_address, dt.customer_name
HAVING COUNT(dt.id) >= 3
ORDER BY total_visits DESC, repair_visits DESC;

-- Equipment breakdown patterns by customer
SELECT 
    dt.customer_name,
    ec.category_name as equipment_type,
    COUNT(dte.id) as total_assignments,
    COUNT(CASE WHEN dte.purpose = 'swap_out' THEN 1 END) as breakdown_swaps,
    COUNT(CASE WHEN dt.task_type = 'repair' THEN 1 END) as repair_calls,
    ROUND(
        COUNT(CASE WHEN dte.purpose = 'swap_out' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(dte.id), 0), 2
    ) as breakdown_rate,
    MIN(dt.created_at) as first_assignment,
    MAX(dt.created_at) as latest_assignment
FROM drivers_taskboard dt
JOIN drivers_task_equipment dte ON dt.id = dte.drivers_task_id
JOIN equipment_categories ec ON dte.equipment_category_id = ec.id
WHERE dt.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY dt.customer_name, ec.id, ec.category_name
HAVING COUNT(dte.id) >= 2
ORDER BY breakdown_rate DESC, total_assignments DESC;

-- =============================================================================
-- USAGE INSTRUCTIONS AND MONITORING GUIDELINES
-- =============================================================================

/*
USAGE EXAMPLES:

1. Check specific driver workload:
   - Uncomment the "Individual driver schedule" query
   - Replace {DRIVER_ID} with actual driver employee ID

2. Monitor customer tasks:
   - Uncomment the "Customer tasks by specific customer" query
   - Replace {CUSTOMER_NAME} with customer name (e.g., "ABC Construction")

3. Daily operations monitoring:
   - Run "Today's operations dashboard" each morning
   - Check "Critical alerts" for urgent attention items
   - Review "Unassigned tasks in backlog" for assignment needs

4. Weekly planning:
   - Use "Daily driver capacity analysis" for next week planning
   - Review "Weekly operations summary" for trends
   - Check "Driver utilization overview" for workload balance

5. Quality control monitoring:
   - Run "Equipment verification status by task" for QC oversight
   - Check "Equipment verification alerts" for pending verifications
   - Monitor "Quality control progress tracking" for process compliance

6. Customer service monitoring:
   - Use "Customer communication status" for WhatsApp notifications
   - Check "Communication gaps" for pending customer notifications
   - Review "High-maintenance customers" for service patterns

DASHBOARD RECOMMENDATIONS:

MORNING BRIEFING (Run Daily):
- Today's operations dashboard
- Critical alerts requiring immediate attention
- Unassigned tasks in backlog
- Equipment verification alerts

OPERATIONAL MONITORING (Run Multiple Times Daily):
- Driver workload analysis
- Equipment verification status
- Communication gaps
- Critical alerts

WEEKLY PLANNING (Run Weekly):
- Weekly operations summary
- Driver utilization overview
- Daily driver capacity analysis (next 7 days)
- Customer patterns analysis

MONTHLY REPORTING (Run Monthly):
- Driver performance metrics
- Task completion trends
- Equipment utilization trends
- Customer service metrics

PERFORMANCE MONITORING:
- Overall driver operations KPIs
- Task type and operational analysis
- Quality control progress tracking
- Equipment verification by employee

ALERTS TO MONITOR:
1. Urgent tasks unassigned for >2 hours
2. Tasks overdue (past scheduled date)
3. Equipment unverified for tasks due within 24 hours
4. Customers not notified for tasks within 48 hours
5. Quality control marked complete but equipment unverified

MAINTENANCE NOTES:
- Review these queries weekly for performance
- Add indexes on frequently filtered columns
- Consider archiving completed tasks older than 6 months
- Monitor query execution times and optimize as needed
- Update geographic analysis based on actual address patterns
*/