-- =============================================================================
-- DATABASE CONSTRAINTS FOR DATA INTEGRITY
-- =============================================================================

-- =============================================================================
-- FOUNDATION TABLE CONSTRAINTS
-- =============================================================================

-- Customer Business Rules
-- Ensure customers have proper identification for companies
ALTER TABLE customers
ADD CONSTRAINT check_company_registration
CHECK (
  (is_company = false) 
  OR 
  (is_company = true AND (registration_number IS NOT NULL OR vat_number IS NOT NULL))
);

-- Credit limits cannot be negative
ALTER TABLE customers
ADD CONSTRAINT check_customer_credit_limit
CHECK (credit_limit >= 0);

-- Contact Information Validation
-- At least one contact method must be provided for contacts
ALTER TABLE contacts
ADD CONSTRAINT check_contact_info_required
CHECK (
  phone_number IS NOT NULL 
  OR whatsapp_number IS NOT NULL 
  OR email IS NOT NULL
);

-- Email format validation (basic)
ALTER TABLE contacts
ADD CONSTRAINT check_email_format
CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE employees
ADD CONSTRAINT check_employee_email_format
CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Primary Contact Constraint
-- Only one primary contact per customer
CREATE UNIQUE INDEX idx_unique_primary_contact 
ON contacts(customer_id) 
WHERE is_primary_contact = true;

-- Only one billing contact per customer
CREATE UNIQUE INDEX idx_unique_billing_contact 
ON contacts(customer_id) 
WHERE is_billing_contact = true;

-- Site Validation
-- GPS coordinates format (basic latitude,longitude validation)
ALTER TABLE sites
ADD CONSTRAINT check_gps_coordinates_format
CHECK (
  gps_coordinates IS NULL 
  OR gps_coordinates ~ '^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$'
);

-- Employee Constraints
-- Username format (alphanumeric and underscore only)
ALTER TABLE employees
ADD CONSTRAINT check_username_format
CHECK (username ~ '^[A-Za-z0-9_]{3,50}$');

-- Equipment Category Code Format
-- Ensure category codes follow expected format (letters + numbers)
ALTER TABLE equipment_categories
ADD CONSTRAINT check_category_code_format
CHECK (category_code ~ '^[A-Z]{2,4}[0-9]{1,4}$');

-- Equipment Pricing Constraints
-- Prices cannot be negative
ALTER TABLE equipment_pricing
ADD CONSTRAINT check_pricing_non_negative
CHECK (
  price_per_day >= 0 
  AND price_per_week >= 0 
  AND price_per_month >= 0 
  AND deposit_amount >= 0
);

-- Minimum hire period must be positive
ALTER TABLE equipment_pricing
ADD CONSTRAINT check_minimum_hire_period
CHECK (minimum_hire_period > 0);

-- Effective date logic
ALTER TABLE equipment_pricing
ADD CONSTRAINT check_effective_date_logic
CHECK (
  effective_to IS NULL 
  OR effective_from <= effective_to
);

-- =============================================================================
-- INTERACTION AND COMPONENT CONSTRAINTS
-- =============================================================================

-- Reference Number Format
-- Ensure reference numbers follow expected format
ALTER TABLE interactions
ADD CONSTRAINT check_reference_format
CHECK (reference_number ~ '^[A-Z]{2}[0-9]{6}$'); -- e.g., 'IN123456'

-- Equipment Quantity Logic
-- Quantities must be positive
ALTER TABLE component_equipment_list
ADD CONSTRAINT check_equipment_quantity
CHECK (quantity > 0);

-- Hire duration must be positive
ALTER TABLE component_equipment_list
ADD CONSTRAINT check_hire_duration
CHECK (hire_duration IS NULL OR hire_duration > 0);

-- Quote Totals Validation
-- Tax rate should be reasonable (0-100%)
ALTER TABLE component_quote_totals
ADD CONSTRAINT check_tax_rate_range
CHECK (tax_rate >= 0 AND tax_rate <= 100);

-- Total amounts should be non-negative
ALTER TABLE component_quote_totals
ADD CONSTRAINT check_quote_amounts_non_negative
CHECK (
  subtotal >= 0 
  AND tax_amount >= 0 
  AND total_amount >= 0
);

-- Quote expiry should be in the future when created
ALTER TABLE component_quote_totals
ADD CONSTRAINT check_quote_valid_until
CHECK (valid_until IS NULL OR valid_until >= CURRENT_DATE);

-- Currency code format (3 letters)
ALTER TABLE component_quote_totals
ADD CONSTRAINT check_currency_format
CHECK (currency ~ '^[A-Z]{3}$');

-- Refund Details Validation
-- Refund amount must be positive
ALTER TABLE component_refund_details
ADD CONSTRAINT check_refund_amount_positive
CHECK (refund_amount > 0);

-- Account balance logic (after refund should be less than before)
ALTER TABLE component_refund_details
ADD CONSTRAINT check_refund_balance_logic
CHECK (
  account_balance_after IS NULL 
  OR account_balance_before IS NULL 
  OR account_balance_after <= account_balance_before
);

-- Date Logic Constraints
-- Hire details: deliver date logic
ALTER TABLE component_hire_details
ADD CONSTRAINT check_hire_date_logic
CHECK (
  deliver_date IS NULL 
  OR start_date IS NULL 
  OR deliver_date <= start_date
);

-- Off-hire details: collection date logic
ALTER TABLE component_offhire_details
ADD CONSTRAINT check_offhire_date_logic
CHECK (
  end_date IS NULL 
  OR collect_date IS NULL 
  OR end_date <= collect_date
);

-- Time consistency (if date is provided, time should be too)
ALTER TABLE component_hire_details
ADD CONSTRAINT check_hire_time_consistency
CHECK (
  (deliver_date IS NULL AND deliver_time IS NULL)
  OR (deliver_date IS NOT NULL)
);

ALTER TABLE component_offhire_details
ADD CONSTRAINT check_offhire_time_consistency
CHECK (
  (collect_date IS NULL AND collect_time IS NULL)
  OR (collect_date IS NOT NULL)
);

-- Breakdown and Coring Details
-- Core specifications validation
ALTER TABLE component_coring_details
ADD CONSTRAINT check_core_specifications
CHECK (
  number_of_cores > 0
  AND (core_diameter IS NULL OR core_diameter ~ '^[0-9]+mm$')
  AND (core_depth IS NULL OR core_depth ~ '^[0-9]+mm$')
);

-- Misc Task Duration
-- Estimated duration should be reasonable (5 minutes to 16 hours)
ALTER TABLE component_misc_task_details
ADD CONSTRAINT check_estimated_duration
CHECK (
  estimated_duration IS NULL 
  OR (estimated_duration >= 5 AND estimated_duration <= 960)
);

-- Rental Agreement Validation
-- Rental dates logic
ALTER TABLE component_rental_agreements
ADD CONSTRAINT check_rental_date_logic
CHECK (
  rental_start_date IS NULL 
  OR rental_end_date IS NULL 
  OR rental_start_date <= rental_end_date
);

-- Rental days should match date difference
ALTER TABLE component_rental_agreements
ADD CONSTRAINT check_rental_days_logic
CHECK (
  total_rental_days IS NULL 
  OR rental_start_date IS NULL 
  OR rental_end_date IS NULL 
  OR total_rental_days = (rental_end_date - rental_start_date + 1)
);

-- Rates and deposits should be non-negative
ALTER TABLE component_rental_agreements
ADD CONSTRAINT check_rental_amounts
CHECK (
  daily_rate >= 0 
  AND weekly_rate >= 0 
  AND deposit_paid >= 0
);

-- =============================================================================
-- TASKBOARD CONSTRAINTS
-- =============================================================================

-- User Taskboard Constraints
-- Task completion logic - completed tasks must have completion timestamps
ALTER TABLE user_taskboard
ADD CONSTRAINT check_user_task_completion
CHECK (
  (status = 'completed' AND completed_at IS NOT NULL)
  OR (status != 'completed')
);

-- Started tasks should have started_at timestamp
ALTER TABLE user_taskboard
ADD CONSTRAINT check_user_task_started
CHECK (
  (status IN ('in_progress', 'completed') AND started_at IS NOT NULL)
  OR (status NOT IN ('in_progress', 'completed'))
);

-- Completion timestamp should be after started timestamp
ALTER TABLE user_taskboard
ADD CONSTRAINT check_user_task_time_logic
CHECK (
  started_at IS NULL 
  OR completed_at IS NULL 
  OR completed_at >= started_at
);

-- Due date should not be in the past when created (allow some flexibility)
ALTER TABLE user_taskboard
ADD CONSTRAINT check_user_task_due_date
CHECK (
  due_date IS NULL 
  OR due_date >= (created_at::date - INTERVAL '1 day')
);

-- Drivers Taskboard Constraints
-- Scheduled time logic for driver tasks
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_scheduled_time_logic
CHECK (
  (scheduled_date IS NOT NULL AND scheduled_time IS NOT NULL)
  OR (scheduled_date IS NULL AND scheduled_time IS NULL)
);

-- Task Duration Logic
-- Estimated duration should be reasonable (15 minutes to 16 hours)
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_estimated_duration_range
CHECK (
  estimated_duration IS NULL 
  OR (estimated_duration >= 15 AND estimated_duration <= 960)
);

-- Status progression logic - backlog tasks cannot have drivers assigned
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_backlog_assignment
CHECK (
  (status = 'backlog' AND assigned_to IS NULL)
  OR (status != 'backlog')
);

-- Assigned tasks should have an assigned driver
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_assigned_task_has_driver
CHECK (
  (status IN ('driver_1', 'driver_2', 'driver_3', 'driver_4') AND assigned_to IS NOT NULL)
  OR (status NOT IN ('driver_1', 'driver_2', 'driver_3', 'driver_4'))
);

-- Quality control logic - equipment must be verified before QC can be marked complete
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_quality_control_logic
CHECK (
  (status_quality_control = 'yes' AND equipment_verified = true)
  OR (status_quality_control = 'no')
);

-- WhatsApp notification requires WhatsApp number
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_whatsapp_notification_logic
CHECK (
  (status_whatsapp = 'yes' AND contact_whatsapp IS NOT NULL)
  OR (status_whatsapp = 'no')
);

-- Drivers Task Equipment Constraints
-- Equipment quantities must be positive
ALTER TABLE drivers_task_equipment
ADD CONSTRAINT check_task_equipment_quantity
CHECK (quantity > 0);

-- Verified equipment should have verifier and timestamp
ALTER TABLE drivers_task_equipment
ADD CONSTRAINT check_equipment_verification
CHECK (
  (verified = true AND verified_by IS NOT NULL AND verified_at IS NOT NULL)
  OR (verified = false)
);

-- =============================================================================
-- SUPPORTING TABLE CONSTRAINTS
-- =============================================================================

-- File Attachments Constraints
-- File size constraint (100MB = 104857600 bytes)
ALTER TABLE attachments
ADD CONSTRAINT check_file_size
CHECK (file_size > 0 AND file_size <= 104857600);

-- File name should not be empty
ALTER TABLE attachments
ADD CONSTRAINT check_file_name_not_empty
CHECK (LENGTH(TRIM(file_name)) > 0);

-- File path should not be empty
ALTER TABLE attachments
ADD CONSTRAINT check_file_path_not_empty
CHECK (LENGTH(TRIM(file_path)) > 0);

-- Audit Log Integrity
-- Ensure audit log has either old_values or new_values (or both)
ALTER TABLE audit_log
ADD CONSTRAINT check_audit_values
CHECK (
  old_values IS NOT NULL 
  OR new_values IS NOT NULL
);

-- Record ID should be positive
ALTER TABLE audit_log
ADD CONSTRAINT check_audit_record_id
CHECK (record_id > 0);

-- System Settings Validation
-- Setting values should not be empty strings
ALTER TABLE system_settings
ADD CONSTRAINT check_setting_value_not_empty
CHECK (LENGTH(TRIM(setting_value)) > 0);

-- Setting key should follow naming convention (lowercase with underscores)
ALTER TABLE system_settings
ADD CONSTRAINT check_setting_key_format
CHECK (setting_key ~ '^[a-z][a-z0-9_]*[a-z0-9]$');

-- =============================================================================
-- BUSINESS RULE CONSTRAINTS
-- =============================================================================

-- Interaction Type Validation
-- Ensure interaction components match interaction type
-- This is implemented through application logic and foreign key relationships

-- Equipment Category Consistency
-- Ensure equipment in drivers_task_equipment matches component_equipment_list for the same interaction
-- This constraint is complex and better handled in application logic with triggers if needed

-- Customer Site Relationship
-- Ensure sites used in components belong to the customer in the interaction
-- This is enforced through the site_id foreign key and customer_id relationship

-- =============================================================================
-- TEMPORAL CONSTRAINTS
-- =============================================================================

-- Prevent backdating beyond reasonable limits (30 days)
ALTER TABLE interactions
ADD CONSTRAINT check_interaction_date_reasonable
CHECK (created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days');

-- Prevent future dating beyond reasonable limits (7 days)
ALTER TABLE interactions
ADD CONSTRAINT check_interaction_date_not_too_future
CHECK (created_at <= CURRENT_TIMESTAMP + INTERVAL '7 days');

-- Task scheduling should not be too far in the past (emergency exceptions allowed)
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_scheduled_not_too_old
CHECK (
  scheduled_date IS NULL 
  OR scheduled_date >= CURRENT_DATE - INTERVAL '7 days'
  OR priority = 'urgent'
);

-- =============================================================================
-- PERFORMANCE AND MAINTENANCE CONSTRAINTS
-- =============================================================================

-- Limit text field lengths for performance
ALTER TABLE interactions
ADD CONSTRAINT check_notes_length
CHECK (LENGTH(notes) <= 5000);

ALTER TABLE user_taskboard
ADD CONSTRAINT check_description_length
CHECK (LENGTH(description) <= 2000);

ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_equipment_summary_length
CHECK (LENGTH(equipment_summary) <= 500);

-- =============================================================================
-- CONSTRAINT VALIDATION FUNCTIONS
-- =============================================================================

-- Function to validate phone numbers (basic format)
CREATE OR REPLACE FUNCTION is_valid_phone(phone_number TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Allow various phone number formats
    RETURN phone_number IS NULL 
           OR phone_number ~ '^[\+]?[0-9\s\-\(\)]{7,20}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Apply phone validation to relevant tables
ALTER TABLE contacts
ADD CONSTRAINT check_phone_format
CHECK (is_valid_phone(phone_number));

ALTER TABLE contacts
ADD CONSTRAINT check_whatsapp_format
CHECK (is_valid_phone(whatsapp_number));

ALTER TABLE employees
ADD CONSTRAINT check_employee_phone_format
CHECK (is_valid_phone(phone));

-- =============================================================================
-- MAINTENANCE NOTES
-- =============================================================================

/*
CONSTRAINT MAINTENANCE NOTES:

1. CONSTRAINT MONITORING:
   - Monitor constraint violations in application logs
   - Review pg_constraint system table for constraint definitions
   - Use pg_stat_user_tables to monitor constraint check overhead

2. PERFORMANCE IMPACT:
   - Check constraints are evaluated on INSERT/UPDATE
   - Complex constraints can impact write performance
   - Consider deferrable constraints for bulk operations

3. BUSINESS RULE EVOLUTION:
   - Some constraints may need adjustment as business rules change
   - Use ALTER TABLE ... DROP CONSTRAINT and ADD CONSTRAINT for updates
   - Test constraint changes thoroughly in staging environment

4. ERROR HANDLING:
   - Application should handle constraint violation exceptions gracefully
   - Provide user-friendly error messages for constraint violations
   - Log constraint violations for business intelligence

5. BULK OPERATIONS:
   - Consider temporarily disabling constraints for large data imports
   - Use SET CONSTRAINTS ALL DEFERRED for transaction-level deferral
   - Validate data integrity after bulk operations

6. CONSTRAINT DEPENDENCIES:
   - Some constraints depend on others (e.g., completion requires started timestamp)
   - Document constraint relationships for maintenance
   - Test constraint combinations during development
*/