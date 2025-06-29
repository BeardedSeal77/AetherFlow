-- =============================================================================
-- COMPLETE HIRE INTERACTION OVERVIEW
-- =============================================================================
-- Shows the sample hire interaction with all related data

SELECT 
    '=== INTERACTION DETAILS ===' as section,
    NULL::text as detail_1,
    NULL::text as detail_2,
    NULL::text as detail_3,
    NULL::text as detail_4
    
UNION ALL

SELECT 
    'Reference Number' as section,
    i.reference_number as detail_1,
    'Status: ' || i.status as detail_2,
    'Created: ' || i.created_at::date::text as detail_3,
    'Type: ' || i.interaction_type as detail_4
FROM interactions.interactions i 
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    '=== CUSTOMER & CONTACT ===' as section,
    NULL::text as detail_1,
    NULL::text as detail_2,
    NULL::text as detail_3,
    NULL::text as detail_4

UNION ALL

SELECT 
    'Customer' as section,
    c.customer_name as detail_1,
    'Code: ' || c.customer_code as detail_2,
    'Credit Limit: R' || c.credit_limit::text as detail_3,
    'Terms: ' || c.payment_terms as detail_4
FROM interactions.interactions i
JOIN core.customers c ON i.customer_id = c.id
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    'Contact Person' as section,
    (ct.first_name || ' ' || ct.last_name) as detail_1,
    'Title: ' || COALESCE(ct.job_title, 'N/A') as detail_2,
    'Phone: ' || COALESCE(ct.phone_number, 'N/A') as detail_3,
    'WhatsApp: ' || COALESCE(ct.whatsapp_number, 'N/A') as detail_4
FROM interactions.interactions i
JOIN core.contacts ct ON i.contact_id = ct.id
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    '=== DELIVERY SITE ===' as section,
    NULL::text as detail_1,
    NULL::text as detail_2,
    NULL::text as detail_3,
    NULL::text as detail_4

UNION ALL

SELECT 
    'Site Details' as section,
    dt.site_address as detail_1,
    'Contact: ' || COALESCE(dt.contact_name, 'N/A') as detail_2,
    'Phone: ' || COALESCE(dt.contact_phone, 'N/A') as detail_3,
    'Scheduled: ' || COALESCE(dt.scheduled_date::text || ' ' || dt.scheduled_time::text, 'Not scheduled') as detail_4
FROM interactions.interactions i
JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    '=== EQUIPMENT BOOKED ===' as section,
    NULL::text as detail_1,
    NULL::text as detail_2,
    NULL::text as detail_3,
    NULL::text as detail_4

UNION ALL

SELECT 
    'Equipment' as section,
    et.type_name as detail_1,
    'Code: ' || et.type_code as detail_2,
    'Quantity: ' || iet.quantity::text as detail_3,
    'Status: ' || iet.booking_status as detail_4
FROM interactions.interactions i
JOIN interactions.interaction_equipment_types iet ON i.id = iet.interaction_id
JOIN core.equipment_types et ON iet.equipment_type_id = et.id
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    '=== ACCESSORIES ===' as section,
    NULL::text as detail_1,
    NULL::text as detail_2,
    NULL::text as detail_3,
    NULL::text as detail_4

UNION ALL

SELECT 
    'Accessory' as section,
    a.accessory_name as detail_1,
    'Quantity: ' || ia.quantity::text as detail_2,
    'Type: ' || ia.accessory_type as detail_3,
    'Billing: ' || a.billing_method as detail_4
FROM interactions.interactions i
JOIN interactions.interaction_accessories ia ON i.id = ia.interaction_id
JOIN core.accessories a ON ia.accessory_id = a.id
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    '=== DRIVER TASK STATUS ===' as section,
    NULL::text as detail_1,
    NULL::text as detail_2,
    NULL::text as detail_3,
    NULL::text as detail_4

UNION ALL

SELECT 
    'Task Details' as section,
    'Task Type: ' || dt.task_type as detail_1,
    'Status: ' || dt.status as detail_2,
    'Priority: ' || dt.priority as detail_3,
    'Assigned: ' || COALESCE(emp.name || ' ' || emp.surname, 'Unassigned') as detail_4
FROM interactions.interactions i
JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
LEFT JOIN core.employees emp ON dt.assigned_to = emp.id
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    'Progress Status' as section,
    'Booked: ' || dt.status_booked as detail_1,
    'Driver: ' || dt.status_driver as detail_2,
    'Quality Control: ' || dt.status_quality_control as detail_3,
    'WhatsApp: ' || dt.status_whatsapp as detail_4
FROM interactions.interactions i
JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
WHERE i.interaction_type = 'hire'

UNION ALL

SELECT 
    'Equipment Status' as section,
    'Allocated: ' || CASE WHEN dt.equipment_allocated THEN 'Yes' ELSE 'No' END as detail_1,
    'Verified: ' || CASE WHEN dt.equipment_verified THEN 'Yes' ELSE 'No' END as detail_2,
    'Created: ' || dt.created_at::date::text as detail_3,
    'Updated: ' || dt.updated_at::date::text as detail_4
FROM interactions.interactions i
JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
WHERE i.interaction_type = 'hire'

ORDER BY section;