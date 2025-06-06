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