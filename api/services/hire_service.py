# api/services/hire_service.py
import json
from typing import List, Dict, Any, Optional
from datetime import date, time, datetime
from api.database.database_service import DatabaseService, handle_database_errors

class HireService:
    def __init__(self, db_service: DatabaseService):
        self.db = db_service
    
    @handle_database_errors
    def validate_hire_request(self, hire_data: Dict[str, Any]) -> Dict[str, Any]:
        """Validate hire request before creation"""
        equipment_json = json.dumps(hire_data.get('equipment_selections', []))
        
        result = self.db.execute_procedure(
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
        return result[0] if result else {'is_valid': False, 'validation_errors': [], 'warnings': []}
    
    @handle_database_errors
    def create_hire_interaction(self, hire_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create complete hire interaction with equipment booking and driver task"""
        equipment_json = json.dumps(hire_data.get('equipment_selections', []))
        accessories_json = json.dumps(hire_data.get('accessory_selections', []))
        
        result = self.db.execute_procedure(
            'sp_create_hire_interaction',
            [
                hire_data['customer_id'],
                hire_data['contact_id'],
                hire_data['employee_id'],
                hire_data['site_id'],
                hire_data.get('contact_method', 'phone'),
                hire_data.get('notes', ''),
                equipment_json,
                accessories_json,
                hire_data['delivery_date'],
                hire_data.get('delivery_time'),
                hire_data.get('hire_start_date'),
                hire_data.get('estimated_hire_end')
            ]
        )
        return result[0] if result else {'success': False, 'message': 'Failed to create hire interaction'}
    
    @handle_database_errors
    def get_hire_details(self, interaction_id: int) -> Dict[str, Any]:
        """Get complete hire interaction details for display"""
        # Get main interaction details
        main_details = self.db.execute_procedure(
            'sp_get_hire_interaction_details',
            [interaction_id]
        )
        
        # Get equipment list
        equipment_list = self.db.execute_procedure(
            'sp_get_hire_equipment_list',
            [interaction_id]
        )
        
        # Get accessories list
        accessories_list = self.db.execute_procedure(
            'sp_get_hire_accessories_list',
            [interaction_id]
        )
        
        return {
            'interaction': main_details[0] if main_details else None,
            'equipment': equipment_list,
            'accessories': accessories_list,
            'total_equipment_items': len(equipment_list),
            'total_accessories': len(accessories_list)
        }
    
    @handle_database_errors
    def get_hire_list(self, filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Get paginated hire list with filters"""
        if filters is None:
            filters = {}
        
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
    
    @handle_database_errors
    def get_hire_dashboard_summary(self, date_from: date = None, date_to: date = None) -> Dict[str, Any]:
        """Get summary statistics for hire management dashboard"""
        result = self.db.execute_procedure(
            'sp_get_hire_dashboard_summary',
            [date_from, date_to]
        )
        return result[0] if result else {}
    
    def prepare_hire_creation_data(self, customer_id: int = None) -> Dict[str, Any]:
        """
        Prepare all data needed for hire creation interface.
        This follows the hire process documentation workflow.
        """
        from api.services.customer_service import CustomerService
        from api.services.equipment_service import EquipmentService
        
        customer_service = CustomerService(self.db)
        equipment_service = EquipmentService(self.db)
        
        data = {
            'customers': customer_service.get_customers_for_selection(),
            'equipment_types': equipment_service.get_equipment_types(),
            'generic_accessories': equipment_service.get_equipment_accessories(),
        }
        
        # If customer is pre-selected, get their contacts and sites
        if customer_id:
            data['customer_contacts'] = customer_service.get_customer_contacts(customer_id)
            data['customer_sites'] = customer_service.get_customer_sites(customer_id)
            data['customer_summary'] = customer_service.get_customer_summary(customer_id)
        
        return data
    
    def format_hire_display(self, hire_details: Dict[str, Any]) -> Dict[str, Any]:
        """
        Format hire details for frontend display following the process documentation
        """
        if not hire_details.get('interaction'):
            return {}
        
        interaction = hire_details['interaction']
        equipment = hire_details.get('equipment', [])
        accessories = hire_details.get('accessories', [])
        
        # Format equipment summary
        equipment_summary = []
        for eq in equipment:
            equipment_summary.append(f"{eq['type_code']} ({eq['booked_quantity']})")
        
        # Format progress status
        progress_status = {
            'equipment_booked': len(equipment) > 0,
            'equipment_allocated': all(eq.get('allocated_quantity', 0) >= eq.get('booked_quantity', 0) for eq in equipment),
            'delivery_scheduled': bool(interaction.get('delivery_date')),
        }
        
        return {
            'reference_number': interaction['reference_number'],
            'status': interaction['interaction_status'],
            'customer_name': interaction['customer_name'],
            'contact_name': interaction['contact_name'],
            'contact_phone': interaction['contact_phone'],
            'delivery_address': interaction['site_address'],
            'delivery_date': interaction.get('delivery_date'),
            'delivery_time': interaction.get('delivery_time'),
            'equipment_summary': ', '.join(equipment_summary),
            'accessories_count': len(accessories),
            'progress_status': progress_status,
            'created_at': interaction['created_at'],
            'notes': interaction.get('notes'),
            'raw_details': hire_details  # Include full details for detailed view
        }
    
    def create_hire_from_process_data(self, process_data: Dict[str, Any], employee_id: int) -> Dict[str, Any]:
        """
        Create hire interaction from frontend process data.
        This handles the complete hire process as documented.
        """
        # Validate required fields
        required_fields = ['customer_id', 'contact_id', 'site_id', 'equipment_selections', 'delivery_date']
        missing_fields = [field for field in required_fields if not process_data.get(field)]
        
        if missing_fields:
            return {
                'success': False,
                'message': f'Missing required fields: {", ".join(missing_fields)}',
                'validation_errors': [{'field': field, 'message': 'Required field'} for field in missing_fields]
            }
        
        # Build hire data structure
        hire_data = {
            'customer_id': process_data['customer_id'],
            'contact_id': process_data['contact_id'],
            'site_id': process_data['site_id'],
            'employee_id': employee_id,
            'contact_method': process_data.get('contact_method', 'phone'),
            'notes': process_data.get('notes', ''),
            'equipment_selections': process_data['equipment_selections'],
            'accessory_selections': process_data.get('accessory_selections', []),
            'delivery_date': process_data['delivery_date'],
            'delivery_time': process_data.get('delivery_time'),
            'hire_start_date': process_data.get('hire_start_date'),
            'estimated_hire_end': process_data.get('estimated_hire_end')
        }
        
        # Validate the hire request first
        validation_result = self.validate_hire_request(hire_data)
        if not validation_result.get('is_valid', False):
            return {
                'success': False,
                'message': 'Hire validation failed',
                'validation_errors': validation_result.get('validation_errors', []),
                'warnings': validation_result.get('warnings', [])
            }
        
        # Create the hire interaction
        creation_result = self.create_hire_interaction(hire_data)
        
        if creation_result.get('success', False):
            # Get the created hire details for return
            hire_details = self.get_hire_details(creation_result['interaction_id'])
            formatted_hire = self.format_hire_display(hire_details)
            
            return {
                'success': True,
                'message': creation_result.get('message', 'Hire created successfully'),
                'hire': formatted_hire,
                'interaction_id': creation_result['interaction_id'],
                'reference_number': creation_result['reference_number'],
                'driver_task_id': creation_result.get('driver_task_id'),
                'warnings': validation_result.get('warnings', [])
            }
        else:
            return {
                'success': False,
                'message': creation_result.get('message', 'Failed to create hire'),
                'validation_errors': []
            }