#!/usr/bin/env python3
"""
Hire Process Handler - Updated for Fixed create_hire Procedure
File: api/workflows/hire_process.py

This script handles the complete hire workflow process.
It serves as the layer between the NextJS frontend and the database.

Updated to work with the fixed create_hire procedure that properly implements
the 3-layer architecture (interactions → components → driver tasks).
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
# SAMPLE DATA - Updated to match your provided sample data
# =============================================================================

# Sample hire request data (using your provided sample data)
SAMPLE_HIRE_REQUEST = {
    "customer": {
        "customer_id": 1,  # ABC Construction Ltd (your sample)
        "customer_name": "ABC Construction Ltd",
        "customer_code": "ABC001"
    },
    "contact": {
        "contact_id": 1,  # John Guy (your sample)
        "first_name": "John",
        "last_name": "Guy",
        "email": "john.guy@abcconstruction.com",
        "phone": "+27111234567"
    },
    "site": {
        "site_id": 2,  # Sandton Project Site (your sample)
        "site_name": "Sandton Project Site",
        "address": "45 Sandton Drive, Sandton, Gauteng, 2196",
        "site_contact_name": "Site Foreman",
        "site_contact_phone": "+27111234570",
        "delivery_instructions": "Deliver to main gate, ask for foreman"
    },
    "equipment": [
        {
            "equipment_category_id": 1,  # Rammer (your sample)
            "equipment_name": "Rammer",
            "equipment_code": "RAM001",
            "quantity": 1,
            "accessories": [
                {"accessory_id": 1, "accessory_name": "2L Petrol", "quantity": 1, "is_default": True}
            ]
        },
        {
            "equipment_category_id": 2,  # T1000 Breaker (your sample)
            "equipment_name": "T1000 Breaker", 
            "equipment_code": "BRK001",
            "quantity": 1,
            "accessories": [
                {"accessory_id": 2, "accessory_name": "Spade Chisel", "quantity": 1, "is_default": True},
                {"accessory_id": 3, "accessory_name": "Moil Chisel", "quantity": 1, "is_default": True}
            ]
        }
    ],
    "dates": {
        "hire_start_date": "2025-06-13",
        "delivery_date": "2025-06-13", 
        "delivery_time": "09:00"
    },
    "notes": "Equipment needed for foundation work. Customer prefers morning delivery.",
    "priority": "medium",
    "employee_id": 5  # John Controller (your sample)
}

# Database connection settings - Updated for Docker setup
DATABASE_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "database": "task_management",
    "user": "SYSTEM",        # Updated to match your Docker setup
    "password": "SYSTEM"     # Updated to match your Docker setup
}

# =============================================================================
# HIRE PROCESS HANDLER CLASS
# =============================================================================

class HireProcessHandler:
    """
    Handles the complete hire workflow process.
    Acts as the middleware between frontend and database.
    Updated to work with the fixed create_hire procedure.
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
            
        # Validate employee ID
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
                SELECT id, customer_code, customer_name, is_company, status, 
                       credit_limit, payment_terms
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
                SELECT id, customer_id, first_name, last_name, job_title, 
                       email, phone_number, is_primary_contact, status
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
        Verify all equipment categories exist and are active
        
        Args:
            equipment_list: List of equipment items to verify
            
        Returns:
            Dict with verification results
        """
        try:
            equipment_ids = [item["equipment_category_id"] for item in equipment_list]
            
            # Query all equipment categories at once
            query = """
                SELECT id, category_code, category_name, description, is_active
                FROM core.equipment_categories 
                WHERE id = ANY(%s) AND is_active = true
            """
            self.cursor.execute(query, (equipment_ids,))
            found_equipment = {eq['id']: dict(eq) for eq in self.cursor.fetchall()}
            
            # Check if all requested equipment was found
            missing_equipment = []
            verified_equipment = []
            
            for item in equipment_list:
                eq_id = item["equipment_category_id"]
                if eq_id in found_equipment:
                    verified_equipment.append({
                        **found_equipment[eq_id],
                        "quantity": item["quantity"]
                    })
                else:
                    missing_equipment.append(eq_id)
            
            if missing_equipment:
                return {
                    "exists": False,
                    "equipment": None,
                    "message": f"Equipment categories not found: {missing_equipment}"
                }
            else:
                return {
                    "exists": True,
                    "equipment": verified_equipment,
                    "message": f"All {len(verified_equipment)} equipment categories verified"
                }
                
        except psycopg2.Error as e:
            logger.error(f"Error verifying equipment: {e}")
            return {
                "exists": False,
                "equipment": None,
                "message": f"Database error: {str(e)}"
            }
    
    def call_create_hire_procedure(self, hire_request: Dict) -> Dict[str, Any]:
        """
        Call the fixed create_hire database procedure
        
        Args:
            hire_request: Complete hire request data
            
        Returns:
            Dict with procedure results
        """
        try:
            # Prepare equipment list as JSONB
            equipment_list = []
            for item in hire_request["equipment"]:
                equipment_list.append({
                    "equipment_category_id": item["equipment_category_id"],
                    "quantity": item["quantity"]
                })
            
            # Convert dates
            hire_start_date = hire_request["dates"]["hire_start_date"]
            delivery_date = hire_request["dates"]["delivery_date"] 
            delivery_time = hire_request["dates"]["delivery_time"]
            
            # Call the fixed create_hire procedure
            query = """
                SELECT * FROM interactions.create_hire(
                    p_customer_id := %s,
                    p_contact_id := %s,
                    p_site_id := %s,
                    p_equipment_list := %s::jsonb,
                    p_hire_start_date := %s,
                    p_delivery_date := %s,
                    p_delivery_time := %s::time,
                    p_notes := %s,
                    p_priority := %s,
                    p_employee_id := %s
                )
            """
            
            self.cursor.execute(query, (
                hire_request["customer"]["customer_id"],
                hire_request["contact"]["contact_id"],
                hire_request["site"]["site_id"],
                json.dumps(equipment_list),
                hire_start_date,
                delivery_date,
                delivery_time,
                hire_request.get("notes"),
                hire_request.get("priority", "medium"),
                hire_request.get("employee_id", 1)
            ))
            
            result = self.cursor.fetchone()
            
            if result:
                result_dict = dict(result)
                
                if result_dict.get("success"):
                    # Commit the transaction
                    self.connection.commit()
                    logger.info(f"✅ Hire created successfully: {result_dict.get('reference_number')}")
                    return {
                        "success": True,
                        "interaction_id": result_dict.get("interaction_id"),
                        "reference_number": result_dict.get("reference_number"),
                        "driver_task_id": result_dict.get("driver_task_id"),
                        "assigned_driver_name": result_dict.get("assigned_driver_name"),
                        "equipment_count": result_dict.get("equipment_count"),
                        "total_quantity": result_dict.get("total_quantity"),
                        "message": result_dict.get("message")
                    }
                else:
                    # Rollback on failure
                    self.connection.rollback()
                    logger.error(f"❌ Hire creation failed: {result_dict.get('message')}")
                    return {
                        "success": False,
                        "message": result_dict.get("message", "Unknown error occurred")
                    }
            else:
                self.connection.rollback()
                return {
                    "success": False,
                    "message": "No result returned from create_hire procedure"
                }
                
        except psycopg2.Error as e:
            # Rollback on database error
            if self.connection:
                self.connection.rollback()
            logger.error(f"Database error in create_hire: {e}")
            return {
                "success": False,
                "message": f"Database error: {str(e)}"
            }
        except Exception as e:
            # Rollback on any other error
            if self.connection:
                self.connection.rollback()
            logger.error(f"Unexpected error in create_hire: {e}")
            return {
                "success": False,
                "message": f"Unexpected error: {str(e)}"
            }
    
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
        if not equipment_verification["exists"]:
            return {
                "success": False,
                "stage": "equipment_verification",
                "message": equipment_verification["message"]
            }
        logger.info(f"✅ {equipment_verification['message']}")
        
        # Step 6: Create hire interaction using fixed procedure
        logger.info("💾 Step 6: Creating hire interaction and driver task")
        creation_result = self.call_create_hire_procedure(hire_request)
        
        if creation_result["success"]:
            logger.info(f"🎉 Hire request processed successfully: {creation_result['reference_number']}")
            return {
                "success": True,
                "stage": "completed",
                "interaction_id": creation_result["interaction_id"],
                "reference_number": creation_result["reference_number"],
                "driver_task_id": creation_result["driver_task_id"],
                "assigned_driver_name": creation_result.get("assigned_driver_name", "Unassigned"),
                "equipment_count": creation_result.get("equipment_count", 0),
                "total_quantity": creation_result.get("total_quantity", 0),
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
    Main execution function - Updated for fixed create_hire procedure
    In production, this would be called by FastAPI/Flask with frontend data
    """
    print("🎯 HIRE PROCESS - Equipment Hire Request Processing (Updated)")
    print("=" * 60)
    print(f"📝 Processing hire request for: {SAMPLE_HIRE_REQUEST['customer']['customer_name']}")
    print(f"👤 Contact: {SAMPLE_HIRE_REQUEST['contact']['first_name']} {SAMPLE_HIRE_REQUEST['contact']['last_name']}")
    print(f"🏢 Site: {SAMPLE_HIRE_REQUEST['site']['site_name']}")
    print(f"📅 Delivery: {SAMPLE_HIRE_REQUEST['dates']['delivery_date']} at {SAMPLE_HIRE_REQUEST['dates']['delivery_time']}")
    print(f"🔧 Equipment: {len(SAMPLE_HIRE_REQUEST['equipment'])} items")
    for item in SAMPLE_HIRE_REQUEST['equipment']:
        print(f"   - {item['quantity']}x {item['equipment_name']} (ID: {item['equipment_category_id']})")
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
            print(f"👷 Assigned Driver: {result.get('assigned_driver_name', 'Unassigned')}")
            print(f"📦 Equipment Count: {result.get('equipment_count', 0)} categories")
            print(f"📊 Total Quantity: {result.get('total_quantity', 0)} items")
            print("\n📊 You can verify this in the database:")
            print(f"   SELECT * FROM interactions.interactions WHERE reference_number = '{result['reference_number']}';")
            print(f"   SELECT * FROM interactions.component_equipment_list WHERE interaction_id = {result['interaction_id']};")
            print(f"   SELECT * FROM interactions.component_hire_details WHERE interaction_id = {result['interaction_id']};")
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