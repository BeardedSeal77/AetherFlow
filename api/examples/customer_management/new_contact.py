import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, Optional

def create_new_contact(
    # Required fields
    customer_id: int,
    first_name: str,
    last_name: str,
    email: str,
    
    # Optional fields
    job_title: Optional[str] = None,
    department: Optional[str] = None,
    phone_number: Optional[str] = None,
    whatsapp_number: Optional[str] = None,
    is_primary_contact: bool = False,
    is_billing_contact: bool = False,
    
    # System
    created_by: Optional[int] = None,
    session_token: Optional[str] = None,
    
    # Database connection (would come from Flask app context later)
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Add a new contact to an existing customer.
    
    Args:
        customer_id: ID of the existing customer
        first_name: Contact's first name
        last_name: Contact's last name
        email: Contact's email (must be unique)
        job_title: Optional job title
        department: Optional department
        phone_number: Optional phone number
        whatsapp_number: Optional WhatsApp number
        is_primary_contact: Set as primary contact (only one per customer)
        is_billing_contact: Set as billing contact (only one per customer)
        created_by: Employee ID creating the contact
        session_token: Alternative authentication via session token
        
    Returns:
        Dictionary with:
        {
            'success': bool,
            'message': str,
            'contact_id': int or None,
            'customer_name': str or None,
            'customer_code': str or None,
            'validation_errors': list
        }
    """
    
    try:
        # Connect to database
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Call the stored procedure
        cursor.execute("""
            SELECT * FROM core.create_new_contact(
                %s, %s, %s, %s,     -- Required: customer_id, first_name, last_name, email
                %s, %s, %s, %s,     -- Optional contact: job_title, department, phone, whatsapp
                %s, %s,             -- Flags: is_primary, is_billing
                %s, %s              -- System: created_by, session_token
            )
        """, (
            customer_id, first_name, last_name, email,
            job_title, department, phone_number, whatsapp_number,
            is_primary_contact, is_billing_contact,
            created_by, session_token
        ))
        
        # Get the result
        result = cursor.fetchone()
        
        # Commit the transaction
        conn.commit()
        
        # Close connections
        cursor.close()
        conn.close()
        
        # Return structured response
        return {
            'success': result['success'],
            'message': result['message'],
            'contact_id': result['contact_id'],
            'customer_name': result['customer_name'],
            'customer_code': result['customer_code'],
            'validation_errors': result['validation_errors']
        }
        
    except psycopg2.Error as e:
        # Database error
        return {
            'success': False,
            'message': f'Database error: {str(e)}',
            'contact_id': None,
            'customer_name': None,
            'customer_code': None,
            'validation_errors': [f'Database error: {str(e)}']
        }
        
    except Exception as e:
        # General error
        return {
            'success': False,
            'message': f'System error: {str(e)}',
            'contact_id': None,
            'customer_name': None,
            'customer_code': None,
            'validation_errors': [f'System error: {str(e)}']
        }


# Example usage functions
def create_new_contact_with_validation(
    # Required fields
    customer_id: int,
    first_name: str,
    last_name: str,
    email: str,
    
    # Optional fields
    job_title: Optional[str] = None,
    department: Optional[str] = None,
    phone_number: Optional[str] = None,
    whatsapp_number: Optional[str] = None,
    is_primary_contact: bool = False,
    is_billing_contact: bool = False,
    
    # System
    created_by: Optional[int] = None,
    session_token: Optional[str] = None,
    
    # Validation options
    skip_duplicate_check: bool = False,
    
    # Database connection
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Create a new contact with comprehensive validation using search procedures.
    
    This function demonstrates the proper workflow:
    1. Validate customer exists using search functions
    2. Check for duplicates using search functions  
    3. Create contact using the simplified procedure
    
    Args:
        customer_id: ID of the existing customer
        first_name: Contact's first name
        last_name: Contact's last name
        email: Contact's email (must be unique)
        job_title: Optional job title
        department: Optional department
        phone_number: Optional phone number
        whatsapp_number: Optional WhatsApp number
        is_primary_contact: Set as primary contact (only one per customer)
        is_billing_contact: Set as billing contact (only one per customer)
        created_by: Employee ID creating the contact
        session_token: Alternative authentication via session token
        skip_duplicate_check: Skip duplicate validation (for special cases)
        
    Returns:
        Dictionary with comprehensive validation and creation results
    """
    
    try:
        # Import the search functions (these would be imported at top in real code)
        from search_customer import get_customer_by_id
        from search_contact import check_for_duplicates_before_create
        
        # =================================================================
        # STEP 1: PRE-VALIDATION USING SEARCH FUNCTIONS
        # =================================================================
        
        # Validate customer exists and is active
        customer_result = get_customer_by_id(customer_id, db_connection_string)
        if not customer_result['success']:
            return {
                'success': False,
                'message': 'Customer validation failed: ' + customer_result['message'],
                'contact_id': None,
                'customer_name': None,
                'customer_code': None,
                'validation_errors': ['Customer not found or inactive'],
                'pre_validation': {
                    'customer_valid': False,
                    'duplicates_checked': False,
                    'duplicates_found': False
                }
            }
        
        customer = customer_result['customer']
        if customer['status'] != 'active':
            return {
                'success': False,
                'message': f'Customer {customer["customer_name"]} is not active',
                'contact_id': None,
                'customer_name': customer['customer_name'],
                'customer_code': customer['customer_code'],
                'validation_errors': ['Customer is not active'],
                'pre_validation': {
                    'customer_valid': False,
                    'duplicates_checked': False,
                    'duplicates_found': False
                }
            }
        
        # =================================================================
        # STEP 2: DUPLICATE DETECTION USING SEARCH FUNCTIONS
        # =================================================================
        
        duplicates_found = False
        duplicate_details = []
        
        if not skip_duplicate_check:
            duplicate_result = check_for_duplicates_before_create(
                email=email,
                phone=phone_number,
                first_name=first_name,
                last_name=last_name
            )
            
            if duplicate_result['has_duplicates']:
                duplicates_found = True
                duplicate_details = duplicate_result['duplicates']
                
                if duplicate_result['exact_matches'] > 0:
                    return {
                        'success': False,
                        'message': 'Exact duplicate contact found - creation blocked',
                        'contact_id': None,
                        'customer_name': customer['customer_name'],
                        'customer_code': customer['customer_code'],
                        'validation_errors': [duplicate_result['recommendation']],
                        'pre_validation': {
                            'customer_valid': True,
                            'duplicates_checked': True,
                            'duplicates_found': True,
                            'duplicate_details': duplicate_details,
                            'recommendation': duplicate_result['recommendation']
                        }
                    }
        
        # =================================================================
        # STEP 3: CREATE CONTACT USING SIMPLIFIED PROCEDURE
        # =================================================================
        
        # Now call the simplified contact creation procedure
        result = create_new_contact(
            customer_id=customer_id,
            first_name=first_name,
            last_name=last_name,
            email=email,
            job_title=job_title,
            department=department,
            phone_number=phone_number,
            whatsapp_number=whatsapp_number,
            is_primary_contact=is_primary_contact,
            is_billing_contact=is_billing_contact,
            created_by=created_by,
            session_token=session_token,
            db_connection_string=db_connection_string
        )
        
        # Enhance the result with pre-validation info
        if result['success']:
            result['pre_validation'] = {
                'customer_valid': True,
                'duplicates_checked': not skip_duplicate_check,
                'duplicates_found': duplicates_found,
                'duplicate_details': duplicate_details if duplicates_found else [],
                'recommendation': 'Contact created successfully'
            }
            
            if duplicates_found:
                result['message'] += f' (Warning: {len(duplicate_details)} similar contacts found)'
        
        return result
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Pre-validation error: {str(e)}',
            'contact_id': None,
            'customer_name': None,
            'customer_code': None,
            'validation_errors': [f'System error during validation: {str(e)}'],
            'pre_validation': {
                'customer_valid': False,
                'duplicates_checked': False,
                'duplicates_found': False
            }
        }


# Updated example usage showing the improved workflow
def improved_workflow_example():
    """Example showing the improved contact creation workflow"""
    
    print("=== Improved Contact Creation Workflow ===\n")
    
    # Scenario 1: Normal contact creation with validation
    print("Scenario 1: Create new contact with full validation")
    result1 = create_new_contact_with_validation(
        customer_id=1001,
        first_name="Alice",
        last_name="Johnson", 
        email="alice.johnson@company.com",
        job_title="Project Manager",
        phone_number="+27112345678",
        created_by=1001
    )
    
    print(f"Result: {result1['message']}")
    if result1['success']:
        print(f"  Contact ID: {result1['contact_id']}")
        print(f"  Pre-validation: Customer valid: {result1['pre_validation']['customer_valid']}")
        print(f"  Duplicates checked: {result1['pre_validation']['duplicates_checked']}")
        print(f"  Duplicates found: {result1['pre_validation']['duplicates_found']}")
    else:
        print(f"  Validation errors: {result1['validation_errors']}")
    
    # Scenario 2: Duplicate detection in action
    print("\nScenario 2: Try to create duplicate contact")
    result2 = create_new_contact_with_validation(
        customer_id=1001,
        first_name="John",
        last_name="Guy",
        email="john.guy@abcconstruction.com",  # This should exist in sample data
        created_by=1001
    )
    
    print(f"Result: {result2['message']}")
    if not result2['success'] and result2['pre_validation']['duplicates_found']:
        print("  Duplicate detection worked!")
        print(f"  Recommendation: {result2['pre_validation']['recommendation']}")
        for dup in result2['pre_validation']['duplicate_details']:
            print(f"    - Found: {dup['full_name']} at {dup['customer_name']} ({dup['duplicate_reason']})")
    
    # Scenario 3: Using the workflow for interaction creation
    print("\nScenario 3: Complete interaction preparation workflow")
    
    # Step 1: Search and select customer (using customer search)
    print("  Step 1: Search for customer")
    # This would use: customers = search_customers("ABC")
    # User selects customer_id = 1001
    
    # Step 2: Get/search contacts for customer
    print("  Step 2: Get contacts for customer")
    contacts = get_customer_contacts(1001)
    if contacts['success']:
        print(f"    Found {contacts['total_found']} existing contacts")
        for contact in contacts['contacts'][:2]:  # Show first 2
            print(f"      - {contact['full_name']} ({contact['email']})")
    
    # Step 3: If needed, create new contact (with validation)
    print("  Step 3: Create new contact if needed")
    print("    -> Would use create_new_contact_with_validation() as shown above")
    
    # Step 4: Now ready for interaction creation
    print("  Step 4: Ready to create interaction with customer_id=1001, contact_id=selected")


def workflow_comparison():
    """Show the difference between old and new workflows"""
    
    print("=== Workflow Comparison ===\n")
    
    print("OLD WORKFLOW (all-in-one procedure):")
    print("  1. new_contact procedure does everything:")
    print("     - Customer validation")
    print("     - Duplicate checking") 
    print("     - Primary/billing conflict checking")
    print("     - Contact creation")
    print("     - Audit logging")
    print("  Problems:")
    print("     - Duplicate logic across procedures")
    print("     - Hard to reuse validation")
    print("     - Limited search capabilities")
    
    print("\nNEW WORKFLOW (separation of concerns):")
    print("  1. Frontend: search_customers() -> select customer")
    print("  2. Frontend: get_customer_contacts() -> show existing contacts") 
    print("  3. Frontend: check_for_duplicates_before_create() -> validate before form submit")
    print("  4. Backend: create_new_contact() -> simple contact creation")
    print("  Benefits:")
    print("     - Reusable search functions")
    print("     - Better user experience (early validation)")
    print("     - Cleaner code separation")
    print("     - Flexible duplicate detection")
    print("     - Optimized database calls")


# Simple test function
def test_contact_creation():
    """Simple test function to verify contact creation works"""
    
    # Test with a known customer (assuming customer ID 1000 exists from sample data)
    result = create_new_contact(
        customer_id=1000,
        first_name="Test",
        last_name="Contact",
        email="test.contact@example.com",
        job_title="Test Position",
        phone_number="+27833999888",
        created_by=1  # System user
    )
    
    if result['success']:
        print(f"✅ SUCCESS: {result['message']}")
        print(f"   Contact ID: {result['contact_id']}")
        print(f"   Customer: {result['customer_name']} ({result['customer_code']})")
    else:
        print(f"❌ FAILED: {result['message']}")
        print(f"   Validation Errors: {result['validation_errors']}")
    
    return result


# Quick lookup helper function
def get_customer_contacts(customer_id: int, db_connection_string: str = "postgresql://username:password@localhost:5432/task_management") -> Dict:
    """
    Helper function to get all contacts for a customer (useful for validation)
    """
    try:
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT 
                c.id,
                c.first_name,
                c.last_name,
                c.email,
                c.job_title,
                c.phone_number,
                c.is_primary_contact,
                c.is_billing_contact,
                c.status,
                cust.customer_name,
                cust.customer_code
            FROM core.contacts c
            JOIN core.customers cust ON c.customer_id = cust.id
            WHERE c.customer_id = %s
            AND c.status = 'active'
            ORDER BY c.is_primary_contact DESC, c.is_billing_contact DESC, c.first_name
        """, (customer_id,))
        
        contacts = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return {
            'success': True,
            'contacts': [dict(contact) for contact in contacts],
            'count': len(contacts)
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e),
            'contacts': [],
            'count': 0
        }


if __name__ == "__main__":
    # Run examples when script is executed directly
    print("=== Contact Creation Examples ===")
    example_usage()
    
    print("\n=== Simple Test ===")
    test_contact_creation()
    
    print("\n=== Customer Contacts Lookup ===")
    contacts = get_customer_contacts(1000)
    if contacts['success']:
        print(f"Found {contacts['count']} contacts for customer 1000")
        for contact in contacts['contacts']:
            print(f"  - {contact['first_name']} {contact['last_name']} ({contact['email']})")
    else:
        print(f"Error: {contacts['error']}")