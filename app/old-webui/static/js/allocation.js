/**
 * Equipment Allocation Dashboard JavaScript
 * Handles equipment allocation functionality
 */

class AllocationDashboard {
    constructor() {
        this.currentBooking = null;
        this.selectedEquipment = [];
        this.qcItems = [];
        
        this.bindEvents();
        this.loadQCItems();
        this.initializeFilters();
    }
    
    bindEvents() {
        // Allocation buttons
        $(document).on('click', '.allocate-btn', (e) => {
            const bookingId = $(e.target).data('booking-id');
            this.startAllocation(bookingId);
        });
        
        // Filter controls
        $('#priorityFilter, #statusFilter').on('change', () => this.applyFilters());
        $('#searchBtn').on('click', () => this.applyFilters());
        $('#customerSearch').on('keypress', (e) => {
            if (e.which === 13) this.applyFilters();
        });
        
        // Refresh button
        $('#refreshBtn').on('click', () => this.refreshData());
        
        // Allocation panel actions
        $('#confirmAllocationBtn').on('click', () => this.confirmAllocation());
        $('#cancelAllocationBtn').on('click', () => this.cancelAllocation());
        
        // Modal actions
        $('#modalConfirmBtn').on('click', () => this.confirmModalAllocation());
        
        // QC actions
        $('#qcConfirmBtn').on('click', () => this.confirmQCDecision());
        
        // Equipment selection in modals
        $(document).on('click', '.equipment-unit', (e) => this.toggleEquipmentSelection(e));
        
        // Equipment selection in panel
        $(document).on('click', '#availableEquipment .equipment-unit', (e) => this.toggleEquipmentSelection(e));
        
        // QC item clicks
        $(document).on('click', '.qc-item', (e) => this.openQCModal(e));
    }
    
    async startAllocation(bookingId) {
        try {
            // Find the booking data
            const bookingCard = $(`.allocation-card[data-booking-id="${bookingId}"]`);
            if (!bookingCard.length) return;
            
            this.currentBooking = {
                booking_id: parseInt(bookingId),
                equipment_type_id: parseInt(bookingCard.data('equipment-type-id')),
                customer_name: bookingCard.data('customer-name'),
                hire_start_date: bookingCard.data('hire-start'),
                hire_end_date: bookingCard.data('hire-end'),
                reference_number: bookingCard.find('h6 strong').text(),
                type_name: bookingCard.find('p:first').text().replace(/.*\s/, '').replace(/\s*\(.*\)/, ''),
                quantity_remaining: parseInt(bookingCard.find('.badge').text().split(' ')[0])
            };
            
            // Load available equipment
            await this.loadAvailableEquipment();
            
            // Show allocation panel
            this.showAllocationPanel();
            
        } catch (error) {
            console.error('Error starting allocation:', error);
            showAlert('Error loading allocation data', 'danger');
        }
    }
    
    async loadAvailableEquipment() {
        try {
            const params = {
                hire_start_date: this.currentBooking.hire_start_date,
                hire_end_date: this.currentBooking.hire_end_date
            };
            
            const equipment = await this.apiCall(
                `/api/allocation/equipment/${this.currentBooking.equipment_type_id}`,
                { params }
            );
            
            this.displayAvailableEquipment(equipment);
            
        } catch (error) {
            console.error('Error loading available equipment:', error);
            showAlert('Error loading available equipment', 'danger');
        }
    }
    
    displayAvailableEquipment(equipment) {
        const container = $('#availableEquipment');
        
        if (!equipment || equipment.length === 0) {
            container.html(`
                <div class="text-center py-4 text-muted">
                    <i class="fas fa-exclamation-triangle fa-3x mb-3"></i>
                    <p>No equipment available for allocation</p>
                </div>
            `);
            return;
        }
        
        const html = equipment.map(item => {
            const overdueClass = item.is_overdue_service ? 'overdue-service' : '';
            const conditionClass = `condition-${item.condition}`;
            
            return `
                <div class="equipment-unit ${overdueClass}" 
                     data-equipment-id="${item.equipment_id}"
                     data-asset-code="${item.asset_code}"
                     data-model="${item.model}"
                     data-condition="${item.condition}">
                    <div class="d-flex justify-content-between align-items-start">
                        <div class="flex-grow-1">
                            <h6 class="mb-1">
                                <i class="fas fa-cog me-2"></i>
                                ${item.asset_code}
                            </h6>
                            <p class="text-muted mb-1 small">${item.model || 'No model specified'}</p>
                            <div class="d-flex gap-1 flex-wrap">
                                <span class="badge condition-badge ${conditionClass}">${item.condition}</span>
                                ${item.is_overdue_service ? '<span class="badge bg-danger">Service Overdue</span>' : ''}
                                ${item.location ? `<span class="badge bg-light text-dark">${item.location}</span>` : ''}
                            </div>
                            ${item.last_service_date ? `<small class="text-muted d-block mt-1">Last Service: ${formatDate(item.last_service_date)}</small>` : ''}
                        </div>
                        <div class="ms-2">
                            <i class="fas fa-hand-pointer text-muted"></i>
                        </div>
                    </div>
                </div>
            `;
        }).join('');
        
        container.html(html);
    }
    
    showAllocationPanel() {
        // Update booking info
        $('#bookingInfo').html(`
            <h6>${this.currentBooking.reference_number}</h6>
            <p class="mb-1"><strong>Customer:</strong> ${this.currentBooking.customer_name}</p>
            <p class="mb-1"><strong>Equipment:</strong> ${this.currentBooking.type_name}</p>
            <p class="mb-1"><strong>Quantity Remaining:</strong> ${this.currentBooking.quantity_remaining}</p>
            <p class="mb-0"><strong>Period:</strong> ${formatDate(this.currentBooking.hire_start_date)} 
                ${this.currentBooking.hire_end_date ? '- ' + formatDate(this.currentBooking.hire_end_date) : ''}</p>
        `);
        
        // Reset selection
        this.selectedEquipment = [];
        this.updateSelectedEquipmentDisplay();
        
        // Show panel
        $('#allocationPanel').show();
        
        // Scroll to panel
        $('#allocationPanel')[0].scrollIntoView({ behavior: 'smooth' });
    }
    
    toggleEquipmentSelection(event) {
        const unit = $(event.currentTarget);
        const equipmentId = parseInt(unit.data('equipment-id'));
        
        // Check if already selected
        const selectedIndex = this.selectedEquipment.findIndex(item => item.equipment_id === equipmentId);
        
        if (selectedIndex >= 0) {
            // Deselect
            this.selectedEquipment.splice(selectedIndex, 1);
            unit.removeClass('selected');
        } else {
            // Check if we can select more
            if (this.selectedEquipment.length >= this.currentBooking.quantity_remaining) {
                showAlert(`Cannot select more than ${this.currentBooking.quantity_remaining} units`, 'warning');
                return;
            }
            
            // Select
            this.selectedEquipment.push({
                equipment_id: equipmentId,
                asset_code: unit.data('asset-code'),
                model: unit.data('model'),
                condition: unit.data('condition')
            });
            unit.addClass('selected');
        }
        
        this.updateSelectedEquipmentDisplay();
    }
    
    updateSelectedEquipmentDisplay() {
        const container = $('#selectedEquipment');
        const countBadge = $('#selectedCount');
        
        countBadge.text(this.selectedEquipment.length);
        
        if (this.selectedEquipment.length === 0) {
            container.html(`
                <div class="text-center text-muted">
                    <i class="fas fa-hand-pointer me-1"></i>
                    Select equipment units above
                </div>
            `);
            $('#confirmAllocationBtn').prop('disabled', true);
            return;
        }
        
        const html = this.selectedEquipment.map(item => `
            <div class="d-flex justify-content-between align-items-center mb-2 p-2 border rounded">
                <div>
                    <strong>${item.asset_code}</strong><br>
                    <small class="text-muted">${item.model || 'No model'}</small><br>
                    <span class="badge condition-${item.condition}">${item.condition}</span>
                </div>
                <button type="button" class="btn btn-sm btn-outline-danger" 
                        onclick="allocationDashboard.deselectEquipment(${item.equipment_id})">
                    <i class="fas fa-times"></i>
                </button>
            </div>
        `).join('');
        
        container.html(html);
        $('#confirmAllocationBtn').prop('disabled', false);
    }
    
    deselectEquipment(equipmentId) {
        // Remove from selection
        this.selectedEquipment = this.selectedEquipment.filter(item => item.equipment_id !== equipmentId);
        
        // Update UI
        $(`.equipment-unit[data-equipment-id="${equipmentId}"]`).removeClass('selected');
        this.updateSelectedEquipmentDisplay();
    }
    
    async confirmAllocation() {
        if (this.selectedEquipment.length === 0) {
            showAlert('Please select equipment to allocate', 'warning');
            return;
        }
        
        try {
            setLoading($('#confirmAllocationBtn')[0]);
            
            const equipmentIds = this.selectedEquipment.map(item => item.equipment_id);
            const notes = $('#allocationNotes').val();
            
            const result = await this.apiCall('/api/allocation/allocate', {
                method: 'POST',
                body: JSON.stringify({
                    booking_id: this.currentBooking.booking_id,
                    equipment_ids: equipmentIds,
                    notes: notes
                })
            });
            
            if (result.success) {
                showAlert(`Successfully allocated ${result.allocated_count} equipment units`, 'success');
                
                // Refresh the bookings list
                await this.refreshData();
                
                // Hide allocation panel
                this.cancelAllocation();
                
                // Refresh QC items
                await this.loadQCItems();
                
            } else {
                showAlert(`Allocation failed: ${result.error_message}`, 'danger');
            }
            
        } catch (error) {
            console.error('Error confirming allocation:', error);
            showAlert('Error confirming allocation', 'danger');
        } finally {
            setLoading($('#confirmAllocationBtn')[0], false);
        }
    }
    
    cancelAllocation() {
        this.currentBooking = null;
        this.selectedEquipment = [];
        $('#allocationPanel').hide();
        $('.equipment-unit').removeClass('selected');
        $('#allocationNotes').val('');
    }
    
    async loadQCItems() {
        try {
            const qcItems = await this.apiCall('/api/qc/pending');
            this.displayQCItems(qcItems);
        } catch (error) {
            console.error('Error loading QC items:', error);
            $('#qcEquipment').html(`
                <div class="text-center text-danger">
                    <i class="fas fa-exclamation-triangle fa-2x mb-2"></i>
                    <p>Error loading QC items</p>
                </div>
            `);
        }
    }
    
    displayQCItems(qcItems) {
        const container = $('#qcEquipment');
        
        if (!qcItems || qcItems.length === 0) {
            container.html(`
                <div class="text-center text-muted">
                    <i class="fas fa-check-circle fa-2x mb-2"></i>
                    <p>No equipment pending QC</p>
                </div>
            `);
            return;
        }
        
        this.qcItems = qcItems;
        
        const html = qcItems.map(item => `
            <div class="qc-item border rounded p-2 mb-2 cursor-pointer" 
                 data-allocation-id="${item.allocation_id}"
                 data-equipment-id="${item.equipment_id}">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">${item.asset_code}</h6>
                        <p class="text-muted mb-1 small">${item.type_name}</p>
                        <p class="text-muted mb-0 small">${item.customer_name}</p>
                    </div>
                    <div class="text-end">
                        <span class="badge condition-${item.condition}">${item.condition}</span>
                        <br><small class="text-muted">${formatDate(item.delivery_date)}</small>
                    </div>
                </div>
            </div>
        `).join('');
        
        container.html(html);
    }
    
    openQCModal(event) {
        const qcItem = $(event.currentTarget);
        const allocationId = parseInt(qcItem.data('allocation-id'));
        
        // Find the QC item data
        const itemData = this.qcItems.find(item => item.allocation_id === allocationId);
        if (!itemData) return;
        
        // Populate modal
        $('#qcEquipmentInfo').html(`
            <div class="d-flex justify-content-between align-items-start">
                <div>
                    <h6 class="mb-1">${itemData.asset_code} - ${itemData.type_name}</h6>
                    <p class="mb-1"><strong>Customer:</strong> ${itemData.customer_name}</p>
                    <p class="mb-1"><strong>Reference:</strong> ${itemData.reference_number}</p>
                    <p class="mb-0"><strong>Delivery Date:</strong> ${formatDate(itemData.delivery_date)}</p>
                </div>
                <span class="badge condition-${itemData.condition}">${itemData.condition}</span>
            </div>
        `);
        
        // Store allocation ID for confirmation
        $('#qcModal').data('allocation-id', allocationId);
        
        // Reset form
        $('#qcNotes').val('');
        $('#qcApprove').prop('checked', true);
        
        // Show modal
        const modal = new bootstrap.Modal(document.getElementById('qcModal'));
        modal.show();
    }
    
    async confirmQCDecision() {
        const allocationId = $('#qcModal').data('allocation-id');
        const approved = $('input[name="qcDecision"]:checked').val() === 'true';
        const notes = $('#qcNotes').val();
        
        if (!notes.trim()) {
            showAlert('Please provide QC notes', 'warning');
            return;
        }
        
        try {
            setLoading($('#qcConfirmBtn')[0]);
            
            const result = await this.apiCall('/api/qc/signoff', {
                method: 'POST',
                body: JSON.stringify({
                    allocation_id: allocationId,
                    approved: approved,
                    qc_notes: notes
                })
            });
            
            if (result.success) {
                showAlert(`QC ${approved ? 'approved' : 'rejected'} successfully`, 'success');
                
                // Close modal
                bootstrap.Modal.getInstance(document.getElementById('qcModal')).hide();
                
                // Refresh QC items
                await this.loadQCItems();
                
            } else {
                showAlert(`QC sign-off failed: ${result.error_message}`, 'danger');
            }
            
        } catch (error) {
            console.error('Error confirming QC decision:', error);
            showAlert('Error saving QC decision', 'danger');
        } finally {
            setLoading($('#qcConfirmBtn')[0], false);
        }
    }
    
    applyFilters() {
        const priority = $('#priorityFilter').val();
        const status = $('#statusFilter').val();
        const customerSearch = $('#customerSearch').val().toLowerCase();
        
        $('.allocation-card').each(function() {
            const card = $(this);
            let show = true;
            
            // Priority filter
            if (priority && !card.hasClass(priority)) {
                show = false;
            }
            
            // Status filter  
            if (status) {
                const bookingStatus = card.find('.badge').text().toLowerCase();
                if (!bookingStatus.includes(status.toLowerCase())) {
                    show = false;
                }
            }
            
            // Customer search
            if (customerSearch) {
                const customerName = card.data('customer-name').toLowerCase();
                if (!customerName.includes(customerSearch)) {
                    show = false;
                }
            }
            
            card.toggle(show);
        });
        
        // Update count
        const visibleCount = $('.allocation-card:visible').length;
        $('#bookingCount').text(visibleCount);
    }
    
    initializeFilters() {
        // Set initial filter state
        $('#statusFilter').val('booked');
        this.applyFilters();
    }
    
    async refreshData() {
        try {
            setLoading($('#refreshBtn')[0]);
            
            // Reload the page to get fresh data
            window.location.reload();
            
        } catch (error) {
            console.error('Error refreshing data:', error);
            showAlert('Error refreshing data', 'danger');
        } finally {
            setLoading($('#refreshBtn')[0], false);
        }
    }
    
    // Utility methods
    async apiCall(url, options = {}) {
        const defaultOptions = {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
            }
        };
        
        const config = { ...defaultOptions, ...options };
        
        // Handle query parameters for GET requests
        if (config.method === 'GET' && options.params) {
            const params = new URLSearchParams(options.params);
            url += '?' + params.toString();
        }
        
        const response = await fetch(url, config);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        return await response.json();
    }
}

// Global instance for access from HTML onclick handlers
let allocationDashboard;

// Initialize the allocation dashboard when document is ready
$(document).ready(() => {
    allocationDashboard = new AllocationDashboard();
    
    // Auto-refresh every 2 minutes
    setInterval(() => {
        if (!document.hidden) { // Only refresh if page is visible
            allocationDashboard.loadQCItems();
        }
    }, 120000);
});
