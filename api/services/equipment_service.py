# api/services/equipment_service.py
import json
from typing import List, Dict, Any, Optional
from datetime import date
from api.database.database_service import DatabaseService, handle_database_errors

class EquipmentService:
    def __init__(self, db_service: DatabaseService):
        self.db = db_service
    
    @handle_database_errors
    def get_equipment_types(self, search_term: str = None, delivery_date: date = None) -> List[Dict[str, Any]]:
        """Get available equipment types for Phase 1 - Generic booking"""
        return self.db.execute_procedure(
            'sp_get_available_equipment_types',
            [search_term, delivery_date]
        )
    
    @handle_database_errors
    def get_individual_equipment(self, equipment_type_id: int = None, delivery_date: date = None) -> List[Dict[str, Any]]:
        """Get individual equipment units for Phase 2 - Specific allocation"""
        return self.db.execute_procedure(
            'sp_get_available_individual_equipment',
            [equipment_type_id, delivery_date, None]
        )
    
    @handle_database_errors
    def get_equipment_accessories(self, equipment_type_ids: List[int] = None) -> List[Dict[str, Any]]:
        """Get accessories for selected equipment types"""
        return self.db.execute_procedure(
            'sp_get_equipment_accessories',
            [equipment_type_ids]
        )
    
    @handle_database_errors
    def calculate_auto_accessories(self, equipment_selections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Calculate default accessories for equipment selection"""
        equipment_json = json.dumps(equipment_selections)
        return self.db.execute_procedure(
            'sp_calculate_auto_accessories',
            [equipment_json]
        )
    
    @handle_database_errors
    def check_equipment_availability(self, equipment_requests: List[Dict[str, Any]], check_date: date = None) -> List[Dict[str, Any]]:
        """Check equipment availability for requested dates and quantities"""
        requests_json = json.dumps(equipment_requests)
        return self.db.execute_procedure(
            'sp_check_equipment_availability',
            [requests_json, check_date]
        )
    
    @handle_database_errors
    def get_equipment_for_allocation(self, equipment_type_id: int, delivery_date: date = None) -> List[Dict[str, Any]]:
        """Get available equipment units for allocation to bookings"""
        return self.db.execute_procedure(
            'sp_get_equipment_for_allocation',
            [equipment_type_id, delivery_date, None]
        )
    
    def format_equipment_display_list(self, equipment_list: List[Dict[str, Any]], accessories_list: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Format equipment and accessories for frontend display.
        Pairs equipment with their default accessories and shows extras separately.
        """
        display_list = []
        
        # Add equipment items
        for equipment in equipment_list:
            display_list.append({
                'type': 'equipment',
                'id': equipment['equipment_type_id'],
                'name': equipment['type_name'],
                'code': equipment.get('type_code', ''),
                'quantity': equipment['booked_quantity'],
                'status': equipment.get('booking_status', 'booked'),
                'icon': '🔧'
            })
        
        # Group accessories by type
        default_accessories = [a for a in accessories_list if a.get('accessory_type') == 'default']
        optional_accessories = [a for a in accessories_list if a.get('accessory_type') != 'default']
        
        # Add default accessories (paired with equipment)
        for accessory in default_accessories:
            display_list.append({
                'type': 'accessory',
                'id': accessory['accessory_id'],
                'name': accessory['accessory_name'],
                'quantity': accessory['quantity'],
                'accessory_type': accessory['accessory_type'],
                'is_consumable': accessory.get('is_consumable', False),
                'equipment_type': accessory.get('equipment_type_name'),
                'icon': '📦'
            })
        
        # Add optional/extra accessories at the end
        for accessory in optional_accessories:
            display_list.append({
                'type': 'accessory',
                'id': accessory['accessory_id'],
                'name': accessory['accessory_name'],
                'quantity': accessory['quantity'],
                'accessory_type': accessory['accessory_type'],
                'is_consumable': accessory.get('is_consumable', False),
                'equipment_type': accessory.get('equipment_type_name'),
                'icon': '📦'
            })
        
        return display_list
    
    def prepare_equipment_selection_data(self, search_term: str = None, delivery_date: date = None) -> Dict[str, Any]:
        """
        Prepare all data needed for equipment selection interface
        """
        equipment_types = self.get_equipment_types(search_term, delivery_date)
        accessories = self.get_equipment_accessories()
        
        # Group accessories by equipment type
        accessories_by_type = {}
        generic_accessories = []
        
        for accessory in accessories:
            if accessory.get('equipment_type_id'):
                type_id = accessory['equipment_type_id']
                if type_id not in accessories_by_type:
                    accessories_by_type[type_id] = []
                accessories_by_type[type_id].append(accessory)
            else:
                generic_accessories.append(accessory)
        
        return {
            'equipment_types': equipment_types,
            'accessories_by_type': accessories_by_type,
            'generic_accessories': generic_accessories,
            'total_equipment_types': len(equipment_types),
            'total_accessories': len(accessories)
        }