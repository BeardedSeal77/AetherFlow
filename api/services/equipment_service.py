# api/services/equipment_service.py - Updated for New Hire Process

import json
from typing import List, Dict, Any, Optional
from datetime import date
from api.database.database_service import DatabaseService, handle_database_errors

class EquipmentService:
    def __init__(self, db_service: DatabaseService):
        self.db = db_service
    
    @handle_database_errors
    def get_equipment_types(self, search_term: str = None, delivery_date: date = None) -> List[Dict[str, Any]]:
        """Get available equipment types for selection"""
        equipment_types = self.db.execute_procedure(
            'sp_get_available_equipment_types',
            [search_term, delivery_date]
        )
        
        # Process and format for frontend
        return [{
            'id': eq['equipment_type_id'],
            'type_code': eq['type_code'],
            'type_name': eq['type_name'],
            'description': eq.get('description', ''),
            'available_units': eq['available_units'],
            'total_units': eq['total_units'],
            'daily_rate': eq.get('daily_rate', 0),
            'category': eq.get('category', 'Equipment')
        } for eq in equipment_types]
    
    @handle_database_errors
    def get_equipment_accessories(self, equipment_type_ids: List[int] = None) -> List[Dict[str, Any]]:
        """Get accessories available for selection (all accessories if no equipment types specified)"""
        accessories = self.db.execute_procedure(
            'sp_get_equipment_accessories',
            [equipment_type_ids]
        )
        
        # Format for frontend
        formatted_accessories = []
        seen_accessories = set()
        
        for acc in accessories:
            accessory_id = acc['accessory_id']
            
            # Deduplicate accessories that appear for multiple equipment types
            if accessory_id not in seen_accessories:
                formatted_accessories.append({
                    'id': accessory_id,
                    'accessory_name': acc['accessory_name'],
                    'accessory_code': acc['accessory_code'],
                    'unit_of_measure': acc['unit_of_measure'],
                    'description': acc.get('description', ''),
                    'is_consumable': acc['is_consumable'],
                    'default_quantity': acc.get('default_quantity', 1),
                    'accessory_type': acc.get('accessory_type', 'optional')
                })
                seen_accessories.add(accessory_id)
        
        return formatted_accessories
    
    @handle_database_errors
    def calculate_auto_accessories(self, equipment_selections: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Calculate default accessories for equipment selection with proper aggregation"""
        
        print(f"=== EQUIPMENT SERVICE DEBUG ===")
        print(f"Received equipment_selections: {equipment_selections}")
        
        if not equipment_selections:
            print("No equipment selections provided to service")
            return []
            
        equipment_json = json.dumps(equipment_selections)
        print(f"Equipment JSON for stored procedure: {equipment_json}")
        
        try:
            auto_accessories = self.db.execute_procedure(
                'sp_calculate_auto_accessories',
                [equipment_json]
            )
            print(f"Stored procedure returned: {auto_accessories}")
            print(f"Number of accessories returned: {len(auto_accessories) if auto_accessories else 0}")
            
            # Process the results
            processed_accessories = []
            for acc in auto_accessories:
                print(f"Processing accessory: {acc}")
                processed = {
                    'accessory_id': acc['accessory_id'],
                    'accessory_name': acc['accessory_name'],
                    'accessory_code': acc['accessory_code'],
                    'quantity': float(acc['total_quantity']),
                    'unit_of_measure': acc['unit_of_measure'],
                    'is_consumable': acc['is_consumable'],
                    'equipment_type_name': acc['equipment_type_name'],
                    'is_default': True
                }
                processed_accessories.append(processed)
                print(f"Processed to: {processed}")
            
            print(f"Final processed accessories: {processed_accessories}")
            return processed_accessories
            
        except Exception as e:
            print(f"Error in equipment service: {str(e)}")
            raise e
    
    @handle_database_errors
    def get_equipment_accessories_complete(self, equipment_selections: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Get complete accessories data for the selection summary.
        This provides both auto-accessories and all available accessories.
        """
        result = {
            'auto_accessories': [],
            'available_accessories': [],
            'equipment_accessories_map': {}
        }
        
        if equipment_selections:
            # Get auto-accessories
            result['auto_accessories'] = self.calculate_auto_accessories(equipment_selections)
            
            # Get equipment-specific accessories for the map
            equipment_type_ids = [eq['equipment_type_id'] for eq in equipment_selections]
            equipment_accessories = self.db.execute_procedure(
                'sp_get_equipment_accessories',
                [equipment_type_ids]
            )
            
            # Build equipment -> accessories mapping
            for acc in equipment_accessories:
                equipment_id = acc['equipment_type_id']
                if equipment_id not in result['equipment_accessories_map']:
                    result['equipment_accessories_map'][equipment_id] = []
                
                result['equipment_accessories_map'][equipment_id].append({
                    'accessory_id': acc['accessory_id'],
                    'accessory_name': acc['accessory_name'],
                    'accessory_code': acc['accessory_code'],
                    'default_quantity': acc['default_quantity'],
                    'unit_of_measure': acc['unit_of_measure'],
                    'accessory_type': acc['accessory_type'],
                    'is_consumable': acc['is_consumable']
                })
        
        # Get all accessories for standalone selection
        result['available_accessories'] = self.get_equipment_accessories([])
        
        return result
    
    @handle_database_errors
    def check_equipment_availability(self, equipment_requests: List[Dict[str, Any]], check_date: date = None) -> List[Dict[str, Any]]:
        """Check equipment availability for requested dates and quantities"""
        requests_json = json.dumps(equipment_requests)
        return self.db.execute_procedure(
            'sp_check_equipment_availability',
            [requests_json, check_date]
        )
    
    def prepare_hire_equipment_data(self, search_term: str = None, delivery_date: date = None) -> Dict[str, Any]:
        """
        Prepare all data needed for the hire equipment selection interface.
        This is a convenience method that gets everything in one call.
        """
        return {
            'equipment_types': self.get_equipment_types(search_term, delivery_date),
            'accessories': self.get_equipment_accessories([]),
            'delivery_date': delivery_date.isoformat() if delivery_date else None,
            'search_term': search_term
        }
    
    def validate_equipment_selection(self, equipment_selections: List[Dict[str, Any]], delivery_date: date = None) -> Dict[str, Any]:
        """
        Validate equipment selection for availability and business rules.
        """
        validation_result = {
            'is_valid': True,
            'errors': [],
            'warnings': []
        }
        
        if not equipment_selections:
            validation_result['is_valid'] = False
            validation_result['errors'].append('No equipment selected')
            return validation_result
        
        # Check availability for each equipment type
        for equipment in equipment_selections:
            if equipment.get('quantity', 0) <= 0:
                validation_result['warnings'].append(
                    f"Equipment {equipment.get('type_name', 'Unknown')} has zero quantity"
                )
        
        # Additional validation can be added here
        # - Credit limit checks
        # - Equipment compatibility checks
        # - Delivery date validation
        
        return validation_result
    
    def format_selection_summary(self, equipment_selections: List[Dict[str, Any]], 
                                accessory_selections: List[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Format equipment and accessory selections for display summary.
        This matches the format expected by your frontend component.
        """
        summary = {
            'equipment': [],
            'accessories': [],
            'auto_accessories': [],
            'totals': {
                'equipment_count': 0,
                'accessory_count': 0,
                'estimated_value': 0
            }
        }
        
        # Process equipment selections
        if equipment_selections:
            summary['equipment'] = equipment_selections
            summary['totals']['equipment_count'] = sum(eq.get('quantity', 0) for eq in equipment_selections)
            
            # Calculate auto-accessories
            auto_accessories = self.calculate_auto_accessories([
                {'equipment_type_id': eq['id'], 'quantity': eq['quantity']} 
                for eq in equipment_selections
            ])
            summary['auto_accessories'] = auto_accessories
        
        # Process accessory selections
        if accessory_selections:
            summary['accessories'] = accessory_selections
            summary['totals']['accessory_count'] = sum(acc.get('quantity', 0) for acc in accessory_selections)
        
        return summary

# Example usage and testing functions
def test_equipment_service():
    """Test function to verify the equipment service is working"""
    from api.database.database_service import DatabaseService
    
    db = DatabaseService()
    service = EquipmentService(db)
    
    try:
        # Test getting equipment types
        equipment_types = service.get_equipment_types()
        print(f"Found {len(equipment_types)} equipment types")
        
        # Test getting accessories
        accessories = service.get_equipment_accessories([])
        print(f"Found {len(accessories)} accessories")
        
        # Test auto-accessories calculation with sample data
        sample_selections = [
            {'equipment_type_id': 1, 'quantity': 2}
        ]
        auto_accessories = service.calculate_auto_accessories(sample_selections)
        print(f"Calculated {len(auto_accessories)} auto-accessories")
        
        return True
        
    except Exception as e:
        print(f"Equipment service test failed: {e}")
        return False

if __name__ == "__main__":
    test_equipment_service()