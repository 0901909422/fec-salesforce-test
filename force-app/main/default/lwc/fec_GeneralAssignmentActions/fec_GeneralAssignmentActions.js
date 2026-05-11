import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { deleteRecord, getRecord } from 'lightning/uiRecordApi';
import { publish, MessageContext } from 'lightning/messageService';
import { loadStyle } from 'lightning/platformResourceLoader';
import FEC_GA_EDIT_MODE from '@salesforce/messageChannel/FEC_GA_Edit_Mode__c';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';

import FEC_BUTTON_EDIT from '@salesforce/label/c.FEC_Action_Edit';
import FEC_CONFIRM_DELETE_MESSAGE from '@salesforce/label/c.FEC_Confirm_Delete_Message';
import FEC_CONFIRM_DELETE_TITLE from '@salesforce/label/c.FEC_Confirm_Delete_Title';
import FEC_BUTTON_DELETE from '@salesforce/label/c.FEC_Button_Delete';
import FEC_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import FEC_BUTTON_CONFIRM from '@salesforce/label/c.FEC_Button_Confirm';
import LABEL_SUCCESS from '@salesforce/label/c.FEC_GA_Save_Success';
import LABEL_DELETED from '@salesforce/label/c.FEC_GA_Delete_Success_Message';
import LABEL_DELETE_ERROR from '@salesforce/label/c.FEC_GA_Delete_Error_Message';
import LABEL_ERROR from '@salesforce/label/c.FEC_GA_Save_Error';

const FIELDS = ['FEC_General_Assignment__c.Name'];

export default class Fec_GeneralAssignmentActions extends NavigationMixin(LightningElement) {
    @api recordId;
    @wire(MessageContext) messageContext;

    labels = {
        edit: FEC_BUTTON_EDIT,
        confirmDeleteMessage: FEC_CONFIRM_DELETE_MESSAGE,
        confirmDeleteTitle: FEC_CONFIRM_DELETE_TITLE,
        delete: FEC_BUTTON_DELETE,
        cancel: FEC_BUTTON_CANCEL,
        confirm: FEC_BUTTON_CONFIRM
    };

    recordName;
    objectLabel = 'General Assignment';
    objectIconName = 'custom:custom70';
    showDeleteModal = false;

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) this.recordName = data.fields.Name?.value;
    }

    handleEdit() {
        publish(this.messageContext, FEC_GA_EDIT_MODE, { recordId: this.recordId });
    }

    handleDelete() {
        this.showDeleteModal = true;
    }

    closeDeleteModal() {
        this.showDeleteModal = false;
    }

    async confirmDelete() {
        this.showDeleteModal = false;
        try {
            await deleteRecord(this.recordId);
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_SUCCESS, message: LABEL_DELETED, variant: 'success' }));
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'FEC_General_Assignment__c', actionName: 'list' },
                state: { filterName: 'All' }
            });
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: e?.body?.message || LABEL_DELETE_ERROR, variant: 'error' }));
        }
    }
}
