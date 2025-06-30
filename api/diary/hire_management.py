# api/diary/hire_management.py
from flask import Blueprint, request, jsonify, current_app
from datetime import datetime
import logging
import os

# Import your existing database service
from api.database.database_service import DatabaseService, DatabaseError

# Import your existing service classes
from api.services.customer_service import CustomerService
from api.services.equipment_service import EquipmentService
from api.services.hire_service import HireService
from api.services.allocation_service import AllocationService
from api.services.driver_task_service import DriverTaskService
from api.services.quality_control_service import QualityControlService

# Setup logging
logger = logging.getLogger(__name__)

# Create blueprint
hire_bp = Blueprint('hire', __name__, url_prefix='/api/hire')

# Initialize database service
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://SYSTEM:SYSTEM@localhost:5432/task_management')
db_service = DatabaseService(DATABASE_URL)

# Initialize all services
customer_service = CustomerService(db_service)
equipment_service = EquipmentService(db_service)
hire_service = HireService(db_service)
allocation_service = AllocationService(db_service)
driver_task_service = DriverTaskService(db_service)
quality_control_service = QualityControlService(db_service)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def handle_api_error(error):
    """Enhanced error handling for API endpoints"""
    import traceback
    
    # Get logger
    logger = current_app.logger if current_app else logging.getLogger(__name__)
    
    # Log the error
    logger.error(f"API Error: {str(error)}")
    logger.error(f"Traceback: {traceback.format_exc()}")
    
    # Return appropriate response based on error type
    if isinstance(error, DatabaseError):
        return jsonify({
            'success': False,
            'error': 'Database operation failed',
            'procedure_name': getattr(error, 'procedure_name', None),
            'details': str(error) if current_app and current_app.debug else None
        }), 500
    elif isinstance(error, ValueError):
        return jsonify({
            'success': False,
            'error': 'Invalid input data',
            'details': str(error)
        }), 400
    else:
        return jsonify({
            'success': False,
            'error': 'Internal server error',
            'details': str(error) if current_app and current_app.debug else None
        }), 500

def get_current_user_id():
    """Get current user ID from session - replace with your auth logic"""
    return 1  # Replace with actual session-based user ID

def parse_date(date_str):
    """Parse date string to date object"""
    if date_str:
        return datetime.strptime(date_str, '%Y-%m-%d').date()
    return None

# =============================================================================
# CUSTOMER ENDPOINTS
# =============================================================================

@hire_bp.route('/customers', methods=['GET'])
def get_customers():
    """Get customer list for hire interface"""
    try:
        search_term = request.args.get('search')
        include_inactive = request.args.get('include_inactive', 'false').lower() == 'true'
        
        customers = customer_service.get_customers_for_selection(search_term, include_inactive)
        
        return jsonify({
            'success': True,
            'data': customers,
            'count': len(customers)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/customers/<int:customer_id>/contacts', methods=['GET'])
def get_customer_contacts(customer_id: int):
    """Get contacts for selected customer"""
    try:
        contacts = customer_service.get_customer_contacts(customer_id)
        
        return jsonify({
            'success': True,
            'data': contacts,
            'count': len(contacts)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/customers/<int:customer_id>/sites', methods=['GET'])
def get_customer_sites(customer_id: int):
    """Get delivery sites for customer"""
    try:
        sites = customer_service.get_customer_sites(customer_id)
        
        return jsonify({
            'success': True,
            'data': sites,
            'count': len(sites)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/customers/<int:customer_id>/summary', methods=['GET'])
def get_customer_summary(customer_id: int):
    """Get customer summary with contacts and sites"""
    try:
        summary = customer_service.get_customer_summary(customer_id)
        
        if not summary:
            return jsonify({
                'success': False,
                'error': 'Customer not found'
            }), 404
        
        return jsonify({
            'success': True,
            'data': summary
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# EQUIPMENT ENDPOINTS
# =============================================================================

@hire_bp.route('/equipment/types', methods=['GET'])
def get_equipment_types():
    """Get equipment types for Phase 1 - Generic booking"""
    try:
        search_term = request.args.get('search')
        delivery_date = parse_date(request.args.get('delivery_date'))
        
        equipment_types = equipment_service.get_equipment_types(search_term, delivery_date)
        
        return jsonify({
            'success': True,
            'data': equipment_types,
            'count': len(equipment_types)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/equipment/individual', methods=['GET'])
def get_individual_equipment():
    """Get individual equipment units for Phase 2 - Specific allocation"""
    try:
        equipment_type_id = request.args.get('type_id', type=int)
        delivery_date = parse_date(request.args.get('delivery_date'))
        
        equipment = equipment_service.get_individual_equipment(equipment_type_id, delivery_date)
        
        return jsonify({
            'success': True,
            'data': equipment,
            'count': len(equipment)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/equipment/accessories', methods=['POST'])
def get_equipment_accessories():
    """Get accessories for selected equipment types"""
    try:
        data = request.get_json()
        equipment_type_ids = data.get('equipment_type_ids', [])
        
        accessories = equipment_service.get_equipment_accessories(equipment_type_ids)
        
        return jsonify({
            'success': True,
            'data': accessories,
            'count': len(accessories)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/equipment/auto-accessories', methods=['POST'])
def calculate_auto_accessories():
    """Calculate default accessories for equipment selection"""
    try:
        data = request.get_json()
        equipment_selections = data.get('equipment_selections', [])
        
        auto_accessories = equipment_service.calculate_auto_accessories(equipment_selections)
        
        return jsonify({
            'success': True,
            'data': auto_accessories,
            'count': len(auto_accessories)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/equipment/availability', methods=['POST'])
def check_equipment_availability():
    """Check equipment availability for requested dates and quantities"""
    try:
        data = request.get_json()
        equipment_requests = data.get('equipment_requests', [])
        check_date = parse_date(data.get('check_date'))
        
        availability = equipment_service.check_equipment_availability(equipment_requests, check_date)
        
        return jsonify({
            'success': True,
            'data': availability,
            'count': len(availability)
        })
    except Exception as e:
        return handle_api_error(e)
    
@hire_bp.route('/equipment/accessories-complete', methods=['POST'])
def get_equipment_accessories_complete():
    """
    Get ALL accessories for selected equipment with proper quantities.
    This is the simple workflow endpoint that returns everything at once.
    """
    try:
        data = request.get_json()
        equipment_selections = data.get('equipment_selections', [])
        
        if not equipment_selections:
            return jsonify({
                'success': True,
                'data': [],
                'count': 0
            })
        
        # Get complete accessories list with proper quantities
        complete_accessories = equipment_service.get_equipment_accessories_complete(equipment_selections)
        
        return jsonify({
            'success': True,
            'data': complete_accessories,
            'count': len(complete_accessories)
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# NEW ACCESSORY ENDPOINTS
# =============================================================================

@hire_bp.route('/accessories/all', methods=['GET'])
def get_all_accessories():
    """Get all accessories in the system for standalone selection"""
    try:
        search_term = request.args.get('search')
        
        accessories = equipment_service.get_all_accessories(search_term)
        
        return jsonify({
            'success': True,
            'data': accessories,
            'count': len(accessories)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/equipment/accessories-with-defaults', methods=['POST'])
def get_equipment_accessories_with_defaults():
    """Get calculated default accessories plus all available optional accessories for equipment"""
    try:
        data = request.get_json()
        equipment_selections = data.get('equipment_selections', [])
        
        if not equipment_selections:
            return jsonify({
                'success': False,
                'error': 'Equipment selections are required'
            }), 400
        
        result = equipment_service.get_equipment_accessories_with_defaults(equipment_selections)
        
        return jsonify({
            'success': True,
            'data': result,
            'count': {
                'calculated_accessories': len(result['calculated_accessories']),
                'available_accessories': len(result['available_accessories'])
            }
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/accessories/validate', methods=['POST'])
def validate_accessory_selection():
    """Validate accessory selections for business rules and constraints"""
    try:
        data = request.get_json()
        accessory_selections = data.get('accessory_selections', [])
        
        validation_result = equipment_service.validate_accessory_selection(accessory_selections)
        
        return jsonify({
            'success': True,
            'data': validation_result
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# HIRE MANAGEMENT ENDPOINTS
# =============================================================================

@hire_bp.route('/hires/validate', methods=['POST'])
def validate_hire_request():
    """Validate hire request before creation"""
    try:
        hire_data = request.get_json()
        
        validation_result = hire_service.validate_hire_request(hire_data)
        
        return jsonify({
            'success': True,
            'data': validation_result
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/hires', methods=['POST'])
def create_hire():
    """Create new hire interaction"""
    try:
        process_data = request.get_json()
        employee_id = get_current_user_id()
        
        result = hire_service.create_hire_from_process_data(process_data, employee_id)
        
        if result.get('success', False):
            return jsonify({
                'success': True,
                'data': result,
                'message': result.get('message', 'Hire created successfully')
            })
        else:
            return jsonify({
                'success': False,
                'error': result.get('message', 'Failed to create hire'),
                'validation_errors': result.get('validation_errors', []),
                'warnings': result.get('warnings', [])
            }), 400
            
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/hires/<int:interaction_id>', methods=['GET'])
def get_hire_details(interaction_id: int):
    """Get complete hire interaction details"""
    try:
        hire_details = hire_service.get_hire_details(interaction_id)
        
        if not hire_details.get('interaction'):
            return jsonify({
                'success': False,
                'error': 'Hire interaction not found'
            }), 404
        
        return jsonify({
            'success': True,
            'data': hire_details
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/hires', methods=['GET'])
def get_hire_list():
    """Get paginated hire list with filters"""
    try:
        filters = {
            'date_from': parse_date(request.args.get('date_from')),
            'date_to': parse_date(request.args.get('date_to')),
            'status_filter': request.args.get('status'),
            'customer_filter': request.args.get('customer'),
            'search_term': request.args.get('search'),
            'limit': request.args.get('limit', 50, type=int),
            'offset': request.args.get('offset', 0, type=int)
        }
        
        hire_list = hire_service.get_hire_list(filters)
        
        return jsonify({
            'success': True,
            'data': hire_list,
            'count': len(hire_list),
            'filters_applied': {k: v for k, v in filters.items() if v is not None}
        })
        
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/hires/dashboard-summary', methods=['GET'])
def get_hire_dashboard_summary():
    """Get summary statistics for hire management dashboard"""
    try:
        date_from = parse_date(request.args.get('date_from'))
        date_to = parse_date(request.args.get('date_to'))
        
        summary = hire_service.get_hire_dashboard_summary(date_from, date_to)
        
        return jsonify({
            'success': True,
            'data': summary
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# ALLOCATION ENDPOINTS
# =============================================================================

@hire_bp.route('/allocations/bookings', methods=['GET'])
def get_bookings_for_allocation():
    """Get generic bookings ready for Phase 2 allocation"""
    try:
        interaction_id = request.args.get('interaction_id', type=int)
        only_unallocated = request.args.get('only_unallocated', 'true').lower() == 'true'
        
        bookings = allocation_service.get_bookings_for_allocation(interaction_id, only_unallocated)
        
        return jsonify({
            'success': True,
            'data': bookings,
            'count': len(bookings)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/allocations/equipment', methods=['GET'])
def get_equipment_for_allocation():
    """Get available equipment for allocation"""
    try:
        equipment_type_id = request.args.get('equipment_type_id', type=int)
        delivery_date = parse_date(request.args.get('delivery_date'))
        
        if not equipment_type_id:
            return jsonify({
                'success': False,
                'error': 'equipment_type_id is required'
            }), 400
        
        equipment = allocation_service.get_equipment_for_allocation(equipment_type_id, delivery_date)
        
        return jsonify({
            'success': True,
            'data': equipment,
            'count': len(equipment)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/allocations', methods=['POST'])
def allocate_equipment():
    """Allocate specific equipment to booking"""
    try:
        data = request.get_json()
        booking_id = data.get('booking_id')
        equipment_ids = data.get('equipment_ids', [])
        allocated_by = get_current_user_id()
        
        if not booking_id or not equipment_ids:
            return jsonify({
                'success': False,
                'error': 'booking_id and equipment_ids are required'
            }), 400
        
        result = allocation_service.allocate_equipment(booking_id, equipment_ids, allocated_by)
        
        return jsonify({
            'success': True,
            'data': result,
            'count': len(result)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/allocations/status/<int:interaction_id>', methods=['GET'])
def get_allocation_status(interaction_id: int):
    """Get allocation progress for interaction"""
    try:
        status = allocation_service.get_allocation_status(interaction_id)
        
        return jsonify({
            'success': True,
            'data': status
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# DRIVER TASK ENDPOINTS
# =============================================================================

@hire_bp.route('/driver-tasks', methods=['GET'])
def get_driver_tasks():
    """Get driver tasks for the drivers taskboard"""
    try:
        filters = {
            'driver_id': request.args.get('driver_id', type=int),
            'status_filter': request.args.get('status'),
            'date_from': parse_date(request.args.get('date_from')),
            'date_to': parse_date(request.args.get('date_to'))
        }
        
        tasks = driver_task_service.get_driver_tasks(**filters)
        
        return jsonify({
            'success': True,
            'data': tasks,
            'count': len(tasks)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/driver-tasks/taskboard', methods=['GET'])
def get_driver_taskboard_data():
    """Get comprehensive data for the drivers taskboard interface"""
    try:
        filters = {
            'driver_id': request.args.get('driver_id', type=int),
            'status_filter': request.args.get('status'),
            'date_from': parse_date(request.args.get('date_from')),
            'date_to': parse_date(request.args.get('date_to'))
        }
        
        taskboard_data = driver_task_service.get_driver_taskboard_data(filters)
        
        return jsonify({
            'success': True,
            'data': taskboard_data
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/driver-tasks/<int:task_id>', methods=['PUT'])
def update_driver_task(task_id: int):
    """Update driver task"""
    try:
        task_updates = request.get_json()
        
        result = driver_task_service.update_task_status(task_id, task_updates)
        
        return jsonify({
            'success': True,
            'data': result
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/driver-tasks/<int:task_id>/details', methods=['GET'])
def get_driver_task_details(task_id: int):
    """Get complete task details including equipment"""
    try:
        task_equipment = driver_task_service.get_task_equipment(task_id)
        
        return jsonify({
            'success': True,
            'data': task_equipment,
            'count': len(task_equipment)
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# QUALITY CONTROL ENDPOINTS
# =============================================================================

@hire_bp.route('/quality-control/pending', methods=['GET'])
def get_equipment_pending_qc():
    """Get equipment pending quality control"""
    try:
        interaction_id = request.args.get('interaction_id', type=int)
        employee_id = request.args.get('employee_id', type=int)
        
        pending_equipment = quality_control_service.get_equipment_pending_qc(interaction_id, employee_id)
        
        return jsonify({
            'success': True,
            'data': pending_equipment,
            'count': len(pending_equipment)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/quality-control/signoff', methods=['POST'])
def quality_control_signoff():
    """Process QC sign-off for equipment"""
    try:
        data = request.get_json()
        allocation_ids = data.get('allocation_ids', [])
        qc_status = data.get('qc_status', 'passed')
        notes = data.get('notes')
        employee_id = get_current_user_id()
        
        if not allocation_ids:
            return jsonify({
                'success': False,
                'error': 'allocation_ids are required'
            }), 400
        
        result = quality_control_service.quality_control_signoff(allocation_ids, employee_id, qc_status, notes)
        
        return jsonify({
            'success': True,
            'data': result,
            'count': len(result)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/quality-control/summary', methods=['GET'])
def get_qc_summary():
    """Get quality control statistics"""
    try:
        date_from = parse_date(request.args.get('date_from'))
        date_to = parse_date(request.args.get('date_to'))
        
        summary = quality_control_service.get_qc_summary(date_from, date_to)
        
        return jsonify({
            'success': True,
            'data': summary
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# TEST ENDPOINTS
# =============================================================================

@hire_bp.route('/test', methods=['GET'])
def test_services():
    """Test endpoint to verify all services are working"""
    try:
        # Test each service
        equipment_types = equipment_service.get_equipment_types()
        customers = customer_service.get_customers_for_selection()
        
        return jsonify({
            'success': True,
            'message': 'All services are working correctly',
            'data': {
                'equipment_types_count': len(equipment_types),
                'customers_count': len(customers),
                'database_connected': True,
                'services_loaded': [
                    'CustomerService',
                    'EquipmentService', 
                    'HireService',
                    'AllocationService',
                    'DriverTaskService',
                    'QualityControlService'
                ]
            }
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/test/accessories', methods=['GET'])
def test_accessories_endpoints():
    """Test the new accessory functionality"""
    try:
        # Test all accessories
        all_accessories = equipment_service.get_all_accessories()
        
        # Test with sample equipment
        sample_equipment = [
            {'equipment_type_id': 1, 'quantity': 2}
        ]
        
        # Test equipment accessories with defaults
        equipment_accessories = equipment_service.get_equipment_accessories_with_defaults(sample_equipment)
        
        # Test validation
        sample_selections = [
            {'accessory_id': 1, 'quantity': 2.0, 'accessory_type': 'default'}
        ]
        validation = equipment_service.validate_accessory_selection(sample_selections)
        
        return jsonify({
            'success': True,
            'test_results': {
                'all_accessories_count': len(all_accessories),
                'equipment_accessories': equipment_accessories,
                'validation_result': validation
            },
            'message': 'All accessory endpoints tested successfully'
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# ERROR HANDLERS
# =============================================================================

@hire_bp.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404

@hire_bp.errorhandler(405)
def method_not_allowed(error):
    return jsonify({
        'success': False,
        'error': 'Method not allowed'
    }), 405

@hire_bp.errorhandler(500)
def internal_error(error):
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500