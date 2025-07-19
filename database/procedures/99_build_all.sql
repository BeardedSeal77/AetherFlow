-- =============================================================================
-- BUILD ALL STORED PROCEDURES
-- =============================================================================
-- This script builds all stored procedures in the correct order
-- Run this after creating the schema and loading sample data

\echo 'Building Equipment Hire System Stored Procedures...'

-- Set search path
SET search_path TO core, equipment, interactions, tasks, system, public;

-- 1. Utility procedures (dependencies for others)
\echo 'Building utility procedures...'
\i database/procedures/01_utility_procedures.sql

-- 2. Equipment procedures (equipment selection and management)
\echo 'Building equipment procedures...'
\i database/procedures/02_equipment_procedures.sql

-- 3. Hire procedures (hire creation and management)
\echo 'Building hire procedures...'
\i database/procedures/03_hire_procedures.sql

-- 4. Allocation procedures (Phase 2 equipment allocation)
\echo 'Building allocation procedures...'
\i database/procedures/04_allocation_procedures.sql

-- =============================================================================
-- CREATE USEFUL VIEWS
-- =============================================================================

\echo 'Creating database views...'

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
LEFT JOIN interactions.interaction_equipment ie ON iet.id = ie.equipment_type_booking_id
LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id AND dt.task_type = 'delivery'
WHERE i.interaction_type = 'hire'
GROUP BY 
    i.id, i.reference_number, i.status, c.customer_name, 
    i.hire_start_date, i.hire_end_date, i.delivery_date,
    dt.status, dt.equipment_allocated, dt.equipment_verified
ORDER BY i.delivery_date, i.created_at;

-- View: Equipment utilization
CREATE OR REPLACE VIEW v_equipment_utilization AS
SELECT 
    et.id as equipment_type_id,
    et.type_code,
    et.type_name,
    COUNT(e.id) as total_units,
    COUNT(CASE WHEN e.status = 'available' THEN 1 END) as available_units,
    COUNT(CASE WHEN e.status = 'rented' THEN 1 END) as rented_units,
    COUNT(CASE WHEN e.status = 'maintenance' THEN 1 END) as maintenance_units,
    COUNT(CASE WHEN e.status = 'repair' THEN 1 END) as repair_units,
    ROUND(
        (COUNT(CASE WHEN e.status = 'rented' THEN 1 END)::DECIMAL / 
         NULLIF(COUNT(e.id), 0)) * 100, 2
    ) as utilization_percentage
FROM equipment.equipment_types et
LEFT JOIN equipment.equipment e ON et.id = e.equipment_type_id
WHERE et.is_active = true
GROUP BY et.id, et.type_code, et.type_name
ORDER BY utilization_percentage DESC;

-- View: Driver taskboard summary
CREATE OR REPLACE VIEW v_driver_taskboard AS
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

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

\echo 'Setting up permissions...'

-- Grant execute permissions on all functions to appropriate roles
-- (In a production environment, you would create specific roles)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC;

-- Grant select permissions on views
GRANT SELECT ON ALL TABLES IN SCHEMA equipment TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA interactions TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA tasks TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA system TO PUBLIC;

\echo 'All stored procedures and views created successfully!'

-- =============================================================================
-- TEST THE INSTALLATION
-- =============================================================================

\echo 'Testing installation...'

-- Test reference number generation
SELECT 'Testing reference number generation:' as test;
SELECT sp_generate_reference_number('hire') as sample_reference;

-- Test customer selection
SELECT 'Testing customer selection:' as test;
SELECT COUNT(*) as customer_count FROM sp_get_customers_for_selection();

-- Test equipment types
SELECT 'Testing equipment types:' as test;
SELECT COUNT(*) as equipment_types_count FROM sp_get_available_equipment_types();

-- Test dashboard summary
SELECT 'Testing dashboard summary:' as test;
SELECT * FROM sp_get_hire_dashboard_summary();

\echo 'Installation test completed successfully!'
\echo '==================================================================='
\echo 'Equipment Hire System Database Setup Complete!'
\echo '==================================================================='
\echo 'Next steps:'
\echo '1. Run: SELECT * FROM sp_get_hire_dashboard_summary();'
\echo '2. Create a test hire: Use the web interface or call stored procedures'
\echo '3. Test allocation workflow: Use sp_get_bookings_for_allocation()'
\echo '==================================================================='
