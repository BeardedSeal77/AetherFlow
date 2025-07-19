# api/config.py
import os
from datetime import timedelta

class Config:
    """Base configuration"""
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    
    # Database Configuration
    DATABASE_URL = os.environ.get('DATABASE_URL') or \
        'postgresql://SYSTEM:SYSTEM@localhost:5432/task_management'
    
    # Database connection pool settings
    DB_POOL_SIZE = int(os.environ.get('DB_POOL_SIZE', '10'))
    DB_POOL_MAX_OVERFLOW = int(os.environ.get('DB_POOL_MAX_OVERFLOW', '20'))
    DB_POOL_TIMEOUT = int(os.environ.get('DB_POOL_TIMEOUT', '30'))
    
    # Session Configuration
    PERMANENT_SESSION_LIFETIME = timedelta(hours=8)
    SESSION_COOKIE_SECURE = os.environ.get('SESSION_COOKIE_SECURE', 'False').lower() == 'true'
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    
    # CORS Configuration
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', 'http://localhost:3000').split(',')
    
    # Logging Configuration
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    
class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    
class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    SESSION_COOKIE_SECURE = True
    
class TestingConfig(Config):
    """Testing configuration"""
    TESTING = True
    DATABASE_URL = os.environ.get('TEST_DATABASE_URL') or \
        'postgresql://SYSTEM:SYSTEM@localhost:5432/task_management_test'

config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}

# api/services/__init__.py
"""
Service layer initialization and dependency injection.
This module sets up all the service classes and their dependencies.
"""

from api.database.database_service import DatabaseService
from api.services.customer_service import CustomerService
from api.services.equipment_service import EquipmentService
from api.services.hire_service import HireService
from api.services.allocation_service import AllocationService
from api.services.driver_task_service import DriverTaskService
from api.services.quality_control_service import QualityControlService
from api.config import Config

class ServiceContainer:
    """
    Service container for dependency injection.
    Manages service instances and their dependencies.
    """
    
    def __init__(self, database_url: str = None):
        self.database_url = database_url or Config.DATABASE_URL
        self._db_service = None
        self._services = {}
    
    @property
    def db_service(self) -> DatabaseService:
        """Get database service instance (singleton)"""
        if self._db_service is None:
            self._db_service = DatabaseService(self.database_url)
        return self._db_service
    
    @property
    def customer_service(self) -> CustomerService:
        """Get customer service instance"""
        if 'customer' not in self._services:
            self._services['customer'] = CustomerService(self.db_service)
        return self._services['customer']
    
    @property
    def equipment_service(self) -> EquipmentService:
        """Get equipment service instance"""
        if 'equipment' not in self._services:
            self._services['equipment'] = EquipmentService(self.db_service)
        return self._services['equipment']
    
    @property
    def hire_service(self) -> HireService:
        """Get hire service instance"""
        if 'hire' not in self._services:
            self._services['hire'] = HireService(self.db_service)
        return self._services['hire']
    
    @property
    def allocation_service(self) -> AllocationService:
        """Get allocation service instance"""
        if 'allocation' not in self._services:
            self._services['allocation'] = AllocationService(self.db_service)
        return self._services['allocation']
    
    @property
    def driver_task_service(self) -> DriverTaskService:
        """Get driver task service instance"""
        if 'driver_task' not in self._services:
            self._services['driver_task'] = DriverTaskService(self.db_service)
        return self._services['driver_task']
    
    @property
    def quality_control_service(self) -> QualityControlService:
        """Get quality control service instance"""
        if 'quality_control' not in self._services:
            self._services['quality_control'] = QualityControlService(self.db_service)
        return self._services['quality_control']
    
    def health_check(self) -> dict:
        """Check health of all services"""
        health_status = {
            'database': 'unknown',
            'services': {}
        }
        
        try:
            # Test database connection
            test_result = self.db_service.execute_query("SELECT 1 as test")
            health_status['database'] = 'healthy' if test_result else 'unhealthy'
        except Exception as e:
            health_status['database'] = f'error: {str(e)}'
        
        # Test each service
        services_to_test = [
            ('customer', self.customer_service),
            ('equipment', self.equipment_service),
            ('hire', self.hire_service),
            ('allocation', self.allocation_service),
            ('driver_task', self.driver_task_service),
            ('quality_control', self.quality_control_service)
        ]
        
        for service_name, service in services_to_test:
            try:
                # Simple test - just check if service can be instantiated
                health_status['services'][service_name] = 'healthy'
            except Exception as e:
                health_status['services'][service_name] = f'error: {str(e)}'
        
        return health_status

# Global service container instance
_service_container = None

def get_service_container(database_url: str = None) -> ServiceContainer:
    """Get global service container instance"""
    global _service_container
    if _service_container is None:
        _service_container = ServiceContainer(database_url)
    return _service_container

def initialize_services(app):
    """Initialize services with Flask app configuration"""
    database_url = app.config.get('DATABASE_URL')
    global _service_container
    _service_container = ServiceContainer(database_url)
    return _service_container

# api/utils/response_helpers.py
"""
Helper functions for standardizing API responses.
"""

from flask import jsonify
from typing import Any, Dict, List, Optional
import logging

logger = logging.getLogger(__name__)

def success_response(data: Any = None, message: str = None, count: int = None) -> Dict[str, Any]:
    """Create a standardized success response"""
    response = {'success': True}
    
    if data is not None:
        response['data'] = data
    
    if message:
        response['message'] = message
    
    if count is not None:
        response['count'] = count
    elif isinstance(data, list):
        response['count'] = len(data)
    
    return jsonify(response)

def error_response(error: str, details: str = None, status_code: int = 400) -> tuple:
    """Create a standardized error response"""
    response = {
        'success': False,
        'error': error
    }
    
    if details:
        response['details'] = details
    
    return jsonify(response), status_code

def validation_error_response(validation_errors: List[Dict[str, str]], 
                            warnings: List[Dict[str, str]] = None) -> tuple:
    """Create a response for validation errors"""
    response = {
        'success': False,
        'error': 'Validation failed',
        'validation_errors': validation_errors
    }
    
    if warnings:
        response['warnings'] = warnings
    
    return jsonify(response), 400

def handle_service_error(error: Exception, context: str = None) -> tuple:
    """Handle service layer errors consistently"""
    from api.database.database_service import DatabaseError
    
    if isinstance(error, DatabaseError):
        logger.error(f"Database error in {context}: {error.message}")
        return error_response(
            'Database error occurred',
            error.message,
            500
        )
    else:
        logger.error(f"Unexpected error in {context}: {str(error)}")
        return error_response(
            'An unexpected error occurred',
            str(error),
            500
        )

# api/utils/validators.py
"""
Validation utilities for API inputs.
"""

from typing import Dict, List, Any, Optional
from datetime import datetime, date
import re

def validate_required_fields(data: Dict[str, Any], required_fields: List[str]) -> List[Dict[str, str]]:
    """Validate that required fields are present and not empty"""
    errors = []
    
    for field in required_fields:
        if field not in data or data[field] is None or data[field] == '':
            errors.append({
                'field': field,
                'message': f'{field} is required'
            })
    
    return errors

def validate_date_string(date_string: str, field_name: str) -> Optional[Dict[str, str]]:
    """Validate date string format (YYYY-MM-DD)"""
    if not date_string:
        return None
    
    try:
        datetime.strptime(date_string, '%Y-%m-%d')
        return None
    except ValueError:
        return {
            'field': field_name,
            'message': f'{field_name} must be in YYYY-MM-DD format'
        }

def validate_time_string(time_string: str, field_name: str) -> Optional[Dict[str, str]]:
    """Validate time string format (HH:MM)"""
    if not time_string:
        return None
    
    try:
        datetime.strptime(time_string, '%H:%M')
        return None
    except ValueError:
        return {
            'field': field_name,
            'message': f'{field_name} must be in HH:MM format'
        }

def validate_email(email: str, field_name: str) -> Optional[Dict[str, str]]:
    """Validate email format"""
    if not email:
        return None
    
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_pattern, email):
        return {
            'field': field_name,
            'message': f'{field_name} must be a valid email address'
        }
    
    return None

def validate_phone_number(phone: str, field_name: str) -> Optional[Dict[str, str]]:
    """Validate South African phone number format"""
    if not phone:
        return None
    
    # Remove spaces and common separators
    cleaned_phone = re.sub(r'[\s\-\(\)]', '', phone)
    
    # Check for valid SA phone number patterns
    sa_patterns = [
        r'^0\d{9}$',  # 0123456789 (landline/mobile)
        r'^\+27\d{9}$',  # +27123456789
        r'^27\d{9}$'  # 27123456789
    ]
    
    if not any(re.match(pattern, cleaned_phone) for pattern in sa_patterns):
        return {
            'field': field_name,
            'message': f'{field_name} must be a valid South African phone number'
        }
    
    return None

def validate_hire_request_data(data: Dict[str, Any]) -> List[Dict[str, str]]:
    """Comprehensive validation for hire request data"""
    errors = []
    
    # Required fields
    required_fields = ['customer_id', 'contact_id', 'site_id', 'equipment_selections', 'delivery_date']
    errors.extend(validate_required_fields(data, required_fields))
    
    # Validate date fields
    if 'delivery_date' in data:
        date_error = validate_date_string(data['delivery_date'], 'delivery_date')
        if date_error:
            errors.append(date_error)
    
    if 'delivery_time' in data and data['delivery_time']:
        time_error = validate_time_string(data['delivery_time'], 'delivery_time')
        if time_error:
            errors.append(time_error)
    
    # Validate equipment selections
    if 'equipment_selections' in data:
        equipment_selections = data['equipment_selections']
        if not isinstance(equipment_selections, list) or len(equipment_selections) == 0:
            errors.append({
                'field': 'equipment_selections',
                'message': 'At least one equipment item must be selected'
            })
        else:
            for i, equipment in enumerate(equipment_selections):
                if not isinstance(equipment, dict):
                    errors.append({
                        'field': f'equipment_selections[{i}]',
                        'message': 'Equipment selection must be an object'
                    })
                    continue
                
                if 'equipment_type_id' not in equipment or 'quantity' not in equipment:
                    errors.append({
                        'field': f'equipment_selections[{i}]',
                        'message': 'Equipment selection must have equipment_type_id and quantity'
                    })
                
                if equipment.get('quantity', 0) <= 0:
                    errors.append({
                        'field': f'equipment_selections[{i}].quantity',
                        'message': 'Equipment quantity must be greater than 0'
                    })
    
    # Validate accessory selections if present
    if 'accessory_selections' in data and data['accessory_selections']:
        accessory_selections = data['accessory_selections']
        if not isinstance(accessory_selections, list):
            errors.append({
                'field': 'accessory_selections',
                'message': 'Accessory selections must be a list'
            })
        else:
            for i, accessory in enumerate(accessory_selections):
                if not isinstance(accessory, dict):
                    errors.append({
                        'field': f'accessory_selections[{i}]',
                        'message': 'Accessory selection must be an object'
                    })
                    continue
                
                if 'accessory_id' not in accessory or 'quantity' not in accessory:
                    errors.append({
                        'field': f'accessory_selections[{i}]',
                        'message': 'Accessory selection must have accessory_id and quantity'
                    })
                
                if accessory.get('quantity', 0) <= 0:
                    errors.append({
                        'field': f'accessory_selections[{i}].quantity',
                        'message': 'Accessory quantity must be greater than 0'
                    })
    
    return errors

# api/middleware/auth.py
"""
Authentication middleware for API endpoints.
"""

from functools import wraps
from flask import session, jsonify, request
import logging

logger = logging.getLogger(__name__)

def require_auth(f):
    """Decorator to require authentication for API endpoints"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'currentUser' not in session:
            return jsonify({
                'success': False,
                'error': 'Authentication required'
            }), 401
        return f(*args, **kwargs)
    return decorated_function

def require_role(required_role):
    """Decorator to require specific role for API endpoints"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if 'currentUser' not in session:
                return jsonify({
                    'success': False,
                    'error': 'Authentication required'
                }), 401
            
            # In a real implementation, you would fetch the user's role from the database
            # For now, we'll assume all authenticated users have access
            user_role = session.get('userRole', 'employee')
            
            if user_role != required_role and user_role != 'owner':
                return jsonify({
                    'success': False,
                    'error': 'Insufficient permissions'
                }), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def log_api_access(f):
    """Decorator to log API access"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        user = session.get('currentUser', 'anonymous')
        logger.info(f"API access: {request.method} {request.path} by {user}")
        return f(*args, **kwargs)
    return decorated_function