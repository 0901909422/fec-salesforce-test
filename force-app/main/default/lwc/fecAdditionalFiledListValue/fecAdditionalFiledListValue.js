import { api, LightningElement, track, wire } from 'lwc';
import getFieldListValues from '@salesforce/apex/FEC_AdditionalFieldController.getFieldListValues';
import deleteFieldListValue from '@salesforce/apex/FEC_AdditionalFieldController.deleteFieldListValue';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { OBJECT_MDM_ADDITIONAL_FIELD_LIST_VALUE, FIELD_ORDER, FIELD_PARENT_FIELD, FIELD_NAME, FIELD_NAME_VN, FIELD_CODE, FIELD_PROCESS_CHANGE_STATUS, VARIANT_SUCCESS, VARIANT_ERROR } from 'c/fecConstants';
// Make sure FIELD_CODE is exported from fecConstants as: export const FIELD_CODE = 'FEC_Code__c';
import LABEL_NEW_LIST_VALUE from '@salesforce/label/c.FEC_New_List_Value';
import LABEL_NAME from '@salesforce/label/c.FEC_Label_Name';
import LABEL_NAME_VN from '@salesforce/label/c.FEC_Label_Name_VN';
import LABEL_ORDER from '@salesforce/label/c.FEC_Col_Order';
import LABEL_LIST_VALUE_CLOSE from '@salesforce/label/c.FEC_List_Value_Modal_Close_Title';
import LABEL_LIST_VALUE_CANCEL from '@salesforce/label/c.FEC_List_Value_Cancel';
import LABEL_LIST_VALUE_SAVE from '@salesforce/label/c.FEC_List_Value_Save';
import LABEL_LIST_VALUE_CONFIRM_DELETE_TITLE from '@salesforce/label/c.FEC_List_Value_Confirm_Delete_Title';
import LABEL_LIST_VALUE_CONFIRM_DELETE_MSG from '@salesforce/label/c.FEC_List_Value_Confirm_Delete_Message';
import LABEL_DELETE from '@salesforce/label/c.FEC_Button_Delete';
import LABEL_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_SAVE_SUCCESS_MSG from '@salesforce/label/c.FEC_Save_Success_Message';
import LABEL_DELETE_SUCCESS_MSG from '@salesforce/label/c.FEC_Delete_Success_Message';

const COLUMNS = [
    { label: 'Code', fieldName: 'FEC_Code__c', type: 'text', initialWidth: 120 },
    { label: 'Name EN', fieldName: FIELD_NAME, type: 'text' },
    { label: 'Name VN', fieldName: FIELD_NAME_VN, type: 'text' },
    { label: 'Order', fieldName: FIELD_ORDER, type: 'number', sortable: true, initialWidth: 90 },
    {
        label: 'Process Status',
        fieldName: FIELD_PROCESS_CHANGE_STATUS,
        type: 'text',
        initialWidth: 130
    },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }, { label: 'Delete', name: 'delete' }] },
        fixedWidth: 80
    },
];

/**
 * LWC for managing Additional Field List Values.
 * Handles CRUD, modal state, and accessibility improvements.
 */
export default class FecAdditionalFiledListValue extends LightningElement {
    @api fieldRecord = {};
    @track listValues;
    @track columns = COLUMNS;
    @track isLoading = false;
    @track isAddEditModalOpen = false;
    @track listValueRecordIdForEdit = null;
    @track isDeleteModalOpen = false;
    @track recordIdToDelete = null;
    wiredListValuesResult;

    // expose to template
    labelNewListValue = LABEL_NEW_LIST_VALUE;
    OBJECT_MDM_ADDITIONAL_FIELD_LIST_VALUE = OBJECT_MDM_ADDITIONAL_FIELD_LIST_VALUE;
    FIELD_ORDER = FIELD_ORDER;
    FIELD_PARENT_FIELD = FIELD_PARENT_FIELD;
    FIELD_CODE = FIELD_CODE;
    FIELD_NAME = FIELD_NAME;
    FIELD_NAME_VN = FIELD_NAME_VN;
    labelListValueName = LABEL_NAME;
    labelListValueNameVN = LABEL_NAME_VN;
    labelCode = 'Code';
    labelOrder = LABEL_ORDER || 'Order';
    labelConfirmDeleteTitle = LABEL_LIST_VALUE_CONFIRM_DELETE_TITLE;
    labelConfirmDeleteMsg = LABEL_LIST_VALUE_CONFIRM_DELETE_MSG;
    labelDelete = LABEL_DELETE;
    labelCancel = LABEL_CANCEL;
    labelSave = LABEL_LIST_VALUE_SAVE;

    get parentFieldId() {
        return this.fieldRecord.Id;
    }

    get listValueModalTitle() {
        return this.listValueRecordIdForEdit ? 'Edit List Value' : 'New List Value';
    }

    @wire(getFieldListValues, { selectedFieldId: '$parentFieldId' })
    wiredListValues(result) {
        this.wiredListValuesResult = result;
        if (result.data) {
            this.listValues = result.data;
            // Debug: Check if Code field exists in data
            if (this.listValues && this.listValues.length > 0) {
                console.log('First record data:', JSON.stringify(this.listValues[0]));
            }
        } else if (result.error) {
            this.showToast('Error', 'Failed to load list values', 'error');
            console.error('Error loading list values:', result.error);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.listValueRecordIdForEdit = row.Id;
            this.isAddEditModalOpen = true;
        } else if (actionName === 'delete') {
            // KIỂM TRA ĐIỀU KIỆN XÓA TẠI ĐÂY
            if (row[FIELD_PROCESS_CHANGE_STATUS] !== 'New') {
                this.showToast('Cảnh báo', 'Chỉ được phép xóa bản ghi có Process Status là "New".', 'warning');
                return; // Dừng lại, không mở modal xóa
            }
            this.recordIdToDelete = row.Id;
            this.isDeleteModalOpen = true;
        }
    }

    openAddEditModal() {
        this.listValueRecordIdForEdit = null;
        this.isAddEditModalOpen = true;
        // Store next order to be used in form
        this.nextOrder = this.calculateNextOrder();
    }

    calculateNextOrder() {
        if (!this.listValues || this.listValues.length === 0) {
            return 1;
        }
        const maxOrder = Math.max(...this.listValues.map(item => item[FIELD_ORDER] || 0));
        return maxOrder + 1;
    }

    closeAddEditModal() {
        this.isAddEditModalOpen = false;
    }

    closeDeleteModal() {
        this.isDeleteModalOpen = false;
        this.recordIdToDelete = null;
    }

    handleFormSubmit() {
        this.template.querySelector('lightning-record-edit-form').submit();
    }

    handleSubmit(event) {
        event.preventDefault();
        const fields = event.detail.fields;
        
        // Validate required fields - only Code validation for new records
        if (!this.listValueRecordIdForEdit) {
            if (!fields[FIELD_CODE] || fields[FIELD_CODE].trim() === '') {
                this.showToast('Error', 'Code is required', 'error');
                return;
            }
        }
        
        if (!fields[FIELD_NAME] || fields[FIELD_NAME].trim() === '') {
            this.showToast('Error', 'Name EN is required', 'error');
            return;
        }
        if (!fields[FIELD_NAME_VN] || fields[FIELD_NAME_VN].trim() === '') {
            this.showToast('Error', 'Name VN is required', 'error');
            return;
        }
        
        // Ensure parent link is set for new records
        if (!this.listValueRecordIdForEdit) {
            fields[FIELD_PARENT_FIELD] = this.fieldRecord ? this.fieldRecord.Id : null;
            // Set Order to nextOrder if it's a new record and not already set
            if (!fields[FIELD_ORDER] || fields[FIELD_ORDER] === '') {
                fields[FIELD_ORDER] = this.nextOrder;
            }
        }

        // Logic check: if it's a new record and parent ID is still null, block it
        if (!this.listValueRecordIdForEdit && !fields[FIELD_PARENT_FIELD]) {
            this.showToast('Error', 'Missing Parent Field reference.', 'error');
            return;
        }

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    async handleFormSuccess() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredListValuesResult);
            this.showToast('Success', LABEL_SAVE_SUCCESS_MSG, VARIANT_SUCCESS);
            this.closeAddEditModal();
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, VARIANT_ERROR);
        } finally {
            this.isLoading = false;
        }
    }

    handleFormError(event) {
        event.preventDefault(); // Ngăn chặn thông báo lỗi default của Salesforce "Sorry to interrupt"
        this.isLoading = false;
        
        // Ngăn chặn component lightning-messages tự động hiển thị lỗi xấu từ API
        const messagesCmp = this.template.querySelector('lightning-messages');
        if (messagesCmp) {
            messagesCmp.clear();
        }

        let errorMessage = 'Đã có lỗi xảy ra. Vui lòng thử lại.';
        const detailMsg = event.detail?.message || '';
        const detailDetail = event.detail?.detail || '';
        const outputMsg = event.detail?.output?.errors?.[0]?.message || '';
        // Extract field error messages if present
        let fieldErrorMsg = '';
        if (event.detail?.output?.fieldErrors) {
            for (let field in event.detail.output.fieldErrors) {
                const fErrors = event.detail.output.fieldErrors[field];
                if (fErrors && fErrors.length > 0) {
                    fieldErrorMsg += fErrors.map(e => e.message).join('; ');
                }
            }
        }
        
        const fullMessage = detailMsg + ' ' + detailDetail + ' ' + outputMsg + ' ' + fieldErrorMsg;

        if (fullMessage.includes('DUPLICATE_VALUE') || fullMessage.includes('duplicate value found')) {
            errorMessage = 'Mã Code này đã tồn tại. Vui lòng nhập Code khác.';
        } else if (fullMessage.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
            errorMessage = detailDetail || detailMsg || outputMsg || fieldErrorMsg;
        } else if (fieldErrorMsg) {
            errorMessage = fieldErrorMsg;
        } else if (outputMsg) {
            errorMessage = outputMsg;
        } else if (detailMsg) {
            errorMessage = detailMsg;
        }

        this.showToast('Lỗi', errorMessage, 'error');
    }

    async confirmDelete() {
        this.isLoading = true;
        try {
            await deleteFieldListValue({ recordId: this.recordIdToDelete });
            this.showToast('Success', LABEL_DELETE_SUCCESS_MSG, 'success');
            await refreshApex(this.wiredListValuesResult);
        } catch (error) {
            let message = 'Lỗi khi xóa';
            if (error && error.body && error.body.message) {
                message = error.body.message;
            }
            this.showToast('Error', message, 'error');
        } finally {
            this.isLoading = false;
            this.closeDeleteModal();
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}