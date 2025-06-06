-- =============================================================================
-- STEP 09: DATABASE INDEXES
-- =============================================================================
-- Purpose: Create indexes for performance optimization
-- Run as: SYSTEM user
-- Database: task_management (PostgreSQL)
-- Order: Must be run NINTH
-- =============================================================================

SET search_path TO core, interactions, tasks, security, system, public;

-- =============================================================================
-- CORE SCHEMA INDEXES
-- =============================================================================

-- Employees indexes
CREATE INDEX idx_employees_role ON core.employees(role) WHERE status = 'active';
CREATE INDEX idx_employees_status ON core.employees(status);
CREATE INDEX idx_employees_email ON core.employees(email) WHERE status = 'active';
CREATE INDEX idx_employees_code ON core.employees(employee_code) WHERE status = 'active';

-- Customers indexes
CREATE INDEX idx_customers_name ON core.customers USING gin(to_tsvector('english', customer_name));
CREATE INDEX idx_customers_code ON core.customers(customer_code) WHERE status = 'active';
CREATE INDEX idx_customers_status ON core.customers(status);
CREATE INDEX idx_customers_company ON core.customers(is_company, status);
CREATE INDEX idx_customers_created_by ON core.customers(created_by);

-- Contacts indexes
CREATE INDEX idx_contacts_customer ON core.contacts(customer_id) WHERE status = 'active';
CREATE INDEX idx_contacts_primary ON core.contacts(customer_id, is_primary_contact) WHERE status = 'active';
CREATE INDEX idx_contacts_billing ON core.contacts(customer_id, is_billing_contact) WHERE status = 'active';
CREATE INDEX idx_contacts_name ON core.contacts USING gin(to_tsvector('english', first_name || ' ' || last_name));
CREATE INDEX idx_contacts_email ON core.contacts(email) WHERE status = 'active';
CREATE INDEX idx_contacts_phone ON core.contacts(phone_number) WHERE status = 'active';

-- Sites indexes
CREATE INDEX idx_sites_customer ON core.sites(customer_id) WHERE is_active = true;
CREATE INDEX idx_sites_type ON core.sites(customer_id, site_type) WHERE is_active = true;
CREATE INDEX idx_sites_address ON core.sites USING gin(to_tsvector('english', address_line1 || ' ' || city));

-- Equipment categories indexes
CREATE INDEX idx_equipment_categories_code ON core.equipment_categories(category_code) WHERE is_active = true;
CREATE INDEX idx_equipment_categories_name ON core.equipment_categories USING gin(to_tsvector('english', category_name));
CREATE INDEX idx_equipment_categories_active ON core.equipment_categories(is_active);

-- Equipment pricing indexes
CREATE INDEX idx_equipment_pricing_category ON core.equipment_pricing(equipment_category_id, customer_type) WHERE is_active = true;
CREATE INDEX idx_equipment_pricing_effective ON core.equipment_pricing(effective_from, effective_until) WHERE is_active = true;

-- =============================================================================
-- SECURITY SCHEMA INDEXES
-- =============================================================================

-- Employee authentication indexes
CREATE UNIQUE INDEX idx_employee_auth_username ON security.employee_auth(username);
CREATE INDEX idx_employee_auth_token ON security.employee_auth(session_token) WHERE session_token IS NOT NULL;
CREATE INDEX idx_employee_auth_locked ON security.employee_auth(locked_until) WHERE locked_until IS NOT NULL;

-- Audit log indexes
CREATE INDEX idx_audit_log_employee ON security.audit_log(employee_id, created_at);
CREATE INDEX idx_audit_log_table ON security.audit_log(table_name, action, created_at);
CREATE INDEX idx_audit_log_date ON security.audit_log(created_at);

-- Login attempts indexes
CREATE INDEX idx_login_attempts_username ON security.login_attempts(username, created_at);
CREATE INDEX idx_login_attempts_ip ON security.login_attempts(ip_address, created_at);
CREATE INDEX idx_login_attempts_date ON security.login_attempts(created_at);

-- Role permissions indexes
CREATE INDEX idx_role_permissions_role ON security.role_permissions(role, permission, resource) WHERE is_active = true;

-- =============================================================================
-- INTERACTIONS SCHEMA INDEXES
-- =============================================================================

-- Interactions indexes
CREATE INDEX idx_interactions_customer ON interactions.interactions(customer_id, created_at);
CREATE INDEX idx_interactions_employee ON interactions.interactions(employee_id, created_at);
CREATE INDEX idx_interactions_type ON interactions.interactions(interaction_type, status, created_at);
CREATE INDEX idx_interactions_status ON interactions.interactions(status, created_at);
CREATE UNIQUE INDEX idx_interactions_reference ON interactions.interactions(reference_number);
CREATE INDEX idx_interactions_date ON interactions.interactions(created_at);

-- Component tables indexes
CREATE INDEX idx_component_equipment_interaction ON interactions.component_equipment_list(interaction_id);
CREATE INDEX idx_component_equipment_category ON interactions.component_equipment_list(equipment_category_id);

CREATE INDEX idx_component_hire_interaction ON interactions.component_hire_details(interaction_id);
CREATE INDEX idx_component_hire_site ON interactions.component_hire_details(site_id);
CREATE INDEX idx_component_hire_date ON interactions.component_hire_details(deliver_date);

CREATE INDEX idx_component_offhire_interaction ON interactions.component_offhire_details(interaction_id);
CREATE INDEX idx_component_offhire_site ON interactions.component_offhire_details(site_id);
CREATE INDEX idx_component_offhire_date ON interactions.component_offhire_details(collect_date);

CREATE INDEX idx_component_breakdown_interaction ON interactions.component_breakdown_details(interaction_id);
CREATE INDEX idx_component_breakdown_site ON interactions.component_breakdown_details(site_id);
CREATE INDEX idx_component_breakdown_urgency ON interactions.component_breakdown_details(urgency_level, breakdown_date);

CREATE INDEX idx_component_application_interaction ON interactions.component_application_details(interaction_id);
CREATE INDEX idx_component_application_status ON interactions.component_application_details(verification_status, created_at);
CREATE INDEX idx_component_application_email ON interactions.component_application_details(applicant_email);

CREATE INDEX idx_component_quote_interaction ON interactions.component_quote_totals(interaction_id);
CREATE INDEX idx_component_quote_valid ON interactions.component_quote_totals(valid_until);

CREATE INDEX idx_component_refund_interaction ON interactions.component_refund_details(interaction_id);
CREATE INDEX idx_component_refund_processed ON interactions.component_refund_details(processed_by, processed_date);

-- =============================================================================
-- TASKS SCHEMA INDEXES
-- =============================================================================

-- User taskboard indexes
CREATE INDEX idx_user_taskboard_interaction ON tasks.user_taskboard(interaction_id);
CREATE INDEX idx_user_taskboard_assigned ON tasks.user_taskboard(assigned_to, status, due_date);
CREATE INDEX idx_user_taskboard_status ON tasks.user_taskboard(status, priority, created_at);
CREATE INDEX idx_user_taskboard_due ON tasks.user_taskboard(due_date) WHERE status NOT IN ('completed', 'cancelled');
CREATE INDEX idx_user_taskboard_parent ON tasks.user_taskboard(parent_task_id) WHERE parent_task_id IS NOT NULL;
CREATE INDEX idx_user_taskboard_type ON tasks.user_taskboard(task_type, status);

-- Drivers taskboard indexes
CREATE INDEX idx_drivers_taskboard_interaction ON tasks.drivers_taskboard(interaction_id);
CREATE INDEX idx_drivers_taskboard_assigned ON tasks.drivers_taskboard(assigned_to, status, scheduled_date);
CREATE INDEX idx_drivers_taskboard_status ON tasks.drivers_taskboard(status, priority, created_at);
CREATE INDEX idx_drivers_taskboard_scheduled ON tasks.drivers_taskboard(scheduled_date, scheduled_time) WHERE status NOT IN ('completed', 'cancelled');
CREATE INDEX idx_drivers_taskboard_customer ON tasks.drivers_taskboard USING gin(to_tsvector('english', customer_name));
CREATE INDEX idx_drivers_taskboard_type ON tasks.drivers_taskboard(task_type, status);
CREATE INDEX idx_drivers_taskboard_created ON tasks.drivers_taskboard(created_by, created_at);

-- Drivers task equipment indexes
CREATE INDEX idx_drivers_task_equipment_task ON tasks.drivers_task_equipment(drivers_task_id);
CREATE INDEX idx_drivers_task_equipment_category ON tasks.drivers_task_equipment(equipment_category_id);
CREATE INDEX idx_drivers_task_equipment_verified ON tasks.drivers_task_equipment(verified, verified_by);

-- Task assignment history indexes
CREATE INDEX idx_task_assignment_history_task ON tasks.task_assignment_history(task_id, task_type);
CREATE INDEX idx_task_assignment_history_assigned ON tasks.task_assignment_history(assigned_to, assigned_at);
CREATE INDEX idx_task_assignment_history_date ON tasks.task_assignment_history(assigned_at);

-- =============================================================================
-- SYSTEM SCHEMA INDEXES
-- =============================================================================

-- Reference sequences indexes
CREATE UNIQUE INDEX idx_reference_sequences_prefix_date ON system.reference_sequences(prefix, date_part);
CREATE INDEX idx_reference_sequences_date ON system.reference_sequences(date_part, updated_at);

-- System configuration indexes
CREATE UNIQUE INDEX idx_system_config_key ON system.system_config(config_key) WHERE is_active = true;
CREATE INDEX idx_system_config_type ON system.system_config(config_type) WHERE is_active = true;

-- =============================================================================
-- COMPOSITE INDEXES FOR COMPLEX QUERIES
-- =============================================================================

-- Customer interaction analysis
CREATE INDEX idx_customer_interactions_analysis ON interactions.interactions(customer_id, interaction_type, status, created_at);

-- Employee workload analysis
CREATE INDEX idx_employee_workload_user ON tasks.user_taskboard(assigned_to, status, priority, due_date);
CREATE INDEX idx_employee_workload_driver ON tasks.drivers_taskboard(assigned_to, status, priority, scheduled_date);

-- Equipment utilization analysis
CREATE INDEX idx_equipment_utilization ON interactions.component_equipment_list(equipment_category_id, interaction_id);

-- Task performance analysis
CREATE INDEX idx_task_performance_user ON tasks.user_taskboard(status, created_at, completed_at) WHERE completed_at IS NOT NULL;
CREATE INDEX idx_task_performance_driver ON tasks.drivers_taskboard(status, created_at, completed_at) WHERE completed_at IS NOT NULL;

-- Customer service analysis
CREATE INDEX idx_customer_service_response ON interactions.interactions(customer_id, created_at, interaction_type, status);

-- =============================================================================
-- PARTIAL INDEXES FOR ACTIVE RECORDS
-- =============================================================================

-- Active tasks only
CREATE INDEX idx_active_user_tasks ON tasks.user_taskboard(assigned_to, priority, due_date) 
    WHERE status IN ('pending', 'in_progress');

CREATE INDEX idx_active_driver_tasks ON tasks.drivers_taskboard(assigned_to, priority, scheduled_date) 
    WHERE status NOT IN ('completed', 'cancelled');

-- Pending interactions
CREATE INDEX idx_pending_interactions ON interactions.interactions(customer_id, employee_id, created_at) 
    WHERE status = 'pending';

-- Overdue tasks
CREATE INDEX idx_user_tasks_active 
    ON tasks.user_taskboard(assigned_to, due_date, priority)
    WHERE status NOT IN ('completed', 'cancelled');

CREATE INDEX idx_driver_tasks_active 
    ON tasks.drivers_taskboard(assigned_to, scheduled_date, priority)
    WHERE status NOT IN ('completed', 'cancelled');

--In Queries, apply date filter dynamically
--SELECT * FROM tasks.user_taskboard
--WHERE status NOT IN ('completed', 'cancelled')
--AND due_date < CURRENT_DATE
--AND assigned_to = 123;


-- =============================================================================
-- NEXT STEP: Run 10_permissions.sql
-- =============================================================================