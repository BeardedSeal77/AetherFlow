-- =============================================================================
-- DATA VERIFICATION AND OVERVIEW QUERIES
-- =============================================================================

-- 1. Overview of all customers with their contact information
SELECT 
    c.id as customer_id,
    c.customer_name,
    c.is_company,
    c.credit_limit,
    c.payment_terms,
    ct.first_name || ' ' || ct.last_name as primary_contact,
    ct.phone_number,
    ct.email,
    COUNT(s.id) as site_count
FROM customers c
LEFT JOIN contacts ct ON c.id = ct.customer_id AND ct.is_primary_contact = true
LEFT JOIN sites s ON c.id = s.customer_id AND s.is_active = true
GROUP BY c.id, c.customer_name, c.is_company, c.credit_limit, c.payment_terms, 
         ct.first_name, ct.last_name, ct.phone_number, ct.email
ORDER BY c.customer_name;

-- 2. Equipment catalog with pricing for both customer types
SELECT 
    ec.category_code,
    ec.category_name,
    ec.description,
    ep_individual.price_per_day as individual_day_rate,
    ep_individual.deposit_amount as individual_deposit,
    ep_company.price_per_day as company_day_rate,
    ep_company.deposit_amount as company_deposit,
    ec.default_accessories
FROM equipment_categories ec
LEFT JOIN equipment_pricing ep_individual ON ec.id = ep_individual.equipment_category_id 
    AND ep_individual.customer_type = 'individual' AND ep_individual.is_active = true
LEFT JOIN equipment_pricing ep_company ON ec.id = ep_company.equipment_category_id 
    AND ep_company.customer_type = 'company' AND ep_company.is_active = true
WHERE ec.is_active = true
ORDER BY ec.category_code;

-- 3. Complete site directory with delivery information
SELECT 
    c.customer_name,
    s.site_name,
    s.site_code,
    s.address_line1 || COALESCE(', ' || s.address_line2, '') || ', ' || s.city as full_address,
    s.site_type,
    s.site_contact_name,
    s.site_contact_phone,
    s.delivery_instructions
FROM sites s
JOIN customers c ON s.customer_id = c.id
WHERE s.is_active = true
ORDER BY c.customer_name, s.site_name;

-- 4. Employee roster by role
SELECT 
    role,
    COUNT(*) as employee_count,
    STRING_AGG(name || ' ' || surname, ', ') as employees
FROM employees 
WHERE status = 'active'
GROUP BY role
ORDER BY role;

-- 5. Customer summary for quick reference
SELECT 
    'Companies' as customer_type,
    COUNT(*) as count,
    AVG(credit_limit) as avg_credit_limit
FROM customers 
WHERE is_company = true AND status = 'active'
UNION ALL
SELECT 
    'Individuals',
    COUNT(*),
    AVG(credit_limit)
FROM customers 
WHERE is_company = false AND status = 'active';

-- =============================================================================
-- READY-TO-USE TEST SCENARIOS
-- =============================================================================

-- Scenario 1: Price List Request
-- "John Guy from ABC Construction calls asking for all equipment prices"
SELECT 
    'SCENARIO 1: Price List Request' as scenario,
    c.customer_name,
    ct.first_name || ' ' || ct.last_name as contact_name,
    ct.phone_number,
    ct.email,
    'Company rates apply' as pricing_note
FROM customers c
JOIN contacts ct ON c.id = ct.customer_id AND ct.is_primary_contact = true
WHERE c.customer_name = 'ABC Construction Ltd';

-- Scenario 2: Quote Request  
-- "Peter Parker needs quote for rammer rental (3 days) delivered to warehouse"
SELECT 
    'SCENARIO 2: Quote Request' as scenario,
    c.customer_name,
    ct.first_name || ' ' || ct.last_name as contact_name,
    s.site_name as delivery_site,
    s.address_line1 || COALESCE(', ' || s.address_line2, '') || ', ' || s.city as full_address,
    ec.category_name as equipment,
    ep.price_per_day,
    (ep.price_per_day * 3) as three_day_cost
FROM customers c
JOIN contacts ct ON c.id = ct.customer_id AND ct.is_primary_contact = true
JOIN sites s ON c.id = s.customer_id
JOIN equipment_categories ec ON ec.category_name = 'Rammer'
JOIN equipment_pricing ep ON ec.id = ep.equipment_category_id AND ep.customer_type = 'company'
WHERE c.customer_name = 'XYZ Building Supplies' AND s.site_name = 'Main Warehouse';

-- Scenario 3: Individual Hire Order
-- "John Guy (individual) wants T1000 Breaker for weekend at Kimberly Street"
SELECT 
    'SCENARIO 3: Individual Hire' as scenario,
    c.customer_name,
    ct.phone_number,
    s.site_name,
    s.address_line1,
    ec.category_name as equipment,
    ep.price_per_day,
    ep.deposit_amount
FROM customers c
JOIN contacts ct ON c.id = ct.customer_id
JOIN sites s ON c.id = s.customer_id
JOIN equipment_categories ec ON ec.category_name = 'T1000 Breaker'
JOIN equipment_pricing ep ON ec.id = ep.equipment_category_id AND ep.customer_type = 'individual'
WHERE c.customer_name = 'John Guy' AND s.site_name = 'Kimberly Street Project';

-- =============================================================================
-- SYSTEM READINESS CHECK
-- =============================================================================

SELECT 
    'System Ready for Testing!' as status,
    (SELECT COUNT(*) FROM customers WHERE status = 'active') as active_customers,
    (SELECT COUNT(*) FROM employees WHERE status = 'active') as active_employees,
    (SELECT COUNT(*) FROM equipment_categories WHERE is_active = true) as equipment_types,
    (SELECT COUNT(*) FROM sites WHERE is_active = true) as active_sites;


    -- =============================================================================
-- INTERACTION VALIDATION QUERIES
-- =============================================================================
-- Add these queries to Database/build/sample_data_validation.sql

-- =============================================================================
-- 8. INTERACTIONS OVERVIEW
-- =============================================================================

-- View all interactions with customer and contact details
SELECT 
    i.id,
    i.reference_number,
    i.interaction_type,
    i.status,
    c.customer_name,
    ct.first_name || ' ' || ct.last_name as contact_name,
    ct.phone_number,
    ct.email,
    e.name || ' ' || e.surname as processed_by,
    i.contact_method,
    i.created_at::date as created_date,
    i.notes
FROM interactions i
JOIN customers c ON i.customer_id = c.id
JOIN contacts ct ON i.contact_id = ct.id
JOIN employees e ON i.employee_id = e.id
ORDER BY i.created_at DESC;

-- =============================================================================
-- 9. DRIVER TASKS OVERVIEW
-- =============================================================================

-- View all driver tasks with equipment and status details
SELECT 
    dt.id as task_id,
    i.reference_number,
    dt.task_type,
    dt.status,
    dt.customer_name,
    dt.contact_name,
    dt.contact_phone,
    dt.site_address,
    dt.equipment_summary,
    dt.scheduled_date,
    dt.scheduled_time,
    dt.estimated_duration,
    dt.status_booked,
    dt.status_driver,
    dt.status_quality_control,
    dt.status_whatsapp,
    dt.equipment_verified,
    dt.created_at::date as created_date,
    e.name || ' ' || e.surname as created_by_employee
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
JOIN employees e ON dt.created_by = e.id
ORDER BY dt.created_at DESC;

-- =============================================================================
-- 10. EQUIPMENT ASSIGNMENTS FOR DRIVER TASKS
-- =============================================================================

-- View equipment assignments for driver tasks
SELECT 
    dt.id as task_id,
    i.reference_number,
    dt.customer_name,
    ec.category_name as equipment,
    ec.category_code,
    dte.quantity,
    dte.purpose,
    dte.condition_notes,
    dte.verified,
    CASE 
        WHEN dte.verified THEN 'Verified by ' || ve.name || ' ' || ve.surname || ' on ' || dte.verified_at::date
        ELSE 'Not verified'
    END as verification_status
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
JOIN drivers_task_equipment dte ON dt.id = dte.drivers_task_id
JOIN equipment_categories ec ON dte.equipment_category_id = ec.id
LEFT JOIN employees ve ON dte.verified_by = ve.id
ORDER BY dt.created_at DESC, ec.category_name;

-- =============================================================================
-- 11. HIRE DETAILS AND COMPONENTS
-- =============================================================================

-- View hire interactions with their components
SELECT 
    i.reference_number,
    i.interaction_type,
    c.customer_name,
    ct.first_name || ' ' || ct.last_name as contact_name,
    s.site_name,
    s.address_line1 || ', ' || s.city as site_address,
    hd.deliver_date,
    hd.deliver_time,
    hd.delivery_method,
    hd.special_instructions,
    STRING_AGG(ec.category_name, ', ') as equipment_list,
    SUM(cel.quantity) as total_items
FROM interactions i
JOIN customers c ON i.customer_id = c.id
JOIN contacts ct ON i.contact_id = ct.id
LEFT JOIN component_hire_details hd ON i.id = hd.interaction_id
LEFT JOIN sites s ON hd.site_id = s.id
LEFT JOIN component_equipment_list cel ON i.id = cel.interaction_id
LEFT JOIN equipment_categories ec ON cel.equipment_category_id = ec.id
WHERE i.interaction_type = 'hire'
GROUP BY i.id, i.reference_number, i.interaction_type, c.customer_name, 
         ct.first_name, ct.last_name, s.site_name, s.address_line1, s.city,
         hd.deliver_date, hd.deliver_time, hd.delivery_method, hd.special_instructions
ORDER BY i.created_at DESC;

-- =============================================================================
-- 12. LATEST INTERACTIONS SUMMARY
-- =============================================================================

-- Quick overview of recent interactions
SELECT 
    'LATEST INTERACTIONS (Last 10)' as summary_type,
    COUNT(*) as total_count
FROM (
    SELECT * FROM interactions ORDER BY created_at DESC LIMIT 10
) recent_interactions

UNION ALL

SELECT 
    'TOTAL INTERACTIONS TODAY',
    COUNT(*)
FROM interactions 
WHERE DATE(created_at) = CURRENT_DATE

UNION ALL

SELECT 
    'TOTAL DRIVER TASKS TODAY',
    COUNT(*)
FROM drivers_taskboard 
WHERE DATE(created_at) = CURRENT_DATE

UNION ALL

SELECT 
    'PENDING DRIVER TASKS',
    COUNT(*)
FROM drivers_taskboard 
WHERE status IN ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4');

-- =============================================================================
-- 13. REFERENCE NUMBER VALIDATION
-- =============================================================================

-- Check reference number format compliance
SELECT 
    reference_number,
    interaction_type,
    CASE 
        WHEN reference_number ~ '^[A-Z]{2}[0-9]{9}$' THEN 'Valid Format'
        ELSE 'Invalid Format'
    END as format_check,
    LENGTH(reference_number) as ref_length,
    SUBSTRING(reference_number, 1, 2) as prefix,
    SUBSTRING(reference_number, 3, 6) as date_part,
    SUBSTRING(reference_number, 9, 3) as sequence_part,
    created_at
FROM interactions 
ORDER BY created_at DESC;

-- =============================================================================
-- 14. DRIVER TASK STATUS PROGRESSION
-- =============================================================================

-- View driver task status progression
SELECT 
    status,
    COUNT(*) as task_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM drivers_taskboard 
GROUP BY status
ORDER BY 
    CASE status
        WHEN 'backlog' THEN 1
        WHEN 'driver_1' THEN 2
        WHEN 'driver_2' THEN 3
        WHEN 'driver_3' THEN 4
        WHEN 'driver_4' THEN 5
        WHEN 'completed' THEN 6
        WHEN 'cancelled' THEN 7
        ELSE 8
    END;

-- =============================================================================
-- 15. EQUIPMENT VERIFICATION STATUS
-- =============================================================================

-- Check equipment verification progress
SELECT 
    dt.id as task_id,
    i.reference_number,
    dt.customer_name,
    COUNT(dte.id) as total_equipment,
    COUNT(CASE WHEN dte.verified THEN 1 END) as verified_equipment,
    COUNT(CASE WHEN NOT dte.verified THEN 1 END) as unverified_equipment,
    CASE 
        WHEN COUNT(dte.id) = COUNT(CASE WHEN dte.verified THEN 1 END) THEN 'All Verified'
        WHEN COUNT(CASE WHEN dte.verified THEN 1 END) = 0 THEN 'None Verified'
        ELSE 'Partially Verified'
    END as verification_status,
    dt.equipment_verified as task_verified_flag
FROM drivers_taskboard dt
JOIN interactions i ON dt.interaction_id = i.id
LEFT JOIN drivers_task_equipment dte ON dt.id = dte.drivers_task_id
WHERE dt.status NOT IN ('completed', 'cancelled')
GROUP BY dt.id, i.reference_number, dt.customer_name, dt.equipment_verified
ORDER BY dt.created_at DESC;

-- =============================================================================
-- 16. CONTACT COMMUNICATION STATUS
-- =============================================================================

-- Check WhatsApp communication status
SELECT 
    dt.customer_name,
    dt.contact_name,
    dt.contact_phone,
    dt.contact_whatsapp,
    dt.status_whatsapp,
    dt.scheduled_date,
    CASE 
        WHEN dt.contact_whatsapp IS NOT NULL AND dt.status_whatsapp = 'no' THEN 'Ready for WhatsApp'
        WHEN dt.contact_whatsapp IS NOT NULL AND dt.status_whatsapp = 'yes' THEN 'WhatsApp Sent'
        WHEN dt.contact_whatsapp IS NULL THEN 'No WhatsApp Available'
        ELSE 'Unknown Status'
    END as whatsapp_status
FROM drivers_taskboard dt
WHERE dt.status NOT IN ('completed', 'cancelled')
ORDER BY dt.scheduled_date, dt.customer_name;