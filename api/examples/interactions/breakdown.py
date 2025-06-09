import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Optional, Union
import json

def create_breakdown(
    # Required fields
    customer_id: int,
    contact_id: int,
    site_id: int,
    equipment_list: List[Dict],      # [{"equipment_category_id": 5, "quantity": 1, "issue_description": "..."}]
    issue_description: str,
    
    # Optional fields
    urgency_level: str = 'medium',   # 'low', 'medium', 'high', 'critical'
    resolution_type: str = 'swap',   # 'swap', 'repair_onsite', 'collect_repair'
    work_impact: Optional[str] = None,
    customer_contact_onsite: Optional[str] = None,
    customer_phone_onsite: Optional[str] = None,
    breakdown_date: Optional[str] = None,  # ISO string or None for current time
    contact_method: str = 'phone',
    initial_notes: Optional[str] = None,
    
    # System
    employee_id: Optional[int] = None,
    session_token: Optional[str] = None,
    
    # Database connection
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Create a breakdown report for equipment failures at customer sites.
    
    Args:
        customer_id: ID of the customer reporting breakdown
        contact_id: ID of the contact person reporting breakdown
        site_id: ID of the site where breakdown occurred
        equipment_list: List of equipment items broken down
            Format: [{"equipment_category_id": 5, "quantity": 1, "issue_description": "Won't start"}]
        issue_description: Overall description of the breakdown
        urgency_level: Priority level - 'low', 'medium', 'high', 'critical'
        resolution_type: How to resolve - 'swap', 'repair_onsite', 'collect_repair'
        work_impact: Description of how breakdown impacts customer's work
        customer_contact_onsite: Name of person at site for driver contact
        customer_phone_onsite: Phone number of person at site
        breakdown_date: When breakdown occurred (ISO string, None = now)
        contact_method: How customer contacted us
        initial_notes: Additional notes about the breakdown report
        employee_id: Employee processing the breakdown
        session_token: Alternative authentication
        
    Returns:
        Dictionary with:
        {
            'success': bool,
            'message': str,
            'interaction_id': int or None,
            'reference_number': str or None,
            'breakdown_component_id': int or None,
            'driver_task_id': int or None,
            'assigned_driver': str or None,
            'estimated_response_time': str or None
        }
    """
    
    try:
        # Input validation
        valid_urgency_levels = ['low', 'medium', 'high', 'critical']
        if urgency_level not in valid_urgency_levels:
            return {
                'success': False,
                'message': f'Invalid urgency level. Must be one of: {", ".join(valid_urgency_levels)}',
                'interaction_id': None,
                'reference_number': None,
                'breakdown_component_id': None,
                'driver_task_id': None,
                'assigned_driver': None,
                'estimated_response_time': None
            }
        
        valid_resolution_types = ['swap', 'repair_onsite', 'collect_repair']
        if resolution_type not in valid_resolution_types:
            return {
                'success': False,
                'message': f'Invalid resolution type. Must be one of: {", ".join(valid_resolution_types)}',
                'interaction_id': None,
                'reference_number': None,
                'breakdown_component_id': None,
                'driver_task_id': None,
                'assigned_driver': None,
                'estimated_response_time': None
            }
        
        valid_contact_methods = ['phone', 'email', 'in_person', 'whatsapp', 'online', 'other']
        if contact_method not in valid_contact_methods:
            return {
                'success': False,
                'message': f'Invalid contact method. Must be one of: {", ".join(valid_contact_methods)}',
                'interaction_id': None,
                'reference_number': None,
                'breakdown_component_id': None,
                'driver_task_id': None,
                'assigned_driver': None,
                'estimated_response_time': None
            }
        
        # Validate equipment list
        if not equipment_list or len(equipment_list) == 0:
            return {
                'success': False,
                'message': 'At least one piece of equipment must be selected',
                'interaction_id': None,
                'reference_number': None,
                'breakdown_component_id': None,
                'driver_task_id': None,
                'assigned_driver': None,
                'estimated_response_time': None
            }
        
        # Validate each equipment item
        for i, equipment in enumerate(equipment_list):
            if 'equipment_category_id' not in equipment:
                return {
                    'success': False,
                    'message': f'Equipment item {i+1} missing equipment_category_id',
                    'interaction_id': None,
                    'reference_number': None,
                    'breakdown_component_id': None,
                    'driver_task_id': None,
                    'assigned_driver': None,
                    'estimated_response_time': None
                }
            
            if 'quantity' not in equipment:
                equipment['quantity'] = 1  # Default quantity
            
            # Ensure issue_description exists
            if 'issue_description' not in equipment:
                equipment['issue_description'] = issue_description
        
        # Connect to database
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Convert equipment list to JSONB
        equipment_jsonb = json.dumps(equipment_list)
        
        # Handle breakdown_date conversion
        breakdown_timestamp = None
        if breakdown_date:
            # If string provided, use it; otherwise let database use current timestamp
            breakdown_timestamp = breakdown_date
        
        # Call the stored procedure
        cursor.execute("""
            SELECT * FROM interactions.create_breakdown(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
        """, (
            customer_id,
            contact_id,
            site_id,
            equipment_jsonb,
            issue_description,
            urgency_level,
            resolution_type,
            work_impact,
            customer_contact_onsite,
            customer_phone_onsite,
            breakdown_timestamp,
            contact_method,
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
            'breakdown_component_id': result['breakdown_component_id'],
            'driver_task_id': result['driver_task_id'],
            'assigned_driver': result['assigned_driver'],
            'estimated_response_time': result['estimated_response_time']
        }
        
    except psycopg2.Error as e:
        # Database error
        return {
            'success': False,
            'message': f'Database error: {str(e)}',
            'interaction_id': None,
            'reference_number': None,
            'breakdown_component_id': None,
            'driver_task_id': None,
            'assigned_driver': None,
            'estimated_response_time': None
        }
        
    except Exception as e:
        # General error
        return {
            'success': False,
            'message': f'System error: {str(e)}',
            'interaction_id': None,
            'reference_number': None,
            'breakdown_component_id': None,
            'driver_task_id': None,
            'assigned_driver': None,
            'estimated_response_time': None
        }


# Helper functions for the breakdown workflow
def search_equipment_for_breakdown(
    customer_id: int,
    search_term: Optional[str] = None,
    site_filter: Optional[int] = None,
    equipment_filter: Optional[str] = None,
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Search for equipment that can be reported as broken down for a customer.
    This is the main function for populating the equipment selection dropdown.
    """
    
    try:
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM core.search_equipment_for_breakdown(%s, %s, %s, %s)
        """, (customer_id, search_term, site_filter, equipment_filter))
        
        equipment = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        # Convert to list of dictionaries
        equipment_list = [dict(item) for item in equipment]
        
        return {
            'success': True,
            'message': f'Found {len(equipment_list)} equipment items available for breakdown reporting',
            'equipment': equipment_list,
            'total_found': len(equipment_list)
        }
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Error searching equipment: {str(e)}',
            'equipment': [],
            'total_found': 0
        }


def get_customer_sites_for_breakdown(
    customer_id: int,
    search_term: Optional[str] = None,
    db_connection_string: str = "postgresql://username:password@localhost:5432/task_management"
) -> Dict:
    """
    Get customer sites for breakdown site selection.
    """
    
    try:
        conn = psycopg2.connect(db_connection_string)
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        cursor.execute("""
            SELECT * FROM core.get_customer_sites(%s, NULL, %s, true)
        """, (customer_id, search_term))
        
        sites = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        # Convert to list of dictionaries
        sites_list = [dict(site) for site in sites]
        
        # Format dates to ISO string
        for site in sites_list:
            if site['created_at']:
                site['created_at'] = site['created_at'].isoformat()
        
        return {
            'success': True,
            'message': f'Found {len(sites_list)} sites for customer',
            'sites': sites_list,
            'total_found': len(sites_list)
        }
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Error retrieving sites: {str(e)}',
            'sites': [],
            'total_found': 0
        }


# Example usage and testing functions
def example_breakdown_scenarios():
    """Example usage showing different breakdown scenarios"""
    
    print("=== Breakdown Processing Examples ===\n")
    
    # Example 1: John Guy's rammer breakdown (your scenario)
    print("1. John Guy's Rammer Breakdown (High Priority):")
    result1 = create_breakdown(
        customer_id=1000,  # ABC Construction
        contact_id=1000,   # John Guy
        site_id=1001,      # Sandton Project Site
        equipment_list=[
            {
                "equipment_category_id": 5,
                "quantity": 1,
                "issue_description": "Rammer stopped working, won't start"
            }
        ],
        issue_description="Rammer HR-250 stopped working completely. Customer reports it was working fine yesterday, but today it won't start at all. Blocking critical concrete work.",
        urgency_level="high",
        resolution_type="swap",
        work_impact="Blocking critical concrete pouring work - project delayed",
        customer_contact_onsite="John Guy",
        customer_phone_onsite="+27111234567",
        contact_method="phone",
        initial_notes="Customer called at 2:30 PM reporting urgent breakdown",
        employee_id=1001
    )
    
    if result1['success']:
        print(f"   ✅ SUCCESS: {result1['message']}")
        print(f"   Reference: {result1['reference_number']}")
        print(f"   Driver Task: {result1['driver_task_id']}")
        print(f"   Assigned Driver: {result1['assigned_driver']}")
        print(f"   Response Time: {result1['estimated_response_time']}")
    else:
        print(f"   ❌ FAILED: {result1['message']}")
    
    # Example 2: Critical breakdown (safety issue)
    print("\n2. Critical Safety Breakdown:")
    result2 = create_breakdown(
        customer_id=1001,
        contact_id=1002,
        site_id=1002,
        equipment_list=[
            {
                "equipment_category_id": 8,
                "quantity": 1,
                "issue_description": "Crane boom stuck, cannot lower"
            }
        ],
        issue_description="CRITICAL: Crane boom stuck in raised position, safety hazard, site evacuation required",
        urgency_level="critical",
        resolution_type="repair_onsite",
        work_impact="SAFETY HAZARD - Site evacuated, work stopped completely",
        customer_contact_onsite="Site Safety Officer",
        customer_phone_onsite="+27111234999",
        contact_method="phone",
        initial_notes="EMERGENCY CALL - Site safety officer reports critical equipment failure",
        employee_id=1001
    )
    
    if result2['success']:
        print(f"   ✅ SUCCESS: {result2['message']}")
        print(f"   Reference: {result2['reference_number']}")
        print(f"   Response Time: {result2['estimated_response_time']}")
    else:
        print(f"   ❌ FAILED: {result2['message']}")
    
    # Example 3: Multiple equipment breakdown
    print("\n3. Multiple Equipment Breakdown:")
    result3 = create_breakdown(
        customer_id=1000,
        contact_id=1000,
        site_id=1001,
        equipment_list=[
            {
                "equipment_category_id": 3,
                "quantity": 1,
                "issue_description": "Excavator hydraulics leaking"
            },
            {
                "equipment_category_id": 7,
                "quantity": 2,
                "issue_description": "Both compactors overheating"
            }
        ],
        issue_description="Multiple equipment failures at construction site. Excavator has hydraulic leak, both compactors overheating.",
        urgency_level="medium",
        resolution_type="repair_onsite",
        work_impact="Slowing down construction progress",
        customer_contact_onsite="Site Foreman",
        customer_phone_onsite="+27112345678",
        contact_method="email",
        initial_notes="Customer emailed breakdown report with photos",
        employee_id=1002
    )
    
    if result3['success']:
        print(f"   ✅ SUCCESS: {result3['message']}")
        print(f"   Equipment Count: {len(result3) if 'equipment_list' in locals() else 'Multiple'}")
    else:
        print(f"   ❌ FAILED: {result3['message']}")


def breakdown_workflow_example():
    """Show the complete breakdown workflow from search to creation"""
    
    print("=== Complete Breakdown Workflow ===\n")
    
    customer_id = 1000  # ABC Construction
    
    print("Step 1: Employee selects customer ABC Construction")
    print(f"Customer ID: {customer_id}")
    
    # Step 2: Get customer sites
    print("\nStep 2: Get available sites for breakdown location")
    sites = get_customer_sites_for_breakdown(customer_id)
    
    if sites['success']:
        print(f"✅ Found {sites['total_found']} sites:")
        for site in sites['sites'][:3]:  # Show first 3
            print(f"   - {site['site_name']} ({site['site_type']}) - {site['full_address']}")
    
    # Step 3: Search equipment for breakdown
    print("\nStep 3: Search equipment available for breakdown reporting")
    equipment = search_equipment_for_breakdown(customer_id, "rammer")
    
    if equipment['success']:
        print(f"✅ Found {equipment['total_found']} equipment items:")
        for item in equipment['equipment'][:3]:  # Show first 3
            print(f"   - {item['display_text']}")
            print(f"     Status: {item['equipment_status']}")
            print(f"     Can Report: {'Yes' if item['can_report_breakdown'] else 'No'}")
    
    # Step 4: Employee selects equipment and creates breakdown
    print("\nStep 4: Employee selects equipment and reports breakdown")
    
    if equipment['success'] and len(equipment['equipment']) > 0:
        selected_equipment = equipment['equipment'][0]
        site_id = selected_equipment['site_id']
        equipment_id = selected_equipment['equipment_category_id']
        
        # Create breakdown using selected equipment
        breakdown_result = create_breakdown(
            customer_id=customer_id,
            contact_id=1000,  # John Guy
            site_id=site_id,
            equipment_list=[
                {
                    "equipment_category_id": equipment_id,
                    "quantity": 1,
                    "issue_description": "Equipment stopped working"
                }
            ],
            issue_description="Equipment failure reported by customer",
            urgency_level="high",
            resolution_type="swap",
            customer_contact_onsite="John Guy",
            customer_phone_onsite="+27111234567",
            employee_id=1001
        )
        
        if breakdown_result['success']:
            print(f"✅ Breakdown created: {breakdown_result['reference_number']}")
            print(f"   Driver assigned: {breakdown_result['assigned_driver']}")
            print(f"   Response time: {breakdown_result['estimated_response_time']}")
        else:
            print(f"❌ Breakdown creation failed: {breakdown_result['message']}")
    
    print("\n📋 Workflow complete! From customer selection to driver assignment.")


def test_breakdown_creation():
    """Simple test function"""
    
    print("=== Simple Breakdown Test ===\n")
    
    result = create_breakdown(
        customer_id=1000,
        contact_id=1000,
        site_id=1001,
        equipment_list=[
            {
                "equipment_category_id": 5,
                "quantity": 1,
                "issue_description": "Test breakdown"
            }
        ],
        issue_description="Test breakdown for system validation",
        urgency_level="low",
        employee_id=1  # System user
    )
    
    if result['success']:
        print(f"✅ SUCCESS: {result['message']}")
        print(f"   Reference Number: {result['reference_number']}")
        print(f"   Interaction ID: {result['interaction_id']}")
        print(f"   Driver Task ID: {result['driver_task_id']}")
        print(f"   Response Time: {result['estimated_response_time']}")
    else:
        print(f"❌ FAILED: {result['message']}")
    
    return result


# Helper function for Flask routes
def process_breakdown_form(form_data: Dict, employee_id: int) -> Dict:
    """
    Process breakdown form data from Flask frontend.
    
    Args:
        form_data: Dictionary with form fields
        employee_id: ID of employee processing the breakdown
        
    Returns:
        Result dictionary ready for JSON response
    """
    
    try:
        # Extract equipment list from form
        equipment_list = []
        if 'equipment_items' in form_data:
            for item in form_data['equipment_items']:
                equipment_list.append({
                    'equipment_category_id': item.get('equipment_id'),
                    'quantity': item.get('quantity', 1),
                    'issue_description': item.get('issue_description', '')
                })
        
        result = create_breakdown(
            customer_id=form_data.get('customer_id'),
            contact_id=form_data.get('contact_id'),
            site_id=form_data.get('site_id'),
            equipment_list=equipment_list,
            issue_description=form_data.get('issue_description'),
            urgency_level=form_data.get('urgency_level', 'medium'),
            resolution_type=form_data.get('resolution_type', 'swap'),
            work_impact=form_data.get('work_impact'),
            customer_contact_onsite=form_data.get('customer_contact_onsite'),
            customer_phone_onsite=form_data.get('customer_phone_onsite'),
            contact_method=form_data.get('contact_method', 'phone'),
            initial_notes=form_data.get('initial_notes'),
            employee_id=employee_id
        )
        
        # Add additional info for frontend
        if result['success']:
            result['next_steps'] = [
                f"Breakdown {result['reference_number']} has been logged",
                f"Driver response time target: {result['estimated_response_time']}",
                f"Driver assigned: {result['assigned_driver']}" if result['assigned_driver'] else "Driver will be assigned based on priority",
                "Customer will be notified when driver is dispatched"
            ]
        
        return result
        
    except Exception as e:
        return {
            'success': False,
            'message': f'Form processing error: {str(e)}',
            'interaction_id': None,
            'reference_number': None,
            'breakdown_component_id': None,
            'driver_task_id': None,
            'assigned_driver': None,
            'estimated_response_time': None
        }


if __name__ == "__main__":
    # Run examples when script is executed directly
    example_breakdown_scenarios()
    
    print("\n" + "="*60)
    breakdown_workflow_example()
    
    print("\n" + "="*60)
    test_breakdown_creation()