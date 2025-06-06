#!/usr/bin/env python3
"""
Database Test Script: Price List Task Creation
==============================================

Test Scenario: John Guy from ABC Construction Ltd calls asking for prices on 
Rammer and T1000 Breaker equipment

This script simulates the complete price list process:
1. Create price list interaction record (Layer 1)
2. Store equipment list components (Layer 2) 
3. Create user taskboard entry to send price list (Layer 3)
4. Generate the actual price list data for reference

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

class PriceListTaskProcessor:
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
                return dict(customer)
            else:
                print(f"❌ Customer '{customer_name}' not found or inactive")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding customer: {e}")
            return None
    
    def get_primary_contact(self, customer_id: int) -> Optional[Dict]:
        """Get primary contact for customer"""
        try:
            query = """
                SELECT * FROM contacts 
                WHERE customer_id = %s 
                AND is_primary_contact = true 
                AND status = 'active'
            """
            self.cursor.execute(query, (customer_id,))
            contact = self.cursor.fetchone()
            
            if contact:
                contact_name = f"{contact['first_name']} {contact['last_name']}"
                print(f"✅ Found primary contact: {contact_name}")
                print(f"   Job Title: {contact['job_title']}")
                print(f"   Phone: {contact['phone_number']}")
                print(f"   Email: {contact['email']}")
                return dict(contact)
            else:
                print(f"❌ No primary contact found for customer {customer_id}")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding contact: {e}")
            return None
    
    def get_equipment_by_names(self, equipment_names: List[str]) -> List[Dict]:
        """Get equipment categories by names"""
        try:
            placeholders = ','.join(['%s'] * len(equipment_names))
            query = f"""
                SELECT * FROM equipment_categories 
                WHERE LOWER(category_name) = ANY(ARRAY[{','.join(['LOWER(%s)'] * len(equipment_names))}])
                AND is_active = true
                ORDER BY category_name
            """
            self.cursor.execute(query, equipment_names)
            equipment_list = self.cursor.fetchall()
            
            print(f"✅ Found {len(equipment_list)} equipment items for price list:")
            for eq in equipment_list:
                print(f"   - {eq['category_name']} ({eq['category_code']})")
            
            return [dict(eq) for eq in equipment_list]
            
        except psycopg2.Error as e:
            print(f"❌ Error finding equipment: {e}")
            return []
    
    def get_equipment_pricing(self, equipment_list: List[Dict], customer_type: str) -> List[Dict]:
        """Get pricing for equipment based on customer type"""
        try:
            pricing_data = []
            
            for equipment in equipment_list:
                query = """
                    SELECT 
                        ec.category_name,
                        ec.category_code,
                        ec.description,
                        ec.default_accessories,
                        ec.specifications,
                        ep.price_per_day,
                        ep.price_per_week,
                        ep.price_per_month,
                        ep.deposit_amount,
                        ep.minimum_hire_period
                    FROM equipment_categories ec
                    JOIN equipment_pricing ep ON ec.id = ep.equipment_category_id
                    WHERE ec.id = %s 
                    AND ep.customer_type = %s 
                    AND ep.is_active = true
                """
                
                self.cursor.execute(query, (equipment['id'], customer_type))
                pricing = self.cursor.fetchone()
                
                if pricing:
                    pricing_data.append(dict(pricing))
                    print(f"✅ Found pricing for {pricing['category_name']}")
                    print(f"   Daily: R{pricing['price_per_day']}")
                    print(f"   Weekly: R{pricing['price_per_week']}")
                    print(f"   Deposit: R{pricing['deposit_amount']}")
                else:
                    print(f"❌ No pricing found for {equipment['category_name']} ({customer_type})")
            
            return pricing_data
            
        except psycopg2.Error as e:
            print(f"❌ Error getting equipment pricing: {e}")
            return []
    
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
    
    def generate_reference_number(self, interaction_type: str) -> str:
        """Generate a unique reference number using the new system"""
        try:
            # First check if the helper functions exist
            try:
                self.cursor.execute("SELECT get_prefix_for_interaction('price_list')")
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
                prefix = 'PL'  # Fallback for price_list
            
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
                'price_list': 'PL',
                'quote': 'QT',
                'hire': 'HR',
                'off_hire': 'OH',
                'breakdown': 'BD',
                'statement': 'ST',
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
            fallback = f"PL{today}001"
            print(f"🆘 Using ultimate fallback: {fallback}")
            return fallback
    
    def create_price_list_interaction(self, customer: Dict, contact: Dict, employee: Dict, 
                                    equipment_names: List[str]) -> Optional[int]:
        """Create the main price list interaction record (Layer 1)"""
        try:
            reference_number = self.generate_reference_number('price_list')
            
            insert_query = """
                INSERT INTO interactions (
                    customer_id, contact_id, employee_id, interaction_type, 
                    status, reference_number, contact_method, notes, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            equipment_list_str = ", ".join(equipment_names)
            notes = f"Price list request from {contact_name} at {customer['customer_name']} for {equipment_list_str}. Customer requested pricing information for potential hire."
            
            values = (
                customer['id'],
                contact['id'], 
                employee['id'],
                'price_list',
                'pending',
                reference_number,
                'phone',
                notes,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            interaction_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created price list interaction (ID: {interaction_id}, Ref: {reference_number})")
            return interaction_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating price list interaction: {e}")
            return None
    
    def create_equipment_list_components(self, interaction_id: int, equipment_list: List[Dict]) -> bool:
        """Create equipment list component records (Layer 2)"""
        try:
            insert_query = """
                INSERT INTO component_equipment_list (
                    interaction_id, equipment_category_id, quantity, special_requirements
                ) VALUES (%s, %s, %s, %s)
            """
            
            for equipment in equipment_list:
                values = (
                    interaction_id,
                    equipment['id'],
                    1,  # Default quantity for price inquiry
                    f"Price inquiry - {equipment['category_name']}"
                )
                self.cursor.execute(insert_query, values)
            
            print(f"✅ Created {len(equipment_list)} equipment list component records")
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error creating equipment list components: {e}")
            return False
    
    def create_user_taskboard_entry(self, interaction_id: int, customer: Dict, contact: Dict, 
                                  created_by: Dict, equipment_names: List[str]) -> Optional[int]:
        """Create user taskboard entry for sending price list (Layer 3)"""
        try:
            # Set due date for tomorrow (standard practice for price list requests)
            tomorrow = date.today().replace(day=date.today().day + 1)
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            equipment_list_str = ", ".join(equipment_names)
            
            task_title = f"Send price list to {contact_name} at {customer['customer_name']}"
            task_description = f"Prepare and send price list for {equipment_list_str} to {contact_name} ({contact['email']}) at {customer['customer_name']}. Customer type: {'Company' if customer['is_company'] else 'Individual'}. Contact method: Email preferred, phone: {contact['phone_number']}"
            
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
                created_by['id'],  # Assign to the hire controller who took the call
                'send_price_list',
                'medium',  # Standard priority for price list requests
                'pending',
                task_title,
                task_description,
                tomorrow,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            task_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created user taskboard entry (ID: {task_id})")
            print(f"   Task: {task_title}")
            print(f"   Due: {tomorrow}")
            print(f"   Priority: Medium")
            
            return task_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating user taskboard entry: {e}")
            return None
    
    def process_price_list_request(self, customer_name: str, equipment_names: List[str]):
        """Main method to process the complete price list request"""
        print("\n📋 STARTING PRICE LIST REQUEST PROCESS")
        print("=" * 60)
        print(f"Customer: {customer_name}")
        print(f"Equipment: {', '.join(equipment_names)}")
        
        # Step 1: Get customer and contact data
        print("\n📋 STEP 1: Customer & Contact Verification")
        customer = self.get_customer_by_name(customer_name)
        if not customer:
            print("❌ Process terminated: Customer not found")
            return False
        
        contact = self.get_primary_contact(customer['id'])
        if not contact:
            print("❌ Process terminated: Primary contact not found")
            return False
        
        # Step 2: Verify equipment exists
        print("\n📦 STEP 2: Equipment Verification")
        equipment_list = self.get_equipment_by_names(equipment_names)
        if not equipment_list:
            print("❌ Process terminated: No equipment found")
            return False
        
        # Step 3: Get pricing information
        print("\n💰 STEP 3: Pricing Information")
        customer_type = 'company' if customer['is_company'] else 'individual'
        pricing_data = self.get_equipment_pricing(equipment_list, customer_type)
        if not pricing_data:
            print("❌ Warning: No pricing data found")
        
        # Step 4: Get hire controller (who processes the request)
        print("\n👤 STEP 4: Employee Assignment")
        employee = self.get_employee_by_role('hire_control')
        if not employee:
            print("❌ Process terminated: No hire controller available")
            return False
        
        # Step 5: Create price list interaction (Layer 1)
        print("\n📝 STEP 5: Creating Price List Interaction (Layer 1)")
        interaction_id = self.create_price_list_interaction(customer, contact, employee, equipment_names)
        if not interaction_id:
            print("❌ Process terminated: Failed to create interaction")
            return False
        
        # Step 6: Create equipment list components (Layer 2)
        print("\n📦 STEP 6: Creating Equipment Components (Layer 2)")
        if not self.create_equipment_list_components(interaction_id, equipment_list):
            print("❌ Warning: Failed to create equipment components")
        
        # Step 7: Create user taskboard entry (Layer 3)
        print("\n📋 STEP 7: Creating User Task (Layer 3)")
        task_id = self.create_user_taskboard_entry(
            interaction_id, customer, contact, employee, equipment_names
        )
        if not task_id:
            print("❌ Warning: Failed to create user task")
            return False
        
        # Commit all changes
        try:
            self.conn.commit()
            print("\n✅ PRICE LIST PROCESS COMPLETED SUCCESSFULLY")
            print(f"✅ All database changes committed")
            print(f"✅ Interaction ID: {interaction_id}")
            print(f"✅ User Task ID: {task_id}")
            
            # Display the created task and price list
            self.display_created_task(task_id)
            if pricing_data:
                self.display_price_list(customer, contact, pricing_data)
            
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error committing changes: {e}")
            self.conn.rollback()
            return False
    
    def display_created_task(self, task_id: int):
        """Display the created user task details"""
        try:
            query = """
                SELECT 
                    ut.*,
                    i.reference_number,
                    e.name || ' ' || e.surname as assigned_to_name
                FROM user_taskboard ut
                JOIN interactions i ON ut.interaction_id = i.id
                JOIN employees e ON ut.assigned_to = e.id
                WHERE ut.id = %s
            """
            
            self.cursor.execute(query, (task_id,))
            task = self.cursor.fetchone()
            
            if task:
                print("\n" + "="*60)
                print("CREATED USER TASK DETAILS:")
                print("="*60)
                print(f"Task ID: {task['id']}")
                print(f"Reference: {task['reference_number']}")
                print(f"Type: {task['task_type']}")
                print(f"Title: {task['title']}")
                print(f"Description: {task['description']}")
                print(f"Assigned to: {task['assigned_to_name']}")
                print(f"Priority: {task['priority']}")
                print(f"Status: {task['status']}")
                print(f"Due Date: {task['due_date']}")
                print(f"Created: {task['created_at']}")
                print("="*60)
                
        except psycopg2.Error as e:
            print(f"❌ Error displaying task details: {e}")
    
    def display_price_list(self, customer: Dict, contact: Dict, pricing_data: List[Dict]):
        """Display the formatted price list that should be sent to customer"""
        try:
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            customer_type = 'Company' if customer['is_company'] else 'Individual'
            
            print("\n" + "="*80)
            print("EQUIPMENT PRICE LIST TO BE SENT TO CUSTOMER:")
            print("="*80)
            print(f"To: {contact_name}")
            print(f"Company: {customer['customer_name']}")
            print(f"Email: {contact['email']}")
            print(f"Phone: {contact['phone_number']}")
            print(f"Customer Type: {customer_type}")
            print(f"Date: {datetime.now().strftime('%Y-%m-%d')}")
            print("-" * 80)
            
            total_daily = 0
            total_weekly = 0
            total_deposit = 0
            
            for item in pricing_data:
                print(f"\n{item['category_name']} ({item['category_code']})")
                print(f"Description: {item['description']}")
                if item['specifications']:
                    print(f"Specifications: {item['specifications']}")
                if item['default_accessories']:
                    print(f"Includes: {item['default_accessories']}")
                print(f"Daily Rate: R{item['price_per_day']:,.2f}")
                print(f"Weekly Rate: R{item['price_per_week']:,.2f}")
                print(f"Monthly Rate: R{item['price_per_month']:,.2f}")
                print(f"Deposit Required: R{item['deposit_amount']:,.2f}")
                print(f"Minimum Hire: {item['minimum_hire_period']} day(s)")
                print("-" * 40)
                
                total_daily += item['price_per_day']
                total_weekly += item['price_per_week']
                total_deposit += item['deposit_amount']
            
            if len(pricing_data) > 1:
                print(f"\nTOTAL FOR ALL ITEMS:")
                print(f"Combined Daily Rate: R{total_daily:,.2f}")
                print(f"Combined Weekly Rate: R{total_weekly:,.2f}")
                print(f"Total Deposit Required: R{total_deposit:,.2f}")
            
            print(f"\nPayment Terms: {customer['payment_terms']}")
            print(f"Credit Limit: R{customer['credit_limit']:,.2f}")
            print("\nNotes:")
            print("- Prices include VAT where applicable")
            print("- Delivery and collection charges may apply")
            print("- Equipment subject to availability")
            print("- Terms and conditions apply")
            print("="*80)
            
        except Exception as e:
            print(f"❌ Error displaying price list: {e}")


def main():
    """Main execution function"""
    print("💰 TASK MANAGEMENT SYSTEM - PRICE LIST TASK CREATION")
    print("📋 Scenario: John Guy from ABC Construction requests prices for Rammer and T1000 Breaker")
    print("📞 Contact Method: Phone call to hire controller")
    print("📧 Response Method: Email price list to customer")
    print("🗄️ Database: task_management @ localhost:5432")
    
    processor = PriceListTaskProcessor()
    
    try:
        # Connect to database
        if not processor.connect():
            return
        
        # Process the price list request
        success = processor.process_price_list_request(
            customer_name="ABC Construction",  # Will match "ABC Construction Ltd"
            equipment_names=["Rammer", "T1000 Breaker"]  # Specific equipment requested
        )
        
        if success:
            print("\n🎉 Price list process completed successfully!")
            print("\n📊 VERIFICATION QUERIES:")
            print("You can verify the data was created by running these SQL queries:")
            print("\n-- View the price list interaction:")
            print("SELECT id, reference_number, interaction_type, status, notes, created_at")
            print("FROM interactions WHERE interaction_type = 'price_list' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View the user task:")
            print("SELECT id, title, task_type, priority, status, due_date, assigned_to")
            print("FROM user_taskboard WHERE task_type = 'send_price_list' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View equipment components:")
            print("SELECT i.reference_number, ec.category_name, cel.special_requirements")
            print("FROM interactions i")
            print("JOIN component_equipment_list cel ON i.id = cel.interaction_id")
            print("JOIN equipment_categories ec ON cel.equipment_category_id = ec.id")
            print("WHERE i.interaction_type = 'price_list' ORDER BY i.created_at DESC;")
            print("\n-- View complete price list data:")
            print("SELECT ec.category_name, ep.price_per_day, ep.price_per_week, ep.deposit_amount")
            print("FROM equipment_categories ec")
            print("JOIN equipment_pricing ep ON ec.id = ep.equipment_category_id")
            print("WHERE ec.category_name IN ('Rammer', 'T1000 Breaker') AND ep.customer_type = 'company';")
        else:
            print("\n❌ Price list process failed - check error messages above")
    
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        processor.disconnect()


if __name__ == "__main__":
    main()