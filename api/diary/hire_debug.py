# api/diary/hire_debug.py
"""
Debug endpoints to test hire system and troubleshoot issues.
"""

from flask import Blueprint, request, jsonify
import logging

# Import services directly
from api.database.database_service import DatabaseService, DatabaseError

logger = logging.getLogger(__name__)

# Create blueprint
hire_debug_bp = Blueprint('hire_debug', __name__)

# Database connection - should match your config
DB_CONNECTION_STRING = "postgresql://SYSTEM:SYSTEM@localhost:5432/task_management"

# Initialize services
db_service = DatabaseService(DB_CONNECTION_STRING)

@hire_debug_bp.route('/test-db', methods=['GET'])
def test_database_connection():
    """Test basic database connection"""
    try:
        result = db_service.execute_query("SELECT 1 as test")
        return jsonify({
            'success': True,
            'message': 'Database connection successful',
            'data': result
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Database connection failed: {str(e)}'
        }), 500

@hire_debug_bp.route('/test-interactions', methods=['GET'])
def test_interactions_table():
    """Test interactions table directly"""
    try:
        # Query interactions table directly
        result = db_service.execute_query("""
            SELECT 
                i.id,
                i.reference_number,
                i.interaction_type,
                i.status,
                c.customer_name,
                i.created_at
            FROM interactions.interactions i
            JOIN core.customers c ON i.customer_id = c.id
            WHERE i.interaction_type = 'hire'
            ORDER BY i.created_at DESC
            LIMIT 10
        """)
        
        return jsonify({
            'success': True,
            'message': f'Found {len(result)} hire interactions',
            'data': result
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Query failed: {str(e)}'
        }), 500

@hire_debug_bp.route('/test-hire-details/<int:interaction_id>', methods=['GET'])
def test_hire_details(interaction_id: int):
    """Test getting hire details for a specific interaction"""
    try:
        # Get interaction details
        interaction_query = """
            SELECT 
                i.id as interaction_id,
                i.reference_number,
                i.status as interaction_status,
                c.customer_name,
                ct.first_name || ' ' || ct.last_name as contact_name,
                ct.phone_number as contact_phone,
                ct.email as contact_email,
                dt.site_address,
                dt.scheduled_date as delivery_date,
                dt.scheduled_time::text as delivery_time,  -- Convert time to string
                i.notes,
                i.created_at,
                emp.name || ' ' || emp.surname as employee_name
            FROM interactions.interactions i
            JOIN core.customers c ON i.customer_id = c.id
            JOIN core.contacts ct ON i.contact_id = ct.id
            JOIN core.employees emp ON i.employee_id = emp.id
            LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
            WHERE i.id = %s
        """
        
        interaction_result = db_service.execute_query(interaction_query, [interaction_id])
        
        # Get equipment details
        equipment_query = """
            SELECT 
                iet.equipment_type_id,
                et.type_name,
                et.type_code,
                iet.quantity as booked_quantity,
                COUNT(ie.id) as allocated_quantity,
                iet.booking_status,
                iet.hire_start_date,
                iet.hire_end_date
            FROM interactions.interaction_equipment_types iet
            JOIN core.equipment_types et ON iet.equipment_type_id = et.id
            LEFT JOIN interactions.interaction_equipment ie ON iet.id = ie.equipment_type_booking_id
            WHERE iet.interaction_id = %s
            GROUP BY iet.id, iet.equipment_type_id, et.type_name, et.type_code, iet.quantity, iet.booking_status, iet.hire_start_date, iet.hire_end_date
        """
        
        equipment_result = db_service.execute_query(equipment_query, [interaction_id])
        
        # Get accessories details
        accessories_query = """
            SELECT 
                ia.accessory_id,
                a.accessory_name,
                ia.quantity,
                ia.accessory_type,
                a.billing_method,
                a.is_consumable,
                et.type_name as equipment_type_name
            FROM interactions.interaction_accessories ia
            JOIN core.accessories a ON ia.accessory_id = a.id
            LEFT JOIN core.equipment_types et ON a.equipment_type_id = et.id
            WHERE ia.interaction_id = %s
        """
        
        accessories_result = db_service.execute_query(accessories_query, [interaction_id])
        
        return jsonify({
            'success': True,
            'data': {
                'interaction': interaction_result[0] if interaction_result else None,
                'equipment': equipment_result,
                'accessories': accessories_result,
                'total_equipment_items': len(equipment_result),
                'total_accessories': len(accessories_result)
            }
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Query failed: {str(e)}'
        }), 500

@hire_debug_bp.route('/test-stored-procedures', methods=['GET'])
def test_stored_procedures():
    """Test if stored procedures exist and work"""
    try:
        # Check if our stored procedures exist
        procedures_query = """
            SELECT 
                n.nspname as schema,
                p.proname as procedure_name,
                pg_get_function_arguments(p.oid) as arguments
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE p.proname LIKE 'sp_get_hire%'
            ORDER BY n.nspname, p.proname
        """
        
        procedures_result = db_service.execute_query(procedures_query)
        
        # Test sp_get_hire_list specifically
        test_results = []
        
        try:
            # Test the stored procedure with default parameters
            hire_list_result = db_service.execute_procedure('sp_get_hire_list', [
                None,  # date_from
                None,  # date_to  
                None,  # status_filter
                None,  # customer_filter
                None,  # search_term
                50,    # limit
                0      # offset
            ])
            test_results.append({
                'procedure': 'sp_get_hire_list',
                'success': True,
                'result_count': len(hire_list_result),
                'sample_data': hire_list_result[:2] if hire_list_result else []
            })
        except Exception as e:
            test_results.append({
                'procedure': 'sp_get_hire_list',
                'success': False,
                'error': str(e)
            })
        
        return jsonify({
            'success': True,
            'message': f'Found {len(procedures_result)} hire-related stored procedures',
            'procedures': procedures_result,
            'test_results': test_results
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Query failed: {str(e)}'
        }), 500

@hire_debug_bp.route('/test-date-ranges', methods=['GET'])
def test_date_ranges():
    """Test different date ranges to see where our data falls"""
    try:
        # Check when our sample interaction was created
        interaction_query = """
            SELECT 
                id,
                reference_number,
                created_at,
                created_at::date as created_date,
                CURRENT_DATE as today,
                CURRENT_DATE - INTERVAL '30 days' as default_from,
                CURRENT_DATE + INTERVAL '7 days' as default_to
            FROM interactions.interactions 
            WHERE interaction_type = 'hire'
            ORDER BY created_at DESC
        """
        
        interactions = db_service.execute_query(interaction_query)
        
        # Test sp_get_hire_list with different date ranges
        test_results = []
        
        # Test 1: Default parameters (NULL dates)
        try:
            result1 = db_service.execute_procedure('sp_get_hire_list', [None, None, None, None, None, 50, 0])
            test_results.append({
                'test': 'Default NULL dates',
                'count': len(result1),
                'parameters': [None, None, None, None, None, 50, 0]
            })
        except Exception as e:
            test_results.append({
                'test': 'Default NULL dates',
                'error': str(e),
                'parameters': [None, None, None, None, None, 50, 0]
            })
        
        # Test 2: Wide date range that includes our data
        try:
            result2 = db_service.execute_procedure('sp_get_hire_list', [
                '2025-01-01',  # Wide from date
                '2025-12-31',  # Wide to date
                None, None, None, 50, 0
            ])
            test_results.append({
                'test': 'Wide date range (2025-01-01 to 2025-12-31)',
                'count': len(result2),
                'sample_data': result2[:1] if result2 else [],
                'parameters': ['2025-01-01', '2025-12-31', None, None, None, 50, 0]
            })
        except Exception as e:
            test_results.append({
                'test': 'Wide date range',
                'error': str(e),
                'parameters': ['2025-01-01', '2025-12-31', None, None, None, 50, 0]
            })
        
        # Test 3: No date filtering at all (using very wide range)
        try:
            result3 = db_service.execute_procedure('sp_get_hire_list', [
                '2000-01-01',  # Very wide from date
                '2030-12-31',  # Very wide to date
                None, None, None, 50, 0
            ])
            test_results.append({
                'test': 'Very wide date range (2000-01-01 to 2030-12-31)',
                'count': len(result3),
                'sample_data': result3[:1] if result3 else [],
                'parameters': ['2000-01-01', '2030-12-31', None, None, None, 50, 0]
            })
        except Exception as e:
            test_results.append({
                'test': 'Very wide date range',
                'error': str(e),
                'parameters': ['2000-01-01', '2030-12-31', None, None, None, 50, 0]
            })
        
        return jsonify({
            'success': True,
            'interactions_in_db': interactions,
            'test_results': test_results,
            'message': f'Found {len(interactions)} interactions in database'
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Date range test failed: {str(e)}'
        }), 500

@hire_debug_bp.route('/test-hire-service', methods=['GET'])
def test_hire_service():
    """Test the hire service directly"""
    try:
        from api.services.hire_service import HireService
        
        hire_service = HireService(db_service)
        
        # Test with default filters
        filters = {
            'date_from': None,
            'date_to': None,
            'status_filter': None,
            'customer_filter': None,
            'search_term': None,
            'limit': 50,
            'offset': 0
        }
        
        result = hire_service.get_hire_list(filters)
        
        return jsonify({
            'success': True,
            'message': f'Hire service returned {len(result)} results',
            'data': result,
            'filters_used': filters
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Hire service test failed: {str(e)}',
            'error_type': type(e).__name__
        }), 500

@hire_debug_bp.route('/simple-hire-list', methods=['GET'])
def simple_hire_list():
    """Get hire list using simple query (no stored procedure)"""
    try:
        # Simple query to get hire interactions
        query = """
            SELECT 
                i.id as interaction_id,
                i.reference_number,
                i.status,
                c.customer_name,
                ct.first_name || ' ' || ct.last_name as contact_name,
                i.created_at,
                dt.scheduled_date as delivery_date,
                dt.status as driver_status
            FROM interactions.interactions i
            JOIN core.customers c ON i.customer_id = c.id
            JOIN core.contacts ct ON i.contact_id = ct.id
            LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
            WHERE i.interaction_type = 'hire'
            ORDER BY i.created_at DESC
            LIMIT 50
        """
        
        result = db_service.execute_query(query)
        
        return jsonify({
            'success': True,
            'data': result,
            'count': len(result),
            'message': f'Found {len(result)} hire interactions using simple query'
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Simple query failed: {str(e)}'
        }), 500