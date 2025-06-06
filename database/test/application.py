#!/usr/bin/env python3
"""
Database Test Script: Application Request Processing
==================================================

Test Scenario: Bill Guy wants to register his company ZXC Works to hire equipment

This script simulates the application process:
1. Create application interaction record (Layer 1)
2. Store application details component (Layer 2) 
3. Create user taskboard entry for manager approval (Layer 3)

Database Connection: PostgreSQL container on localhost:5432
"""

import psycopg2
import psycopg2.extras
from datetime import datetime, date, time
from typing import Dict, Optional

# Database connection configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'task_management',
    'user': 'SYSTEM',
    'password': 'SYSTEM'
}

class ApplicationProcessor:
    def __init__(self):
        self.conn = None
        self.cursor = None
        
    def connect(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(**DB_CONFIG)
            self.cursor = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            print("✅ Successfully connected to task_management database")
            return True
        except psycopg2.Error as e:
            print(f"❌ Database connection failed: {e}")
            return False
    
    def disconnect(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        print("📴 Database connection closed")
    
    def get_employee_by_role(self, role: str) -> Optional[Dict]:
        """Find an active employee by role"""
        try:
            query = "SELECT * FROM employees WHERE role = %s AND status = 'active' ORDER BY name LIMIT 1"
            self.cursor.execute(query, (role,))
            employee = self.cursor.fetchone()
            
            if employee:
                print(f"✅ Found {role}: {employee['name']} {employee['surname']} (ID: {employee['id']})")
                return dict(employee)
            else:
                print(f"❌ No active {role} found")
                return None
        except psycopg2.Error as e:
            print(f"❌ Error finding employee: {e}")
            return None
    
    def generate_reference_number(self) -> str:
        """Generate reference number for application"""
        try:
            # Try new system first
            try:
                self.cursor.execute("SELECT get_prefix_for_interaction('application')")
                prefix_result = self.cursor.fetchone()
                prefix = list(prefix_result.values())[0] if prefix_result else 'AP'
                
                date_part = datetime.now().strftime('%y%m%d')
                self.cursor.execute("SELECT get_next_sequence_for_date(%s, %s)", (prefix, date_part))
                seq_result = self.cursor.fetchone()
                sequence = list(seq_result.values())[0] if seq_result else 1
                
                reference = f"{prefix}{date_part}{sequence:03d}"
            except:
                # Fallback to manual
                date_part = datetime.now().strftime('%y%m%d')
                self.cursor.execute("SELECT COUNT(*) FROM interactions WHERE DATE(created_at) = CURRENT_DATE AND reference_number LIKE %s", (f"AP{date_part}%",))
                count = self.cursor.fetchone()[0] + 1
                reference = f"AP{date_part}{count:03d}"
            
            print(f"📝 Generated reference: {reference}")
            return reference
        except Exception as e:
            print(f"❌ Reference generation failed: {e}")
            return f"AP{datetime.now().strftime('%y%m%d')}001"
    
    def process_application(self, company_name: str, contact_name: str, phone: str, email: str):
        """Main method to process the application"""
        print("\n📝 STARTING APPLICATION PROCESS")
        print("=" * 50)
        print(f"Company: {company_name}")
        print(f"Contact: {contact_name}")
        print(f"Phone: {phone}")
        print(f"Email: {email}")
        
        # Step 1: Get employees
        print("\n👤 STEP 1: Employee Assignment")
        hire_controller = self.get_employee_by_role('hire_control')
        
        if not hire_controller:
            print("❌ Process terminated: No hire controller available")
            return False
        
        # Step 2: Create application interaction using generic customer (Layer 1)
        print("\n📝 STEP 2: Creating Application Interaction")
        reference = self.generate_reference_number()
        
        interaction_query = """
            INSERT INTO interactions (customer_id, contact_id, employee_id, interaction_type, 
                                    status, reference_number, contact_method, notes, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
        """
        notes = f"New account application from {contact_name} for company {company_name}. Contact: {phone}, {email}. Application form to be emailed to applicant."
        
        # Use generic customer (ID 999) and contact (ID 999)
        self.cursor.execute(interaction_query, (999, 999, hire_controller['id'], 'application', 'pending', 
                                              reference, 'phone', notes, datetime.now()))
        interaction_id = self.cursor.fetchone()['id']
        print(f"✅ Created interaction (ID: {interaction_id}, Ref: {reference})")
        print(f"   Using generic customer/contact (ID: 999)")
        
        # Step 3: Create application details component with applicant info (Layer 2)
        print("\n📋 STEP 3: Creating Application Details Component")
        
        # Parse contact name
        name_parts = contact_name.strip().split()
        first_name = name_parts[0]
        last_name = name_parts[-1] if len(name_parts) > 1 else ""
        
        app_details_query = """
            INSERT INTO component_application_details (
                interaction_id, application_type, applicant_first_name, applicant_last_name, 
                applicant_email, verification_status, documents_required, verification_notes
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        documents = "Company registration certificate, VAT certificate, Director ID copy, Proof of business address"
        verification_notes = f"Company: {company_name}, Phone: {phone}"
        
        self.cursor.execute(app_details_query, (interaction_id, 'company', first_name, last_name, 
                                              email, 'pending', documents, verification_notes))
        print(f"✅ Created application details component")
        print(f"   Applicant: {first_name} {last_name}")
        print(f"   Email: {email}")
        print(f"   Company: {company_name}")
        
        # Step 4: Create hire controller task to email application form (Layer 3)
        print("\n📋 STEP 4: Creating Hire Controller Task")
        tomorrow = date.today().replace(day=date.today().day + 1)
        
        task_title = f"Email application form to {contact_name} ({company_name})"
        task_description = f"""New Account Application - EMAIL APPLICATION FORM

APPLICANT DETAILS:
Name: {first_name} {last_name}
Company: {company_name}
Email: {email}
Phone: {phone}
Application Type: Company Account

REQUIRED ACTIONS:
1. Email application form to: {email}
2. Include list of required documentation
3. Provide company contact details for queries
4. Set follow-up reminder for 1 week
5. Update interaction status when email sent
6. Forward to manager when completed application received

EMAIL CONTENT SHOULD INCLUDE:
- Company account application form
- Required documentation list:
  {documents}
- Contact details for queries
- Timeline for application processing

FOLLOW-UP:
- Check for completed application in 1 week
- Send reminder if no response after 2 weeks
- Close application if no response after 1 month

Reference: {reference}"""
        
        task_query = """
            INSERT INTO user_taskboard (interaction_id, assigned_to, task_type, priority, status,
                                      title, description, due_date, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id
        """
        
        self.cursor.execute(task_query, (interaction_id, hire_controller['id'], 'process_application', 
                                       'medium', 'pending', task_title, task_description, tomorrow, datetime.now()))
        task_id = self.cursor.fetchone()['id']
        
        print(f"✅ Created hire controller task (ID: {task_id})")
        print(f"   Assigned to: {hire_controller['name']} {hire_controller['surname']} (Hire Control)")
        print(f"   Priority: MEDIUM")
        print(f"   Due: {tomorrow}")
        
        # Commit all changes
        try:
            self.conn.commit()
            print("\n✅ APPLICATION PROCESS COMPLETED")
            print(f"✅ Interaction ID: {interaction_id}")
            print(f"✅ Hire Controller Task ID: {task_id}")
            print("📧 Next: Hire controller will email application form to applicant")
            return True
        except psycopg2.Error as e:
            print(f"❌ Error committing: {e}")
            self.conn.rollback()
            return False


def main():
    """Main execution function"""
    print("📝 TASK MANAGEMENT SYSTEM - APPLICATION PROCESSING")
    print("📋 Scenario: Bill Guy wants to register ZXC Works for equipment hire")
    print("📧 Task Assignment: Hire controller (to email application form)")
    print("🗄️ Database: task_management @ localhost:5432")
    
    processor = ApplicationProcessor()
    
    try:
        if not processor.connect():
            return
        
        success = processor.process_application(
            company_name="ZXC Works",
            contact_name="Bill Guy",
            phone="+27114567890",
            email="bill.guy@zxcworks.com"
        )
        
        if success:
            print("\n🎉 Application submitted successfully!")
            print("\n📊 VERIFICATION QUERIES:")
            print("-- View the application interaction:")
            print("SELECT id, reference_number, interaction_type, status, created_at")
            print("FROM interactions WHERE interaction_type = 'application' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View the hire controller task:")
            print("SELECT ut.title, ut.priority, ut.due_date, e.name || ' ' || e.surname as assigned_to")
            print("FROM user_taskboard ut JOIN employees e ON ut.assigned_to = e.id")
            print("WHERE ut.task_type = 'process_application' ORDER BY ut.created_at DESC LIMIT 1;")
            print("\n-- View the applicant details:")
            print("SELECT i.reference_number, ad.applicant_first_name, ad.applicant_last_name,")
            print("       ad.applicant_email, ad.application_type, ad.verification_status")
            print("FROM interactions i")
            print("JOIN component_application_details ad ON i.id = ad.interaction_id")
            print("WHERE i.interaction_type = 'application' ORDER BY i.created_at DESC LIMIT 1;")
            print("\n-- View all applications using generic customer:")
            print("SELECT i.reference_number, ad.applicant_first_name || ' ' || ad.applicant_last_name as applicant,")
            print("       ad.applicant_email, ad.verification_notes, i.created_at")
            print("FROM interactions i")
            print("JOIN component_application_details ad ON i.id = ad.interaction_id")
            print("WHERE i.customer_id = 999 AND i.interaction_type = 'application'")
            print("ORDER BY i.created_at DESC;")
        else:
            print("\n❌ Application failed")
    
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        processor.disconnect()


if __name__ == "__main__":
    main()