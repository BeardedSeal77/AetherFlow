-- =============================================================================
-- INITIAL DATA - UPDATED FOR NEW SCHEMA
-- =============================================================================

-- System employee
INSERT INTO core.employees (
    id, employee_code, name, surname, role, email, phone_number, hire_date, status, created_at
) VALUES (
    1, 'SYSTEM', 'System', 'User', 'owner', 'system@localhost', NULL, CURRENT_DATE, 'active', CURRENT_TIMESTAMP
);

-- Generic customer for applications
INSERT INTO core.customers (
    id, customer_code, customer_name, is_company, created_by
) VALUES (
    999, 'GENERIC', 'Generic Customer - Applications', false, 1
);

-- Generic contact
INSERT INTO core.contacts (
    id, customer_id, first_name, last_name, is_primary_contact
) VALUES (
    999, 999, 'Generic', 'Contact', true
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

-- Sample equipment types (renamed from equipment_categories)
INSERT INTO core.equipment_types (type_code, type_name, description, specifications) VALUES
('RAMMER-4S', '4 Stroke Rammer', 'Heavy duty 4-stroke petrol rammer for soil compaction', 'Engine: 4-stroke, Weight: 85kg, Impact force: 18kN'),
('RAMMER-2S', '2 Stroke Rammer', 'Lightweight 2-stroke petrol rammer for general compaction', 'Engine: 2-stroke, Weight: 65kg, Impact force: 15kN'),
('PLATE-SM', 'Small Plate Compactor', 'Small reversible plate compactor for tight spaces', 'Engine: Petrol, Plate size: 400mm, Weight: 120kg'),
('POKER-25', 'Concrete Poker 25mm', 'High frequency concrete vibrator poker', 'Diameter: 25mm, Frequency: 12000vpm, Length: 1.5m'),
('DRIVE-UNIT', 'Poker Drive Unit', 'Electric drive unit for concrete poker', 'Power: 2.2kW, Voltage: 240V, Weight: 35kg'),
('GRINDER-250', '250mm Angle Grinder', 'Heavy duty angle grinder for cutting and grinding', 'Disc size: 250mm, Power: 2.5kW, Weight: 6kg'),
('GEN-2.5KVA', '2.5kVA Generator', 'Portable petrol generator for power tools', 'Output: 2.5kVA, Fuel: Petrol, Runtime: 8 hours');

-- Sample individual equipment units
INSERT INTO core.equipment (equipment_type_id, asset_code, serial_number, model, condition, status) VALUES
-- Rammers (4-stroke)
(1, 'R1001', 'WP1550-2023-001', 'Wacker WP1550', 'excellent', 'available'),
(1, 'R1002', 'WP1550-2023-002', 'Wacker WP1550', 'good', 'available'),
(1, 'R1003', 'WP1550-2022-003', 'Wacker WP1550', 'good', 'available'),
-- Rammers (2-stroke)
(2, 'R2001', 'BS50-2024-001', 'Wacker BS50-2', 'excellent', 'available'),
(2, 'R2002', 'BS50-2024-002', 'Wacker BS50-2', 'good', 'available'),
-- Plate compactors
(3, 'P1001', 'DPU2540-2023-001', 'Wacker DPU2540', 'excellent', 'available'),
(3, 'P1002', 'DPU2540-2023-002', 'Wacker DPU2540', 'good', 'available'),
-- Concrete pokers
(4, 'CP001', 'IEC25-2023-001', 'Inmesol IEC25', 'excellent', 'available'),
(4, 'CP002', 'IEC25-2023-002', 'Inmesol IEC25', 'good', 'available'),
-- Drive units
(5, 'DU001', 'M5000-2023-001', 'Inmesol M5000', 'excellent', 'available'),
(5, 'DU002', 'M5000-2022-001', 'Inmesol M5000', 'good', 'available'),
-- Grinders
(6, 'G1001', 'AG250-2024-001', 'Bosch AG250', 'excellent', 'available'),
(6, 'G1002', 'AG250-2024-002', 'Bosch AG250', 'good', 'available'),
-- Generators
(7, 'GEN001', 'EU25-2023-001', 'Honda EU25i', 'excellent', 'available'),
(7, 'GEN002', 'EU25-2023-002', 'Honda EU25i', 'good', 'available');

-- Sample accessories (updated to reference equipment_types)
INSERT INTO core.accessories (equipment_type_id, accessory_name, accessory_type, billing_method, quantity, description, is_consumable, created_by) VALUES
-- Petrol for rammers and generators
(1, 'Petrol', 'default', 'consumption', 2, '4-stroke petrol', true, 1),
(2, 'Petrol', 'default', 'consumption', 2, '2-stroke petrol mix', true, 1),
(7, 'Petrol', 'default', 'consumption', 5, 'Unleaded petrol for generator', true, 1),
-- Safety equipment (default with all equipment)
(1, 'Safety helmet', 'default', 'fixed', 1, 'Hard hat', false, 1),
(2, 'Safety helmet', 'default', 'fixed', 1, 'Hard hat', false, 1),
(3, 'Safety helmet', 'default', 'fixed', 1, 'Hard hat', false, 1),
(4, 'Safety helmet', 'default', 'fixed', 1, 'Hard hat', false, 1),
(5, 'Safety helmet', 'default', 'fixed', 1, 'Hard hat', false, 1),
(6, 'Safety helmet', 'default', 'fixed', 1, 'Hard hat', false, 1),
(7, 'Safety helmet', 'default', 'fixed', 1, 'Hard hat', false, 1),
-- Generator specific accessories
(7, 'Extension cord', 'default', 'fixed', 1, '20m heavy duty extension cord', false, 1),
-- Grinder specific accessories
(6, 'Cutting disc', 'optional', 'consumption', 2, '250mm concrete cutting disc', true, 1),
-- Engine oil for 4-stroke equipment
(1, 'Engine oil', 'optional', 'consumption', 1, '4-stroke engine oil', true, 1),
(7, 'Engine oil', 'optional', 'consumption', 1, '4-stroke engine oil', true, 1);

-- Sample customer data for testing (starting from ID 1000 to avoid conflicts with generic customer)
INSERT INTO core.customers (id, customer_code, customer_name, is_company, registration_number, vat_number, credit_limit, payment_terms, created_by) VALUES
(1000, 'ABC001', 'ABC Construction', true, 'CK2023/123456/23', '4123456789', 50000.00, '30 days', 1),
(1001, 'IND001', 'John Smith', false, NULL, NULL, 5000.00, '7 days', 1),
(1002, 'XYZ001', 'XYZ Builders', true, 'CK2022/987654/23', '4987654321', 25000.00, '30 days', 1);

-- Sample contacts for customers (starting from ID 1000 to avoid conflicts with generic contact)
INSERT INTO core.contacts (id, customer_id, first_name, last_name, job_title, email, phone_number, whatsapp_number, is_primary_contact, is_billing_contact) VALUES
(1000, 1000, 'John', 'Guy', 'Site Manager', 'john@abcconstruction.co.za', '0821234567', '0821234567', true, false),
(1001, 1000, 'Mary', 'Finance', 'Accounts Manager', 'accounts@abcconstruction.co.za', '0827654321', NULL, false, true),
(1002, 1001, 'John', 'Smith', 'Owner', 'john.smith@email.com', '0823456789', '0823456789', true, true),
(1003, 1002, 'Peter', 'Builder', 'Foreman', 'peter@xyzbuilders.co.za', '0829876543', '0829876543', true, true);

-- Sample sites for customers
INSERT INTO core.sites (customer_id, site_code, site_name, site_type, address_line1, city, province, postal_code, site_contact_name, site_contact_phone) VALUES
(1000, 'ABC-SAND', 'Sandton Office Development', 'project_site', '123 Rivonia Road', 'Sandton', 'Gauteng', '2196', 'John Guy', '0821234567'),
(1000, 'ABC-ROSED', 'Rosebank Mall Extension', 'project_site', '456 Oxford Road', 'Rosebank', 'Gauteng', '2196', 'John Guy', '0821234567'),
(1001, 'JS-HOME', 'Home Address', 'delivery_site', '789 Main Street', 'Johannesburg', 'Gauteng', '2000', 'John Smith', '0823456789'),
(1002, 'XYZ-WORKSHOP', 'XYZ Workshop', 'head_office', '321 Industrial Road', 'Germiston', 'Gauteng', '1401', 'Peter Builder', '0829876543');

-- Sample employees (starting from ID 2 since ID 1 is system user)
INSERT INTO core.employees (id, employee_code, name, surname, role, email, phone_number, whatsapp_number, hire_date) VALUES
(2, 'HC001', 'Sarah', 'Johnson', 'hire_control', 'sarah@company.com', '0111234567', '0781234567', '2023-01-15'),
(3, 'ACC001', 'Mike', 'Williams', 'accounts', 'mike@company.com', '0119876543', '0789876543', '2023-02-01'),
(4, 'DRV001', 'David', 'Brown', 'driver', 'david@company.com', '0115555555', '0785555555', '2023-03-01'),
(5, 'DRV002', 'Chris', 'Wilson', 'driver', 'chris@company.com', '0116666666', '0786666666', '2023-03-15'),
(6, 'MGR001', 'Lisa', 'Davis', 'manager', 'lisa@company.com', '0117777777', '0787777777', '2022-12-01');