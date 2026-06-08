import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

import getGlobalObjectList from '@salesforce/apex/FEC_MasterDataSettingController.getGlobalObjectList';
import getObjectFields from '@salesforce/apex/FEC_MasterDataSettingController.getObjectFields';
import getDistinctSections from '@salesforce/apex/FEC_MasterDataSettingController.getDistinctSections';
import getDistinctSubSections from '@salesforce/apex/FEC_MasterDataSettingController.getDistinctSubSections';
import getUserRoles from '@salesforce/apex/FEC_MasterDataSettingController.getUserRoles';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
import executePushToLive from '@salesforce/apex/FEC_MasterDataSettingController.executePushToLive';

import deployCustomField from '@salesforce/apex/FEC_MetadataFieldCreator.deployCustomField';
import validateFieldApiName from '@salesforce/apex/FEC_MetadataFieldCreator.validateFieldApiName';
import checkFieldExists from '@salesforce/apex/FEC_MetadataFieldCreator.checkFieldExists';
import generateApiName from '@salesforce/apex/FEC_MetadataFieldCreator.generateApiName';
import getDeployRequestStatus from '@salesforce/apex/FEC_MetadataFieldCreator.getDeployRequestStatus';

import LABEL_TITLE from '@salesforce/label/c.FEC_Label_Auto_Field_Creator_Title';
import LABEL_DEPLOY_IN_PROGRESS from '@salesforce/label/c.FEC_Label_Deploy_In_Progress';
import LABEL_DEPLOY_SUCCESS from '@salesforce/label/c.FEC_Label_Deploy_Success';
import LABEL_DEPLOY_FAILED from '@salesforce/label/c.FEC_Label_Deploy_Failed';
import LABEL_PUSH_TO_LIVE from '@salesforce/label/c.FEC_Label_Push_To_Live';
import LABEL_ERROR_FIELD_EXISTS from '@salesforce/label/c.FEC_Error_Field_Already_Exists';

const STEPS = {
    SELECT_OBJECT: 'SelectObject',
    SELECT_FIELD: 'SelectField',
    DEPLOY_FIELD: 'DeployField',
    CONFIGURE_MDS: 'ConfigureMDS',
    REVIEW_SAVE: 'ReviewSave'
};

const FIELD_TYPES = [
    { label: 'Text', value: 'Text' },
    { label: 'Number', value: 'Number' },
    { label: 'Checkbox', value: 'Checkbox' },
    { label: 'Date', value: 'Date' },
    { label: 'DateTime', value: 'DateTime' },
    { label: 'Picklist', value: 'Picklist' },
    { label: 'Lookup', value: 'Lookup' },
    { label: 'Currency', value: 'Currency' },
    { label: 'Percent', value: 'Percent' },
    { label: 'Phone', value: 'Phone' },
    { label: 'Email', value: 'Email' },
    { label: 'URL', value: 'URL' }
];

const DEPLOY_EVENT_CHANNEL = '/event/FEC_Field_Deploy_Event__e';
const DEPLOY_TIMEOUT_MS = 120000;
const SEARCH_DEBOUNCE_MS = 300;

export default class FecAutoFieldCreator extends LightningElement {
    @api natureOfCaseId;
    @api stageId;
    @api recordId;

    labels = { LABEL_TITLE, LABEL_DEPLOY_IN_PROGRESS, LABEL_DEPLOY_SUCCESS, LABEL_DEPLOY_FAILED, LABEL_PUSH_TO_LIVE };
    fieldTypeOptions = FIELD_TYPES;

    // State machine
    currentStep = STEPS.SELECT_OBJECT;

    // Step 1: Select Object
    objectOptions = [];
    filteredObjectOptions = [];
    selectedObject = '';
    objectSearchTerm = '';
    _searchTimeout;

    // Step 2: Select/Create Field
    fieldMode = 'existing'; // 'existing' or 'new'
    fieldOptions = [];
    selectedField = '';
    fieldLabel = '';
    fieldApiName = '';
    fieldType = 'Text';
    fieldLength = 255;
    fieldDescription = '';
    picklistValues = '';
    relatedObject = '';
    apiNameError = '';
    fieldExistsError = '';

    // Step 3: Deploy
    deployRequestId;
    deployStatus = '';
    deployError = '';
    isDeploying = false;
    _subscription;
    _deployTimeout;

    // Step 4: Configure MDS
    sectionOptions = [];
    subSectionOptions = [];
    selectedSection = '';
    selectedSubSection = '';
    subSectionOrder = '';
    subSectionLayout = '';
    subSectionFieldLayout = '';
    fieldOrderDisplay = '';
    fieldStatus = true;
    fieldReadOnly = false;
    fieldMandatory = false;
    applicableRole = '';
    roleOptions = [];

    // Step 5: Review & Save
    savedRecordId;
    isPushing = false;
    pushStatus = '';

    // ── Getters for step visibility ──
    get isStepSelectObject() { return this.currentStep === STEPS.SELECT_OBJECT; }
    get isStepSelectField() { return this.currentStep === STEPS.SELECT_FIELD; }
    get isStepDeployField() { return this.currentStep === STEPS.DEPLOY_FIELD; }
    get isStepConfigureMDS() { return this.currentStep === STEPS.CONFIGURE_MDS; }
    get isStepReviewSave() { return this.currentStep === STEPS.REVIEW_SAVE; }

    get isNewField() { return this.fieldMode === 'new'; }
    get isExistingField() { return this.fieldMode === 'existing'; }
    get showPicklistValues() { return this.fieldType === 'Picklist'; }
    get showRelatedObject() { return this.fieldType === 'Lookup'; }
    get isNextDisabledStep1() { return !this.selectedObject; }
    get isNextDisabledStep2() {
        if (this.isExistingField) return !this.selectedField;
        return !(this.fieldLabel && this.fieldApiName && !this.apiNameError && !this.fieldExistsError);
    }
    get fieldModeOptions() {
        return [
            { label: 'Chọn field hiện có', value: 'existing' },
            { label: 'Tạo field mới', value: 'new' }
        ];
    }
    get stepIndicatorSteps() {
        return [
            { label: 'Select Object', value: STEPS.SELECT_OBJECT },
            { label: 'Select Field', value: STEPS.SELECT_FIELD },
            { label: 'Deploy', value: STEPS.DEPLOY_FIELD },
            { label: 'Configure MDS', value: STEPS.CONFIGURE_MDS },
            { label: 'Review & Save', value: STEPS.REVIEW_SAVE }
        ];
    }

    // ── Lifecycle ──
    connectedCallback() {
        this.loadObjects();
        this.registerEmpApiErrorListener();
    }

    disconnectedCallback() {
        this.unsubscribeFromDeployEvent();
        if (this._deployTimeout) clearTimeout(this._deployTimeout);
        if (this._searchTimeout) clearTimeout(this._searchTimeout);
    }

    // ── Step 1: Load objects ──
    loadObjects() {
        getGlobalObjectList()
            .then(result => {
                this.objectOptions = result;
                this.filteredObjectOptions = result;
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleObjectSearch(event) {
        const searchTerm = event.target.value;
        this.objectSearchTerm = searchTerm;
        if (this._searchTimeout) clearTimeout(this._searchTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimeout = setTimeout(() => {
            this.filterObjects(searchTerm);
        }, SEARCH_DEBOUNCE_MS);
    }

    filterObjects(searchTerm) {
        if (!searchTerm) {
            this.filteredObjectOptions = [...this.objectOptions];
            return;
        }
        const lower = searchTerm.toLowerCase();
        this.filteredObjectOptions = this.objectOptions.filter(
            opt => opt.label.toLowerCase().includes(lower) || opt.value.toLowerCase().includes(lower)
        );
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.loadFieldsForObject();
    }

    loadFieldsForObject() {
        if (!this.selectedObject) return;
        getObjectFields({ objectName: this.selectedObject })
            .then(result => {
                this.fieldOptions = result.map(f => ({
                    label: f.label + ' (' + f.value + ')',
                    value: f.value
                }));
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleNextFromStep1() {
        if (this.selectedObject) {
            this.currentStep = STEPS.SELECT_FIELD;
        }
    }

    // ── Step 2: Select/Create Field ──
    handleFieldModeChange(event) {
        this.fieldMode = event.detail.value;
        this.apiNameError = '';
        this.fieldExistsError = '';
    }

    handleExistingFieldChange(event) {
        this.selectedField = event.detail.value;
        const fieldInfo = this.fieldOptions.find(f => f.value === this.selectedField);
        if (fieldInfo) {
            this.fieldApiName = fieldInfo.value;
            this.fieldLabel = fieldInfo.label.split(' (')[0];
        }
    }

    handleFieldLabelChange(event) {
        this.fieldLabel = event.detail.value;
        this.autoGenerateApiName();
    }

    autoGenerateApiName() {
        if (!this.fieldLabel) {
            this.fieldApiName = '';
            return;
        }
        generateApiName({ fieldLabel: this.fieldLabel })
            .then(result => {
                this.fieldApiName = result;
                this.validateApiName();
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleFieldApiNameChange(event) {
        this.fieldApiName = event.detail.value;
        this.validateApiName();
    }

    validateApiName() {
        if (!this.fieldApiName) {
            this.apiNameError = '';
            return;
        }
        validateFieldApiName({ apiName: this.fieldApiName })
            .then(result => {
                this.apiNameError = result.isValid ? '' : result.errorMessage;
                if (result.isValid) {
                    this.checkDuplicateField();
                }
            })
            .catch(error => {
                this.showError(error);
            });
    }

    checkDuplicateField() {
        if (!this.selectedObject || !this.fieldApiName) return;
        checkFieldExists({ objectName: this.selectedObject, fieldApiName: this.fieldApiName })
            .then(exists => {
                this.fieldExistsError = exists ? LABEL_ERROR_FIELD_EXISTS : '';
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleFieldTypeChange(event) { this.fieldType = event.detail.value; }
    handleFieldLengthChange(event) { this.fieldLength = event.detail.value; }
    handleFieldDescriptionChange(event) { this.fieldDescription = event.detail.value; }
    handlePicklistValuesChange(event) { this.picklistValues = event.detail.value; }
    handleRelatedObjectChange(event) { this.relatedObject = event.detail.value; }

    handleNextFromStep2() {
        if (this.isNextDisabledStep2) return;
        if (this.isExistingField) {
            this.currentStep = STEPS.CONFIGURE_MDS;
            this.loadSections();
            this.loadRoles();
        } else {
            this.currentStep = STEPS.DEPLOY_FIELD;
        }
    }

    handleBackToStep1() {
        this.currentStep = STEPS.SELECT_OBJECT;
    }

    // ── Step 3: Deploy Field ──
    handleDeploy() {
        this.isDeploying = true;
        this.deployStatus = LABEL_DEPLOY_IN_PROGRESS;
        this.deployError = '';

        const fieldConfig = {
            objectName: this.selectedObject,
            fieldLabel: this.fieldLabel,
            fieldApiName: this.fieldApiName,
            fieldType: this.fieldType,
            length: this.fieldLength,
            description: this.fieldDescription,
            picklistValues: this.picklistValues,
            relatedObject: this.relatedObject
        };

        this.subscribeToDeployEvent();

        deployCustomField({ fieldConfig })
            .then(requestId => {
                this.deployRequestId = requestId;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                this._deployTimeout = setTimeout(() => {
                    this.handleDeployTimeout();
                }, DEPLOY_TIMEOUT_MS);
            })
            .catch(error => {
                this.isDeploying = false;
                this.deployStatus = LABEL_DEPLOY_FAILED;
                this.deployError = error.body?.message || error.message || 'Unknown error';
            });
    }

    subscribeToDeployEvent() {
        subscribe(DEPLOY_EVENT_CHANNEL, -1, (message) => {
            this.handleDeployEvent(message);
        }).then(subscription => {
            this._subscription = subscription;
        });
    }

    unsubscribeFromDeployEvent() {
        if (this._subscription) {
            unsubscribe(this._subscription);
            this._subscription = null;
        }
    }

    registerEmpApiErrorListener() {
        onError(error => {
            console.error('empApi error:', JSON.stringify(error));
        });
    }

    handleDeployEvent(message) {
        const payload = message.data.payload;
        if (payload.FEC_Request_Id__c !== this.deployRequestId) return;

        if (this._deployTimeout) clearTimeout(this._deployTimeout);
        this.unsubscribeFromDeployEvent();
        this.isDeploying = false;

        if (payload.FEC_Deploy_Status__c === 'Success') {
            this.deployStatus = LABEL_DEPLOY_SUCCESS;
            this.showToast('Success', LABEL_DEPLOY_SUCCESS, 'success');
            this.currentStep = STEPS.CONFIGURE_MDS;
            this.loadSections();
            this.loadRoles();
        } else {
            this.deployStatus = LABEL_DEPLOY_FAILED;
            this.deployError = payload.FEC_Error_Message__c || 'Deploy failed';
        }
    }

    handleDeployTimeout() {
        this.isDeploying = false;
        this.deployStatus = 'Timeout — checking status...';
        this.unsubscribeFromDeployEvent();

        getDeployRequestStatus({ requestId: this.deployRequestId })
            .then(result => {
                if (result.status === 'Success') {
                    this.deployStatus = LABEL_DEPLOY_SUCCESS;
                    this.currentStep = STEPS.CONFIGURE_MDS;
                    this.loadSections();
                    this.loadRoles();
                } else if (result.status === 'Failed') {
                    this.deployStatus = LABEL_DEPLOY_FAILED;
                    this.deployError = result.errorMessage || 'Deploy failed';
                } else {
                    this.deployStatus = 'Deploy is still in progress. Please check Field Deploy Requests.';
                }
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleRetryDeploy() {
        this.handleDeploy();
    }

    handleBackToStep2() {
        this.currentStep = STEPS.SELECT_FIELD;
        this.unsubscribeFromDeployEvent();
        if (this._deployTimeout) clearTimeout(this._deployTimeout);
    }

    // ── Step 4: Configure MDS ──
    loadSections() {
        if (!this.natureOfCaseId || !this.stageId) return;
        getDistinctSections({ natureOfCaseId: this.natureOfCaseId, stageId: this.stageId })
            .then(result => {
                this.sectionOptions = result.map(s => ({ label: s, value: s }));
            })
            .catch(error => {
                this.showError(error);
            });
    }

    loadRoles() {
        getUserRoles()
            .then(result => {
                this.roleOptions = result.map(r => ({ label: r.label, value: r.value }));
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleSectionChange(event) {
        this.selectedSection = event.detail.value;
        this.loadSubSections();
    }

    loadSubSections() {
        if (!this.natureOfCaseId || !this.stageId || !this.selectedSection) return;
        getDistinctSubSections({
            natureOfCaseId: this.natureOfCaseId,
            stageId: this.stageId,
            section: this.selectedSection
        })
            .then(result => {
                this.subSectionOptions = result.map(ss => ({
                    label: ss.subSection,
                    value: ss.subSection
                }));
                // Auto-fill defaults if available
                if (result.length > 0) {
                    const first = result[0];
                    this.subSectionOrder = first.subSectionOrder || '';
                    this.subSectionLayout = first.subSectionLayout || '';
                    this.subSectionFieldLayout = first.subSectionFieldLayout || '';
                }
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handleSubSectionChange(event) {
        this.selectedSubSection = event.detail.value;
    }
    handleSubSectionOrderChange(event) { this.subSectionOrder = event.detail.value; }
    handleSubSectionLayoutChange(event) { this.subSectionLayout = event.detail.value; }
    handleSubSectionFieldLayoutChange(event) { this.subSectionFieldLayout = event.detail.value; }
    handleFieldOrderChange(event) { this.fieldOrderDisplay = event.detail.value; }
    handleFieldStatusChange(event) { this.fieldStatus = event.detail.checked; }
    handleFieldReadOnlyChange(event) { this.fieldReadOnly = event.detail.checked; }
    handleFieldMandatoryChange(event) { this.fieldMandatory = event.detail.checked; }
    handleApplicableRoleChange(event) { this.applicableRole = event.detail.value; }

    handleNextFromStep4() {
        this.currentStep = STEPS.REVIEW_SAVE;
    }

    handleBackToStep3or2() {
        this.currentStep = this.isNewField ? STEPS.DEPLOY_FIELD : STEPS.SELECT_FIELD;
    }

    // ── Step 5: Review & Save ──
    handleSave() {
        const mappingReq = {
            'FEC_Nature_Of_Case__c': this.natureOfCaseId,
            'FEC_Stage_Name__c': this.stageId,
            'FEC_Field_Object_Name__c': this.selectedObject,
            'FEC_Field_API_Name__c': this.fieldApiName,
            'FEC_Field_Label_Name__c': this.fieldLabel,
            'FEC_Section__c': this.selectedSection,
            'FEC_Sub_Section__c': this.selectedSubSection,
            'FEC_Sub_Section_Order__c': this.subSectionOrder || null,
            'FEC_Sub_Section_Layout__c': this.subSectionLayout || null,
            'FEC_Sub_Section_Field_Layout__c': this.subSectionFieldLayout || null,
            'FEC_Field_Order_Display__c': this.fieldOrderDisplay || null,
            'FEC_Field_Status__c': this.fieldStatus,
            'FEC_Field_ReadOnly__c': this.fieldReadOnly,
            'FEC_Field_Mandatory__c': this.fieldMandatory,
            'FEC_Applicable_Role__c': Array.isArray(this.applicableRole) ? this.applicableRole.join(';') : this.applicableRole
        };

        saveMasterDataSetting({ mappingReq })
            .then(result => {
                this.savedRecordId = result;
                this.showToast('Success', 'MDS record created successfully', 'success');
            })
            .catch(error => {
                this.showError(error);
            });
    }

    handlePushToLive() {
        this.isPushing = true;
        this.pushStatus = 'Đang đồng bộ...';

        executePushToLive()
            .then(() => {
                this.isPushing = false;
                this.pushStatus = 'Đã đồng bộ';
                this.showToast('Success', 'Push to Live completed', 'success');
                this.dispatchEvent(new CustomEvent('success', { detail: { recordId: this.savedRecordId } }));
            })
            .catch(error => {
                this.isPushing = false;
                this.pushStatus = '';
                this.showError(error);
            });
    }

    handleFinish() {
        this.dispatchEvent(new CustomEvent('success', { detail: { recordId: this.savedRecordId } }));
    }

    handleBackToStep4() {
        this.currentStep = STEPS.CONFIGURE_MDS;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // ── Utilities ──
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(error) {
        const message = error.body?.message || error.message || 'Unknown error';
        this.showToast('Error', message, 'error');
    }
}