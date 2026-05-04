import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import initManageFraudCase from '@salesforce/apex/FEC_IntegrationManageFraudCaseCtrl.initManageFraudCase';

export default class FecIntegrationManageFraudCase extends LightningElement {
    @api serviceCaseId;

    _natureOfCaseId;
    @api
    get natureOfCaseId() {
        return this._natureOfCaseId;
    }
    set natureOfCaseId(value) {
        const changed = this._natureOfCaseId !== value;
        this._natureOfCaseId = value;
        console.log('this._natureOfCaseId: ', this._natureOfCaseId);
        if (changed && this.serviceCaseId) {
            if (value) {
                this.loadInitData();
            } else {
                //this.actionMode = null;
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

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (pageRef && pageRef.state) {
            const urlServiceCaseId = pageRef.state.c__serviceCaseId;
            const urlNatureOfCaseId = pageRef.state.c__natureOfCaseId;
            
            if (urlServiceCaseId) this.serviceCaseId = urlServiceCaseId;
            if (urlNatureOfCaseId) this.natureOfCaseId = urlNatureOfCaseId;
            console.log('this.serviceCaseId : ', this.serviceCaseId );
            console.log('this.natureOfCaseId : ', this.natureOfCaseId );
        }
        if (this.serviceCaseId) {
            this._initialized = true;
            this.loadInitData();
        }
    }

    connectedCallback() {
        // When embedded in another component with @api props (no URL state)
        if (this.serviceCaseId && !this._initialized) {
            this._initialized = true;
            this.loadInitData();
        }
    }

    get isCreateMode() {
        return this.actionMode === 'CreateMode';
    }

    get isEditMode() {
        return this.actionMode === 'EditMode';
    }

    get isViewMode() {
        return this.actionMode === 'ViewMode';
    }

    get hasMapping() {
        return this.actionMode !== 'NotMapping';
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

    loadInitData() {
        this.loading = true;
        console.log('loadInitData-this.natureOfCaseId:', this.natureOfCaseId);
        initManageFraudCase({
            serviceCaseId: this.serviceCaseId,
            natureOfCaseId: this.natureOfCaseId
        })
            .then(result => {
                console.log('[ManageFraudCase] init result:', result);
                if (result) {
                    this.actionMode = result.actionMode;
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