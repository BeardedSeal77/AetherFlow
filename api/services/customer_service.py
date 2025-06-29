# api/services/customer_service.py
from typing import List, Dict, Any, Optional
from api.database.database_service import DatabaseService, handle_database_errors

class CustomerService:
    def __init__(self, db_service: DatabaseService):
        self.db = db_service
    
    @handle_database_errors
    def get_customers_for_selection(self, search_term: str = None, include_inactive: bool = False) -> List[Dict[str, Any]]:
        """Get customer list for hire interface selection"""
        return self.db.execute_procedure(
            'sp_get_customers_for_selection',
            [search_term, include_inactive]
        )
    
    @handle_database_errors
    def get_customer_contacts(self, customer_id: int) -> List[Dict[str, Any]]:
        """Get contacts for selected customer"""
        return self.db.execute_procedure(
            'sp_get_customer_contacts',
            [customer_id]
        )
    
    @handle_database_errors
    def get_customer_sites(self, customer_id: int) -> List[Dict[str, Any]]:
        """Get delivery sites for customer"""
        return self.db.execute_procedure(
            'sp_get_customer_sites',
            [customer_id]
        )
    
    @handle_database_errors
    def validate_customer_credit(self, customer_id: int, estimated_amount: float = 0) -> Dict[str, Any]:
        """Validate customer credit limit against estimated hire value"""
        result = self.db.execute_procedure(
            'sp_validate_customer_credit',
            [customer_id, estimated_amount]
        )
        return result[0] if result else {
            'is_valid': False,
            'message': 'Credit validation failed'
        }
    
    @handle_database_errors
    def get_customer_summary(self, customer_id: int) -> Dict[str, Any]:
        """Get customer summary with contacts and sites count"""
        # Get basic customer info
        customers = self.get_customers_for_selection()
        customer = next((c for c in customers if c['customer_id'] == customer_id), None)
        
        if not customer:
            return None
        
        # Get counts
        contacts = self.get_customer_contacts(customer_id)
        sites = self.get_customer_sites(customer_id)
        
        return {
            **customer,
            'contacts_count': len(contacts),
            'sites_count': len(sites),
            'primary_contact': next((c for c in contacts if c['is_primary_contact']), None),
            'billing_contact': next((c for c in contacts if c['is_billing_contact']), None)
        }