-- =============================================================================
-- SAMPLE DATA SETUP FOR TASK MANAGEMENT SYSTEM TESTING
-- =============================================================================

-- =============================================================================
-- 1. EMPLOYEES (Internal Staff)
-- =============================================================================

-- Insert sample employees covering different roles
INSERT INTO employees (username, email, password_hash, role, name, surname, phone, status) VALUES
('john_controller', 'john@company.com', '$2b$12$dummy_hash_1', 'hire_control', 'John', 'Smith', '+27123456789', 'active'),
('mike_driver', 'mike@company.com', '$2b$12$dummy_hash_2', 'driver', 'Mike', 'Johnson', '+27123456790', 'active'),
('sarah_accounts', 'sarah@company.com', '$2b$12$dummy_hash_3', 'accounts', 'Sarah', 'Williams', '+27123456791', 'active'),
('tom_manager', 'tom@company.com', '$2b$12$dummy_hash_4', 'manager', 'Tom', 'Brown', '+27123456792', 'active'),
('lisa_buyer', 'lisa@company.com', '$2b$12$dummy_hash_5', 'buyer', 'Lisa', 'Davis', '+27123456793', 'active');

-- =============================================================================
-- 2. CUSTOMERS (External Clients)
-- =============================================================================

-- Company Customer
INSERT INTO customers (customer_name, is_company, registration_number, vat_number, credit_limit, payment_terms, status, notes) 
VALUES 
('ABC Construction Ltd', true, 'REG2023001', 'VAT123456789', 50000.00, '30 days', 'active', 'Large construction company - good payment history'),
('XYZ Building Supplies', true, 'REG2023002', 'VAT987654321', 25000.00, '14 days', 'active', 'Medium building supplier - regular customer');

-- Individual Customer  
INSERT INTO customers (customer_name, is_company, credit_limit, payment_terms, status, notes) 
VALUES 
('John Guy', false, 5000.00, 'COD', 'active', 'Individual contractor - cash customer');

-- =============================================================================
-- 3. CONTACTS FOR CUSTOMERS
-- =============================================================================

-- Contacts for ABC Construction Ltd (customer_id = 1)
INSERT INTO contacts (customer_id, first_name, last_name, job_title, department, phone_number, whatsapp_number, email, is_primary_contact, is_billing_contact, status) 
VALUES 
(1, 'John', 'Guy', 'Site Manager', 'Operations', '+27111234567', '+27111234567', 'john.guy@abcconstruction.com', true, false, 'active'),
(1, 'Mary', 'Jane', 'Accounts Manager', 'Finance', '+27111234568', '+27111234568', 'mary.jane@abcconstruction.com', false, true, 'active');

-- Contacts for XYZ Building Supplies (customer_id = 2)
INSERT INTO contacts (customer_id, first_name, last_name, job_title, department, phone_number, whatsapp_number, email, is_primary_contact, is_billing_contact, status) 
VALUES 
(2, 'Peter', 'Parker', 'Procurement Manager', 'Purchasing', '+27112234567', '+27112234567', 'peter.parker@xyzsupplies.com', true, true, 'active');

-- Contact for John Guy (individual customer - customer_id = 3)
INSERT INTO contacts (customer_id, first_name, last_name, job_title, phone_number, whatsapp_number, email, is_primary_contact, is_billing_contact, status) 
VALUES 
(3, 'John', 'Guy', 'Owner', '+27113234567', '+27113234567', 'john.guy.contractor@gmail.com', true, true, 'active');

-- =============================================================================
-- 4. SITES FOR CUSTOMERS
-- =============================================================================

-- Sites for ABC Construction Ltd
INSERT INTO sites (customer_id, site_name, site_code, address_line1, address_line2, city, postal_code, gps_coordinates, site_type, site_contact_name, site_contact_phone, access_instructions, delivery_instructions, special_notes) 
VALUES 
(1, 'Sandton Office Development', 'SAND01', '123 Rivonia Road', 'Sandton Central', 'Johannesburg', '2196', '-26.1076,28.0567', 'construction', 'John Guy', '+27111234567', 'Security gate - mention ABC Construction', 'Deliver to site office container', 'Active construction site - safety gear required'),
(1, 'Head Office', 'HO001', '456 Main Street', 'Bryanston', 'Johannesburg', '2021', '-26.0434,28.0166', 'office', 'Mary Jane', '+27111234568', 'Reception will assist', 'Normal business hours delivery', 'Corporate head office');

-- Sites for XYZ Building Supplies
INSERT INTO sites (customer_id, site_name, site_code, address_line1, city, postal_code, site_type, site_contact_name, site_contact_phone, access_instructions, delivery_instructions) 
VALUES 
(2, 'Main Warehouse', 'WH001', '789 Industrial Road', 'Kempton Park', '1619', 'warehouse', 'Peter Parker', '+27112234567', 'Loading bay access via side entrance', 'Weekdays 7AM-5PM only');

-- Sites for John Guy (individual)
INSERT INTO sites (customer_id, site_name, address_line1, city, postal_code, site_type, site_contact_name, site_contact_phone, access_instructions, delivery_instructions) 
VALUES 
(3, 'Kimberly Street Project', '123 Kimberly Street', 'Randburg', '2194', 'residential', 'John Guy', '+27113234567', 'Residential area - ring bell', 'Available weekdays after 3PM and weekends');

-- =============================================================================
-- 5. EQUIPMENT CATEGORIES
-- =============================================================================

-- Insert the specified equipment categories
INSERT INTO equipment_categories (category_name, category_code, description, default_accessories, specifications, is_active) 
VALUES 
('Rammer', 'RAM01', 'PNEUMATIC RAMMER 2-STROKE', 'Comes with fuel mix, basic maintenance kit', 'Weight: 9kg, Impact rate: 680 blows/min, Fuel: 2-stroke petrol mix', true),
('T1000 Breaker', 'BRK01', 'ELECTRIC BREAKER T1000 110V', 'Comes with 2 chisels (point and flat), power cable', 'Power: 1100W, Impact rate: 3400 bpm, Chuck: SDS-Max', true),
('Poker', 'POK01', 'CONCRETE VIBRATOR POKER 25MM', 'Comes with 3m flexible shaft, motor unit', 'Frequency: 12000 vpm, Shaft diameter: 25mm, Power: 1.5kW', true),
('Plate Compactor', 'PLT01', 'PLATE COMPACTOR 60KG PETROL', 'Comes with 5L petrol, rubber mat for asphalt', 'Weight: 60kg, Plate size: 500x330mm, Engine: 4-stroke petrol', true);

-- =============================================================================
-- 6. EQUIPMENT PRICING
-- =============================================================================

-- Set up pricing for each equipment category (individual and company rates)
INSERT INTO equipment_pricing (equipment_category_id, customer_type, price_per_day, price_per_week, price_per_month, minimum_hire_period, deposit_amount, effective_from, is_active) 
VALUES 
-- Rammer pricing
(1, 'individual', 85.00, 450.00, 1500.00, 1, 500.00, '2024-01-01', true),
(1, 'company', 75.00, 400.00, 1350.00, 1, 400.00, '2024-01-01', true),

-- T1000 Breaker pricing  
(2, 'individual', 120.00, 650.00, 2200.00, 1, 800.00, '2024-01-01', true),
(2, 'company', 110.00, 600.00, 2000.00, 1, 700.00, '2024-01-01', true),

-- Poker pricing
(3, 'individual', 95.00, 500.00, 1700.00, 1, 600.00, '2024-01-01', true),
(3, 'company', 85.00, 450.00, 1550.00, 1, 500.00, '2024-01-01', true),

-- Plate Compactor pricing
(4, 'individual', 150.00, 800.00, 2800.00, 1, 1000.00, '2024-01-01', true),
(4, 'company', 135.00, 750.00, 2500.00, 1, 900.00, '2024-01-01', true);

-- =============================================================================
-- 7. PRICE LIST TEMPLATES
-- =============================================================================

-- Create some price list templates for different scenarios
INSERT INTO price_list_templates (template_name, equipment_category_filter, customer_type, include_pricing, include_specifications, is_active) 
VALUES 
('Standard Individual Price List', 'all', 'individual', true, true, true),
('Standard Company Price List', 'all', 'company', true, true, true),
('Compaction Equipment Only', '[1,4]', 'both', true, true, true),
('Breaking Equipment Only', '[2,3]', 'both', true, true, true);

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Verify the data was inserted correctly
SELECT 'EMPLOYEES' as table_name, COUNT(*) as record_count FROM employees
UNION ALL
SELECT 'CUSTOMERS', COUNT(*) FROM customers  
UNION ALL
SELECT 'CONTACTS', COUNT(*) FROM contacts
UNION ALL
SELECT 'SITES', COUNT(*) FROM sites
UNION ALL
SELECT 'EQUIPMENT_CATEGORIES', COUNT(*) FROM equipment_categories
UNION ALL
SELECT 'EQUIPMENT_PRICING', COUNT(*) FROM equipment_pricing
UNION ALL
SELECT 'PRICE_LIST_TEMPLATES', COUNT(*) FROM price_list_templates;

-- =============================================================================
-- SAMPLE PROCESS TEST SCENARIOS
-- =============================================================================

/*
With this sample data, you can now test these process scenarios:

1. PRICE LIST REQUEST:
   - John Guy from ABC Construction calls asking for compaction equipment prices
   - Contact: john.guy@abcconstruction.com, +27111234567

2. QUOTE REQUEST:  
   - Peter Parker from XYZ Building Supplies needs a quote for rammer rental (3 days)
   - Delivery to Main Warehouse site

3. ORDER/HIRE:
   - John Guy (individual) wants to hire T1000 Breaker for weekend project
   - Delivery to Kimberly Street Project site

4. BREAKDOWN:
   - ABC Construction reports plate compactor broken at Sandton site
   - Needs urgent swap or repair

5. OFF-HIRE:
   - Customer returns equipment early or on time

6. STATEMENT REQUEST:
   - Customer requests account statement

7. REFUND REQUEST:
   - Customer has overpaid and wants refund

Each scenario will create an interaction record and flow through to the appropriate taskboards!
*/