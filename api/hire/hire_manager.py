"""
Hire Management System - Comprehensive Python Class
Handles all hire creation, customer selection, equipment management using stored procedures
"""

import os
import json
import psycopg2
import psycopg2.extras
from datetime import datetime, date
from decimal import Decimal
from typing import List, Dict, Optional, Any
import logging

logger = logging.getLogger(__name__)


class HireManager:
    """Comprehensive hire management class using stored procedures"""
    
    def __init__(self):
        self.db_config = {
            'host': os.getenv('PGHOST', 'localhost'),
            'database': os.getenv('PGDATABASE', 'hire_system'),
            'user': os.getenv('PGUSER', 'postgres'),
            'password': os.getenv('PGPASSWORD', 'password'),
            'port': os.getenv('PGPORT', '5432')
        }
    
    def get_db_connection(self):
        """Get database connection with proper error handling"""
        try:
            if os.getenv('DATABASE_URL'):
                conn = psycopg2.connect(os.getenv('DATABASE_URL'))
            else:
                conn = psycopg2.connect(**self.db_config)
            
            conn.autocommit = True
            return conn
        except psycopg2.Error as e:
            logger.error(f"Database connection error: {e}")
            raise
    
    def execute_stored_procedure(self, proc_name: str, params: List = None) -> List[Dict]:
        """Execute stored procedure and return results as dictionaries"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            if params:
                cursor.callproc(proc_name, params)
            else:
                cursor.callproc(proc_name)
            
            try:
                results = cursor.fetchall()
                cursor.close()
                conn.close()
                return [dict(row) for row in results]
            except psycopg2.ProgrammingError:
                cursor.close()
                conn.close()
                return []
        except psycopg2.Error as e:
            logger.error(f"Stored procedure error: {e}")
            raise
    
    def execute_query(self, query: str, params: List = None) -> List[Dict]:
        """Execute direct SQL query and return results"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            
            try:
                results = cursor.fetchall()
                cursor.close()
                conn.close()
                return [dict(row) for row in results]
            except psycopg2.ProgrammingError:
                cursor.close()
                conn.close()
                return []
        except psycopg2.Error as e:
            logger.error(f"Query execution error: {e}")
            raise
    
    # =========================================================================
    # CUSTOMER MANAGEMENT
    # =========================================================================
    
    def search_customers(self, search_term: str = '') -> List[Dict]:
        """Search customers using stored procedure"""
        try:
            # Rename fields to match frontend expectations
            results = self.execute_stored_procedure('sp_get_customers_for_selection', [search_term])
            return [
                {
                    'id': row['customer_id'],
                    'name': row['customer_name'], 
                    'customer_code': row['customer_code']
                }
                for row in results
            ]
        except Exception as e:
            logger.error(f"Error searching customers: {e}")
            raise
    
    def get_customer_contacts(self, customer_id: int) -> List[Dict]:
        """Get contacts for a specific customer"""
        try:
            return self.execute_stored_procedure('sp_get_customer_contacts', [customer_id])
        except Exception as e:
            logger.error(f"Error fetching customer contacts: {e}")
            raise
    
    def get_customer_sites(self, customer_id: int) -> List[Dict]:
        """Get delivery sites for a specific customer"""
        try:
            return self.execute_stored_procedure('sp_get_customer_sites', [customer_id])
        except Exception as e:
            logger.error(f"Error fetching customer sites: {e}")
            raise
    
    # =========================================================================
    # EQUIPMENT MANAGEMENT
    # =========================================================================
    
    def search_equipment_types(self, search_term: str = '', hire_start_date: str = None, hire_end_date: str = None) -> List[Dict]:
        """Search equipment types with availability checking"""
        try:
            return self.execute_stored_procedure('sp_get_available_equipment_types', [search_term, hire_start_date, hire_end_date])
        except Exception as e:
            logger.error(f"Error searching equipment types: {e}")
            raise
    
    def search_specific_equipment(self, search_term: str = '', hire_start_date: str = None, hire_end_date: str = None) -> List[Dict]:
        """Search specific equipment units with availability checking"""
        try:
            return self.execute_stored_procedure('sp_get_available_individual_equipment', [search_term, hire_start_date, hire_end_date])
        except Exception as e:
            logger.error(f"Error searching specific equipment: {e}")
            raise
    
    def get_equipment_type_accessories(self, equipment_type_id: int) -> List[Dict]:
        """Get accessories for a specific equipment type"""
        try:
            return self.execute_stored_procedure('sp_get_equipment_type_accessories', [equipment_type_id])
        except Exception as e:
            logger.error(f"Error fetching equipment type accessories: {e}")
            raise
    
    def get_equipment_accessories(self, equipment_id: int) -> List[Dict]:
        """Get accessories for a specific equipment unit"""
        try:
            return self.execute_stored_procedure('sp_get_equipment_accessories', [equipment_id])
        except Exception as e:
            logger.error(f"Error fetching equipment accessories: {e}")
            raise
    
    def calculate_auto_accessories(self, equipment_types: List[Dict]) -> List[Dict]:
        """Calculate automatic accessories for equipment types"""
        try:
            return self.execute_stored_procedure('sp_calculate_auto_accessories', [json.dumps(equipment_types)])
        except Exception as e:
            logger.error(f"Error calculating auto accessories: {e}")
            raise
    
    # =========================================================================
    # HIRE MANAGEMENT
    # =========================================================================
    
    def validate_hire_request(self, hire_data: Dict) -> Dict:
        """Validate hire request before creation"""
        try:
            result = self.execute_stored_procedure('sp_validate_hire_request', [
                hire_data.get('customer_id'),
                hire_data.get('contact_id'),
                hire_data.get('site_id'),
                hire_data.get('hire_start_date'),
                hire_data.get('hire_end_date'),
                json.dumps(hire_data.get('equipment_types', [])),
                json.dumps(hire_data.get('accessories', []))
            ])
            return dict(result[0]) if result else {'is_valid': False, 'error_message': 'Validation failed'}
        except Exception as e:
            logger.error(f"Error validating hire request: {e}")
            return {'is_valid': False, 'error_message': str(e)}
    
    def create_hire(self, hire_data: Dict, employee_id: int = 1) -> Dict:
        """Create new hire interaction using stored procedure"""
        try:
            logger.info(f"Creating hire with data: {hire_data}")
            
            # Validate the hire request first
            validation = self.validate_hire_request(hire_data)
            if not validation.get('is_valid'):
                return {
                    'success': False,
                    'error_message': validation.get('error_message', 'Validation failed')
                }
            
            # Create the hire using stored procedure
            result = self.execute_stored_procedure('sp_create_hire_interaction', [
                hire_data.get('customer_id'),
                hire_data.get('contact_id'),
                employee_id,
                hire_data.get('site_id'),
                hire_data.get('contact_method', 'phone'),
                hire_data.get('hire_start_date'),
                hire_data.get('hire_end_date'),
                hire_data.get('delivery_date'),
                hire_data.get('delivery_time'),
                hire_data.get('special_instructions'),
                hire_data.get('notes'),
                json.dumps(hire_data.get('equipment_types', [])),
                json.dumps(hire_data.get('accessories', []))
            ])
            
            logger.info(f"Hire creation result: {result}")
            
            if result and len(result) > 0:
                hire_result = dict(result[0])
                if hire_result.get('success', False):
                    return {
                        'success': True,
                        'interaction_id': hire_result.get('interaction_id'),
                        'reference_number': hire_result.get('reference_number'),
                        'message': 'Hire created successfully'
                    }
                else:
                    return {
                        'success': False,
                        'error_message': hire_result.get('error_message', 'Unknown error occurred')
                    }
            else:
                return {
                    'success': False,
                    'error_message': 'No result returned from hire creation'
                }
                
        except Exception as e:
            logger.error(f"Error creating hire: {e}")
            return {
                'success': False,
                'error_message': str(e)
            }
    
    def get_hire_details(self, interaction_id: int) -> Dict:
        """Get hire details with equipment and accessories using new stored procedure"""
        try:
            result = self.execute_stored_procedure('sp_get_hire_details', [interaction_id])
            if result and len(result) > 0:
                hire_details = result[0]
                # Parse JSON fields if they're strings
                if isinstance(hire_details.get('equipment'), str):
                    import json
                    hire_details['equipment'] = json.loads(hire_details['equipment'])
                if isinstance(hire_details.get('accessories'), str):
                    import json
                    hire_details['accessories'] = json.loads(hire_details['accessories'])
                return hire_details
            return None
        except Exception as e:
            logger.error(f"Error fetching hire details: {e}")
            return {'error': str(e)}
    
    def get_all_hires(self, filters: Dict = None) -> List[Dict]:
        """Get all hires with optional filtering"""
        try:
            query = """
                SELECT 
                    i.id,
                    i.reference_number,
                    i.hire_start_date,
                    i.hire_end_date,
                    i.delivery_date,
                    i.status,
                    i.created_date,
                    c.name as customer_name,
                    c.account_code,
                    cc.name as contact_name,
                    cs.name as site_name
                FROM interactions.interactions i
                LEFT JOIN core.customers c ON i.customer_id = c.id
                LEFT JOIN core.customer_contacts cc ON i.contact_id = cc.id
                LEFT JOIN core.customer_sites cs ON i.site_id = cs.id
                WHERE i.interaction_type = 'hire'
                ORDER BY i.created_date DESC
                LIMIT 100
            """
            return self.execute_query(query)
        except Exception as e:
            logger.error(f"Error fetching all hires: {e}")
            raise
    
    # =========================================================================
    # UTILITY METHODS
    # =========================================================================
    
    def serialize_decimal(self, obj):
        """JSON serializer for Decimal objects"""
        import time
        if isinstance(obj, Decimal):
            return float(obj)
        elif isinstance(obj, (date, datetime)):
            return obj.isoformat()
        elif isinstance(obj, time.struct_time):
            return str(obj)
        elif hasattr(obj, 'strftime'):  # For time objects
            return obj.strftime('%H:%M:%S')
        raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
    
    def get_todays_hires(self, date=None):
        """Get all hires for a specific date (default today)."""
        try:
            if not date:
                from datetime import datetime
                date = datetime.now().strftime('%Y-%m-%d')
            
            result = self.execute_stored_procedure('sp_get_todays_hires', [date])
            
            # Convert result to be JSON serializable
            if result:
                import json
                json_result = json.loads(json.dumps(result, default=self.serialize_decimal))
                return json_result
            return []
        except Exception as e:
            logger.error(f"Error getting today's hires: {str(e)}")
            return []
    
    def get_pending_allocations(self):
        """Get hires that have generic equipment needing allocation."""
        try:
            result = self.execute_stored_procedure('sp_get_pending_allocations', [])
            return result if result else []
        except Exception as e:
            logger.error(f"Error getting pending allocations: {str(e)}")
            return []
    
    def get_available_equipment(self, equipment_type_id):
        """Get available equipment for a specific type."""
        try:
            result = self.execute_stored_procedure('sp_get_available_equipment_for_allocation', [equipment_type_id])
            return result if result else []
        except Exception as e:
            logger.error(f"Error getting available equipment: {str(e)}")
            return []
    
    def allocate_equipment(self, data):
        """Allocate specific equipment to a hire."""
        try:
            hire_id = data.get('hire_id')
            equipment_type_id = data.get('equipment_type_id')
            equipment_ids = data.get('equipment_ids', [])
            
            result = self.execute_stored_procedure('sp_allocate_equipment', [
                hire_id, equipment_type_id, equipment_ids
            ])
            
            if result:
                return {'success': True, 'message': 'Equipment allocated successfully'}
            else:
                return {'success': False, 'error': 'Failed to allocate equipment'}
        except Exception as e:
            logger.error(f"Error allocating equipment: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def remove_equipment(self, data):
        """Remove equipment from a hire."""
        try:
            hire_id = data.get('hire_id')
            equipment_type_id = data.get('equipment_type_id')
            equipment_id = data.get('equipment_id')
            
            result = self.execute_stored_procedure('sp_remove_hire_equipment', [
                hire_id, equipment_type_id, equipment_id
            ])
            
            if result:
                return {'success': True, 'message': 'Equipment removed successfully'}
            else:
                return {'success': False, 'error': 'Failed to remove equipment'}
        except Exception as e:
            logger.error(f"Error removing equipment: {str(e)}")
            return {'success': False, 'error': str(e)}

    def get_hire_details(self, hire_id):
        """Get detailed hire information by ID."""
        try:
            result = self.execute_stored_procedure('sp_get_hire_details', [hire_id])
            
            if result and len(result) > 0:
                import json
                hire_data = json.loads(json.dumps(result[0], default=self.serialize_decimal))
                return hire_data
            else:
                return {'error': 'Hire not found'}
        except Exception as e:
            logger.error(f"Error getting hire details: {str(e)}")
            return {'error': str(e)}