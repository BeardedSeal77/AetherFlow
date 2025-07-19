-- =============================================================================
-- DATABASE VIEWS - Equipment Hire System
-- =============================================================================
-- This script creates all database views for the equipment hire system
-- Run this after creating all stored procedures

\echo 'Creating database views...'

-- Set search path
SET search_path TO core, equipment, interactions, tasks, system, public;

-- =============================================================================
-- EQUIPMENT AND ACCESSORIES VIEWS
-- =============================================================================

-- View: Equipment with default accessories
CREATE OR REPLACE VIEW v_equipment_default_accessories AS
SELECT 
    et.id as equipment_type_id,
    et.type_code,
    et.type_name,
    a.id as accessory_id,
    a.accessory_code,
    a.accessory_name,
    ea.default_quantity,
    a.unit_of_measure,
    a.unit_rate,
    (ea.default_quantity * a.unit_rate) as default_cost
FROM equipment.equipment_types et
JOIN equipment.equipment_accessories ea ON et.id = ea.equipment_type_id
JOIN equipment.accessories a ON ea.accessory_id = a.id
WHERE ea.accessory_type = 'default'
  AND et.is_active = true
  AND a.status = 'active'
ORDER BY et.type_name, a.accessory_name;

COMMENT ON VIEW v_equipment_default_accessories IS 'Equipment types with their default accessories and costs';

-- View: All equipment-accessory relationships
CREATE OR REPLACE VIEW v_equipment_all_accessories AS
SELECT 
    et.id as equipment_type_id,
    et.type_code,
    et.type_name,
    a.id as accessory_id,
    a.accessory_code,
    a.accessory_name,
    ea.default_quantity,
    ea.accessory_type,
    a.unit_of_measure,
    a.unit_rate,
    (ea.default_quantity * a.unit_rate) as default_cost,
    a.status as accessory_status,
    et.is_active as equipment_type_active
FROM equipment.equipment_types et
JOIN equipment.equipment_accessories ea ON et.id = ea.equipment_type_id
JOIN equipment.accessories a ON ea.accessory_id = a.id
ORDER BY et.type_name, ea.accessory_type, a.accessory_name;

COMMENT ON VIEW v_equipment_all_accessories IS 'All equipment-accessory relationships including optional accessories';

-- View: Accessories with equipment context
CREATE OR REPLACE VIEW v_accessories_with_equipment AS
SELECT 
    a.id as accessory_id,
    a.accessory_code,
    a.accessory_name,
    a.category,
    a.unit_of_measure,
    a.unit_rate,
    a.status,
    COUNT(ea.equipment_type_id) as equipment_types_count,
    STRING_AGG(et.type_name, ', ' ORDER BY et.type_name) as equipment_types,
    SUM(CASE WHEN ea.accessory_type = 'default' THEN ea.default_quantity ELSE 0 END) as total_default_quantity,
    SUM(CASE WHEN ea.accessory_type = 'optional' THEN ea.default_quantity ELSE 0 END) as total_optional_quantity
FROM equipment.accessories a
LEFT JOIN equipment.equipment_accessories ea ON a.id = ea.accessory_id
LEFT JOIN equipment.equipment_types et ON ea.equipment_type_id = et.id AND et.is_active = true
WHERE a.status = 'active'
GROUP BY a.id, a.accessory_code, a.accessory_name, a.category, a.unit_of_measure, a.unit_rate, a.status
ORDER BY a.accessory_name;

COMMENT ON VIEW v_accessories_with_equipment IS 'Accessories with summary of which equipment types use them';

-- =============================================================================
-- HIRE AND INTERACTION VIEWS
-- =============================================================================

-- View: Hire summary with allocation status
CREATE OR REPLACE VIEW v_hire_summary AS
SELECT 
    i.id as interaction_id,
    i.reference_number,
    i.status,
    c.customer_name,
    i.hire_start_date,
    i.hire_end_date,
    i.delivery_date,
    COUNT(iet.id) as equipment_types_count,
    SUM(iet.quantity) as total_equipment_booked,
    COUNT(ie.id) as total_equipment_allocated,
    CASE 
        WHEN SUM(iet.quantity) = COUNT(ie.id) THEN 'Fully Allocated'
        WHEN COUNT(ie.id) > 0 THEN 'Partially Allocated'
        ELSE 'Not Allocated'
    END as allocation_status,
    dt.status as driver_task_status,
    dt.equipment_allocated,
    dt.equipment_verified
FROM interactions.interactions i
JOIN core.customers c ON i.customer_id = c.id
LEFT JOIN interactions.interaction_equipment_types iet ON i.id = iet.interaction_id
LEFT JOIN interactions.interaction_equipment ie ON i.id = ie.interaction_id
LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
WHERE i.interaction_type = 'hire'
GROUP BY 
    i.id, i.reference_number, i.status, c.customer_name, 
    i.hire_start_date, i.hire_end_date, i.delivery_date,
    dt.status, dt.equipment_allocated, dt.equipment_verified
ORDER BY i.delivery_date DESC, i.created_at DESC;

COMMENT ON VIEW v_hire_summary IS 'Summary view of all hires with allocation and task status';

-- View: Hire accessories detailed
CREATE OR REPLACE VIEW v_hire_accessories_detailed AS
SELECT 
    ia.id as interaction_accessory_id,
    i.id as interaction_id,
    i.reference_number,
    c.customer_name,
    a.accessory_code,
    a.accessory_name,
    ia.quantity,
    ia.accessory_type,
    ia.unit_rate,
    (ia.quantity * ia.unit_rate) as total_cost,
    et.type_name as equipment_type,
    iet.quantity as equipment_quantity,
    CASE 
        WHEN ia.accessory_type = 'default' THEN 'Auto-calculated'
        WHEN ia.accessory_type = 'optional' THEN 'User-selected'
        ELSE 'Manual'
    END as selection_method
FROM interactions.interaction_accessories ia
JOIN interactions.interactions i ON ia.interaction_id = i.id
JOIN core.customers c ON i.customer_id = c.id
JOIN equipment.accessories a ON ia.accessory_id = a.id
LEFT JOIN interactions.interaction_equipment_types iet ON ia.equipment_type_booking_id = iet.id
LEFT JOIN equipment.equipment_types et ON iet.equipment_type_id = et.id
WHERE i.interaction_type = 'hire'
ORDER BY i.reference_number, ia.accessory_type, a.accessory_name;

COMMENT ON VIEW v_hire_accessories_detailed IS 'Detailed view of hire accessories with context and calculations';

-- =============================================================================
-- DRIVER AND TASK VIEWS
-- =============================================================================

-- View: Driver taskboard summary
CREATE OR REPLACE VIEW v_driver_tasks_summary AS
SELECT 
    dt.id as task_id,
    dt.task_type,
    dt.status,
    dt.priority,
    dt.customer_name,
    dt.contact_name,
    dt.contact_phone,
    dt.scheduled_date,
    dt.scheduled_time,
    i.reference_number,
    i.hire_start_date,
    dt.equipment_allocated,
    dt.equipment_verified,
    CASE 
        WHEN dt.assigned_driver_id IS NOT NULL 
        THEN (e.name || ' ' || e.surname)
        ELSE 'Unassigned'
    END as assigned_driver,
    COUNT(iet.id) as equipment_types_count,
    SUM(iet.quantity) as total_equipment
FROM tasks.drivers_taskboard dt
JOIN interactions.interactions i ON dt.interaction_id = i.id
LEFT JOIN core.employees e ON dt.assigned_driver_id = e.id
LEFT JOIN interactions.interaction_equipment_types iet ON i.id = iet.interaction_id
GROUP BY 
    dt.id, dt.task_type, dt.status, dt.priority, dt.customer_name,
    dt.contact_name, dt.contact_phone, dt.scheduled_date, dt.scheduled_time,
    i.reference_number, i.hire_start_date, dt.equipment_allocated, 
    dt.equipment_verified, dt.assigned_driver_id, e.name, e.surname
ORDER BY 
    dt.scheduled_date, dt.scheduled_time, 
    CASE dt.priority 
        WHEN 'urgent' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        ELSE 4 
    END;

COMMENT ON VIEW v_driver_tasks_summary IS 'Summary view of driver tasks with hire and equipment context';

-- =============================================================================
-- EQUIPMENT AVAILABILITY VIEWS
-- =============================================================================

-- View: Equipment availability status
CREATE OR REPLACE VIEW v_equipment_availability AS
SELECT 
    e.id as equipment_id,
    e.asset_code,
    et.type_name,
    et.type_code,
    e.model,
    e.serial_number,
    e.condition,
    e.status,
    e.location,
    e.last_service_date,
    e.next_service_due,
    CASE 
        WHEN e.next_service_due IS NOT NULL AND e.next_service_due < CURRENT_DATE 
        THEN true 
        ELSE false 
    END as is_overdue_service,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM interactions.interaction_equipment ie
            JOIN interactions.interactions i ON ie.interaction_id = i.id
            WHERE ie.equipment_id = e.id
            AND i.status NOT IN ('cancelled', 'completed')
            AND i.hire_end_date >= CURRENT_DATE
        ) THEN 'On Hire'
        WHEN e.status = 'available' THEN 'Available'
        WHEN e.status = 'maintenance' THEN 'In Maintenance'
        WHEN e.status = 'damaged' THEN 'Damaged'
        ELSE 'Unknown'
    END as availability_status
FROM equipment.equipment e
JOIN equipment.equipment_types et ON e.equipment_type_id = et.id
WHERE e.is_active = true AND et.is_active = true
ORDER BY et.type_name, e.asset_code;

COMMENT ON VIEW v_equipment_availability IS 'Current availability status of all equipment units';

-- =============================================================================
-- VIEW PERMISSIONS
-- =============================================================================

\echo 'Setting view permissions...'

-- Grant select permissions on all views
GRANT SELECT ON v_equipment_default_accessories TO PUBLIC;
GRANT SELECT ON v_equipment_all_accessories TO PUBLIC;
GRANT SELECT ON v_accessories_with_equipment TO PUBLIC;
GRANT SELECT ON v_hire_summary TO PUBLIC;
GRANT SELECT ON v_hire_accessories_detailed TO PUBLIC;
GRANT SELECT ON v_driver_tasks_summary TO PUBLIC;
GRANT SELECT ON v_equipment_availability TO PUBLIC;

\echo 'Database views created successfully!'
\echo '==================================================================='
\echo 'Available Views:'
\echo '- v_equipment_default_accessories: Equipment with default accessories'
\echo '- v_equipment_all_accessories: All equipment-accessory relationships'
\echo '- v_accessories_with_equipment: Accessories with equipment context'
\echo '- v_hire_summary: Hire summary with allocation status'
\echo '- v_hire_accessories_detailed: Detailed hire accessories'
\echo '- v_driver_tasks_summary: Driver taskboard summary'
\echo '- v_equipment_availability: Equipment availability status'
\echo '==================================================================='