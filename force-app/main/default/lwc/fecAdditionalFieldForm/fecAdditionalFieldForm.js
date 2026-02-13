import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Custom Labels (use label names created in org: c.FEC_Cancel, c.FEC_Cancel_Title, etc.)
import LABEL_CANCEL from '@salesforce/label/c.FEC_Cancel';
import LABEL_CANCEL_TITLE from '@salesforce/label/c.FEC_Cancel_Title';
import LABEL_SAVE from '@salesforce/label/c.FEC_Save';
import LABEL_SAVE_TITLE from '@salesforce/label/c.FEC_Save_Title';
import LABEL_SUCCESS_TITLE from '@salesforce/label/c.FEC_Success_Title';
import LABEL_SAVE_SUCCESS_MSG from '@salesforce/label/c.FEC_Save_Success_Message';
import LABEL_ERROR_TITLE from '@salesforce/label/c.FEC_Error_Title';

// Shared constants
import { OBJECT_MDM_ADDITIONAL_FIELD, FIELD_FEC_UNIQUE_ID, FIELD_NAME, FIELD_NAME_VN, FIELD_FEC_TYPE, FIELD_FIELD_STATUS, FIELD_FIELD_MANDATORY } from 'c/fecConstants';

/**
 * FecAdditionalFieldForm
 * Handles add/edit form for FEC_MDM_Additional_Field__c
 */
export default class FecAdditionalFieldForm extends LightningElement {
    /** Record Id for edit mode, null for new mode */
    @api recordId;

    // Object and Field constants (use in template bindings)
    // Expose shared constants to template
    OBJECT_API_NAME = OBJECT_MDM_ADDITIONAL_FIELD;
    FIELD_FEC_UNIQUE_ID = FIELD_FEC_UNIQUE_ID;
    FIELD_NAME = FIELD_NAME;
    FIELD_NAME_VN = FIELD_NAME_VN;
    FIELD_FEC_TYPE = FIELD_FEC_TYPE;
    FIELD_FIELD_STATUS = FIELD_FIELD_STATUS;
    FIELD_FIELD_MANDATORY = FIELD_FIELD_MANDATORY;

    /** True if in new mode (no recordId) */
    get isNewMode() {
        return !this.recordId;
    }

    /** True if in edit mode (has recordId) */
    get isEditMode() {
        return !!this.recordId;
    }

    // Localized labels using Custom Labels (platform handles translations)
    get labelCancel() {
        return LABEL_CANCEL;
    }
    get titleCancel() {
        return LABEL_CANCEL_TITLE;
    }
    get labelSave() {
        return LABEL_SAVE;
    }
    get titleSave() {
        return LABEL_SAVE_TITLE;
    }

    /**
     * Handle successful save
     * @param {Event} event
     */
    handleSuccess(event) {
        const evt = new ShowToastEvent({
            title: LABEL_SUCCESS_TITLE,
            message: LABEL_SAVE_SUCCESS_MSG,
            variant: 'success'
        });
        this.dispatchEvent(evt);
        this.dispatchEvent(new CustomEvent('success', { detail: event.detail }));
    }

    /**
     * Handle form error
     * @param {Event} event
     */
    handleError(event) {
        const errMsg = (event.detail && event.detail.detail) ? event.detail.detail : JSON.stringify(event.detail);
        const evt = new ShowToastEvent({
            title: LABEL_ERROR_TITLE,
            message: errMsg,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    }

    /**
     * Handle cancel button click
     */
    handleCancel() {
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) form.reset();
        // Dispatch event so parent can close modal
        this.dispatchEvent(new CustomEvent('cancel'));
    }
}