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

    /** Default status to true for new records */
    get fieldStatusValue() {
        return this.isNewMode ? true : undefined;
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
     * Utility method for logging
     */
    showLog(methodName, message) {
        console.log(`[${methodName}] ${message}`);
    }

    /**
     * Handle form submission to validate inputs before saving to server
     * @param {Event} event 
     */
    handleSubmit(event) {
        event.preventDefault(); // Chặn hành vi submit mặc định
        this.showLog('handleSubmit', 'START');

        const fields = event.detail.fields;
        let isValid = true;

        // Xác định các trường bắt buộc cần kiểm tra (Dùng constant đã import)
        const requiredFields = [this.FIELD_NAME, this.FIELD_NAME_VN, this.FIELD_FEC_TYPE];

        // FEC_Unique_ID chỉ là input bắt buộc ở mode tạo mới
        if (this.isNewMode) {
            requiredFields.push(this.FIELD_FEC_UNIQUE_ID);
        }

        // Kiểm tra khoảng trắng và làm sạch dữ liệu
        for (let fieldName of requiredFields) {
            let fieldValue = fields[fieldName];
            
            if (fieldValue && fieldValue.trim() === '') {
                isValid = false;
                break;
            }
            
            // Xóa khoảng trắng thừa 2 đầu để data lưu vào Database được sạch
            if (fieldValue) {
                fields[fieldName] = fieldValue.trim();
            }
        }

        // Xử lý kết quả validation
        if (!isValid) {
            this.showLog('handleSubmit', 'RETURN: Validation Failed (Only spaces entered)');
            this.dispatchEvent(new ShowToastEvent({
                title: LABEL_ERROR_TITLE,
                message: 'Các trường bắt buộc không được để trống hoặc chỉ chứa khoảng trắng.',
                variant: 'error',
                mode: 'dismissable'
            }));
            return;
        }

        this.showLog('handleSubmit', 'RETURN: Validation Passed. Submitting to Salesforce.');
        
        // Submit thủ công sau khi đã kiểm tra xong
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    /**
     * Handle successful save
     * @param {Event} event
     */
    handleSuccess(event) {
        this.dispatchEvent(new CustomEvent('success', { detail: event.detail }));
    }

    /**
     * Handle form error
     * @param {Event} event
     */
    handleError(event) {
        event.preventDefault();
        event.stopPropagation();
        
        // Extract the most concise error message
        let errMsg = 'An error occurred. Please try again.';
        if (event.detail && event.detail.detail) {
            errMsg = event.detail.detail;
            
            // Xử lý lỗi trùng lặp FEC Unique ID cho thân thiện với người dùng
            if (errMsg.includes('FEC_Unique_ID__c') && errMsg.includes('duplicate')) {
                errMsg = 'Mã FEC Unique ID này đã tồn tại trong hệ thống. Vui lòng kiểm tra lại.';
            }
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

    /**
     * Handle cancel button click
     */
    handleCancel() {
        // Dispatch event so parent can close modal
        this.dispatchEvent(new CustomEvent('cancel', { 
            bubbles: true, 
            composed: true,
            detail: {}
        }));
    }
}