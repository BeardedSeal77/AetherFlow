-- =============================================================================
-- SAMPLE DATA FOR EQUIPMENT HIRE SYSTEM
-- =============================================================================

-- System employee (must be first for foreign key references)
INSERT INTO core.employees (
    id, employee_code, name, surname, role, email, phone_number, hire_date, status, created_at, created_by
) VALUES (
    1, 'SYSTEM', 'System', 'User', 'owner', 'system@localhost', NULL, CURRENT_DATE, 'active', CURRENT_TIMESTAMP, 1
);

-- Additional employees
INSERT INTO core.employees (id, employee_code, name, surname, role, email, phone_number, whatsapp_number, hire_date, created_by) VALUES
(2, 'HC001', 'Sarah', 'Johnson', 'hire_control', 'sarah@company.com', '0111234567', '0781234567', '2023-01-15', 1),
(3, 'ACC001', 'Mike', 'Williams', 'accounts', 'mike@company.com', '0119876543', '0789876543', '2023-02-01', 1),
(4, 'DRV001', 'David', 'Brown', 'driver', 'david@company.com', '0115555555', '0785555555', '2023-03-01', 1),
(5, 'DRV002', 'Chris', 'Wilson', 'driver', 'chris@company.com', '0116666666', '0786666666', '2023-03-15', 1),
(6, 'MGR001', 'Lisa', 'Davis', 'manager', 'lisa@company.com', '0117777777', '0787777777', '2022-12-01', 1);

-- Sample customers
INSERT INTO core.customers (id, customer_code, customer_name, is_company, registration_number, vat_number, credit_limit, created_by) VALUES
(1000, 'ABC001', 'ABC Construction (Pty) Ltd', true, '2020/123456/07', '4123456789', 50000.00, 1),
(1001, 'XYZ001', 'XYZ Engineering', true, '2019/654321/07', '4987654321', 75000.00, 1),
(1002, 'GEN001', 'Generic Customer - Applications', false, NULL, NULL, 0.00, 1);

-- Sample contacts
INSERT INTO core.contacts (id, customer_id, first_name, last_name, job_title, email, phone_number, whatsapp_number, is_primary_contact, created_by) VALUES
(1000, 1000, 'John', 'Guy', 'Site Manager', 'john@abcconstruction.com', '0821234567', '0821234567', true, 1),
(1001, 1000, 'Mary', 'Smith', 'Project Manager', 'mary@abcconstruction.com', '0827654321', '0827654321', false, 1),
(1002, 1001, 'Peter', 'Jones', 'Operations Manager', 'peter@xyzeng.com', '0823456789', '0823456789', true, 1),
(1003, 1002, 'Generic', 'Contact', 'Contact', 'generic@localhost', NULL, NULL, true, 1);

-- Sample sites
INSERT INTO core.sites (id, customer_id, site_code, site_name, site_type, address_line1, city, province, postal_code, site_contact_name, site_contact_phone, created_by) VALUES
(1000, 1000, 'ABC-SAND', 'Sandton Office Development', 'project_site', '123 Rivonia Road', 'Sandton', 'Gauteng', '2196', 'John Guy', '0821234567', 1),
(1001, 1000, 'ABC-CPT', 'Cape Town Warehouse', 'project_site', '456 Main Road', 'Cape Town', 'Western Cape', '8001', 'Sarah Williams', '0829876543', 1),
(1002, 1001, 'XYZ-JHB', 'Johannesburg Head Office', 'head_office', '789 Commissioner Street', 'Johannesburg', 'Gauteng', '2001', 'Peter Jones', '0823456789', 1);

-- Reference prefixes
INSERT INTO system.reference_prefixes (interaction_type, prefix, description) VALUES
('hire', 'HR', 'Equipment Hire'),
('quote', 'QT', 'Quote Request'),
('off_hire', 'OH', 'Off-Hire/Collection'),
('breakdown', 'BD', 'Equipment Breakdown'),
('application', 'AP', 'Account Application');

-- =============================================================================
-- EQUIPMENT DATA
-- =============================================================================

-- Equipment types
INSERT INTO equipment.equipment_types (id, type_code, type_name, description, specifications, daily_rate, weekly_rate, monthly_rate, created_by) VALUES
(1, 'RAMMER-4S', '4 Stroke Rammer', 'Heavy duty 4-stroke petrol rammer for soil compaction', 'Engine: 4-stroke, Weight: 85kg, Impact force: 18kN', 250.00, 1500.00, 5000.00, 1),
(2, 'RAMMER-2S', '2 Stroke Rammer', 'Lightweight 2-stroke petrol rammer for general compaction', 'Engine: 2-stroke, Weight: 65kg, Impact force: 15kN', 200.00, 1200.00, 4000.00, 1),
(3, 'PLATE-SM', 'Small Plate Compactor', 'Small reversible plate compactor for tight spaces', 'Engine: Petrol, Plate size: 400mm, Weight: 120kg', 300.00, 1800.00, 6000.00, 1),
(4, 'POKER-25', 'Concrete Poker 25mm', 'High frequency concrete vibrator poker', 'Diameter: 25mm, Frequency: 12000vpm, Length: 1.5m', 150.00, 900.00, 3000.00, 1),
(5, 'DRIVE-UNIT', 'Poker Drive Unit', 'Electric drive unit for concrete poker', 'Power: 2.2kW, Voltage: 240V, Weight: 35kg', 100.00, 600.00, 2000.00, 1),
(6, 'GRINDER-250', '250mm Angle Grinder', 'Heavy duty angle grinder for cutting and grinding', 'Disc size: 250mm, Power: 2.5kW, Weight: 6kg', 80.00, 480.00, 1600.00, 1),
(7, 'GEN-2.5KVA', '2.5kVA Generator', 'Portable petrol generator for power tools', 'Output: 2.5kVA, Fuel: Petrol, Runtime: 8 hours', 350.00, 2100.00, 7000.00, 1),
(8, 'BREAKER-HILTI', 'Hilti Breaker', 'Heavy duty electric demolition hammer', 'Power: 1500W, Impact energy: 35J, Weight: 8.5kg', 180.00, 1080.00, 3600.00, 1),
(9, 'BREAKER-BOSCH', 'Bosch Breaker', 'Professional electric demolition hammer', 'Power: 1700W, Impact energy: 45J, Weight: 9.2kg', 200.00, 1200.00, 4000.00, 1);

-- Generic equipment (virtual stock for booking)
INSERT INTO equipment.equipment_generic (id, equipment_type_id, generic_code, description, virtual_stock, created_by) VALUES
(1, 1, 'GEN-RAM4S-001', '4-Stroke Rammers - Available Pool', 5, 1),
(2, 2, 'GEN-RAM2S-001', '2-Stroke Rammers - Available Pool', 3, 1),
(3, 3, 'GEN-PLATE-001', 'Small Plate Compactors - Available Pool', 4, 1),
(4, 4, 'GEN-POKER-001', 'Concrete Pokers - Available Pool', 6, 1),
(5, 5, 'GEN-DRIVE-001', 'Drive Units - Available Pool', 4, 1),
(6, 6, 'GEN-GRIND-001', '250mm Grinders - Available Pool', 8, 1),
(7, 7, 'GEN-GEN25-001', '2.5kVA Generators - Available Pool', 3, 1),
(8, 8, 'GEN-HILTI-001', 'Hilti Breakers - Available Pool', 4, 1),
(9, 9, 'GEN-BOSCH-001', 'Bosch Breakers - Available Pool', 3, 1);

-- Specific equipment units
INSERT INTO equipment.equipment (equipment_type_id, asset_code, serial_number, model, condition, status, created_by) VALUES
-- 4-Stroke Rammers
(1, 'R1001', 'WP1550-2023-001', 'Wacker WP1550', 'excellent', 'available', 1),
(1, 'R1002', 'WP1550-2023-002', 'Wacker WP1550', 'good', 'available', 1),
(1, 'R1003', 'WP1550-2022-003', 'Wacker WP1550', 'good', 'available', 1),
(1, 'R1004', 'WP1550-2024-001', 'Wacker WP1550', 'excellent', 'available', 1),
(1, 'R1005', 'WP1550-2024-002', 'Wacker WP1550', 'good', 'available', 1),
-- 2-Stroke Rammers
(2, 'R2001', 'BS50-2024-001', 'Wacker BS50-2', 'excellent', 'available', 1),
(2, 'R2002', 'BS50-2024-002', 'Wacker BS50-2', 'good', 'available', 1),
(2, 'R2003', 'BS50-2023-001', 'Wacker BS50-2', 'good', 'available', 1),
-- Plate Compactors
(3, 'P1001', 'DPU2540-2023-001', 'Wacker DPU2540', 'excellent', 'available', 1),
(3, 'P1002', 'DPU2540-2023-002', 'Wacker DPU2540', 'good', 'available', 1),
(3, 'P1003', 'DPU2540-2024-001', 'Wacker DPU2540', 'excellent', 'available', 1),
(3, 'P1004', 'DPU2540-2024-002', 'Wacker DPU2540', 'good', 'available', 1),
-- Concrete Pokers
(4, 'CP001', 'IEC25-2023-001', 'Inmesol IEC25', 'excellent', 'available', 1),
(4, 'CP002', 'IEC25-2023-002', 'Inmesol IEC25', 'good', 'available', 1),
(4, 'CP003', 'IEC25-2024-001', 'Inmesol IEC25', 'excellent', 'available', 1),
(4, 'CP004', 'IEC25-2024-002', 'Inmesol IEC25', 'good', 'available', 1),
(4, 'CP005', 'IEC25-2024-003', 'Inmesol IEC25', 'good', 'available', 1),
(4, 'CP006', 'IEC25-2023-003', 'Inmesol IEC25', 'good', 'available', 1),
-- Drive Units
(5, 'DU001', 'M5000-2023-001', 'Inmesol M5000', 'excellent', 'available', 1),
(5, 'DU002', 'M5000-2022-001', 'Inmesol M5000', 'good', 'available', 1),
(5, 'DU003', 'M5000-2024-001', 'Inmesol M5000', 'excellent', 'available', 1),
(5, 'DU004', 'M5000-2024-002', 'Inmesol M5000', 'good', 'available', 1),
-- Grinders
(6, 'G1001', 'AG250-2024-001', 'Bosch AG250', 'excellent', 'available', 1),
(6, 'G1002', 'AG250-2024-002', 'Bosch AG250', 'good', 'available', 1),
(6, 'G1003', 'AG250-2023-001', 'Bosch AG250', 'good', 'available', 1),
(6, 'G1004', 'AG250-2023-002', 'Bosch AG250', 'good', 'available', 1),
(6, 'G1005', 'AG250-2024-003', 'Bosch AG250', 'excellent', 'available', 1),
(6, 'G1006', 'AG250-2024-004', 'Bosch AG250', 'good', 'available', 1),
(6, 'G1007', 'AG250-2023-003', 'Bosch AG250', 'good', 'available', 1),
(6, 'G1008', 'AG250-2023-004', 'Bosch AG250', 'good', 'available', 1),
-- Generators
(7, 'GEN001', 'EU25-2023-001', 'Honda EU25i', 'excellent', 'available', 1),
(7, 'GEN002', 'EU25-2023-002', 'Honda EU25i', 'good', 'available', 1),
(7, 'GEN003', 'EU25-2024-001', 'Honda EU25i', 'excellent', 'available', 1),
-- Hilti Breakers
(8, 'BH001', 'TE1000-2024-001', 'Hilti TE 1000-AVR', 'excellent', 'available', 1),
(8, 'BH002', 'TE1000-2024-002', 'Hilti TE 1000-AVR', 'good', 'available', 1),
(8, 'BH003', 'TE1000-2023-001', 'Hilti TE 1000-AVR', 'good', 'available', 1),
(8, 'BH004', 'TE1000-2024-003', 'Hilti TE 1000-AVR', 'excellent', 'available', 1),
-- Bosch Breakers
(9, 'BB001', 'GSH16-2024-001', 'Bosch GSH 16-30', 'excellent', 'available', 1),
(9, 'BB002', 'GSH16-2024-002', 'Bosch GSH 16-30', 'good', 'available', 1),
(9, 'BB003', 'GSH16-2023-001', 'Bosch GSH 16-30', 'good', 'available', 1);

-- =============================================================================
-- ACCESSORIES DATA
-- =============================================================================

-- Master accessories
INSERT INTO equipment.accessories (accessory_code, accessory_name, description, is_consumable, unit_of_measure, unit_rate, created_by) VALUES
-- Fuels
('PETROL-4S', 'Petrol (4-stroke)', 'Unleaded petrol for 4-stroke engines', true, 'litres', 25.50, 1),
('PETROL-2S', 'Petrol (2-stroke)', '2-stroke petrol mix (50:1)', true, 'litres', 28.00, 1),
('PETROL-GEN', 'Generator Petrol', 'Unleaded petrol for generators', true, 'litres', 25.50, 1),

-- Oils and lubricants
('OIL-4S', 'Engine Oil (4-stroke)', 'SAE 30 4-stroke engine oil', true, 'litres', 120.00, 1),
('OIL-2S', '2-stroke Oil', 'High quality 2-stroke oil', true, 'litres', 150.00, 1),

-- Safety equipment
('HELMET', 'Safety Helmet', 'Hard hat for construction work', false, 'item', 15.00, 1),
('GLOVES', 'Work Gloves', 'Heavy duty work gloves', false, 'pair', 25.00, 1),
('GOGGLES', 'Safety Goggles', 'Eye protection for grinding/cutting', false, 'item', 35.00, 1),

-- Tool accessories
('CORD-20M', '20m Extension Cord', 'Heavy duty 20m extension cord', false, 'item', 45.00, 1),
('CORD-10M', '10m Extension Cord', 'Heavy duty 10m extension cord', false, 'item', 30.00, 1),
('DISC-250-CONC', '250mm Concrete Disc', 'Concrete cutting disc for 250mm grinder', true, 'item', 85.00, 1),
('DISC-250-MET', '250mm Metal Disc', 'Metal cutting disc for 250mm grinder', true, 'item', 75.00, 1),

-- Breaker chisels
('CHISEL-MOIL', 'Moil Point Chisel', 'Pointed moil chisel for breaking concrete', false, 'item', 180.00, 1),
('CHISEL-SPADE', 'Spade Chisel', 'Flat spade chisel for chipping and breaking', false, 'item', 165.00, 1),
('CHISEL-CONE', 'Cone Point Chisel', 'Cone-shaped chisel for precise breaking', false, 'item', 175.00, 1),
('CHISEL-FLAT', 'Flat Chisel', 'Wide flat chisel for surface preparation', false, 'item', 155.00, 1),

-- Additional accessories
('FUNNEL', 'Fuel Funnel', 'Plastic funnel for fuel filling', false, 'item', 12.00, 1),
('RAG-PACK', 'Cleaning Rags', 'Pack of cleaning rags', true, 'pack', 18.00, 1),
('CORD-BREAKER', 'Breaker Extension Cord', 'Heavy duty 15m extension cord for breakers', false, 'item', 55.00, 1),
('LUBRICANT', 'Chisel Lubricant', 'Special lubricant for breaker chisels', true, 'tube', 45.00, 1);

-- =============================================================================
-- EQUIPMENT-ACCESSORIES RELATIONSHIPS
-- =============================================================================

-- 4-Stroke Rammer accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories (automatically included)
(1, (SELECT id FROM equipment.accessories WHERE accessory_code = 'PETROL-4S'), 'default', 2.0, 1),    -- 2 litres petrol
(1, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(1, (SELECT id FROM equipment.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories
(1, (SELECT id FROM equipment.accessories WHERE accessory_code = 'OIL-4S'), 'optional', 1.0, 1),       -- 1 litre oil
(1, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- 2-Stroke Rammer accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(2, (SELECT id FROM equipment.accessories WHERE accessory_code = 'PETROL-2S'), 'default', 2.0, 1),     -- 2 litres 2-stroke mix
(2, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(2, (SELECT id FROM equipment.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories
(2, (SELECT id FROM equipment.accessories WHERE accessory_code = 'OIL-2S'), 'optional', 0.5, 1),       -- 0.5 litres 2-stroke oil
(2, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- Small Plate Compactor accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(3, (SELECT id FROM equipment.accessories WHERE accessory_code = 'PETROL-4S'), 'default', 3.0, 1),     -- 3 litres petrol
(3, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(3, (SELECT id FROM equipment.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories
(3, (SELECT id FROM equipment.accessories WHERE accessory_code = 'OIL-4S'), 'optional', 1.0, 1),       -- 1 litre oil
(3, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- Concrete Poker accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(4, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(4, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- 1 pair gloves
-- Optional accessories
(4, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GOGGLES'), 'optional', 1, 1);        -- 1 safety goggles

-- Drive Unit accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(5, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CORD-10M'), 'default', 1, 1),        -- 10m cord
(5, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
-- Optional accessories
(5, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CORD-20M'), 'optional', 1, 1),       -- 20m cord upgrade
(5, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'optional', 1, 1);         -- 1 pair gloves

-- 250mm Grinder accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(6, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(6, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GOGGLES'), 'default', 1, 1),          -- 1 safety goggles
(6, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- 1 pair gloves
-- Optional accessories
(6, (SELECT id FROM equipment.accessories WHERE accessory_code = 'DISC-250-CONC'), 'optional', 2, 1),  -- 2 concrete discs
(6, (SELECT id FROM equipment.accessories WHERE accessory_code = 'DISC-250-MET'), 'optional', 2, 1),   -- 2 metal discs
(6, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CORD-10M'), 'optional', 1, 1);       -- 10m cord

-- 2.5kVA Generator accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(7, (SELECT id FROM equipment.accessories WHERE accessory_code = 'PETROL-GEN'), 'default', 5.0, 1),    -- 5 litres petrol
(7, (SELECT id FROM equipment.accessories WHERE accessory_code = 'FUNNEL'), 'default', 1, 1),          -- 1 funnel
-- Optional accessories
(7, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CORD-20M'), 'optional', 1, 1),       -- 20m extension
(7, (SELECT id FROM equipment.accessories WHERE accessory_code = 'OIL-4S'), 'optional', 1.0, 1);       -- 1 litre oil

-- Hilti Breaker accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GOGGLES'), 'default', 1, 1),          -- 1 safety goggles
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- 1 pair gloves
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CHISEL-MOIL'), 'default', 1, 1),     -- 1 moil chisel
-- Optional accessories
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CHISEL-SPADE'), 'optional', 1, 1),   -- 1 spade chisel
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CHISEL-CONE'), 'optional', 1, 1),    -- 1 cone chisel
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CORD-BREAKER'), 'optional', 1, 1),   -- 15m cord
(8, (SELECT id FROM equipment.accessories WHERE accessory_code = 'LUBRICANT'), 'optional', 1, 1);      -- 1 tube lubricant

-- Bosch Breaker accessories
INSERT INTO equipment.equipment_accessories (equipment_type_id, accessory_id, accessory_type, default_quantity, created_by) VALUES
-- Default accessories
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'HELMET'), 'default', 1, 1),           -- 1 helmet
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GOGGLES'), 'default', 1, 1),          -- 1 safety goggles
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'GLOVES'), 'default', 1, 1),          -- 1 pair gloves
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CHISEL-FLAT'), 'default', 1, 1),     -- 1 flat chisel
-- Optional accessories
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CHISEL-MOIL'), 'optional', 1, 1),    -- 1 moil chisel
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CHISEL-SPADE'), 'optional', 1, 1),   -- 1 spade chisel
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'CORD-BREAKER'), 'optional', 1, 1),   -- 15m cord
(9, (SELECT id FROM equipment.accessories WHERE accessory_code = 'LUBRICANT'), 'optional', 1, 1);      -- 1 tube lubricant
