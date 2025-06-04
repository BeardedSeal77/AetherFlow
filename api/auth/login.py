from flask import Blueprint, request, jsonify, session

auth_bp = Blueprint('auth', __name__)

# Mock users (in a real app, this would be a database)
users = [
    {"username": "user1", "password": "password1"},
    {"username": "user2", "password": "password2"}
]

@auth_bp.route('/login', methods=['POST'])
def login():
    """Handle user login."""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    user = next((u for u in users if u['username'] == username and u['password'] == password), None)

    if user:
        session['currentUser'] = username
        return jsonify({'success': True, 'message': 'Login successful'})
    else:
        return jsonify({'success': False, 'error': 'Invalid username or password'}), 401

@auth_bp.route('/logout', methods=['POST'])
def logout():
    """Handle user logout."""
    session.pop('currentUser', None)
    return jsonify({'success': True, 'message': 'Logout successful'})