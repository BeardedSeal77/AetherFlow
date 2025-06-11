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

-- Insert authentication data for employees (default password: "password123")
INSERT INTO security.employee_auth (employee_id, username, password_hash, password_salt) 
SELECT 
    e.id,
    e.employee_code,
    result.hash,
    result.salt_used
FROM core.employees e
CROSS JOIN LATERAL security.hash_password('password123') as result
WHERE e.id BETWEEN 2 AND 10;

-- =============================================================================
-- SAMPLE CUSTOMERS
-- =============================================================================

INSERT INTO core.customers (id, customer_code, customer_name, is_company, registration_number, vat_number, credit_limit, payment_terms, created_by) VALUES
(1, 'ABC001', 'ABC Construction Ltd', true, 'REG2023001', 'VAT4001234567', 50000.00, '30 days', 1),
(2, 'XYZ001', 'XYZ Building Supplies', true, 'REG2023002', 'VAT4007654321', 75000.00, '30 days', 1),
(3, 'SMI001', 'Smith & Associates', true, 'REG2023003', 'VAT4001122334', 25000.00, '14 days', 1),
(4, 'JOH001', 'John Guy', false, NULL, NULL, 5000.00, 'COD', 1),
(5, 'MAR001', 'Mary Johnson', false, NULL, NULL, 3000.00, 'COD', 1);

-- =============================================================================
-- SAMPLE CONTACTS
-- =============================================================================

INSERT INTO core.contacts (id, customer_id, first_name, last_name, job_title, email, phone_number, whatsapp_number, is_primary_contact, is_billing_contact) VALUES
-- ABC Construction contacts
(1, 1, 'John', 'Guy', 'Project Manager', 'john.guy@abcconstruction.com', '+27111234567', '+27111234567', true, false),
(2, 1, 'Susan', 'Financial', 'Financial Manager', 'susan.financial@abcconstruction.com', '+27111234568', NULL, false, true),
-- XYZ Building Supplies contacts
(3, 2, 'Peter', 'Parker', 'Operations Manager', 'peter.parker@xyzbuild.com', '+27112345678', '+27112345678', true, true),
(4, 2, 'Mary', 'Jane', 'Assistant Manager', 'mary.jane@xyzbuild.com', '+27112345679', NULL, false, false),
-- Smith & Associates contacts
(5, 3, 'Robert', 'Smith', 'Director', 'robert.smith@smithassoc.com', '+27113456789', '+27113456789', true, true),
-- Individual customers
(6, 4, 'John', 'Guy', 'Individual', 'john.guy.individual@email.com', '+27114567890', '+27114567890', true, true),
(7, 5, 'Mary', 'Johnson', 'Individual', 'mary.johnson@email.com', '+27115678901', '+27115678901', true, true);

-- =============================================================================
-- SAMPLE SITES
-- =============================================================================

INSERT INTO core.sites (id, customer_id, site_code, site_name, site_type, address_line1, address_line2, city, province, postal_code, site_contact_name, site_contact_phone, delivery_instructions) VALUES
-- ABC Construction sites
(1, 1, 'ABC-HO', 'ABC Head Office', 'head_office', '123 Main Street', 'Suite 100', 'Johannesburg', 'Gauteng', '2000', 'John Guy', '+27111234567', 'Reception will sign for deliveries'),
(2, 1, 'ABC-SAND', 'Sandton Project Site', 'project_site', '45 Sandton Drive', NULL, 'Sandton', 'Gauteng', '2196', 'Site Foreman', '+27111234570', 'Deliver to main gate, ask for foreman'),
(3, 1, 'ABC-PTA', 'Pretoria Warehouse', 'warehouse', '78 Industrial Road', NULL, 'Pretoria', 'Gauteng', '0001', 'Warehouse Manager', '+27111234571', 'Loading bay 3, business hours only'),
-- XYZ Building Supplies sites
(4, 2, 'XYZ-MAIN', 'Main Warehouse', 'warehouse', '321 Commerce Street', NULL, 'Johannesburg', 'Gauteng', '2001', 'Peter Parker', '+27112345678', 'Forklift available for unloading'),
(5, 2, 'XYZ-BRANCH', 'Branch Office', 'branch', '654 Branch Avenue', NULL, 'Randburg', 'Gauteng', '2194', 'Mary Jane', '+27112345679', 'Limited parking, call ahead'),
-- Smith & Associates sites
(6, 3, 'SMI-OFF', 'Smith Office', 'head_office', '987 Office Park', 'Building C', 'Centurion', 'Gauteng', '0046', 'Robert Smith', '+27113456789', 'Security controlled access'),
-- Individual customer sites
(7, 4, 'JG-HOME', 'John Guy Home', 'delivery_site', '147 Residential Road', NULL, 'Roodepoort', 'Gauteng', '1724', 'John Guy', '+27114567890', 'Deliver to garage, key under pot'),
(8, 5, 'MJ-HOME', 'Mary Johnson Home', 'delivery_site', '258 Suburb Street', NULL, 'Germiston', 'Gauteng', '1401', 'Mary Johnson', '+27115678901', 'Ring doorbell, dog friendly');

-- =============================================================================
-- SAMPLE EQUIPMENT CATEGORIES
-- =============================================================================

INSERT INTO core.equipment_categories (id, category_code, category_name, description, specifications) VALUES
(1, 'RAM001', 'Rammer', 'Pneumatic rammer for soil compaction', 'Weight: 65kg, Impact force: 1400N, Fuel: Petrol'),
(2, 'BRK001', 'T1000 Breaker', 'Heavy duty concrete breaker', 'Weight: 28kg, Impact force: 40J, Power: Electric'),
(3, 'BRK002', 'Hydraulic Breaker', 'Large hydraulic concrete breaker', 'Weight: 45kg, Impact force: 85J, Power: Hydraulic'),
(4, 'GEN001', 'Generator 5kVA', 'Portable diesel generator', 'Output: 5kVA, Fuel: Diesel, Runtime: 8 hours'),
(5, 'GEN002', 'Generator 10kVA', 'Heavy duty diesel generator', 'Output: 10kVA, Fuel: Diesel, Runtime: 10 hours'),
(6, 'MIX001', 'Concrete Mixer', 'Portable concrete mixer', 'Capacity: 350L, Power: Electric, Speed: Variable'),
(7, 'CMP001', 'Plate Compactor', 'Vibratory plate compactor', 'Weight: 85kg, Force: 25kN, Engine: Petrol'),
(8, 'CUT001', 'Angle Grinder', 'Heavy duty angle grinder', 'Disc size: 230mm, Power: 2400W, Speed: 6500rpm'),
(9, 'DRL001', 'Core Drill', 'Diamond core drilling machine', 'Max diameter: 200mm, Power: Electric, Speed: Variable'),
(10, 'LOD001', 'Mini Loader', 'Compact tracked loader', 'Operating weight: 2.5t, Bucket capacity: 0.3m³');

-- =============================================================================
-- SAMPLE EQUIPMENT ACCESSORIES
-- =============================================================================

INSERT INTO core.equipment_accessories (equipment_category_id, accessory_name, accessory_type, quantity, description, is_consumable, created_by) VALUES
-- Rammer accessories (2L petrol default)
(1, '2L Petrol', 'default', 1, 'Standard petrol fuel supply', true, 1),
(1, 'Starting Kit', 'default', 1, 'Pull cord and maintenance tools', false, 1),
(1, 'Operating Manual', 'default', 1, 'User guide and safety instructions', false, 1),
-- T1000 Breaker accessories (4 chisels: spade default, moil default, flat, cone)
(2, 'Spade Chisel', 'default', 1, 'General purpose spade chisel (default)', false, 1),
(2, 'Moil Chisel', 'default', 1, 'Pointed moil chisel for precision work (default)', false, 1),
(2, 'Flat Chisel', 'default', 1, 'Flat blade chisel for surface work', false, 1),
(2, 'Cone Chisel', 'default', 1, 'Cone shaped chisel for breaking', false, 1),
(2, 'Power Cable', 'default', 1, '10m heavy duty power cable', false, 1),
(2, 'Carrying Case', 'default', 1, 'Protective carrying case', false, 1),
-- Hydraulic Breaker accessories (4 chisels: spade default, moil default, flat, cone)
(3, 'Spade Chisel', 'default', 1, 'Heavy duty spade chisel (default)', false, 1),
(3, 'Moil Chisel', 'default', 1, 'Heavy duty moil chisel (default)', false, 1),
(3, 'Flat Chisel', 'default', 1, 'Heavy duty flat chisel', false, 1),
(3, 'Cone Chisel', 'default', 1, 'Heavy duty cone chisel', false, 1),
(3, 'Hydraulic Hoses', 'default', 2, 'High pressure hydraulic hoses', false, 1),
-- Generator 5kVA accessories (5L petrol default)
(4, '5L Petrol', 'default', 1, 'Standard petrol fuel supply', true, 1),
(4, 'Power Cables', 'default', 1, 'Heavy duty power cables', false, 1),
-- Generator 10kVA accessories (5L petrol default)
(5, '5L Petrol', 'default', 1, 'Standard petrol fuel supply', true, 1),
(5, 'Power Cables', 'default', 1, 'Heavy duty power cables', false, 1),
(5, 'Weather Cover', 'default', 1, 'Waterproof protective cover', false, 1),
-- Concrete Mixer accessories
(6, 'Mixing Paddles', 'default', 2, 'Replacement mixing paddles', false, 1),
(6, 'Cleaning Kit', 'default', 1, 'Brushes and cleaning supplies', false, 1),
-- Plate Compactor accessories (2L petrol default)
(7, '2L Petrol', 'default', 1, 'Standard petrol fuel supply', true, 1),
(7, 'Water Tank', 'default', 1, 'Water tank for dust suppression', false, 1),
(7, 'Rubber Mat', 'default', 1, 'Protective rubber mat', false, 1),
-- Angle Grinder accessories
(8, 'Cutting Discs', 'default', 5, '230mm cutting discs', true, 1),
(8, 'Safety Guard', 'default', 1, 'Protective safety guard', false, 1),
-- Core Drill accessories
(9, 'Diamond Bits Set', 'default', 1, 'Complete set of diamond core bits', false, 1),
(9, 'Water Pump', 'default', 1, 'Cooling water circulation pump', false, 1),
-- Mini Loader accessories (10L petrol default)
(10, '10L Petrol', 'default', 1, 'Standard petrol fuel supply', true, 1),
(10, 'Standard Bucket', 'default', 1, '0.3m³ capacity bucket', false, 1),
(10, 'Operator Manual', 'default', 1, 'Operating instructions and safety guide', false, 1);

-- =============================================================================
-- SAMPLE EQUIPMENT PRICING
-- =============================================================================

-- Individual pricing
INSERT INTO core.equipment_pricing (id, equipment_category_id, customer_type, price_per_day, price_per_week, price_per_month, deposit_amount, minimum_hire_period) VALUES
(1, 1, 'individual', 150.00, 900.00, 3200.00, 500.00, 1),   -- Rammer
(2, 2, 'individual', 120.00, 720.00, 2800.00, 400.00, 1),   -- T1000 Breaker
(3, 3, 'individual', 200.00, 1200.00, 4500.00, 800.00, 1),   -- Hydraulic Breaker
(4, 4, 'individual', 250.00, 1500.00, 5500.00, 1000.00, 1),  -- Generator 5kVA
(5, 5, 'individual', 400.00, 2400.00, 9000.00, 1500.00, 1),  -- Generator 10kVA
(6, 6, 'individual', 100.00, 600.00, 2200.00, 300.00, 1),    -- Concrete Mixer
(7, 7, 'individual', 180.00, 1080.00, 4000.00, 600.00, 1),   -- Plate Compactor
(8, 8, 'individual', 80.00, 480.00, 1800.00, 200.00, 1),     -- Angle Grinder
(9, 9, 'individual', 350.00, 2100.00, 8000.00, 1200.00, 1),  -- Core Drill
(10, 10, 'individual', 800.00, 4800.00, 18000.00, 3000.00, 1); -- Mini Loader

-- Company pricing (typically 10-15% lower)
INSERT INTO core.equipment_pricing (id, equipment_category_id, customer_type, price_per_day, price_per_week, price_per_month, deposit_amount, minimum_hire_period) VALUES
(11, 1, 'company', 135.00, 810.00, 2880.00, 500.00, 1),   -- Rammer
(12, 2, 'company', 108.00, 648.00, 2520.00, 400.00, 1),   -- T1000 Breaker
(13, 3, 'company', 180.00, 1080.00, 4050.00, 800.00, 1),   -- Hydraulic Breaker
(14, 4, 'company', 225.00, 1350.00, 4950.00, 1000.00, 1),  -- Generator 5kVA
(15, 5, 'company', 360.00, 2160.00, 8100.00, 1500.00, 1),  -- Generator 10kVA
(16, 6, 'company', 90.00, 540.00, 1980.00, 300.00, 1),    -- Concrete Mixer
(17, 7, 'company', 162.00, 972.00, 3600.00, 600.00, 1),   -- Plate Compactor
(18, 8, 'company', 72.00, 432.00, 1620.00, 200.00, 1),     -- Angle Grinder
(19, 9, 'company', 315.00, 1890.00, 7200.00, 1200.00, 1),  -- Core Drill
(20, 10, 'company', 720.00, 4320.00, 16200.00, 3000.00, 1); -- Mini Loader

-- =============================================================================
-- SAMPLE DATA VALIDATION
-- =============================================================================

-- Display summary of inserted data
DO $$
DECLARE
    employee_count INTEGER;
    customer_count INTEGER;
    equipment_count INTEGER;
    accessory_count INTEGER;
    pricing_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO employee_count FROM core.employees WHERE id > 1;
    SELECT COUNT(*) INTO customer_count FROM core.customers WHERE id < 999;
    SELECT COUNT(*) INTO equipment_count FROM core.equipment_categories;
    SELECT COUNT(*) INTO accessory_count FROM core.equipment_accessories;
    SELECT COUNT(*) INTO pricing_count FROM core.equipment_pricing;
    
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'SAMPLE DATA INSERTED SUCCESSFULLY';
    RAISE NOTICE '=============================================================================';
    RAISE NOTICE 'Employees: % (IDs: 2-10)', employee_count;
    RAISE NOTICE 'Customers: % (IDs: 1-5)', customer_count;
    RAISE NOTICE 'Equipment Categories: % (IDs: 1-10)', equipment_count;
    RAISE NOTICE 'Equipment Accessories: % items', accessory_count;
    RAISE NOTICE 'Equipment Pricing: % entries', pricing_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run 12_sequence_reset.sql to set sequences to 1000';
    RAISE NOTICE '=============================================================================';
END $$;

-- =============================================================================
-- NEXT STEP: Run 12_sequence_reset.sql
-- =============================================================================