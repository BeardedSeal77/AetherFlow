// =============================================================================
// DATABASE INDEXES FOR PERFORMANCE
// =============================================================================

// Customer lookup indexes
CREATE INDEX idx_individuals_contact ON individual_customers(contact_number, whatsapp_number);
CREATE INDEX idx_individuals_email ON individual_customers(email);
CREATE INDEX idx_individuals_name ON individual_customers(customer_name, customer_surname);

CREATE INDEX idx_companies_name ON companies(company_name);
CREATE INDEX idx_companies_status ON companies(status);

CREATE INDEX idx_company_contacts_company ON company_contacts(company_id);
CREATE INDEX idx_company_contacts_primary ON company_contacts(company_id, is_primary_contact);
CREATE INDEX idx_company_contacts_email ON company_contacts(email);

// Employee indexes
CREATE INDEX idx_employees_role ON employees(role, status);
CREATE INDEX idx_employees_username ON employees(username);

// Equipment indexes
CREATE INDEX idx_equipment_categories_code ON equipment_categories(category_code);
CREATE INDEX idx_equipment_categories_active ON equipment_categories(is_active);
CREATE INDEX idx_equipment_categories_name ON equipment_categories(category_name);

// Interaction indexes
CREATE INDEX idx_interactions_individual ON interactions(individual_customer_id, created_at);
CREATE INDEX idx_interactions_company ON interactions(company_id, created_at);
CREATE INDEX idx_interactions_contact ON interactions(company_contact_id, created_at);
CREATE INDEX idx_interactions_type_status ON interactions(interaction_type, status);
CREATE INDEX idx_interactions_employee ON interactions(employee_id, created_at);
CREATE INDEX idx_interactions_reference ON interactions(reference_number);

// Component table indexes
CREATE INDEX idx_component_equipment_interaction ON component_equipment_list(interaction_id);
CREATE INDEX idx_component_equipment_category ON component_equipment_list(equipment_category_id);

CREATE INDEX idx_component_application_interaction ON component_application_details(interaction_id);

CREATE INDEX idx_component_hire_interaction ON component_hire_date_details(interaction_id);
CREATE INDEX idx_component_hire_dates ON component_hire_date_details(deliver_date, start_date);

CREATE INDEX idx_component_offhire_interaction ON component_off_hire_date_details(interaction_id);
CREATE INDEX idx_component_offhire_dates ON component_off_hire_date_details(collect_date, end_date);

CREATE INDEX idx_component_breakdown_interaction ON component_breakdown_date_details(interaction_id);
CREATE INDEX idx_component_breakdown_dates ON component_breakdown_date_details(breakdown_date);

// Taskboard indexes
CREATE INDEX idx_user_taskboard_assigned ON user_taskboard(assigned_to, status);
CREATE INDEX idx_user_taskboard_due ON user_taskboard(due_date, priority);
CREATE INDEX idx_user_taskboard_type ON user_taskboard(task_type, status);

CREATE INDEX idx_drivers_taskboard_assigned ON drivers_taskboard(assigned_to, scheduled_date);
CREATE INDEX idx_drivers_taskboard_status ON drivers_taskboard(status, priority);
CREATE INDEX idx_drivers_taskboard_date ON drivers_taskboard(scheduled_date, scheduled_time);
CREATE INDEX idx_drivers_taskboard_type ON drivers_taskboard(task_type, status);

CREATE INDEX idx_drivers_task_equipment_task ON drivers_task_equipment(drivers_task_id);
CREATE INDEX idx_drivers_task_equipment_category ON drivers_task_equipment(equipment_category_id);

// Audit and system indexes
CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_user_date ON audit_log(changed_by, created_at);

CREATE INDEX idx_attachments_related ON attachments(related_table, related_id);
CREATE INDEX idx_attachments_uploaded_by ON attachments(uploaded_by);

CREATE INDEX idx_system_settings_key ON system_settings(setting_key);