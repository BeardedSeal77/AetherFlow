# Equipment & Accessories Selection - Complete Process Documentation

## 🎯 **DESIRED USER EXPERIENCE**

### **Step 1: Equipment Selection**
- User sees searchable dropdown: "Add Equipment"
- User types "Hilti" → sees "Hilti Breaker" option
- User clicks → Equipment added to selection summary

### **Step 2: Automatic Accessories**
- System automatically adds default accessories for Hilti Breaker:
  - Moil Chisel: 1 (default)
  - Spade Chisel: 1 (default) 
  - Cone Chisel: 0 (optional)
  - Flat Chisel: 0 (optional)

### **Step 3: Manual Accessories** 
- User can search "Add Accessories" for standalone items
- User can adjust quantities of auto-added accessories

### **Step 4: Selection Summary**
- Shows equipment with nested auto-accessories
- Shows standalone accessories separately
- User can adjust all quantities with +/- buttons

### **Final UI Structure**
```
Selection Summary:
  🔧 4 Stroke Rammer (RAMMER-4S)                    Qty: [1] [✕]
     Auto-included accessories:
     Petrol (4-stroke)     [−] 2.0 [+] litres
     Fuel Funnel          [−] 1.0 [+] item  
     Safety Helmet        [−] 1.0 [+] item

  🔧 Hilti Breaker (BREAKER-HILTI)                  Qty: [1] [✕]
     Auto-included accessories:
     Moil Chisel          [−] 1.0 [+] item
     Spade Chisel         [−] 1.0 [+] item
     Cone Chisel          [−] 0.0 [+] item
     Flat Chisel          [−] 0.0 [+] item

  Additional Accessories:
  Spare Extension Cord     [−] 2.0 [+] item
```

---

## 🗄️ **DATABASE LAYER**

### **Stored Procedure: `sp_calculate_auto_accessories`**

**Location:** `database/procedures/equipment_selection_procedures/sp_calculate_auto_accessories.sql`

**Purpose:** Calculate default accessories for selected equipment with proper aggregation

**Function Signature:**
```sql
CREATE OR REPLACE FUNCTION sp_calculate_auto_accessories(
    p_equipment_selections JSONB
)
RETURNS TABLE(
    accessory_id INTEGER,
    accessory_name VARCHAR(255),
    accessory_code VARCHAR(50),
    total_quantity DECIMAL(8,2),
    unit_of_measure VARCHAR(20),
    is_consumable BOOLEAN,
    equipment_type_name TEXT
)
```

**Input Format:** 
```json
[
  {"equipment_type_id": 1, "quantity": 2},
  {"equipment_type_id": 3, "quantity": 1}
]
```

**Output Format:**
```json
[
  {
    "accessory_id": 1,
    "accessory_name": "Petrol (4-stroke)",
    "accessory_code": "PETROL-4S", 
    "total_quantity": 4.00,
    "unit_of_measure": "litres",
    "is_consumable": true,
    "equipment_type_name": "4 Stroke Rammer"
  },
  {
    "accessory_id": 6,
    "accessory_name": "Safety Helmet",
    "accessory_code": "HELMET",
    "total_quantity": 3.00,
    "unit_of_measure": "item", 
    "is_consumable": false,
    "equipment_type_name": "4 Stroke Rammer, Generator"
  }
]
```

**Key Database Tables:**
- `core.equipment_types` - Equipment definitions (id, type_code, type_name)
- `core.accessories` - Accessory definitions (id, accessory_name, accessory_code)
- `core.equipment_accessories` - Links equipment to accessories with default quantities

**Sample Data Relationships:**
```sql
-- Equipment Type: 4 Stroke Rammer (ID: 1)
-- Default Accessories:
--   - Petrol (4-stroke): 2.0 litres (default)
--   - Safety Helmet: 1.0 item (default)  
--   - Fuel Funnel: 1.0 item (default)

-- Equipment Type: Hilti Breaker (ID: 2) 
-- Default Accessories:
--   - Moil Chisel: 1.0 item (default)
--   - Spade Chisel: 1.0 item (default)
--   - Cone Chisel: 0.0 item (optional)
--   - Flat Chisel: 0.0 item (optional)
```

### **Testing the Stored Procedure**
```sql
-- Test with single equipment
SELECT * FROM sp_calculate_auto_accessories('[{"equipment_type_id": 1, "quantity": 1}]');

-- Test with multiple equipment
SELECT * FROM sp_calculate_auto_accessories('[
  {"equipment_type_id": 1, "quantity": 2},
  {"equipment_type_id": 2, "quantity": 1}
]');
```

---

## 🔧 **BACKEND API LAYER**

### **File: `api/diary/hire_management.py`**

#### **Endpoint 1: Get Equipment Types**
```python
@hire_bp.route('/equipment/types', methods=['GET'])
def get_equipment_types():
    """Get available equipment types for selection"""
```

**URL:** `GET /api/hire/equipment/types?delivery_date=2025-07-01`  
**Purpose:** Load equipment for searchable dropdown  
**Service Call:** `equipment_service.get_equipment_types(search_term, delivery_date)`  
**Response Format:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "type_code": "RAMMER-4S",
      "type_name": "4 Stroke Rammer",
      "description": "Heavy duty compaction rammer",
      "available_units": 2,
      "total_units": 3
    }
  ]
}
```

#### **Endpoint 2: Get All Accessories**
```python
@hire_bp.route('/equipment/accessories', methods=['GET'])
def get_all_accessories_list():
    """Get all accessories for standalone selection"""
```

**URL:** `GET /api/hire/equipment/accessories`  
**Purpose:** Load accessories for searchable dropdown  
**Service Call:** `equipment_service.get_equipment_accessories([])`  
**Response Format:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "accessory_name": "Petrol (4-stroke)",
      "accessory_code": "PETROL-4S",
      "unit_of_measure": "litres",
      "is_consumable": true
    }
  ]
}
```

#### **Endpoint 3: Calculate Auto-Accessories**
```python
@hire_bp.route('/equipment/auto-accessories', methods=['POST'])
def calculate_auto_accessories():
    """Calculate default accessories for equipment selection"""
```

**URL:** `POST /api/hire/equipment/auto-accessories`  
**Purpose:** Get default accessories for selected equipment  
**Service Call:** `equipment_service.calculate_auto_accessories(equipment_selections)`  
**Request Format:**
```json
{
  "equipment_selections": [
    {"equipment_type_id": 1, "quantity": 1},
    {"equipment_type_id": 2, "quantity": 2}
  ]
}
```
**Response Format:**
```json
{
  "success": true,
  "data": [
    {
      "accessory_id": 1,
      "accessory_name": "Petrol (4-stroke)",
      "accessory_code": "PETROL-4S",
      "quantity": 2.0,
      "unit_of_measure": "litres",
      "is_consumable": true,
      "equipment_type_name": "4 Stroke Rammer",
      "is_default": true
    }
  ]
}
```

### **File: `api/services/equipment_service.py`**

#### **Method: `get_equipment_types()`**
```python
def get_equipment_types(self, search_term=None, delivery_date=None):
    """Get available equipment types for selection"""
    equipment_types = self.db.execute_procedure(
        'sp_get_available_equipment_types',
        [search_term, delivery_date]
    )
    # Format for frontend
    return formatted_equipment
```

#### **Method: `get_equipment_accessories()`**
```python
def get_equipment_accessories(self, equipment_type_ids=[]):
    """Get accessories available for selection"""
    accessories = self.db.execute_procedure(
        'sp_get_equipment_accessories',
        [equipment_type_ids]
    )
    # Format and deduplicate
    return formatted_accessories
```

#### **Method: `calculate_auto_accessories()`**
```python
def calculate_auto_accessories(self, equipment_selections):
    """Calculate default accessories for equipment selection"""
    # 1. Convert to JSON
    equipment_json = json.dumps(equipment_selections)
    
    # 2. Call stored procedure  
    auto_accessories = self.db.execute_procedure(
        'sp_calculate_auto_accessories',
        [equipment_json]
    )
    
    # 3. Format for frontend
    return [{
        'accessory_id': acc['accessory_id'],
        'accessory_name': acc['accessory_name'],
        'accessory_code': acc['accessory_code'],
        'quantity': float(acc['total_quantity']),
        'unit_of_measure': acc['unit_of_measure'],
        'is_consumable': acc['is_consumable'],
        'equipment_type_name': acc['equipment_type_name'],
        'is_default': True
    } for acc in auto_accessories]
```

---

## 🖥️ **FRONTEND LAYER**

### **File: `app/components/interaction/EquipmentSelection.tsx`**

#### **Key State Variables**
```tsx
// Equipment state
const [equipmentTypes, setEquipmentTypes] = useState<EquipmentType[]>([])
const [equipmentSearch, setEquipmentSearch] = useState('')
const [showEquipmentDropdown, setShowEquipmentDropdown] = useState(false)

// Accessory state  
const [allAccessories, setAllAccessories] = useState<Accessory[]>([])
const [autoAccessories, setAutoAccessories] = useState<AutoAccessory[]>([])
const [accessorySearch, setAccessorySearch] = useState('')
const [showAccessoryDropdown, setShowAccessoryDropdown] = useState(false)

// Selection state (passed from parent)
const [equipmentSelections, setEquipmentSelections] = useState<EquipmentSelection[]>([])
const [accessorySelections, setAccessorySelections] = useState<AccessorySelection[]>([])

// Loading states
const [isLoading, setIsLoading] = useState(false)
const [isCalculatingAccessories, setIsCalculatingAccessories] = useState(false)
```

#### **Key Interfaces**
```tsx
interface EquipmentSelection {
  equipment_type_id: number
  quantity: number
  type_name?: string
  type_code?: string
}

interface AccessorySelection {
  accessory_id: number
  quantity: number
  accessory_type: string // 'equipment_default', 'standalone'
  accessory_name?: string
  unit_of_measure?: string
  is_consumable?: boolean
}

interface AutoAccessory {
  accessory_id: number
  accessory_name: string
  accessory_code: string
  quantity: number
  unit_of_measure: string
  is_consumable: boolean
  equipment_type_name: string
  is_default: boolean
}
```

#### **Key Functions**

##### **1. Data Loading Functions**
```tsx
const loadEquipmentTypes = async () => {
  // Fetch equipment for dropdown
  const response = await fetch(`/api/hire/equipment/types`)
  const data = await response.json()
  setEquipmentTypes(data.data)
}

const loadAllAccessories = async () => {
  // Fetch accessories for dropdown
  const response = await fetch('/api/hire/equipment/accessories')
  const data = await response.json()
  setAllAccessories(data.data)
}
```

##### **2. Equipment Selection Functions**
```tsx
const addEquipmentType = (equipment: EquipmentType) => {
  // Add equipment to selection or increase quantity
  const existing = equipmentSelections.find(e => e.equipment_type_id === equipment.equipment_type_id)
  
  if (existing) {
    updateEquipmentQuantity(equipment.equipment_type_id, existing.quantity + 1)
  } else {
    const newSelection: EquipmentSelection = {
      equipment_type_id: equipment.equipment_type_id,
      quantity: 1,
      type_name: equipment.type_name,
      type_code: equipment.type_code
    }
    onEquipmentChange([...equipmentSelections, newSelection])
  }
}

const updateEquipmentQuantity = (equipmentTypeId: number, newQuantity: number) => {
  if (newQuantity <= 0) {
    const updated = equipmentSelections.filter(e => e.equipment_type_id !== equipmentTypeId)
    onEquipmentChange(updated)
  } else {
    const updated = equipmentSelections.map(e =>
      e.equipment_type_id === equipmentTypeId ? { ...e, quantity: newQuantity } : e
    )
    onEquipmentChange(updated)
  }
}
```

##### **3. Auto-Accessories Calculation**
```tsx
const calculateAutoAccessories = async () => {
  try {
    setIsCalculatingAccessories(true)
    
    // Transform for API
    const equipmentSelectionsForAPI = equipmentSelections.map(eq => ({
      equipment_type_id: eq.equipment_type_id,
      quantity: eq.quantity || 1
    }))

    // Validate
    const validSelections = equipmentSelectionsForAPI.filter(eq => 
      eq.equipment_type_id && eq.quantity > 0
    )

    if (validSelections.length === 0) {
      setAutoAccessories([])
      return
    }

    // API Call
    const response = await fetch('/api/hire/equipment/auto-accessories', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ equipment_selections: validSelections }),
    })

    const data = await response.json()
    
    if (data.success) {
      setAutoAccessories(data.data || [])
      
      // Convert to AccessorySelection format
      const autoAccessorySelections: AccessorySelection[] = (data.data || []).map((auto: AutoAccessory) => ({
        accessory_id: auto.accessory_id,
        quantity: auto.quantity,
        accessory_type: 'equipment_default',
        accessory_name: auto.accessory_name,
        unit_of_measure: auto.unit_of_measure,
        is_consumable: auto.is_consumable
      }))
      
      // Combine with standalone accessories
      const standaloneAccessories = accessorySelections.filter(as => as.accessory_type === 'standalone')
      const combinedAccessories = [...autoAccessorySelections, ...standaloneAccessories]
      onAccessoriesChange(combinedAccessories)
    }
  } catch (error) {
    console.error('Error calculating auto-accessories:', error)
    setAutoAccessories([])
  } finally {
    setIsCalculatingAccessories(false)
  }
}
```

##### **4. Accessory Management Functions**
```tsx
const addStandaloneAccessory = (accessory: Accessory) => {
  const newAccessorySelection: AccessorySelection = {
    accessory_id: accessory.accessory_id,
    quantity: 1,
    accessory_type: 'standalone',
    accessory_name: accessory.accessory_name,
    unit_of_measure: accessory.unit_of_measure,
    is_consumable: accessory.is_consumable
  }
  
  onAccessoriesChange([...accessorySelections, newAccessorySelection])
}

const updateAutoAccessoryQuantity = (accessoryId: number, newQuantity: number) => {
  // Update auto-accessories state
  const updatedAutoAccessories = autoAccessories.map(a =>
    a.accessory_id === accessoryId ? { ...a, quantity: Math.max(0, newQuantity) } : a
  )
  setAutoAccessories(updatedAutoAccessories)
  
  // Update accessory selections
  const autoAccessorySelections = updatedAutoAccessories.map(auto => ({
    accessory_id: auto.accessory_id,
    quantity: auto.quantity,
    accessory_type: 'equipment_default',
    accessory_name: auto.accessory_name,
    unit_of_measure: auto.unit_of_measure,
    is_consumable: auto.is_consumable
  }))
  
  const standaloneAccessories = accessorySelections.filter(as => as.accessory_type === 'standalone')
  const combinedAccessories = [...autoAccessorySelections, ...standaloneAccessories]
  onAccessoriesChange(combinedAccessories)
}
```

#### **Key useEffect Hooks**
```tsx
// Load initial data
useEffect(() => {
  loadEquipmentTypes()
  loadAllAccessories()
}, [deliveryDate])

// Calculate auto-accessories when equipment changes
useEffect(() => {
  if (equipmentSelections.length > 0) {
    calculateAutoAccessories()  // ← Critical trigger
  } else {
    setAutoAccessories([])
    const standaloneOnly = accessorySelections.filter(as => as.accessory_type === 'standalone')
    onAccessoriesChange(standaloneOnly)
  }
}, [equipmentSelections]) // ← Dependency array
```

---

## 🔄 **COMPLETE DATA FLOW**

### **1. Page Load Sequence**
```
1. Component mounts
   ↓
2. useEffect triggers loadEquipmentTypes()
   ↓  
3. Frontend → GET /api/hire/equipment/types
   ↓
4. Backend → sp_get_available_equipment_types
   ↓
5. Equipment dropdown populated

6. useEffect triggers loadAllAccessories()
   ↓
7. Frontend → GET /api/hire/equipment/accessories  
   ↓
8. Backend → sp_get_equipment_accessories([])
   ↓
9. Accessories dropdown populated
```

### **2. User Selects Equipment**
```
1. User clicks "4 Stroke Rammer" in dropdown
   ↓
2. addEquipmentType() called
   ↓ 
3. onEquipmentChange() updates parent state
   ↓
4. equipmentSelections = [{equipment_type_id: 1, quantity: 1}]
   ↓
5. useEffect dependency [equipmentSelections] triggers
   ↓
6. calculateAutoAccessories() called
   ↓
7. POST /api/hire/equipment/auto-accessories
   Body: {"equipment_selections": [{"equipment_type_id": 1, "quantity": 1}]}
   ↓
8. Backend → equipment_service.calculate_auto_accessories()
   ↓
9. Backend → sp_calculate_auto_accessories('[{"equipment_type_id": 1, "quantity": 1}]')
   ↓
10. Stored procedure returns:
    [
      {"accessory_id": 1, "accessory_name": "Petrol", "total_quantity": "2.00"},
      {"accessory_id": 6, "accessory_name": "Safety Helmet", "total_quantity": "1.00"}
    ]
   ↓
11. Backend formats and returns to frontend
   ↓
12. Frontend setAutoAccessories([...]) updates state
   ↓
13. Frontend converts to AccessorySelection format
   ↓
14. Frontend calls onAccessoriesChange() to update parent
   ↓
15. UI re-renders showing equipment with nested accessories
```

### **3. Expected UI Result**
```
Selection Summary:
  🔧 4 Stroke Rammer (RAMMER-4S)                    Qty: [1] [✕]
     Auto-included accessories:
     Petrol (4-stroke)     [−] 2.0 [+] litres
     Fuel Funnel          [−] 1.0 [+] item  
     Safety Helmet        [−] 1.0 [+] item
```

### **4. User Adjusts Auto-Accessory Quantity**
```
1. User clicks [+] next to "Petrol (4-stroke)"
   ↓
2. updateAutoAccessoryQuantity(1, 3.0) called
   ↓
3. autoAccessories state updated (quantity: 2.0 → 3.0)
   ↓
4. AccessorySelection array updated and passed to parent
   ↓
5. UI shows new quantity: [−] 3.0 [+]
```

---

## 🔍 **TROUBLESHOOTING CHECKLIST**

### **Database Layer Issues**
- [ ] **Stored procedure exists:** `\df sp_calculate_auto_accessories`
- [ ] **Stored procedure runs:** `SELECT * FROM sp_calculate_auto_accessories('[{"equipment_type_id": 1, "quantity": 1}]');`
- [ ] **Equipment types exist:** `SELECT id, type_code, type_name FROM core.equipment_types LIMIT 5;`
- [ ] **Accessories exist:** `SELECT id, accessory_name FROM core.accessories LIMIT 5;`
- [ ] **Relationships exist:** `SELECT * FROM core.equipment_accessories WHERE accessory_type = 'default' LIMIT 5;`

### **Backend API Issues** 
- [ ] **Debug endpoint works:** `GET /api/hire/equipment/debug-auto-accessories`
- [ ] **Equipment types endpoint:** `GET /api/hire/equipment/types` returns data
- [ ] **Accessories endpoint:** `GET /api/hire/equipment/accessories` returns data  
- [ ] **Auto-accessories endpoint:** `POST /api/hire/equipment/auto-accessories` with test data
- [ ] **Service method exists:** `equipment_service.calculate_auto_accessories()` is defined
- [ ] **JSON import exists:** `import json` at top of files

### **Frontend State Issues**
- [ ] **equipmentSelections updates:** Console shows state change when equipment selected
- [ ] **useEffect triggers:** calculateAutoAccessories() is called when equipment changes
- [ ] **API call succeeds:** Network tab shows 200 response with data
- [ ] **autoAccessories updates:** State is set with returned data
- [ ] **UI renders:** Auto-accessories section appears in DOM

### **Integration Issues**
- [ ] **Data format consistent:** Frontend sends `equipment_type_id`, backend expects `equipment_type_id`
- [ ] **Error handling:** Failures don't silently break the chain
- [ ] **React keys unique:** No "Each child should have unique key" warnings
- [ ] **Parent state updates:** onEquipmentChange() and onAccessoriesChange() work correctly

---

## 🚀 **TESTING SEQUENCE**

### **Step 1: Test Database Layer**
```sql
-- Verify stored procedure works
SELECT * FROM sp_calculate_auto_accessories('[{"equipment_type_id": 1, "quantity": 1}]');

-- Should return 2-3 accessories with quantities
```

### **Step 2: Test Backend API**
```bash
# Test debug endpoint
curl http://localhost:5328/api/hire/equipment/debug-auto-accessories

# Test equipment types
curl http://localhost:5328/api/hire/equipment/types

# Test auto-accessories  
curl -X POST http://localhost:5328/api/hire/equipment/auto-accessories \
  -H "Content-Type: application/json" \
  -d '{"equipment_selections": [{"equipment_type_id": 1, "quantity": 1}]}'
```

### **Step 3: Test Frontend State**
Add to `EquipmentSelection.tsx` temporarily:
```tsx
console.log('=== STATE DEBUG ===')
console.log('equipmentSelections:', equipmentSelections)
console.log('autoAccessories:', autoAccessories)
console.log('accessorySelections:', accessorySelections)
```

### **Step 4: Test Integration**
1. Open browser dev tools → Console tab
2. Select equipment in UI
3. Verify console shows:
   - State updates
   - API calls  
   - Response data
   - UI updates

### **Step 5: Test User Experience**
1. Select "4 Stroke Rammer"
2. Verify auto-accessories appear
3. Adjust quantities with +/- buttons
4. Add standalone accessories
5. Verify selection summary is correct

---

## 📁 **FILE LOCATIONS SUMMARY**

### **Database**
- `database/procedures/equipment_selection_procedures/sp_calculate_auto_accessories.sql`

### **Backend**  
- `api/diary/hire_management.py` - API endpoints
- `api/services/equipment_service.py` - Business logic
- `api/database/database_service.py` - Database connection

### **Frontend**
- `app/components/interaction/EquipmentSelection.tsx` - Main component
- `app/diary/new-interaction/page.tsx` - Parent page that uses component

### **Debugging**
- `GET /api/hire/equipment/debug-auto-accessories` - Backend debugging
- Browser console - Frontend debugging
- pgAdmin - Database debugging

This systematic approach should help identify exactly where any issues occur in the complete equipment & accessories selection flow.