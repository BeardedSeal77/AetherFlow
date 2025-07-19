"""
Authentication blueprint for the Flask API
Based on the old auth system from api/old/index.py
"""

from flask import Blueprint, request, jsonify, session
import logging
import os

logger = logging.getLogger(__name__)

auth_bp = Blueprint('auth', __name__)

# Mock user database - in production this would be a real database
MOCK_USERS = {
    'admin': {'password': 'admin123', 'role': 'admin', 'name': 'Administrator'},
    'operator': {'password': 'op123', 'role': 'operator', 'name': 'Equipment Operator'},
    'driver': {'password': 'driver123', 'role': 'driver', 'name': 'Driver'},
    'manager': {'password': 'mgr123', 'role': 'manager', 'name': 'Manager'}
}

@auth_bp.route('/login', methods=['POST'])
def login():
    """Handle user login."""
    try:
        data = request.get_json()
        username = data.get('username', '').strip()
        password = data.get('password', '').strip()
        
        if not username or not password:
            return jsonify({
                'success': False,
                'error': 'Username and password are required'
            }), 400
        
        # Check credentials
        if username in MOCK_USERS and MOCK_USERS[username]['password'] == password:
            user_info = MOCK_USERS[username]
            
            # Store in session
            session['currentUser'] = username
            session['userRole'] = user_info['role']
            session['userName'] = user_info['name']
            session.permanent = True
            
            logger.info(f"User {username} logged in successfully")
            
            return jsonify({
                'success': True,
                'message': 'Login successful',
                'user': {
                    'username': username,
                    'name': user_info['name'],
                    'role': user_info['role']
                }
            })
        else:
            logger.warning(f"Failed login attempt for username: {username}")
            return jsonify({
                'success': False,
                'error': 'Invalid username or password'
            }), 401
            
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred during login'
        }), 500

@auth_bp.route('/logout', methods=['POST'])
def logout():
    """Handle user logout."""
    try:
        username = session.get('currentUser')
        
        # Clear session
        session.clear()
        
        if username:
            logger.info(f"User {username} logged out")
        
        return jsonify({
            'success': True,
            'message': 'Logout successful'
        })
        
    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'An error occurred during logout'
        }), 500

@auth_bp.route('/session', methods=['GET'])
def get_session():
    """Get current user session."""
    try:
        if 'currentUser' in session:
            return jsonify({
                'user': {
                    'username': session['currentUser'],
                    'name': session.get('userName', session['currentUser']),
                    'role': session.get('userRole', 'user')
                }
            })
        return jsonify({'user': None})
        
    except Exception as e:
        logger.error(f"Session check error: {str(e)}")
        return jsonify({'user': None})

@auth_bp.route('/validate', methods=['POST'])
def validate_session():
    """Validate current session."""
    try:
        if 'currentUser' in session:
            return jsonify({
                'success': True,
                'valid': True,
                'user': {
                    'username': session['currentUser'],
                    'name': session.get('userName', session['currentUser']),
                    'role': session.get('userRole', 'user')
                }
            })
        else:
            return jsonify({
                'success': True,
                'valid': False
            })
            
    except Exception as e:
        logger.error(f"Session validation error: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Session validation failed'
        }), 500