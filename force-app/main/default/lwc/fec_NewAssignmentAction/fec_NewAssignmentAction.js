import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import getGeneralAssignmentNames from '@salesforce/apex/FEC_NewAssignmentController.getGeneralAssignmentNames';
import createAssignment from '@salesforce/apex/FEC_NewAssignmentController.createAssignment';
import ASSIGNMENT_OBJECT from '@salesforce/schema/FEC_Assignment__c';
import ASSIGNMENT_TYPE_FIELD from '@salesforce/schema/FEC_Assignment__c.FEC_Assignment_Type__c';
import ASSIGNMENT_STATUS_FIELD from '@salesforce/schema/FEC_Assignment__c.FEC_Assignment_Status__c';
import { ASSIGNMENT_TYPE_CALL, ASSIGNMENT_TYPE_GENERAL, ASSIGNMENT_TYPE_ROUTING } from 'c/fec_CommonConst';
import LABEL_CALL_NAME from '@salesforce/label/c.FEC_NEW_ASSIGNMENT_CALL_NAME';
import LABEL_ERR_TYPE from '@salesforce/label/c.FEC_NEW_ASSIGNMENT_ERR_TYPE_REQUIRED';
import LABEL_ERR_NAME from '@salesforce/label/c.FEC_NEW_ASSIGNMENT_ERR_NAME_REQUIRED';
import LABEL_SUCCESS_TITLE from '@salesforce/label/c.FEC_Assignment_List';
import LABEL_SUCCESS_MSG from '@salesforce/label/c.FEC_NEW_ASSIGNMENT_SUCCESS_MSG';
import LABEL_ERR_CREATE from '@salesforce/label/c.FEC_NEW_ASSIGNMENT_ERR_CREATE';

export default class Fec_NewAssignmentAction extends LightningElement {
    @api recordId;
    @track assignmentType = '';
    @track assignmentStatus = 'Open';
    @track assignmentName = '';
    @track errorMsg = '';
    @track isSaving = false;
    @track _generalNameOptions = [];

    _objectInfo;
    _typeOptions = [];
    _statusOptions = [];

    @wire(getObjectInfo, { objectApiName: ASSIGNMENT_OBJECT })
    wiredObjectInfo({ data }) {
        if (data) this._objectInfo = data;
    }

    @wire(getPicklistValues, { recordTypeId: '$_defaultRecordTypeId', fieldApiName: ASSIGNMENT_TYPE_FIELD })
    wiredType({ data }) {
        if (data) this._typeOptions = data.values.map(v => ({ label: v.label, value: v.value }));
    }

    @wire(getPicklistValues, { recordTypeId: '$_defaultRecordTypeId', fieldApiName: ASSIGNMENT_STATUS_FIELD })
    wiredStatus({ data }) {
        if (data) this._statusOptions = data.values.map(v => ({ label: v.label, value: v.value }));
    }

    get _defaultRecordTypeId() {
        return this._objectInfo?.defaultRecordTypeId;
    }

    get assignmentTypeOptions() {
        return this._typeOptions.filter(opt => opt.value !== ASSIGNMENT_TYPE_ROUTING);
    }

    get assignmentStatusOptions() {
        return this._statusOptions.length ? this._statusOptions : [{ label: 'Open', value: 'Open' }];
    }

    get assignmentNameOptions() {
        if (this.assignmentType === ASSIGNMENT_TYPE_CALL) {
            return [{ label: LABEL_CALL_NAME, value: LABEL_CALL_NAME }];
        }
        if (this.assignmentType === ASSIGNMENT_TYPE_GENERAL) {
            return this._generalNameOptions;
        }
        return [];
    }

    get isCallType() {
        return this.assignmentType === ASSIGNMENT_TYPE_CALL;
    }

    get isNameDisabled() {
        return this.assignmentType === ASSIGNMENT_TYPE_CALL || !this.assignmentType;
    }

    handleTypeChange(e) {
        this.assignmentType = e.detail.value;
        this.assignmentName = '';
        this.errorMsg = '';

        if (this.assignmentType === ASSIGNMENT_TYPE_CALL) {
            this.assignmentName = LABEL_CALL_NAME;
        } else if (this.assignmentType === ASSIGNMENT_TYPE_GENERAL) {
            getGeneralAssignmentNames({ caseId: this.recordId })
                .then(result => {
                    this._generalNameOptions = result.map(r => ({ label: r.label, value: r.value }));
                })
                .catch(() => {
                    this._generalNameOptions = [];
                });
        }
    }

    handleStatusChange(e) { this.assignmentStatus = e.detail.value; }
    handleNameChange(e) { this.assignmentName = e.detail.value; }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        this.errorMsg = '';
        if (!this.assignmentType) { this.errorMsg = LABEL_ERR_TYPE; return; }
        if (!this.assignmentName) { this.errorMsg = LABEL_ERR_NAME; return; }

        this.isSaving = true;

        createAssignment({
            caseId: this.recordId,
            assignmentType: this.assignmentType,
            assignmentStatus: this.assignmentStatus,
            assignmentName: this.assignmentName
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: LABEL_SUCCESS_TITLE, message: LABEL_SUCCESS_MSG, variant: 'success' }));
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(e => {
                this.errorMsg = e?.body?.message || LABEL_ERR_CREATE;
                this.isSaving = false;
            });
    }
}
