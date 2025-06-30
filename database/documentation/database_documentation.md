# Equipment Hire Management System - Database Documentation

## Overview

This database supports an equipment hire management system that handles the complete lifecycle of equipment rentals, from customer selection and booking through to allocation, delivery, and quality control.

## Database Architecture

The system uses a **three-layer architecture**:
- **Frontend (NextJS)**: User interface
- **Python Services**: Business logic and validation
- **PostgreSQL Database**: Data storage with stored procedures

---

## 📁 Folder Structure

### `/build/` - Database Setup Files
Core files needed to create and initialize the database.

| File | Purpose |
|------|---------|
| `00_docker_setup` | Docker configuration for PostgreSQL container setup |
| `tables.sql` | **Main schema definition** - Creates all tables, indexes, and constraints |
| `sample_data.sql` | **Test data** - Inserts sample customers, equipment, and accessories for testing |

### `/documentation/` - System Documentation
High-level system documentation and process flows.

| File | Purpose |
|------|---------|
| `hire_process.txt` | **Business process documentation** - How equipment hire workflow works |
| `system_architecture.txt` | **Technical architecture** - API specifications and data flow diagrams |

### `/procedures/` - Stored Procedures (Business Logic)
All database stored procedures organized by functional area.

#### `/customer_selection_procedures/` - Customer Management
Procedures for finding and selecting customers during hire creation.

| File | Purpose |
|------|---------|
| `sp_get_customers_for_selection.sql` | Get customer list with search and filtering |
| `sp_get_customer_contacts.sql` | Get contacts for selected customer |
| `sp_get_customer_sites.sql` | Get delivery sites for customer |

#### `/equipment_selection_procedures/` - Equipment Booking (Phase 1)
Procedures for selecting equipment types and calculating accessories.

| File | Purpose |
|------|---------|
| `sp_get_available_equipment_types.sql` | Get equipment types available for booking |
| `sp_get_available_individual_equipment.sql` | Get specific equipment units |
| `sp_get_equipment_accessories.sql` | Get accessories for equipment types |
| `sp_calculate_auto_accessories.sql` | **Calculate default accessories** for equipment selection |

#### `/hire_validation_procedures/` - Validation & Business Rules
Procedures that validate hire requests before creation.

| File | Purpose |
|------|---------|
| `sp_validate_customer_credit.sql` | Check customer credit limits |
| `sp_check_equipment_availability.sql` | Verify equipment is available for dates |
| `sp_validate_hire_request.sql` | **Master validation** - validates complete hire request |

#### `/hire_creation_procedures/` - Hire Creation
Procedures that create hire interactions and associated records.

| File | Purpose |
|------|---------|
| `sp_create_hire_interaction.sql` | **Main hire creation** - creates interaction, bookings, accessories, and driver tasks |

#### `/hire_display_procedures/` - Hire Information Display
Procedures for displaying hire details to users.

| File | Purpose |
|------|---------|
| `sp_get_hire_interaction_details.sql` | Get complete hire details |
| `sp_get_hire_equipment_list.sql` | Get equipment list with booking/allocation status |
| `sp_get_hire_accessories_list.sql` | Get accessories list with context |

#### `/equipment_allocation_procedures/` - Equipment Allocation (Phase 2)
Procedures for allocating specific equipment units to bookings.

| File | Purpose |
|------|---------|
| `sp_get_bookings_for_allocation.sql` | Get generic bookings ready for allocation |
| `sp_get_equipment_for_allocation.sql` | Get available equipment units |
| `sp_allocate_specific_equipment.sql` | **Allocate specific units** to bookings |
| `sp_get_allocation_status.sql` | Track allocation progress |

#### `/quality_control_procedures/` - Quality Control
Procedures for equipment quality control and sign-off.

| File | Purpose |
|------|---------|
| `sp_get_equipment_pending_qc.sql` | Get equipment pending quality control |
| `sp_quality_control_signoff.sql` | **QC approval process** |
| `sp_get_qc_summary.sql` | QC statistics and reporting |

#### `/driver_task_management/` - Driver Tasks
Procedures for managing driver delivery/collection tasks.

| File | Purpose |
|------|---------|
| `sp_get_driver_tasks.sql` | Get tasks for driver taskboard |
| `sp_update_driver_task_status.sql` | Update task progress |
| `sp_get_driver_task_equipment.sql` | Get equipment list for driver tasks |

#### `/extras/` - Additional Utilities
Extra procedures for pricing, reporting, and system utilities.

| File | Purpose |
|------|---------|
| `sp_calculate_hire_pricing.sql` | **Pricing calculations** (placeholder for pricing module) |
| `sp_get_hire_list.sql` | Get paginated hire list with filters |
| `sp_get_interaction_activity_log.sql` | Activity logging and audit trail |
| `sp_get_interactions_by_date.sql` | Date-based interaction reporting |

#### `/sample/` - Test Data Creation
Procedures for creating test data.

| File | Purpose |
|------|---------|
| `sp_create_sample_hire.sql` | **Create complete sample hire** for testing |

#### `/utility/` - System Utilities
Core system utility procedures.

| File | Purpose |
|------|---------|
| `sp_get_hire_dashboard_summary.sql` | Dashboard summary statistics |
| `sp_generate_reference_number.sql` | **Generate unique reference numbers** |

#### Root Procedure Files

| File | Purpose |
|------|---------|
| `build_all_procedures.sql` | **Master installation script** - installs all procedures and views |
| `permissions.sql` | Database permissions and security settings |

### `/views/` - Database Views
Pre-built views that simplify working with complex relationships.

#### `/core/` - Core Business Views
Views that make the equipment-accessories relationship easier to work with.

| File | Purpose |
|------|---------|
| `v_equipment_default_accessories.sql` | **Default accessories per equipment type** |
| `v_equipment_all_accessories.sql` | All equipment-accessory relationships |
| `v_accessories_with_equipment.sql` | **Accessories with equipment context** |
| `v_equipment_auto_accessories_summary.sql` | Auto-accessories summary per equipment |
| `v_hire_accessories_detailed.sql` | **Hire accessories with enhanced context** |

### `/Test Queries/` - Development & Testing
SQL queries for testing and development.

| File | Purpose |
|------|---------|
| `hire_interaction.sql` | Test queries for hire interaction functionality |

---

## 🚀 Quick Start

### 1. **Database Setup**
```bash
# Run the main setup script
./ZZ database install.bat
```

### 2. **Manual Setup Steps**
```sql
-- 1. Create database schema
\i database/build/tables.sql

-- 2. Load sample data
\i database/build/sample_data.sql

-- 3. Install all procedures and views
\i database/procedures/build_all_procedures.sql
```

### 3. **Test Installation**
```sql
-- Test basic functionality
SELECT sp_generate_reference_number('hire');
SELECT COUNT(*) FROM sp_get_customers_for_selection();
SELECT * FROM sp_create_sample_hire();
```

---

## 🏗️ Database Schema Overview

### Core Schemas
- **`core`** - Master data (customers, equipment, accessories, employees)
- **`interactions`** - Business transactions (hires, bookings, allocations)
- **`tasks`** - Task management (driver tasks, user tasks)
- **`system`** - System configuration and logging

### Key Tables
- **`core.customers`** - Customer master data
- **`core.equipment_types`** - Equipment type definitions
- **`core.equipment`** - Individual equipment units
- **`core.accessories`** - Universal accessories
- **`core.equipment_accessories`** - Equipment-accessory relationships
- **`interactions.interactions`** - Main business interactions
- **`interactions.interaction_equipment_types`** - Phase 1: Generic equipment bookings
- **`interactions.interaction_equipment`** - Phase 2: Specific equipment allocations
- **`interactions.interaction_accessories`** - Accessory assignments
- **`tasks.drivers_taskboard`** - Driver delivery/collection tasks

---

## 🔄 Business Process Flow

### 1. **Hire Creation Process**
1. Customer selection (`customer_selection_procedures/`)
2. Equipment selection (`equipment_selection_procedures/`)
3. Validation (`hire_validation_procedures/`)
4. Hire creation (`hire_creation_procedures/`)

### 2. **Equipment Allocation Process**
1. View bookings (`equipment_allocation_procedures/`)
2. Allocate specific units (`equipment_allocation_procedures/`)
3. Quality control (`quality_control_procedures/`)
4. Driver tasks (`driver_task_management/`)

### 3. **Monitoring & Reporting**
1. Hire display (`hire_display_procedures/`)
2. Dashboard summaries (`utility/`)
3. Activity logging (`extras/`)

---

## 📚 Key Concepts

### **Two-Phase Equipment Management**
- **Phase 1**: Generic booking (reserve "2x Rammer")
- **Phase 2**: Specific allocation (assign units "R1001, R1002")

### **Universal Accessories**
- Accessories are shared across equipment types
- Flexible quantities per equipment type
- Automatic calculation of default accessories

### **Task-Driven Workflow**
- Driver tasks created automatically
- Quality control integration
- Progress tracking throughout hire lifecycle

---

## 🛠️ Development Guidelines

### **Adding New Procedures**
1. Create in appropriate subfolder
2. Follow naming convention (`sp_action_object`)
3. Add to `build_all_procedures.sql`
4. Include proper error handling
5. Add comments and documentation

### **Modifying Existing Procedures**
1. Update procedure file
2. Test with sample data
3. Update Python services if needed
4. Update API documentation

### **Database Changes**
1. Modify `tables.sql` for schema changes
2. Update `sample_data.sql` for test data
3. Update affected procedures
4. Create migration scripts if needed