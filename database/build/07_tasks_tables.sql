-- =============================================================================
-- STEP 07: TASK MANAGEMENT TABLES
-- =============================================================================
-- Purpose: Create task management tables (Layer 3)
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run SEVENTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- USER TASKBOARD TABLE (Layer 3)
-- =============================================================================
CREATE TABLE tasks.user_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    parent_task_id INTEGER,
    assigned_to INTEGER NOT NULL,
    task_type VARCHAR(50) NOT NULL CHECK (task_type IN 
        ('send_price_list', 'send_quote', 'send_statement', 'process_refund', 'process_application', 
         'follow_up', 'verification', 'approval', 'documentation', 'misc_admin')),
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN 
        ('pending', 'in_progress', 'waiting_approval', 'completed', 'cancelled', 'on_hold')),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date DATE,
    estimated_hours DECIMAL(5,2),
    actual_hours DECIMAL(5,2),
    completion_notes TEXT,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_task_id) REFERENCES tasks.user_taskboard(id),
    FOREIGN KEY (assigned_to) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.user_taskboard IS 'Layer 3: User tasks for office staff (hire controllers, accounts team)';

-- =============================================================================
-- DRIVERS TASKBOARD TABLE (Layer 3)
-- =============================================================================
CREATE TABLE tasks.drivers_taskboard (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER NOT NULL,
    assigned_to INTEGER,
    task_type VARCHAR(50) NOT NULL CHECK (task_type IN 
        ('delivery', 'collection', 'swap', 'repair', 'coring', 'misc_driver_task')),
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status VARCHAR(50) NOT NULL DEFAULT 'backlog' CHECK (status IN 
        ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4', 'completed', 'cancelled')),
    customer_name VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    contact_phone VARCHAR(20),
    contact_whatsapp VARCHAR(20),
    site_address TEXT,
    site_delivery_instructions TEXT,
    equipment_summary TEXT,
    equipment_verified BOOLEAN NOT NULL DEFAULT false,
    scheduled_date DATE,
    scheduled_time TIME,
    estimated_duration INTEGER DEFAULT 90, -- minutes
    -- Progress tracking
    status_booked VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_booked IN ('yes', 'no')),
    status_driver VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_driver IN ('yes', 'no')),
    status_quality_control VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_quality_control IN ('yes', 'no')),
    status_whatsapp VARCHAR(10) NOT NULL DEFAULT 'no' CHECK (status_whatsapp IN ('yes', 'no')),
    -- Completion tracking
    completed_at TIMESTAMP WITH TIME ZONE,
    completion_notes TEXT,
    created_by INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interaction_id) REFERENCES interactions.interactions(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES core.employees(id),
    FOREIGN KEY (created_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.drivers_taskboard IS 'Layer 3: Driver tasks for equipment delivery, collection, repairs';

-- =============================================================================
-- DRIVERS TASK EQUIPMENT TABLE
-- =============================================================================
CREATE TABLE tasks.drivers_task_equipment (
    id SERIAL PRIMARY KEY,
    drivers_task_id INTEGER NOT NULL,
    equipment_category_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    purpose VARCHAR(50) NOT NULL CHECK (purpose IN ('deliver', 'collect', 'swap_out', 'swap_in', 'repair')),
    condition_notes TEXT,
    verified BOOLEAN NOT NULL DEFAULT false,
    verified_by INTEGER,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (drivers_task_id) REFERENCES tasks.drivers_taskboard(id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_category_id) REFERENCES core.equipment_categories(id),
    FOREIGN KEY (verified_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.drivers_task_equipment IS 'Equipment items assigned to driver tasks with verification';

-- =============================================================================
-- TASK ASSIGNMENT HISTORY TABLE
-- =============================================================================
CREATE TABLE tasks.task_assignment_history (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    task_type VARCHAR(20) NOT NULL CHECK (task_type IN ('user_task', 'driver_task')),
    assigned_from INTEGER,
    assigned_to INTEGER NOT NULL,
    assigned_by INTEGER NOT NULL,
    assignment_reason TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unassigned_at TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (assigned_from) REFERENCES core.employees(id),
    FOREIGN KEY (assigned_to) REFERENCES core.employees(id),
    FOREIGN KEY (assigned_by) REFERENCES core.employees(id)
);

COMMENT ON TABLE tasks.task_assignment_history IS 'Track task assignment changes for audit and workload analysis';

-- =============================================================================
-- TRIGGERS FOR UPDATED_AT
-- =============================================================================

CREATE TRIGGER user_taskboard_updated_at 
    BEFORE UPDATE ON tasks.user_taskboard
    FOR EACH ROW EXECUTE FUNCTION interactions.update_timestamp();

CREATE TRIGGER drivers_taskboard_updated_at 
    BEFORE UPDATE ON tasks.drivers_taskboard
    FOR EACH ROW EXECUTE FUNCTION interactions.update_timestamp();

-- =============================================================================
-- NEXT STEP: Run 08_system_tables.sql
-- =============================================================================