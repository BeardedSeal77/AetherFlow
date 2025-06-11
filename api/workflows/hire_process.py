#!/usr/bin/env python3
"""
Hire Process Handler
File: api/workflows/hire_process.py

This script handles the complete hire workflow process.
It serves as the layer between the NextJS frontend and the database.

The top section contains sample data variables that simulate frontend input.
The rest of the script processes this data as it would in production.
Later, the sample data can be replaced with actual frontend data.
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import json
from datetime import datetime, date, time
from typing import Dict, List, Optional, Any
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# =============================================================================
# SAMPLE DATA - Replace with frontend data in production
# =============================================================================

# Sample hire request data (would come from NextJS frontend)
SAMPLE_HIRE_REQUEST = {
    "customer": {
        "customer_id": 1000,  # ABC Construction Ltd
        "customer_name": "ABC Construction Ltd",
        "customer_code": "ABC001"
    },
    "contact": {
        "contact_id": 1000,  # John Guy
        "first_name": "John",
        "last_name": "Guy",
        "email": "john.guy@abcconstruction.co.za",
        "phone": "+27112345678"
    },
    "site": {
        "site_id": 1001,  # Sandton Office Development
        "site_name": "Sandton Office Development",
        "address": "123 Rivonia Road, Sandton, Johannesburg",
        "site_contact_name": "John Guy",
        "site_contact_phone": "+27112345678",
        "delivery_instructions": "Main entrance, ask for site foreman"
    },
    "equipment": [
        {
            "equipment_category_id": 5,
            "equipment_name": "Pedestrian Rammer",
            "equipment_code": "TE1000",
            "quantity": 1,
            "accessories": [
                {"accessory_id": 101, "accessory_name": "Safety Equipment", "quantity": 1, "is_default": True},
                {"accessory_id": 102, "accessory_name": "Fuel Can", "quantity": 1, "is_default": False}
            ]
        },
        {
            "equipment_category_id": 8,
            "equipment_name": "Plate Compactor",
            "equipment_code": "PC500",
            "quantity": 1,
            "accessories": [
                {"accessory_id": 103, "accessory_name": "Rubber Mat", "quantity": 1, "is_default": True}
            ]
        }
    ],
    "dates": {
        "hire_start_date": "2025-06-10",
        "delivery_date": "2025-06-10",
        "delivery_time": "09:00"
    },
    "notes": "Equipment needed for foundation work. Customer prefers morning delivery.",
    "employee_id": 1002  # Hire controller processing the request
}

# Database connection settings
DATABASE_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "database": "task_management",
    "user": "system_user",
    "password": "system_password"
}

# =============================================================================
# HIRE PROCESS HANDLER CLASS
# =============================================================================

class HireProcessHandler:
    """
    Handles the complete hire workflow process.
    Acts as the middleware between frontend and database.
    """
    
    def __init__(self, db_config: Dict[str, str]):
        self.db_config = db_config
        self.connection = None
        self.cursor = None
    
    def connect_to_database(self) -> bool:
        """Establish database connection"""
        try:
            self.connection = psycopg2.connect(**self.db_config)
            self.cursor = self.connection.cursor(cursor_factory=RealDictCursor)
            logger.info("✅ Database connection established")
            return True
        except psycopg2.Error as e:
            logger.error(f"❌ Database connection failed: {e}")
            return False
    
    def disconnect_from_database(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        logger.info("🔌 Database connection closed")
    
    def validate_hire_request(self, hire_request: Dict) -> Dict[str, Any]:
        """
        Validate hire request data before processing
        
        Args:
            hire_request: Complete hire request data
            
        Returns:
            Dict with validation results
        """
        validation_errors = []
        
        # Validate required customer data
        if not hire_request.get("customer", {}).get("customer_id"):
            validation_errors.append("Customer ID is required")
        
        # Validate required contact data
        if not hire_request.get("contact", {}).get("contact_id"):
            validation_errors.append("Contact ID is required")
        
        # Validate required site data
        if not hire_request.get("site", {}).get("site_id"):
            validation_errors.append("Site ID is required")
        
        # Validate equipment list
        equipment = hire_request.get("equipment", [])
        if not equipment:
            validation_errors.append("At least one equipment item is required")
        
        for i, item in enumerate(equipment):
            if not item.get("equipment_category_id"):
                validation_errors.append(f"Equipment item {i+1}: Category ID is required")
            if not item.get("quantity") or item.get("quantity") <= 0:
                validation_errors.append(f"Equipment item {i+1}: Valid quantity is required")
        
        # Validate dates
        dates = hire_request.get("dates", {})
        if not dates.get("hire_start_date"):
            validation_errors.append("Hire start date is required")
        if not dates.get("delivery_date"):
            validation_errors.append("Delivery date is required")
        
        # Validate employee
        if not hire_request.get("employee_id"):
            validation_errors.append("Employee ID is required")
        
        return {
            "is_valid": len(validation_errors) == 0,
            "errors": validation_errors
        }
    
    def verify_customer_exists(self, customer_id: int) -> Dict[str, Any]:
        """
        Verify customer exists and is active
        
        Args:
            customer_id: Customer ID to verify
            
        Returns:
            Dict with verification results
        """
        try:
            query = """
                SELECT id, customer_name, customer_code, status, credit_limit, payment_terms
                FROM core.customers 
                WHERE id = %s AND status = 'active'
            """
            self.cursor.execute(query, (customer_id,))
            customer = self.cursor.fetchone()
            
            if customer:
                return {
                    "exists": True,
                    "customer": dict(customer),
                    "message": f"Customer verified: {customer['customer_name']}"
                }
            else:
                return {
                    "exists": False,
                    "customer": None,
                    "message": "Customer not found or inactive"
                }
        except psycopg2.Error as e:
            logger.error(f"Error verifying customer: {e}")
            return {
                "exists": False,
                "customer": None,
                "message": f"Database error: {str(e)}"
            }
    
    def verify_contact_exists(self, contact_id: int, customer_id: int) -> Dict[str, Any]:
        """
        Verify contact exists and belongs to customer
        
        Args:
            contact_id: Contact ID to verify
            customer_id: Customer ID the contact should belong to
            
        Returns:
            Dict with verification results
        """
        try:
            query = """
                SELECT id, customer_id, first_name, last_name, email, phone_number, 
                       is_primary_contact, is_billing_contact, status
                FROM core.contacts 
                WHERE id = %s AND customer_id = %s AND status = 'active'
            """
            self.cursor.execute(query, (contact_id, customer_id))
            contact = self.cursor.fetchone()
            
            if contact:
                return {
                    "exists": True,
                    "contact": dict(contact),
                    "message": f"Contact verified: {contact['first_name']} {contact['last_name']}"
                }
            else:
                return {
                    "exists": False,
                    "contact": None,
                    "message": "Contact not found or doesn't belong to customer"
                }
        except psycopg2.Error as e:
            logger.error(f"Error verifying contact: {e}")
            return {
                "exists": False,
                "contact": None,
                "message": f"Database error: {str(e)}"
            }
    
    def verify_site_exists(self, site_id: int, customer_id: int) -> Dict[str, Any]:
        """
        Verify site exists and belongs to customer
        
        Args:
            site_id: Site ID to verify
            customer_id: Customer ID the site should belong to
            
        Returns:
            Dict with verification results
        """
        try:
            query = """
                SELECT id, customer_id, site_name, address_line1, address_line2, 
                       city, postal_code, site_type, site_contact_name, 
                       site_contact_phone, delivery_instructions, is_active
                FROM core.sites 
                WHERE id = %s AND customer_id = %s AND is_active = true
            """
            self.cursor.execute(query, (site_id, customer_id))
            site = self.cursor.fetchone()
            
            if site:
                return {
                    "exists": True,
                    "site": dict(site),
                    "message": f"Site verified: {site['site_name']}"
                }
            else:
                return {
                    "exists": False,
                    "site": None,
                    "message": "Site not found or doesn't belong to customer"
                }
        except psycopg2.Error as e:
            logger.error(f"Error verifying site: {e}")
            return {
                "exists": False,
                "site": None,
                "message": f"Database error: {str(e)}"
            }
    
    def verify_equipment_exists(self, equipment_list: List[Dict]) -> Dict[str, Any]:
        """
        Verify all equipment items exist and are active
        
        Args:
            equipment_list: List of equipment items to verify
            
        Returns:
            Dict with verification results
        """
        verified_equipment = []
        verification_errors = []
        
        try:
            for item in equipment_list:
                equipment_id = item.get("equipment_category_id")
                query = """
                    SELECT id, category_code, category_name, description, is_active
                    FROM core.equipment_categories 
                    WHERE id = %s AND is_active = true
                """
                self.cursor.execute(query, (equipment_id,))
                equipment = self.cursor.fetchone()
                
                if equipment:
                    verified_equipment.append({
                        "equipment": dict(equipment),
                        "quantity": item.get("quantity"),
                        "accessories": item.get("accessories", [])
                    })
                else:
                    verification_errors.append(f"Equipment ID {equipment_id} not found or inactive")
            
            return {
                "all_verified": len(verification_errors) == 0,
                "verified_equipment": verified_equipment,
                "errors": verification_errors,
                "message": f"Verified {len(verified_equipment)} equipment items"
            }
        except psycopg2.Error as e:
            logger.error(f"Error verifying equipment: {e}")
            return {
                "all_verified": False,
                "verified_equipment": [],
                "errors": [f"Database error: {str(e)}"],
                "message": "Equipment verification failed"
            }
    
    def authenticate_employee(self, employee_id: int) -> Dict[str, Any]:
        """
        Authenticate employee and get their details
        
        Args:
            employee_id: Employee ID to authenticate
            
        Returns:
            Dict with authentication results
        """
        try:
            query = """
                SELECT id, employee_code, name, surname, role, status
                FROM core.employees 
                WHERE id = %s AND status = 'active'
            """
            self.cursor.execute(query, (employee_id,))
            employee = self.cursor.fetchone()
            
            if employee:
                return {
                    "authenticated": True,
                    "employee": dict(employee),
                    "message": f"Employee authenticated: {employee['name']} {employee['surname']}"
                }
            else:
                return {
                    "authenticated": False,
                    "employee": None,
                    "message": "Employee not found or inactive"
                }
        except psycopg2.Error as e:
            logger.error(f"Error authenticating employee: {e}")
            return {
                "authenticated": False,
                "employee": None,
                "message": f"Database error: {str(e)}"
            }
    
    def create_hire_interaction(self, hire_request: Dict, verified_data: Dict) -> Dict[str, Any]:
        """
        Create the hire interaction and driver task
        
        Args:
            hire_request: Original hire request data
            verified_data: All verified data from validation steps
            
        Returns:
            Dict with creation results
        """
        try:
            # Generate reference number
            reference_number = self.generate_reference_number('hire')
            
            # Create interaction record
            interaction_query = """
                INSERT INTO interactions.interactions (
                    customer_id, contact_id, employee_id, interaction_type,
                    status, reference_number, contact_method, notes, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) 
                RETURNING id
            """
            
            interaction_values = (
                hire_request["customer"]["customer_id"],
                hire_request["contact"]["contact_id"],
                hire_request["employee_id"],
                'hire',
                'new',
                reference_number,
                'phone',  # Default contact method
                hire_request.get("notes", ""),
                datetime.now()
            )
            
            self.cursor.execute(interaction_query, interaction_values)
            interaction_id = self.cursor.fetchone()['id']
            
            logger.info(f"✅ Created interaction {reference_number} (ID: {interaction_id})")
            
            # Create driver task
            task_result = self.create_driver_task(
                interaction_id, 
                reference_number, 
                hire_request, 
                verified_data
            )
            
            if task_result["success"]:
                # Commit the transaction
                self.connection.commit()
                
                return {
                    "success": True,
                    "interaction_id": interaction_id,
                    "reference_number": reference_number,
                    "driver_task_id": task_result["task_id"],
                    "message": f"Hire {reference_number} created successfully"
                }
            else:
                # Rollback if driver task creation failed
                self.connection.rollback()
                return {
                    "success": False,
                    "message": f"Driver task creation failed: {task_result['message']}"
                }
                
        except psycopg2.Error as e:
            self.connection.rollback()
            logger.error(f"Error creating hire interaction: {e}")
            return {
                "success": False,
                "message": f"Database error: {str(e)}"
            }
    
    def create_driver_task(self, interaction_id: int, reference_number: str, 
                          hire_request: Dict, verified_data: Dict) -> Dict[str, Any]:
        """
        Create driver delivery task for the hire
        
        Args:
            interaction_id: ID of the created interaction
            reference_number: Reference number for the hire
            hire_request: Original hire request data
            verified_data: All verified data
            
        Returns:
            Dict with task creation results
        """
        try:
            # Build equipment summary
            equipment_summary = ", ".join([
                f"{item['equipment']['category_name']} (Qty: {item['quantity']})"
                for item in verified_data['equipment']['verified_equipment']
            ])
            
            # Build full address
            site = verified_data['site']['site']
            full_address = site['address_line1']
            if site.get('address_line2'):
                full_address += f", {site['address_line2']}"
            full_address += f", {site['city']}"
            
            # Create driver task
            task_query = """
                INSERT INTO tasks.drivers_taskboard (
                    interaction_id, created_by, task_type, priority, status,
                    scheduled_date, scheduled_time, estimated_duration,
                    customer_name, contact_name, contact_phone, site_address,
                    equipment_summary, special_instructions, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """
            
            contact = verified_data['contact']['contact']
            contact_name = f"{contact['first_name']} {contact['last_name']}"
            
            task_values = (
                interaction_id,
                hire_request["employee_id"],
                'delivery',
                'medium',  # Default priority
                'backlog',  # Starts unassigned
                hire_request["dates"]["delivery_date"],
                hire_request["dates"]["delivery_time"],
                90,  # 90 minutes estimated duration
                hire_request["customer"]["customer_name"],
                contact_name,
                contact.get('phone_number', ''),
                full_address,
                equipment_summary,
                hire_request.get("notes", ""),
                datetime.now()
            )
            
            self.cursor.execute(task_query, task_values)
            task_id = self.cursor.fetchone()['id']
            
            logger.info(f"✅ Created driver task (ID: {task_id})")
            
            return {
                "success": True,
                "task_id": task_id,
                "message": f"Driver delivery task created"
            }
            
        except psycopg2.Error as e:
            logger.error(f"Error creating driver task: {e}")
            return {
                "success": False,
                "task_id": None,
                "message": f"Database error: {str(e)}"
            }
    
    def generate_reference_number(self, interaction_type: str) -> str:
        """
        Generate reference number for interaction
        
        Args:
            interaction_type: Type of interaction (hire, off_hire, etc.)
            
        Returns:
            Generated reference number
        """
        try:
            # Get prefix
            self.cursor.execute("SELECT get_prefix_for_interaction(%s)", (interaction_type,))
            prefix_result = self.cursor.fetchone()
            prefix = list(prefix_result.values())[0] if prefix_result else 'HR'
            
            # Get date part
            date_part = datetime.now().strftime('%y%m%d')
            
            # Get sequence
            self.cursor.execute("SELECT get_next_sequence_for_date(%s, %s)", (prefix, date_part))
            seq_result = self.cursor.fetchone()
            sequence = list(seq_result.values())[0] if seq_result else 1
            
            reference = f"{prefix}{date_part}{sequence:03d}"
            logger.info(f"📝 Generated reference number: {reference}")
            return reference
            
        except Exception as e:
            logger.warning(f"Reference generation failed, using fallback: {e}")
            # Fallback reference generation
            date_part = datetime.now().strftime('%y%m%d')
            return f"HR{date_part}001"
    
    def process_hire_request(self, hire_request: Dict) -> Dict[str, Any]:
        """
        Main method to process complete hire request
        
        Args:
            hire_request: Complete hire request data from frontend
            
        Returns:
            Dict with processing results
        """
        logger.info("🎯 Starting hire request processing")
        
        # Step 1: Validate request data
        logger.info("📋 Step 1: Validating hire request data")
        validation = self.validate_hire_request(hire_request)
        if not validation["is_valid"]:
            return {
                "success": False,
                "stage": "validation",
                "message": "Request validation failed",
                "errors": validation["errors"]
            }
        logger.info("✅ Request validation passed")
        
        # Step 2: Verify customer
        logger.info("👤 Step 2: Verifying customer")
        customer_verification = self.verify_customer_exists(hire_request["customer"]["customer_id"])
        if not customer_verification["exists"]:
            return {
                "success": False,
                "stage": "customer_verification",
                "message": customer_verification["message"]
            }
        logger.info(f"✅ {customer_verification['message']}")
        
        # Step 3: Verify contact
        logger.info("📞 Step 3: Verifying contact")
        contact_verification = self.verify_contact_exists(
            hire_request["contact"]["contact_id"],
            hire_request["customer"]["customer_id"]
        )
        if not contact_verification["exists"]:
            return {
                "success": False,
                "stage": "contact_verification",
                "message": contact_verification["message"]
            }
        logger.info(f"✅ {contact_verification['message']}")
        
        # Step 4: Verify site
        logger.info("🏢 Step 4: Verifying site")
        site_verification = self.verify_site_exists(
            hire_request["site"]["site_id"],
            hire_request["customer"]["customer_id"]
        )
        if not site_verification["exists"]:
            return {
                "success": False,
                "stage": "site_verification",
                "message": site_verification["message"]
            }
        logger.info(f"✅ {site_verification['message']}")
        
        # Step 5: Verify equipment
        logger.info("🔧 Step 5: Verifying equipment")
        equipment_verification = self.verify_equipment_exists(hire_request["equipment"])
        if not equipment_verification["all_verified"]:
            return {
                "success": False,
                "stage": "equipment_verification",
                "message": "Equipment verification failed",
                "errors": equipment_verification["errors"]
            }
        logger.info(f"✅ {equipment_verification['message']}")
        
        # Step 6: Authenticate employee
        logger.info("🔐 Step 6: Authenticating employee")
        employee_auth = self.authenticate_employee(hire_request["employee_id"])
        if not employee_auth["authenticated"]:
            return {
                "success": False,
                "stage": "employee_authentication",
                "message": employee_auth["message"]
            }
        logger.info(f"✅ {employee_auth['message']}")
        
        # Step 7: Create hire interaction and driver task
        logger.info("💾 Step 7: Creating hire interaction and driver task")
        verified_data = {
            "customer": customer_verification,
            "contact": contact_verification,
            "site": site_verification,
            "equipment": equipment_verification,
            "employee": employee_auth
        }
        
        creation_result = self.create_hire_interaction(hire_request, verified_data)
        
        if creation_result["success"]:
            logger.info(f"🎉 Hire request processed successfully: {creation_result['reference_number']}")
            return {
                "success": True,
                "stage": "completed",
                "interaction_id": creation_result["interaction_id"],
                "reference_number": creation_result["reference_number"],
                "driver_task_id": creation_result["driver_task_id"],
                "message": creation_result["message"]
            }
        else:
            logger.error(f"❌ Hire creation failed: {creation_result['message']}")
            return {
                "success": False,
                "stage": "creation",
                "message": creation_result["message"]
            }

# =============================================================================
# MAIN EXECUTION
# =============================================================================

def main():
    """
    Main execution function
    In production, this would be called by FastAPI/Flask with frontend data
    """
    print("🎯 HIRE PROCESS - Equipment Hire Request Processing")
    print("=" * 60)
    print(f"📝 Processing hire request for: {SAMPLE_HIRE_REQUEST['customer']['customer_name']}")
    print(f"👤 Contact: {SAMPLE_HIRE_REQUEST['contact']['first_name']} {SAMPLE_HIRE_REQUEST['contact']['last_name']}")
    print(f"🏢 Site: {SAMPLE_HIRE_REQUEST['site']['site_name']}")
    print(f"📅 Delivery: {SAMPLE_HIRE_REQUEST['dates']['delivery_date']} at {SAMPLE_HIRE_REQUEST['dates']['delivery_time']}")
    print(f"🔧 Equipment: {len(SAMPLE_HIRE_REQUEST['equipment'])} items")
    print("=" * 60)
    
    # Initialize hire processor
    processor = HireProcessHandler(DATABASE_CONFIG)
    
    try:
        # Connect to database
        if not processor.connect_to_database():
            print("❌ Cannot proceed without database connection")
            return
        
        # Process the hire request
        result = processor.process_hire_request(SAMPLE_HIRE_REQUEST)
        
        # Display results
        print("\n" + "=" * 60)
        print("PROCESSING RESULTS:")
        print("=" * 60)
        
        if result["success"]:
            print(f"✅ SUCCESS: {result['message']}")
            print(f"📝 Reference Number: {result['reference_number']}")
            print(f"🆔 Interaction ID: {result['interaction_id']}")
            print(f"🚛 Driver Task ID: {result['driver_task_id']}")
            print("\n📊 You can verify this in the database:")
            print(f"   SELECT * FROM interactions.interactions WHERE reference_number = '{result['reference_number']}';")
            print(f"   SELECT * FROM tasks.drivers_taskboard WHERE interaction_id = {result['interaction_id']};")
        else:
            print(f"❌ FAILED at {result.get('stage', 'unknown')} stage")
            print(f"💬 Message: {result['message']}")
            if 'errors' in result:
                print("🔍 Errors:")
                for error in result['errors']:
                    print(f"   - {error}")
        
        print("=" * 60)
        
    except Exception as e:
        print(f"💥 Unexpected error: {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        processor.disconnect_from_database()

if __name__ == "__main__":
    main()