import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Optional, Union

def search_customers(
    # Search parameters
    search_term: Optional[str] = None,
    customer_type: Optional[str] = None,  # 'company', 'individual', or None
    status: str = 'active',               # 'active', 'inactive', 'all'
    include_contacts: bool = True,        # Include primary contact info
    limit_results: int = 50,              # Limit number of results
    offset_results: int = 0,              # For pagination
    
    # System authentication
    created_by: Optional[int] = None,
    session_token: Optional[str] = None,
    
    # Database connection (would come from Flask app context later)
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Search for customers with flexible filtering and full-text search capabilities.
    
    Args:
        search_term: Text to search for (customer name, code, VAT, registration number)
        customer_type: Filter by type - 'company', 'individual', or None for both
        status: Filter by status - 'active', 'inactive', 'all'
        include_contacts: Whether to include primary contact information
        limit_results: Maximum number of results to return
        offset_results: Number of results to skip (for pagination)
        created_by: Employee ID performing the search
        session_token: Session token for authentication
        
    Returns:
        Dictionary with:
        {
            'success': bool,
            'message': str,
            'customers': [
                {
                    'customer_id': int,
                    'customer_code': str,
                    'customer_name': str,
                    'is_company': bool,
                    'status': str,
                    'credit_limit': float,
                    'payment_terms': str,
                    'registration_number': str,
                    'vat_number': str,
                    'primary_contact_id': int,
                    'primary_contact_name': str,
                    'primary_contact_email': str,
                    'primary_contact_phone': str,
                    'total_contacts': int,
                    'total_sites': int,
                    'last_interaction_date': str,
                    'created_at': str
                }
            ],
            'total_found': int,
            'search_params': dict,
            'has_more': bool
        }
    """
    
    try:
        # Input validation
        if customer_type and customer_type not in ['company', 'individual']:
            return {
                'success': False,
                'message': 'Invalid customer_type. Must be "company", "individual", or None',
                'customers': [],
                'total_found': 0,
                'search_params': {},
                'has_more': False
            }
        
        if status not in ['active', 'inactive', 'all']:
            return {
                'success': False,
                'message': 'Invalid status. Must be "active", "inactive", or "all"',
                'customers': [],
                'total_found': 0,
                'search_params': {},
                'has_more': False
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
            SELECT * FROM core.search_customers(
                %s, %s, %s, %s, %s, %s, %s, %s
            )
        """, (
            search_term,
            customer_type,
            status,
            include_contacts,
            limit_results,
            offset_results,
            created_by,
            session_token
        ))
        
        # Get all results
        customers = cursor.fetchall()
        
        # Close connections
        cursor.close()
        conn.close()
        
        # Convert to list of dictionaries and format data
        customer_list = []
        for customer in customers:
            customer_dict = dict(customer)
            
            # Format decimal values
            if customer_dict['credit_limit']:
                customer_dict['credit_limit'] = float(customer_dict['credit_limit'])
            
            # Format dates to ISO string
            if customer_dict['last_interaction_date']:
                customer_dict['last_interaction_date'] = customer_dict['last_interaction_date'].isoformat()
            
            if customer_dict['created_at']:
                customer_dict['created_at'] = customer_dict['created_at'].isoformat()
            
            # Handle None values for better JSON serialization
            for key, value in customer_dict.items():
                if value is None:
                    customer_dict[key] = None
            
            customer_list.append(customer_dict)
        
        # Build search summary
        search_params = {
            'search_term': search_term,
            'customer_type': customer_type,
            'status': status,
            'include_contacts': include_contacts,
            'limit': limit_results,
            'offset': offset_results
        }
        
        # Determine if there are more results
        has_more = len(customer_list) == limit_results
        
        # Build success message
        if search_term:
            message = f'Found {len(customer_list)} customers matching "{search_term}"'
        else:
            message = f'Found {len(customer_list)} customers'
        
        return {
            'success': True,
            'message': message,
            'customers': customer_list,
            'total_found': len(customer_list),
            'search_params': search_params,
            'has_more': has_more
        }
        
    except psycopg2.Error as e:
        # Database error
        return {
            'success': False,
            'message': f'Database error: {str(e)}',
            'customers': [],
            'total_found': 0,
            'search_params': {},
            'has_more': False
        }
        
    except Exception as e:
        # General error
        return {
            'success': False,
            'message': f'System error: {str(e)}',
            'customers': [],
            'total_found': 0,
            'search_params': {},
            'has_more': False
        }


def get_customer_by_id(
    customer_id: int,
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Quick lookup of customer by ID.
    
    Args:
        customer_id: ID of the customer to retrieve
        
    Returns:
        Dictionary with customer details or error info
    """
    
    try:
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM core.get_customer_by_id(%s)
        """, (customer_id,))
        
        customer = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if customer:
            customer_dict = dict(customer)
            if customer_dict['credit_limit']:
                customer_dict['credit_limit'] = float(customer_dict['credit_limit'])
            
            return {
                'success': True,
                'message': f'Customer {customer_dict["customer_name"]} found',
                'customer': customer_dict
            }
        else:
            return {
                'success': False,
                'message': 'Customer not found',
                'customer': None
            }
            
    except Exception as e:
        return {
            'success': False,
            'message': f'Error: {str(e)}',
            'customer': None
        }


# Example usage and testing functions
def example_searches():
    """Example usage of the search_customers function"""
    
    print("=== Customer Search Examples ===\n")
    
    # Example 1: Basic search
    print("1. Search for 'ABC':")
    result1 = search_customers(search_term="ABC")
    print(f"   Found {result1['total_found']} customers")
    for customer in result1['customers'][:3]:  # Show first 3
        print(f"   - {customer['customer_name']} ({customer['customer_code']})")
    
    # Example 2: Company search
    print("\n2. Search companies containing 'Construction':")
    result2 = search_customers(search_term="Construction", customer_type="company")
    print(f"   Found {result2['total_found']} companies")
    for customer in result2['customers']:
        print(f"   - {customer['customer_name']} ({customer['customer_code']})")
    
    # Example 3: Individual search
    print("\n3. Search individuals:")
    result3 = search_customers(customer_type="individual", limit_results=5)
    print(f"   Found {result3['total_found']} individuals")
    for customer in result3['customers']:
        contact = f" - Contact: {customer['primary_contact_name']}" if customer['primary_contact_name'] else ""
        print(f"   - {customer['customer_name']} ({customer['customer_code']}){contact}")
    
    # Example 4: Search by customer code
    print("\n4. Search by code 'ABC001':")
    result4 = search_customers(search_term="ABC001")
    if result4['customers']:
        customer = result4['customers'][0]
        print(f"   - {customer['customer_name']} ({customer['customer_code']})")
        print(f"     Credit Limit: R{customer['credit_limit']}")
        print(f"     Payment Terms: {customer['payment_terms']}")
    
    # Example 5: Get customer by ID
    print("\n5. Get customer by ID 1001:")
    result5 = get_customer_by_id(1001)
    if result5['success']:
        customer = result5['customer']
        print(f"   - {customer['customer_name']} ({customer['customer_code']})")
    else:
        print(f"   - {result5['message']}")


def search_for_dropdown(search_term: str, limit: int = 10) -> List[Dict]:
    """
    Simplified search function perfect for dropdown/autocomplete components.
    Returns just the essential data needed for selection.
    """
    
    result = search_customers(
        search_term=search_term,
        limit_results=limit,
        include_contacts=False  # Faster without contact info
    )
    
    if result['success']:
        # Return simplified format perfect for dropdowns
        return [
            {
                'id': customer['customer_id'],
                'code': customer['customer_code'],
                'name': customer['customer_name'],
                'type': 'Company' if customer['is_company'] else 'Individual',
                'display': f"{customer['customer_name']} ({customer['customer_code']})"
            }
            for customer in result['customers']
        ]
    else:
        return []


def test_search_performance():
    """Test search performance with different query types"""
    import time
    
    print("=== Search Performance Tests ===\n")
    
    test_cases = [
        ("Empty search (all customers)", ""),
        ("Exact code match", "ABC001"),
        ("Partial name match", "ABC"),
        ("Company type filter", "Construction"),
        ("Full text search", "Building Supplies")
    ]
    
    for test_name, search_term in test_cases:
        start_time = time.time()
        result = search_customers(search_term=search_term, limit_results=20)
        end_time = time.time()
        
        print(f"{test_name}:")
        print(f"  Search term: '{search_term}'")
        print(f"  Results: {result['total_found']}")
        print(f"  Time: {(end_time - start_time)*1000:.2f}ms")
        print()


if __name__ == "__main__":
    # Run examples when script is executed directly
    example_searches()
    
    print("\n" + "="*50)
    test_search_performance()
    
    print("\n" + "="*50)
    print("=== Dropdown Search Example ===")
    dropdown_results = search_for_dropdown("ABC", 5)
    for item in dropdown_results:
        print(f"  {item['display']}")