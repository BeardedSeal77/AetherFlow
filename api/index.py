from flask import Flask, session, jsonify
from api.auth.login import auth_bp
from api.diary.diary import diary_bp

app = Flask(__name__)
app.secret_key = 'your_secret_key'  # Change this to a secure key in production

# Register blueprints
app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(diary_bp, url_prefix='/api/diary')

@app.route('/api/auth/session')
def get_session():
    """Get current user session."""
    if 'currentUser' in session:
        # Format the user data to match the expected structure in frontend
        return jsonify({'user': {
            'username': session['currentUser'],
            'name': session['currentUser']  # You can customize this as needed
        }})
    return jsonify({'user': None})

# Add a test endpoint to check if the API is working
@app.route('/api/test')
def test_api():
    """Test endpoint to verify API is working."""
    return jsonify({
        'status': 'success',
        'message': 'API is working correctly'
    })

if __name__ == '__main__':
    app.run(debug=True)