# api/index.py
from flask import Flask, session, jsonify
from flask_cors import CORS
import logging
import os

# Import JSON encoder fix
from api.utils.json_serializer import configure_json_encoder

# Import existing blueprints
from api.auth.login import auth_bp

# Import hire management and drivers blueprints
from api.diary.hire_management import hire_bp
from api.diary.drivers import drivers_bp

# Import debug blueprint
from api.diary.hire_debug import hire_debug_bp

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'your_secret_key_change_in_production')

# Configure custom JSON encoder to handle date/time objects
configure_json_encoder(app)

# Enable CORS for frontend
CORS(app, supports_credentials=True)

# Register blueprints
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(hire_bp, url_prefix='/api/hire')  # Hire management routes
app.register_blueprint(drivers_bp, url_prefix='/api/diary/drivers')  # Drivers taskboard (legacy path)
app.register_blueprint(hire_debug_bp, url_prefix='/api/debug')  # Debug endpoints

@app.route('/api/auth/session')
def get_session():
    """Get current user session."""
    if 'currentUser' in session:
        # Format the user data to match the expected structure in frontend
        return jsonify({
            'user': {
                'username': session['currentUser'],
                'name': session['currentUser']  # You can customize this as needed
            }
        })
    return jsonify({'user': None})

@app.route('/api/test')
def test_api():
    """Test endpoint to verify API is working."""
    return jsonify({
        'status': 'success',
        'message': 'API is working correctly',
        'available_endpoints': {
            'auth': ['/api/auth/login', '/api/auth/logout', '/api/auth/session'],
            'drivers': ['/api/diary/drivers', '/api/diary/drivers/{id}', '/api/diary/drivers/summary'],
            'hire_management': [
                '/api/hire/customers',
                '/api/hire/equipment/types', 
                '/api/hire/hires',
                '/api/hire/allocations',
                '/api/hire/driver-tasks',
                '/api/hire/quality-control'
            ]
        }
    })

@app.route('/api/hire/test', methods=['GET'])
def test_hire_system():
    """Test hire management system endpoints"""
    try:
        from api.diary.hire_management import customer_service, equipment_service
        
        # Test database connections
        customers = customer_service.get_customers_for_selection()
        equipment_types = equipment_service.get_equipment_types()
        
        return jsonify({
            'status': 'success',
            'message': 'Hire management system is working',
            'test_results': {
                'customers_count': len(customers),
                'equipment_types_count': len(equipment_types),
                'database_connection': 'success'
            }
        })
    except Exception as e:
        logger.error(f"Hire system test failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Hire system test failed: {str(e)}'
        }), 500

@app.route('/api/drivers/test', methods=['GET'])
def test_drivers_system():
    """Test drivers system endpoints"""
    try:
        from api.diary.drivers import driver_task_service
        
        # Test drivers system
        tasks = driver_task_service.get_driver_tasks()
        
        return jsonify({
            'status': 'success',
            'message': 'Drivers system is working',
            'test_results': {
                'tasks_count': len(tasks),
                'database_connection': 'success'
            }
        })
    except Exception as e:
        logger.error(f"Drivers system test failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Drivers system test failed: {str(e)}'
        }), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': 'API endpoint not found'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500

if __name__ == '__main__':
    app.run(debug=True, port=5328)