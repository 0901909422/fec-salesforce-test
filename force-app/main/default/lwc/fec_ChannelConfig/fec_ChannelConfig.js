// tungnm37: Channel Config tab - view/edit mode với 3 checkbox
import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import FEC_Toast_Success from '@salesforce/label/c.FEC_Toast_Success';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Channel_Config_Save_Success from '@salesforce/label/c.FEC_Channel_Config_Save_Success';
import FEC_Channel_Config_Save_Error from '@salesforce/label/c.FEC_Channel_Config_Save_Error';
import FEC_Button_Cancel from '@salesforce/label/c.FEC_Button_Cancel';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_Label_Get_Nature_Of_Case from '@salesforce/label/c.FEC_Label_Get_Nature_Of_Case';
import FEC_Label_Cancel_Case from '@salesforce/label/c.FEC_Label_Cancel_Case';
import FEC_Label_Update_Case_Status from '@salesforce/label/c.FEC_Label_Update_Case_Status';

const FIELDS = [
    'FEC_Channel__c.FEC_Get_Nature_Of_Case__c',
    'FEC_Channel__c.FEC_Cancel_Case__c',
    'FEC_Channel__c.FEC_Update_Case_Status__c'
];

export default class Fec_ChannelConfig extends LightningElement {
    @api recordId;
    @track isSaving = false;
    @track isEditMode = false;

    labelGetNatureOfCase = FEC_Label_Get_Nature_Of_Case;
    labelCancelCase = FEC_Label_Cancel_Case;
    labelUpdateCaseStatus = FEC_Label_Update_Case_Status;
    labelCancel = FEC_Button_Cancel;
    labelSave = FEC_Button_Save;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    record;

    get getNatureOfCase() {
        return this.record?.data?.fields?.FEC_Get_Nature_Of_Case__c?.value;
    }
    get cancelCase() {
        return this.record?.data?.fields?.FEC_Cancel_Case__c?.value;
    }
    get updateCaseStatus() {
        return this.record?.data?.fields?.FEC_Update_Case_Status__c?.value;
    }

    get getNatureOfCaseIcon() {
        return this.getNatureOfCase ? 'utility:check' : 'utility:close';
    }
    get cancelCaseIcon() {
        return this.cancelCase ? 'utility:check' : 'utility:close';
    }
    get updateCaseStatusIcon() {
        return this.updateCaseStatus ? 'utility:check' : 'utility:close';
    }

    handleEdit() {
        this.isEditMode = true;
    }

    handleSubmit(event) {
        event.preventDefault();
        this.isSaving = true;
        const fields = event.detail.fields;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess() {
        this.isSaving = false;
        this.isEditMode = false;
        getRecordNotifyChange([{ recordId: this.recordId }]);
        this.dispatchEvent(new ShowToastEvent({
            title: FEC_Toast_Success,
            message: FEC_Channel_Config_Save_Success,
            variant: 'success'
        }));
    }

    handleError(event) {
        this.isSaving = false;
        const msg = event.detail?.detail || FEC_Channel_Config_Save_Error;
        this.dispatchEvent(new ShowToastEvent({
            title: FEC_Toast_Error,
            message: msg,
            variant: 'error'
        }));
    }

    handleCancel() {
        this.isEditMode = false;
        this.template.querySelectorAll('lightning-input-field').forEach(f => f.reset());
    }
}
