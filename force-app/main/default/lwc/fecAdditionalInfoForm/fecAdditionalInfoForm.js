import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import LABEL_CANCEL from '@salesforce/label/c.FEC_Cancel';
import LABEL_SAVE from '@salesforce/label/c.FEC_Save';
import LABEL_ERROR_TITLE from '@salesforce/label/c.FEC_Error_Title';

export default class FecAdditionalInfoForm extends LightningElement {
    @api recordId;

    objectApiName = 'FEC_Additional_Info__c';

    get isNewMode() {
        return !this.recordId;
    }

    get isEditMode() {
        return !!this.recordId;
    }

    get labelCancel() {
        return LABEL_CANCEL;
    }

    get labelSave() {
        return LABEL_SAVE;
    }

    handleSuccess() {
        this.dispatchEvent(new CustomEvent('success'));
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel', {
            bubbles: true,
            composed: true
        }));
    }

    handleError(event) {
        event.preventDefault();
        event.stopPropagation();

        let errMsg = 'An error occurred. Please try again.';
        if (event.detail && event.detail.detail) {
            errMsg = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errMsg = event.detail.message;
        }

        this.dispatchEvent(new ShowToastEvent({
            title: LABEL_ERROR_TITLE,
            message: errMsg,
            variant: 'error',
            mode: 'dismissable'
        }));
    }
}