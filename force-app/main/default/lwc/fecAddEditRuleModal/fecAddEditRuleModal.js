import { LightningElement, api, track } from 'lwc';

export default class FecAddEditRuleModal extends LightningElement {
    @api businessProcessId;
    @api editingRuleId;
    @api selectedRuleData;
    @api isLoading = false;

    @track formData = {
        previousStageId: '',
        actionButtonId: '',
        nextStageId: '',
        nextQueue: '',
        teamUserGroup: ''
    };

    @track stageOptions = [];
    @track actionOptions = [];
    @track errors = {};
    @track isEditMode = false;

    connectedCallback() {
        console.log('[AddEditRuleModal] Connected - editingRuleId:', this.editingRuleId);
        console.log('[AddEditRuleModal] selectedRuleData:', this.selectedRuleData);
        
        this.isEditMode = !!this.editingRuleId;
        
        if (this.isEditMode && this.selectedRuleData) {
            this.loadEditData();
        } else {
            this.resetForm();
        }

        this.loadStages();
        this.loadActionButtons();
    }

    /**
     * Load dữ liệu nếu edit existing rule
     */
    loadEditData() {
        const rule = this.selectedRuleData;
        this.formData = {
            previousStageId: rule.currentStageId || '',
            actionButtonId: rule.actionCode || '',
            nextStageId: rule.nextStageId || '',
            nextQueue: rule.nextQueue || '',
            teamUserGroup: rule.teamUserGroup || ''
        };
        console.log('[AddEditRuleModal] Loaded edit data:', this.formData);
    }

    /**
     * Reset form cho Add new rule
     */
    resetForm() {
        this.formData = {
            previousStageId: '',
            actionButtonId: '',
            nextStageId: '',
            nextQueue: '',
            teamUserGroup: ''
        };
        this.errors = {};
    }

    /**
     * Load Stage options từ Apex
     * TODO: Call getStagesByBP Apex method
     */
    loadStages() {
        // Mock data - Replace with Apex call
        this.stageOptions = [
            { label: 'Stage 1', value: 'stage1' },
            { label: 'Stage 2', value: 'stage2' },
            { label: 'Stage 3', value: 'stage3' }
        ];
        console.log('[AddEditRuleModal] Loaded stages:', this.stageOptions);
    }

    /**
     * Load Action Button options từ Apex
     * TODO: Call getActionButtons Apex method
     */
    loadActionButtons() {
        // Mock data - Replace with Apex call
        this.actionOptions = [
            { label: 'Approve', value: 'APPROVE' },
            { label: 'Reject', value: 'REJECT' },
            { label: 'Submit', value: 'SUBMIT' }
        ];
        console.log('[AddEditRuleModal] Loaded actions:', this.actionOptions);
    }

    /**
     * Handle input change
     */
    handleInputChange(event) {
        const fieldName = event.target.dataset.fieldName;
        const value = event.target.value;
        
        this.formData[fieldName] = value;
        // Clear error khi user chỉnh sửa
        if (this.errors[fieldName]) {
            delete this.errors[fieldName];
            this.errors = { ...this.errors };
        }
        
        console.log('[AddEditRuleModal] Field changed:', fieldName, value);
    }

    /**
     * Validate form
     */
    validateForm() {
        this.errors = {};
        
        if (!this.formData.previousStageId) {
            this.errors.previousStageId = 'Vui lòng chọn Current Stage';
        }
        if (!this.formData.actionButtonId) {
            this.errors.actionButtonId = 'Vui lòng chọn Action';
        }
        if (!this.formData.nextStageId) {
            this.errors.nextStageId = 'Vui lòng chọn Next Stage';
        }
        
        const hasErrors = Object.keys(this.errors).length > 0;
        console.log('[AddEditRuleModal] Validation result:', { hasErrors, errors: this.errors });
        
        return !hasErrors;
    }

    /**
     * Handle save button click
     */
    handleSave() {
        console.log('[AddEditRuleModal] Save button clicked');
        
        if (!this.validateForm()) {
            console.log('[AddEditRuleModal] Validation failed');
            return;
        }

        console.log('[AddEditRuleModal] Form data to save:', this.formData);
        
        // Dispatch custom event với rule data
        this.dispatchEvent(
            new CustomEvent('save', {
                detail: {
                    isEditMode: this.isEditMode,
                    editingRuleId: this.editingRuleId,
                    ruleData: this.formData
                }
            })
        );
    }

    /**
     * Handle cancel button click
     */
    handleCancel() {
        console.log('[AddEditRuleModal] Cancel button clicked');
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    get modalTitle() {
        return this.isEditMode ? 'Chỉnh sửa Rule' : 'Thêm Rule Mới';
    }

    get saveButtonLabel() {
        return this.isEditMode ? 'Cập nhật' : 'Thêm Rule';
    }

    get getErrorClass() {
        return (fieldName) => {
            return this.errors[fieldName] ? 'slds-has-error' : '';
        };
    }

    get getSelectClass() {
        return (fieldName) => {
            return `slds-select ${this.errors[fieldName] ? 'slds-has-error' : ''}`;
        };
    }

    get getErrorMessage() {
        return (fieldName) => {
            return this.errors[fieldName] || '';
        };
    }

    get previousStageClass() {
        return this.errors?.previousStageId ? 'slds-select select-field select-error' : 'slds-select select-field';
    }

    get actionButtonClass() {
        return this.errors?.actionButtonId ? 'slds-select select-field select-error' : 'slds-select select-field';
    }

    get nextStageClass() {
        return this.errors?.nextStageId ? 'slds-select select-field select-error' : 'slds-select select-field';
    }
}