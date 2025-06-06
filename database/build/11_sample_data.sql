-- =============================================================================
-- STEP 11: SAMPLE DATA
-- =============================================================================
-- Purpose: Insert sample data for testing and development
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run ELEVENTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- SAMPLE EMPLOYEES (including authentication)
-- =============================================================================

-- Insert sample employees
INSERT INTO core.employees (id, employee_code, name, surname, role, email, phone_number, hire_date, status) VALUES
(2, 'MGR001', 'Sarah', 'Manager', 'manager', 'sarah.manager@company.com', '+27110000002', '2024-01-15', 'active'),
(3, 'BUY001', 'Mike', 'Buyer', 'buyer', 'mike.buyer@company.com', '+27110000003', '2024-02-01', 'active'),
(4, 'ACC001', 'Linda', 'Accounts', 'accounts', 'linda.accounts@company.com', '+27110000004', '2024-02-15', 'active'),
(5, 'HIR001', 'John', 'Controller', 'hire_control', 'john.controller@company.com', '+27110000005', '2024-03-01', 'active'),
(6, 'DRV001', 'Peter', 'Driver', 'driver', 'peter.driver@company.com', '+27110000006', '2024-03-15', 'active'),
(7, 'DRV002', 'James', 'Driver', 'driver', 'james.driver@company.com', '+27110000007', '2024-04-01', 'active'),
(8, 'DRV003', 'David', 'Driver', 'driver', 'david.driver@company.com', '+27110000008', '2024-04-15', 'active'),
(9, 'DRV004', 'Mark', 'Driver', 'driver', 'mark.driver@company.com', '+27110000009', '2024-05-01', 'active'),
(10, 'MEC001', 'Robert', 'Mechanic', 'mechanic', 'robert.mechanic@company.com', '+27110000010', '2024-05-15', 'active');

-- Set employee ID sequence
SELECT setval('core.employees_id_seq', 100, false);

-- Insert authentication data for employees (default password: "password123")
INSERT INTO security.employee_auth (employee_id, username, password_hash, password_salt) 
SELECT 
    e.id,
    e.employee_code,
    result.hash,
    result.salt_used
FROM core.employees e
CROSS JOIN LATERAL security.hash_password('password123') as result
WHERE e.id BETWEEN 1 AND 10;

-- =============================================================================
-- SAMPLE CUSTOMERS
-- =============================================================================

INSERT INTO core.customers (customer_code, customer_name, is_company, registration_number, vat_number, credit_limit, payment_terms, created_by) VALUES
('ABC001', 'ABC Construction Ltd', true, 'REG2023001', 'VAT4001234567', 50000.00, '30 days', 1),
('XYZ001', 'XYZ Building Supplies', true, 'REG2023002', 'VAT4007654321', 75000.00, '30 days', 1),
('SMI001', 'Smith & Associates', true, 'REG2023003', 'VAT4001122334', 25000.00, '14 days', 1),
('JOH001', 'John Guy', false, NULL, NULL, 5000.00, 'COD', 1),
('MAR001', 'Mary Johnson', false, NULL, NULL, 3000.00, 'COD', 1);

-- =============================================================================
-- SAMPLE CONTACTS
-- =============================================================================

INSERT INTO core.contacts (customer_id, first_name, last_name, job_title, email, phone_number, whatsapp_number, is_primary_contact, is_billing_contact) VALUES
-- ABC Construction contacts
(1000, 'John', 'Guy', 'Project Manager', 'john.guy@abcconstruction.com', '+27111234567', '+27111234567', true, false),
(1000, 'Susan', 'Financial', 'Financial Manager', 'susan.financial@abcconstruction.com', '+27111234568', NULL, false, true),
-- XYZ Building Supplies contacts
(1001, 'Peter', 'Parker', 'Operations Manager', 'peter.parker@xyzbuild.com', '+27112345678', '+27112345678', true, true),
(1001, 'Mary', 'Jane', 'Assistant Manager', 'mary.jane@xyzbuild.com', '+27112345679', NULL, false, false),
-- Smith & Associates contacts
(1002, 'Robert', 'Smith', 'Director', 'robert.smith@smithassoc.com', '+27113456789', '+27113456789', true, true),
-- Individual customers
(1003, 'John', 'Guy', 'Individual', 'john.guy.individual@email.com', '+27114567890', '+27114567890', true, true),
(1004, 'Mary', 'Johnson', 'Individual', 'mary.johnson@email.com', '+27115678901', '+27115678901', true, true);

-- =============================================================================
-- SAMPLE SITES
-- =============================================================================

INSERT INTO core.sites (customer_id, site_code, site_name, site_type, address_line1, address_line2, city, province, postal_code, site_contact_name, site_contact_phone, delivery_instructions) VALUES
-- ABC Construction sites
(1000, 'ABC-HO', 'ABC Head Office', 'head_office', '123 Main Street', 'Suite 100', 'Johannesburg', 'Gauteng', '2000', 'John Guy', '+27111234567', 'Reception will sign for deliveries'),
(1000, 'ABC-SAND', 'Sandton Project Site', 'project_site', '45 Sandton Drive', NULL, 'Sandton', 'Gauteng', '2196', 'Site Foreman', '+27111234570', 'Deliver to main gate, ask for foreman'),
(1000, 'ABC-PTA', 'Pretoria Warehouse', 'warehouse', '78 Industrial Road', NULL, 'Pretoria', 'Gauteng', '0001', 'Warehouse Manager', '+27111234571', 'Loading bay 3, business hours only'),
-- XYZ Building Supplies sites
(1001, 'XYZ-MAIN', 'Main Warehouse', 'warehouse', '321 Commerce Street', NULL, 'Johannesburg', 'Gauteng', '2001', 'Peter Parker', '+27112345678', 'Forklift available for unloading'),
(1001, 'XYZ-BRANCH', 'Branch Office', 'branch', '654 Branch Avenue', NULL, 'Randburg', 'Gauteng', '2194', 'Mary Jane', '+27112345679', 'Limited parking, call ahead'),
-- Smith & Associates sites
(1002, 'SMI-OFF', 'Smith Office', 'head_office', '987 Office Park', 'Building C', 'Centurion', 'Gauteng', '0046', 'Robert Smith', '+27113456789', 'Security controlled access'),
-- Individual customer sites
(1003, 'JG-HOME', 'John Guy Home', 'delivery_site', '147 Residential Road', NULL, 'Roodepoort', 'Gauteng', '1724', 'John Guy', '+27114567890', 'Deliver to garage, key under pot'),
(1004, 'MJ-HOME', 'Mary Johnson Home', 'delivery_site', '258 Suburb Street', NULL, 'Germiston', 'Gauteng', '1401', 'Mary Johnson', '+27115678901', 'Ring doorbell, dog friendly');

-- =============================================================================
-- SAMPLE EQUIPMENT CATEGORIES
-- =============================================================================

INSERT INTO core.equipment_categories (category_code, category_name, description, specifications, default_accessories) VALUES
('RAM001', 'Rammer', 'Pneumatic rammer for soil compaction', 'Weight: 65kg, Impact force: 1400N, Fuel: Petrol', 'Starting kit, operating manual'),
('BRK001', 'T1000 Breaker', 'Heavy duty concrete breaker', 'Weight: 28kg, Impact force: 40J, Power: Electric', '2x chisels, power cable, carrying case'),
('BRK002', 'Hydraulic Breaker', 'Large hydraulic concrete breaker', 'Weight: 45kg, Impact force: 85J, Power: Hydraulic', '4x chisels, hydraulic hoses'),
('GEN001', 'Generator 5kVA', 'Portable diesel generator', 'Output: 5kVA, Fuel: Diesel, Runtime: 8 hours', '5L diesel, power cables'),
('GEN002', 'Generator 10kVA', 'Heavy duty diesel generator', 'Output: 10kVA, Fuel: Diesel, Runtime: 10 hours', '10L diesel, power cables, weather cover'),
('MIX001', 'Concrete Mixer', 'Portable concrete mixer', 'Capacity: 350L, Power: Electric, Speed: Variable', 'Mixing paddles, cleaning kit'),
('CMP001', 'Plate Compactor', 'Vibratory plate compactor', 'Weight: 85kg, Force: 25kN, Engine: Petrol', 'Water tank, rubber mat'),
('CUT001', 'Angle Grinder', 'Heavy duty angle grinder', 'Disc size: 230mm, Power: 2400W, Speed: 6500rpm', '5x cutting discs, safety guard'),
('DRL001', 'Core Drill', 'Diamond core drilling machine', 'Max diameter: 200mm, Power: Electric, Speed: Variable', 'Diamond bits set, water pump'),
('LOD001', 'Mini Loader', 'Compact tracked loader', 'Operating weight: 2.5t, Bucket capacity: 0.3m³', 'Standard bucket, operator manual');

-- =============================================================================
-- SAMPLE EQUIPMENT PRICING
-- =============================================================================

-- Individual pricing
INSERT INTO core.equipment_pricing (equipment_category_id, customer_type, price_per_day, price_per_week, price_per_month, deposit_amount, minimum_hire_period) VALUES
(1, 'individual', 150.00, 900.00, 3200.00, 500.00, 1),   -- Rammer
(2, 'individual', 120.00, 720.00, 2800.00, 400.00, 1),   -- T1000 Breaker
(3, 'individual', 200.00, 1200.00, 4500.00, 800.00, 1),   -- Hydraulic Breaker
(4, 'individual', 250.00, 1500.00, 5500.00, 1000.00, 1),  -- Generator 5kVA
(5, 'individual', 400.00, 2400.00, 9000.00, 1500.00, 1),  -- Generator 10kVA
(6, 'individual', 100.00, 600.00, 2200.00, 300.00, 1),    -- Concrete Mixer
(7, 'individual', 180.00, 1080.00, 4000.00, 600.00, 1),   -- Plate Compactor
(8, 'individual', 80.00, 480.00, 1800.00, 200.00, 1),     -- Angle Grinder
(9, 'individual', 350.00, 2100.00, 8000.00, 1200.00, 1),  -- Core Drill
(10, 'individual', 800.00, 4800.00, 18000.00, 3000.00, 1); -- Mini Loader

-- Company pricing (typically 10-15% lower)
INSERT INTO core.equipment_pricing (equipment_category_id, customer_type, price_per_day, price_per_week, price_per_month, deposit_amount, minimum_hire_period) VALUES
(1, 'company', 135.00, 810.00, 2880.00, 500.00, 1),   -- Rammer
(2, 'company', 108.00, 648.00, 2520.00, 400.00, 1),   -- T1000 Breaker
(3, 'company', 180.00, 1080.00, 4050.00, 800.00, 1),   -- Hydraulic Breaker
(4, 'company', 225.00, 1350.00, 4950.00, 1000.00, 1),  -- Generator 5kVA
(5, 'company', 360.00, 2160.00, 8100.00, 1500.00, 1),  -- Generator 10kVA
(6, 'company', 90.00, 540.00, 1980.00, 300.00, 1),    -- Concrete Mixer
(7, 'company', 162.00, 972.00, 3600.00, 600.00, 1),   -- Plate Compactor
(8, 'company', 72.00, 432.00, 1620.00, 200.00, 1),     -- Angle Grinder
(9, 'company', 315.00, 1890.00, 7200.00, 1200.00, 1),  -- Core Drill
(10, 'company', 720.00, 4320.00, 16200.00, 3000.00, 1); -- Mini Loader

-- =============================================================================
-- UPDATE SEQUENCES TO AVOID CONFLICTS
-- =============================================================================

SELECT setval('core.customers_id_seq', 1000, false);
SELECT setval('core.contacts_id_seq', 1000, false);
SELECT setval('core.sites_id_seq', 100, false);
SELECT setval('core.equipment_categories_id_seq', 100, false);
SELECT setval('core.equipment_pricing_id_seq', 100, false);
SELECT setval('interactions.interactions_id_seq', 100, false);
SELECT setval('tasks.user_taskboard_id_seq', 100, false);
SELECT setval('tasks.drivers_taskboard_id_seq', 100, false);

-- =============================================================================
-- NEXT STEP: Run 12_monitoring_views.sql
-- =============================================================================