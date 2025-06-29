# api/services/driver_task_service.py
from typing import List, Dict, Any, Optional
from datetime import date, datetime
from api.database.database_service import DatabaseService, handle_database_errors

class DriverTaskService:
    def __init__(self, db_service: DatabaseService):
        self.db = db_service
    
    @handle_database_errors
    def get_driver_tasks(self, driver_id: int = None, status_filter: str = None, 
                        date_from: date = None, date_to: date = None) -> List[Dict[str, Any]]:
        """Get driver tasks for the drivers taskboard"""
        return self.db.execute_procedure(
            'sp_get_driver_tasks',
            [driver_id, status_filter, date_from, date_to]
        )
    
    @handle_database_errors
    def update_task_status(self, task_id: int, status_updates: Dict[str, Any]) -> Dict[str, Any]:
        """Update driver task status and progress indicators"""
        result = self.db.execute_procedure(
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
        return result[0] if result else {'success': False, 'message': 'Update failed'}
    
    @handle_database_errors
    def get_task_equipment(self, task_id: int) -> List[Dict[str, Any]]:
        """Get equipment and accessories list for a driver task"""
        return self.db.execute_procedure(
            'sp_get_driver_task_equipment',
            [task_id]
        )
    
    def get_driver_taskboard_data(self, filters: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Get comprehensive data for the drivers taskboard interface.
        Organizes tasks by status columns (Backlog, Driver 1-4).
        """
        if filters is None:
            filters = {}
        
        # Get all tasks
        tasks = self.get_driver_tasks(
            driver_id=filters.get('driver_id'),
            status_filter=filters.get('status_filter'),
            date_from=filters.get('date_from'),
            date_to=filters.get('date_to')
        )
        
        # Organize by status columns
        taskboard_data = {
            'columns': {
                'Backlog': [],
                'Driver 1': [],
                'Driver 2': [],
                'Driver 3': [],
                'Driver 4': []
            },
            'summary': {
                'total_tasks': len(tasks),
                'by_status': {},
                'by_priority': {},
                'equipment_allocation_status': {
                    'pending_allocation': 0,
                    'allocated_pending_qc': 0,
                    'ready_for_delivery': 0
                }
            }
        }
        
        # Process each task
        for task in tasks:
            # Format task for frontend
            formatted_task = self.format_task_for_frontend(task)
            
            # Add to appropriate column
            status = task['status']
            if status in taskboard_data['columns']:
                taskboard_data['columns'][status].append(formatted_task)
            
            # Update summary counters
            if status not in taskboard_data['summary']['by_status']:
                taskboard_data['summary']['by_status'][status] = 0
            taskboard_data['summary']['by_status'][status] += 1
            
            priority = task['priority']
            if priority not in taskboard_data['summary']['by_priority']:
                taskboard_data['summary']['by_priority'][priority] = 0
            taskboard_data['summary']['by_priority'][priority] += 1
            
            # Equipment allocation status
            if not task['equipment_allocated']:
                taskboard_data['summary']['equipment_allocation_status']['pending_allocation'] += 1
            elif not task['equipment_verified']:
                taskboard_data['summary']['equipment_allocation_status']['allocated_pending_qc'] += 1
            else:
                taskboard_data['summary']['equipment_allocation_status']['ready_for_delivery'] += 1
        
        return taskboard_data
    
    def format_task_for_frontend(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Format driver task data for frontend consumption.
        Matches the DriverTask interface in the frontend.
        """
        # Calculate progress (0-4 based on Yes responses)
        progress_items = [
            task.get('status_booked', 'no'),
            task.get('status_driver', 'no'),
            task.get('status_quality_control', 'no'),
            task.get('status_whatsapp', 'no')
        ]
        progress = sum(1 for item in progress_items if item == 'yes')
        
        # Extract equipment list from summary
        equipment_summary = task.get('equipment_summary', '')
        equipment_list = []
        if equipment_summary:
            # Parse equipment summary like "RAMMER-4S (2), PLATE-SM (1)"
            items = equipment_summary.split(', ')
            for item in items:
                if '(' in item and ')' in item:
                    name = item.split('(')[0].strip()
                    equipment_list.append(name)
        
        return {
            'id': str(task['task_id']),
            'status': task['status'],
            'type': task['task_type'].title(),
            'equipment': equipment_list,
            'customer': task['customer_name'],
            'company': task['customer_name'],  # Using customer_name for company
            'address': task['site_address'] or '',
            'booked': task.get('status_booked', 'no').title(),
            'driver': task.get('status_driver', 'no').title(),
            'qualityControl': task.get('status_quality_control', 'no').title(),
            'whatsapp': task.get('status_whatsapp', 'no').title(),
            'priority': task['priority'],
            'scheduled_date': task.get('scheduled_date'),
            'scheduled_time': task.get('scheduled_time'),
            'contact_name': task.get('contact_name'),
            'contact_phone': task.get('contact_phone'),
            'contact_whatsapp': task.get('contact_whatsapp'),
            'equipment_allocated': task.get('equipment_allocated', False),
            'equipment_verified': task.get('equipment_verified', False),
            'reference_number': task.get('reference_number'),
            'interaction_id': task['interaction_id'],
            'progress': progress
        }
    
    def update_task_from_frontend(self, task_id: int, frontend_task: Dict[str, Any], employee_id: int = None) -> Dict[str, Any]:
        """
        Update task from frontend DriverTask format.
        Converts frontend data to database format.
        """
        # Convert frontend format to database format
        status_updates = {
            'status': frontend_task.get('status'),
            'status_booked': frontend_task.get('booked', '').lower() if frontend_task.get('booked') else None,
            'status_driver': frontend_task.get('driver', '').lower() if frontend_task.get('driver') else None,
            'status_quality_control': frontend_task.get('qualityControl', '').lower() if frontend_task.get('qualityControl') else None,
            'status_whatsapp': frontend_task.get('whatsapp', '').lower() if frontend_task.get('whatsapp') else None,
            'assigned_to': employee_id,
            'completion_notes': frontend_task.get('completion_notes')
        }
        
        # Remove None values
        status_updates = {k: v for k, v in status_updates.items() if v is not None}
        
        return self.update_task_status(task_id, status_updates)
    
    def move_task_to_status(self, task_id: int, new_status: str, employee_id: int = None) -> Dict[str, Any]:
        """
        Move task to a new status column (used for drag & drop).
        """
        # Map status to driver assignment if moving to driver column
        status_updates = {'status': new_status}
        
        if new_status.startswith('driver_') or new_status.startswith('Driver '):
            # Assign driver automatically when moved to driver column
            if employee_id:
                status_updates['assigned_to'] = employee_id
                status_updates['status_driver'] = 'yes'
        elif new_status == 'backlog':
            # Unassign when moved back to backlog
            status_updates['assigned_to'] = None
            status_updates['status_driver'] = 'no'
        
        return self.update_task_status(task_id, status_updates)
    
    def get_task_details_with_equipment(self, task_id: int) -> Dict[str, Any]:
        """
        Get complete task details including equipment list for detailed view/modal.
        """
        # Get basic task info
        tasks = self.get_driver_tasks()
        task = next((t for t in tasks if t['task_id'] == task_id), None)
        
        if not task:
            return None
        
        # Get equipment details
        equipment_details = self.get_task_equipment(task_id)
        
        # Format for frontend
        formatted_task = self.format_task_for_frontend(task)
        formatted_task['equipment_details'] = equipment_details
        
        return formatted_task
    
    def validate_task_status_transition(self, task_id: int, new_status: str) -> Dict[str, Any]:
        """
        Validate if a task status transition is allowed.
        Business rules for task workflow.
        """
        # Get current task
        tasks = self.get_driver_tasks()
        task = next((t for t in tasks if t['task_id'] == task_id), None)
        
        if not task:
            return {'valid': False, 'message': 'Task not found'}
        
        current_status = task['status']
        
        # Define allowed transitions
        allowed_transitions = {
            'backlog': ['driver_1', 'driver_2', 'driver_3', 'driver_4'],
            'driver_1': ['backlog', 'driver_2', 'driver_3', 'driver_4', 'completed'],
            'driver_2': ['backlog', 'driver_1', 'driver_3', 'driver_4', 'completed'],
            'driver_3': ['backlog', 'driver_1', 'driver_2', 'driver_4', 'completed'],
            'driver_4': ['backlog', 'driver_1', 'driver_2', 'driver_3', 'completed'],
            'completed': []  # Cannot move from completed
        }
        
        # Normalize status names
        current_status = current_status.lower().replace(' ', '_')
        new_status = new_status.lower().replace(' ', '_')
        
        if current_status not in allowed_transitions:
            return {'valid': False, 'message': f'Unknown current status: {current_status}'}
        
        if new_status not in allowed_transitions.get(current_status, []):
            return {'valid': False, 'message': f'Cannot move from {current_status} to {new_status}'}
        
        # Additional business rule: Check if equipment is allocated when moving to driver
        if new_status.startswith('driver_') and not task.get('equipment_allocated', False):
            return {
                'valid': False, 
                'message': 'Equipment must be allocated before assigning to driver',
                'warning': True
            }
        
        return {'valid': True, 'message': 'Transition allowed'}