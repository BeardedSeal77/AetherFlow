# api/services/quality_control_service.py
from typing import List, Dict, Any, Optional
from datetime import date
from api.database.database_service import DatabaseService, handle_database_errors

class QualityControlService:
    def __init__(self, db_service: DatabaseService):
        self.db = db_service
    
    @handle_database_errors
    def get_equipment_pending_qc(self, interaction_id: int = None, employee_id: int = None) -> List[Dict[str, Any]]:
        """Get equipment allocations pending quality control"""
        return self.db.execute_procedure(
            'sp_get_equipment_pending_qc',
            [interaction_id, employee_id]
        )
    
    @handle_database_errors
    def quality_control_signoff(self, allocation_ids: List[int], employee_id: int, 
                               qc_status: str = 'passed', notes: str = None) -> List[Dict[str, Any]]:
        """Process QC sign-off for equipment"""
        return self.db.execute_procedure(
            'sp_quality_control_signoff',
            [allocation_ids, employee_id, qc_status, notes]
        )
    
    @handle_database_errors
    def get_qc_summary(self, date_from: date = None, date_to: date = None) -> Dict[str, Any]:
        """Get quality control statistics and completion rates"""
        result = self.db.execute_procedure(
            'sp_get_qc_summary',
            [date_from, date_to]
        )
        return result[0] if result else {}
    
    def get_qc_dashboard_data(self, filters: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Get comprehensive QC dashboard data with pending items and statistics.
        """
        if filters is None:
            filters = {}
        
        # Get pending QC items
        pending_qc = self.get_equipment_pending_qc(
            interaction_id=filters.get('interaction_id'),
            employee_id=filters.get('employee_id')
        )
        
        # Get QC summary statistics
        qc_summary = self.get_qc_summary(
            date_from=filters.get('date_from'),
            date_to=filters.get('date_to')
        )
        
        # Group pending items by interaction
        pending_by_interaction = {}
        for item in pending_qc:
            interaction_id = item['interaction_id']
            if interaction_id not in pending_by_interaction:
                pending_by_interaction[interaction_id] = {
                    'interaction_id': interaction_id,
                    'reference_number': item['reference_number'],
                    'customer_name': item['customer_name'],
                    'delivery_date': item['delivery_date'],
                    'equipment_items': []
                }
            pending_by_interaction[interaction_id]['equipment_items'].append(item)
        
        # Organize by priority (upcoming deliveries first)
        prioritized_interactions = sorted(
            pending_by_interaction.values(),
            key=lambda x: (x['delivery_date'] or date.max, x['reference_number'])
        )
        
        dashboard_data = {
            'pending_qc_by_interaction': prioritized_interactions,
            'pending_qc_items': pending_qc,
            'summary': qc_summary,
            'counts': {
                'total_pending_items': len(pending_qc),
                'total_pending_interactions': len(pending_by_interaction),
                'urgent_count': len([item for item in pending_qc if item.get('delivery_date') and item['delivery_date'] <= date.today()]),
                'equipment_types': {}
            }
        }
        
        # Count by equipment type
        for item in pending_qc:
            type_name = item['type_name']
            if type_name not in dashboard_data['counts']['equipment_types']:
                dashboard_data['counts']['equipment_types'][type_name] = 0
            dashboard_data['counts']['equipment_types'][type_name] += 1
        
        return dashboard_data
    
    def process_bulk_qc_signoff(self, qc_batch: List[Dict[str, Any]], employee_id: int) -> Dict[str, Any]:
        """
        Process multiple QC sign-offs in bulk.
        Expected format: [{'allocation_ids': [int, ...], 'qc_status': str, 'notes': str}]
        """
        results = {
            'successful_signoffs': [],
            'failed_signoffs': [],
            'summary': {'total': 0, 'successful': 0, 'failed': 0}
        }
        
        for batch_item in qc_batch:
            allocation_ids = batch_item['allocation_ids']
            qc_status = batch_item.get('qc_status', 'passed')
            notes = batch_item.get('notes')
            
            try:
                signoff_results = self.quality_control_signoff(allocation_ids, employee_id, qc_status, notes)
                
                for result in signoff_results:
                    results['summary']['total'] += 1
                    if result.get('success', False):
                        results['successful_signoffs'].append(result)
                        results['summary']['successful'] += 1
                    else:
                        results['failed_signoffs'].append(result)
                        results['summary']['failed'] += 1
                        
            except Exception as e:
                for allocation_id in allocation_ids:
                    results['failed_signoffs'].append({
                        'allocation_id': allocation_id,
                        'success': False,
                        'message': f'QC signoff failed: {str(e)}'
                    })
                    results['summary']['total'] += 1
                    results['summary']['failed'] += 1
        
        return results
    
    def format_qc_item_for_frontend(self, qc_item: Dict[str, Any]) -> Dict[str, Any]:
        """
        Format QC item for frontend consumption.
        """
        return {
            'allocation_id': qc_item['allocation_id'],
            'interaction_id': qc_item['interaction_id'],
            'reference_number': qc_item['reference_number'],
            'customer_name': qc_item['customer_name'],
            'equipment': {
                'id': qc_item['equipment_id'],
                'asset_code': qc_item['asset_code'],
                'type_name': qc_item['type_name'],
                'model': qc_item['model'],
                'condition': qc_item['condition']
            },
            'allocated_info': {
                'allocated_at': qc_item['allocated_at'],
                'allocated_by_name': qc_item['allocated_by_name']
            },
            'delivery_date': qc_item['delivery_date'],
            'urgency': self.calculate_urgency(qc_item.get('delivery_date')),
            'qc_status': 'pending'
        }
    
    def calculate_urgency(self, delivery_date: date = None) -> str:
        """Calculate urgency level based on delivery date"""
        if not delivery_date:
            return 'normal'
        
        days_until_delivery = (delivery_date - date.today()).days
        
        if days_until_delivery < 0:
            return 'overdue'
        elif days_until_delivery == 0:
            return 'today'
        elif days_until_delivery == 1:
            return 'tomorrow'
        elif days_until_delivery <= 3:
            return 'urgent'
        elif days_until_delivery <= 7:
            return 'soon'
        else:
            return 'normal'
    
    def get_qc_checklist_template(self, equipment_type_id: int = None) -> Dict[str, Any]:
        """
        Get QC checklist template for equipment type.
        This would typically be configurable per equipment type.
        """
        # Basic template - in production this would come from database
        basic_checklist = [
            {'category': 'Visual Inspection', 'items': [
                'Check for visible damage',
                'Verify all parts present',
                'Check for leaks or cracks',
                'Inspect safety labels'
            ]},
            {'category': 'Functional Test', 'items': [
                'Engine starts properly',
                'All controls functional',
                'No unusual noises',
                'Performance within specification'
            ]},
            {'category': 'Safety Check', 'items': [
                'Safety features operational',
                'Emergency stop functional',
                'Guards and shields secure',
                'Warning devices working'
            ]},
            {'category': 'Maintenance Status', 'items': [
                'Service records up to date',
                'Fluid levels adequate',
                'Filters clean',
                'Next service date noted'
            ]}
        ]
        
        return {
            'equipment_type_id': equipment_type_id,
            'checklist': basic_checklist,
            'total_items': sum(len(category['items']) for category in basic_checklist),
            'qc_standards': {
                'pass_threshold': 90,  # Percentage of items that must pass
                'critical_items': ['Engine starts properly', 'Safety features operational', 'Emergency stop functional']
            }
        }
    
    def validate_qc_decision(self, qc_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate QC decision based on checklist results.
        """
        checklist_results = qc_data.get('checklist_results', {})
        total_items = qc_data.get('total_items', 0)
        critical_items = qc_data.get('critical_items', [])
        
        if not checklist_results or total_items == 0:
            return {'valid': False, 'message': 'Incomplete QC checklist'}
        
        # Check critical items
        failed_critical = []
        for item in critical_items:
            if not checklist_results.get(item, False):
                failed_critical.append(item)
        
        if failed_critical:
            return {
                'valid': False,
                'recommended_status': 'failed',
                'message': f'Critical items failed: {", ".join(failed_critical)}'
            }
        
        # Calculate pass rate
        passed_items = sum(1 for result in checklist_results.values() if result)
        pass_rate = (passed_items / total_items) * 100
        
        pass_threshold = qc_data.get('pass_threshold', 90)
        
        if pass_rate >= pass_threshold:
            return {
                'valid': True,
                'recommended_status': 'passed',
                'message': f'QC passed with {pass_rate:.1f}% success rate'
            }
        else:
            return {
                'valid': True,
                'recommended_status': 'failed',
                'message': f'QC failed with {pass_rate:.1f}% success rate (threshold: {pass_threshold}%)'
            }