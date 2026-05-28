import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { subscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import FRAUD_FIELD_SYNC from '@salesforce/messageChannel/FEC_Fraud_Field_Sync__c';
import initManageFraudCase from '@salesforce/apex/FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase';
import getIntegrationActionModes from '@salesforce/apex/FEC_IntegrationCreateFraudController.getIntegrationActionModes';

export default class FecIntegrationManageFraudCase extends LightningElement {
    @api serviceCaseId;
    @api recordId;
    @api actionView;
    @api modeEditCase = false;

    @wire(MessageContext)
    messageContext;

    _natureOfCaseId;
    @api
    get natureOfCaseId() {
        return this._natureOfCaseId;
    }
    set natureOfCaseId(value) {
        const changed = this._natureOfCaseId !== value;
        this._natureOfCaseId = value;
        console.log('this._natureOfCaseId: ', this._natureOfCaseId);
        if (changed && (this.serviceCaseId || this.recordId)) {
            if (!this.serviceCaseId) this.serviceCaseId = this.recordId;
            if (value) {
                this.loadInitData();
            } else {
                this.loading = false;
            }
        }
    }

    @track caseDataId;
    @track actionMode;
    @track fraudCaseId;
    @track caseStatus;
    @track caseData;
    @track loading = true;
    @track error;
    @track isFraudSectionOpen = true;
    @track integrateMappingId;
    @track serviceCSCaseId;
    @track fraudHandlingCaseId;
    _initialized = false;
    actionModes = {};

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef && pageRef.state) {
            const urlServiceCaseId = pageRef.state.c__serviceCaseId;
            const urlNatureOfCaseId = pageRef.state.c__natureOfCaseId;
            const urlActionMode = pageRef.state.c__actionMode;
            
            if (urlServiceCaseId) this.serviceCaseId = urlServiceCaseId;
            if (urlNatureOfCaseId) this.natureOfCaseId = urlNatureOfCaseId;
            if (urlActionMode) {
                this.actionMode = urlActionMode;
                this._urlActionMode = urlActionMode;
            }
            console.log('this.serviceCaseId : ', this.serviceCaseId );
            console.log('this.natureOfCaseId : ', this.natureOfCaseId );
            console.log('this.actionMode (from URL) : ', this.actionMode );
        }
        if (this.serviceCaseId) {
            this._initialized = true;
            this.loadInitData();
        }
    }

    connectedCallback() {
        console.log('[fecIntegrationManageFraudCase] connectedCallback — serviceCaseId:', this.serviceCaseId, '| recordId:', this.recordId, '| natureOfCaseId:', this._natureOfCaseId);
        // Subscribe to case→fraud field sync via LMS
        this._subscriptionFraudSync = subscribe(
            this.messageContext,
            FRAUD_FIELD_SYNC,
            (message) => {
                if (message.source === 'case' && message.fieldId) {
                    console.log('[fecIntegrationManageFraudCase] received sync:', message.fieldId, message.value);
                    this.setFraudFieldValue(message.fieldId, message.value);
                }
            },
            { scope: APPLICATION_SCOPE }
        );
        getIntegrationActionModes()
            .then(res => { this.actionModes = res || {}; })
            .catch(err => { console.error('getIntegrationActionModes error', err); });
        // When embedded in another component with @api props (no URL state)
        const effectiveId = this.serviceCaseId || this.recordId;
        if (effectiveId && !this._initialized) {
            this._initialized = true;
            if (!this.serviceCaseId) this.serviceCaseId = this.recordId;
            this.loadInitData();
        }
    }

    get isCreateMode() {
        return this.actionMode === this.actionModes.CREATE_MODE;
    }

    get isEditMode() {
        return this.modeEditCase && this.actionMode === this.actionModes.EDIT_MODE;
    }
    get isSubmitMode() {
        return this.modeEditCase && this.actionMode === this.actionModes.SUBMIT_MODE;
    }

    get isViewMode() {
        if (!this.modeEditCase) {
            return true;
        }
        if (this.actionView) {
            return this.actionMode = this.actionView;
        }
        return this.actionMode === this.actionModes.VIEW_MODE || this.actionMode === 'ViewOriginal';
    }

    get hasMapping() {
        return this.actionMode !== this.actionModes.NOT_MAPPING;
    }

    get notLoading() {
        return !this.loading;
    }

    get fraudSectionClass() {
        return this.isFraudSectionOpen ? 'slds-section slds-is-open' : 'slds-section';
    }

    get fraudSectionIcon() {
        return this.isFraudSectionOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    toggleFraudSection() {
        this.isFraudSectionOpen = !this.isFraudSectionOpen;
    }

    handleFraudCaseSuccess() {
        this.loadInitData();
    }

    renderedCallback() {
        // Apply buffered field values once child is rendered
        if (this._pendingFieldValues) {
            const createEl = this.template.querySelector('c-fec-integration-create-fraud-case');
            if (createEl && typeof createEl.setFieldValue === 'function') {
                for (const [fieldId, value] of Object.entries(this._pendingFieldValues)) {
                    createEl.setFieldValue(fieldId, value);
                }
                this._pendingFieldValues = null;
            }
        }
    }

    @api
    getFieldData() {
        return {
            actionMode: this.actionMode,
            fraudCaseId: this.fraudCaseId,
            caseStatus: this.caseStatus,
            integrateMappingId: this.integrateMappingId,
            serviceCSCaseId: this.serviceCSCaseId
        };
    }

    @api
    setFraudFieldValue(fieldId, value) {
        const createEl = this.template.querySelector('c-fec-integration-create-fraud-case');
        if (createEl && typeof createEl.setFieldValue === 'function') {
            createEl.setFieldValue(fieldId, value);
        } else {
            // Buffer value if child not rendered yet
            if (!this._pendingFieldValues) {
                this._pendingFieldValues = {};
            }
            this._pendingFieldValues[fieldId] = value;
        }
    }

    @api
    async submitFraudWithoutCallout() {
        const createEl = this.template.querySelector('c-fec-integration-create-fraud-case');
        if (createEl && typeof createEl.onSubmitWithoutCallout === 'function') {
            await createEl.onSubmitWithoutCallout();
        }
    }

    @api
    async submitFraudCase() {
        const createEl = this.template.querySelector('c-fec-integration-create-fraud-case');
        if (createEl && typeof createEl.onSubmitFraudCase === 'function') {
            await createEl.onSubmitFraudCase();
        }
    }

    @api
    setRemarks(value) {
        const createEl = this.template.querySelector('c-fec-integration-create-fraud-case');
        if (createEl) {
            createEl.remarks = value || '';
        }
    }

    @api
    validateFraudForm() {
        console.log('[fecIntegrationManageFraudCase] validateFraudForm — actionMode:', this.actionMode, '| hasMapping:', this.hasMapping);
        // Skip validation if no mapping or in ViewMode
        //if (!this.hasMapping || this.isViewMode) return true;

        if (this.isCreateMode) {
            const createEl = this.template.querySelector('c-fec-integration-create-fraud-case');
            console.log('[fecIntegrationManageFraudCase] validateFraudForm — createEl:', createEl);
            if (createEl && typeof createEl.validateForm === 'function') {
                return createEl.validateForm();
            }
        }

        if (this.isEditMode || this.isSubmitMode) {
            const updateEl = this.template.querySelector('c-fec-integration-update-fraud-case');
            if (updateEl && typeof updateEl.validateForm === 'function') {
                return updateEl.validateForm();
            }
        }

        return true;
    }

    loadInitData() {
        this.loading = true;
        console.log('loadInitData-this.natureOfCaseId:', this.natureOfCaseId);
        initManageFraudCase({
            serviceCaseId: this.serviceCaseId,
            natureOfCaseId: this.natureOfCaseId
        })
            .then(result => {
                console.log('[ManageFraudCase] init result:', result);
                console.log('[ManageFraudCase] actionView (api param):', this.actionView);
                if (result) {
                    // Priority: URL param > actionView prop > Apex result
                    const urlActionMode = this._urlActionMode;
                    this.actionMode = urlActionMode || this.actionView || result.actionMode;
                    console.log('[ManageFraudCase] final actionMode:', this.actionMode, '| from:', urlActionMode ? 'URL' : (this.actionView ? 'actionView' : 'result.actionMode'));
                    this.fraudCaseId = result.fraudCaseId;
                    this.caseStatus = result.caseStatus;
                    this.caseData = result.caseData;
                    this.integrateMappingId = result.integrateMappingId;
                    this.serviceCSCaseId = result.serviceCaseId;
                    this.caseDataId = result.caseData ? result.caseData.Id : null;
                }
                console.log('[ManageFraudCase] actionMode:', this.actionMode);
                console.log('[ManageFraudCase] integrateMappingId:', this.integrateMappingId);
            })
            .catch(err => {
                console.error('[ManageFraudCase] Error:', err);
                this.error = err?.body?.message || err?.message;
            })
            .finally(() => {
                this.loading = false;
            });
    }
}