import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { subscribe, MessageContext } from 'lightning/messageService';
import { loadStyle } from 'lightning/platformResourceLoader';
import FEC_GA_EDIT_MODE from '@salesforce/messageChannel/FEC_GA_Edit_Mode__c';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';
import LABEL_SUCCESS from '@salesforce/label/c.FEC_GA_Save_Success';
import LABEL_SAVED from '@salesforce/label/c.FEC_GA_Saved_Message';
import LABEL_ERROR from '@salesforce/label/c.FEC_GA_Save_Error';
import LABEL_SAVE_ERROR from '@salesforce/label/c.FEC_GA_Save_Error_Message';

const FIELDS = [
    'FEC_General_Assignment__c.FEC_General_Assignment_Name__c',
    'FEC_General_Assignment__c.FEC_General_Assignment_Code__c',
    'FEC_General_Assignment__c.FEC_Active__c'
];

export default class Fec_GeneralAssignmentDetail extends LightningElement {
    @api recordId;
    @api startInEditMode = false;
    @track isEditMode = false;
    @track record = {};
    @wire(MessageContext) messageContext;

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
        subscribe(this.messageContext, FEC_GA_EDIT_MODE, (msg) => {
            if (msg.recordId === this.recordId) {
                this.isEditMode = true;
            }
        });
        if (this.startInEditMode) this.isEditMode = true;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) {
            this.record = {
                FEC_General_Assignment_Name__c: data.fields.FEC_General_Assignment_Name__c?.value,
                FEC_General_Assignment_Code__c: data.fields.FEC_General_Assignment_Code__c?.value,
                FEC_Active__c: data.fields.FEC_Active__c?.value
            };
        }
    }

    handleCancel() { this.isEditMode = false; }

    handleSubmit(event) {
        event.preventDefault();
        this.template.querySelector('lightning-record-edit-form').submit(event.detail.fields);
    }

    handleSuccess() {
        this.isEditMode = false;
        getRecordNotifyChange([{ recordId: this.recordId }]);
        this.dispatchEvent(new ShowToastEvent({ title: LABEL_SUCCESS, message: LABEL_SAVED, variant: 'success' }));
    }

    handleError(event) {
        this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: event.detail?.detail || LABEL_SAVE_ERROR, variant: 'error' }));
    }
}

