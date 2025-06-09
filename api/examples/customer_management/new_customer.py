import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Optional, Tuple

def create_new_customer(
    # Required fields
    customer_name: str,
    contact_first_name: str,
    contact_last_name: str,
    contact_email: str,
    
    # Optional fields
    customer_code: Optional[str] = None,
    is_company: bool = True,
    registration_number: Optional[str] = None,
    vat_number: Optional[str] = None,
    credit_limit: float = 0.00,
    payment_terms: str = "30 days",
    
    # Contact details
    contact_job_title: Optional[str] = None,
    contact_department: Optional[str] = None,
    contact_phone: Optional[str] = None,
    contact_whatsapp: Optional[str] = None,
    is_billing_contact: bool = True,
    
    # Site/Address details
    site_name: Optional[str] = None,
    site_type: str = "delivery_site",
    address_line1: Optional[str] = None,
    address_line2: Optional[str] = None,
    city: Optional[str] = None,
    province: Optional[str] = None,
    postal_code: Optional[str] = None,
    country: str = "South Africa",
    delivery_instructions: Optional[str] = None,
    
    # System
    created_by: Optional[int] = None,
    session_token: Optional[str] = None,
    
    # Database connection (would come from Flask app context later)
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Create a new customer with contact and optional site information.
    
    Args:
        customer_name: Name of the customer/company
        contact_first_name: Primary contact first name
        contact_last_name: Primary contact last name
        contact_email: Primary contact email
        customer_code: Optional custom customer code (defaults to ID if None)
        is_company: True for company, False for individual
        ... (other optional parameters)
        
    Returns:
        Dictionary with:
        {
            'success': bool,
            'message': str,
            'customer_id': int or None,
            'customer_code': str or None,
            'contact_id': int or None,
            'site_id': int or None,
            'validation_errors': list
        }
    """
    
    try:
        # Connect to database
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Call the stored procedure
        cursor.execute("""
            SELECT * FROM core.create_new_customer(
                %s, %s, %s, %s,           -- Required: name, first, last, email
                %s, %s, %s, %s, %s, %s,   -- Optional customer: code, company, reg, vat, credit, terms
                %s, %s, %s, %s, %s,       -- Optional contact: job, dept, phone, whatsapp, billing
                %s, %s, %s, %s, %s, %s, %s, %s, %s,  -- Optional site: name, type, addr1, addr2, city, province, postal, country, instructions
                %s, %s                    -- System: created_by, session_token
            )
        """, (
            customer_name, contact_first_name, contact_last_name, contact_email,
            customer_code, is_company, registration_number, vat_number, credit_limit, payment_terms,
            contact_job_title, contact_department, contact_phone, contact_whatsapp, is_billing_contact,
            site_name, site_type, address_line1, address_line2, city, province, postal_code, country, delivery_instructions,
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
            'customer_id': result['customer_id'],
            'customer_code': result['customer_code'],
            'contact_id': result['contact_id'],
            'site_id': result['site_id'],
            'validation_errors': result['validation_errors']
        }
        
    except psycopg2.Error as e:
        # Database error
        return {
            'success': False,
            'message': f'Database error: {str(e)}',
            'customer_id': None,
            'customer_code': None,
            'contact_id': None,
            'site_id': None,
            'validation_errors': [f'Database error: {str(e)}']
        }
        
    except Exception as e:
        # General error
        return {
            'success': False,
            'message': f'System error: {str(e)}',
            'customer_id': None,
            'customer_code': None,
            'contact_id': None,
            'site_id': None,
            'validation_errors': [f'System error: {str(e)}']
        }


# Example usage functions
def example_usage():
    """Example usage of the create_new_customer function"""
    
    # Example 1: Minimal company (code will default to ID)
    result1 = create_new_customer(
        customer_name="ABC Construction Ltd",
        contact_first_name="John",
        contact_last_name="Smith",
        contact_email="john@abcconstruction.co.za",
        created_by=1001
    )
    print("Example 1 Result:", result1)
    
    # Example 2: Individual with custom code and address
    result2 = create_new_customer(
        customer_name="Mary Johnson",
        contact_first_name="Mary",
        contact_last_name="Johnson", 
        contact_email="mary.johnson@email.com",
        customer_code="MARY001",  # Custom code
        is_company=False,
        contact_phone="+27821234567",
        address_line1="123 Residential Street",
        city="Johannesburg",
        province="Gauteng",
        postal_code="2000",
        created_by=1001
    )
    print("Example 2 Result:", result2)
    
    # Example 3: Full company with all details
    result3 = create_new_customer(
        customer_name="Tech Solutions Pty Ltd",
        contact_first_name="Sarah",
        contact_last_name="Williams",
        contact_email="sarah@techsolutions.co.za",
        customer_code="TECH001",
        is_company=True,
        registration_number="2023/123456/07",
        vat_number="4123456789",
        credit_limit=50000.00,
        payment_terms="30 days",
        contact_job_title="Operations Manager",
        contact_department="Operations",
        contact_phone="+27112345678",
        contact_whatsapp="+27821234567",
        site_name="Tech Solutions Head Office",
        site_type="head_office",
        address_line1="456 Technology Drive",
        address_line2="Suite 200",
        city="Sandton",
        province="Gauteng", 
        postal_code="2196",
        delivery_instructions="Use main reception, security controlled access",
        created_by=1001
    )
    print("Example 3 Result:", result3)


# Simple test function for when you want to test the database procedure
def test_customer_creation():
    """Simple test function to verify the customer creation works"""
    
    result = create_new_customer(
        customer_name="Test Customer Ltd",
        contact_first_name="Test",
        contact_last_name="User",
        contact_email="test@example.com",
        created_by=1  # System user
    )
    
    if result['success']:
        print(f"✅ SUCCESS: {result['message']}")
        print(f"   Customer ID: {result['customer_id']}")
        print(f"   Customer Code: {result['customer_code']}")
        print(f"   Contact ID: {result['contact_id']}")
    else:
        print(f"❌ FAILED: {result['message']}")
        print(f"   Validation Errors: {result['validation_errors']}")
    
    return result


if __name__ == "__main__":
    # Run examples when script is executed directly
    print("=== Customer Creation Examples ===")
    example_usage()
    
    print("\n=== Simple Test ===")
    test_customer_creation()