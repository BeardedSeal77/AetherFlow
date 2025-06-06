#!/usr/bin/env python3
"""
Database Test Script: Account Statement Request
==============================================

Test Scenario: John Guy from ABC Construction Ltd calls requesting an account statement

This script simulates the complete statement request process:
1. Create statement interaction record (Layer 1)
2. Store statement request details (Layer 2) 
3. Create user taskboard entry for accounts team (Layer 3)

Database Connection: PostgreSQL container on localhost:5432
"""

import psycopg2
import psycopg2.extras
from datetime import datetime, date, time
import json
from typing import Dict, List, Optional, Tuple

# Database connection configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'task_management',
    'user': 'SYSTEM',
    'password': 'SYSTEM'
}

class StatementRequestProcessor:
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
    
    def get_customer_by_name(self, customer_name: str) -> Optional[Dict]:
        """Get customer by name"""
        try:
            query = "SELECT * FROM customers WHERE LOWER(customer_name) LIKE LOWER(%s) AND status = 'active'"
            self.cursor.execute(query, (f'%{customer_name}%',))
            customer = self.cursor.fetchone()
            
            if customer:
                print(f"✅ Found customer: {customer['customer_name']} (ID: {customer['id']})")
                print(f"   Type: {'Company' if customer['is_company'] else 'Individual'}")
                print(f"   Credit Limit: R{customer['credit_limit']:,.2f}")
                print(f"   Payment Terms: {customer['payment_terms']}")
                return dict(customer)
            else:
                print(f"❌ Customer '{customer_name}' not found or inactive")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding customer: {e}")
            return None
    
    def get_contact_by_name(self, customer_id: int, contact_name: str) -> Optional[Dict]:
        """Get contact by first/last name for customer"""
        try:
            # First try to find by concatenated full name
            query = """
                SELECT * FROM contacts 
                WHERE customer_id = %s 
                AND LOWER(first_name || ' ' || last_name) LIKE LOWER(%s)
                AND status = 'active'
                ORDER BY is_primary_contact DESC
                LIMIT 1
            """
            self.cursor.execute(query, (customer_id, f'%{contact_name}%'))
            contact = self.cursor.fetchone()
            
            # If not found, try individual name parts
            if not contact:
                print(f"🔍 Full name search failed, trying individual name parts...")
                name_parts = contact_name.strip().split()
                if len(name_parts) >= 2:
                    first_name = name_parts[0]
                    last_name = name_parts[-1]  # Take last part as surname
                    
                    query = """
                        SELECT * FROM contacts 
                        WHERE customer_id = %s 
                        AND LOWER(first_name) LIKE LOWER(%s) 
                        AND LOWER(last_name) LIKE LOWER(%s)
                        AND status = 'active'
                        ORDER BY is_primary_contact DESC
                        LIMIT 1
                    """
                    self.cursor.execute(query, (customer_id, f'%{first_name}%', f'%{last_name}%'))
                    contact = self.cursor.fetchone()
            
            # If still not found, try just first name
            if not contact:
                print(f"🔍 Name parts search failed, trying first name only...")
                first_name = contact_name.strip().split()[0] if contact_name.strip().split() else contact_name
                
                query = """
                    SELECT * FROM contacts 
                    WHERE customer_id = %s 
                    AND LOWER(first_name) LIKE LOWER(%s)
                    AND status = 'active'
                    ORDER BY is_primary_contact DESC
                    LIMIT 1
                """
                self.cursor.execute(query, (customer_id, f'%{first_name}%'))
                contact = self.cursor.fetchone()
            
            if contact:
                contact_full_name = f"{contact['first_name']} {contact['last_name']}"
                print(f"✅ Found contact: {contact_full_name}")
                print(f"   Job Title: {contact['job_title']}")
                print(f"   Phone: {contact['phone_number']}")
                print(f"   Email: {contact['email']}")
                print(f"   Primary Contact: {'Yes' if contact['is_primary_contact'] else 'No'}")
                print(f"   Billing Contact: {'Yes' if contact['is_billing_contact'] else 'No'}")
                return dict(contact)
            else:
                # If still not found, show available contacts for debugging
                print(f"❌ No contact found matching '{contact_name}' for customer {customer_id}")
                
                debug_query = """
                    SELECT first_name, last_name, job_title, is_primary_contact, status 
                    FROM contacts 
                    WHERE customer_id = %s
                """
                self.cursor.execute(debug_query, (customer_id,))
                available_contacts = self.cursor.fetchall()
                
                if available_contacts:
                    print(f"📋 Available contacts for customer {customer_id}:")
                    for contact in available_contacts:
                        print(f"   - {contact['first_name']} {contact['last_name']} ({contact['job_title']}) - Status: {contact['status']}")
                else:
                    print(f"📋 No contacts found for customer {customer_id}")
                
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding contact: {e}")
            return None
    
    def get_employee_by_role(self, role: str) -> Optional[Dict]:
        """Find an active employee by role - prioritizing accounts team"""
        try:
            query = """
                SELECT * FROM employees 
                WHERE role = %s AND status = 'active'
                ORDER BY name
                LIMIT 1
            """
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
    
    def get_accounts_team_member(self) -> Optional[Dict]:
        """Find an active accounts team member to assign the task"""
        try:
            query = """
                SELECT * FROM employees 
                WHERE role = 'accounts' AND status = 'active'
                ORDER BY name
                LIMIT 1
            """
            self.cursor.execute(query)
            accounts_employee = self.cursor.fetchone()
            
            if accounts_employee:
                print(f"✅ Found accounts team member: {accounts_employee['name']} {accounts_employee['surname']} (ID: {accounts_employee['id']})")
                return dict(accounts_employee)
            else:
                print(f"❌ No active accounts team member found")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding accounts team member: {e}")
            return None
    
    def generate_reference_number(self, interaction_type: str) -> str:
        """Generate a unique reference number using the new system"""
        try:
            # First check if the helper functions exist
            try:
                self.cursor.execute("SELECT get_prefix_for_interaction('statement')")
                test_result = self.cursor.fetchone()
            except psycopg2.Error as func_error:
                print(f"⚠️ Helper functions not available: {func_error}")
                return self.generate_reference_number_manual(interaction_type)
            
            # Get prefix from database lookup table
            prefix_query = "SELECT get_prefix_for_interaction(%s)"
            self.cursor.execute(prefix_query, (interaction_type,))
            result = self.cursor.fetchone()
            
            if result:
                if isinstance(result, dict):
                    prefix = list(result.values())[0]
                elif isinstance(result, (list, tuple)):
                    prefix = result[0]
                else:
                    prefix = result
            else:
                prefix = 'ST'  # Fallback for statement
            
            # Get date part (YYMMDD format)
            date_part = datetime.now().strftime('%y%m%d')
            
            # Get next sequence number for today
            seq_query = "SELECT get_next_sequence_for_date(%s, %s)"
            self.cursor.execute(seq_query, (prefix, date_part))
            sequence_result = self.cursor.fetchone()
            
            if sequence_result:
                if isinstance(sequence_result, dict):
                    sequence = list(sequence_result.values())[0]
                elif isinstance(sequence_result, (list, tuple)):
                    sequence = sequence_result[0]
                else:
                    sequence = sequence_result
            else:
                sequence = 1  # Fallback
            
            # Format reference number: PPYYMMDDNNN
            reference = f"{prefix}{date_part}{sequence:03d}"
            
            print(f"📝 Generated reference number: {reference}")
            return reference
            
        except Exception as e:
            print(f"❌ Error generating reference number: {e}")
            return self.generate_reference_number_manual(interaction_type)
    
    def generate_reference_number_manual(self, interaction_type: str) -> str:
        """Manual reference number generation as fallback"""
        try:
            prefix_map = {
                'statement': 'ST',
                'price_list': 'PL',
                'quote': 'QT',
                'hire': 'HR',
                'off_hire': 'OH',
                'breakdown': 'BD',
                'refund': 'RF',
                'application': 'AP',
                'coring': 'CR',
                'misc_task': 'MT'
            }
            
            prefix = prefix_map.get(interaction_type, 'IN')
            date_part = datetime.now().strftime('%y%m%d')
            
            query = """
                SELECT COUNT(*) as count FROM interactions 
                WHERE DATE(created_at) = CURRENT_DATE
                AND reference_number LIKE %s
            """
            pattern = f"{prefix}{date_part}%"
            self.cursor.execute(query, (pattern,))
            result = self.cursor.fetchone()
            
            if result:
                count = result['count'] if isinstance(result, dict) else result[0]
            else:
                count = 0
            
            sequence = count + 1
            reference = f"{prefix}{date_part}{sequence:03d}"
            
            print(f"📝 Generated reference number (manual): {reference}")
            return reference
            
        except Exception as e:
            print(f"❌ Manual generation failed: {e}")
            today = datetime.now().strftime('%y%m%d')
            fallback = f"ST{today}001"
            print(f"🆘 Using ultimate fallback: {fallback}")
            return fallback
    
    def create_statement_interaction(self, customer: Dict, contact: Dict, employee: Dict) -> Optional[int]:
        """Create the main statement interaction record (Layer 1)"""
        try:
            reference_number = self.generate_reference_number('statement')
            
            insert_query = """
                INSERT INTO interactions (
                    customer_id, contact_id, employee_id, interaction_type, 
                    status, reference_number, contact_method, notes, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            notes = f"Account statement request from {contact_name} at {customer['customer_name']}. Customer requested current account statement showing balance and transaction history."
            
            values = (
                customer['id'],
                contact['id'], 
                employee['id'],
                'statement',
                'pending',
                reference_number,
                'phone',
                notes,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            interaction_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created statement interaction (ID: {interaction_id}, Ref: {reference_number})")
            return interaction_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating statement interaction: {e}")
            return None
    
    def create_user_taskboard_entry(self, interaction_id: int, customer: Dict, contact: Dict, 
                                  created_by: Dict, accounts_employee: Dict) -> Optional[int]:
        """Create user taskboard entry for accounts team to generate statement (Layer 3)"""
        try:
            # Set due date for tomorrow (standard practice for statement requests)
            tomorrow = date.today().replace(day=date.today().day + 1)
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            
            task_title = f"Generate account statement for {contact_name} at {customer['customer_name']}"
            task_description = f"""Account statement request for {customer['customer_name']}:

Contact: {contact_name} ({contact['job_title']})
Email: {contact['email']}
Phone: {contact['phone_number']}
Customer Type: {'Company' if customer['is_company'] else 'Individual'}
Credit Limit: R{customer['credit_limit']:,.2f}
Payment Terms: {customer['payment_terms']}

Tasks:
1. Generate current account statement
2. Include all transactions and current balance
3. Email statement to customer contact
4. Update interaction status to completed

Billing Contact: {'Yes' if contact['is_billing_contact'] else 'No - Please verify if statement should be sent to billing contact instead'}"""
            
            insert_query = """
                INSERT INTO user_taskboard (
                    interaction_id, assigned_to, task_type, priority, status,
                    title, description, due_date, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """
            
            values = (
                interaction_id,
                accounts_employee['id'],  # Assign to accounts team member
                'send_statement',
                'medium',  # Standard priority for statement requests
                'pending',
                task_title,
                task_description,
                tomorrow,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            task_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created accounts team task (ID: {task_id})")
            print(f"   Assigned to: {accounts_employee['name']} {accounts_employee['surname']} (Accounts)")
            print(f"   Task: {task_title}")
            print(f"   Due: {tomorrow}")
            print(f"   Priority: Medium")
            
            return task_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating accounts team task: {e}")
            return None
    
    def process_statement_request(self, customer_name: str, contact_name: str):
        """Main method to process the complete statement request"""
        print("\n📊 STARTING ACCOUNT STATEMENT REQUEST PROCESS")
        print("=" * 60)
        print(f"Customer: {customer_name}")
        print(f"Contact: {contact_name}")
        
        # Step 1: Get customer and contact data
        print("\n📋 STEP 1: Customer & Contact Verification")
        customer = self.get_customer_by_name(customer_name)
        if not customer:
            print("❌ Process terminated: Customer not found")
            return False
        
        contact = self.get_contact_by_name(customer['id'], contact_name)
        if not contact:
            print("❌ Process terminated: Contact not found")
            return False
        
        # Step 2: Get employee who took the call (hire controller)
        print("\n👤 STEP 2: Call Handler Assignment")
        employee = self.get_employee_by_role('hire_control')
        if not employee:
            print("❌ Process terminated: No hire controller available")
            return False
        
        # Step 3: Get accounts team member to assign the task
        print("\n💼 STEP 3: Accounts Team Assignment")
        accounts_employee = self.get_accounts_team_member()
        if not accounts_employee:
            print("❌ Process terminated: No accounts team member available")
            return False
        
        # Step 4: Create statement interaction (Layer 1)
        print("\n📝 STEP 4: Creating Statement Interaction (Layer 1)")
        interaction_id = self.create_statement_interaction(customer, contact, employee)
        if not interaction_id:
            print("❌ Process terminated: Failed to create interaction")
            return False
        
        # Step 5: Create accounts team task (Layer 3)
        print("\n📋 STEP 5: Creating Accounts Team Task (Layer 3)")
        task_id = self.create_user_taskboard_entry(
            interaction_id, customer, contact, employee, accounts_employee
        )
        if not task_id:
            print("❌ Warning: Failed to create accounts team task")
            return False
        
        # Commit all changes
        try:
            self.conn.commit()
            print("\n✅ STATEMENT REQUEST PROCESS COMPLETED SUCCESSFULLY")
            print(f"✅ All database changes committed")
            print(f"✅ Interaction ID: {interaction_id}")
            print(f"✅ Accounts Task ID: {task_id}")
            
            # Display the created task
            self.display_created_task(task_id)
            self.display_customer_account_info(customer, contact)
            
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error committing changes: {e}")
            self.conn.rollback()
            return False
    
    def display_created_task(self, task_id: int):
        """Display the created accounts team task details"""
        try:
            query = """
                SELECT 
                    ut.*,
                    i.reference_number,
                    e.name || ' ' || e.surname as assigned_to_name,
                    e.role as assigned_to_role
                FROM user_taskboard ut
                JOIN interactions i ON ut.interaction_id = i.id
                JOIN employees e ON ut.assigned_to = e.id
                WHERE ut.id = %s
            """
            
            self.cursor.execute(query, (task_id,))
            task = self.cursor.fetchone()
            
            if task:
                print("\n" + "="*60)
                print("CREATED ACCOUNTS TEAM TASK:")
                print("="*60)
                print(f"Task ID: {task['id']}")
                print(f"Reference: {task['reference_number']}")
                print(f"Type: {task['task_type']}")
                print(f"Title: {task['title']}")
                print(f"Assigned to: {task['assigned_to_name']} ({task['assigned_to_role'].upper()})")
                print(f"Priority: {task['priority']}")
                print(f"Status: {task['status']}")
                print(f"Due Date: {task['due_date']}")
                print(f"Created: {task['created_at']}")
                print("\nTask Description:")
                print("-" * 40)
                print(task['description'])
                print("="*60)
                
        except psycopg2.Error as e:
            print(f"❌ Error displaying task details: {e}")
    
    def display_customer_account_info(self, customer: Dict, contact: Dict):
        """Display customer account information for reference"""
        try:
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            
            print("\n" + "="*60)
            print("CUSTOMER ACCOUNT INFORMATION:")
            print("="*60)
            print(f"Customer: {customer['customer_name']}")
            print(f"Customer Type: {'Company' if customer['is_company'] else 'Individual'}")
            if customer['is_company']:
                if customer['registration_number']:
                    print(f"Registration Number: {customer['registration_number']}")
                if customer['vat_number']:
                    print(f"VAT Number: {customer['vat_number']}")
            
            print(f"Credit Limit: R{customer['credit_limit']:,.2f}")
            print(f"Payment Terms: {customer['payment_terms']}")
            print(f"Account Status: {customer['status'].upper()}")
            
            print(f"\nRequesting Contact: {contact_name}")
            print(f"Job Title: {contact['job_title']}")
            print(f"Department: {contact.get('department', 'N/A')}")
            print(f"Email: {contact['email']}")
            print(f"Phone: {contact['phone_number']}")
            print(f"WhatsApp: {contact.get('whatsapp_number', 'N/A')}")
            print(f"Primary Contact: {'Yes' if contact['is_primary_contact'] else 'No'}")
            print(f"Billing Contact: {'Yes' if contact['is_billing_contact'] else 'No'}")
            
            if not contact['is_billing_contact']:
                print("\n⚠️  NOTE: This contact is NOT marked as billing contact.")
                print("   Accounts team should verify if statement should be sent to billing contact instead.")
            
            print("="*60)
            
        except Exception as e:
            print(f"❌ Error displaying customer account info: {e}")


def main():
    """Main execution function"""
    print("📊 TASK MANAGEMENT SYSTEM - ACCOUNT STATEMENT REQUEST")
    print("📋 Scenario: John Guy from ABC Construction requests account statement")
    print("📞 Contact Method: Phone call to hire controller")
    print("📧 Task Assignment: Accounts team member")
    print("🗄️ Database: task_management @ localhost:5432")
    
    processor = StatementRequestProcessor()
    
    try:
        # Connect to database
        if not processor.connect():
            return
        
        # Process the statement request
        success = processor.process_statement_request(
            customer_name="ABC Construction",  # Will match "ABC Construction Ltd"
            contact_name="John Guy"  # Will find John Guy contact
        )
        
        if success:
            print("\n🎉 Account statement request completed successfully!")
            print("\n📊 VERIFICATION QUERIES:")
            print("You can verify the data was created by running these SQL queries:")
            print("\n-- View the statement interaction:")
            print("SELECT id, reference_number, interaction_type, status, notes, created_at")
            print("FROM interactions WHERE interaction_type = 'statement' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View the accounts team task:")
            print("SELECT ut.id, ut.title, ut.task_type, ut.priority, ut.status, ut.due_date,")
            print("       e.name || ' ' || e.surname as assigned_to, e.role")
            print("FROM user_taskboard ut")
            print("JOIN employees e ON ut.assigned_to = e.id")
            print("WHERE ut.task_type = 'send_statement' ORDER BY ut.created_at DESC LIMIT 1;")
            print("\n-- View all tasks assigned to accounts team:")
            print("SELECT ut.id, ut.title, ut.task_type, ut.status, ut.due_date, i.reference_number")
            print("FROM user_taskboard ut")
            print("JOIN employees e ON ut.assigned_to = e.id")
            print("JOIN interactions i ON ut.interaction_id = i.id")
            print("WHERE e.role = 'accounts' AND ut.status NOT IN ('completed', 'cancelled')")
            print("ORDER BY ut.due_date ASC;")
            print("\n-- Check customer account details:")
            print("SELECT customer_name, is_company, credit_limit, payment_terms, status")
            print("FROM customers WHERE customer_name LIKE '%ABC Construction%';")
        else:
            print("\n❌ Account statement request failed - check error messages above")
    
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        processor.disconnect()


if __name__ == "__main__":
    main()