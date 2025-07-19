"""
Hire management routes for the Equipment Hire System
Handles hire creation, viewing, and management using HireManager class
"""

from flask import Blueprint, request, jsonify, session
from .hire_manager import HireManager
import json
import logging

logger = logging.getLogger(__name__)

hire_bp = Blueprint('hire', __name__)
hire_manager = HireManager()

@hire_bp.route('/create', methods=['POST'])
def create_hire():
    """Create a new hire interaction using HireManager."""
    try:
        data = request.get_json()
        employee_id = session.get('employee_id', 1)  # Default employee for demo
        
        logger.info(f"Creating hire for customer {data.get('customer_id')}")
        
        # Create the hire using HireManager
        result = hire_manager.create_hire(data, employee_id)
        
        if result.get('success'):
            return jsonify(result)
        else:
            return jsonify(result), 400
        
    except Exception as e:
        logger.error(f"Error creating hire: {str(e)}")
        return jsonify({
            'success': False,
            'error_message': str(e)
        }), 500

@hire_bp.route('/<int:hire_id>', methods=['GET'])
def get_hire(hire_id):
    """Get hire details by ID using HireManager."""
    try:
        hire_details = hire_manager.get_hire_details(hire_id)
        
        if 'error' in hire_details:
            return jsonify({
                'success': False,
                'error': hire_details['error']
            }), 404
        
        return jsonify({
            'success': True,
            'hire': hire_details
        })
        
    except Exception as e:
        logger.error(f"Error fetching hire {hire_id}: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch hire details'
        }), 500

@hire_bp.route('/validate', methods=['POST'])
def validate_hire():
    """Validate hire request before creation."""
    try:
        data = request.get_json()
        validation_result = hire_manager.validate_hire_request(data)
        return jsonify(validation_result)
        
    except Exception as e:
        logger.error(f"Error validating hire: {str(e)}")
        return jsonify({
            'is_valid': False,
            'error_message': str(e)
        }), 500

@hire_bp.route('/list', methods=['GET'])
def list_hires():
    """Get list of all hires."""
    try:
        filters = request.args.to_dict()
        hires = hire_manager.get_all_hires(filters)
        return jsonify({
            'success': True,
            'hires': hires
        })
        
    except Exception as e:
        logger.error(f"Error fetching hires: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Failed to fetch hires'
        }), 500

# View and allocation endpoints
@hire_bp.route('/today', methods=['GET'])
def get_todays_hires():
    """Get all hires for today."""
    try:
        date = request.args.get('date')
        hires = hire_manager.get_todays_hires(date)
        return jsonify(hires)
    except Exception as e:
        logger.error(f"Error getting today's hires: {str(e)}")
        return jsonify({'error': 'Failed to load hires'}), 500

@hire_bp.route('/pending-allocations', methods=['GET'])
def get_pending_allocations():
    """Get hires that need equipment allocation."""
    try:
        pending = hire_manager.get_pending_allocations()
        return jsonify(pending)
    except Exception as e:
        logger.error(f"Error getting pending allocations: {str(e)}")
        return jsonify({'error': 'Failed to load pending allocations'}), 500

@hire_bp.route('/equipment/<int:equipment_type_id>/available', methods=['GET'])
def get_available_equipment(equipment_type_id):
    """Get available equipment for allocation."""
    try:
        equipment = hire_manager.get_available_equipment(equipment_type_id)
        return jsonify(equipment)
    except Exception as e:
        logger.error(f"Error getting available equipment: {str(e)}")
        return jsonify({'error': 'Failed to load equipment'}), 500

@hire_bp.route('/allocate-equipment', methods=['POST'])
def allocate_equipment():
    """Allocate specific equipment to a hire."""
    try:
        data = request.json
        result = hire_manager.allocate_equipment(data)
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error allocating equipment: {str(e)}")
        return jsonify({'success': False, 'error': 'Failed to allocate equipment'}), 500

@hire_bp.route('/remove-equipment', methods=['POST'])
def remove_equipment():
    """Remove equipment from a hire."""
    try:
        data = request.json
        result = hire_manager.remove_equipment(data)
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error removing equipment: {str(e)}")
        return jsonify({'success': False, 'error': 'Failed to remove equipment'}), 500