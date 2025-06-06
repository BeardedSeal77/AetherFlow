#!/usr/bin/env python3
"""
Database Test Script: Breakdown Task Creation
============================================

Test Scenario: John Guy from ABC Construction Ltd reports a TE1000 Breaker breakdown
at Sandton Office Development site - URGENT - driver needed within the hour

This script simulates the complete breakdown process:
1. Create breakdown interaction record (Layer 1)
2. Store breakdown components (Layer 2) 
3. Create urgent driver taskboard entry (Layer 3)
4. Create equipment assignments for the driver task

Database Connection: PostgreSQL container on localhost:5432
"""

import psycopg2
import psycopg2.extras
from datetime import datetime, date, time, timedelta
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

class BreakdownTaskProcessor:
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
    
    def get_customer_by_id(self, customer_id: int) -> Optional[Dict]:
        """Get customer by ID"""
        try:
            query = "SELECT * FROM customers WHERE id = %s AND status = 'active'"
            self.cursor.execute(query, (customer_id,))
            customer = self.cursor.fetchone()
            
            if customer:
                print(f"✅ Found customer: {customer['customer_name']} (ID: {customer['id']})")
                return dict(customer)
            else:
                print(f"❌ Customer ID {customer_id} not found or inactive")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding customer: {e}")
            return None
    
    def get_contact_by_id(self, contact_id: int) -> Optional[Dict]:
        """Get contact by ID"""
        try:
            query = "SELECT * FROM contacts WHERE id = %s AND status = 'active'"
            self.cursor.execute(query, (contact_id,))
            contact = self.cursor.fetchone()
            
            if contact:
                contact_name = f"{contact['first_name']} {contact['last_name']}"
                print(f"✅ Found contact: {contact_name} (ID: {contact['id']})")
                return dict(contact)
            else:
                print(f"❌ Contact ID {contact_id} not found or inactive")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding contact: {e}")
            return None
    
    def get_site_by_name(self, customer_id: int, site_name: str) -> Optional[Dict]:
        """Get site by name for specific customer"""
        try:
            query = """
                SELECT * FROM sites 
                WHERE customer_id = %s 
                AND LOWER(site_name) LIKE LOWER(%s)
                AND is_active = true
                ORDER BY site_name
                LIMIT 1
            """
            self.cursor.execute(query, (customer_id, f'%{site_name}%'))
            site = self.cursor.fetchone()
            
            if site:
                print(f"✅ Found site: {site['site_name']} (ID: {site['id']})")
                print(f"   Address: {site['address_line1']}, {site['city']}")
                return dict(site)
            else:
                print(f"❌ Site '{site_name}' not found for customer {customer_id}")
                return None
                
        except psycopg2.Error as e:
            print(f"❌ Error finding site: {e}")
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
            
            print(f"✅ Found {len(equipment_list)} broken equipment items:")
            for eq in equipment_list:
                print(f"   - {eq['category_name']} ({eq['category_code']}) ⚠️ BROKEN")
            
            return [dict(eq) for eq in equipment_list]
            
        except psycopg2.Error as e:
            print(f"❌ Error finding equipment: {e}")
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
                # Test if the function exists
                self.cursor.execute("SELECT get_prefix_for_interaction('breakdown')")
                test_result = self.cursor.fetchone()
            except psycopg2.Error as func_error:
                print(f"⚠️ Helper functions not available: {func_error}")
                # Fall back to manual method
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
                prefix = 'BD'  # Fallback for breakdown
            
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
            print(f"   Format: {prefix}(prefix) + {date_part}(date) + {sequence:03d}(sequence)")
            return reference
            
        except Exception as e:
            print(f"❌ Error generating reference number: {e}")
            return self.generate_reference_number_manual(interaction_type)
    
    def generate_reference_number_manual(self, interaction_type: str) -> str:
        """Manual reference number generation as fallback"""
        try:
            prefix_map = {
                'breakdown': 'BD',
                'hire': 'HR',
                'off_hire': 'OH',
                'order': 'OR',
                'quote': 'QT',
                'price_list': 'PL',
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
            fallback = f"BD{today}001"
            print(f"🆘 Using ultimate fallback: {fallback}")
            return fallback
    
    def create_breakdown_interaction(self, customer: Dict, contact: Dict, employee: Dict, 
                                   issue_description: str) -> Optional[int]:
        """Create the main breakdown interaction record (Layer 1)"""
        try:
            reference_number = self.generate_reference_number('breakdown')
            
            insert_query = """
                INSERT INTO interactions (
                    customer_id, contact_id, employee_id, interaction_type, 
                    status, reference_number, contact_method, notes, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """
            
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            notes = f"URGENT BREAKDOWN: {contact_name} at {customer['customer_name']} reports equipment breakdown at Sandton site. Issue: {issue_description}. Driver needed within the hour."
            
            values = (
                customer['id'],
                contact['id'], 
                employee['id'],
                'breakdown',
                'pending',
                reference_number,
                'phone',  # Urgent call
                notes,
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            interaction_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created URGENT breakdown interaction (ID: {interaction_id}, Ref: {reference_number})")
            return interaction_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating breakdown interaction: {e}")
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
                    1,  # Quantity
                    f"BREAKDOWN - {equipment['category_name']} requires immediate repair or replacement"
                )
                self.cursor.execute(insert_query, values)
            
            print(f"✅ Created {len(equipment_list)} breakdown equipment component records")
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error creating equipment list components: {e}")
            return False
    
    def create_breakdown_details_component(self, interaction_id: int, site: Dict, issue_description: str, 
                                         resolution_type: str = 'swap') -> bool:
        """Create breakdown details component record (Layer 2)"""
        try:
            breakdown_time = datetime.now()
            
            insert_query = """
                INSERT INTO component_breakdown_details (
                    interaction_id, site_id, breakdown_date, breakdown_time,
                    resolution_type, urgency, issue_description, equipment_condition
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            values = (
                interaction_id,
                site['id'],
                breakdown_time.date(),
                breakdown_time.time(),
                resolution_type,  # 'swap' or 'repair'
                'critical',  # High urgency - within the hour
                issue_description,
                'Non-operational - requires immediate attention'
            )
            
            self.cursor.execute(insert_query, values)
            print(f"✅ Created breakdown details component - CRITICAL urgency, {resolution_type} required")
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error creating breakdown details component: {e}")
            return False
    
    def create_drivers_taskboard_entry(self, interaction_id: int, customer: Dict, contact: Dict, 
                                     site: Dict, equipment_list: List[Dict], created_by: Dict,
                                     issue_description: str) -> Optional[int]:
        """Create URGENT drivers taskboard entry (Layer 3)"""
        try:
            # URGENT - schedule for immediate dispatch (within 30 minutes)
            urgent_time = datetime.now() + timedelta(minutes=30)
            scheduled_date = urgent_time.date()
            scheduled_time = urgent_time.time()
            
            # Format contact info
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            site_address = f"{site['address_line1']}"
            if site['address_line2']:
                site_address += f", {site['address_line2']}"
            site_address += f", {site['city']}"
            
            # Equipment summary
            equipment_summary = ", ".join([eq['category_name'] + " (BROKEN)" for eq in equipment_list])
            
            insert_query = """
                INSERT INTO drivers_taskboard (
                    interaction_id, created_by, task_type, priority, status,
                    scheduled_date, scheduled_time, estimated_duration,
                    customer_name, contact_name, contact_phone, contact_whatsapp,
                    site_address, site_delivery_instructions,
                    status_booked, status_driver, status_quality_control, status_whatsapp,
                    equipment_summary, equipment_verified, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) RETURNING id
            """
            
            values = (
                interaction_id,
                created_by['id'],
                'repair',  # Task type is repair for breakdown
                'urgent',  # CRITICAL priority
                'backlog',  # Starts in backlog but should be assigned immediately
                scheduled_date,
                scheduled_time,
                45,  # 45 minutes estimated duration for emergency response
                customer['customer_name'],
                contact_name,
                contact.get('phone_number'),
                contact.get('whatsapp_number'),
                site_address,
                f"🚨 URGENT BREAKDOWN: {issue_description}. Immediate response required. {site.get('delivery_instructions', 'Standard access')}",
                'yes',  # Immediately booked due to urgency
                'no',   # No driver assigned yet - needs immediate assignment
                'no',   # Quality control not done yet
                'no',   # WhatsApp notification not sent yet
                equipment_summary,
                False,  # Equipment not verified yet
                datetime.now()
            )
            
            self.cursor.execute(insert_query, values)
            drivers_task_id = self.cursor.fetchone()['id']
            
            print(f"✅ Created URGENT drivers taskboard entry (ID: {drivers_task_id})")
            print(f"   🚨 CRITICAL BREAKDOWN at {customer['customer_name']}")
            print(f"   ⚡ Immediate dispatch required: {scheduled_date} at {scheduled_time}")
            print(f"   🔧 Equipment: {equipment_summary}")
            print(f"   📞 Contact: {contact_name} - {contact.get('phone_number', 'N/A')}")
            
            return drivers_task_id
            
        except psycopg2.Error as e:
            print(f"❌ Error creating drivers taskboard entry: {e}")
            return None
    
    def create_driver_task_equipment(self, drivers_task_id: int, equipment_list: List[Dict]) -> bool:
        """Create driver task equipment assignments for breakdown"""
        try:
            insert_query = """
                INSERT INTO drivers_task_equipment (
                    drivers_task_id, equipment_category_id, quantity, 
                    purpose, condition_notes, verified
                ) VALUES (%s, %s, %s, %s, %s, %s)
            """
            
            for equipment in equipment_list:
                values = (
                    drivers_task_id,
                    equipment['id'],
                    1,  # Quantity
                    'swap_out',  # Purpose is to swap out broken equipment
                    f"BREAKDOWN: {equipment['category_name']} is non-operational and requires immediate replacement or repair",
                    False  # Not verified yet
                )
                self.cursor.execute(insert_query, values)
                
                # Also add the replacement equipment
                replacement_values = (
                    drivers_task_id,
                    equipment['id'],
                    1,  # Quantity
                    'swap_in',  # Purpose is to swap in working equipment
                    f"REPLACEMENT: Working {equipment['category_name']} to replace broken unit",
                    False  # Not verified yet
                )
                self.cursor.execute(insert_query, replacement_values)
            
            print(f"✅ Created {len(equipment_list) * 2} driver task equipment assignments (broken + replacements)")
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error creating driver task equipment: {e}")
            return False
    
    def process_breakdown_request(self, customer_id: int, contact_id: int, site_name: str, 
                                equipment_names: List[str], issue_description: str):
        """Main method to process the complete breakdown request"""
        print("\n🚨 STARTING URGENT BREAKDOWN REQUEST PROCESS")
        print("=" * 60)
        print(f"🚨 CRITICAL PRIORITY - DRIVER NEEDED WITHIN THE HOUR")
        print(f"Customer ID: {customer_id}")
        print(f"Contact ID: {contact_id}")
        print(f"Site: {site_name}")
        print(f"Broken Equipment: {', '.join(equipment_names)}")
        print(f"Issue: {issue_description}")
        print("=" * 60)
        
        # Step 1: Get customer, contact, and site data
        print("\n📋 STEP 1: Data Verification")
        customer = self.get_customer_by_id(customer_id)
        if not customer:
            print("❌ Process terminated: Customer not found")
            return False
        
        contact = self.get_contact_by_id(contact_id)
        if not contact:
            print("❌ Process terminated: Contact not found")
            return False
        
        site = self.get_site_by_name(customer_id, site_name)
        if not site:
            print("❌ Process terminated: Site not found")
            return False
        
        equipment_list = self.get_equipment_by_names(equipment_names)
        if not equipment_list:
            print("❌ Process terminated: No equipment found")
            return False
        
        # Step 2: Get hire controller (who processes the request)
        print("\n👤 STEP 2: Employee Assignment")
        employee = self.get_employee_by_role('hire_control')
        if not employee:
            print("❌ Process terminated: No hire controller available")
            return False
        
        # Step 3: Create breakdown interaction (Layer 1)
        print("\n📝 STEP 3: Creating URGENT Breakdown Interaction (Layer 1)")
        interaction_id = self.create_breakdown_interaction(customer, contact, employee, issue_description)
        if not interaction_id:
            print("❌ Process terminated: Failed to create interaction")
            return False
        
        # Step 4: Create equipment list components (Layer 2)
        print("\n📦 STEP 4: Creating Equipment Components (Layer 2)")
        if not self.create_equipment_list_components(interaction_id, equipment_list):
            print("❌ Warning: Failed to create equipment components")
        
        # Step 5: Create breakdown details component (Layer 2)
        print("\n🔧 STEP 5: Creating Breakdown Details Component (Layer 2)")
        if not self.create_breakdown_details_component(interaction_id, site, issue_description, 'swap'):
            print("❌ Warning: Failed to create breakdown details")
        
        # Step 6: Create URGENT drivers taskboard entry (Layer 3)
        print("\n🚛 STEP 6: Creating URGENT Driver Task (Layer 3)")
        drivers_task_id = self.create_drivers_taskboard_entry(
            interaction_id, customer, contact, site, equipment_list, employee, issue_description
        )
        if not drivers_task_id:
            print("❌ Warning: Failed to create driver task")
            return False
        
        # Step 7: Create driver task equipment assignments
        print("\n🔧 STEP 7: Creating Equipment Assignments")
        if not self.create_driver_task_equipment(drivers_task_id, equipment_list):
            print("❌ Warning: Failed to create equipment assignments")
        
        # Commit all changes
        try:
            self.conn.commit()
            print("\n✅ URGENT BREAKDOWN PROCESS COMPLETED")
            print(f"✅ All database changes committed")
            print(f"✅ Interaction ID: {interaction_id}")
            print(f"✅ Driver Task ID: {drivers_task_id}")
            
            # Display the created task
            self.display_created_driver_task(drivers_task_id)
            
            return True
            
        except psycopg2.Error as e:
            print(f"❌ Error committing changes: {e}")
            self.conn.rollback()
            return False
    
    def display_created_driver_task(self, drivers_task_id: int):
        """Display the created driver task details"""
        try:
            query = """
                SELECT 
                    dt.*,
                    i.reference_number,
                    STRING_AGG(ec.category_name, ', ') as equipment_names
                FROM drivers_taskboard dt
                JOIN interactions i ON dt.interaction_id = i.id
                LEFT JOIN drivers_task_equipment dte ON dt.id = dte.drivers_task_id
                LEFT JOIN equipment_categories ec ON dte.equipment_category_id = ec.id
                WHERE dt.id = %s
                GROUP BY dt.id, i.reference_number
            """
            
            self.cursor.execute(query, (drivers_task_id,))
            task = self.cursor.fetchone()
            
            if task:
                print("\n" + "="*60)
                print("🚨 URGENT BREAKDOWN DRIVER TASK DETAILS:")
                print("="*60)
                print(f"Task ID: {task['id']}")
                print(f"Reference: {task['reference_number']}")
                print(f"Task Type: {task['task_type'].upper()} 🔧")
                print(f"Priority: {task['priority'].upper()} 🚨")
                print(f"Customer: {task['customer_name']}")
                print(f"Contact: {task['contact_name']}")
                print(f"Phone: {task['contact_phone']} 📞")
                print(f"WhatsApp: {task['contact_whatsapp']} 📱")
                print(f"Breakdown Site: {task['site_address']}")
                print(f"Equipment Issue: {task['equipment_names']}")
                print(f"Scheduled Response: {task['scheduled_date']} at {task['scheduled_time']} ⚡")
                print(f"Estimated Duration: {task['estimated_duration']} minutes")
                print(f"Status: {task['status']}")
                print(f"Special Instructions: {task['site_delivery_instructions']}")
                print(f"Progress Indicators:")
                print(f"  📅 Booked: {task['status_booked']}")
                print(f"  🚛 Driver: {task['status_driver']} ⚠️ NEEDS IMMEDIATE ASSIGNMENT")
                print(f"  ✅ Quality Control: {task['status_quality_control']}")
                print(f"  📱 WhatsApp: {task['status_whatsapp']}")
                print(f"Equipment Verified: {task['equipment_verified']}")
                print("="*60)
                print("🚨 ACTION REQUIRED: Assign driver immediately for emergency response!")
                print("="*60)
                
        except psycopg2.Error as e:
            print(f"❌ Error displaying task details: {e}")


def main():
    """Main execution function"""
    print("🚨 TASK MANAGEMENT SYSTEM - EMERGENCY BREAKDOWN TASK CREATION")
    print("📋 Scenario: John Guy reports URGENT TE1000 Breaker breakdown")
    print("🏗️ Location: Sandton Office Development")
    print("⚡ Priority: CRITICAL - Driver needed within the hour")
    print("🗄️ Database: task_management @ localhost:5432")
    
    processor = BreakdownTaskProcessor()
    
    try:
        # Connect to database
        if not processor.connect():
            return
        
        # Process the urgent breakdown request
        success = processor.process_breakdown_request(
            customer_id=1,  # ABC Construction Ltd
            contact_id=1,   # John Guy
            site_name="sandton",  # Will match "Sandton Office Development"
            equipment_names=["T1000 Breaker"],  # Broken equipment
            issue_description="TE1000 Breaker stopped working mid-operation, no power, blocking critical work"
        )
        
        if success:
            print("\n🎉 Emergency breakdown process completed successfully!")
            print("\n📊 VERIFICATION QUERIES:")
            print("You can verify the data was created by running these SQL queries:")
            print("\n-- View the breakdown interaction:")
            print("SELECT id, reference_number, interaction_type, status, notes, created_at")
            print("FROM interactions WHERE interaction_type = 'breakdown' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View the urgent repair task:")
            print("SELECT id, customer_name, task_type, priority, equipment_summary, status, scheduled_date")
            print("FROM drivers_taskboard WHERE task_type = 'repair' ORDER BY created_at DESC LIMIT 1;")
            print("\n-- View breakdown details:")
            print("SELECT i.reference_number, bd.breakdown_date, bd.breakdown_time, bd.urgency, bd.issue_description, s.site_name")
            print("FROM interactions i")
            print("JOIN component_breakdown_details bd ON i.id = bd.interaction_id")
            print("JOIN sites s ON bd.site_id = s.id")
            print("WHERE i.interaction_type = 'breakdown' ORDER BY i.created_at DESC LIMIT 1;")
            print("\n-- View urgent tasks requiring immediate attention:")
            print("SELECT task_type, priority, COUNT(*) as urgent_tasks")
            print("FROM drivers_taskboard")
            print("WHERE priority = 'urgent' AND status IN ('backlog', 'driver_1', 'driver_2', 'driver_3', 'driver_4')")
            print("GROUP BY task_type, priority ORDER BY urgent_tasks DESC;")
        else:
            print("\n❌ Emergency breakdown process failed - check error messages above")
    
    except Exception as e:
        print(f"\n💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        processor.disconnect()


if __name__ == "__main__":
    main()