-- =============================================================================
-- DATABASE CONSTRAINTS FOR DATA INTEGRITY
-- =============================================================================

-- Customer Type Constraint
-- Ensure interactions link to either individual OR company (not both, not neither)
ALTER TABLE interactions 
ADD CONSTRAINT check_customer_type 
CHECK (
  (individual_customer_id IS NOT NULL AND company_id IS NULL AND company_contact_id IS NULL) 
  OR 
  (individual_customer_id IS NULL AND company_id IS NOT NULL AND company_contact_id IS NOT NULL)
);

-- Company Contact Must Belong to Company
-- Ensure company_contact_id matches the company_id in interactions
ALTER TABLE interactions
ADD CONSTRAINT check_contact_belongs_to_company
CHECK (
  (company_id IS NULL AND company_contact_id IS NULL)
  OR
  (company_id IS NOT NULL AND company_contact_id IS NOT NULL)
);

-- Primary Contact Constraint
-- Only one primary contact per company
CREATE UNIQUE INDEX idx_unique_primary_contact 
ON company_contacts(company_id) 
WHERE is_primary_contact = true;

-- Equipment Category Code Format
-- Ensure category codes follow expected format (letters + numbers)
ALTER TABLE equipment_categories
ADD CONSTRAINT check_category_code_format
CHECK (category_code ~ '^[A-Z]{2,4}[0-9]{1,4}$');

-- Task Assignment Logic
-- User taskboard can be assigned to any role (all users can have individual tasks)
ALTER TABLE user_taskboard
ADD CONSTRAINT check_user_task_assignment
CHECK (
  assigned_to IN (
    SELECT id FROM employees 
    WHERE role IN ('owner', 'manager', 'accounts', 'buyer', 'hire_control', 'driver', 'employee')
  )
);

-- Driver taskboard can be assigned to any role (all users can see/work driver schedule)
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_driver_task_assignment
CHECK (
  assigned_to IN (
    SELECT id FROM employees 
    WHERE role IN ('owner', 'manager', 'accounts', 'buyer', 'hire_control', 'driver', 'employee')
  )
);

-- Task Completion Logic
-- Completed tasks must have completion timestamps
ALTER TABLE user_taskboard
ADD CONSTRAINT check_user_task_completion
CHECK (
  (status = 'completed' AND completed_at IS NOT NULL)
  OR
  (status != 'completed')
);

ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_driver_task_completion
CHECK (
  (status = 'completed' AND completed_at IS NOT NULL)
  OR
  (status != 'completed')
);

-- Date Logic Constraints
-- Start date cannot be after end date
ALTER TABLE component_hire_date_details
ADD CONSTRAINT check_hire_date_logic
CHECK (start_date <= deliver_date OR start_date IS NULL OR deliver_date IS NULL);

ALTER TABLE component_off_hire_date_details
ADD CONSTRAINT check_offhire_date_logic
CHECK (end_date <= collect_date OR end_date IS NULL OR collect_date IS NULL);

-- Scheduled time logic for driver tasks
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_scheduled_time_logic
CHECK (
  (scheduled_date IS NOT NULL AND scheduled_time IS NOT NULL)
  OR
  (scheduled_date IS NULL AND scheduled_time IS NULL)
);

-- Task Duration Logic
-- Actual duration should be reasonable (not negative, not more than 24 hours)
ALTER TABLE drivers_taskboard
ADD CONSTRAINT check_duration_logic
CHECK (
  actual_duration IS NULL 
  OR 
  (actual_duration >= 0 AND actual_duration <= 1440) -- max 24 hours in minutes
);

-- Priority and Status Logic
-- Urgent tasks cannot be in pending status for long
-- (This might be enforced in application logic rather than DB constraint)

-- Reference Number Format
-- Ensure reference numbers follow expected format
ALTER TABLE interactions
ADD CONSTRAINT check_reference_format
CHECK (reference_number ~ '^[A-Z]{2}[0-9]{6}$'); -- e.g., 'IN123456'

-- Contact Information Validation
-- At least one contact method must be provided for individuals
ALTER TABLE individual_customers
ADD CONSTRAINT check_individual_contact_info
CHECK (
  contact_number IS NOT NULL 
  OR whatsapp_number IS NOT NULL 
  OR email IS NOT NULL
);

-- At least one contact method for company contacts
ALTER TABLE company_contacts
ADD CONSTRAINT check_company_contact_info
CHECK (
  contact_number IS NOT NULL 
  OR whatsapp_number IS NOT NULL 
  OR email IS NOT NULL
);

-- Credit Limit Logic
-- Credit limits cannot be negative
ALTER TABLE individual_customers
ADD CONSTRAINT check_individual_credit_limit
CHECK (credit_limit >= 0);

ALTER TABLE companies
ADD CONSTRAINT check_company_credit_limit
CHECK (credit_limit >= 0);

-- Equipment Quantity Logic
-- Quantities must be positive
ALTER TABLE component_equipment_list
ADD CONSTRAINT check_equipment_quantity
CHECK (quantity > 0);

ALTER TABLE drivers_task_equipment
ADD CONSTRAINT check_task_equipment_quantity
CHECK (quantity > 0);

-- File Size Constraint
-- Limit attachment file sizes (100MB = 104857600 bytes)
ALTER TABLE attachments
ADD CONSTRAINT check_file_size
CHECK (file_size > 0 AND file_size <= 104857600);

-- Audit Log Integrity
-- Ensure audit log has either old_values or new_values (or both)
ALTER TABLE audit_log
ADD CONSTRAINT check_audit_values
CHECK (
  old_values IS NOT NULL 
  OR new_values IS NOT NULL
);

-- System Settings Validation
-- Setting values should not be empty strings
ALTER TABLE system_settings
ADD CONSTRAINT check_setting_value_not_empty
CHECK (setting_value IS NOT NULL AND LENGTH(TRIM(setting_value)) > 0);