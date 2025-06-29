# api/diary/dashboard.py
from flask import Blueprint, request, jsonify, session
import logging
from datetime import datetime, date

# Import the hire management services
try:
    from api.diary.hire_management import hire_service, DatabaseError
    HIRE_MANAGEMENT_AVAILABLE = True
except ImportError:
    # Fallback for when hire management isn't set up yet
    HIRE_MANAGEMENT_AVAILABLE = False
    print("Warning: Hire management services not available. Using legacy mode.")

logger = logging.getLogger(__name__)

dashboard_bp = Blueprint('dashboard', __name__)

def handle_api_error(error: Exception) -> tuple:
    """Standard error handler for API endpoints"""
    if HIRE_MANAGEMENT_AVAILABLE and isinstance(error, DatabaseError):
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

@dashboard_bp.route('/dashboard', methods=['GET'])
def get_dashboard_data():
    """
    Get dashboard data for the diary section.
    This provides task summaries and statistics.
    """
    try:
        if not HIRE_MANAGEMENT_AVAILABLE:
            # Return mock data for backward compatibility
            return jsonify({
                'success': True,
                'tasks': [
                    {
                        'id': '1',
                        'title': 'Sample Task',
                        'status': 'Backlog'
                    }
                ],
                'message': 'Using mock data - hire management services not yet configured'
            })
        
        # Get date range for dashboard
        date_from_str = request.args.get('date_from')
        date_to_str = request.args.get('date_to')
        
        date_from = None
        date_to = None
        if date_from_str:
            date_from = datetime.strptime(date_from_str, '%Y-%m-%d').date()
        if date_to_str:
            date_to = datetime.strptime(date_to_str, '%Y-%m-%d').date()
        
        # Get hire dashboard summary
        summary = hire_service.get_hire_dashboard_summary(date_from, date_to)
        
        # Transform for frontend TaskBoard component
        # The existing TaskBoard expects tasks with id, title, status
        mock_tasks = []
        
        # Create mock tasks based on summary data
        if summary.get('pending_hires', 0) > 0:
            mock_tasks.append({
                'id': 'pending-hires',
                'title': f"{summary['pending_hires']} Pending Hires",
                'status': 'Backlog'
            })
        
        if summary.get('pending_allocations', 0) > 0:
            mock_tasks.append({
                'id': 'pending-allocations',
                'title': f"{summary['pending_allocations']} Pending Allocations",
                'status': 'In Progress'
            })
        
        if summary.get('pending_qc', 0) > 0:
            mock_tasks.append({
                'id': 'pending-qc',
                'title': f"{summary['pending_qc']} Pending QC",
                'status': 'In Review'
            })
        
        if summary.get('completed_hires', 0) > 0:
            mock_tasks.append({
                'id': 'completed-hires',
                'title': f"{summary['completed_hires']} Completed Hires",
                'status': 'Completed'
            })
        
        return jsonify({
            'success': True,
            'tasks': mock_tasks,
            'summary': summary
        })
        
    except Exception as e:
        return handle_api_error(e)