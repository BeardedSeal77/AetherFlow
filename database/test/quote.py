#!/usr/bin/env python3
"""
Database Test Script: Quote Request Processing
==============================================

Test Scenario: John Guy from ABC Construction Ltd requests a quote to hire a rammer for 3 days

This script simulates the complete quote request process:
1. Create quote interaction record (Layer 1)
2. Store equipment list and quote totals components (Layer 2) 
3. Create user taskboard entry for hire controller to send quote (Layer 3)

Database Connection: PostgreSQL container on localhost:5432
"""

import psycopg2
import psycopg2.extras
from datetime import datetime, date, time, timedelta
import json
from typing import Dict, List, Optional, Tuple
from decimal import Decimal

# Database connection configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'task_management',
    'user': 'SYSTEM',
    'password': 'SYSTEM'
}

class QuoteRequestProcessor:
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
                name_parts = contact_name.strip().split()
                if len(name_parts) >= 2:
                    first_name = name_parts[0]
                    last_name = name_parts[-1]
                    
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
            
            if contact:
                contact_full_name = f"{contact['first_name']} {contact['last_name']}"
                print(f"✅ Found contact: {contact_full_name}")
                print(f"   Job Title: {contact['job_title']}")
                print(f"   Phone: {contact['phone_number']}")
                print(f"   Email: {contact['email']}")
                return dict(contact)
            else:
                print(f"❌ No contact found matching '{contact_name}' for customer {customer_id}")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding contact: {e}")
            return None
    
    def get_equipment_by_names(self, equipment_names: List[str]) -> List[Dict]:
        """Get equipment categories by names"""
        try:
            query = f"""
                SELECT * FROM equipment_categories 
                WHERE LOWER(category_name) = ANY(ARRAY[{','.join(['LOWER(%s)'] * len(equipment_names))}])
                AND is_active = true
                ORDER BY category_name
            """
            self.cursor.execute(query, equipment_names)
            equipment_list = self.cursor.fetchall()
            
            print(f"✅ Found {len(equipment_list)} equipment items for quote:")
            for eq in equipment_list:
                print(f"   - {eq['category_name']} ({eq['category_code']})")
            
            return [dict(eq) for eq in equipment_list]
            
        except psycopg2.Error as e:
            print(f"❌ Error finding equipment: {e}")
            return []
    
    def get_equipment_pricing(self, equipment_list: List[Dict], customer_type: str, hire_duration: int) -> List[Dict]:
        """Get pricing for equipment based on customer type and duration"""
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
                    # Calculate total cost based on duration
                    daily_rate = float(pricing['price_per_day'])
                    weekly_rate = float(pricing['price_per_week'])
                    monthly_rate = float(pricing['price_per_month'])
                    
                    # Choose best rate for customer
                    if hire_duration >= 28:  # Monthly rate
                        total_cost = monthly_rate * (hire_duration / 30)
                        rate_type = "monthly"
                        base_rate = monthly_rate
                    elif hire_duration >= 7:  # Weekly rate
                        total_cost = weekly_rate * (hire_duration / 7)
                        rate_type = "weekly"
                        base_rate = weekly_rate
                    else:  # Daily rate
                        total_cost = daily_rate * hire_duration
                        rate_type = "daily"
                        base_rate = daily_rate
                    
                    pricing_info = dict(pricing)
                    pricing_info['hire_duration'] = hire_duration
                    pricing_info['rate_type'] = rate_type
                    pricing_info['base_rate'] = base_rate
                    pricing_info['total_cost'] = round(total_cost, 2)
                    pricing_info['equipment_id'] = equipment['id']
                    
                    pricing_data.append(pricing_info)
                    
                    print(f"✅ Calculated pricing for {pricing['category_name']}")
                    print(f"   Duration: {hire_duration} days")
                    print(f"   Rate: R{base_rate:,.2f} per {rate_type.replace('ly', '')}")
                    print(f"   Total: R{total_cost:,.2f}")
                    print(f"   Deposit: R{pricing['deposit_amount']:,.2f}")
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
            try:
                self.cursor.execute("SELECT get_prefix_for_interaction('quote')")
                test_result = self.cursor.fetchone()
            except psycopg2.Error:
                return self.generate_reference_number_manual(interaction_type)
            
            prefix_query = "SELECT get_prefix_for_interaction(%s)"
            self.cursor.execute(prefix_query, (interaction_type,))
            result = self.cursor.fetchone()
            
            prefix = 'QT'  # Default fallback
            if result:
                if isinstance(result, dict):
                    prefix = list(result.values())[0]
                elif isinstance(result, (list, tuple)):
                    prefix = result[0]
                else:
                    prefix = result
            
            date_part = datetime.now().strftime('%y%m%d')
            
            seq_query = "SELECT get_next_sequence_for_date(%s, %s)"
            self.cursor.execute(seq_query, (prefix, date_part))
            sequence_result = self.cursor.fetchone()
            
            sequence = 1
            if sequence_result:
                if isinstance(sequence_result, dict):
                    sequence = list(sequence_result.values())[0]
                elif isinstance(sequence_result, (list, tuple)):
                    sequence = sequence_result[0]
                else:
                    sequence = sequence_result
            
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
                'quote': 'QT',
                'price_list': 'PL',
                'hire': 'HR',
                'statement': 'ST',
                'refund': 'RF'
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
            
            count = result['count'] if result else 0
            sequence = count + 1
            reference = f"{prefix}{date_part}{sequence:03d}"
            
            print(f"📝 Generated reference number (manual): {reference}")
            return reference
            
        except Exception as e:
            print(f"❌ Manual generation failed: {e}")
            today = datetime.now().strftime('%y%m%d')
            return f"QT{today}001"
    
    def create_quote_interaction(self, customer: Dict, contact: Dict, employee: Dict, 
                               equipment_names: List[str], hire_duration: int) -> Optional[int]:
        """Create the main quote interaction record (Layer 1)"""
        try:
            reference_number = self.generate_reference_number('quote')
            
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
            notes = f"Quote request from {contact_name} at {customer['customer_name']} for {equipment_list_str}. Duration: {hire_duration} days. Customer requires formal quotation for budget approval."
            
            values = (
                customer['id'],
                contact['id'], 
                employee['id'],
                'quote',
                'pending',
                reference_number,
                'phone',
                notes,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            interaction_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created quote interaction (ID: {interaction_id}, Ref: {reference_number})")
            return interaction_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating quote interaction: {e}")
            return None
    
    def create_equipment_list_components(self, interaction_id: int, equipment_list: List[Dict], 
                                       pricing_data: List[Dict], hire_duration: int) -> bool:
        """Create equipment list component records (Layer 2)"""
        try:
            insert_query = """
                INSERT INTO component_equipment_list (
                    interaction_id, equipment_category_id, quantity, 
                    hire_duration, hire_period_type, special_requirements
                ) VALUES (%s, %s, %s, %s, %s, %s)
            """
            
            for i, equipment in enumerate(equipment_list):
                if i < len(pricing_data):
                    pricing = pricing_data[i]
                    special_requirements = f"Quote for {hire_duration} day hire. Rate: R{pricing['base_rate']:,.2f} per {pricing['rate_type'].replace('ly', '')}. Total: R{pricing['total_cost']:,.2f}"
                else:
                    special_requirements = f"Quote for {hire_duration} day hire"
                
                values = (
                    interaction_id,
                    equipment['id'],
                    1,  # Quantity
                    hire_duration,
                    'days',
                    special_requirements
                )
                self.cursor.execute(insert_query, values)
            
            print(f"✅ Created {len(equipment_list)} equipment list component records")
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error creating equipment list components: {e}")
            return False
    
    def create_quote_totals_component(self, interaction_id: int, pricing_data: List[Dict], 
                                    tax_rate: float = 15.0) -> bool:
        """Create quote totals component record (Layer 2)"""
        try:
            # Calculate totals
            subtotal = sum(item['total_cost'] for item in pricing_data)
            tax_amount = subtotal * (tax_rate / 100)
            total_amount = subtotal + tax_amount
            
            # Quote valid for 30 days
            valid_until = date.today() + timedelta(days=30)
            
            insert_query = """
                INSERT INTO component_quote_totals (
                    interaction_id, subtotal, tax_rate, tax_amount, total_amount,
                    currency, valid_until, notes, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            notes = f"Quote includes {len(pricing_data)} equipment item(s). VAT included at {tax_rate}%. Quote valid for 30 days from issue date."
            
            values = (
                interaction_id,
                subtotal,
                tax_rate,
                tax_amount,
                total_amount,
                'ZAR',
                valid_until,
                notes,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            print(f"✅ Created quote totals component")
            print(f"   Subtotal: R{subtotal:,.2f}")
            print(f"   VAT ({tax_rate}%): R{tax_amount:,.2f}")
            print(f"   Total: R{total_amount:,.2f}")
            print(f"   Valid Until: {valid_until}")
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error creating quote totals component: {e}")
            return False
    
    def create_user_taskboard_entry(self, interaction_id: int, customer: Dict, contact: Dict, 
                                  created_by: Dict, pricing_data: List[Dict], hire_duration: int) -> Optional[int]:
        """Create user taskboard entry for sending quote (Layer 3)"""
        try:
            # Set due date for tomorrow (quotes need prompt turnaround)
            tomorrow = date.today().replace(day=date.today().day + 1)
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            equipment_list_str = ", ".join([item['category_name'] for item in pricing_data])
            
            # Calculate totals for task description
            subtotal = sum(item['total_cost'] for item in pricing_data)
            tax_amount = subtotal * 0.15
            total_amount = subtotal + tax_amount
            
            task_title = f"Send quote to {contact_name} at {customer['customer_name']}"
            task_description = f"""Quote request for {customer['customer_name']}:

QUOTE DETAILS:
Equipment: {equipment_list_str}
Duration: {hire_duration} days
Subtotal: R{subtotal:,.2f}
VAT (15%): R{tax_amount:,.2f}
Total: R{total_amount:,.2f}

CUSTOMER INFORMATION:
Contact: {contact_name} ({contact['job_title']})
Email: {contact['email']}
Phone: {contact['phone_number']}
Customer Type: {'Company' if customer['is_company'] else 'Individual'}
Credit Limit: R{customer['credit_limit']:,.2f}
Payment Terms: {customer['payment_terms']}

REQUIRED ACTIONS:
1. Generate formal quote document (PDF)
2. Include all equipment specifications and pricing
3. Add standard terms and conditions
4. Email quote to customer contact
5. Follow up within 3 business days if no response
6. Update interaction status when quote is sent

EQUIPMENT DETAILS:
{chr(10).join([f"- {item['category_name']}: R{item['total_cost']:,.2f} ({hire_duration} days @ R{item['base_rate']:,.2f} per {item['rate_type'].replace('ly', '')})" for item in pricing_data])}

Quote Valid Until: {(date.today() + timedelta(days=30)).strftime('%Y-%m-%d')}"""
            
            insert_query = """
                INSERT INTO user_taskboard (
                    interaction_id, assigned_to, task_type, priority, status,
                    title, description, due_date, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """
            
            # High priority for quotes (time-sensitive)
            priority = 'high' if total_amount > 5000 else 'medium'
            
            values = (
                interaction_id,
                created_by['id'],  # Assign to hire controller who took the call
                'send_quote',
                priority,
                'pending',
                task_title,
                task_description,
                tomorrow,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            task_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created quote task (ID: {task_id})")
            print(f"   Assigned to: {created_by['name']} {created_by['surname']} (Hire Control)")
            print(f"   Task: {task_title}")
            print(f"   Priority: {priority.upper()}")
            print(f"   Due: {tomorrow}")
            
            return task_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating quote task: {e}")
            return None
    
    def process_quote_request(self, customer_name: str, contact_name: str, 
                            equipment_names: List[str], hire_duration: int):
        """Main method to process the complete quote request"""
        print("\n💼 STARTING QUOTE REQUEST PROCESS")
        print("=" * 60)
        print(f"Customer: {customer_name}")
        print(f"Contact: {contact_name}")
        print(f"Equipment: {', '.join(equipment_names)}")
        print(f"Duration: {hire_duration} days")
        
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
        
        # Step 2: Verify equipment exists and get pricing
        print("\n📦 STEP 2: Equipment & Pricing Verification")
        equipment_list = self.get_equipment_by_names(equipment_names)
        if not equipment_list:
            print("❌ Process terminated: No equipment found")
            return False
        
        customer_type = 'company' if customer['is_company'] else 'individual'
        pricing_data = self.get_equipment_pricing(equipment_list, customer_type, hire_duration)
        if not pricing_data:
            print("❌ Process terminated: No pricing data found")
            return False
        
        # Step 3: Get hire controller (who processes quotes)
        print("\n👤 STEP 3: Employee Assignment")
        employee = self.get_employee_by_role('hire_control')
        if not employee:
            print("❌ Process terminated: No hire controller available")
            return False
        
        # Step 4: Create quote interaction (Layer 1)
        print("\n📝 STEP 4: Creating Quote Interaction (Layer 1)")
        interaction_id = self.create_quote_interaction(customer, contact, employee, equipment_names, hire_duration)
        if not interaction_id:
            print("❌ Process terminated: Failed to create interaction")
            return False
        
        # Step 5: Create equipment list components (Layer 2)
        print("\n📦 STEP 5: Creating Equipment Components (Layer 2)")
        if not self.create_equipment_list_components(interaction_id, equipment_list, pricing_data, hire_duration):
            print("❌ Warning: Failed to create equipment components")
        
        # Step 6: Create quote totals component (Layer 2)
        print("\n💰 STEP 6: Creating Quote Totals Component (Layer 2)")
        if not self.create_quote_totals_component(interaction_id, pricing_data, 15.0):
            print("❌ Warning: Failed to create quote totals")
        
        # Step 7: Create user taskboard entry (Layer 3)
        print("\n📋 STEP 7: Creating Quote Task (Layer 3)")
        task_id = self.create_user_taskboard_entry(
            interaction_id, customer, contact, employee, pricing_data, hire_duration
        )
        if not task_id:
            print("❌ Warning: Failed to create quote task")
            return False
        
        # Commit all changes
        try:
            self.conn.commit()
            print("\n✅ QUOTE REQUEST PROCESS COMPLETED SUCCESSFULLY")
            print(f"✅ All database changes committed")
            print(f"✅ Interaction ID: {interaction_id}")
            print(f"✅ Quote Task ID: {task_id}")
            
            # Display the created task and quote
            self.display_created_task(task_id)
            self.display_quote_summary(customer, contact, pricing_data, hire_duration)
            
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error committing changes: {e}")
            self.conn.rollback()
            return False
    
    def display_created_task(self, task_id: int):
        """Display the created quote task details"""
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
                print("CREATED QUOTE TASK:")
                print("="*60)
                print(f"Task ID: {task['id']}")
                print(f"Reference: {task['reference_number']}")
                print(f"Type: {task['task_type']}")
                print(f"Title: {task['title']}")
                print(f"Assigned to: {task['assigned_to_name']}")
                print(f"Priority: {task['priority'].upper()}")
                print(f"Status: {task['status']}")
                print(f"Due Date: {task['due_date']}")
                print("="*60)
                
        except psycopg2.Error as e:
            print(f"❌ Error displaying task details: {e}")
    
    def display_quote_summary(self, customer: Dict, contact: Dict, pricing_data: List[Dict], hire_duration: int):
        """Display the quote summary that will be sent to customer"""
        try:
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            
            print("\n" + "="*80)
            print("QUOTE SUMMARY TO BE SENT TO CUSTOMER:")
            print("="*80)
            print(f"To: {contact_name}")
            print(f"Company: {customer['customer_name']}")
            print(f"Email: {contact['email']}")
            print(f"Phone: {contact['phone_number']}")
            print(f"Quote Date: {datetime.now().strftime('%Y-%m-%d')}")
            print(f"Valid Until: {(date.today() + timedelta(days=30)).strftime('%Y-%m-%d')}")
            print("-" * 80)
            
            subtotal = 0
            print(f"\nEQUIPMENT HIRE QUOTE - {hire_duration} DAYS:")
            print("-" * 50)
            
            for item in pricing_data:
                print(f"\n{item['category_name']} ({item['category_code']})")
                print(f"Description: {item['description']}")
                if item['specifications']:
                    print(f"Specifications: {item['specifications']}")
                if item['default_accessories']:
                    print(f"Includes: {item['default_accessories']}")
                print(f"Duration: {hire_duration} days")
                print(f"Rate: R{item['base_rate']:,.2f} per {item['rate_type'].replace('ly', '')}")
                print(f"Total: R{item['total_cost']:,.2f}")
                print(f"Deposit Required: R{item['deposit_amount']:,.2f}")
                print("-" * 50)
                subtotal += item['total_cost']
            
            tax_amount = subtotal * 0.15
            total_amount = subtotal + tax_amount
            total_deposit = sum(item['deposit_amount'] for item in pricing_data)
            
            print(f"\nQUOTE TOTALS:")
            print(f"Subtotal: R{subtotal:,.2f}")
            print(f"VAT (15%): R{tax_amount:,.2f}")
            print(f"TOTAL AMOUNT: R{total_amount:,.2f}")
            print(f"Total Deposit Required: R{float(total_deposit):,.2f}")
            
            print(f"\nPAYMENT TERMS:")
            print(f"Customer Terms: {customer['payment_terms']}")
            print(f"Credit Limit: R{customer['credit_limit']:,.2f}")
            
            print(f"\nTERMS & CONDITIONS:")
            print("- Quote valid for 30 days from issue date")
            print("- Prices include VAT where applicable")
            print("- Deposit required before equipment dispatch")
            print("- Delivery and collection charges may apply")
            print("- Equipment subject to availability")
            print("- Standard hire terms and conditions apply")
            print("="*80)
            
        except Exception as e:
            print(f"❌ Error displaying quote summary: {e}")


def main():
    """Main execution function"""
    print("💼 TASK MANAGEMENT SYSTEM - QUOTE REQUEST PROCESSING")
    print("📋 Scenario: John Guy from ABC Construction requests quote for rammer hire (3 days)")
    print("📞 Contact Method: Phone call to hire controller")
    print("📧 Task Assignment: Hire controller (same person)")
    print("🗄️ Database: task_management @ localhost:5432")
    
    processor = QuoteRequestProcessor()
    
    try:
        # Connect to database
        if not processor.connect():
            return
        
        # Process the quote request
        success = processor.process_quote_request(
            customer_name="ABC Construction",  # Will match "ABC Construction Ltd"
            contact_name="John Guy",  # Will find John Guy contact
            equipment_names=["Rammer"],  # Equipment for quote
            hire_duration=3  # 3 days hire
        )
        
        if success:
            print("\n🎉 Quote request completed successfully!")
            print("\n📊 VERIFICATION QUERIES:")
            print("You can verify the data was created by running these SQL queries:")
            print("\n-- View the quote interaction:")
            print("SELECT id, reference_number, interaction_type, status, notes, created_at")
            print("FROM interactions WHERE interaction_type = 'quote' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View the equipment components:")
            print("SELECT i.reference_number, ec.category_name, cel.hire_duration, cel.hire_period_type, cel.special_requirements")
            print("FROM interactions i")
            print("JOIN component_equipment_list cel ON i.id = cel.interaction_id")
            print("JOIN equipment_categories ec ON cel.equipment_category_id = ec.id")
            print("WHERE i.interaction_type = 'quote' ORDER BY i.created_at DESC;")
            print("\n-- View the quote totals:")
            print("SELECT i.reference_number, qt.subtotal, qt.tax_rate, qt.tax_amount, qt.total_amount, qt.valid_until")
            print("FROM interactions i")
            print("JOIN component_quote_totals qt ON i.id = qt.interaction_id")
            print("WHERE i.interaction_type = 'quote' ORDER BY i.created_at DESC LIMIT 1;")
            print("\n-- View the quote task:")
            print("SELECT ut.id, ut.title, ut.task_type, ut.priority, ut.status, ut.due_date,")
            print("       e.name || ' ' || e.surname as assigned_to")
            print("FROM user_taskboard ut")
            print("JOIN employees e ON ut.assigned_to = e.id")
            print("WHERE ut.task_type = 'send_quote' ORDER BY ut.created_at DESC LIMIT 1;")
            print("\n-- View complete quote details:")
            print("SELECT ")
            print("    i.reference_number,")
            print("    c.customer_name,")
            print("    ct.first_name || ' ' || ct.last_name as contact_name,")
            print("    ec.category_name,")
            print("    cel.hire_duration,")
            print("    qt.subtotal,")
            print("    qt.tax_amount,")
            print("    qt.total_amount,")
            print("    qt.valid_until")
            print("FROM interactions i")
            print("JOIN customers c ON i.customer_id = c.id")
            print("JOIN contacts ct ON i.contact_id = ct.id")
            print("JOIN component_equipment_list cel ON i.id = cel.interaction_id")
            print("JOIN equipment_categories ec ON cel.equipment_category_id = ec.id")
            print("JOIN component_quote_totals qt ON i.id = qt.interaction_id")
            print("WHERE i.interaction_type = 'quote'")
            print("ORDER BY i.created_at DESC;")
        else:
            print("\n❌ Quote request failed - check error messages above")
    
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        processor.disconnect()


if __name__ == "__main__":
    main()