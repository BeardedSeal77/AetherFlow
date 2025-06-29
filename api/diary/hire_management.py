# api/diary/hire_management.py
from flask import Blueprint, request, jsonify, session
from datetime import datetime, date
import logging
from typing import Dict, Any

# Import services
from api.database.database_service import DatabaseService, DatabaseError
from api.services.customer_service import CustomerService
from api.services.equipment_service import EquipmentService
from api.services.hire_service import HireService
from api.services.allocation_service import AllocationService
from api.services.driver_task_service import DriverTaskService
from api.services.quality_control_service import QualityControlService

logger = logging.getLogger(__name__)

# Create blueprint
hire_bp = Blueprint('hire', __name__)

# Database connection string - should come from config
DB_CONNECTION_STRING = "postgresql://SYSTEM:SYSTEM@localhost:5432/task_management"

# Initialize services
db_service = DatabaseService(DB_CONNECTION_STRING)
customer_service = CustomerService(db_service)
equipment_service = EquipmentService(db_service)
hire_service = HireService(db_service)
allocation_service = AllocationService(db_service)
driver_task_service = DriverTaskService(db_service)
qc_service = QualityControlService(db_service)

def get_current_user_id():
    """Get current user ID from session"""
    return session.get('currentUser', 'system')  # Default to system for now

def handle_api_error(error: Exception) -> tuple:
    """Standard error handler for API endpoints"""
    if isinstance(error, DatabaseError):
        logger.error(f"Database error: {error.message}")
        return jsonify({
            'success': False,
            'error': 'Database error occurred',
            'details': error.message if error.message else str(error)
        }), 500
    else:
        logger.error(f"Unexpected error: {str(error)}")
        return jsonify({
            'success': False,
            'error': 'An unexpected error occurred',
            'details': str(error)
        }), 500

# =============================================================================
# CUSTOMER SELECTION ENDPOINTS
# =============================================================================

@hire_bp.route('/customers', methods=['GET'])
def get_customers():
    """Get customer list for hire interface selection"""
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
# EQUIPMENT SELECTION ENDPOINTS
# =============================================================================

@hire_bp.route('/equipment/types', methods=['GET'])
def get_equipment_types():
    """Get equipment types for Phase 1 - Generic booking"""
    try:
        search_term = request.args.get('search')
        delivery_date_str = request.args.get('delivery_date')
        
        delivery_date = None
        if delivery_date_str:
            delivery_date = datetime.strptime(delivery_date_str, '%Y-%m-%d').date()
        
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
        delivery_date_str = request.args.get('delivery_date')
        
        delivery_date = None
        if delivery_date_str:
            delivery_date = datetime.strptime(delivery_date_str, '%Y-%m-%d').date()
        
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
        check_date_str = data.get('check_date')
        
        check_date = None
        if check_date_str:
            check_date = datetime.strptime(check_date_str, '%Y-%m-%d').date()
        
        availability = equipment_service.check_equipment_availability(equipment_requests, check_date)
        
        return jsonify({
            'success': True,
            'data': availability,
            'count': len(availability)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/equipment/selection-data', methods=['GET'])
def get_equipment_selection_data():
    """Get all data needed for equipment selection interface"""
    try:
        search_term = request.args.get('search')
        delivery_date_str = request.args.get('delivery_date')
        
        delivery_date = None
        if delivery_date_str:
            delivery_date = datetime.strptime(delivery_date_str, '%Y-%m-%d').date()
        
        selection_data = equipment_service.prepare_equipment_selection_data(search_term, delivery_date)
        
        return jsonify({
            'success': True,
            'data': selection_data
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
    """Create new hire interaction following the hire process"""
    try:
        process_data = request.get_json()
        employee_id = get_current_user_id()  # Get from session
        
        # Use the comprehensive hire creation method
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
        # Try using the service first
        try:
            hire_details = hire_service.get_hire_details(interaction_id)
        except Exception as service_error:
            logger.warning(f"Service method failed, using direct query: {service_error}")
            
            # Fallback to direct query
            from api.diary.hire_management import db_service
            
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
                    dt.scheduled_time::text as delivery_time,
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
            
            hire_details = {
                'interaction': interaction_result[0] if interaction_result else None,
                'equipment': equipment_result,
                'accessories': accessories_result,
                'total_equipment_items': len(equipment_result),
                'total_accessories': len(accessories_result)
            }
        
        if not hire_details.get('interaction'):
            return jsonify({
                'success': False,
                'error': 'Hire interaction not found'
            }), 404
        
        # Format for frontend display
        formatted_hire = {
            'hire': hire_details,
            'raw_details': hire_details
        }
        
        return jsonify({
            'success': True,
            'data': formatted_hire
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/hires', methods=['GET'])
def get_hire_list():
    """Get paginated hire list with filters"""
    try:
        filters = {
            'date_from': request.args.get('date_from'),
            'date_to': request.args.get('date_to'),
            'status_filter': request.args.get('status'),
            'customer_filter': request.args.get('customer'),
            'search_term': request.args.get('search'),
            'limit': request.args.get('limit', 50, type=int),
            'offset': request.args.get('offset', 0, type=int)
        }
        
        # Convert date strings
        if filters['date_from']:
            filters['date_from'] = datetime.strptime(filters['date_from'], '%Y-%m-%d').date()
        if filters['date_to']:
            filters['date_to'] = datetime.strptime(filters['date_to'], '%Y-%m-%d').date()
        
        # Use direct query instead of stored procedure for now
        try:
            hire_list = hire_service.get_hire_list(filters)
        except Exception as stored_proc_error:
            # Fallback to simple query if stored procedure fails
            logger.warning(f"Stored procedure failed, using fallback: {stored_proc_error}")
            
            # Simple direct query as fallback
            query = """
                SELECT 
                    i.id as interaction_id,
                    i.reference_number,
                    i.status,
                    c.customer_name,
                    ct.first_name || ' ' || ct.last_name as contact_name,
                    i.created_at,
                    dt.scheduled_date as delivery_date,
                    dt.status as driver_status,
                    'pending' as allocation_status,
                    'pending' as qc_status,
                    '' as equipment_summary
                FROM interactions.interactions i
                JOIN core.customers c ON i.customer_id = c.id
                JOIN core.contacts ct ON i.contact_id = ct.id
                LEFT JOIN tasks.drivers_taskboard dt ON i.id = dt.interaction_id
                WHERE i.interaction_type = 'hire'
                ORDER BY i.created_at DESC
                LIMIT %s OFFSET %s
            """
            
            from api.diary.hire_management import db_service
            hire_list = db_service.execute_query(query, [filters['limit'], filters['offset']])
        
        return jsonify({
            'success': True,
            'data': hire_list,
            'count': len(hire_list),
            'total_count': len(hire_list)  # Simplified for now
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/hires/dashboard-summary', methods=['GET'])
def get_hire_dashboard_summary():
    """Get summary statistics for hire management dashboard"""
    try:
        date_from_str = request.args.get('date_from')
        date_to_str = request.args.get('date_to')
        
        date_from = None
        date_to = None
        if date_from_str:
            date_from = datetime.strptime(date_from_str, '%Y-%m-%d').date()
        if date_to_str:
            date_to = datetime.strptime(date_to_str, '%Y-%m-%d').date()
        
        summary = hire_service.get_hire_dashboard_summary(date_from, date_to)
        
        return jsonify({
            'success': True,
            'data': summary
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/hires/creation-data', methods=['GET'])
def get_hire_creation_data():
    """Get all data needed for hire creation interface"""
    try:
        customer_id = request.args.get('customer_id', type=int)
        
        creation_data = hire_service.prepare_hire_creation_data(customer_id)
        
        return jsonify({
            'success': True,
            'data': creation_data
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# EQUIPMENT ALLOCATION ENDPOINTS
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
        delivery_date_str = request.args.get('delivery_date')
        
        if not equipment_type_id:
            return jsonify({
                'success': False,
                'error': 'equipment_type_id is required'
            }), 400
        
        delivery_date = None
        if delivery_date_str:
            delivery_date = datetime.strptime(delivery_date_str, '%Y-%m-%d').date()
        
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

@hire_bp.route('/allocations/bulk', methods=['POST'])
def process_bulk_allocation():
    """Process multiple equipment allocations in bulk"""
    try:
        data = request.get_json()
        allocations = data.get('allocations', [])
        allocated_by = get_current_user_id()
        
        result = allocation_service.process_bulk_allocation(allocations, allocated_by)
        
        return jsonify({
            'success': True,
            'data': result
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/allocations/status/<int:interaction_id>', methods=['GET'])
def get_allocation_status(interaction_id: int):
    """Get allocation progress for interaction"""
    try:
        status = allocation_service.get_allocation_status(interaction_id)
        summary = allocation_service.get_allocation_summary_for_interaction(interaction_id)
        
        return jsonify({
            'success': True,
            'data': {
                'status': status,
                'summary': summary
            }
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/allocations/interface-data', methods=['GET'])
def get_allocation_interface_data():
    """Get all data needed for the allocation interface"""
    try:
        interaction_id = request.args.get('interaction_id', type=int)
        
        interface_data = allocation_service.prepare_allocation_interface_data(interaction_id)
        
        return jsonify({
            'success': True,
            'data': interface_data
        })
    except Exception as e:
        return handle_api_error(e)

# =============================================================================
# DRIVER TASK ENDPOINTS (for Drivers Taskboard)
# =============================================================================

@hire_bp.route('/driver-tasks', methods=['GET'])
def get_driver_tasks():
    """Get driver tasks for the drivers taskboard"""
    try:
        filters = {
            'driver_id': request.args.get('driver_id', type=int),
            'status_filter': request.args.get('status'),
            'date_from': request.args.get('date_from'),
            'date_to': request.args.get('date_to')
        }
        
        # Convert date strings
        if filters['date_from']:
            filters['date_from'] = datetime.strptime(filters['date_from'], '%Y-%m-%d').date()
        if filters['date_to']:
            filters['date_to'] = datetime.strptime(filters['date_to'], '%Y-%m-%d').date()
        
        tasks = driver_task_service.get_driver_tasks(**filters)
        
        # Format for frontend (convert to DriverTask interface format)
        formatted_tasks = [driver_task_service.format_task_for_frontend(task) for task in tasks]
        
        return jsonify({
            'success': True,
            'data': formatted_tasks,
            'count': len(formatted_tasks)
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
            'date_from': request.args.get('date_from'),
            'date_to': request.args.get('date_to')
        }
        
        # Convert date strings
        if filters['date_from']:
            filters['date_from'] = datetime.strptime(filters['date_from'], '%Y-%m-%d').date()
        if filters['date_to']:
            filters['date_to'] = datetime.strptime(filters['date_to'], '%Y-%m-%d').date()
        
        taskboard_data = driver_task_service.get_driver_taskboard_data(filters)
        
        return jsonify({
            'success': True,
            'data': taskboard_data
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/driver-tasks/<int:task_id>', methods=['PUT'])
def update_driver_task(task_id: int):
    """Update driver task from frontend"""
    try:
        frontend_task = request.get_json()
        employee_id = get_current_user_id()
        
        result = driver_task_service.update_task_from_frontend(task_id, frontend_task, employee_id)
        
        return jsonify({
            'success': True,
            'data': result
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/driver-tasks/<int:task_id>/move', methods=['PUT'])
def move_driver_task(task_id: int):
    """Move task to new status (for drag & drop)"""
    try:
        data = request.get_json()
        new_status = data.get('status')
        employee_id = get_current_user_id()
        
        if not new_status:
            return jsonify({
                'success': False,
                'error': 'status is required'
            }), 400
        
        # Validate transition
        validation = driver_task_service.validate_task_status_transition(task_id, new_status)
        if not validation.get('valid', False):
            return jsonify({
                'success': False,
                'error': validation.get('message'),
                'warning': validation.get('warning', False)
            }), 400
        
        result = driver_task_service.move_task_to_status(task_id, new_status, employee_id)
        
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
        task_details = driver_task_service.get_task_details_with_equipment(task_id)
        
        if not task_details:
            return jsonify({
                'success': False,
                'error': 'Task not found'
            }), 404
        
        return jsonify({
            'success': True,
            'data': task_details
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
        
        pending_equipment = qc_service.get_equipment_pending_qc(interaction_id, employee_id)
        
        # Format for frontend
        formatted_equipment = [qc_service.format_qc_item_for_frontend(item) for item in pending_equipment]
        
        return jsonify({
            'success': True,
            'data': formatted_equipment,
            'count': len(formatted_equipment)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/quality-control/dashboard', methods=['GET'])
def get_qc_dashboard():
    """Get comprehensive QC dashboard data"""
    try:
        filters = {
            'interaction_id': request.args.get('interaction_id', type=int),
            'employee_id': request.args.get('employee_id', type=int),
            'date_from': request.args.get('date_from'),
            'date_to': request.args.get('date_to')
        }
        
        # Convert date strings
        if filters['date_from']:
            filters['date_from'] = datetime.strptime(filters['date_from'], '%Y-%m-%d').date()
        if filters['date_to']:
            filters['date_to'] = datetime.strptime(filters['date_to'], '%Y-%m-%d').date()
        
        dashboard_data = qc_service.get_qc_dashboard_data(filters)
        
        return jsonify({
            'success': True,
            'data': dashboard_data
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
        
        result = qc_service.quality_control_signoff(allocation_ids, employee_id, qc_status, notes)
        
        return jsonify({
            'success': True,
            'data': result,
            'count': len(result)
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/quality-control/bulk-signoff', methods=['POST'])
def process_bulk_qc_signoff():
    """Process multiple QC sign-offs in bulk"""
    try:
        data = request.get_json()
        qc_batch = data.get('qc_batch', [])
        employee_id = get_current_user_id()
        
        result = qc_service.process_bulk_qc_signoff(qc_batch, employee_id)
        
        return jsonify({
            'success': True,
            'data': result
        })
    except Exception as e:
        return handle_api_error(e)

@hire_bp.route('/quality-control/checklist/<int:equipment_type_id>', methods=['GET'])
def get_qc_checklist(equipment_type_id: int):
    """Get QC checklist template for equipment type"""
    try:
        checklist = qc_service.get_qc_checklist_template(equipment_type_id)
        
        return jsonify({
            'success': True,
            'data': checklist
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