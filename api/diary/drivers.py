import os
import json
import uuid
from datetime import date
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATA_FOLDER = os.path.join("public", "data")

def get_today_filename():
    """Get filename for today's driver tasks."""
    today_str = date.today().isoformat()  # e.g., 2025-04-14
    return f"drivers-{today_str}.json"

def get_driver_tasks():
    """Get driver tasks for today."""
    try:
        # Ensure data folder exists
        if not os.path.exists(DATA_FOLDER):
            logger.info(f"Creating data folder: {DATA_FOLDER}")
            os.makedirs(DATA_FOLDER)

        filename = get_today_filename()
        filepath = os.path.join(DATA_FOLDER, filename)
        logger.info(f"Accessing driver tasks at: {filepath}")

        if not os.path.isfile(filepath):
            # If the file doesn't exist, create it with sample tasks for testing
            logger.info(f"File not found, creating sample data at: {filepath}")
            sample_tasks = {
                "tasks": [
                    {
                        "id": "task-1",
                        "status": "Backlog",
                        "type": "Deliver",
                        "equipment": ["Rammer", "TE1000", "Poker"],
                        "customer": "John Smith",
                        "company": "Smith Construction",
                        "address": "1 Tree Road, London",
                        "booked": "Yes",
                        "driver": "No",
                        "qualityControl": "No",
                        "whatsapp": "No"
                    },
                    {
                        "id": "task-2",
                        "status": "Backlog",
                        "type": "Collect",
                        "equipment": ["Breaker", "Excavator", "Drill"],
                        "customer": "Sarah Johnson",
                        "company": "Johnson Builders",
                        "address": "42 Maple Street, Manchester",
                        "booked": "Yes",
                        "driver": "Yes",
                        "qualityControl": "No",
                        "whatsapp": "No"
                    },
                    {
                        "id": "task-3",
                        "status": "Backlog",
                        "type": "Swap",
                        "equipment": ["Generator", "Mixer"],
                        "customer": "Robert Williams",
                        "company": "Williams Constructions",
                        "address": "7 Oak Avenue, Birmingham",
                        "booked": "Yes",
                        "driver": "Yes",
                        "qualityControl": "Yes",
                        "whatsapp": "No"
                    },
                    {
                        "id": "task-4",
                        "status": "Backlog",
                        "type": "Deliver",
                        "equipment": ["Hammer", "Drill", "Saw"],
                        "customer": "Emily Davis",
                        "company": "Davis & Sons",
                        "address": "15 Pine Road, Leeds",
                        "booked": "Yes",
                        "driver": "Yes",
                        "qualityControl": "Yes",
                        "whatsapp": "Yes"
                    },
                    {
                        "id": "task-5",
                        "status": "Driver 1",
                        "type": "Deliver",
                        "equipment": ["Loader", "Compactor"],
                        "customer": "James Wilson",
                        "company": "Wilson & Co",
                        "address": "23 Cedar Lane, Glasgow",
                        "booked": "Yes",
                        "driver": "No",
                        "qualityControl": "No",
                        "whatsapp": "No"
                    },
                    {
                        "id": "task-6",
                        "status": "Driver 2",
                        "type": "Collect",
                        "equipment": ["Jackhammer", "Scaffold"],
                        "customer": "David Thompson",
                        "company": "Thompson Building",
                        "address": "9 Birch Street, Liverpool",
                        "booked": "Yes",
                        "driver": "Yes",
                        "qualityControl": "No",
                        "whatsapp": "No"
                    },
                    {
                        "id": "task-7",
                        "status": "Driver 3",
                        "type": "Swap",
                        "equipment": ["Excavator", "Crane"],
                        "customer": "Michael Brown",
                        "company": "Brown Construction",
                        "address": "31 Elm Road, Edinburgh",
                        "booked": "Yes",
                        "driver": "Yes",
                        "qualityControl": "Yes",
                        "whatsapp": "No"
                    },
                    {
                        "id": "task-8",
                        "status": "Driver 4",
                        "type": "Deliver",
                        "equipment": ["Bulldozer", "Forklift"],
                        "customer": "Andrew Miller",
                        "company": "Miller Builders",
                        "address": "12 Willow Lane, Bristol",
                        "booked": "Yes",
                        "driver": "Yes",
                        "qualityControl": "Yes",
                        "whatsapp": "Yes"
                    }
                ]
            }
            
            with open(filepath, "w") as f:
                json.dump(sample_tasks, f, indent=2)
                logger.info("Sample tasks written successfully")

        # Read the data file
        logger.info(f"Reading tasks from: {filepath}")
        with open(filepath, "r") as f:
            content = f.read()
            
        # Validate JSON before parsing
        if not content or content.strip() == '':
            logger.warning("Empty file found, returning empty task list")
            return []
            
        try:
            data = json.loads(content)
            logger.info("Successfully parsed JSON data")
        except json.JSONDecodeError as e:
            logger.error(f"JSON parsing error: {str(e)}, first 100 chars: {content[:100]}")
            # Return empty list instead of propagating the error
            return []
        
        tasks = data.get("tasks", [])
        
        # Ensure each task has the required fields and proper formatting
        for task in tasks:
            # Ensure task has an ID
            if 'id' not in task:
                task_id = str(uuid.uuid4())
                logger.info(f"Adding missing ID to task: {task_id}")
                task['id'] = task_id
                
            # Ensure equipment is a list
            if 'equipment' in task and not isinstance(task['equipment'], list):
                if isinstance(task['equipment'], str):
                    # Convert comma-separated string to list
                    task['equipment'] = [item.strip() for item in task['equipment'].split(',')]
                else:
                    # If it's neither a list nor a string, initialize as empty list
                    task['equipment'] = []
            elif 'equipment' not in task:
                task['equipment'] = []
                
            # Ensure status fields are set
            for status_field in ['booked', 'driver', 'qualityControl', 'whatsapp']:
                if status_field not in task:
                    task[status_field] = 'No'
                    
            # Ensure type is one of the allowed values
            if 'type' not in task or task['type'] not in ['Deliver', 'Collect', 'Swap']:
                task['type'] = 'Deliver'  # Default to 'Deliver'
                
            # Ensure other required fields are present
            for field in ['customer', 'company', 'address']:
                if field not in task:
                    task[field] = f"Unspecified {field.capitalize()}"
                
        logger.info(f"Returning {len(tasks)} tasks")
        return tasks
        
    except Exception as e:
        logger.error(f"Unexpected error in get_driver_tasks: {str(e)}")
        # Return empty list instead of propagating the error
        return []

def update_driver_task(task_id, updated_task):
    """Update a specific driver task."""
    try:
        tasks = get_driver_tasks()
        task_found = False
        
        # Find and update the task
        for i, task in enumerate(tasks):
            if task["id"] == task_id:
                # Validate updated task fields
                if 'equipment' in updated_task and not isinstance(updated_task['equipment'], list):
                    if isinstance(updated_task['equipment'], str):
                        # Convert comma-separated string to list
                        updated_task['equipment'] = [item.strip() for item in updated_task['equipment'].split(',')]
                    else:
                        # If it's neither a list nor a string, use existing equipment or empty list
                        updated_task['equipment'] = task.get('equipment', [])
                
                # Ensure status fields are valid
                for status_field in ['booked', 'driver', 'qualityControl', 'whatsapp']:
                    if status_field in updated_task and updated_task[status_field] not in ['Yes', 'No']:
                        updated_task[status_field] = 'No'
                
                # Ensure type is valid
                if 'type' in updated_task and updated_task['type'] not in ['Deliver', 'Collect', 'Swap']:
                    updated_task['type'] = task.get('type', 'Deliver')
                
                # Update the task
                tasks[i] = updated_task
                task_found = True
                break
        
        if not task_found:
            logger.error(f"Task {task_id} not found")
            return {"success": False, "error": f"Task {task_id} not found"}
        
        # Save the updated tasks
        filename = get_today_filename()
        filepath = os.path.join(DATA_FOLDER, filename)
        
        with open(filepath, "w") as f:
            json.dump({"tasks": tasks}, f, indent=2)
            
        logger.info(f"Successfully updated task {task_id}")
        return {"success": True, "task": updated_task}
        
    except Exception as e:
        logger.error(f"Error updating task {task_id}: {str(e)}")
        return {"success": False, "error": str(e)}