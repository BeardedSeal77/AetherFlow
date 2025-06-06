#!/usr/bin/env python3
"""
Database Test Script: Refund Request Processing
==============================================

Test Scenario: John Guy from ABC Construction Ltd calls requesting a refund on his account

This script simulates the complete refund request process:
1. Create refund interaction record (Layer 1)
2. Store refund details component (Layer 2) 
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

class RefundRequestProcessor:
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
        """Find an active employee by role"""
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
                self.cursor.execute("SELECT get_prefix_for_interaction('refund')")
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
                prefix = 'RF'  # Fallback for refund
            
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
                'refund': 'RF',
                'statement': 'ST',
                'price_list': 'PL',
                'quote': 'QT',
                'hire': 'HR',
                'off_hire': 'OH',
                'breakdown': 'BD',
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
            fallback = f"RF{today}001"
            print(f"🆘 Using ultimate fallback: {fallback}")
            return fallback
    
    def create_refund_interaction(self, customer: Dict, contact: Dict, employee: Dict, 
                                refund_reason: str) -> Optional[int]:
        """Create the main refund interaction record (Layer 1)"""
        try:
            reference_number = self.generate_reference_number('refund')
            
            insert_query = """
                INSERT INTO interactions (
                    customer_id, contact_id, employee_id, interaction_type, 
                    status, reference_number, contact_method, notes, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            notes = f"Refund request from {contact_name} at {customer['customer_name']}. Reason: {refund_reason}. Customer requests refund of account credit balance."
            
            values = (
                customer['id'],
                contact['id'], 
                employee['id'],
                'refund',
                'pending',
                reference_number,
                'phone',
                notes,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            interaction_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created refund interaction (ID: {interaction_id}, Ref: {reference_number})")
            return interaction_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating refund interaction: {e}")
            return None
    
    def create_refund_details_component(self, interaction_id: int, refund_amount: float, 
                                      refund_reason: str, refund_type: str = 'partial',
                                      account_balance_before: float = 0.0) -> bool:
        """Create refund details component record (Layer 2)"""
        try:
            account_balance_after = account_balance_before - refund_amount
            
            insert_query = """
                INSERT INTO component_refund_details (
                    interaction_id, refund_type, refund_amount, refund_reason,
                    account_balance_before, account_balance_after, refund_method,
                    bank_details
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            values = (
                interaction_id,
                refund_type,  # 'full', 'partial', 'deposit_only'
                refund_amount,
                refund_reason,
                account_balance_before,
                account_balance_after,
                'eft',  # Default to electronic transfer
                'Customer banking details to be verified by accounts team'
            )
            
            self.cursor.execute(insert_query, values)
            print(f"✅ Created refund details component - Amount: R{refund_amount:,.2f}")
            print(f"   Type: {refund_type.replace('_', ' ').title()}")
            print(f"   Balance Before: R{account_balance_before:,.2f}")
            print(f"   Balance After: R{account_balance_after:,.2f}")
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error creating refund details component: {e}")
            return False
    
    def create_user_taskboard_entry(self, interaction_id: int, customer: Dict, contact: Dict, 
                                  created_by: Dict, accounts_employee: Dict, refund_amount: float,
                                  refund_reason: str, refund_type: str) -> Optional[int]:
        """Create user taskboard entry for accounts team to process refund (Layer 3)"""
        try:
            # Set due date for tomorrow (refunds need prompt attention)
            tomorrow = date.today().replace(day=date.today().day + 1)
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            
            task_title = f"Process refund request for {contact_name} at {customer['customer_name']}"
            task_description = f"""Refund request for {customer['customer_name']}:

REFUND DETAILS:
Amount: R{refund_amount:,.2f}
Type: {refund_type.replace('_', ' ').title()}
Reason: {refund_reason}

CUSTOMER INFORMATION:
Contact: {contact_name} ({contact['job_title']})
Email: {contact['email']}
Phone: {contact['phone_number']}
Customer Type: {'Company' if customer['is_company'] else 'Individual'}
Credit Limit: R{customer['credit_limit']:,.2f}
Payment Terms: {customer['payment_terms']}

REQUIRED ACTIONS:
1. Verify current account balance and transaction history
2. Confirm refund amount and eligibility
3. Obtain customer banking details for EFT
4. Process refund through banking system
5. Update customer account records
6. Email refund confirmation to customer
7. Update interaction status to completed

APPROVAL REQUIRED: {'Yes - Manager approval needed for refunds over R5,000' if refund_amount > 5000 else 'Standard processing - no special approval needed'}

Banking Method: Electronic Transfer (EFT)
Customer Banking Details: To be obtained and verified"""
            
            # Set priority based on refund amount
            if refund_amount > 10000:
                priority = 'high'
            elif refund_amount > 5000:
                priority = 'medium'
            else:
                priority = 'medium'
            
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
                'process_refund',
                priority,
                'pending',
                task_title,
                task_description,
                tomorrow,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            task_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created accounts team refund task (ID: {task_id})")
            print(f"   Assigned to: {accounts_employee['name']} {accounts_employee['surname']} (Accounts)")
            print(f"   Task: {task_title}")
            print(f"   Priority: {priority.upper()}")
            print(f"   Due: {tomorrow}")
            
            return task_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating accounts team refund task: {e}")
            return None
    
    def process_refund_request(self, customer_name: str, contact_name: str, refund_amount: float,
                             refund_reason: str, refund_type: str = 'partial'):
        """Main method to process the complete refund request"""
        print("\n💰 STARTING REFUND REQUEST PROCESS")
        print("=" * 60)
        print(f"Customer: {customer_name}")
        print(f"Contact: {contact_name}")
        print(f"Refund Amount: R{refund_amount:,.2f}")
        print(f"Refund Type: {refund_type.replace('_', ' ').title()}")
        print(f"Reason: {refund_reason}")
        
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
        
        # Step 4: Create refund interaction (Layer 1)
        print("\n📝 STEP 4: Creating Refund Interaction (Layer 1)")
        interaction_id = self.create_refund_interaction(customer, contact, employee, refund_reason)
        if not interaction_id:
            print("❌ Process terminated: Failed to create interaction")
            return False
        
        # Step 5: Create refund details component (Layer 2)
        print("\n💳 STEP 5: Creating Refund Details Component (Layer 2)")
        # Simulate current account balance (in real system, this would be calculated from transaction history)
        # Convert Decimal to float for calculation
        credit_limit_float = float(customer['credit_limit'])
        simulated_account_balance = credit_limit_float * 0.3  # Assume 30% of credit limit as current balance
        if not self.create_refund_details_component(interaction_id, refund_amount, refund_reason, 
                                                  refund_type, simulated_account_balance):
            print("❌ Warning: Failed to create refund details component")
        
        # Step 6: Create accounts team task (Layer 3)
        print("\n📋 STEP 6: Creating Accounts Team Task (Layer 3)")
        task_id = self.create_user_taskboard_entry(
            interaction_id, customer, contact, employee, accounts_employee, 
            refund_amount, refund_reason, refund_type
        )
        if not task_id:
            print("❌ Warning: Failed to create accounts team task")
            return False
        
        # Commit all changes
        try:
            self.conn.commit()
            print("\n✅ REFUND REQUEST PROCESS COMPLETED SUCCESSFULLY")
            print(f"✅ All database changes committed")
            print(f"✅ Interaction ID: {interaction_id}")
            print(f"✅ Accounts Task ID: {task_id}")
            
            # Display the created task and refund details
            self.display_created_task(task_id)
            self.display_refund_summary(customer, contact, refund_amount, refund_reason, refund_type)
            
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error committing changes: {e}")
            self.conn.rollback()
            return False
    
    def display_created_task(self, task_id: int):
        """Display the created accounts team refund task details"""
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
                print("CREATED ACCOUNTS TEAM REFUND TASK:")
                print("="*60)
                print(f"Task ID: {task['id']}")
                print(f"Reference: {task['reference_number']}")
                print(f"Type: {task['task_type']}")
                print(f"Title: {task['title']}")
                print(f"Assigned to: {task['assigned_to_name']} ({task['assigned_to_role'].upper()})")
                print(f"Priority: {task['priority'].upper()}")
                print(f"Status: {task['status']}")
                print(f"Due Date: {task['due_date']}")
                print(f"Created: {task['created_at']}")
                print("="*60)
                
        except psycopg2.Error as e:
            print(f"❌ Error displaying task details: {e}")
    
    def display_refund_summary(self, customer: Dict, contact: Dict, refund_amount: float, 
                             refund_reason: str, refund_type: str):
        """Display refund request summary"""
        try:
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            
            print("\n" + "="*60)
            print("REFUND REQUEST SUMMARY:")
            print("="*60)
            print(f"Customer: {customer['customer_name']}")
            print(f"Customer Type: {'Company' if customer['is_company'] else 'Individual'}")
            print(f"Requesting Contact: {contact_name} ({contact['job_title']})")
            print(f"Contact Email: {contact['email']}")
            print(f"Contact Phone: {contact['phone_number']}")
            
            print(f"\nREFUND DETAILS:")
            print(f"Amount Requested: R{refund_amount:,.2f}")
            print(f"Refund Type: {refund_type.replace('_', ' ').title()}")
            print(f"Reason: {refund_reason}")
            print(f"Method: Electronic Transfer (EFT)")
            
            print(f"\nACCOUNT INFORMATION:")
            print(f"Credit Limit: R{customer['credit_limit']:,.2f}")
            print(f"Payment Terms: {customer['payment_terms']}")
            
            print(f"\nNEXT STEPS:")
            print(f"1. Accounts team will verify current account balance")
            print(f"2. Customer banking details will be obtained")
            print(f"3. Refund will be processed via EFT")
            print(f"4. Customer will receive confirmation email")
            
            if refund_amount > 5000:
                print(f"\n⚠️  HIGH VALUE REFUND - Manager approval may be required")
            
            print("="*60)
            
        except Exception as e:
            print(f"❌ Error displaying refund summary: {e}")


def main():
    """Main execution function"""
    print("💰 TASK MANAGEMENT SYSTEM - REFUND REQUEST PROCESSING")
    print("📋 Scenario: John Guy from ABC Construction requests account refund")
    print("📞 Contact Method: Phone call to hire controller")
    print("📧 Task Assignment: Accounts team member")
    print("🗄️ Database: task_management @ localhost:5432")
    
    processor = RefundRequestProcessor()
    
    try:
        # Connect to database
        if not processor.connect():
            return
        
        # Process the refund request
        success = processor.process_refund_request(
            customer_name="ABC Construction",  # Will match "ABC Construction Ltd"
            contact_name="John Guy",  # Will find John Guy contact
            refund_amount=2500.00,  # Refund amount in ZAR
            refund_reason="Overpayment on account - customer paid invoice twice",
            refund_type="partial"  # partial, full, or deposit_only
        )
        
        if success:
            print("\n🎉 Refund request completed successfully!")
            print("\n📊 VERIFICATION QUERIES:")
            print("You can verify the data was created by running these SQL queries:")
            print("\n-- View the refund interaction:")
            print("SELECT id, reference_number, interaction_type, status, notes, created_at")
            print("FROM interactions WHERE interaction_type = 'refund' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View the refund details component:")
            print("SELECT i.reference_number, rd.refund_amount, rd.refund_type, rd.refund_reason,")
            print("       rd.account_balance_before, rd.account_balance_after, rd.refund_method")
            print("FROM interactions i")
            print("JOIN component_refund_details rd ON i.id = rd.interaction_id")
            print("WHERE i.interaction_type = 'refund' ORDER BY i.created_at DESC LIMIT 1;")
            print("\n-- View the accounts team refund task:")
            print("SELECT ut.id, ut.title, ut.task_type, ut.priority, ut.status, ut.due_date,")
            print("       e.name || ' ' || e.surname as assigned_to, e.role")
            print("FROM user_taskboard ut")
            print("JOIN employees e ON ut.assigned_to = e.id")
            print("WHERE ut.task_type = 'process_refund' ORDER BY ut.created_at DESC LIMIT 1;")
            print("\n-- View all pending refund tasks:")
            print("SELECT ut.id, ut.title, ut.priority, ut.due_date, i.reference_number,")
            print("       rd.refund_amount, rd.refund_type")
            print("FROM user_taskboard ut")
            print("JOIN interactions i ON ut.interaction_id = i.id")
            print("JOIN component_refund_details rd ON i.id = rd.interaction_id")
            print("WHERE ut.task_type = 'process_refund' AND ut.status = 'pending'")
            print("ORDER BY ut.priority DESC, ut.due_date ASC;")
        else:
            print("\n❌ Refund request failed - check error messages above")
    
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        processor.disconnect()


if __name__ == "__main__":
    main()