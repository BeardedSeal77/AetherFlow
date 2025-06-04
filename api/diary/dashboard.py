import json
import os
import uuid
import logging
import glob

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def load_tasks(username):
    """Load tasks for a specific user."""
    try:
        # Log the username and current directory for debugging
        logger.info(f"Loading tasks for user: {username}")
        logger.info(f"Current working directory: {os.getcwd()}")
        
        # Define various possible paths to find the user file
        base_paths = [
            "public/data",
            "./public/data",
            "../public/data",
            os.path.join(os.getcwd(), "public", "data"),
            os.path.join(os.path.dirname(os.getcwd()), "public", "data")
        ]
        
        # First try the expected path with the username
        for base_path in base_paths:
            user_file = os.path.join(base_path, f"{username}.json")
            logger.info(f"Trying path: {user_file}")
            
            if os.path.exists(user_file):
                logger.info(f"Found user file at: {user_file}")
                with open(user_file, "r") as file:
                    data = json.load(file)
                    tasks = data.get("tasks", [])
                    
                    # Ensure each task has an ID
                    for task in tasks:
                        if 'id' not in task:
                            task['id'] = str(uuid.uuid4())
                    
                    logger.info(f"Loaded {len(tasks)} tasks for user {username}")
                    return tasks
        
        # If not found, search for any matching files
        for base_path in base_paths:
            if os.path.exists(base_path):
                logger.info(f"Searching for JSON files in: {base_path}")
                json_files = glob.glob(os.path.join(base_path, "*.json"))
                logger.info(f"Found JSON files: {json_files}")
                
                # If we found any user1.json file, let's try it
                for file_path in json_files:
                    if os.path.basename(file_path) == f"{username}.json":
                        logger.info(f"Loading from found file: {file_path}")
                        with open(file_path, "r") as file:
                            data = json.load(file)
                            tasks = data.get("tasks", [])
                            
                            # Ensure each task has an ID
                            for task in tasks:
                                if 'id' not in task:
                                    task['id'] = str(uuid.uuid4())
                            
                            logger.info(f"Loaded {len(tasks)} tasks for user {username}")
                            return tasks
        
        # Return helpful debug info if file doesn't exist
        logger.warning(f"No task file found for user {username}, returning debug data")
        return [
            {
                "id": "debug-1",
                "title": f"Debug task - No user file found for '{username}'",
                "status": "Backlog"
            },
            {
                "id": "debug-2",
                "title": "Check Flask console for file path details",
                "status": "In Progress"
            }
        ]
        
    except Exception as e:
        logger.error(f"Error loading tasks for user {username}: {str(e)}")
        # Return error info in tasks
        return [
            {
                "id": "error-1",
                "title": f"Error loading tasks: {str(e)}",
                "status": "Backlog"
            }
        ]