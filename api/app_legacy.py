"""
Equipment Hire Management System
Flask web application for managing equipment hire with two-phase booking
"""

import os
import json
import psycopg2
import psycopg2.extras
from flask import Flask, render_template, request, jsonify, redirect, url_for, flash, session
from flask_moment import Moment
from datetime import datetime, date, time
from decimal import Decimal
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'hire-system-secret-key-change-in-production')

# Initialize Flask-Moment for date formatting
moment = Moment(app)

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
            cursor.execute(f"SELECT * FROM {proc_name}()")
        
        # Fetch results if available
        try:
            results = cursor.fetchall()
        except psycopg2.ProgrammingError:
            # No results to fetch (INSERT/UPDATE operations)
            results = []
        
        cursor.close()
        conn.close()
        return results
    except psycopg2.Error as e:
        logger.error(f"Stored procedure error: {e}")
        raise

def json_serializer(obj):
    """JSON serializer for objects not serializable by default"""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    elif isinstance(obj, time):
        return obj.strftime('%H:%M:%S')
    elif isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")

@app.route('/')
def index():
    """Dashboard homepage"""
    try:
        # Get dashboard summary
        summary = execute_stored_procedure('sp_get_hire_dashboard_summary')
        dashboard_data = summary[0] if summary else {}
        
        # Get recent hires
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        cursor.execute("""
            SELECT 
                reference_number, customer_name, allocation_status,
                equipment_types_count, total_equipment_booked, driver_task_status,
                interaction_id, hire_start_date, delivery_date
            FROM v_hire_summary 
            ORDER BY interaction_id DESC 
            LIMIT 10
        """)
        recent_hires = cursor.fetchall()
        
        # Get driver tasks
        cursor.execute("""
            SELECT 
                task_id, task_type, status, customer_name, scheduled_date,
                equipment_allocated, equipment_verified, assigned_driver
            FROM v_driver_taskboard 
            WHERE status IN ('backlog', 'assigned', 'in_progress')
            ORDER BY scheduled_date, task_id 
            LIMIT 10
        """)
        driver_tasks = cursor.fetchall()
        
        # Get equipment utilization
        cursor.execute("""
            SELECT type_name, total_units, available_units, utilization_percentage
            FROM v_equipment_utilization 
            ORDER BY utilization_percentage DESC 
            LIMIT 8
        """)
        equipment_utilization = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return render_template('index.html', 
                             dashboard=dashboard_data,
                             recent_hires=recent_hires,
                             driver_tasks=driver_tasks,
                             equipment_utilization=equipment_utilization)
    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        flash(f'Error loading dashboard: {str(e)}', 'error')
        return render_template('index.html', dashboard={}, recent_hires=[], 
                             driver_tasks=[], equipment_utilization=[])

@app.route('/hire/new')
def new_hire():
    """New hire form"""
    return render_template('hire_form.html')

@app.route('/api/customers')
def api_customers():
    """API endpoint for customer selection"""
    search_term = request.args.get('search', '')
    try:
        customers = execute_stored_procedure('sp_get_customers_for_selection', [search_term])
        return jsonify([dict(customer) for customer in customers])
    except Exception as e:
        logger.error(f"Error fetching customers: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/customers/<int:customer_id>/contacts')
def api_customer_contacts(customer_id):
    """API endpoint for customer contacts"""
    try:
        contacts = execute_stored_procedure('sp_get_customer_contacts', [customer_id])
        return jsonify([dict(contact) for contact in contacts])
    except Exception as e:
        logger.error(f"Error fetching contacts: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/customers/<int:customer_id>/sites')
def api_customer_sites(customer_id):
    """API endpoint for customer sites"""
    try:
        sites = execute_stored_procedure('sp_get_customer_sites', [customer_id])
        return jsonify([dict(site) for site in sites])
    except Exception as e:
        logger.error(f"Error fetching sites: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment-types')
def api_equipment_types():
    """API endpoint for equipment types"""
    search_term = request.args.get('search', '')
    hire_start_date = request.args.get('hire_start_date')
    hire_end_date = request.args.get('hire_end_date')
    
    # Convert empty strings to None for proper NULL handling
    hire_start_date = hire_start_date if hire_start_date and hire_start_date.strip() else None
    hire_end_date = hire_end_date if hire_end_date and hire_end_date.strip() else None
    
    try:
        equipment_types = execute_stored_procedure('sp_get_available_equipment_types', 
                                                 [search_term, hire_start_date, hire_end_date])
        return jsonify([dict(eq) for eq in equipment_types])
    except Exception as e:
        logger.error(f"Error fetching equipment types: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment')
def api_individual_equipment():
    """API endpoint for individual equipment units"""
    equipment_type_id = request.args.get('equipment_type_id')
    search_term = request.args.get('search', '')
    hire_start_date = request.args.get('hire_start_date')
    hire_end_date = request.args.get('hire_end_date')
    
    # Convert empty strings to None for proper NULL handling
    equipment_type_id = int(equipment_type_id) if equipment_type_id and equipment_type_id.strip() else None
    hire_start_date = hire_start_date if hire_start_date and hire_start_date.strip() else None
    hire_end_date = hire_end_date if hire_end_date and hire_end_date.strip() else None
    
    try:
        # Use the updated function that returns equipment_type_id
        equipment = execute_stored_procedure('sp_search_equipment_units', 
                                           [search_term, hire_start_date, hire_end_date])
        return jsonify([dict(eq) for eq in equipment])
    except Exception as e:
        logger.error(f"Error fetching equipment: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/accessories/auto-calculate', methods=['POST'])
def api_auto_calculate_accessories():
    """API endpoint for automatic accessory calculation"""
    equipment_types_json = request.json.get('equipment_types', '[]')
    
    try:
        accessories = execute_stored_procedure('sp_calculate_auto_accessories', 
                                             [json.dumps(equipment_types_json)])
        return jsonify([dict(acc) for acc in accessories])
    except Exception as e:
        logger.error(f"Error calculating accessories: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/accessories/standalone')
def api_standalone_accessories():
    """API endpoint for standalone accessories"""
    search_term = request.args.get('search', '')
    try:
        accessories = execute_stored_procedure('sp_get_standalone_accessories', [search_term])
        return jsonify([dict(acc) for acc in accessories])
    except Exception as e:
        logger.error(f"Error fetching accessories: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment-types/<int:equipment_type_id>/accessories')
def api_equipment_type_accessories(equipment_type_id):
    """API endpoint for equipment type accessories"""
    try:
        accessories = execute_stored_procedure('sp_get_equipment_type_accessories', [equipment_type_id])
        return jsonify([dict(acc) for acc in accessories])
    except Exception as e:
        logger.error(f"Error fetching equipment type accessories: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/equipment/<int:equipment_id>/accessories')
def api_equipment_accessories(equipment_id):
    """API endpoint for specific equipment accessories"""
    try:
        accessories = execute_stored_procedure('sp_get_equipment_accessories', [equipment_id])
        return jsonify([dict(acc) for acc in accessories])
    except Exception as e:
        logger.error(f"Error fetching equipment accessories: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/hire/validate', methods=['POST'])
def api_validate_hire():
    """API endpoint for hire validation"""
    data = request.json
    
    try:
        validation = execute_stored_procedure('sp_validate_hire_request', [
            data.get('customer_id'),
            data.get('contact_id'),
            data.get('site_id'),
            data.get('hire_start_date'),
            data.get('hire_end_date'),
            json.dumps(data.get('equipment_types', [])),
            json.dumps(data.get('accessories', []))
        ])
        
        return jsonify(dict(validation[0]) if validation else {'is_valid': False, 'error_message': 'Validation failed'})
    except Exception as e:
        logger.error(f"Error validating hire: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/hire/create', methods=['POST'])
def api_create_hire():
    """API endpoint for hire creation"""
    data = request.json
    
    # Set default employee_id to 2 (Sarah Johnson - hire_control) if not provided
    employee_id = session.get('employee_id', 2)
    
    # Add detailed debugging
    logger.info(f"Creating hire with data: {data}")
    
    try:
        # Fix parameter order to match stored procedure definition
        result = execute_stored_procedure('sp_create_hire_interaction', [
            data.get('customer_id'),                     # p_customer_id
            data.get('contact_id'),                      # p_contact_id  
            employee_id,                                 # p_employee_id
            data.get('site_id'),                         # p_site_id
            data.get('contact_method', 'phone'),         # p_contact_method
            data.get('hire_start_date'),                 # p_hire_start_date
            data.get('hire_end_date'),                   # p_hire_end_date
            data.get('delivery_date'),                   # p_delivery_date
            data.get('delivery_time'),                   # p_delivery_time
            data.get('special_instructions'),            # p_special_instructions
            data.get('notes'),                           # p_notes
            json.dumps(data.get('equipment_types', [])), # p_equipment_types_json
            json.dumps(data.get('accessories', []))      # p_accessories_json
        ])
        
        logger.info(f"Hire creation result: {result}")
        return jsonify(dict(result[0]) if result else {'success': False, 'error_message': 'Creation failed'})
    except Exception as e:
        logger.error(f"Error creating hire with data {data}: {e}")
        return jsonify({'error': str(e), 'data_received': data}), 500

@app.route('/hire/<int:interaction_id>')
def hire_details(interaction_id):
    """Hire details page"""
    try:
        # Get hire details
        details = execute_stored_procedure('sp_get_hire_interaction_details', [interaction_id])
        if not details:
            flash('Hire not found', 'error')
            return redirect(url_for('index'))
        
        hire_detail = dict(details[0])
        
        # Get equipment list
        equipment_list = execute_stored_procedure('sp_get_hire_equipment_list', [interaction_id])
        
        # Get accessories list
        accessories_list = execute_stored_procedure('sp_get_hire_accessories_list', [interaction_id])
        
        # Get allocation status - simplified view
        allocation_status = execute_stored_procedure('sp_get_simple_allocation_status', [interaction_id])
        allocation_bookings = [dict(booking) for booking in allocation_status] if allocation_status else []
        
        # Get available equipment for each booking that needs allocation
        available_equipment = {}
        for booking in allocation_bookings:
            if booking['quantity_remaining'] > 0:
                equipment_type_id = booking.get('equipment_type_id')
                if equipment_type_id:
                    available_units = execute_stored_procedure('sp_get_available_equipment_for_type', 
                                                             [equipment_type_id, hire_detail['hire_start_date'], hire_detail.get('hire_end_date')])
                    available_equipment[booking['equipment_generic_booking_id']] = [dict(unit) for unit in available_units]
        
        return render_template('hire_details.html',
                             hire=hire_detail,
                             equipment_list=[dict(eq) for eq in equipment_list],
                             accessories_list=[dict(acc) for acc in accessories_list],
                             allocation_bookings=allocation_bookings,
                             available_equipment=available_equipment)
    except Exception as e:
        logger.error(f"Error loading hire details: {e}")
        flash(f'Error loading hire details: {str(e)}', 'error')
        return redirect(url_for('index'))

@app.route('/allocation')
def allocation_dashboard():
    """Equipment allocation dashboard"""
    try:
        # Get bookings ready for allocation
        bookings = execute_stored_procedure('sp_get_bookings_for_allocation', [None, 'booked'])
        
        return render_template('allocation.html', 
                             bookings=[dict(booking) for booking in bookings])
    except Exception as e:
        logger.error(f"Error loading allocation dashboard: {e}")
        flash(f'Error loading allocation dashboard: {str(e)}', 'error')
        return render_template('allocation.html', bookings=[])

@app.route('/api/allocation/equipment/<int:equipment_type_id>')
def api_allocation_equipment(equipment_type_id):
    """API endpoint for equipment available for allocation"""
    hire_start_date = request.args.get('hire_start_date', str(date.today()))
    hire_end_date = request.args.get('hire_end_date')
    exclude_interaction_id = request.args.get('exclude_interaction_id')
    
    try:
        equipment = execute_stored_procedure('sp_get_equipment_for_allocation', 
                                           [equipment_type_id, hire_start_date, hire_end_date, exclude_interaction_id])
        return jsonify([dict(eq) for eq in equipment])
    except Exception as e:
        logger.error(f"Error fetching allocation equipment: {e}")
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
    employee_id = session.get('employee_id', 2)  # Default to Sarah Johnson
    
    try:
        result = execute_stored_procedure('sp_allocate_specific_equipment', [
            data.get('booking_id'),
            data.get('equipment_ids', []),
            employee_id,
            data.get('notes')
        ])
        
        return jsonify(dict(result[0]) if result else {'success': False, 'error_message': 'Allocation failed'})
    except Exception as e:
        logger.error(f"Error allocating equipment: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/qc/pending')
def api_qc_pending():
    """API endpoint for equipment pending QC"""
    interaction_id = request.args.get('interaction_id')
    try:
        equipment = execute_stored_procedure('sp_get_equipment_pending_qc', [interaction_id])
        return jsonify([dict(eq) for eq in equipment])
    except Exception as e:
        logger.error(f"Error fetching pending QC equipment: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/qc/signoff', methods=['POST'])
def api_qc_signoff():
    """API endpoint for QC sign-off"""
    data = request.json
    employee_id = session.get('employee_id', 2)  # Default to Sarah Johnson
    
    try:
        result = execute_stored_procedure('sp_quality_control_signoff', [
            data.get('allocation_id'),
            employee_id,
            data.get('qc_notes'),
            data.get('approved', True)
        ])
        
        return jsonify(dict(result[0]) if result else {'success': False, 'error_message': 'QC sign-off failed'})
    except Exception as e:
        logger.error(f"Error in QC sign-off: {e}")
        return jsonify({'error': str(e)}), 500

@app.errorhandler(404)
def not_found_error(error):
    return render_template('base.html'), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return render_template('base.html'), 500

# Custom template filters
@app.template_filter('currency')
def currency_filter(value):
    """Format currency values"""
    if value is None:
        return 'R 0.00'
    return f'R {float(value):,.2f}'

@app.template_filter('date_format')
def date_format_filter(value):
    """Format date values"""
    if value is None:
        return ''
    if isinstance(value, str):
        try:
            value = datetime.fromisoformat(value.replace('Z', '+00:00')).date()
        except:
            return value
    return value.strftime('%d %b %Y')

@app.template_filter('time_format')
def time_format_filter(value):
    """Format time values"""
    if value is None:
        return ''
    if isinstance(value, str):
        try:
            value = datetime.strptime(value, '%H:%M:%S').time()
        except:
            return value
    return value.strftime('%H:%M')

@app.template_filter('status_badge')
def status_badge_filter(status):
    """Generate Bootstrap badge for status"""
    badge_classes = {
        'pending': 'badge-warning',
        'in_progress': 'badge-info',
        'completed': 'badge-success',
        'cancelled': 'badge-secondary',
        'booked': 'badge-primary',
        'allocated': 'badge-info',
        'delivered': 'badge-success',
        'backlog': 'badge-warning',
        'assigned': 'badge-info',
        'available': 'badge-success',
        'rented': 'badge-danger',
        'maintenance': 'badge-warning'
    }
    badge_class = badge_classes.get(status.lower(), 'badge-secondary')
    return f'<span class="badge {badge_class}">{status.title()}</span>'

if __name__ == '__main__':
    # For development
    app.run(host='0.0.0.0', port=5000, debug=True)
