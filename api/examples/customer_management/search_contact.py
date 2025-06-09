import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Optional, Union

def search_contacts(
    # Search parameters
    search_term: Optional[str] = None,
    customer_id: Optional[int] = None,        # Search within specific customer
    email_search: Optional[str] = None,       # For duplicate detection
    phone_search: Optional[str] = None,       # For duplicate detection
    contact_status: str = 'active',           # 'active', 'inactive', 'all'
    customer_status: str = 'active',          # Filter by customer status
    include_customer_info: bool = True,       # Include customer details
    primary_only: bool = False,               # Only primary contacts
    billing_only: bool = False,               # Only billing contacts
    limit_results: int = 50,                  # Limit number of results
    offset_results: int = 0,                  # For pagination
    
    # System authentication
    created_by: Optional[int] = None,
    session_token: Optional[str] = None,
    
    # Database connection
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Search for contacts with flexible filtering and duplicate detection capabilities.
    
    Args:
        search_term: Text to search for (name, job title, department, customer name)
        customer_id: Search within specific customer only
        email_search: Search by email (for duplicate detection)
        phone_search: Search by phone number (for duplicate detection)
        contact_status: Filter by contact status - 'active', 'inactive', 'all'
        customer_status: Filter by customer status - 'active', 'inactive', 'all'
        include_customer_info: Whether to include customer information
        primary_only: Only return primary contacts
        billing_only: Only return billing contacts
        limit_results: Maximum number of results to return
        offset_results: Number of results to skip (for pagination)
        created_by: Employee ID performing the search
        session_token: Session token for authentication
        
    Returns:
        Dictionary with:
        {
            'success': bool,
            'message': str,
            'contacts': [
                {
                    'contact_id': int,
                    'customer_id': int,
                    'first_name': str,
                    'last_name': str,
                    'full_name': str,
                    'job_title': str,
                    'department': str,
                    'email': str,
                    'phone_number': str,
                    'whatsapp_number': str,
                    'is_primary_contact': bool,
                    'is_billing_contact': bool,
                    'contact_status': str,
                    'customer_code': str,
                    'customer_name': str,
                    'customer_is_company': bool,
                    'customer_status': str,
                    'last_interaction_date': str,
                    'created_at': str,
                    'duplicate_score': int
                }
            ],
            'total_found': int,
            'search_params': dict,
            'has_more': bool,
            'potential_duplicates': int
        }
    """
    
    try:
        # Input validation
        if contact_status not in ['active', 'inactive', 'all']:
            return {
                'success': False,
                'message': 'Invalid contact_status. Must be "active", "inactive", or "all"',
                'contacts': [],
                'total_found': 0,
                'search_params': {},
                'has_more': False,
                'potential_duplicates': 0
            }
        
        if customer_status not in ['active', 'inactive', 'all']:
            return {
                'success': False,
                'message': 'Invalid customer_status. Must be "active", "inactive", or "all"',
                'contacts': [],
                'total_found': 0,
                'search_params': {},
                'has_more': False,
                'potential_duplicates': 0
            }
        
        if limit_results < 1 or limit_results > 1000:
            limit_results = 50  # Default safe limit
            
        if offset_results < 0:
            offset_results = 0
        
        # Connect to database
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Call the stored procedure
        cursor.execute("""
            SELECT * FROM core.search_contacts(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
        """, (
            search_term,
            customer_id,
            email_search,
            phone_search,
            contact_status,
            customer_status,
            include_customer_info,
            primary_only,
            billing_only,
            limit_results,
            offset_results,
            created_by,
            session_token
        ))
        
        # Get all results
        contacts = cursor.fetchall()
        
        # Close connections
        cursor.close()
        conn.close()
        
        # Convert to list of dictionaries and format data
        contact_list = []
        potential_duplicates = 0
        
        for contact in contacts:
            contact_dict = dict(contact)
            
            # Format dates to ISO string
            if contact_dict['last_interaction_date']:
                contact_dict['last_interaction_date'] = contact_dict['last_interaction_date'].isoformat()
            
            if contact_dict['created_at']:
                contact_dict['created_at'] = contact_dict['created_at'].isoformat()
            
            # Count potential duplicates (score > 50)
            if contact_dict['duplicate_score'] > 50:
                potential_duplicates += 1
            
            # Handle None values for better JSON serialization
            for key, value in contact_dict.items():
                if value is None:
                    contact_dict[key] = None
            
            contact_list.append(contact_dict)
        
        # Build search summary
        search_params = {
            'search_term': search_term,
            'customer_id': customer_id,
            'email_search': email_search,
            'phone_search': phone_search,
            'contact_status': contact_status,
            'customer_status': customer_status,
            'include_customer_info': include_customer_info,
            'primary_only': primary_only,
            'billing_only': billing_only,
            'limit': limit_results,
            'offset': offset_results
        }
        
        # Determine if there are more results
        has_more = len(contact_list) == limit_results
        
        # Build success message
        if email_search or phone_search:
            message = f'Found {len(contact_list)} contacts for duplicate check'
        elif customer_id:
            message = f'Found {len(contact_list)} contacts for customer {customer_id}'
        elif search_term:
            message = f'Found {len(contact_list)} contacts matching "{search_term}"'
        else:
            message = f'Found {len(contact_list)} contacts'
        
        return {
            'success': True,
            'message': message,
            'contacts': contact_list,
            'total_found': len(contact_list),
            'search_params': search_params,
            'has_more': has_more,
            'potential_duplicates': potential_duplicates
        }
        
    except psycopg2.Error as e:
        # Database error
        return {
            'success': False,
            'message': f'Database error: {str(e)}',
            'contacts': [],
            'total_found': 0,
            'search_params': {},
            'has_more': False,
            'potential_duplicates': 0
        }
        
    except Exception as e:
        # General error
        return {
            'success': False,
            'message': f'System error: {str(e)}',
            'contacts': [],
            'total_found': 0,
            'search_params': {},
            'has_more': False,
            'potential_duplicates': 0
        }


def get_customer_contacts(
    customer_id: int,
    active_only: bool = True,
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Get all contacts for a specific customer (for dropdown population).
    
    Args:
        customer_id: ID of the customer
        active_only: Whether to include only active contacts
        
    Returns:
        Dictionary with contacts for the customer
    """
    
    try:
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM core.get_customer_contacts(%s, %s)
        """, (customer_id, active_only))
        
        contacts = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        contact_list = [dict(contact) for contact in contacts]
        
        return {
            'success': True,
            'message': f'Found {len(contact_list)} contacts for customer {customer_id}',
            'contacts': contact_list,
            'total_found': len(contact_list)
        }
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Error: {str(e)}',
            'contacts': [],
            'total_found': 0
        }


def detect_duplicate_contacts(
    email: Optional[str] = None,
    phone: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    exclude_contact_id: Optional[int] = None,
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Detect potential duplicate contacts based on email, phone, or name.
    
    Args:
        email: Email to check for duplicates
        phone: Phone number to check for duplicates
        first_name: First name to check for duplicates
        last_name: Last name to check for duplicates
        exclude_contact_id: Contact ID to exclude from search (when updating)
        
    Returns:
        Dictionary with potential duplicate contacts and confidence scores
    """
    
    try:
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM core.detect_duplicate_contacts(%s, %s, %s, %s, %s)
        """, (email, phone, first_name, last_name, exclude_contact_id))
        
        duplicates = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        duplicate_list = [dict(duplicate) for duplicate in duplicates]
        
        # Categorize by confidence level
        high_confidence = [d for d in duplicate_list if d['confidence_score'] >= 80]
        medium_confidence = [d for d in duplicate_list if 60 <= d['confidence_score'] < 80]
        low_confidence = [d for d in duplicate_list if d['confidence_score'] < 60]
        
        return {
            'success': True,
            'message': f'Found {len(duplicate_list)} potential duplicates',
            'duplicates': duplicate_list,
            'total_found': len(duplicate_list),
            'high_confidence': high_confidence,
            'medium_confidence': medium_confidence,
            'low_confidence': low_confidence,
            'has_exact_matches': len(high_confidence) > 0
        }
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Error: {str(e)}',
            'duplicates': [],
            'total_found': 0,
            'high_confidence': [],
            'medium_confidence': [],
            'low_confidence': [],
            'has_exact_matches': False
        }


# Simplified functions for specific use cases

def search_contacts_for_dropdown(
    search_term: str, 
    customer_id: Optional[int] = None,
    limit: int = 10
) -> List[Dict]:
    """
    Simplified contact search perfect for dropdown/autocomplete components.
    Returns just the essential data needed for selection.
    """
    
    result = search_contacts(
        search_term=search_term,
        customer_id=customer_id,
        limit_results=limit,
        include_customer_info=True
    )
    
    if result['success']:
        return [
            {
                'id': contact['contact_id'],
                'name': contact['full_name'],
                'email': contact['email'],
                'phone': contact['phone_number'],
                'job_title': contact['job_title'],
                'customer_name': contact['customer_name'],
                'customer_code': contact['customer_code'],
                'is_primary': contact['is_primary_contact'],
                'is_billing': contact['is_billing_contact'],
                'display': f"{contact['full_name']} ({contact['customer_name']})" + 
                          (f" - {contact['job_title']}" if contact['job_title'] else "")
            }
            for contact in result['contacts']
        ]
    else:
        return []


def check_for_duplicates_before_create(
    email: str,
    phone: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None
) -> Dict:
    """
    Quick duplicate check before creating a new contact.
    Returns simple yes/no with details of any duplicates found.
    """
    
    result = detect_duplicate_contacts(email, phone, first_name, last_name)
    
    if result['success']:
        return {
            'has_duplicates': result['total_found'] > 0,
            'exact_matches': len(result['high_confidence']),
            'similar_matches': len(result['medium_confidence']),
            'duplicates': result['duplicates'],
            'recommendation': 
                'STOP - Exact duplicate found!' if len(result['high_confidence']) > 0
                else 'CAUTION - Similar contact found' if len(result['medium_confidence']) > 0
                else 'OK - No duplicates detected'
        }
    else:
        return {
            'has_duplicates': False,
            'exact_matches': 0,
            'similar_matches': 0,
            'duplicates': [],
            'recommendation': 'OK - Check failed, but proceed with caution'
        }


# Example usage and testing functions
def example_contact_searches():
    """Example usage of the contact search functions"""
    
    print("=== Contact Search Examples ===\n")
    
    # Example 1: Basic name search
    print("1. Search for contacts named 'John':")
    result1 = search_contacts(search_term="John")
    print(f"   Found {result1['total_found']} contacts")
    for contact in result1['contacts'][:3]:  # Show first 3
        print(f"   - {contact['full_name']} at {contact['customer_name']} ({contact['email']})")
    
    # Example 2: Search within specific customer
    print("\n2. Search contacts for customer 1001:")
    result2 = get_customer_contacts(1001)
    print(f"   Found {result2['total_found']} contacts")
    for contact in result2['contacts']:
        primary = " (PRIMARY)" if contact['is_primary_contact'] else ""
        billing = " (BILLING)" if contact['is_billing_contact'] else ""
        print(f"   - {contact['full_name']}{primary}{billing} - {contact['email']}")
    
    # Example 3: Search by email (duplicate detection)
    print("\n3. Check for duplicate email 'john@company.com':")
    result3 = search_contacts(email_search="john@company.com")
    if result3['potential_duplicates'] > 0:
        print(f"   DUPLICATE ALERT: Found {result3['potential_duplicates']} potential duplicates")
        for contact in result3['contacts']:
            if contact['duplicate_score'] > 50:
                print(f"   - {contact['full_name']} at {contact['customer_name']} (Score: {contact['duplicate_score']})")
    else:
        print("   No duplicates found")
    
    # Example 4: Primary contacts only
    print("\n4. Search primary contacts:")
    result4 = search_contacts(primary_only=True, limit_results=5)
    print(f"   Found {result4['total_found']} primary contacts")
    for contact in result4['contacts']:
        print(f"   - {contact['full_name']} (PRIMARY) at {contact['customer_name']}")
    
    # Example 5: Dropdown search
    print("\n5. Dropdown search for 'Manager':")
    dropdown_results = search_contacts_for_dropdown("Manager", limit=5)
    for item in dropdown_results:
        print(f"   - {item['display']}")


def test_duplicate_detection():
    """Test the duplicate detection functionality"""
    
    print("=== Duplicate Detection Tests ===\n")
    
    # Test cases for duplicate detection
    test_cases = [
        {
            'name': 'Exact email match',
            'email': 'john.guy@abcconstruction.com',
            'expected': 'Should find exact match'
        },
        {
            'name': 'Phone number match', 
            'phone': '+27111234567',
            'expected': 'Should find phone match'
        },
        {
            'name': 'Name match',
            'first_name': 'John',
            'last_name': 'Guy',
            'expected': 'Should find name match'
        },
        {
            'name': 'New contact (no duplicates)',
            'email': 'newperson@newcompany.com',
            'first_name': 'New',
            'last_name': 'Person',
            'expected': 'Should find no duplicates'
        }
    ]
    
    for i, test_case in enumerate(test_cases, 1):
        print(f"{i}. {test_case['name']}:")
        
        result = check_for_duplicates_before_create(
            email=test_case.get('email'),
            phone=test_case.get('phone'),
            first_name=test_case.get('first_name'),
            last_name=test_case.get('last_name')
        )
        
        print(f"   Expected: {test_case['expected']}")
        print(f"   Result: {result['recommendation']}")
        print(f"   Duplicates found: {result['exact_matches']} exact, {result['similar_matches']} similar")
        
        if result['duplicates']:
            for dup in result['duplicates'][:2]:  # Show first 2
                print(f"   - {dup['full_name']} at {dup['customer_name']} ({dup['duplicate_reason']})")
        print()


def interaction_workflow_example():
    """Example of the interaction creation workflow"""
    
    print("=== Interaction Creation Workflow ===\n")
    
    # Step 1: Search for customer
    print("Step 1: Search for customer 'ABC'")
    from flask_search_customer_function import search_customers  # Import customer search
    customers = search_customers("ABC", limit_results=3)
    
    if customers['success'] and customers['customers']:
        selected_customer = customers['customers'][0]
        print(f"Selected: {selected_customer['customer_name']} ({selected_customer['customer_code']})")
        
        # Step 2: Get contacts for selected customer
        print(f"\nStep 2: Get contacts for {selected_customer['customer_name']}")
        contacts = get_customer_contacts(selected_customer['customer_id'])
        
        if contacts['success'] and contacts['contacts']:
            print(f"Available contacts ({contacts['total_found']}):")
            for contact in contacts['contacts']:
                primary = " (PRIMARY)" if contact['is_primary_contact'] else ""
                print(f"  - {contact['full_name']}{primary} - {contact['email']}")
            
            # Step 3: Could also search contacts directly
            print(f"\nStep 3: Alternative - Direct contact search within customer")
            direct_search = search_contacts(
                search_term="Manager",
                customer_id=selected_customer['customer_id']
            )
            
            if direct_search['success']:
                print(f"Found {direct_search['total_found']} contacts matching 'Manager':")
                for contact in direct_search['contacts']:
                    print(f"  - {contact['full_name']} ({contact['job_title']})")
        else:
            print("No contacts found for this customer")
    else:
        print("No customers found")


if __name__ == "__main__":
    # Run examples when script is executed directly
    example_contact_searches()
    
    print("\n" + "="*50)
    test_duplicate_detection()
    
    print("\n" + "="*50)
    interaction_workflow_example()