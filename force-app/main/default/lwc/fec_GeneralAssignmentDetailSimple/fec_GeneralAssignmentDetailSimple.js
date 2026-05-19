// tungnm37: Detail + Edit form cho FEC_General_Assignment__c (Name, Code, Active)
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
import LABEL_DETAIL_INFO from '@salesforce/label/c.FEC_Label_Detail_Information';
import LABEL_GA_NAME from '@salesforce/label/c.FEC_Label_GA_Name';
import LABEL_GA_CODE from '@salesforce/label/c.FEC_Label_GA_Code';
import LABEL_ACTIVE from '@salesforce/label/c.FEC_Label_Active';
import LABEL_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_SAVE from '@salesforce/label/c.FEC_Button_Save';
import updateGeneralAssignment from '@salesforce/apex/FEC_GeneralAssignmentController.updateGeneralAssignment';

const FIELDS = [
    'FEC_General_Assignment__c.Name',
    'FEC_General_Assignment__c.FEC_General_Assignment_Name__c',
    'FEC_General_Assignment__c.FEC_General_Assignment_Code__c',
    'FEC_General_Assignment__c.FEC_Active__c'
];

export default class Fec_GeneralAssignmentDetailSimple extends LightningElement {
    @api recordId;
    @track isEditMode = false;
    @track record = {};
    @track editName = '';
    @track editCode = '';
    @track editActive = false;
    @wire(MessageContext) messageContext;

    labels = {
        detailInfo: LABEL_DETAIL_INFO,
        gaName: LABEL_GA_NAME,
        gaCode: LABEL_GA_CODE,
        active: LABEL_ACTIVE,
        cancel: LABEL_CANCEL,
        save: LABEL_SAVE
    };

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
        subscribe(this.messageContext, FEC_GA_EDIT_MODE, (msg) => {
            if (msg.recordId === this.recordId) {
                this._enterEditMode();
            }
        });
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) {
            this.record = {
                Name: data.fields.Name?.value,
                FEC_General_Assignment_Name__c: data.fields.FEC_General_Assignment_Name__c?.value,
                FEC_General_Assignment_Code__c: data.fields.FEC_General_Assignment_Code__c?.value,
                FEC_Active__c: data.fields.FEC_Active__c?.value
            };
        }
    }

    _enterEditMode() {
        this.isEditMode = true;
        this.editName = this.record.FEC_General_Assignment_Name__c || '';
        this.editCode = this.record.FEC_General_Assignment_Code__c || '';
        this.editActive = this.record.FEC_Active__c || false;
    }

    handleNameChange(e) { this.editName = e.target.value; }
    handleCodeChange(e) { this.editCode = e.target.value; }
    handleActiveChange(e) { this.editActive = e.target.checked; }

    handleCancel() { this.isEditMode = false; }

    handleSave() {
        updateGeneralAssignment({
            recordId: this.recordId,
            customerType: null,
            channelIds: null,
            generalAssignmentName: this.editName,
            generalAssignmentCode: this.editCode,
            active: this.editActive
        })
        .then(() => {
            this.isEditMode = false;
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_SUCCESS, message: LABEL_SAVED, variant: 'success' }));
        })
        .catch(err => {
            const msg = err?.body?.message || LABEL_SAVE_ERROR;
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: msg, variant: 'error' }));
        });
    }
}
