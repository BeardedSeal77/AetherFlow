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
    def get_all_accessories(self, search_term: str = None) -> List[Dict[str, Any]]:
        """Get all accessories in the system (for standalone accessory selection)"""
        query = """
        SELECT 
            accessory_id,
            accessory_name,
            accessory_code,
            unit_of_measure,
            is_consumable,
            description
        FROM core.v_accessories_with_equipment
        WHERE (%s IS NULL OR 
            accessory_name ILIKE %s OR 
            accessory_code ILIKE %s OR 
            description ILIKE %s)
        ORDER BY is_consumable DESC, accessory_name;
        """
        
        if search_term:
            search_pattern = f"%{search_term}%"
            params = [search_term, search_pattern, search_pattern, search_pattern]
        else:
            params = [None, None, None, None]
            
        return self.db.execute_query(query, params)
    

    @handle_database_errors
    def get_equipment_accessories_complete(self, equipment_selections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Get ALL accessories for selected equipment with proper quantities.
        This is the simple workflow method that returns everything at once.
        
        Returns list of accessories in frontend format:
        - Default accessories with their calculated quantities  
        - Optional accessories with quantity 0
        """
        if not equipment_selections:
            return []
        
        equipment_type_ids = [sel['equipment_type_id'] for sel in equipment_selections]
        
        # Get calculated default accessories
        calculated_defaults = self.calculate_auto_accessories(equipment_selections)
        default_accessory_ids = {acc['accessory_id'] for acc in calculated_defaults}
        
        # Get ALL accessories for these equipment types
        all_accessories = self.get_equipment_accessories(equipment_type_ids)
        
        # Build the complete list
        result_accessories = []
        
        # Add default accessories with calculated quantities
        for accessory in calculated_defaults:
            result_accessories.append({
                'accessory_id': accessory['accessory_id'],
                'quantity': float(accessory['total_quantity']),
                'accessory_type': 'equipment_default',
                'accessory_name': accessory['accessory_name'],
                'unit_of_measure': accessory.get('unit_of_measure', 'item'),
                'is_consumable': accessory.get('is_consumable', False),
                'equipment_type_id': accessory.get('equipment_type_id')
            })
        
        # Add optional accessories with quantity 0
        for accessory in all_accessories:
            if accessory['accessory_id'] not in default_accessory_ids:
                result_accessories.append({
                    'accessory_id': accessory['accessory_id'],
                    'quantity': 0,
                    'accessory_type': 'equipment_optional',
                    'accessory_name': accessory['accessory_name'],
                    'unit_of_measure': accessory.get('unit_of_measure', 'item'),
                    'is_consumable': accessory.get('is_consumable', False),
                    'equipment_type_id': accessory.get('equipment_type_id')
                })
        
        return result_accessories  
    
    @handle_database_errors
    def get_equipment_accessories_with_defaults(self, equipment_selections: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Get both calculated default accessories and all optional accessories for equipment.
        This is the comprehensive method that handles all accessory logic for the frontend.
        
        Returns:
        {
            'calculated_accessories': [...],  # Default accessories with calculated quantities
            'available_accessories': [...]    # All accessories related to selected equipment
        }
        """
        if not equipment_selections:
            return {
                'calculated_accessories': [],
                'available_accessories': []
            }
        
        # Get equipment type IDs
        equipment_type_ids = [sel['equipment_type_id'] for sel in equipment_selections]
        
        # Calculate default accessories with proper quantities
        calculated_defaults = self.calculate_auto_accessories(equipment_selections)
        
        # Transform to frontend format
        default_accessories = []
        for accessory in calculated_defaults:
            default_accessories.append({
                'accessory_id': accessory['accessory_id'],
                'quantity': float(accessory['total_quantity']),
                'accessory_type': 'default',
                'accessory_name': accessory['accessory_name']
            })
        
        # Get all accessories related to the selected equipment types
        all_equipment_accessories = self.get_equipment_accessories(equipment_type_ids)
        
        # Create optional accessories with 0 quantity (user can increase them)
        optional_accessories = []
        default_accessory_ids = {acc['accessory_id'] for acc in calculated_defaults}
        
        for accessory in all_equipment_accessories:
            # Skip if it's already included as a default
            if accessory['accessory_id'] in default_accessory_ids:
                continue
                
            # Add as optional with 0 quantity
            optional_accessories.append({
                'accessory_id': accessory['accessory_id'],
                'quantity': 0,
                'accessory_type': 'optional',
                'accessory_name': accessory['accessory_name']
            })
        
        return {
            'calculated_accessories': default_accessories + optional_accessories,
            'available_accessories': all_equipment_accessories
        }
    

    @handle_database_errors
    def validate_accessory_selection(self, accessory_selections: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Validate accessory selections and return validation results.
        Checks for valid accessory IDs, reasonable quantities, etc.
        """
        validation_result = {
            'valid': True,
            'errors': [],
            'warnings': []
        }
        
        if not accessory_selections:
            return validation_result
        
        # Get all valid accessory IDs
        all_accessories_query = """
        SELECT accessory_id, accessory_name, is_consumable, unit_of_measure
        FROM core.accessories 
        WHERE status = 'active'
        """
        valid_accessories = {acc['accessory_id']: acc for acc in self.db.execute_query(all_accessories_query)}
        
        for selection in accessory_selections:
            accessory_id = selection.get('accessory_id')
            quantity = selection.get('quantity', 0)
            
            # Check if accessory exists
            if accessory_id not in valid_accessories:
                validation_result['valid'] = False
                validation_result['errors'].append(f"Invalid accessory ID: {accessory_id}")
                continue
            
            accessory = valid_accessories[accessory_id]
            
            # Check quantity
            if quantity < 0:
                validation_result['valid'] = False
                validation_result['errors'].append(f"Negative quantity for {accessory['accessory_name']}")
            elif quantity == 0 and selection.get('accessory_type') != 'optional':
                validation_result['warnings'].append(f"Zero quantity for {accessory['accessory_name']}")
            elif quantity > 1000:  # Reasonable upper limit
                validation_result['warnings'].append(f"Very high quantity ({quantity}) for {accessory['accessory_name']}")
        
        return validation_result

    
    @handle_database_errors
    def get_equipment_accessories(self, equipment_type_ids: List[int] = None) -> List[Dict[str, Any]]:
        """Get accessories for selected equipment types"""
        if not equipment_type_ids:
            return self.get_all_accessories()
        
        return self.db.execute_procedure(
            'sp_get_equipment_accessories',
            [equipment_type_ids]
        )
    
    @handle_database_errors
    def get_accessories_for_equipment(self, equipment_type_ids: List[int]) -> List[Dict[str, Any]]:
        """
        Get ALL accessories (default and optional) for specific equipment types.
        Used to show users what accessories are available for their selected equipment.
        """
        if not equipment_type_ids:
            return []
            
        accessories = self.db.execute_procedure(
            'sp_get_equipment_accessories',
            [equipment_type_ids]
        )
        
        # Process and deduplicate accessories
        return self._process_equipment_accessories(accessories)
    
    @handle_database_errors
    def calculate_auto_accessories(self, equipment_selections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Calculate default accessories for equipment selection with proper aggregation"""
        if not equipment_selections:
            return []
            
        equipment_json = json.dumps(equipment_selections)
        auto_accessories = self.db.execute_procedure(
            'sp_calculate_auto_accessories',
            [equipment_json]
        )
        
        # Add additional processing and validation
        return self._process_auto_accessories(auto_accessories)
    
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
    
    def prepare_equipment_selection_data(self, search_term: str = None, delivery_date: date = None) -> Dict[str, Any]:
        """
        Prepare all data needed for equipment selection interface
        """
        equipment_types = self.get_equipment_types(search_term, delivery_date)
        all_accessories = self.get_all_accessories()
        
        return {
            'equipment_types': equipment_types,
            'all_accessories': all_accessories,
            'total_equipment_types': len(equipment_types),
            'total_accessories': len(all_accessories)
        }
    
    # ============================================================================
    # PRIVATE PROCESSING METHODS
    # ============================================================================
    
    def _process_equipment_accessories(self, accessories: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Process and deduplicate accessories for equipment"""
        seen_accessories = {}
        processed = []
        
        for accessory in accessories:
            accessory_id = accessory['accessory_id']
            
            if accessory_id not in seen_accessories:
                # First time seeing this accessory
                processed_accessory = {
                    'accessory_id': accessory_id,
                    'accessory_name': accessory['accessory_name'],
                    'accessory_code': accessory['accessory_code'],
                    'accessory_type': accessory['accessory_type'],
                    'default_quantity': accessory['default_quantity'],
                    'unit_of_measure': accessory['unit_of_measure'],
                    'description': accessory['description'],
                    'is_consumable': accessory['is_consumable'],
                    'equipment_types': [accessory['type_name']] if accessory.get('type_name') else []
                }
                
                seen_accessories[accessory_id] = len(processed)
                processed.append(processed_accessory)
            else:
                # Add equipment type to existing accessory
                existing_index = seen_accessories[accessory_id]
                if accessory.get('type_name') and accessory['type_name'] not in processed[existing_index]['equipment_types']:
                    processed[existing_index]['equipment_types'].append(accessory['type_name'])
        
        return processed
    
    def _process_auto_accessories(self, auto_accessories: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Process auto-calculated accessories with validation and enrichment"""
        processed = []
        
        for accessory in auto_accessories:
            # Validate required fields
            if not accessory.get('accessory_id') or not accessory.get('total_quantity'):
                continue
                
            processed_accessory = {
                'accessory_id': accessory['accessory_id'],
                'accessory_name': accessory['accessory_name'],
                'accessory_code': accessory.get('accessory_code', ''),
                'total_quantity': float(accessory['total_quantity']),
                'unit_of_measure': accessory.get('unit_of_measure', 'item'),
                'is_consumable': accessory.get('is_consumable', False),
                'equipment_type_name': accessory.get('equipment_type_name', ''),
                'accessory_type': 'default'  # Auto accessories are always default
            }
            
            # Add validation flags
            processed_accessory['is_valid'] = True
            processed_accessory['warnings'] = []
            
            # Check for potential issues
            if processed_accessory['total_quantity'] > 100:
                processed_accessory['warnings'].append('Large quantity - please verify')
            
            if processed_accessory['is_consumable'] and processed_accessory['total_quantity'] < 1:
                processed_accessory['warnings'].append('Low consumable quantity')
            
            processed.append(processed_accessory)
        
        return processed
    
    def _analyze_availability(self, availability: List[Dict[str, Any]], requests: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Analyze equipment availability and add insights"""
        analyzed = []
        
        for i, avail in enumerate(availability):
            request = requests[i] if i < len(requests) else {}
            
            analyzed_item = {
                **avail,
                'request_quantity': request.get('quantity', 0),
                'availability_status': 'available' if avail.get('available_quantity', 0) >= request.get('quantity', 0) else 'insufficient',
                'shortfall': max(0, request.get('quantity', 0) - avail.get('available_quantity', 0)),
                'utilization_percent': round((request.get('quantity', 0) / max(1, avail.get('total_quantity', 1))) * 100, 1)
            }
            
            # Add recommendations
            if analyzed_item['availability_status'] == 'insufficient':
                analyzed_item['recommendation'] = f"Consider reducing quantity or selecting alternative equipment"
            elif analyzed_item['utilization_percent'] > 80:
                analyzed_item['recommendation'] = f"High utilization - consider booking early"
            else:
                analyzed_item['recommendation'] = f"Good availability"
            
            analyzed.append(analyzed_item)
        
        return analyzed
    
    def _enrich_equipment_data(self, equipment_types: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Enrich equipment data with additional calculated fields"""
        enriched = []
        
        for equipment in equipment_types:
            enriched_equipment = {
                **equipment,
                'availability_percentage': round((equipment.get('available_units', 0) / max(1, equipment.get('total_units', 1))) * 100, 1),
                'status': 'available' if equipment.get('available_units', 0) > 0 else 'unavailable',
                'demand_level': self._calculate_demand_level(equipment.get('available_units', 0), equipment.get('total_units', 1))
            }
            
            enriched.append(enriched_equipment)
        
        return enriched
    
    def _deduplicate_accessories(self, accessories: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Remove duplicate accessories based on accessory_id"""
        seen = set()
        deduplicated = []
        
        for accessory in accessories:
            accessory_id = accessory.get('accessory_id')
            if accessory_id and accessory_id not in seen:
                seen.add(accessory_id)
                deduplicated.append(accessory)
        
        return deduplicated
    
    def _calculate_availability_summary(self, equipment_types: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calculate overall availability summary"""
        if not equipment_types:
            return {'total_types': 0, 'available_types': 0, 'availability_rate': 0}
        
        available_types = sum(1 for eq in equipment_types if eq.get('available_units', 0) > 0)
        
        return {
            'total_types': len(equipment_types),
            'available_types': available_types,
            'unavailable_types': len(equipment_types) - available_types,
            'availability_rate': round((available_types / len(equipment_types)) * 100, 1)
        }
    
    def _calculate_demand_level(self, available_units: int, total_units: int) -> str:
        """Calculate demand level based on availability"""
        if total_units == 0:
            return 'unknown'
        
        availability_percent = (available_units / total_units) * 100
        
        if availability_percent >= 75:
            return 'low'
        elif availability_percent >= 25:
            return 'medium'
        else:
            return 'high'
    
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
        optional_accessories = [a for a in accessories_list if a.get('accessory_type') == 'optional']
        standalone_accessories = [a for a in accessories_list if a.get('accessory_type') == 'standalone']
        
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
        
        # Add optional accessories
        for accessory in optional_accessories:
            if accessory['quantity'] > 0:  # Only show optional accessories with quantities
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
        
        # Add standalone accessories
        for accessory in standalone_accessories:
            display_list.append({
                'type': 'accessory',
                'id': accessory['accessory_id'],
                'name': accessory['accessory_name'],
                'quantity': accessory['quantity'],
                'accessory_type': accessory['accessory_type'],
                'is_consumable': accessory.get('is_consumable', False),
                'icon': '📦'
            })
        
        return display_list