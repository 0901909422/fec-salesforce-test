import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Custom Labels (use label names created in org: c.FEC_Cancel, c.FEC_Cancel_Title, etc.)
import LABEL_CANCEL from '@salesforce/label/c.FEC_Cancel';
import LABEL_CANCEL_TITLE from '@salesforce/label/c.FEC_Cancel_Title';
import LABEL_SAVE from '@salesforce/label/c.FEC_Save';
import LABEL_SAVE_TITLE from '@salesforce/label/c.FEC_Save_Title';
import LABEL_SUCCESS_TITLE from '@salesforce/label/c.FEC_Success_Title';
import LABEL_SAVE_SUCCESS_MSG from '@salesforce/label/c.FEC_Save_Success_Message';
import LABEL_ERROR_TITLE from '@salesforce/label/c.FEC_Error_Title';
import LABEL_ERROR_SPECIAL_CHARS_ID from '@salesforce/label/c.FEC_Error_Special_Characters_ID';
import LABEL_ERROR_REQUIRED_EMPTY from '@salesforce/label/c.FEC_Error_Required_Fields_Empty';

// Shared constants
import { OBJECT_MDM_ADDITIONAL_FIELD, FIELD_FEC_UNIQUE_ID, FIELD_NAME, FIELD_NAME_VN, FIELD_FEC_TYPE, FIELD_FIELD_STATUS, FIELD_FIELD_MANDATORY } from 'c/fecConstants';

// Apex for save with list values
import savePropertyWithListValues from '@salesforce/apex/FEC_AdditionalFieldController.savePropertyWithListValues';
import getFieldListValuesFresh from '@salesforce/apex/FEC_AdditionalFieldController.getFieldListValuesFresh';

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

    // Inline List Values state
    listValueRows = [];
    listValueErrors = [];
    selectedType = '';
    _rowCounter = 0;
    _existingListValuesLoaded = false;

    get showListValues() {
        return this.selectedType === 'List';
    }

    get hasListValueRows() {
        return this.listValueRows.length > 0;
    }

    get hasListValueErrors() {
        return this.listValueErrors.length > 0;
    }

    /**
     * Handle Type picklist change — show/hide List Values section in real-time.
     * When switching away from "List", clear all list value rows.
     */
    handleTypeChange(event) {
        const newType = event.detail.value;
        if (newType !== this.selectedType) {
            this.selectedType = newType;
            // Switching away from List → clear rows
            if (newType !== 'List') {
                this.listValueRows = [];
                this.listValueErrors = [];
                this._existingListValuesLoaded = false;
            } else if (this.isEditMode && !this._existingListValuesLoaded) {
                // Edit mode + switched to List → load existing values
                this.loadExistingListValues();
            }
        }
    }

    /**
     * Load existing List Values for edit mode when Type = "List"
     */
    async loadExistingListValues() {
        if (!this.recordId) return;
        try {
            const values = await getFieldListValuesFresh({ selectedFieldId: this.recordId });
            if (values && values.length > 0) {
                this.listValueRows = values.map((v, idx) => {
                    this._rowCounter++;
                    return {
                        key: 'row-' + this._rowCounter,
                        id: v.Id,
                        code: v.FEC_Code__c || '',
                        nameEN: v.Name || '',
                        nameVN: v.FEC_Name_VN__c || ''
                    };
                });
            }
            this._existingListValuesLoaded = true;
        } catch (error) {
            console.error('Error loading list values:', error);
        }
    }

    /**
     * In edit mode, detect Type from loaded record and load list values
     */
    handleRecordLoad(event) {
        const fields = event.detail.records
            ? Object.values(event.detail.records)[0]?.fields
            : null;
        if (fields && fields.FEC_Type__c) {
            this.selectedType = fields.FEC_Type__c.value || '';
            if (this.selectedType === 'List' && this.isEditMode && !this._existingListValuesLoaded) {
                this.loadExistingListValues();
            }
        }
    }

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

        // Track selected type for List Values visibility
        this.selectedType = fields[this.FIELD_FEC_TYPE] || '';

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
                message: LABEL_ERROR_REQUIRED_EMPTY,
                variant: 'error',
                mode: 'dismissable'
            }));
            return;
        }

        // Validate Unique ID: phải bắt đầu bằng chữ Latin, cho phép chữ, số, gạch dưới, dấu chấm, gạch ngang
        if (this.isNewMode) {
            const uniqueId = fields[this.FIELD_FEC_UNIQUE_ID];
            if (uniqueId && !/^[a-zA-Z][a-zA-Z0-9_.\-]*$/.test(uniqueId)) {
                this.dispatchEvent(new ShowToastEvent({
                    title: LABEL_ERROR_TITLE,
                    message: LABEL_ERROR_SPECIAL_CHARS_ID,
                    variant: 'error',
                    mode: 'dismissable'
                }));
                return;
            }
        }

        // Validate List Values when Type = "List"
        if (fields[this.FIELD_FEC_TYPE] === 'List') {
            if (this.listValueRows.length === 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: LABEL_ERROR_TITLE,
                    message: 'At least 1 List Value is required for Type "List"',
                    variant: 'error',
                    mode: 'dismissable'
                }));
                return;
            }

            // Validate rows
            this.listValueErrors = [];
            const seenCodes = new Set();
            for (let i = 0; i < this.listValueRows.length; i++) {
                const row = this.listValueRows[i];
                if (!row.code || !row.code.trim()) {
                    this.listValueErrors.push(`Row ${i + 1}: Code is required`);
                }
                if (!row.nameEN || !row.nameEN.trim()) {
                    this.listValueErrors.push(`Row ${i + 1}: Name EN is required`);
                }
                if (!row.nameVN || !row.nameVN.trim()) {
                    this.listValueErrors.push(`Row ${i + 1}: Name VN is required`);
                }
                if (row.code && seenCodes.has(row.code.trim().toLowerCase())) {
                    this.listValueErrors.push(`Row ${i + 1}: Duplicate Code "${row.code.trim()}"`);
                } else if (row.code) {
                    seenCodes.add(row.code.trim().toLowerCase());
                }
            }

            if (this.listValueErrors.length > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: LABEL_ERROR_TITLE,
                    message: 'Please fix List Value errors before saving',
                    variant: 'error',
                    mode: 'dismissable'
                }));
                return;
            }

            if (this.isNewMode) {
                // Create mode: use imperative Apex call
                this.saveWithListValues(fields);
                return;
            }
            // Edit mode: submit standard form first, then save list values in handleSuccess
            this._pendingListValuesSave = true;
        }

        this.showLog('handleSubmit', 'RETURN: Validation Passed. Submitting to Salesforce.');
        
        // Submit thủ công sau khi đã kiểm tra xong (standard flow for non-List types and edit mode)
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    /**
     * Save Property + List Values via imperative Apex call
     */
    async saveWithListValues(fields) {
        try {
            const propertyData = {
                'Name': fields[this.FIELD_NAME],
                'FEC_Unique_ID__c': fields[this.FIELD_FEC_UNIQUE_ID],
                'FEC_Type__c': fields[this.FIELD_FEC_TYPE],
                'FEC_Name_VN__c': fields[this.FIELD_NAME_VN],
                'FEC_Field_Mandatory__c': fields[this.FIELD_FIELD_MANDATORY] || false,
                'Field_API_Name__c': fields[this.FIELD_FEC_UNIQUE_ID] // Use Unique ID as initial API name
            };

            // Build pipe-separated string from rows for Apex parsing
            const listValuesRaw = this.listValueRows
                .map(r => `${(r.code || '').trim()}|${(r.nameEN || '').trim()}|${(r.nameVN || '').trim()}`)
                .join('\n');

            const result = await savePropertyWithListValues({
                propertyData: propertyData,
                listValuesRaw: listValuesRaw
            });

            if (result && result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title: LABEL_SUCCESS_TITLE,
                    message: LABEL_SAVE_SUCCESS_MSG,
                    variant: 'success'
                }));
                // Reset state for clean re-open
                this._existingListValuesLoaded = false;
                this.listValueRows = [];
                this.listValueErrors = [];
                this.selectedType = '';
                this.dispatchEvent(new CustomEvent('success', { detail: { id: result.propertyId } }));
            }
        } catch (error) {
            const errMsg = error?.body?.message || error?.message || 'An error occurred';
            this.dispatchEvent(new ShowToastEvent({
                title: LABEL_ERROR_TITLE,
                message: errMsg,
                variant: 'error',
                mode: 'dismissable'
            }));
        }
    }

    /**
     * Add a new empty row to List Values
     */
    handleAddListValue() {
        this._rowCounter++;
        this.listValueRows = [...this.listValueRows, {
            key: 'row-' + this._rowCounter,
            code: '',
            nameEN: '',
            nameVN: ''
        }];
    }

    /**
     * Remove a row from List Values
     */
    handleRemoveListValue(event) {
        const keyToRemove = event.currentTarget.dataset.key;
        this.listValueRows = this.listValueRows.filter(r => r.key !== keyToRemove);
    }

    /**
     * Handle input change in a List Value row
     */
    handleListValueInputChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;

        this.listValueRows = this.listValueRows.map(r => {
            if (r.key === key) {
                return { ...r, [field]: value };
            }
            return r;
        });
        // Clear errors on input
        this.listValueErrors = [];
    }

    /**
     * Handle successful save
     * @param {Event} event
     */
    handleSuccess(event) {
        if (this._pendingListValuesSave && this.isEditMode) {
            this._pendingListValuesSave = false;
            this.saveListValuesForEdit();
        }
        // Reset list values cache so next edit open will re-fetch fresh data
        this._existingListValuesLoaded = false;
        this.listValueRows = [];
        this.listValueErrors = [];
        this.selectedType = '';

        this.dispatchEvent(new CustomEvent('success', { detail: event.detail }));
    }

    /**
     * Save List Values for edit mode — delete removed, update existing, insert new
     */
    async saveListValuesForEdit() {
        try {
            // Build pipe-separated string from rows
            const listValuesRaw = this.listValueRows
                .map(r => `${(r.code || '').trim()}|${(r.nameEN || '').trim()}|${(r.nameVN || '').trim()}`)
                .join('\n');

            // Use savePropertyWithListValues with existing recordId
            // The Apex method handles both create and update via the propertyData
            const propertyData = {
                'Id': this.recordId,
                'FEC_Type__c': 'List'
            };

            await savePropertyWithListValues({
                propertyData: propertyData,
                listValuesRaw: listValuesRaw
            });
        } catch (error) {
            console.error('Error saving list values in edit mode:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: LABEL_ERROR_TITLE,
                message: error?.body?.message || 'Error saving List Values',
                variant: 'error'
            }));
        }
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