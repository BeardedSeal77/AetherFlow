"""
Equipment Hire Management System - Flask API
Flask API backend for managing equipment hire with two-phase booking
Based on the comprehensive old system from api/old/index.py
"""

import os
import json
import psycopg2
import psycopg2.extras
from flask import Flask, render_template, request, jsonify, redirect, url_for, flash, session
from flask_moment import Moment
from flask_cors import CORS
from datetime import datetime, date, time, timedelta
from decimal import Decimal
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'hire-system-secret-key-change-in-production')

# Enable CORS for Next.js frontend with credentials support
CORS(app, 
     origins=["http://localhost:5000", "http://localhost:3000", "http://127.0.0.1:5000", "http://127.0.0.1:3000"],
     supports_credentials=True)

# Session configuration
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(hours=8)

# Initialize Flask-Moment for date formatting
moment = Moment(app)

# Import and register auth blueprint
from auth.login import auth_bp
app.register_blueprint(auth_bp, url_prefix='/api/auth')

# Import and register hire blueprint
from hire.routes import hire_bp
app.register_blueprint(hire_bp, url_prefix='/api/hire')

# Add custom Jinja2 filters
@app.template_filter('fromjson')
def fromjson_filter(json_string):
    """Parse JSON string in templates"""
    try:
        if json_string:
            return json.loads(json_string)
        return []
    except (json.JSONDecodeError, TypeError):
        return []

# Database configuration
DATABASE_CONFIG = {
    'host': os.getenv('PGHOST', 'localhost'),
    'database': os.getenv('PGDATABASE', 'hire_system'),
    'user': os.getenv('PGUSER', 'postgres'),
    'password': os.getenv('PGPASSWORD', 'password'),
    'port': os.getenv('PGPORT', '5432')
}

def get_db_connection():
    """Get database connection with proper error handling"""
    try:
        # Try environment variable first
        if os.getenv('DATABASE_URL'):
            conn = psycopg2.connect(os.getenv('DATABASE_URL'))
        else:
            conn = psycopg2.connect(**DATABASE_CONFIG)
        
        conn.autocommit = True
        return conn
    except psycopg2.Error as e:
        logger.error(f"Database connection error: {e}")
        raise

def execute_stored_procedure(proc_name, params=None):
    """Execute stored procedure and return results"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        if params:
            cursor.callproc(proc_name, params)
        else:
            cursor.callproc(proc_name)
        
        # Fetch results if available
        try:
            results = cursor.fetchall()
            cursor.close()
            conn.close()
            return results
        except psycopg2.ProgrammingError:
            # No results to fetch (e.g., for INSERT/UPDATE operations)
            cursor.close()
            conn.close()
            return []
    except psycopg2.Error as e:
        logger.error(f"Stored procedure error: {e}")
        raise

# Import hire manager for API routes
from hire.hire_manager import HireManager
hire_manager = HireManager()

# API Routes using HireManager
@app.route('/api/customers')
def api_customers():
    """API endpoint for customer search using HireManager"""
    search = request.args.get('search', '')
    try:
        customers = hire_manager.search_customers(search)
        return jsonify(customers)
    except Exception as e:
        logger.error(f"Error fetching customers: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/customers/<int:customer_id>/contacts')
def api_customer_contacts(customer_id):
    """API endpoint for customer contacts using HireManager"""
    try:
        contacts = hire_manager.get_customer_contacts(customer_id)
        return jsonify(contacts)
    except Exception as e:
        logger.error(f"Error fetching customer contacts: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/customers/<int:customer_id>/sites')
def api_customer_sites(customer_id):
    """API endpoint for customer sites using HireManager"""
    try:
        sites = hire_manager.get_customer_sites(customer_id)
        return jsonify(sites)
    except Exception as e:
        logger.error(f"Error fetching customer sites: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment-types')
def api_equipment_types():
    """API endpoint for equipment types search using HireManager"""
    search = request.args.get('search', '')
    hire_start_date = request.args.get('hire_start_date')
    hire_end_date = request.args.get('hire_end_date')
    
    try:
        equipment_types = hire_manager.search_equipment_types(search, hire_start_date, hire_end_date)
        return jsonify(equipment_types)
    except Exception as e:
        logger.error(f"Error fetching equipment types: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment')
def api_equipment():
    """API endpoint for specific equipment search using HireManager"""
    search = request.args.get('search', '')
    hire_start_date = request.args.get('hire_start_date')
    hire_end_date = request.args.get('hire_end_date')
    
    try:
        equipment = hire_manager.search_specific_equipment(search, hire_start_date, hire_end_date)
        return jsonify(equipment)
    except Exception as e:
        logger.error(f"Error fetching equipment: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment-types/<int:equipment_type_id>/accessories')
def api_equipment_type_accessories(equipment_type_id):
    """API endpoint for equipment type accessories using HireManager"""
    try:
        accessories = hire_manager.get_equipment_type_accessories(equipment_type_id)
        return jsonify(accessories)
    except Exception as e:
        logger.error(f"Error fetching equipment type accessories: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment/<int:equipment_id>/accessories')
def api_equipment_accessories(equipment_id):
    """API endpoint for specific equipment accessories using HireManager"""
    try:
        accessories = hire_manager.get_equipment_accessories(equipment_id)
        return jsonify(accessories)
    except Exception as e:
        logger.error(f"Error fetching equipment accessories: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/accessories/auto-calculate', methods=['POST'])
def api_auto_calculate_accessories():
    """API endpoint for automatic accessory calculation using HireManager"""
    data = request.json
    equipment_types = data.get('equipment_types', [])
    
    try:
        accessories = hire_manager.calculate_auto_accessories(equipment_types)
        return jsonify(accessories)
    except Exception as e:
        logger.error(f"Error calculating auto accessories: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/hires')
def api_hires():
    """API endpoint for hire list using HireManager"""
    try:
        filters = request.args.to_dict()
        hires = hire_manager.get_all_hires(filters)
        return jsonify(hires)
    except Exception as e:
        logger.error(f"Error fetching hires: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/hires/<int:interaction_id>')
def api_hire_details(interaction_id):
    """API endpoint for hire details using HireManager"""
    try:
        hire_details = hire_manager.get_hire_details(interaction_id)
        
        if 'error' in hire_details:
            return jsonify({'error': hire_details['error']}), 404
        
        return jsonify(hire_details)
    except Exception as e:
        logger.error(f"Error fetching hire details: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/allocation/allocate', methods=['POST'])
def api_allocate_equipment():
    """API endpoint for equipment allocation"""
    data = request.json
    
    try:
        booking_id = data.get('booking_id')
        equipment_ids = data.get('equipment_ids', [])
        
        if not booking_id or not equipment_ids:
            return jsonify({'success': False, 'error': 'Missing booking_id or equipment_ids'}), 400
        
        # Allocate equipment using stored procedure
        result = execute_stored_procedure('sp_allocate_equipment', [booking_id, equipment_ids])
        
        if result and result[0]:
            result_dict = dict(result[0])
            return jsonify(result_dict)
        else:
            return jsonify({'success': False, 'error': 'Allocation failed'}), 500
    except Exception as e:
        logger.error(f"Error allocating equipment: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/health')
def api_health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'Equipment Hire API'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5328, debug=True)