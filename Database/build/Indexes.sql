-- =============================================================================
-- FIXED COMPREHENSIVE INDEX STRATEGY FOR TASK MANAGEMENT SYSTEM
-- =============================================================================

-- =============================================================================
-- PREREQUISITE: ENABLE REQUIRED EXTENSIONS
-- =============================================================================

-- Enable trigram extension for fuzzy text search (run as superuser)
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- FOUNDATION TABLES INDEXES
-- =============================================================================

-- CUSTOMERS TABLE INDEXES
CREATE INDEX idx_customers_name ON customers(customer_name);
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_is_company ON customers(is_company);
CREATE INDEX idx_customers_created_at ON customers(created_at);
CREATE INDEX idx_customers_status_company ON customers(status, is_company);
-- Fuzzy text search index (requires pg_trgm extension)
-- CREATE INDEX idx_customers_name_trgm ON customers USING gin(customer_name gin_trgm_ops);

-- CONTACTS TABLE INDEXES
CREATE INDEX idx_contacts_customer_id ON contacts(customer_id);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_phone ON contacts(phone_number);
CREATE INDEX idx_contacts_whatsapp ON contacts(whatsapp_number);
CREATE INDEX idx_contacts_status ON contacts(status);
CREATE INDEX idx_contacts_primary ON contacts(is_primary_contact) WHERE is_primary_contact = true;
CREATE INDEX idx_contacts_billing ON contacts(is_billing_contact) WHERE is_billing_contact = true;
CREATE INDEX idx_contacts_customer_status ON contacts(customer_id, status);
-- Full name search index (requires pg_trgm extension)
-- CREATE INDEX idx_contacts_name_search ON contacts USING gin((first_name || ' ' || last_name) gin_trgm_ops);

-- SITES TABLE INDEXES
CREATE INDEX idx_sites_customer_id ON sites(customer_id);
CREATE INDEX idx_sites_active ON sites(is_active);
CREATE INDEX idx_sites_type ON sites(site_type);
CREATE INDEX idx_sites_city ON sites(city);
CREATE INDEX idx_sites_postal_code ON sites(postal_code);
CREATE INDEX idx_sites_customer_active ON sites(customer_id, is_active);
-- Address search index (requires pg_trgm extension)
-- CREATE INDEX idx_sites_address_search ON sites USING gin((address_line1 || ' ' || COALESCE(address_line2, '') || ' ' || city) gin_trgm_ops);

-- EMPLOYEES TABLE INDEXES
CREATE INDEX idx_employees_username ON employees(username);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_role ON employees(role);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_last_login ON employees(last_login);
CREATE INDEX idx_employees_role_status ON employees(role, status);
-- Employee name search index (requires pg_trgm extension)
-- CREATE INDEX idx_employees_name_search ON employees USING gin((name || ' ' || surname) gin_trgm_ops);

-- EQUIPMENT CATEGORIES TABLE INDEXES
CREATE INDEX idx_equipment_categories_code ON equipment_categories(category_code);
CREATE INDEX idx_equipment_categories_name ON equipment_categories(category_name);
CREATE INDEX idx_equipment_categories_active ON equipment_categories(is_active);
-- Category name search index (requires pg_trgm extension)
-- CREATE INDEX idx_equipment_categories_name_search ON equipment_categories USING gin(category_name gin_trgm_ops);

-- EQUIPMENT PRICING TABLE INDEXES
CREATE INDEX idx_equipment_pricing_category_id ON equipment_pricing(equipment_category_id);
CREATE INDEX idx_equipment_pricing_customer_type ON equipment_pricing(customer_type);
CREATE INDEX idx_equipment_pricing_effective_dates ON equipment_pricing(effective_from, effective_to);
CREATE INDEX idx_equipment_pricing_active ON equipment_pricing(is_active);
CREATE INDEX idx_equipment_pricing_category_customer_active ON equipment_pricing(equipment_category_id, customer_type, is_active);
-- Removed problematic date comparison - use regular index and filter in queries
CREATE INDEX idx_equipment_pricing_current ON equipment_pricing(equipment_category_id, customer_type, is_active, effective_from, effective_to);

-- PRICE LIST TEMPLATES TABLE INDEXES
CREATE INDEX idx_price_list_templates_active ON price_list_templates(is_active);
CREATE INDEX idx_price_list_templates_customer_type ON price_list_templates(customer_type);

-- =============================================================================
-- LAYER 1: INTERACTION RECORDING INDEXES
-- =============================================================================

-- INTERACTIONS TABLE INDEXES
CREATE INDEX idx_interactions_customer_id ON interactions(customer_id);
CREATE INDEX idx_interactions_contact_id ON interactions(contact_id);
CREATE INDEX idx_interactions_employee_id ON interactions(employee_id);
CREATE INDEX idx_interactions_type ON interactions(interaction_type);
CREATE INDEX idx_interactions_status ON interactions(status);
CREATE INDEX idx_interactions_created_at ON interactions(created_at);
CREATE INDEX idx_interactions_updated_at ON interactions(updated_at);
CREATE INDEX idx_interactions_reference_number ON interactions(reference_number);
CREATE INDEX idx_interactions_contact_method ON interactions(contact_method);

-- Composite indexes for common query patterns
CREATE INDEX idx_interactions_customer_type_status ON interactions(customer_id, interaction_type, status);
CREATE INDEX idx_interactions_employee_status_created ON interactions(employee_id, status, created_at);
CREATE INDEX idx_interactions_type_created ON interactions(interaction_type, created_at);
CREATE INDEX idx_interactions_status_updated ON interactions(status, updated_at);
CREATE INDEX idx_interactions_recent_by_customer ON interactions(customer_id, created_at DESC);

-- =============================================================================
-- LAYER 2: COMPONENT STORAGE INDEXES
-- =============================================================================

-- APPLICATION DETAILS COMPONENT INDEXES
CREATE INDEX idx_component_application_details_interaction_id ON component_application_details(interaction_id);
CREATE INDEX idx_component_application_details_verification_status ON component_application_details(verification_status);
CREATE INDEX idx_component_application_details_verification_date ON component_application_details(verification_date);

-- EQUIPMENT LIST COMPONENT INDEXES
CREATE INDEX idx_component_equipment_list_interaction_id ON component_equipment_list(interaction_id);
CREATE INDEX idx_component_equipment_list_equipment_category_id ON component_equipment_list(equipment_category_id);
CREATE INDEX idx_component_equipment_list_hire_period ON component_equipment_list(hire_duration, hire_period_type);

-- QUOTE TOTALS COMPONENT INDEXES
CREATE INDEX idx_component_quote_totals_interaction_id ON component_quote_totals(interaction_id);
CREATE INDEX idx_component_quote_totals_valid_until ON component_quote_totals(valid_until);
CREATE INDEX idx_component_quote_totals_created_at ON component_quote_totals(created_at);

-- REFUND DETAILS COMPONENT INDEXES
CREATE INDEX idx_component_refund_details_interaction_id ON component_refund_details(interaction_id);
CREATE INDEX idx_component_refund_details_processed_by ON component_refund_details(processed_by);
CREATE INDEX idx_component_refund_details_processed_at ON component_refund_details(processed_at);
CREATE INDEX idx_component_refund_details_refund_type ON component_refund_details(refund_type);

-- HIRE DETAILS COMPONENT INDEXES
CREATE INDEX idx_component_hire_details_interaction_id ON component_hire_details(interaction_id);
CREATE INDEX idx_component_hire_details_site_id ON component_hire_details(site_id);
CREATE INDEX idx_component_hire_details_deliver_date ON component_hire_details(deliver_date);
CREATE INDEX idx_component_hire_details_start_date ON component_hire_details(start_date);
CREATE INDEX idx_component_hire_details_delivery_method ON component_hire_details(delivery_method);

-- OFF-HIRE DETAILS COMPONENT INDEXES
CREATE INDEX idx_component_offhire_details_interaction_id ON component_offhire_details(interaction_id);
CREATE INDEX idx_component_offhire_details_site_id ON component_offhire_details(site_id);
CREATE INDEX idx_component_offhire_details_collect_date ON component_offhire_details(collect_date);
CREATE INDEX idx_component_offhire_details_end_date ON component_offhire_details(end_date);
CREATE INDEX idx_component_offhire_details_collection_method ON component_offhire_details(collection_method);

-- BREAKDOWN DETAILS COMPONENT INDEXES
CREATE INDEX idx_component_breakdown_details_interaction_id ON component_breakdown_details(interaction_id);
CREATE INDEX idx_component_breakdown_details_site_id ON component_breakdown_details(site_id);
CREATE INDEX idx_component_breakdown_details_breakdown_date ON component_breakdown_details(breakdown_date);
CREATE INDEX idx_component_breakdown_details_urgency ON component_breakdown_details(urgency);
CREATE INDEX idx_component_breakdown_details_resolution_type ON component_breakdown_details(resolution_type);

-- CORING DETAILS COMPONENT INDEXES
CREATE INDEX idx_component_coring_details_interaction_id ON component_coring_details(interaction_id);
CREATE INDEX idx_component_coring_details_site_id ON component_coring_details(site_id);
CREATE INDEX idx_component_coring_details_coring_date ON component_coring_details(coring_date);
CREATE INDEX idx_component_coring_details_urgency ON component_coring_details(urgency);
CREATE INDEX idx_component_coring_details_core_diameter ON component_coring_details(core_diameter);

-- MISC TASK DETAILS COMPONENT INDEXES
CREATE INDEX idx_component_misc_task_details_interaction_id ON component_misc_task_details(interaction_id);
CREATE INDEX idx_component_misc_task_details_site_id ON component_misc_task_details(site_id);
CREATE INDEX idx_component_misc_task_details_task_date ON component_misc_task_details(task_date);
CREATE INDEX idx_component_misc_task_details_urgency ON component_misc_task_details(urgency);
CREATE INDEX idx_component_misc_task_details_task_category ON component_misc_task_details(task_category);

-- RENTAL AGREEMENTS COMPONENT INDEXES
CREATE INDEX idx_component_rental_agreements_interaction_id ON component_rental_agreements(interaction_id);
CREATE INDEX idx_component_rental_agreements_agreement_number ON component_rental_agreements(agreement_number);
CREATE INDEX idx_component_rental_agreements_rental_dates ON component_rental_agreements(rental_start_date, rental_end_date);
CREATE INDEX idx_component_rental_agreements_start_date ON component_rental_agreements(rental_start_date);
CREATE INDEX idx_component_rental_agreements_end_date ON component_rental_agreements(rental_end_date);

-- =============================================================================
-- LAYER 3: TASKBOARD OPERATIONS INDEXES
-- =============================================================================

-- USER TASKBOARD INDEXES
CREATE INDEX idx_user_taskboard_interaction_id ON user_taskboard(interaction_id);
CREATE INDEX idx_user_taskboard_assigned_to ON user_taskboard(assigned_to);
CREATE INDEX idx_user_taskboard_task_type ON user_taskboard(task_type);
CREATE INDEX idx_user_taskboard_priority ON user_taskboard(priority);
CREATE INDEX idx_user_taskboard_status ON user_taskboard(status);
CREATE INDEX idx_user_taskboard_due_date ON user_taskboard(due_date);
CREATE INDEX idx_user_taskboard_parent_task_id ON user_taskboard(parent_task_id);
CREATE INDEX idx_user_taskboard_created_at ON user_taskboard(created_at);
CREATE INDEX idx_user_taskboard_updated_at ON user_taskboard(updated_at);

-- Composite indexes for user taskboard queries
CREATE INDEX idx_user_taskboard_assigned_status ON user_taskboard(assigned_to, status);
CREATE INDEX idx_user_taskboard_assigned_due ON user_taskboard(assigned_to, due_date) WHERE status != 'completed';
CREATE INDEX idx_user_taskboard_status_priority ON user_taskboard(status, priority);
CREATE INDEX idx_user_taskboard_assigned_type_status ON user_taskboard(assigned_to, task_type, status);

-- DRIVERS TASKBOARD INDEXES
CREATE INDEX idx_drivers_taskboard_interaction_id ON drivers_taskboard(interaction_id);
CREATE INDEX idx_drivers_taskboard_assigned_to ON drivers_taskboard(assigned_to);
CREATE INDEX idx_drivers_taskboard_created_by ON drivers_taskboard(created_by);
CREATE INDEX idx_drivers_taskboard_task_type ON drivers_taskboard(task_type);
CREATE INDEX idx_drivers_taskboard_priority ON drivers_taskboard(priority);
CREATE INDEX idx_drivers_taskboard_status ON drivers_taskboard(status);
CREATE INDEX idx_drivers_taskboard_scheduled_date ON drivers_taskboard(scheduled_date);
CREATE INDEX idx_drivers_taskboard_scheduled_time ON drivers_taskboard(scheduled_time);
CREATE INDEX idx_drivers_taskboard_created_at ON drivers_taskboard(created_at);
CREATE INDEX idx_drivers_taskboard_updated_at ON drivers_taskboard(updated_at);

-- Status tracking indexes for drivers taskboard
CREATE INDEX idx_drivers_taskboard_status_booked ON drivers_taskboard(status_booked);
CREATE INDEX idx_drivers_taskboard_status_driver ON drivers_taskboard(status_driver);
CREATE INDEX idx_drivers_taskboard_status_quality_control ON drivers_taskboard(status_quality_control);
CREATE INDEX idx_drivers_taskboard_status_whatsapp ON drivers_taskboard(status_whatsapp);
CREATE INDEX idx_drivers_taskboard_equipment_verified ON drivers_taskboard(equipment_verified);

-- Composite indexes for drivers taskboard common queries
CREATE INDEX idx_drivers_taskboard_assigned_status ON drivers_taskboard(assigned_to, status);
CREATE INDEX idx_drivers_taskboard_status_scheduled ON drivers_taskboard(status, scheduled_date);
CREATE INDEX idx_drivers_taskboard_assigned_scheduled ON drivers_taskboard(assigned_to, scheduled_date);
CREATE INDEX idx_drivers_taskboard_task_type_status ON drivers_taskboard(task_type, status);
CREATE INDEX idx_drivers_taskboard_priority_status ON drivers_taskboard(priority, status);
CREATE INDEX idx_drivers_taskboard_scheduled_date_status ON drivers_taskboard(scheduled_date, status);

-- Multi-column index for complete status tracking
CREATE INDEX idx_drivers_taskboard_all_status ON drivers_taskboard(status_booked, status_driver, status_quality_control, status_whatsapp);

-- Customer and site search indexes (requires pg_trgm extension)
-- CREATE INDEX idx_drivers_taskboard_customer_name ON drivers_taskboard USING gin(customer_name gin_trgm_ops);
-- CREATE INDEX idx_drivers_taskboard_contact_name ON drivers_taskboard USING gin(contact_name gin_trgm_ops);
CREATE INDEX idx_drivers_taskboard_contact_phone ON drivers_taskboard(contact_phone);
CREATE INDEX idx_drivers_taskboard_contact_whatsapp ON drivers_taskboard(contact_whatsapp);

-- DRIVERS TASK EQUIPMENT INDEXES
CREATE INDEX idx_drivers_task_equipment_task_id ON drivers_task_equipment(drivers_task_id);
CREATE INDEX idx_drivers_task_equipment_equipment_category_id ON drivers_task_equipment(equipment_category_id);
CREATE INDEX idx_drivers_task_equipment_purpose ON drivers_task_equipment(purpose);
CREATE INDEX idx_drivers_task_equipment_verified ON drivers_task_equipment(verified);
CREATE INDEX idx_drivers_task_equipment_verified_by ON drivers_task_equipment(verified_by);
CREATE INDEX idx_drivers_task_equipment_verified_at ON drivers_task_equipment(verified_at);

-- Composite indexes for equipment verification queries
CREATE INDEX idx_drivers_task_equipment_task_verified ON drivers_task_equipment(drivers_task_id, verified);
CREATE INDEX idx_drivers_task_equipment_task_purpose ON drivers_task_equipment(drivers_task_id, purpose);

-- DRIVERS TASK STATUS HISTORY INDEXES
CREATE INDEX idx_drivers_task_status_history_task_id ON drivers_task_status_history(drivers_task_id);
CREATE INDEX idx_drivers_task_status_history_changed_by ON drivers_task_status_history(changed_by);
CREATE INDEX idx_drivers_task_status_history_created_at ON drivers_task_status_history(created_at);
CREATE INDEX idx_drivers_task_status_history_from_status ON drivers_task_status_history(from_status);
CREATE INDEX idx_drivers_task_status_history_to_status ON drivers_task_status_history(to_status);

-- DRIVERS ASSIGNMENT HISTORY INDEXES
CREATE INDEX idx_drivers_assignment_history_task_id ON drivers_assignment_history(drivers_task_id);
CREATE INDEX idx_drivers_assignment_history_assigned_to ON drivers_assignment_history(assigned_to);
CREATE INDEX idx_drivers_assignment_history_assigned_by ON drivers_assignment_history(assigned_by);
CREATE INDEX idx_drivers_assignment_history_assigned_at ON drivers_assignment_history(assigned_at);
CREATE INDEX idx_drivers_assignment_history_unassigned_at ON drivers_assignment_history(unassigned_at);

-- =============================================================================
-- SUPPORTING TABLES INDEXES
-- =============================================================================

-- ATTACHMENTS TABLE INDEXES
CREATE INDEX idx_attachments_interaction_id ON attachments(interaction_id);
CREATE INDEX idx_attachments_drivers_task_id ON attachments(drivers_task_id);
CREATE INDEX idx_attachments_uploaded_by ON attachments(uploaded_by);
CREATE INDEX idx_attachments_created_at ON attachments(created_at);
CREATE INDEX idx_attachments_file_type ON attachments(file_type);

-- AUDIT LOG TABLE INDEXES
CREATE INDEX idx_audit_log_table_name ON audit_log(table_name);
CREATE INDEX idx_audit_log_record_id ON audit_log(record_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_changed_by ON audit_log(changed_by);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at);
CREATE INDEX idx_audit_log_ip_address ON audit_log(ip_address);

-- Composite indexes for audit queries
CREATE INDEX idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_table_created ON audit_log(table_name, created_at);
CREATE INDEX idx_audit_log_changed_by_created ON audit_log(changed_by, created_at);

-- SYSTEM SETTINGS TABLE INDEXES
CREATE INDEX idx_system_settings_key ON system_settings(setting_key);
CREATE INDEX idx_system_settings_type ON system_settings(setting_type);
CREATE INDEX idx_system_settings_updated_by ON system_settings(updated_by);
CREATE INDEX idx_system_settings_updated_at ON system_settings(updated_at);

-- =============================================================================
-- SPECIALIZED PERFORMANCE INDEXES
-- =============================================================================

-- Date range queries (commonly used for reports and dashboards)
CREATE INDEX idx_interactions_date_range ON interactions(created_at, interaction_type, status);
CREATE INDEX idx_drivers_taskboard_date_range ON drivers_taskboard(scheduled_date, status, task_type);
CREATE INDEX idx_audit_log_date_range ON audit_log(created_at, table_name);

-- Equipment utilization tracking
CREATE INDEX idx_equipment_utilization ON component_equipment_list(equipment_category_id, hire_duration, hire_period_type);

-- Customer activity tracking
CREATE INDEX idx_customer_activity ON interactions(customer_id, created_at DESC, interaction_type);

-- Driver performance tracking
CREATE INDEX idx_driver_performance ON drivers_taskboard(assigned_to, status, scheduled_date, created_at);

-- Pending tasks dashboard
CREATE INDEX idx_pending_tasks_dashboard ON drivers_taskboard(status, priority, scheduled_date) 
    WHERE status IN ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4');

-- Quality control dashboard
CREATE INDEX idx_quality_control_dashboard ON drivers_taskboard(status_quality_control, equipment_verified, status) 
    WHERE status != 'completed' AND status != 'cancelled';

-- Communication tracking
CREATE INDEX idx_communication_tracking ON drivers_taskboard(status_whatsapp, contact_whatsapp, scheduled_date) 
    WHERE status_whatsapp = 'no' AND contact_whatsapp IS NOT NULL;

-- =============================================================================
-- PARTIAL INDEXES FOR OPTIMIZATION
-- =============================================================================

-- Active records only (common filtering) - Safe partial indexes with static values
CREATE INDEX idx_customers_active_only ON customers(customer_name, created_at) WHERE status = 'active';
CREATE INDEX idx_employees_active_only ON employees(role, name, surname) WHERE status = 'active';
CREATE INDEX idx_equipment_categories_active_only ON equipment_categories(category_name, category_code) WHERE is_active = true;
CREATE INDEX idx_sites_active_only ON sites(customer_id, site_name) WHERE is_active = true;

-- Incomplete tasks only - Safe partial indexes with static values
CREATE INDEX idx_user_taskboard_incomplete ON user_taskboard(assigned_to, priority, due_date) 
    WHERE status IN ('pending', 'in_progress');
CREATE INDEX idx_drivers_taskboard_incomplete ON drivers_taskboard(assigned_to, scheduled_date, priority) 
    WHERE status NOT IN ('completed', 'cancelled');

-- Verified equipment only - Safe partial index with static values
CREATE INDEX idx_drivers_task_equipment_verified_only ON drivers_task_equipment(drivers_task_id, equipment_category_id) 
    WHERE verified = true;

-- REMOVED: All date-based partial indexes that used CURRENT_DATE or INTERVAL functions
-- These caused "functions in index predicate must be marked IMMUTABLE" errors
-- Use regular indexes and filter in application code or queries instead

-- =============================================================================
-- OPTIONAL: ENABLE TEXT SEARCH INDEXES (Run after enabling pg_trgm extension)
-- =============================================================================

/*
-- To enable fuzzy text search, first run as superuser:
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Then uncomment and run these indexes:

-- Customer name fuzzy search
CREATE INDEX idx_customers_name_trgm ON customers USING gin(customer_name gin_trgm_ops);

-- Contact name search
CREATE INDEX idx_contacts_name_search ON contacts USING gin((first_name || ' ' || last_name) gin_trgm_ops);

-- Site address search  
CREATE INDEX idx_sites_address_search ON sites USING gin((address_line1 || ' ' || COALESCE(address_line2, '') || ' ' || city) gin_trgm_ops);

-- Employee name search
CREATE INDEX idx_employees_name_search ON employees USING gin((name || ' ' || surname) gin_trgm_ops);

-- Equipment category name search
CREATE INDEX idx_equipment_categories_name_search ON equipment_categories USING gin(category_name gin_trgm_ops);

-- Driver taskboard customer/contact search
CREATE INDEX idx_drivers_taskboard_customer_name ON drivers_taskboard USING gin(customer_name gin_trgm_ops);
CREATE INDEX idx_drivers_taskboard_contact_name ON drivers_taskboard USING gin(contact_name gin_trgm_ops);
*/

-- =============================================================================
-- MAINTENANCE NOTES
-- =============================================================================

/*
FIXES APPLIED:

1. IMMUTABLE FUNCTION ERROR:
   - REMOVED all partial indexes using CURRENT_DATE, INTERVAL functions, or date arithmetic
   - Converted problematic partial indexes to regular composite indexes
   - Use application-level filtering for date-based conditions instead

2. GIN_TRGM_OPS ERROR:
   - Commented out all gin_trgm_ops indexes
   - Added instructions to enable pg_trgm extension first
   - Provided optional section to add text search indexes after extension is enabled

3. PERFORMANCE OPTIMIZATIONS:
   - Kept all essential indexes for query performance
   - Maintained safe partial indexes for status-based filtering
   - Preserved composite indexes for complex queries
   - Removed date-based partial indexes to avoid IMMUTABLE errors

INSTALLATION STEPS:

1. Run the main index creation script (this file)
2. Optionally enable pg_trgm extension: CREATE EXTENSION IF NOT EXISTS pg_trgm;
3. Optionally run the commented text search indexes for fuzzy matching

MAINTENANCE RECOMMENDATIONS:

1. STATISTICS UPDATE:
   - Run ANALYZE regularly (daily) on high-traffic tables
   - Consider auto-vacuum settings for optimal performance

2. INDEX MONITORING:
   - Monitor index usage with pg_stat_user_indexes
   - Drop unused indexes periodically
   - Monitor index bloat and rebuild when necessary

3. PERFORMANCE TUNING:
   - Adjust work_mem for complex queries
   - Consider partitioning for very large tables (audit_log, interactions)
   - Monitor slow queries and add indexes as needed

4. QUERY PATTERN ANALYSIS:
   - Review query patterns quarterly
   - Add composite indexes for frequently used WHERE clauses
   - Consider covering indexes for read-heavy queries

5. INDEX SIZE MONITORING:
   - Monitor total index size vs table size ratio
   - Aim for reasonable index overhead (typically 1-3x table size)
*/