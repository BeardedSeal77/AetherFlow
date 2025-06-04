from flask import Blueprint, jsonify, request, session
from api.diary.drivers import get_driver_tasks, update_driver_task
from api.diary.dashboard import load_tasks
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

diary_bp = Blueprint('diary', __name__)

@diary_bp.route('/test', methods=['GET'])
def test():
    """Test endpoint to verify the diary API is working."""
    return jsonify({
        "status": "success",
        "message": "Diary API is working correctly",
        "session": {
            "has_user": 'currentUser' in session,
            "username": session.get('currentUser', {}).get('username') if 'currentUser' in session else None
        }
    })

@diary_bp.route('/dashboard', methods=['GET'])
def dashboard():
    """Get all tasks for the current user."""
    try:
        # Get username from session
        if 'currentUser' not in session:
            logger.error("No user in session")
            return jsonify({"error": "Not authenticated"}), 401
            
        # In login.py, the session['currentUser'] is just the username string
        username = session['currentUser']
        logger.info(f"Loading dashboard for user: {username}")
            
        # Load tasks for the user
        tasks = load_tasks(username)
        return jsonify({"tasks": tasks})
        
    except Exception as e:
        logger.error(f"Error fetching dashboard tasks: {str(e)}")
        return jsonify({"error": str(e)}), 500

@diary_bp.route('/drivers', methods=['GET'])
def drivers():
    """Get all driver tasks for today."""
    try:
        tasks = get_driver_tasks()
        return jsonify({"tasks": tasks})
    except Exception as e:
        logger.error(f"Error fetching driver tasks: {str(e)}")
        return jsonify({"error": str(e)}), 500

@diary_bp.route('/drivers/<task_id>', methods=['PUT'])
def update_driver(task_id):
    """Update a driver task."""
    try:
        # Log the incoming request
        logger.info(f"Received update request for task {task_id}")
        logger.info(f"Request data: {request.data}")
        
        # Parse the incoming JSON data
        if not request.is_json:
            logger.error("Request does not contain JSON data")
            return jsonify({"error": "Request must be JSON"}), 400
            
        updated_task = request.get_json()
        
        # Validate the task data
        if not updated_task or 'id' not in updated_task or 'status' not in updated_task:
            logger.error(f"Invalid task data: {updated_task}")
            return jsonify({"error": "Invalid task data"}), 400
            
        # Ensure the ID in the URL matches the ID in the payload
        if task_id != updated_task['id']:
            logger.error(f"Task ID mismatch: URL {task_id} vs payload {updated_task['id']}")
            return jsonify({"error": "Task ID mismatch"}), 400
        
        # Call the update function
        result = update_driver_task(task_id, updated_task)
        
        if result.get("success", False):
            return jsonify(result), 200
        else:
            return jsonify(result), 500
            
    except Exception as e:
        logger.error(f"Error updating driver task {task_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500