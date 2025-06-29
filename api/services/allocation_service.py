# api/services/allocation_service.py
from typing import List, Dict, Any, Optional
from datetime import date
from api.database.database_service import DatabaseService, handle_database_errors

class AllocationService:
    def __init__(self, db_service: DatabaseService):
        self.db = db_service
    
    @handle_database_errors
    def get_bookings_for_allocation(self, interaction_id: int = None, only_unallocated: bool = True) -> List[Dict[str, Any]]:
        """Get generic bookings ready for Phase 2 allocation"""
        return self.db.execute_procedure(
            'sp_get_bookings_for_allocation',
            [interaction_id, only_unallocated]
        )
    
    @handle_database_errors
    def get_equipment_for_allocation(self, equipment_type_id: int, delivery_date: date = None) -> List[Dict[str, Any]]:
        """Get available equipment units for allocation"""
        return self.db.execute_procedure(
            'sp_get_equipment_for_allocation',
            [equipment_type_id, delivery_date, None]
        )
    
    @handle_database_errors
    def allocate_equipment(self, booking_id: int, equipment_ids: List[int], allocated_by: int) -> List[Dict[str, Any]]:
        """Allocate specific equipment to booking"""
        return self.db.execute_procedure(
            'sp_allocate_specific_equipment',
            [booking_id, equipment_ids, allocated_by]
        )
    
    @handle_database_errors
    def get_allocation_status(self, interaction_id: int) -> List[Dict[str, Any]]:
        """Get allocation progress for interaction"""
        return self.db.execute_procedure(
            'sp_get_allocation_status',
            [interaction_id]
        )
    
    def prepare_allocation_interface_data(self, interaction_id: int = None) -> Dict[str, Any]:
        """
        Prepare all data needed for the allocation interface.
        This supports the Phase 2 equipment allocation process.
        """
        # Get bookings ready for allocation
        bookings = self.get_bookings_for_allocation(interaction_id, only_unallocated=True)
        
        allocation_data = {
            'bookings': bookings,
            'allocation_options': {},
            'summary': {
                'total_bookings': len(bookings),
                'bookings_by_type': {},
                'pending_allocations': 0
            }
        }
        
        # For each booking, get available equipment for allocation
        for booking in bookings:
            equipment_type_id = booking['equipment_type_id']
            delivery_date = booking.get('delivery_date')
            
            available_equipment = self.get_equipment_for_allocation(
                equipment_type_id, delivery_date
            )
            
            allocation_data['allocation_options'][booking['booking_id']] = {
                'booking': booking,
                'available_equipment': available_equipment,
                'available_count': len([eq for eq in available_equipment if eq['is_available']]),
                'required_quantity': booking['remaining_quantity']
            }
            
            # Update summary
            type_name = booking['type_name']
            if type_name not in allocation_data['summary']['bookings_by_type']:
                allocation_data['summary']['bookings_by_type'][type_name] = 0
            allocation_data['summary']['bookings_by_type'][type_name] += booking['remaining_quantity']
            allocation_data['summary']['pending_allocations'] += booking['remaining_quantity']
        
        return allocation_data
    
    def process_bulk_allocation(self, allocations: List[Dict[str, Any]], allocated_by: int) -> Dict[str, Any]:
        """
        Process multiple equipment allocations in bulk.
        Expected format: [{'booking_id': int, 'equipment_ids': [int, ...]}]
        """
        results = {
            'successful_allocations': [],
            'failed_allocations': [],
            'summary': {'total': 0, 'successful': 0, 'failed': 0}
        }
        
        for allocation in allocations:
            booking_id = allocation['booking_id']
            equipment_ids = allocation['equipment_ids']
            
            try:
                allocation_results = self.allocate_equipment(booking_id, equipment_ids, allocated_by)
                
                for result in allocation_results:
                    results['summary']['total'] += 1
                    if result.get('success', False):
                        results['successful_allocations'].append(result)
                        results['summary']['successful'] += 1
                    else:
                        results['failed_allocations'].append(result)
                        results['summary']['failed'] += 1
                        
            except Exception as e:
                results['failed_allocations'].append({
                    'booking_id': booking_id,
                    'equipment_ids': equipment_ids,
                    'success': False,
                    'message': f'Allocation failed: {str(e)}'
                })
                results['summary']['total'] += len(equipment_ids)
                results['summary']['failed'] += len(equipment_ids)
        
        return results
    
    def get_allocation_summary_for_interaction(self, interaction_id: int) -> Dict[str, Any]:
        """
        Get comprehensive allocation summary for an interaction.
        This is useful for the drivers taskboard and progress tracking.
        """
        allocation_status = self.get_allocation_status(interaction_id)
        
        summary = {
            'interaction_id': interaction_id,
            'equipment_types': [],
            'overall_status': 'not_allocated',
            'progress': {
                'total_equipment_types': len(allocation_status),
                'fully_allocated_types': 0,
                'partially_allocated_types': 0,
                'unallocated_types': 0,
                'total_units_required': 0,
                'total_units_allocated': 0
            }
        }
        
        for status in allocation_status:
            equipment_type_info = {
                'equipment_type_id': status['equipment_type_id'],
                'type_name': status['type_name'],
                'booked_quantity': status['booked_quantity'],
                'allocated_quantity': status['allocated_quantity'],
                'allocation_complete': status['allocation_complete'],
                'allocated_equipment': status.get('allocated_equipment', [])
            }
            
            summary['equipment_types'].append(equipment_type_info)
            
            # Update progress counters
            summary['progress']['total_units_required'] += status['booked_quantity']
            summary['progress']['total_units_allocated'] += status['allocated_quantity']
            
            if status['allocation_complete']:
                summary['progress']['fully_allocated_types'] += 1
            elif status['allocated_quantity'] > 0:
                summary['progress']['partially_allocated_types'] += 1
            else:
                summary['progress']['unallocated_types'] += 1
        
        # Determine overall status
        if summary['progress']['fully_allocated_types'] == summary['progress']['total_equipment_types']:
            summary['overall_status'] = 'fully_allocated'
        elif summary['progress']['total_units_allocated'] > 0:
            summary['overall_status'] = 'partially_allocated'
        else:
            summary['overall_status'] = 'not_allocated'
        
        # Calculate allocation percentage
        if summary['progress']['total_units_required'] > 0:
            summary['progress']['allocation_percentage'] = round(
                (summary['progress']['total_units_allocated'] / summary['progress']['total_units_required']) * 100, 1
            )
        else:
            summary['progress']['allocation_percentage'] = 0
        
        return summary