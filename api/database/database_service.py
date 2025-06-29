# api/database/database_service.py
import psycopg2
from psycopg2.extras import RealDictCursor
import json
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, date

logger = logging.getLogger(__name__)

class DatabaseError(Exception):
    """Custom exception for database errors"""
    def __init__(self, message, procedure_name=None, original_error=None):
        self.message = message
        self.procedure_name = procedure_name
        self.original_error = original_error
        super().__init__(self.message)

class DatabaseService:
    def __init__(self, connection_string: str):
        self.connection_string = connection_string
    
    def execute_procedure(self, procedure_name: str, params: List = None) -> List[Dict[str, Any]]:
        """Execute a stored procedure and return results"""
        try:
            with psycopg2.connect(self.connection_string) as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                    if params:
                        cursor.callproc(procedure_name, params)
                    else:
                        cursor.callproc(procedure_name)
                    
                    try:
                        results = cursor.fetchall()
                        return [dict(row) for row in results]
                    except psycopg2.ProgrammingError:
                        # No results to fetch (INSERT/UPDATE procedures)
                        return []
        except psycopg2.Error as e:
            logger.error(f"Database error in {procedure_name}: {str(e)}")
            raise DatabaseError(
                message=f"Database error: {str(e)}",
                procedure_name=procedure_name,
                original_error=e
            )
        except Exception as e:
            logger.error(f"Unexpected error in {procedure_name}: {str(e)}")
            raise DatabaseError(
                message=f"Unexpected error: {str(e)}",
                procedure_name=procedure_name,
                original_error=e
            )
    
    def execute_query(self, query: str, params: List = None) -> List[Dict[str, Any]]:
        """Execute a direct SQL query"""
        try:
            with psycopg2.connect(self.connection_string) as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                    cursor.execute(query, params)
                    try:
                        results = cursor.fetchall()
                        return [dict(row) for row in results]
                    except psycopg2.ProgrammingError:
                        return []
        except psycopg2.Error as e:
            logger.error(f"Database error in query: {str(e)}")
            raise DatabaseError(
                message=f"Database error: {str(e)}",
                original_error=e
            )

def handle_database_errors(func):
    """Decorator for consistent database error handling"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except DatabaseError:
            # Re-raise database errors as-is
            raise
        except Exception as e:
            logger.error(f"Unexpected error in {func.__name__}: {str(e)}")
            raise DatabaseError(
                message=f"Unexpected error in {func.__name__}: {str(e)}",
                procedure_name=func.__name__,
                original_error=e
            )
    return wrapper