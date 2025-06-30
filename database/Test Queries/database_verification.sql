-- database_verification.sql
-- Run this to verify your database procedures are working correctly

-- =============================================================================
-- 1. CHECK REQUIRED PROCEDURES EXIST
-- =============================================================================

SELECT 
    n.nspname as schema_name,
    p.proname as procedure_name,
    'EXISTS' as status
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE p.proname IN (
    'sp_get_available_equipment_types',
    'sp_get_equipment_accessories', 
    'sp_calculate_auto_accessories'
)
ORDER BY p.proname;

-- Expected: 3 procedures should be listed

-- =============================================================================
-- 2. CHECK REQUIRED VIEWS EXIST  
-- =============================================================================

SELECT 
    schemaname,
    viewname,
    'EXISTS' as status
FROM pg_views 
WHERE viewname IN (
    'v_equipment_default_accessories',
    'v_equipment_all_accessories', 
    'v_accessories_with_equipment'
);

-- Expected: 3 views should be listed

-- =============================================================================
-- 3. CHECK EQUIPMENT-ACCESSORIES RELATIONSHIP TABLE
-- =============================================================================

SELECT 
    COUNT(*) as total_relationships,
    COUNT(DISTINCT equipment_type_id) as equipment_types_with_accessories,
    COUNT(DISTINCT accessory_id) as accessories_used
FROM core.equipment_accessories;

-- Expected: Should show positive numbers for all counts

-- =============================================================================
-- 4. TEST EQUIPMENT TYPES PROCEDURE
-- =============================================================================

SELECT 
    equipment_type_id,
    type_code,
    type_name,
    total_units,
    available_units
FROM sp_get_available_equipment_types(NULL, '2025-07-01')
LIMIT 5;

-- Expected: Should return equipment types with availability

-- =============================================================================
-- 5. TEST AUTO-ACCESSORIES CALCULATION
-- =============================================================================

SELECT 
    accessory_id,
    accessory_name,
    total_quantity,
    unit_of_measure,
    is_consumable
FROM sp_calculate_auto_accessories('[{"equipment_type_id": 1, "quantity": 2}]');

-- Expected: Should return calculated accessories for equipment type 1

-- =============================================================================
-- 6. TEST EQUIPMENT ACCESSORIES PROCEDURE
-- =============================================================================

SELECT 
    accessory_id,
    equipment_type_id,
    accessory_name,
    accessory_type,
    default_quantity,
    unit_of_measure
FROM sp_get_equipment_accessories(ARRAY[1, 2])
LIMIT 10;

-- Expected: Should return accessories for equipment types 1 and 2

-- =============================================================================
-- 7. CHECK ACCESSORIES VIEW
-- =============================================================================

SELECT 
    accessory_id,
    accessory_name,
    accessory_code,
    equipment_type_count,
    equipment_type_names
FROM core.v_accessories_with_equipment
LIMIT 5;

-- Expected: Should show accessories with their equipment context

-- =============================================================================
-- 8. VERIFY SAMPLE DATA EXISTS
-- =============================================================================

-- Check equipment types
SELECT COUNT(*) as equipment_types_count FROM core.equipment_types WHERE is_active = true;

-- Check accessories  
SELECT COUNT(*) as accessories_count FROM core.accessories WHERE status = 'active';

-- Check equipment-accessory relationships
SELECT COUNT(*) as relationships_count FROM core.equipment_accessories;

-- Expected: All counts should be > 0

-- =============================================================================
-- 9. TEST DEFAULT ACCESSORIES VIEW
-- =============================================================================

SELECT 
    equipment_type_id,
    type_name,
    accessory_name,
    default_quantity,
    unit_of_measure
FROM core.v_equipment_default_accessories
LIMIT 10;

-- Expected: Should show default accessories for equipment types

-- =============================================================================
-- 10. FULL INTEGRATION TEST
-- =============================================================================

-- This simulates what the Python API does:

-- Step 1: Get equipment types
SELECT 'Step 1: Equipment Types' as test_step, COUNT(*) as result_count
FROM sp_get_available_equipment_types(NULL, CURRENT_DATE);

-- Step 2: Calculate auto accessories for sample equipment
SELECT 'Step 2: Auto Accessories' as test_step, COUNT(*) as result_count  
FROM sp_calculate_auto_accessories('[{"equipment_type_id": 1, "quantity": 2}, {"equipment_type_id": 2, "quantity": 1}]');

-- Step 3: Get all accessories for equipment types
SELECT 'Step 3: Equipment Accessories' as test_step, COUNT(*) as result_count
FROM sp_get_equipment_accessories(ARRAY[1, 2]);

-- Step 4: Get all accessories (standalone)
SELECT 'Step 4: All Accessories' as test_step, COUNT(*) as result_count
FROM core.v_accessories_with_equipment;

-- Expected: All steps should return positive counts

-- =============================================================================
-- TROUBLESHOOTING SECTION
-- =============================================================================

-- If any tests fail, run these diagnostic queries:

-- Check if procedures were created properly
SELECT 
    p.proname,
    p.prosrc LIKE '%UPDATED%' as is_updated_version
FROM pg_proc p 
WHERE p.proname LIKE 'sp_%accessories%';

-- Check for procedure compilation errors
SELECT 
    proname,
    prorettype,
    proargtypes
FROM pg_proc 
WHERE proname IN ('sp_get_equipment_accessories', 'sp_calculate_auto_accessories')
ORDER BY proname;

-- Check table structure
\d core.equipment_accessories
\d core.accessories

-- Check for foreign key relationships
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'equipment_accessories';