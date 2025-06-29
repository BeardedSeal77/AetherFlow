# api/diary/drivers.py
"""
Drivers API - Standalone implementation for driver taskboard.
This replaces any old diary.py dependencies and integrates with the hire management system.
"""

from flask import Blueprint, request, jsonify, session
import logging
from datetime import datetime, date

# Import services directly
from api.database.database_service import DatabaseService, DatabaseError
from api.services.driver_task_service import DriverTaskService

logger = logging.getLogger(__name__)

# Create blueprint
drivers_bp = Blueprint('drivers', __name__)

# Database connection - should match your config
DB_CONNECTION_STRING = "postgresql://SYSTEM:SYSTEM@localhost:5432/task_management"

# Initialize services
db_service = DatabaseService(DB_CONNECTION_STRING)
driver_task_service = DriverTaskService(db_service)

def get_current_user_id():
    """Get current user ID from session"""
    # For now, return a default user ID - in production this would come from proper session management
    return session.get('currentUser', 2)  # Default to employee ID 2 (Sarah Johnson)

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

@drivers_bp.route('/', methods=['GET'])
def get_drivers_taskboard():
    """
    Get driver taskboard data in the format expected by the frontend.
    This is the main endpoint used by /diary/drivers page.
    """
    try:
        # Get filter parameters
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
        
        # Get taskboard data using the service
        taskboard_data = driver_task_service.get_driver_taskboard_data(filters)
        
        # Extract just the tasks in the format expected by the frontend
        all_tasks = []
        for status_column, tasks in taskboard_data['columns'].items():
            all_tasks.extend(tasks)
        
        return jsonify({
            'success': True,
            'tasks': all_tasks,
            'summary': taskboard_data['summary'],
            'columns': taskboard_data['columns']
        })
        
    except Exception as e:
        return handle_api_error(e)

@drivers_bp.route('/<int:task_id>', methods=['PUT'])
def update_driver_task(task_id: int):
    """
    Update a driver task.
    Accepts the DriverTask format from the frontend.
    """
    try:
        task_data = request.get_json()
        employee_id = get_current_user_id()
        
        # Use the service to update the task
        result = driver_task_service.update_task_from_frontend(task_id, task_data, employee_id)
        
        if result.get('success', False):
            return jsonify({
                'success': True,
                'data': result,
                'message': result.get('message', 'Task updated successfully')
            })
        else:
            return jsonify({
                'success': False,
                'error': result.get('message', 'Failed to update task')
            }), 400
            
    except Exception as e:
        return handle_api_error(e)

@drivers_bp.route('/<int:task_id>/move', methods=['PUT'])
def move_driver_task_status(task_id: int):
    """
    Move a task to a new status column (for drag & drop functionality).
    """
    try:
        data = request.get_json()
        new_status = data.get('status')
        employee_id = get_current_user_id()
        
        if not new_status:
            return jsonify({
                'success': False,
                'error': 'status is required'
            }), 400
        
        # Validate the transition
        validation = driver_task_service.validate_task_status_transition(task_id, new_status)
        if not validation.get('valid', False):
            status_code = 409 if validation.get('warning', False) else 400
            return jsonify({
                'success': False,
                'error': validation.get('message'),
                'warning': validation.get('warning', False)
            }), status_code
        
        # Move the task
        result = driver_task_service.move_task_to_status(task_id, new_status, employee_id)
        
        return jsonify({
            'success': True,
            'data': result
        })
        
    except Exception as e:
        return handle_api_error(e)

@drivers_bp.route('/<int:task_id>/details', methods=['GET'])
def get_driver_task_details(task_id: int):
    """
    Get detailed information about a specific driver task.
    Includes equipment details for the task modal.
    """
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

@drivers_bp.route('/summary', methods=['GET'])
def get_drivers_summary():
    """
    Get summary statistics for the drivers taskboard.
    """
    try:
        filters = {
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
            'data': taskboard_data['summary']
        })
        
    except Exception as e:
        return handle_api_error(e)

# Health check endpoint specific to drivers
@drivers_bp.route('/health', methods=['GET'])
def drivers_health_check():
    """Check if drivers API is working"""
    try:
        # Test database connection
        tasks = driver_task_service.get_driver_tasks()
        
        return jsonify({
            'success': True,
            'status': 'healthy',
            'tasks_count': len(tasks),
            'message': 'Drivers API is working correctly'
        })
    except Exception as e:
        return handle_api_error(e)