-- =============================================================================
-- COMPLETE SAMPLE DATA FOR EQUIPMENT & ACCESSORIES - WITH BREAKERS & CHISELS
-- =============================================================================

-- System employee (must be first for foreign key references)
INSERT INTO core.employees (
    id, employee_code, name, surname, role, email, phone_number, hire_date, status, created_at, created_by
) VALUES (
    1, 'SYSTEM', 'System', 'User', 'owner', 'system@localhost', NULL, CURRENT_DATE, 'active', CURRENT_TIMESTAMP, 1
);

-- Generic customer for applications
INSERT INTO core.customers (
    id, customer_code, customer_name, is_company, created_by
) VALUES (
    999, 'GENERIC', 'Generic Customer - Applications', false, 1
);

-- Generic contact
INSERT INTO core.contacts (
    id, customer_id, first_name, last_name, is_primary_contact, created_by
) VALUES (
    999, 999, 'Generic', 'Contact', true, 1
);

-- Reference prefixes
INSERT INTO system.reference_prefixes (interaction_type, prefix, description) VALUES
('price_list', 'PL', 'Price List Request'),
('quote', 'QT', 'Quote Request'),
('statement', 'ST', 'Account Statement'),
('refund', 'RF', 'Refund Request'),
('hire', 'HR', 'Equipment Hire'),
('off_hire', 'OH', 'Off-Hire/Collection'),
('breakdown', 'BD', 'Equipment Breakdown'),
('application', 'AP', 'Account Application'),
('coring', 'CR', 'Coring Services'),
('misc_task', 'MT', 'Miscellaneous Task');

-- Sample employees (starting from ID 2 since ID 1 is system user)
INSERT INTO core.employees (id, employee_code, name, surname, role, email, phone_number, whatsapp_number, hire_date, created_by) VALUES
(2, 'HC001', 'Sarah', 'Johnson', 'hire_control', 'sarah@company.com', '0111234567', '0781234567', '2023-01-15', 1),
(3, 'ACC001', 'Mike', 'Williams', 'accounts', 'mike@company.com', '0119876543', '0789876543', '2023-02-01', 1),
(4, 'DRV001', 'David', 'Brown', 'driver', 'david@company.com', '0115555555', '0785555555', '2023-03-01', 1),
(5, 'DRV002', 'Chris', 'Wilson', 'driver', 'chris@company.com', '0116666666', '0786666666', '2023-03-15', 1),
(6, 'MGR001', 'Lisa', 'Davis', 'manager', 'lisa@company.com', '0117777777', '0787777777', '2022-12-01', 1);

-- =============================================================================
-- EQUIPMENT TYPES (including breakers)
-- =============================================================================
INSERT INTO core.equipment_types (type_code, type_name, description, specifications, created_by) VALUES
('RAMMER-4S', '4 Stroke Rammer', 'Heavy duty 4-stroke petrol rammer for soil compaction', 'Engine: 4-stroke, Weight: 85kg, Impact force: 18kN', 1),
('RAMMER-2S', '2 Stroke Rammer', 'Lightweight 2-stroke petrol rammer for general compaction', 'Engine: 2-stroke, Weight: 65kg, Impact force: 15kN', 1),
('PLATE-SM', 'Small Plate Compactor', 'Small reversible plate compactor for tight spaces', 'Engine: Petrol, Plate size: 400mm, Weight: 120kg', 1),
('POKER-25', 'Concrete Poker 25mm', 'High frequency concrete vibrator poker', 'Diameter: 25mm, Frequency: 12000vpm, Length: 1.5m', 1),
('DRIVE-UNIT', 'Poker Drive Unit', 'Electric drive unit for concrete poker', 'Power: 2.2kW, Voltage: 240V, Weight: 35kg', 1),
('GRINDER-250', '250mm Angle Grinder', 'Heavy duty angle grinder for cutting and grinding', 'Disc size: 250mm, Power: 2.5kW, Weight: 6kg', 1),
('GEN-2.5KVA', '2.5kVA Generator', 'Portable petrol generator for power tools', 'Output: 2.5kVA, Fuel: Petrol, Runtime: 8 hours', 1),
('BREAKER-HILTI', 'Hilti Breaker', 'Heavy duty electric demolition hammer for concrete breaking', 'Power: 1500W, Impact energy: 35J, Weight: 8.5kg', 1),
('BREAKER-BOSCH', 'Bosch Breaker', 'Professional electric demolition hammer for heavy demolition', 'Power: 1700W, Impact energy: 45J, Weight: 9.2kg', 1);

-- =============================================================================
-- INDIVIDUAL EQUIPMENT UNITS
-- =============================================================================
INSERT INTO core.equipment (equipment_type_id, asset_code, serial_number, model, condition, status, created_by) VALUES
-- Rammers (4-stroke)
(1, 'R1001', 'WP1550-2023-001', 'Wacker WP1550', 'excellent', 'available', 1),
(1, 'R1002', 'WP1550-2023-002', 'Wacker WP1550', 'good', 'available', 1),
(1, 'R1003', 'WP1550-2022-003', 'Wacker WP1550', 'good', 'available', 1),
-- Rammers (2-stroke)
(2, 'R2001', 'BS50-2024-001', 'Wacker BS50-2', 'excellent', 'available', 1),
(2, 'R2002', 'BS50-2024-002', 'Wacker BS50-2', 'good', 'available', 1),
-- Plate compactors
(3, 'P1001', 'DPU2540-2023-001', 'Wacker DPU2540', 'excellent', 'available', 1),
(3, 'P1002', 'DPU2540-2023-002', 'Wacker DPU2540', 'good', 'available', 1),
-- Concrete pokers
(4, 'CP001', 'IEC25-2023-001', 'Inmesol IEC25', 'excellent', 'available', 1),
(4, 'CP002', 'IEC25-2023-002', 'Inmesol IEC25', 'good', 'available', 1),
-- Drive units
(5, 'DU001', 'M5000-2023-001', 'Inmesol M5000', 'excellent', 'available', 1),
(5, 'DU002', 'M5000-2022-001', 'Inmesol M5000', 'good', 'available', 1),
-- Grinders
(6, 'G1001', 'AG250-2024-001', 'Bosch AG250', 'excellent', 'available', 1),
(6, 'G1002', 'AG250-2024-002', 'Bosch AG250', 'good', 'available', 1),
-- Generators
(7, 'GEN001', 'EU25-2023-001', 'Honda EU25i', 'excellent', 'available', 1),
(7, 'GEN002', 'EU25-2023-002', 'Honda EU25i', 'good', 'available', 1),
-- Hilti Breakers
(8, 'BH001', 'TE1000-2024-001', 'Hilti TE 1000-AVR', 'excellent', 'available', 1),
(8, 'BH002', 'TE1000-2024-002', 'Hilti TE 1000-AVR', 'good', 'available', 1),
(8, 'BH003', 'TE1000-2023-001', 'Hilti TE 1000-AVR', 'good', 'available', 1),
-- Bosch Breakers
(9, 'BB001', 'GSH16-2024-001', 'Bosch GSH 16-30', 'excellent', 'available', 1),
(9, 'BB002', 'GSH16-2024-002', 'Bosch GSH 16-30', 'good', 'available', 1);

-- =============================================================================
-- MASTER ACCESSORIES LIST (including chisels)
-- =============================================================================
INSERT INTO core.accessories (accessory_code, accessory_name, description, is_consumable, unit_of_measure, created_by) VALUES
-- Fuels
('PETROL-4S', 'Petrol (4-stroke)', 'Unleaded petrol for 4-stroke engines', true, 'litres', 1),
('PETROL-2S', 'Petrol (2-stroke)', '2-stroke petrol mix (50:1)', true, 'litres', 1),
('PETROL-GEN', 'Generator Petrol', 'Unleaded petrol for generators', true, 'litres', 1),

-- Oils and lubricants
('OIL-4S', 'Engine Oil (4-stroke)', 'SAE 30 4-stroke engine oil', true, 'litres', 1),
('OIL-2S', '2-stroke Oil', 'High quality 2-stroke oil', true, 'litres', 1),

-- Safety equipment
('HELMET', 'Safety Helmet', 'Hard hat for construction work', false, 'item', 1),
('GLOVES', 'Work Gloves', 'Heavy duty work gloves', false, 'pair', 1),
('GOGGLES', 'Safety Goggles', 'Eye protection for grinding/cutting', false, 'item', 1),

-- Tool accessories
('CORD-20M', '20m Extension Cord', 'Heavy duty 20m extension cord', false, 'item', 1),
('CORD-10M', '10m Extension Cord', 'Heavy duty 10m extension cord', false, 'item', 1),
('DISC-250-CONC', '250mm Concrete Disc', 'Concrete cutting disc for 250mm grinder', true, 'item', 1),
('DISC-250-MET', '250mm Metal Disc', 'Metal cutting disc for 250mm grinder', true, 'item', 1),

-- Breaker chisels (the requested accessories)
('CHISEL-MOIL', 'Moil Point Chisel', 'Pointed moil chisel for breaking concrete and masonry', false, 'item', 1),
('CHISEL-SPADE', 'Spade Chisel', 'Flat spade chisel for chipping and breaking', false, 'item', 1),
('CHISEL-CONE', 'Cone Point Chisel', 'Cone-shaped chisel for precise breaking work', false, 'item', 1),
('CHISEL-FLAT', 'Flat Chisel', 'Wide flat chisel for surface preparation and chipping', false, 'item', 1),

-- Additional accessories
('FUNNEL', 'Fuel Funnel', 'Plastic funnel for fuel filling', false, 'item', 1),
('RAG-PACK', 'Cleaning Rags', 'Pack of cleaning rags', true, 'pack', 1),
('CORD-BREAKER', 'Breaker Extension Cord', 'Heavy duty 15m extension cord for breakers', false, 'item', 1),
('LUBRICANT', 'Chisel Lubricant', 'Special lubricant for breaker chisels', true, 'tube', 1);

-- =============================================================================
-- EQUIPMENT-ACCESSORIES RELATIONSHIPS
-- =============================================================================

-- 4-Stroke Rammer (RAMMER-4S) default accessories
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories (automatically included)
(1, (SELECT id FROM core.accessories WHERE accessory_code = 'PETROL-4S'), 'default', 2.0, 1),    -- 2 litres petrol
(1, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(1, (SELECT id FROM core.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories (customer can choose)
(1, (SELECT id FROM core.accessories WHERE accessory_code = 'OIL-4S'), 'optional', 1.0, 1),       -- 1 litre oil
(1, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- 2-Stroke Rammer (RAMMER-2S) default accessories  
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(2, (SELECT id FROM core.accessories WHERE accessory_code = 'PETROL-2S'), 'default', 2.0, 1),     -- 2 litres 2-stroke mix
(2, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(2, (SELECT id FROM core.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories
(2, (SELECT id FROM core.accessories WHERE accessory_code = 'OIL-2S'), 'optional', 0.5, 1),       -- 0.5 litres 2-stroke oil
(2, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- Small Plate Compactor (PLATE-SM) default accessories
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(3, (SELECT id FROM core.accessories WHERE accessory_code = 'PETROL-4S'), 'default', 3.0, 1),     -- 3 litres petrol
(3, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(3, (SELECT id FROM core.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories
(3, (SELECT id FROM core.accessories WHERE accessory_code = 'OIL-4S'), 'optional', 1.0, 1),       -- 1 litre oil
(3, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- Concrete Poker (POKER-25) default accessories
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(4, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(4, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- 1 pair gloves
-- Optional accessories
(4, (SELECT id FROM core.accessories WHERE accessory_code = 'GOGGLES'), 'optional', 1, 1);        -- 1 safety goggles

-- Drive Unit (DRIVE-UNIT) default accessories
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(5, (SELECT id FROM core.accessories WHERE accessory_code = 'CORD-10M'), 'default', 1, 1),        -- 10m cord
(5, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
-- Optional accessories
(5, (SELECT id FROM core.accessories WHERE accessory_code = 'CORD-20M'), 'optional', 1, 1),       -- 20m cord upgrade
(5, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- 250mm Grinder (GRINDER-250) default accessories
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(6, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(6, (SELECT id FROM core.accessories WHERE accessory_code = 'GOGGLES'), 'default', 1, 1),          -- 1 safety goggles
(6, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- 1 pair gloves
-- Optional accessories  
(6, (SELECT id FROM core.accessories WHERE accessory_code = 'DISC-250-CONC'), 'optional', 2, 1),  -- 2 concrete discs
(6, (SELECT id FROM core.accessories WHERE accessory_code = 'DISC-250-MET'), 'optional', 2, 1);   -- 2 metal discs

-- 2.5kVA Generator (GEN-2.5KVA) default accessories
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(7, (SELECT id FROM core.accessories WHERE accessory_code = 'PETROL-GEN'), 'default', 5.0, 1),    -- 5 litres petrol
(7, (SELECT id FROM core.accessories WHERE accessory_code = 'CORD-20M'), 'default', 1, 1),        -- 20m cord
(7, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(7, (SELECT id FROM core.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories
(7, (SELECT id FROM core.accessories WHERE accessory_code = 'OIL-4S'), 'optional', 1.0, 1),       -- 1 litre oil
(7, (SELECT id FROM core.accessories WHERE accessory_code = 'CORD-10M'), 'optional', 1, 1);       -- Additional 10m cord

-- =============================================================================
-- HILTI BREAKER ACCESSORIES (the requested setup)
-- =============================================================================
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories (automatically included with default quantities)
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-MOIL'), 'default', 1, 1),     -- Moil = 1 (default)
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-SPADE'), 'default', 1, 1),    -- Spade = 1 (default)
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- Safety helmet
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'GOGGLES'), 'default', 1, 1),          -- Safety goggles
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- Work gloves
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'CORD-BREAKER'), 'default', 1, 1),    -- Extension cord

-- Optional accessories (start at quantity 0, user can adjust)
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-CONE'), 'optional', 0, 1),    -- Cone = 0 (optional)
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-FLAT'), 'optional', 0, 1),    -- Flat = 0 (optional)
(8, (SELECT id FROM core.accessories WHERE accessory_code = 'LUBRICANT'), 'optional', 1, 1);      -- Chisel lubricant

-- =============================================================================
-- BOSCH BREAKER ACCESSORIES (similar setup)
-- =============================================================================
INSERT INTO core.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-MOIL'), 'default', 1, 1),     -- Moil = 1 (default)
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-SPADE'), 'default', 1, 1),    -- Spade = 1 (default)
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- Safety helmet
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'GOGGLES'), 'default', 1, 1),          -- Safety goggles
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- Work gloves
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'CORD-BREAKER'), 'default', 1, 1),    -- Extension cord

-- Optional accessories
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-CONE'), 'optional', 0, 1),    -- Cone = 0 (optional)
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'CHISEL-FLAT'), 'optional', 0, 1),    -- Flat = 0 (optional)
(9, (SELECT id FROM core.accessories WHERE accessory_code = 'LUBRICANT'), 'optional', 1, 1);      -- Chisel lubricant

-- =============================================================================
-- SAMPLE CUSTOMERS, CONTACTS, AND SITES
-- =============================================================================

-- Sample customers
INSERT INTO core.customers (id, customer_code, customer_name, is_company, registration_number, vat_number, credit_limit, payment_terms, created_by) VALUES
(1000, 'ABC001', 'ABC Construction', true, 'CK2023/123456/23', '4123456789', 50000.00, '30 days', 1),
(1001, 'IND001', 'John Smith', false, NULL, NULL, 5000.00, '7 days', 1),
(1002, 'XYZ001', 'XYZ Builders', true, 'CK2022/987654/23', '4987654321', 25000.00, '30 days', 1);

-- Sample contacts for customers
INSERT INTO core.contacts (id, customer_id, first_name, last_name, job_title, email, phone_number, whatsapp_number, is_primary_contact, is_billing_contact, created_by) VALUES
(1000, 1000, 'John', 'Guy', 'Site Manager', 'john@abcconstruction.co.za', '0821234567', '0821234567', true, false, 1),
(1001, 1000, 'Mary', 'Finance', 'Accounts Manager', 'accounts@abcconstruction.co.za', '0827654321', NULL, false, true, 1),
(1002, 1001, 'John', 'Smith', 'Owner', 'john.smith@email.com', '0823456789', '0823456789', true, true, 1),
(1003, 1002, 'Peter', 'Builder', 'Foreman', 'peter@xyzbuilders.co.za', '0829876543', '0829876543', true, true, 1);

-- Sample sites for customers
INSERT INTO core.sites (customer_id, site_code, site_name, site_type, address_line1, city, province, postal_code, site_contact_name, site_contact_phone, created_by) VALUES
(1000, 'ABC-SAND', 'Sandton Office Development', 'project_site', '123 Rivonia Road', 'Sandton', 'Gauteng', '2196', 'John Guy', '0821234567', 1),
(1000, 'ABC-ROSED', 'Rosebank Mall Extension', 'project_site', '456 Oxford Road', 'Rosebank', 'Gauteng', '2196', 'John Guy', '0821234567', 1),
(1001, 'JS-HOME', 'Home Address', 'delivery_site', '789 Main Street', 'Johannesburg', 'Gauteng', '2000', 'John Smith', '0823456789', 1),
(1002, 'XYZ-WORKSHOP', 'XYZ Workshop', 'head_office', '321 Industrial Road', 'Germiston', 'Gauteng', '1401', 'Peter Builder', '0829876543', 1);

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Test Hilti Breaker setup
-- SELECT 
--     et.type_name,
--     a.accessory_name,
--     ea.accessory_type,
--     ea.default_quantity,
--     a.unit_of_measure
-- FROM core.equipment_types et
-- JOIN core.equipment_accessories ea ON et.id = ea.equipment_type_id
-- JOIN core.accessories a ON ea.accessory_id = a.id  
-- WHERE et.type_code = 'BREAKER-HILTI'
-- ORDER BY ea.accessory_type, a.accessory_name;

-- Test stored procedure with Hilti Breaker
-- SELECT * FROM sp_calculate_auto_accessories('[{"equipment_type_id": 8, "quantity": 1}]');

-- Show all equipment types and their IDs
-- SELECT id, type_code, type_name FROM core.equipment_types ORDER BY id;

-- =============================================================================
-- EXPECTED RESULT WHEN USER SELECTS HILTI BREAKER:
-- =============================================================================
/*
When a user selects "Hilti Breaker", they should see:

🔧 Hilti Breaker (BREAKER-HILTI)                    Qty: [1] [✕]
   Auto-included accessories:
   Moil Point Chisel       [−] 1.0 [+] item        ← Default (starts at 1)
   Spade Chisel           [−] 1.0 [+] item        ← Default (starts at 1)
   Safety Helmet          [−] 1.0 [+] item        ← Default
   Safety Goggles         [−] 1.0 [+] item        ← Default
   Work Gloves            [−] 1.0 [+] item        ← Default
   Breaker Extension Cord [−] 1.0 [+] item        ← Default
   Cone Point Chisel      [−] 0.0 [+] item        ← Optional (starts at 0)
   Flat Chisel            [−] 0.0 [+] item        ← Optional (starts at 0)
   Chisel Lubricant       [−] 1.0 [+] tube        ← Optional

Key features:
- Moil and Spade chisels start at 1 (the 2 defaults you requested)
- Cone and Flat chisels start at 0 (the 2 non-defaults you requested)
- User can adjust all quantities with +/- buttons
- Safety equipment is automatically included
*/