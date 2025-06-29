# Python Integration Guide - Hire Management Procedures

## Overview
#This guide shows how to integrate the stored procedures with your Python Flask business logic layer.

## Database Connection Setup


import psycopg2
from psycopg2.extras import RealDictCursor
import json

class DatabaseService:
    def __init__(self, connection_string):
        self.connection_string = connection_string
    
    def execute_procedure(self, procedure_name, params=None):
        """Execute a stored procedure and return results"""
        with psycopg2.connect(self.connection_string) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                if params:
                    cursor.callproc(procedure_name, params)
                else:
                    cursor.callproc(procedure_name)
                
                try:
                    results = cursor.fetchall()
                    return [dict(row) for row in results]
                except psycopg2.ProgrammingError:
                    # No results to fetch (INSERT/UPDATE procedures)
                    return None


## Service Layer Examples

### Customer Service

class CustomerService:
    def __init__(self, db_service):
        self.db = db_service
    
    def get_customers_for_selection(self, search_term=None, include_inactive=False):
        """Get customer list for hire interface"""
        return self.db.execute_procedure(
            'sp_get_customers_for_selection',
            [search_term, include_inactive]
        )
    
    def get_customer_contacts(self, customer_id):
        """Get contacts for selected customer"""
        return self.db.execute_procedure(
            'sp_get_customer_contacts',
            [customer_id]
        )
    
    def get_customer_sites(self, customer_id):
        """Get delivery sites for customer"""
        return self.db.execute_procedure(
            'sp_get_customer_sites',
            [customer_id]
        )


### Equipment Service

class EquipmentService:
    def __init__(self, db_service):
        self.db = db_service
    
    def get_equipment_types(self, search_term=None, delivery_date=None):
        """Get available equipment types (Phase 1 - Generic)"""
        return self.db.execute_procedure(
            'sp_get_available_equipment_types',
            [search_term, delivery_date]
        )
    
    def get_individual_equipment(self, equipment_type_id=None, delivery_date=None):
        """Get individual equipment units (Phase 2 - Specific)"""
        return self.db.execute_procedure(
            'sp_get_available_individual_equipment',
            [equipment_type_id, delivery_date, None]
        )
    
    def get_equipment_accessories(self, equipment_type_ids):
        """Get accessories for selected equipment types"""
        return self.db.execute_procedure(
            'sp_get_equipment_accessories',
            [equipment_type_ids]
        )
    
    def calculate_auto_accessories(self, equipment_selections):
        """Calculate default accessories for equipment selection"""
        # Convert Python list to JSONB
        equipment_json = json.dumps(equipment_selections)
        return self.db.execute_procedure(
            'sp_calculate_auto_accessories',
            [equipment_json]
        )


### Hire Service

class HireService:
    def __init__(self, db_service):
        self.db = db_service
    
    def validate_hire_request(self, hire_data):
        """Validate hire request before creation"""
        equipment_json = json.dumps(hire_data['equipment_selections'])
        
        return self.db.execute_procedure(
            'sp_validate_hire_request',
            [
                hire_data['customer_id'],
                hire_data['contact_id'],
                hire_data['site_id'],
                equipment_json,
                hire_data['delivery_date'],
                hire_data.get('estimated_amount', 0)
            ]
        )
    
    def create_hire_interaction(self, hire_data):
        """Create complete hire interaction"""
        equipment_json = json.dumps(hire_data['equipment_selections'])
        accessories_json = json.dumps(hire_data['accessory_selections'])
        
        return self.db.execute_procedure(
            'sp_create_hire_interaction',
            [
                hire_data['customer_id'],
                hire_data['contact_id'],
                hire_data['employee_id'],
                hire_data['site_id'],
                hire_data['contact_method'],
                hire_data.get('notes', ''),
                equipment_json,
                accessories_json,
                hire_data['delivery_date'],
                hire_data.get('delivery_time'),
                hire_data.get('hire_start_date'),
                hire_data.get('estimated_hire_end')
            ]
        )
    
    def get_hire_details(self, interaction_id):
        """Get complete hire interaction details"""
        main_details = self.db.execute_procedure(
            'sp_get_hire_interaction_details',
            [interaction_id]
        )
        
        equipment_list = self.db.execute_procedure(
            'sp_get_hire_equipment_list',
            [interaction_id]
        )
        
        accessories_list = self.db.execute_procedure(
            'sp_get_hire_accessories_list',
            [interaction_id]
        )
        
        return {
            'interaction': main_details[0] if main_details else None,
            'equipment': equipment_list,
            'accessories': accessories_list
        }
    
    def get_hire_list(self, filters):
        """Get paginated hire list with filters"""
        return self.db.execute_procedure(
            'sp_get_hire_list',
            [
                filters.get('date_from'),
                filters.get('date_to'),
                filters.get('status_filter'),
                filters.get('customer_filter'),
                filters.get('search_term'),
                filters.get('limit', 50),
                filters.get('offset', 0)
            ]
        )


### Allocation Service

class AllocationService:
    def __init__(self, db_service):
        self.db = db_service
    
    def get_bookings_for_allocation(self, interaction_id=None):
        """Get generic bookings ready for Phase 2 allocation"""
        return self.db.execute_procedure(
            'sp_get_bookings_for_allocation',
            [interaction_id, True]
        )
    
    def get_equipment_for_allocation(self, equipment_type_id, delivery_date):
        """Get available equipment for allocation"""
        return self.db.execute_procedure(
            'sp_get_equipment_for_allocation',
            [equipment_type_id, delivery_date, None]
        )
    
    def allocate_equipment(self, booking_id, equipment_ids, allocated_by):
        """Allocate specific equipment to booking"""
        return self.db.execute_procedure(
            'sp_allocate_specific_equipment',
            [booking_id, equipment_ids, allocated_by]
        )
    
    def get_allocation_status(self, interaction_id):
        """Get allocation progress for interaction"""
        return self.db.execute_procedure(
            'sp_get_allocation_status',
            [interaction_id]
        )


### Quality Control Service

class QualityControlService:
    def __init__(self, db_service):
        self.db = db_service
    
    def get_equipment_pending_qc(self, interaction_id=None):
        """Get equipment pending quality control"""
        return self.db.execute_procedure(
            'sp_get_equipment_pending_qc',
            [interaction_id, None]
        )
    
    def quality_control_signoff(self, allocation_ids, employee_id, qc_status='passed', notes=None):
        """Process QC sign-off for equipment"""
        return self.db.execute_procedure(
            'sp_quality_control_signoff',
            [allocation_ids, employee_id, qc_status, notes]
        )
    
    def get_qc_summary(self, date_from, date_to):
        """Get QC statistics"""
        return self.db.execute_procedure(
            'sp_get_qc_summary',
            [date_from, date_to]
        )


### Driver Task Service

class DriverTaskService:
    def __init__(self, db_service):
        self.db = db_service
    
    def get_driver_tasks(self, driver_id=None, status_filter=None, date_from=None, date_to=None):
        """Get driver tasks for taskboard"""
        return self.db.execute_procedure(
            'sp_get_driver_tasks',
            [driver_id, status_filter, date_from, date_to]
        )
    
    def update_task_status(self, task_id, status_updates):
        """Update driver task status and progress"""
        return self.db.execute_procedure(
            'sp_update_driver_task_status',
            [
                task_id,
                status_updates.get('status'),
                status_updates.get('status_booked'),
                status_updates.get('status_driver'),
                status_updates.get('status_quality_control'),
                status_updates.get('status_whatsapp'),
                status_updates.get('assigned_to'),
                status_updates.get('completion_notes')
            ]
        )
    
    def get_task_equipment(self, task_id):
        """Get equipment list for driver task"""
        return self.db.execute_procedure(
            'sp_get_driver_task_equipment',
            [task_id]
        )


## Flask API Endpoints

### Customer Endpoints

@app.route('/api/customers', methods=['GET'])
def get_customers():
    search_term = request.args.get('search')
    include_inactive = request.args.get('include_inactive', 'false').lower() == 'true'
    
    try:
        customers = customer_service.get_customers_for_selection(search_term, include_inactive)
        return jsonify({'success': True, 'data': customers})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/customers/<int:customer_id>/contacts', methods=['GET'])
def get_customer_contacts(customer_id):
    try:
        contacts = customer_service.get_customer_contacts(customer_id)
        return jsonify({'success': True, 'data': contacts})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/customers/<int:customer_id>/sites', methods=['GET'])
def get_customer_sites(customer_id):
    try:
        sites = customer_service.get_customer_sites(customer_id)
        return jsonify({'success': True, 'data': sites})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


### Equipment Endpoints

@app.route('/api/equipment/types', methods=['GET'])
def get_equipment_types():
    search_term = request.args.get('search')
    delivery_date = request.args.get('delivery_date')
    
    try:
        equipment_types = equipment_service.get_equipment_types(search_term, delivery_date)
        return jsonify({'success': True, 'data': equipment_types})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/equipment/individual', methods=['GET'])
def get_individual_equipment():
    equipment_type_id = request.args.get('type_id', type=int)
    delivery_date = request.args.get('delivery_date')
    
    try:
        equipment = equipment_service.get_individual_equipment(equipment_type_id, delivery_date)
        return jsonify({'success': True, 'data': equipment})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/equipment/accessories', methods=['POST'])
def get_equipment_accessories():
    data = request.get_json()
    equipment_type_ids = data.get('equipment_type_ids', [])
    
    try:
        accessories = equipment_service.get_equipment_accessories(equipment_type_ids)
        return jsonify({'success': True, 'data': accessories})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/equipment/auto-accessories', methods=['POST'])
def calculate_auto_accessories():
    data = request.get_json()
    equipment_selections = data.get('equipment_selections', [])
    
    try:
        auto_accessories = equipment_service.calculate_auto_accessories(equipment_selections)
        return jsonify({'success': True, 'data': auto_accessories})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


### Hire Management Endpoints

@app.route('/api/hires/validate', methods=['POST'])
def validate_hire_request():
    hire_data = request.get_json()
    
    try:
        validation_result = hire_service.validate_hire_request(hire_data)
        return jsonify({'success': True, 'data': validation_result[0] if validation_result else None})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/hires', methods=['POST'])
def create_hire():
    hire_data = request.get_json()
    
    try:
        # Validate first
        validation = hire_service.validate_hire_request(hire_data)
        if validation and not validation[0]['is_valid']:
            return jsonify({
                'success': False, 
                'validation_errors': validation[0]['validation_errors']
            }), 400
        
        # Create hire
        result = hire_service.create_hire_interaction(hire_data)
        return jsonify({'success': True, 'data': result[0] if result else None})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/hires/<int:interaction_id>', methods=['GET'])
def get_hire_details(interaction_id):
    try:
        hire_details = hire_service.get_hire_details(interaction_id)
        return jsonify({'success': True, 'data': hire_details})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/hires', methods=['GET'])
def get_hire_list():
    filters = {
        'date_from': request.args.get('date_from'),
        'date_to': request.args.get('date_to'),
        'status_filter': request.args.get('status'),
        'customer_filter': request.args.get('customer'),
        'search_term': request.args.get('search'),
        'limit': request.args.get('limit', 50, type=int),
        'offset': request.args.get('offset', 0, type=int)
    }
    
    try:
        hire_list = hire_service.get_hire_list(filters)
        return jsonify({'success': True, 'data': hire_list})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


### Allocation Endpoints

@app.route('/api/allocations/bookings', methods=['GET'])
def get_bookings_for_allocation():
    interaction_id = request.args.get('interaction_id', type=int)
    
    try:
        bookings = allocation_service.get_bookings_for_allocation(interaction_id)
        return jsonify({'success': True, 'data': bookings})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/allocations/equipment', methods=['GET'])
def get_equipment_for_allocation():
    equipment_type_id = request.args.get('equipment_type_id', type=int)
    delivery_date = request.args.get('delivery_date')
    
    try:
        equipment = allocation_service.get_equipment_for_allocation(equipment_type_id, delivery_date)
        return jsonify({'success': True, 'data': equipment})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/allocations', methods=['POST'])
def allocate_equipment():
    data = request.get_json()
    booking_id = data.get('booking_id')
    equipment_ids = data.get('equipment_ids', [])
    allocated_by = data.get('allocated_by')
    
    try:
        result = allocation_service.allocate_equipment(booking_id, equipment_ids, allocated_by)
        return jsonify({'success': True, 'data': result})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/allocations/status/<int:interaction_id>', methods=['GET'])
def get_allocation_status(interaction_id):
    try:
        status = allocation_service.get_allocation_status(interaction_id)
        return jsonify({'success': True, 'data': status})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


### Quality Control Endpoints

@app.route('/api/quality-control/pending', methods=['GET'])
def get_equipment_pending_qc():
    interaction_id = request.args.get('interaction_id', type=int)
    
    try:
        pending_equipment = qc_service.get_equipment_pending_qc(interaction_id)
        return jsonify({'success': True, 'data': pending_equipment})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/quality-control/signoff', methods=['POST'])
def quality_control_signoff():
    data = request.get_json()
    allocation_ids = data.get('allocation_ids', [])
    employee_id = data.get('employee_id')
    qc_status = data.get('qc_status', 'passed')
    notes = data.get('notes')
    
    try:
        result = qc_service.quality_control_signoff(allocation_ids, employee_id, qc_status, notes)
        return jsonify({'success': True, 'data': result})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/quality-control/summary', methods=['GET'])
def get_qc_summary():
    date_from = request.args.get('date_from')
    date_to = request.args.get('date_to')
    
    try:
        summary = qc_service.get_qc_summary(date_from, date_to)
        return jsonify({'success': True, 'data': summary[0] if summary else None})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


### Driver Task Endpoints

@app.route('/api/driver-tasks', methods=['GET'])
def get_driver_tasks():
    filters = {
        'driver_id': request.args.get('driver_id', type=int),
        'status_filter': request.args.get('status'),
        'date_from': request.args.get('date_from'),
        'date_to': request.args.get('date_to')
    }
    
    try:
        tasks = driver_task_service.get_driver_tasks(**filters)
        return jsonify({'success': True, 'data': tasks})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/driver-tasks/<int:task_id>', methods=['PUT'])
def update_driver_task(task_id):
    status_updates = request.get_json()
    
    try:
        result = driver_task_service.update_task_status(task_id, status_updates)
        return jsonify({'success': True, 'data': result[0] if result else None})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/driver-tasks/<int:task_id>/equipment', methods=['GET'])
def get_driver_task_equipment(task_id):
    try:
        equipment = driver_task_service.get_task_equipment(task_id)
        return jsonify({'success': True, 'data': equipment})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


## Error Handling Best Practices


class DatabaseError(Exception):
    """Custom exception for database errors"""
    def __init__(self, message, procedure_name=None, original_error=None):
        self.message = message
        self.procedure_name = procedure_name
        self.original_error = original_error
        super().__init__(self.message)

def handle_database_errors(func):
    """Decorator for consistent database error handling"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except psycopg2.Error as e:
            raise DatabaseError(
                message=f"Database error: {str(e)}",
                procedure_name=func.__name__,
                original_error=e
            )
        except Exception as e:
            raise DatabaseError(
                message=f"Unexpected error: {str(e)}",
                procedure_name=func.__name__,
                original_error=e
            )
    return wrapper

# Apply to service methods
class HireService:
    @handle_database_errors
    def create_hire_interaction(self, hire_data):
        # Implementation here
        pass


## Testing Examples


# Example test for hire creation
def test_create_hire_interaction():
    hire_data = {
        'customer_id': 1000,
        'contact_id': 1000,
        'employee_id': 2,
        'site_id': 1,
        'contact_method': 'phone',
        'notes': 'Test hire',
        'equipment_selections': [
            {'equipment_type_id': 1, 'quantity': 2}
        ],
        'accessory_selections': [
            {'accessory_id': 1, 'quantity': 4.0, 'accessory_type': 'default'}
        ],
        'delivery_date': '2025-07-01',
        'delivery_time': '09:00:00'
    }
    
    result = hire_service.create_hire_interaction(hire_data)
    assert result[0]['success'] == True
    assert 'reference_number' in result[0]
    print(f"Created hire: {result[0]['reference_number']}")

# Example test for equipment allocation
def test_equipment_allocation():
    # Get bookings ready for allocation
    bookings = allocation_service.get_bookings_for_allocation()
    assert len(bookings) > 0
    
    booking = bookings[0]
    
    # Get available equipment
    equipment = allocation_service.get_equipment_for_allocation(
        booking['equipment_type_id'], 
        booking['delivery_date']
    )
    assert len(equipment) > 0
    
    # Allocate equipment
    result = allocation_service.allocate_equipment(
        booking['booking_id'],
        [equipment[0]['equipment_id']],
        2  # employee_id
    )
    
    assert result[0]['success'] == True
    print(f"Allocated equipment: {result[0]['asset_code']}")


## Configuration Example


# config.py
import os

class Config:
    DATABASE_URL = os.environ.get('DATABASE_URL') or \
        'postgresql://username:password@localhost:5432/equipment_hire'
    
    # Database connection pool settings
    DB_POOL_SIZE = 10
    DB_POOL_MAX_OVERFLOW = 20
    DB_POOL_TIMEOUT = 30

# app.py
from config import Config

# Initialize services
db_service = DatabaseService(Config.DATABASE_URL)
customer_service = CustomerService(db_service)
equipment_service = EquipmentService(db_service)
hire_service = HireService(db_service)
allocation_service = AllocationService(db_service)
qc_service = QualityControlService(db_service)
driver_task_service = DriverTaskService(db_service)


## Key Benefits of This Architecture

# 1. **Clean Separation**: Frontend → Python → Database with clear boundaries
# 2. **Business Logic Encapsulation**: All validation and rules in stored procedures
# 3. **Performance**: Reduced network calls, optimized database operations
# 4. **Consistency**: Standardized error handling and response formats
# 5. **Security**: Parameterized queries, controlled database access
# 6. **Maintainability**: Changes to business logic happen in procedures
# 7. **Testing**: Easy to unit test each layer independently

## Next Steps

# 1. **Install and test procedures** using the build script
# 2. **Implement Python services** following the examples above
# 3. **Build API endpoints** with proper error handling
# 4. **Create frontend components** that consume these APIs
# 5. **Add authentication/authorization** to restrict access as needed
# 6. **Implement logging and monitoring** for production deployment