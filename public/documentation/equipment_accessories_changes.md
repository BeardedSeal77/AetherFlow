# Equipment & Accessories System Changes Documentation

## Overview
This document outlines the changes made to the equipment and accessories system to support unified default accessories for both generic equipment types and unique equipment units.

## Date
June 30, 2025

---

## Problem Statement
The previous system had limitations:
- Default accessories were stored as text in `equipment_types.default_accessories` column
- No proper quantity management for accessories
- Difficult to maintain consistent accessories across generic and unique equipment
- No standardized accessory codes or proper consumable tracking

---

## Solution Implemented

### 1. Database Schema Changes

#### **REMOVED**
- `equipment_types.default_accessories` column (TEXT field)

#### **MODIFIED** 
- `core.accessories` table - Completely restructured:
  - Removed `equipment_type_id` foreign key (no longer tied to specific equipment types)
  - Added `accessory_code` VARCHAR(50) UNIQUE NOT NULL
  - Added `unit_of_measure` VARCHAR(20) DEFAULT 'item'
  - Removed `billing_method` column
  - Accessories are now universal/reusable across equipment types

#### **ADDED**
- **`core.equipment_accessories`** - NEW relationship table:
  ```sql
  - equipment_type_id INTEGER (FK to equipment_types)
  - accessory_id INTEGER (FK to accessories)  
  - accessory_type VARCHAR(20) ('default' or 'optional')
  - default_quantity DECIMAL(8,2)
  - created_by INTEGER
  - created_at TIMESTAMP
  - UNIQUE(equipment_type_id, accessory_id)
  ```

- **`core.v_equipment_default_accessories`** - VIEW for easy access to default accessories
- **`core.v_equipment_all_accessories`** - VIEW for all accessories (default + optional)

### 2. Data Structure Changes

#### **Before:**
```sql
equipment_types.default_accessories = "2L petrol, 1 helmet, 1 funnel"
accessories linked directly to equipment_type_id
```

#### **After:**
```sql
accessories: Universal master list with unique codes (PETROL-4S, HELMET, etc.)
equipment_accessories: Links equipment types to accessories with quantities
```

### 3. Key Benefits

1. **Unified Accessories**: Generic "RAMMER-4S" and unique "R1001" both get same defaults
2. **Proper Quantities**: 2L petrol for rammers, 5L for generators  
3. **Reusable Accessories**: HELMET accessory used across all equipment types
4. **Easy Maintenance**: Add accessory once, link to multiple equipment types
5. **Better Tracking**: Consumable vs non-consumable, units of measure

---

## Examples

### Equipment Type: RAMMER-4S (and unique units R1001, R1002, R1003)
**Default Accessories:**
- 2.0 litres PETROL-4S (consumable)
- 1 item HELMET 
- 1 item FUNNEL

**Optional Accessories:**
- 1.0 litres OIL-4S (consumable)
- 1 pair GLOVES

### Equipment Type: GEN-2.5KVA (and unique units GEN001, GEN002)  
**Default Accessories:**
- 5.0 litres PETROL-GEN (consumable)
- 1 item CORD-20M
- 1 item HELMET
- 1 item FUNNEL

---

## Impact on Existing Procedures

### Procedures Requiring Updates

#### **HIGH PRIORITY - Core Functionality**

1. **`sp_get_equipment_accessories`** ⚠️ **CRITICAL**
   - **Current Issue**: Uses old `accessories.equipment_type_id` and `accessories.billing_method`
   - **Required Changes**: Update to use new relationship table and remove billing_method
   - **Impact**: Equipment selection functionality will break

2. **`sp_calculate_auto_accessories`** ⚠️ **CRITICAL**  
   - **Current Issue**: Uses old `accessories.equipment_type_id` and `accessories.billing_method`
   - **Required Changes**: Complete rewrite to use `equipment_accessories` relationship
   - **Impact**: Auto-accessory calculation will fail

3. **`sp_create_hire_interaction`** ⚠️ **HIGH**
   - **Current Issue**: References old accessory structure in interaction_accessories inserts
   - **Required Changes**: Update accessory_id validation and insertion logic
   - **Impact**: Hire creation may fail on accessory assignment

4. **`sp_get_hire_accessories_list`** ⚠️ **HIGH**
   - **Current Issue**: JOINs on old `accessories.equipment_type_id`
   - **Required Changes**: Update JOIN logic to use new relationship tables
   - **Impact**: Accessory display in hire details will be incorrect

#### **MEDIUM PRIORITY - Display/Reporting**

5. **`sp_get_available_equipment_types`** ⚠️ **MEDIUM**
   - **Current Status**: Appears clean - doesn't reference accessories directly
   - **Required Changes**: None immediately, but may need to include accessory counts
   - **Impact**: Equipment type listing should continue working

6. **`sp_get_hire_interaction_details`** ⚠️ **MEDIUM**
   - **Potential Issue**: May include accessory information in output
   - **Required Changes**: Verify accessory display logic
   - **Impact**: Hire detail views may show incorrect accessory info

7. **`sp_get_hire_equipment_list`** ⚠️ **MEDIUM**
   - **Potential Issue**: May show equipment with accessories
   - **Required Changes**: Update if it includes accessory information
   - **Impact**: Equipment lists in hire views

#### **LOW PRIORITY - Edge Cases**

8. **`sp_create_sample_hire`** ⚠️ **LOW**
   - **Current Issue**: Uses hardcoded accessory_ids that may not exist
   - **Required Changes**: Update sample data to use new accessory structure
   - **Impact**: Testing and demo functionality

9. **`sp_get_available_individual_equipment`** ✅ **CLEAN**
   - **Status**: No changes needed - doesn't reference accessories
   - **Impact**: Individual equipment selection continues working

10. **Any Python services using accessories** ⚠️ **MEDIUM**
    - **Files**: `api/services/equipment_service.py`, hire workflow services
    - **Impact**: Python code may expect old accessory data structure

### Detailed Procedure Updates Required

#### **1. sp_get_equipment_accessories (CRITICAL)**
```sql
-- OLD WAY (BROKEN):
SELECT a.id, a.equipment_type_id, a.accessory_name, a.billing_method
FROM core.accessories a 
WHERE a.equipment_type_id = p_equipment_type_id

-- NEW WAY (REQUIRED):
SELECT a.id, ea.equipment_type_id, a.accessory_name, ea.default_quantity, a.unit_of_measure
FROM core.accessories a
JOIN core.equipment_accessories ea ON a.id = ea.accessory_id  
WHERE ea.equipment_type_id = ANY(p_equipment_type_ids)
```

#### **2. sp_calculate_auto_accessories (CRITICAL)**
```sql
-- OLD WAY (BROKEN):
FROM core.accessories a
WHERE a.equipment_type_id = equipment_type_id AND a.accessory_type = 'default'

-- NEW WAY (REQUIRED):  
FROM core.accessories a
JOIN core.equipment_accessories ea ON a.id = ea.accessory_id
WHERE ea.equipment_type_id = equipment_type_id AND ea.accessory_type = 'default'
```

#### **3. sp_get_hire_accessories_list (HIGH)**
```sql
-- OLD WAY (BROKEN):
LEFT JOIN core.equipment_types et ON a.equipment_type_id = et.id

-- NEW WAY (REQUIRED):
LEFT JOIN core.equipment_accessories ea ON a.id = ea.accessory_id  
LEFT JOIN core.equipment_types et ON ea.equipment_type_id = et.id
```

#### **4. sp_create_sample_hire (LOW)**
```sql
-- OLD WAY (MAY BREAK):
sample_accessories := '[{"accessory_id": 1, "quantity": 14.0}]'

-- NEW WAY (REQUIRED):
-- Use accessory_codes to find IDs or update sample data with correct new IDs
```

---

## Migration Notes

### Data Migration Steps (if migrating existing data)
1. Create new accessories master list with unique codes
2. Parse existing `default_accessories` text fields  
3. Create equipment_accessories relationships
4. Verify all equipment types have proper accessories assigned
5. Update all procedures to use new structure
6. Test thoroughly before going live

### Rollback Considerations
- Keep backup of old structure until confident in new system
- Document procedure changes for easy rollback if needed
- Test new system thoroughly with sample data first

---

## Testing Recommendations

1. **Verify Equipment-Accessories Links**: 
   ```sql
   SELECT * FROM core.v_equipment_default_accessories ORDER BY type_code;
   ```

2. **Test Procedure Updates**: Run each updated procedure with sample data

3. **Validate Hire Creation**: Ensure accessories are properly assigned during hire creation

4. **Check Reports**: Verify all accessory-related reports show correct data

---

## Files Modified

- `database/build/tables.sql` - Schema changes
- `database/build/sample_data.sql` - Sample data updated
- Multiple stored procedures (see impact list above)

---

## Next Steps - UPDATE PRIORITY ORDER

### Phase 1: Critical Procedures (Must Fix Immediately)
1. ✅ Update schema (completed)
2. ✅ Update sample data (completed)  
3. 🔄 **NEXT**: Fix `sp_get_equipment_accessories` 
4. 🔄 **NEXT**: Fix `sp_calculate_auto_accessories`
5. ⏳ Fix `sp_get_hire_accessories_list`
6. ⏳ Fix `sp_create_hire_interaction`

### Phase 2: Secondary Procedures  
7. ⏳ Test and verify `sp_create_sample_hire`
8. ⏳ Update any Python services expecting old data structure
9. ⏳ Test all equipment selection workflows

### Phase 3: Validation & Testing
10. ⏳ Run comprehensive tests on hire creation workflow
11. ⏳ Verify accessory assignment works correctly  
12. ⏳ Test equipment type selection with new accessories
13. ⏳ Update any frontend code expecting old accessory format

### Phase 4: Documentation & Deployment
14. ⏳ Update API documentation
15. ⏳ Deploy and validate in staging environment
16. ⏳ Monitor for any missed procedure dependencies