import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

// Import Object References
import USER_OBJ from '@salesforce/schema/User';
import CASE_OBJ from '@salesforce/schema/Case';
import ADDITIONAL_INFO_OBJ from '@salesforce/schema/FEC_Additional_Info__c';
import CUSTOMER_HISTORY_OBJ from '@salesforce/schema/FEC_Customer_History__c';
import insertMegeLabel from '@salesforce/label/c.FEC_Insert_Merge_Field';
import accountLabel from '@salesforce/label/c.FEC_Object_Account';
import caseLabel from '@salesforce/label/c.FEC_Object_Case';
import userLabel from '@salesforce/label/c.FEC_Object_User';
import senderLabel from '@salesforce/label/c.FEC_Sender';

import additionalInfoLabel from '@salesforce/label/c.FEC_Object_Additional_Info';
import customerHistoryLabel from '@salesforce/label/c.FEC_Object_Customer_History';
import selectMergeFieldLabel from '@salesforce/label/c.FEC_Select_Merge_Field';
import cancelLabel from '@salesforce/label/c.FEC_Merge_Field_Cancel';
import insertLabel from '@salesforce/label/c.FEC_Merge_Field_Insert';
import placeholderLabel from '@salesforce/label/c.FEC_Merge_Field_Placeholder';

export default class Fec_MergeFieldPicker extends LightningElement {
    @track selectedObject = 'User';
    @track searchQuery = '';
    @track selectedField = '';
    @track isInsertDisabled = true;

    labels = {
        insertMegeLabel,
        accountLabel,
        caseLabel,
        userLabel,
        selectMergeFieldLabel,
        cancelLabel,
        insertLabel,
        placeholderLabel,
        additionalInfoLabel,
        customerHistoryLabel,
        senderLabel
    }

    // Store raw field data from wires
    additionalInfoFields = [];
    customerHistoryFields = [];
    caseFields = [];
    userFields = [];

    // Static Object Navigation
    @track objects = [
        { label: this.labels.senderLabel, value: 'User', className: 'slds-vertical-tabs__nav-item slds-is-active' },
        { label: this.labels.caseLabel, value: 'Case', className: 'slds-vertical-tabs__nav-item' },
        { label: this.labels.additionalInfoLabel, value: 'FEC_Additional_Info__c', className: 'slds-vertical-tabs__nav-item' },
        { label: this.labels.customerHistoryLabel, value: 'FEC_Customer_History__c', className: 'slds-vertical-tabs__nav-item' }
    ];

    // --- Wire Adapters ---
    @wire(getObjectInfo, { objectApiName: USER_OBJ })
    wiredUser({ data }) {
        if (data) this.userFields = this.formatFields(data.fields);
    }

    @wire(getObjectInfo, { objectApiName: CASE_OBJ })
    wiredCase({ data }) {
        if (data) this.caseFields = this.formatFields(data.fields);
    }

    @wire(getObjectInfo, { objectApiName: ADDITIONAL_INFO_OBJ })
    wiredAdditionalInfo({ data }) {
        if (data) {
            this.additionalInfoFields = this.formatFields(data.fields);
            console.log('this.data:', data);
            console.log('this.additionalInfoFields:', this.additionalInfoFields);
        }
    }

    @wire(getObjectInfo, { objectApiName: CUSTOMER_HISTORY_OBJ })
    wiredCustomerHistory({ data }) {
        if (data) {
            this.customerHistoryFields = this.formatFields(data.fields);
            console.log('this.data:', data);
            console.log('this.accountFields:', this.customerHistoryFields);
        }
    }

    // Helper to transform field map into sorted array
    formatFields(fieldsMap) {
        return Object.values(fieldsMap)
            .map(f => ({ label: f.label, value: f.apiName }))
            .sort((a, b) => a.label.localeCompare(b.label));
    }

    // --- Getters & Logic ---
    get currentFields() {
        if (this.selectedObject === 'User') {
            return this.userFields;
        } else if (this.selectedObject === 'Case') {
            return this.caseFields;
        } else if (this.selectedObject === 'FEC_Additional_Info__c') {
            return this.additionalInfoFields;
        } else  if (this.selectedObject === 'FEC_Customer_History__c') {
            return this.customerHistoryFields;
        }
        return this.userFields;
    }

    get filteredFields() {
        if (!this.searchQuery) return this.currentFields;
        return this.currentFields.filter(f => 
            f.label.toLowerCase().includes(this.searchQuery.toLowerCase())
        );
    }

    handleObjectSelect(event) {
        // 'name' corresponds to the name attribute in lightning-vertical-navigation-item
        this.selectedObject = event.detail.name; 
        console.log('this.selectedObject:', this.selectedObject);
        this.selectedField = ''; 
        this.searchQuery = '';
    }

    handleSearch(event) {
        this.searchQuery = event.target.value;
    }

    handleFieldChange(event) {
        this.selectedField = event.target.value;
        console.log('this.selectedField:', this.selectedField);
        this.isInsertDisabled = false;
    }

    handleInsert() {
        // Formats the merge field tag for the editor
        const mergeTag = `{{{${this.selectedObject}.${this.selectedField}}}}`;
        console.log('Inserting merge field:', mergeTag);
        this.dispatchEvent(new CustomEvent('insert', { detail: mergeTag }));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}