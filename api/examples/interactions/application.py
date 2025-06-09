import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, Optional

def create_application(
    # Required fields
    application_type: str,          # 'individual' or 'company'
    applicant_first_name: str,
    applicant_last_name: str,
    applicant_email: str,
    
    # Optional fields
    contact_method: str = 'email',
    documents_required: Optional[str] = None,
    documents_received: Optional[str] = None,
    verification_notes: Optional[str] = None,
    initial_notes: Optional[str] = None,
    
    # System
    employee_id: Optional[int] = None,
    session_token: Optional[str] = None,
    
    # Database connection
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Create a new customer application (individual or company).
    
    Args:
        application_type: 'individual' or 'company'
        applicant_first_name: Applicant's first name
        applicant_last_name: Applicant's last name
        applicant_email: Applicant's email address
        contact_method: How they contacted us ('email', 'phone', 'in_person', 'whatsapp', 'online', 'other')
        documents_required: List of documents needed for verification
        documents_received: List of documents already received
        verification_notes: Initial verification notes
        initial_notes: General notes about the application
        employee_id: Employee processing the application
        session_token: Alternative authentication via session token
        
    Returns:
        Dictionary with:
        {
            'success': bool,
            'message': str,
            'interaction_id': int or None,
            'reference_number': str or None,
            'task_id': int or None,
            'assigned_to': str or None
        }
    """
    
    try:
        # Input validation
        if application_type not in ['individual', 'company']:
            return {
                'success': False,
                'message': 'Application type must be "individual" or "company"',
                'interaction_id': None,
                'reference_number': None,
                'task_id': None,
                'assigned_to': None
            }
        
        if contact_method not in ['phone', 'email', 'in_person', 'whatsapp', 'online', 'other']:
            return {
                'success': False,
                'message': 'Invalid contact method',
                'interaction_id': None,
                'reference_number': None,
                'task_id': None,
                'assigned_to': None
            }
        
        # Connect to database
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Call the stored procedure
        cursor.execute("""
            SELECT * FROM interactions.create_application(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
        """, (
            application_type,
            applicant_first_name,
            applicant_last_name,
            applicant_email,
            contact_method,
            documents_required,
            documents_received,
            verification_notes,
            initial_notes,
            employee_id,
            session_token
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
            'interaction_id': result['interaction_id'],
            'reference_number': result['reference_number'],
            'task_id': result['task_id'],
            'assigned_to': result['assigned_to']
        }
        
    except psycopg2.Error as e:
        # Database error
        return {
            'success': False,
            'message': f'Database error: {str(e)}',
            'interaction_id': None,
            'reference_number': None,
            'task_id': None,
            'assigned_to': None
        }
        
    except Exception as e:
        # General error
        return {
            'success': False,
            'message': f'System error: {str(e)}',
            'interaction_id': None,
            'reference_number': None,
            'task_id': None,
            'assigned_to': None
        }


def update_application_status(
    interaction_id: int,
    verification_status: str,
    verification_notes: Optional[str] = None,
    approved_by: Optional[int] = None,
    employee_id: Optional[int] = None,
    session_token: Optional[str] = None,
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Update the status of an existing application.
    
    Args:
        interaction_id: ID of the application interaction
        verification_status: New status ('pending', 'documents_requested', 'documents_received', 'under_review', 'approved', 'rejected')
        verification_notes: Notes about the status change
        approved_by: Employee ID if approving/rejecting
        employee_id: Employee making the change
        session_token: Alternative authentication
        
    Returns:
        Dictionary with success status and details
    """
    
    try:
        # Validate status
        valid_statuses = ['pending', 'documents_requested', 'documents_received', 'under_review', 'approved', 'rejected']
        if verification_status not in valid_statuses:
            return {
                'success': False,
                'message': f'Invalid status. Must be one of: {", ".join(valid_statuses)}',
                'reference_number': None,
                'new_status': None
            }
        
        # Connect to database
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Call the stored procedure
        cursor.execute("""
            SELECT * FROM interactions.update_application_status(
                %s, %s, %s, %s, %s, %s
            )
        """, (
            interaction_id,
            verification_status,
            verification_notes,
            approved_by,
            employee_id,
            session_token
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
            'reference_number': result['reference_number'],
            'new_status': result['new_status']
        }
        
    except psycopg2.Error as e:
        return {
            'success': False,
            'message': f'Database error: {str(e)}',
            'reference_number': None,
            'new_status': None
        }
        
    except Exception as e:
        return {
            'success': False,
            'message': f'System error: {str(e)}',
            'reference_number': None,
            'new_status': None
        }


# Example usage and testing functions
def example_applications():
    """Example usage of the application functions"""
    
    print("=== Application Processing Examples ===\n")
    
    # Example 1: Individual application
    print("1. Create individual application:")
    result1 = create_application(
        application_type="individual",
        applicant_first_name="John",
        applicant_last_name="Smith",
        applicant_email="john.smith@email.com",
        contact_method="email",
        documents_required="ID document, proof of income",
        verification_notes="Initial application via website",
        initial_notes="Customer called to inquire about equipment rental",
        employee_id=1001
    )
    
    if result1['success']:
        print(f"   ✅ SUCCESS: {result1['message']}")
        print(f"   Reference: {result1['reference_number']}")
        print(f"   Assigned to: {result1['assigned_to']}")
        
        # Example status update
        print("\n   Updating status to request documents:")
        status_result = update_application_status(
            interaction_id=result1['interaction_id'],
            verification_status="documents_requested",
            verification_notes="Requested ID document and proof of income via email",
            employee_id=1001
        )
        
        if status_result['success']:
            print(f"   ✅ Status updated: {status_result['message']}")
        else:
            print(f"   ❌ Status update failed: {status_result['message']}")
    else:
        print(f"   ❌ FAILED: {result1['message']}")
    
    # Example 2: Company application
    print("\n2. Create company application:")
    result2 = create_application(
        application_type="company",
        applicant_first_name="Sarah",
        applicant_last_name="Williams",
        applicant_email="sarah@techsolutions.co.za",
        contact_method="phone",
        documents_required="Company registration, VAT certificate, director ID",
        documents_received="Registration certificate received",
        verification_notes="Large construction company, good credit history",
        initial_notes="Referred by existing customer ABC Construction",
        employee_id=1002
    )
    
    if result2['success']:
        print(f"   ✅ SUCCESS: {result2['message']}")
        print(f"   Reference: {result2['reference_number']}")
        print(f"   Task ID: {result2['task_id']}")
    else:
        print(f"   ❌ FAILED: {result2['message']}")


def application_workflow_example():
    """Show the complete application workflow"""
    
    print("=== Complete Application Workflow ===\n")
    
    print("Scenario: Customer calls asking about equipment rental")
    print("Employee creates application and processes it through completion\n")
    
    # Step 1: Create application
    print("Step 1: Employee creates application")
    app_result = create_application(
        application_type="individual",
        applicant_first_name="Mary",
        applicant_last_name="Johnson",
        applicant_email="mary.johnson@email.com",
        contact_method="phone",
        documents_required="ID document, proof of address, proof of income",
        verification_notes="Customer sounds legitimate, has specific equipment needs",
        initial_notes="Called asking about excavator rental for home renovation project",
        employee_id=1001
    )
    
    if not app_result['success']:
        print(f"❌ Application creation failed: {app_result['message']}")
        return
    
    print(f"✅ Application created: {app_result['reference_number']}")
    print(f"   Assigned to: {app_result['assigned_to']}")
    interaction_id = app_result['interaction_id']
    
    # Step 2: Request documents
    print("\nStep 2: Hire control requests documents")
    status1 = update_application_status(
        interaction_id=interaction_id,
        verification_status="documents_requested",
        verification_notes="Emailed customer requesting ID, proof of address, and proof of income",
        employee_id=1003  # Different hire control employee
    )
    
    if status1['success']:
        print(f"✅ {status1['message']}")
    else:
        print(f"❌ Failed: {status1['message']}")
        return
    
    # Step 3: Documents received
    print("\nStep 3: Documents received")
    status2 = update_application_status(
        interaction_id=interaction_id,
        verification_status="documents_received",
        verification_notes="Customer emailed scanned copies of all required documents",
        employee_id=1003
    )
    
    if status2['success']:
        print(f"✅ {status2['message']}")
    
    # Step 4: Under review
    print("\nStep 4: Application under review")
    status3 = update_application_status(
        interaction_id=interaction_id,
        verification_status="under_review",
        verification_notes="Verifying documents with relevant authorities",
        employee_id=1003
    )
    
    if status3['success']:
        print(f"✅ {status3['message']}")
    
    # Step 5: Approve application
    print("\nStep 5: Application approved")
    status4 = update_application_status(
        interaction_id=interaction_id,
        verification_status="approved",
        verification_notes="All documents verified. Customer approved for rental account with R5000 credit limit.",
        approved_by=1003,
        employee_id=1003
    )
    
    if status4['success']:
        print(f"✅ {status4['message']}")
        print("   Next step: Create customer record from approved application")
    
    print("\n📋 Workflow complete! Application processed from initial contact to approval.")


def test_application_creation():
    """Simple test function"""
    
    print("=== Simple Application Test ===\n")
    
    result = create_application(
        application_type="individual",
        applicant_first_name="Test",
        applicant_last_name="User",
        applicant_email="test@example.com",
        contact_method="online",
        verification_notes="Test application",
        employee_id=1  # System user
    )
    
    if result['success']:
        print(f"✅ SUCCESS: {result['message']}")
        print(f"   Reference Number: {result['reference_number']}")
        print(f"   Interaction ID: {result['interaction_id']}")
        print(f"   Task ID: {result['task_id']}")
        print(f"   Assigned To: {result['assigned_to']}")
    else:
        print(f"❌ FAILED: {result['message']}")
    
    return result


# Helper function for Flask routes
def process_application_form(form_data: Dict, employee_id: int) -> Dict:
    """
    Process application form data from Flask frontend.
    
    Args:
        form_data: Dictionary with form fields
        employee_id: ID of employee processing the application
        
    Returns:
        Result dictionary ready for JSON response
    """
    
    # Extract and validate form data
    try:
        result = create_application(
            application_type=form_data.get('application_type'),
            applicant_first_name=form_data.get('first_name'),
            applicant_last_name=form_data.get('last_name'),
            applicant_email=form_data.get('email'),
            contact_method=form_data.get('contact_method', 'email'),
            documents_required=form_data.get('documents_required'),
            documents_received=form_data.get('documents_received'),
            verification_notes=form_data.get('verification_notes'),
            initial_notes=form_data.get('initial_notes'),
            employee_id=employee_id
        )
        
        # Add additional info for frontend
        if result['success']:
            result['next_steps'] = [
                "Application has been created and assigned to hire control team",
                "Hire control will review and request any additional documents needed",
                "Customer will be notified of approval/rejection within 2 business days"
            ]
        
        return result
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Form processing error: {str(e)}',
            'interaction_id': None,
            'reference_number': None,
            'task_id': None,
            'assigned_to': None
        }


if __name__ == "__main__":
    # Run examples when script is executed directly
    example_applications()
    
    print("\n" + "="*60)
    application_workflow_example()
    
    print("\n" + "="*60)
    test_application_creation()