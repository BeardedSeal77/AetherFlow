/**
 * Equipment Hire Form JavaScript
 * Handles the new hire creation form functionality
 */

class HireForm {
    constructor() {
        this.selectedEquipment = [];
        this.selectedAccessories = [];
        this.currentMode = 'generic'; // 'generic' or 'specific'
        this.autoAccessories = [];
        
        this.initializeForm();
        this.bindEvents();
        this.loadInitialData();
    }
    
    initializeForm() {
        // Set default dates
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        
        document.getElementById('hireStartDate').value = tomorrow.toISOString().split('T')[0];
        document.getElementById('deliveryDate').value = tomorrow.toISOString().split('T')[0];
        
        // Initialize mode
        this.setEquipmentMode('generic');
    }
    
    bindEvents() {
        // Customer selection
        $('#customerSelect').on('change', (e) => this.onCustomerChange(e.target.value));
        
        // Equipment mode toggle
        $('#genericModeBtn').on('click', () => this.setEquipmentMode('generic'));
        $('#specificModeBtn').on('click', () => this.setEquipmentMode('specific'));
        
        // Search buttons
        $('#equipmentSearchBtn').on('click', () => this.searchEquipment());
        $('#accessorySearchBtn').on('click', () => this.searchAccessories());
        
        // Enter key search AND real-time filtering
        $('#equipmentSearch').on('keypress', (e) => {
            if (e.which === 13) this.searchEquipment();
        });
        $('#equipmentSearch').on('input', () => {
            // Only filter if we have results already displayed
            if ($('#equipmentList .equipment-item').length > 0) {
                this.filterEquipmentResults();
            }
        });
        
        $('#accessorySearch').on('keypress', (e) => {
            if (e.which === 13) this.searchAccessories();
        });
        $('#accessorySearch').on('input', () => this.filterAccessoryResults());
        
        // Form actions
        $('#validateBtn').on('click', () => this.validateHire());
        $('#resetBtn').on('click', () => this.resetForm());
        $('#hireForm').on('submit', (e) => this.submitForm(e));
        
        // Date validation
        $('#hireStartDate, #hireEndDate, #deliveryDate').on('change', () => this.validateDates());
    }
    
    async loadInitialData() {
        try {
            // Load customers
            const customers = await this.apiCall('/api/customers');
            this.populateCustomers(customers);
        } catch (error) {
            console.error('Error loading initial data:', error);
            showAlert('Error loading form data', 'danger');
        }
    }
    
    async onCustomerChange(customerId) {
        if (!customerId) {
            $('#contactSelect').prop('disabled', true).html('<option value="">Select Contact...</option>');
            $('#siteSelect').prop('disabled', true).html('<option value="">Select Site...</option>');
            return;
        }
        
        try {
            // Load contacts and sites for selected customer
            const [contacts, sites] = await Promise.all([
                this.apiCall(`/api/customers/${customerId}/contacts`),
                this.apiCall(`/api/customers/${customerId}/sites`)
            ]);
            
            this.populateContacts(contacts);
            this.populateSites(sites);
            
        } catch (error) {
            console.error('Error loading customer data:', error);
            showAlert('Error loading customer information', 'danger');
        }
    }
    
    setEquipmentMode(mode) {
        this.currentMode = mode;
        
        // Update button states
        $('#genericModeBtn').toggleClass('active', mode === 'generic');
        $('#specificModeBtn').toggleClass('active', mode === 'specific');
        
        // Update search placeholder
        const placeholder = mode === 'generic' 
            ? 'Search equipment types...' 
            : 'Search specific equipment units...';
        $('#equipmentSearch').attr('placeholder', placeholder);
        
        // Clear current search results
        $('#equipmentList').html(`
            <div class="text-center py-4">
                <i class="fas fa-search fa-3x text-muted mb-3"></i>
                <p class="text-muted">Search for equipment to add to hire</p>
            </div>
        `);
    }
    
    async searchEquipment() {
        const searchTerm = $('#equipmentSearch').val();
        const hireStartDate = $('#hireStartDate').val();
        const hireEndDate = $('#hireEndDate').val();
        
        if (!searchTerm.trim()) {
            showAlert('Please enter a search term', 'warning');
            return;
        }
        
        try {
            setLoading($('#equipmentSearchBtn')[0]);
            
            let equipment;
            if (this.currentMode === 'generic') {
                equipment = await this.apiCall('/api/equipment-types', {
                    params: {
                        search: searchTerm,
                        hire_start_date: hireStartDate,
                        hire_end_date: hireEndDate
                    }
                });
            } else {
                equipment = await this.apiCall('/api/equipment', {
                    params: {
                        search: searchTerm,
                        hire_start_date: hireStartDate,
                        hire_end_date: hireEndDate
                    }
                });
            }
            
            this.displayEquipmentResults(equipment);
            
        } catch (error) {
            console.error('Error searching equipment:', error);
            showAlert('Error searching equipment', 'danger');
        } finally {
            setLoading($('#equipmentSearchBtn')[0], false);
        }
    }
    
    displayEquipmentResults(equipment) {
        const container = $('#equipmentList');
        
        if (!equipment || equipment.length === 0) {
            container.html(`
                <div class="text-center py-4">
                    <i class="fas fa-exclamation-circle fa-3x text-muted mb-3"></i>
                    <p class="text-muted">No equipment found matching your search</p>
                </div>
            `);
            return;
        }
        
        const html = equipment.map(item => {
            if (this.currentMode === 'generic') {
                return this.createEquipmentTypeCard(item);
            } else {
                return this.createEquipmentUnitCard(item);
            }
        }).join('');
        
        container.html(html);
        
        // Bind click events
        container.find('.equipment-item').on('click', (e) => {
            const card = $(e.currentTarget);
            const equipmentData = card.data();
            
            // Debug logging to see what data we're getting
            console.log('Equipment data from card:', equipmentData);
            
            this.addEquipment(equipmentData);
        });
    }
    
    createEquipmentTypeCard(equipment) {
        const isUnavailable = equipment.available_units === 0;
        const unavailableClass = isUnavailable ? 'opacity-50' : '';
        
        return `
            <div class="equipment-item ${unavailableClass}" 
                 data-equipment-type-id="${equipment.equipment_type_id}"
                 data-type-code="${equipment.type_code}"
                 data-type-name="${equipment.type_name}"
                 data-daily-rate="${equipment.daily_rate}"
                 data-mode="generic">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">
                            <i class="fas fa-tools me-2"></i>
                            ${equipment.type_name}
                        </h6>
                        <p class="text-muted mb-1">${equipment.type_code}</p>
                        <p class="small mb-2">${equipment.description || ''}</p>
                        <div class="row text-sm">
                            <div class="col-sm-6">
                                <strong>Available:</strong> ${equipment.available_units}/${equipment.total_units}
                            </div>
                            <div class="col-sm-6">
                                <strong>Daily Rate:</strong> ${formatCurrency(equipment.daily_rate)}
                            </div>
                        </div>
                    </div>
                    <div class="ms-3">
                        <button type="button" class="btn btn-primary btn-sm" ${isUnavailable ? 'disabled' : ''}>
                            <i class="fas fa-plus"></i>
                        </button>
                    </div>
                </div>
            </div>
        `;
    }
    
    createEquipmentUnitCard(equipment) {
        return `
            <div class="equipment-item" 
                 data-equipment-id="${equipment.equipment_id}"
                 data-equipment-type-id="${equipment.equipment_type_id}"
                 data-asset-code="${equipment.asset_code}"
                 data-type-name="${equipment.type_name}"
                 data-model="${equipment.model}"
                 data-condition="${equipment.condition}"
                 data-mode="specific">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">
                            <i class="fas fa-cog me-2"></i>
                            ${equipment.asset_code}
                        </h6>
                        <p class="text-muted mb-1">${equipment.type_name}</p>
                        <p class="small mb-2">${equipment.model || ''}</p>
                        <div class="d-flex gap-2">
                            <span class="badge condition-${equipment.condition}">${equipment.condition}</span>
                            ${equipment.is_overdue_service ? '<span class="badge bg-danger">Service Overdue</span>' : ''}
                        </div>
                    </div>
                    <div class="ms-3">
                        <button type="button" class="btn btn-primary btn-sm">
                            <i class="fas fa-plus"></i>
                        </button>
                    </div>
                </div>
            </div>
        `;
    }
    
    async addEquipment(equipmentData) {
        console.log('addEquipment called with:', equipmentData);
        
        // Check if already selected
        const isAlreadySelected = this.selectedEquipment.some(item => {
            if (equipmentData.mode === 'generic') {
                return item.equipment_type_id === equipmentData.equipmentTypeId;
            } else {
                return item.equipment_id === equipmentData.equipmentId;
            }
        });
        
        if (isAlreadySelected) {
            showAlert('Equipment already selected', 'warning');
            return;
        }
        
        // Add to selected equipment  
        const equipmentItem = {
            id: equipmentData.mode === 'generic' ? equipmentData.equipmentTypeId : equipmentData.equipmentId,
            mode: equipmentData.mode,
            equipment_type_id: equipmentData.equipmentTypeId, // Now this should be available for both modes
            equipment_id: equipmentData.mode === 'specific' ? equipmentData.equipmentId : null,
            name: equipmentData.mode === 'generic' ? equipmentData.typeName : `${equipmentData.assetCode} - ${equipmentData.typeName}`,
            code: equipmentData.mode === 'generic' ? equipmentData.typeCode : equipmentData.assetCode,
            quantity: 1,
            daily_rate: equipmentData.dailyRate || 0
        };
        
        console.log('Created equipmentItem:', equipmentItem);
        
        this.selectedEquipment.push(equipmentItem);
        
        // If generic mode, calculate auto-accessories AND add all related accessories
        if (equipmentData.mode === 'generic') {
            await this.calculateAutoAccessories();
            // Add all accessories (default with quantity > 0, optional with quantity = 0)
            await this.addAllEquipmentAccessories(equipmentData.equipmentTypeId);
        } else if (equipmentData.mode === 'specific') {
            // For specific equipment, load its accessories
            await this.addSpecificEquipmentAccessories(equipmentData.equipmentId);
        }
        
        this.updateSelectedItemsDisplay();
        showAlert(`${equipmentItem.name} added to hire`, 'success');
    }
    
    async calculateAutoAccessories() {
        try {
            const equipmentTypes = this.selectedEquipment
                .filter(item => item.mode === 'generic')
                .map(item => ({
                    equipment_type_id: item.equipment_type_id,
                    quantity: item.quantity
                }));
            
            if (equipmentTypes.length === 0) return;
            
            const accessories = await this.apiCall('/api/accessories/auto-calculate', {
                method: 'POST',
                body: JSON.stringify({ equipment_types: equipmentTypes })
            });
            
            // Update auto accessories, merging with existing custom accessories
            this.autoAccessories = accessories;
            this.mergeAccessories();
            
        } catch (error) {
            console.error('Error calculating auto accessories:', error);
            showAlert('Error calculating accessories', 'warning');
        }
    }
    
    mergeAccessories() {
        // Start with auto accessories
        const mergedAccessories = [...this.autoAccessories];
        
        // Add custom accessories that aren't already in auto accessories
        this.selectedAccessories.forEach(customAcc => {
            const existingIndex = mergedAccessories.findIndex(autoAcc => autoAcc.accessory_id === customAcc.accessory_id);
            if (existingIndex >= 0) {
                // Merge quantities
                mergedAccessories[existingIndex].total_quantity += customAcc.quantity;
            } else {
                // Add new custom accessory
                mergedAccessories.push({
                    accessory_id: customAcc.accessory_id,
                    accessory_code: customAcc.accessory_code,
                    accessory_name: customAcc.accessory_name,
                    total_quantity: customAcc.quantity,
                    unit_of_measure: customAcc.unit_of_measure,
                    unit_rate: customAcc.unit_rate,
                    accessory_type: 'custom'
                });
            }
        });
        
        this.autoAccessories = mergedAccessories;
    }
    
    async addSpecificEquipmentAccessories(equipmentId) {
        try {
            const accessories = await this.apiCall(`/api/equipment/${equipmentId}/accessories`);
            
            // Add these accessories to the auto accessories list
            accessories.forEach(accessory => {
                const existingIndex = this.autoAccessories.findIndex(item => 
                    item.accessory_id === accessory.accessory_id
                );
                
                if (existingIndex >= 0) {
                    // Increase quantity if already exists
                    this.autoAccessories[existingIndex].total_quantity += accessory.quantity;
                } else {
                    // Add new accessory
                    this.autoAccessories.push({
                        accessory_id: accessory.accessory_id,
                        accessory_code: accessory.accessory_code,
                        accessory_name: accessory.accessory_name,
                        total_quantity: accessory.quantity,
                        unit_of_measure: accessory.unit_of_measure,
                        unit_rate: accessory.unit_rate,
                        accessory_type: accessory.accessory_type
                    });
                }
            });
            
        } catch (error) {
            console.error('Error loading equipment accessories:', error);
            showAlert('Error loading equipment accessories', 'warning');
        }
    }
    
    async addAllEquipmentAccessories(equipmentTypeId) {
        try {
            const accessories = await this.apiCall(`/api/equipment-types/${equipmentTypeId}/accessories`);
            
            // Add optional accessories with quantity 0
            accessories.forEach(accessory => {
                if (accessory.accessory_type === 'optional') {
                    const existingIndex = this.autoAccessories.findIndex(item => 
                        item.accessory_id === accessory.accessory_id
                    );
                    
                    if (existingIndex === -1) {
                        this.autoAccessories.push({
                            accessory_id: accessory.accessory_id,
                            accessory_code: accessory.accessory_code,
                            accessory_name: accessory.accessory_name,
                            total_quantity: 0,
                            unit_of_measure: accessory.unit_of_measure,
                            unit_rate: accessory.unit_rate,
                            accessory_type: accessory.accessory_type
                        });
                    }
                }
            });
            
        } catch (error) {
            console.error('Error loading equipment type accessories:', error);
        }
    }
    
    updateSelectedItemsDisplay() {
        const container = $('#selectedItems');
        
        if (this.selectedEquipment.length === 0 && this.autoAccessories.length === 0) {
            container.html(`
                <div class="text-center py-4 text-muted">
                    <i class="fas fa-inbox fa-3x mb-3"></i>
                    <p>No items selected</p>
                </div>
            `);
            return;
        }
        
        let html = '';
        
        // Equipment items
        this.selectedEquipment.forEach((item, index) => {
            html += this.createSelectedEquipmentItem(item, index);
        });
        
        // Separator if both equipment and accessories exist
        if (this.selectedEquipment.length > 0 && this.autoAccessories.length > 0) {
            html += '<hr class="my-3">';
        }
        
        // Accessory items
        this.autoAccessories.forEach((item, index) => {
            if (item.total_quantity > 0) {
                html += this.createSelectedAccessoryItem(item, index);
            }
        });
        
        container.html(html);
        this.bindSelectedItemEvents();
    }
    
    createSelectedEquipmentItem(item, index) {
        const maxQuantity = item.mode === 'specific' ? 1 : 99;
        const isSpecific = item.mode === 'specific';
        
        return `
            <div class="selected-item equipment-item" data-index="${index}" data-type="equipment">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">
                            <i class="fas fa-${isSpecific ? 'cog' : 'tools'} me-2"></i>
                            ${item.name}
                        </h6>
                        <small class="text-muted">${item.code}</small>
                        ${item.daily_rate > 0 ? `<br><small class="text-success">${formatCurrency(item.daily_rate)}/day</small>` : ''}
                    </div>
                    <div class="item-actions">
                        <div class="quantity-controls me-2">
                            <button type="button" class="btn btn-outline-secondary btn-sm quantity-decrease" ${item.quantity <= 1 ? 'disabled' : ''}>
                                <i class="fas fa-minus"></i>
                            </button>
                            <input type="number" class="form-control form-control-sm quantity-input" 
                                   value="${item.quantity}" min="1" max="${maxQuantity}" ${isSpecific ? 'readonly' : ''}>
                            <button type="button" class="btn btn-outline-secondary btn-sm quantity-increase" ${item.quantity >= maxQuantity ? 'disabled' : ''}>
                                <i class="fas fa-plus"></i>
                            </button>
                        </div>
                        <button type="button" class="btn btn-outline-danger btn-sm remove-item">
                            <i class="fas fa-times"></i>
                        </button>
                    </div>
                </div>
            </div>
        `;
    }
    
    createSelectedAccessoryItem(item, index) {
        const isDefault = item.accessory_type === 'default';
        
        return `
            <div class="selected-item accessory-item" data-index="${index}" data-type="accessory">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">
                            <i class="fas fa-puzzle-piece me-2"></i>
                            ${item.accessory_name}
                        </h6>
                        <small class="text-muted">${item.accessory_code}</small>
                        ${item.unit_rate > 0 ? `<br><small class="text-success">${formatCurrency(item.unit_rate)}/${item.unit_of_measure}</small>` : ''}
                        <br><span class="badge bg-${isDefault ? 'secondary' : 'info'}">${item.accessory_type}</span>
                    </div>
                    <div class="item-actions">
                        <div class="quantity-controls me-2">
                            <button type="button" class="btn btn-outline-secondary btn-sm quantity-decrease" 
                                    ${isDefault && item.total_quantity <= 1 ? 'disabled' : ''}>
                                <i class="fas fa-minus"></i>
                            </button>
                            <input type="number" class="form-control form-control-sm quantity-input" 
                                   value="${item.total_quantity}" min="${isDefault ? 1 : 0}" step="0.5">
                            <button type="button" class="btn btn-outline-secondary btn-sm quantity-increase">
                                <i class="fas fa-plus"></i>
                            </button>
                        </div>
                        <button type="button" class="btn btn-outline-danger btn-sm remove-item">
                            <i class="fas fa-times"></i>
                        </button>
                    </div>
                </div>
            </div>
        `;
    }
    
    bindSelectedItemEvents() {
        // Quantity controls
        $('.quantity-decrease').on('click', (e) => this.adjustQuantity(e, -1));
        $('.quantity-increase').on('click', (e) => this.adjustQuantity(e, 1));
        $('.quantity-input').on('change', (e) => this.setQuantity(e));
        
        // Remove items
        $('.remove-item').on('click', (e) => this.removeItem(e));
    }
    
    adjustQuantity(event, delta) {
        const item = $(event.target).closest('.selected-item');
        const input = item.find('.quantity-input');
        const currentValue = parseFloat(input.val()) || 0;
        const newValue = Math.max(0, currentValue + delta);
        
        input.val(newValue);
        this.setQuantity({ target: input[0] });
    }
    
    async setQuantity(event) {
        const input = $(event.target);
        const item = input.closest('.selected-item');
        const index = parseInt(item.data('index'));
        const type = item.data('type');
        const newQuantity = parseFloat(input.val()) || 0;
        
        if (type === 'equipment') {
            this.selectedEquipment[index].quantity = newQuantity;
            if (this.selectedEquipment[index].mode === 'generic') {
                await this.calculateAutoAccessories();
            }
        } else if (type === 'accessory') {
            this.autoAccessories[index].total_quantity = newQuantity;
        }
        
        this.updateSelectedItemsDisplay();
    }
    
    async removeItem(event) {
        const item = $(event.target).closest('.selected-item');
        const index = parseInt(item.data('index'));
        const type = item.data('type');
        
        if (type === 'equipment') {
            this.selectedEquipment.splice(index, 1);
            await this.calculateAutoAccessories();
        } else if (type === 'accessory') {
            // Allow removal of ANY accessory (including default ones)
            this.autoAccessories.splice(index, 1);
        }
        
        this.updateSelectedItemsDisplay();
    }
    
    async searchAccessories() {
        const searchTerm = $('#accessorySearch').val();
        
        if (!searchTerm.trim()) {
            showAlert('Please enter a search term', 'warning');
            return;
        }
        
        try {
            setLoading($('#accessorySearchBtn')[0]);
            
            const accessories = await this.apiCall('/api/accessories/standalone', {
                params: {
                    search: searchTerm
                }
            });
            
            this.displayAccessoryResults(accessories);
            
        } catch (error) {
            console.error('Error searching accessories:', error);
            showAlert('Error searching accessories', 'danger');
        } finally {
            setLoading($('#accessorySearchBtn')[0], false);
        }
    }
    
    displayAccessoryResults(accessories) {
        const container = $('#accessoryList');
        
        if (!accessories || accessories.length === 0) {
            container.html(`
                <div class="text-center py-3 text-muted">
                    <i class="fas fa-exclamation-circle fa-2x mb-2"></i>
                    <p>No accessories found matching your search</p>
                </div>
            `);
            return;
        }
        
        const html = accessories.map(accessory => `
            <div class="accessory-item" 
                 data-accessory-id="${accessory.accessory_id}"
                 data-accessory-code="${accessory.accessory_code}"
                 data-accessory-name="${accessory.accessory_name}"
                 data-unit-rate="${accessory.unit_rate}"
                 data-unit-of-measure="${accessory.unit_of_measure}">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">
                            <i class="fas fa-puzzle-piece me-2"></i>
                            ${accessory.accessory_name}
                        </h6>
                        <p class="text-muted mb-1">${accessory.accessory_code}</p>
                        <p class="small mb-2">${accessory.description || ''}</p>
                        <div class="text-sm">
                            <strong>Rate:</strong> ${formatCurrency(accessory.unit_rate)}/${accessory.unit_of_measure}
                        </div>
                    </div>
                    <div class="ms-3">
                        <button type="button" class="btn btn-primary btn-sm">
                            <i class="fas fa-plus"></i>
                        </button>
                    </div>
                </div>
            </div>
        `).join('');
        
        container.html(html);
        
        // Bind click events
        container.find('.accessory-item').on('click', (e) => {
            const card = $(e.currentTarget);
            const accessoryData = card.data();
            this.addCustomAccessory(accessoryData);
        });
    }
    
    addCustomAccessory(accessoryData) {
        // Check if already exists in auto accessories
        const existingIndex = this.autoAccessories.findIndex(item => 
            item.accessory_id === accessoryData.accessoryId
        );
        
        if (existingIndex >= 0) {
            // Increase quantity
            this.autoAccessories[existingIndex].total_quantity += 1;
        } else {
            // Add new custom accessory
            this.autoAccessories.push({
                accessory_id: accessoryData.accessoryId,
                accessory_code: accessoryData.accessoryCode,
                accessory_name: accessoryData.accessoryName,
                total_quantity: 1,
                unit_of_measure: accessoryData.unitOfMeasure,
                unit_rate: accessoryData.unitRate,
                accessory_type: 'custom'
            });
        }
        
        this.updateSelectedItemsDisplay();
        showAlert(`${accessoryData.accessoryName} added`, 'success');
    }
    
    validateDates() {
        const hireStart = $('#hireStartDate').val();
        const hireEnd = $('#hireEndDate').val();
        const delivery = $('#deliveryDate').val();
        
        if (hireStart && delivery && new Date(delivery) > new Date(hireStart)) {
            showAlert('Delivery date should not be after hire start date', 'warning');
        }
        
        if (hireStart && hireEnd && new Date(hireEnd) < new Date(hireStart)) {
            showAlert('Hire end date cannot be before start date', 'warning');
        }
    }
    
    async validateHire() {
        const formData = this.collectFormData();
        
        if (!this.validateFormData(formData)) {
            return;
        }
        
        try {
            setLoading($('#validateBtn')[0]);
            
            const validation = await this.apiCall('/api/hire/validate', {
                method: 'POST',
                body: JSON.stringify(formData)
            });
            
            if (validation.is_valid) {
                showAlert('Hire validation passed! Ready to create.', 'success');
                if (validation.warning_message) {
                    showAlert(validation.warning_message, 'warning');
                }
            } else {
                showAlert(`Validation failed: ${validation.error_message}`, 'danger');
            }
            
        } catch (error) {
            console.error('Error validating hire:', error);
            showAlert('Error validating hire request', 'danger');
        } finally {
            setLoading($('#validateBtn')[0], false);
        }
    }
    
    async submitForm(event) {
        event.preventDefault();
        
        const formData = this.collectFormData();
        
        if (!this.validateFormData(formData)) {
            return;
        }
        
        try {
            setLoading($('#submitBtn')[0]);
            
            const result = await this.apiCall('/api/hire/create', {
                method: 'POST',
                body: JSON.stringify(formData)
            });
            
            if (result.success) {
                showAlert(`Hire created successfully! Reference: ${result.reference_number}`, 'success');
                
                // Redirect to hire details after short delay
                setTimeout(() => {
                    window.location.href = `/hire/${result.interaction_id}`;
                }, 2000);
            } else {
                showAlert(`Failed to create hire: ${result.error_message}`, 'danger');
            }
            
        } catch (error) {
            console.error('Error creating hire:', error);
            showAlert('Error creating hire request', 'danger');
        } finally {
            setLoading($('#submitBtn')[0], false);
        }
    }
    
    collectFormData() {
        return {
            customer_id: parseInt($('#customerSelect').val()),
            contact_id: parseInt($('#contactSelect').val()),
            site_id: parseInt($('#siteSelect').val()),
            contact_method: $('#contactMethod').val(),
            hire_start_date: $('#hireStartDate').val(),
            hire_end_date: $('#hireEndDate').val() || null,
            delivery_date: $('#deliveryDate').val(),
            delivery_time: $('#deliveryTime').val() || null,
            special_instructions: $('#specialInstructions').val() || null,
            notes: $('#notes').val() || null,
            equipment_types: this.selectedEquipment.map(item => ({
                equipment_type_id: item.equipment_type_id,
                equipment_id: item.equipment_id, // Include specific equipment ID if available
                quantity: item.quantity,
                mode: item.mode
            })),
            accessories: this.autoAccessories
                .filter(item => item.total_quantity > 0 && item.accessory_type !== 'default')
                .map(item => ({
                    accessory_id: item.accessory_id,
                    quantity: item.total_quantity,
                    equipment_type_booking_id: null
                }))
        };
    }
    
    validateFormData(formData) {
        if (!formData.customer_id) {
            showAlert('Please select a customer', 'warning');
            return false;
        }
        
        if (!formData.contact_id) {
            showAlert('Please select a contact person', 'warning');
            return false;
        }
        
        if (!formData.site_id) {
            showAlert('Please select a delivery site', 'warning');
            return false;
        }
        
        if (!formData.hire_start_date) {
            showAlert('Please set hire start date', 'warning');
            return false;
        }
        
        if (!formData.delivery_date) {
            showAlert('Please set delivery date', 'warning');
            return false;
        }
        
        if (this.selectedEquipment.length === 0) {
            showAlert('Please select at least one piece of equipment', 'warning');
            return false;
        }
        
        return true;
    }
    
    resetForm() {
        if (confirm('Are you sure you want to reset the form? All data will be lost.')) {
            this.selectedEquipment = [];
            this.selectedAccessories = [];
            this.autoAccessories = [];
            
            document.getElementById('hireForm').reset();
            this.initializeForm();
            this.updateSelectedItemsDisplay();
            
            showAlert('Form reset successfully', 'info');
        }
    }
    
    // Utility methods
    populateCustomers(customers) {
        const select = $('#customerSelect');
        select.html('<option value="">Select Customer...</option>');
        
        customers.forEach(customer => {
            select.append(`
                <option value="${customer.customer_id}">
                    ${customer.customer_name} (${customer.customer_code})
                </option>
            `);
        });
    }
    
    populateContacts(contacts) {
        const select = $('#contactSelect');
        select.html('<option value="">Select Contact...</option>');
        select.prop('disabled', false);
        
        contacts.forEach(contact => {
            const primaryIndicator = contact.is_primary_contact ? ' (Primary)' : '';
            select.append(`
                <option value="${contact.contact_id}">
                    ${contact.full_name}${primaryIndicator}
                    ${contact.job_title ? ' - ' + contact.job_title : ''}
                </option>
            `);
        });
    }
    
    populateSites(sites) {
        const select = $('#siteSelect');
        select.html('<option value="">Select Site...</option>');
        select.prop('disabled', false);
        
        sites.forEach(site => {
            select.append(`
                <option value="${site.site_id}">
                    ${site.site_name} (${site.site_code || 'No Code'})
                </option>
            `);
        });
    }
    
    // New method to add all accessories for an equipment type
    async addAllEquipmentAccessories(equipmentTypeId) {
        try {
            const allAccessories = await this.apiCall(`/api/equipment-types/${equipmentTypeId}/accessories`);
            
            allAccessories.forEach(acc => {
                const existingIndex = this.autoAccessories.findIndex(item => 
                    item.accessory_id === acc.accessory_id
                );
                
                if (existingIndex < 0) {
                    // Add accessory with proper quantity (default > 0, optional = 0)
                    this.autoAccessories.push({
                        accessory_id: acc.accessory_id,
                        accessory_code: acc.accessory_code,
                        accessory_name: acc.accessory_name,
                        total_quantity: acc.accessory_type === 'default' ? acc.default_quantity : 0,
                        unit_of_measure: acc.unit_of_measure,
                        unit_rate: 0.00,
                        accessory_type: acc.accessory_type
                    });
                }
            });
            
        } catch (error) {
            console.error('Error loading equipment accessories:', error);
        }
    }
    
    // New method to filter equipment results in real-time
    filterEquipmentResults() {
        const searchTerm = $('#equipmentSearch').val().toLowerCase().trim();
        
        // If no search term, show all items
        if (!searchTerm) {
            $('#equipmentList .equipment-item').show();
            return;
        }
        
        $('#equipmentList .equipment-item').each(function() {
            const card = $(this);
            const typeName = card.data('type-name')?.toLowerCase() || '';
            const typeCode = card.data('type-code')?.toLowerCase() || '';
            const assetCode = card.data('asset-code')?.toLowerCase() || '';
            
            const matches = typeName.includes(searchTerm) || 
                          typeCode.includes(searchTerm) || 
                          assetCode.includes(searchTerm);
            
            card.toggle(matches);
        });
    }
    
    // New method to filter accessory results in real-time
    filterAccessoryResults() {
        const searchTerm = $('#accessorySearch').val().toLowerCase().trim();
        if (!searchTerm) return;
        
        $('#accessoryList .accessory-item').each(function() {
            const card = $(this);
            const accessoryName = card.data('accessory-name')?.toLowerCase() || '';
            const accessoryCode = card.data('accessory-code')?.toLowerCase() || '';
            
            const matches = accessoryName.includes(searchTerm) || 
                          accessoryCode.includes(searchTerm);
            
            card.toggle(matches);
        });
    }

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

// Initialize the hire form when document is ready
$(document).ready(() => {
    new HireForm();
});
