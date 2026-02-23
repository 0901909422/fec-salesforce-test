import { api, LightningElement, track, wire } from 'lwc';
import getFieldListValues from '@salesforce/apex/FEC_AdditionalFieldController.getFieldListValues';
import deleteFieldListValue from '@salesforce/apex/FEC_AdditionalFieldController.deleteFieldListValue';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { OBJECT_MDM_ADDITIONAL_FIELD_LIST_VALUE, FIELD_ORDER, FIELD_PARENT_FIELD } from 'c/fecConstants';
import LABEL_NEW_LIST_VALUE from '@salesforce/label/c.FEC_New_List_Value';
import LABEL_LIST_VALUE_CLOSE from '@salesforce/label/c.FEC_List_Value_Modal_Close_Title';
import LABEL_LIST_VALUE_CANCEL from '@salesforce/label/c.FEC_List_Value_Cancel';
import LABEL_LIST_VALUE_SAVE from '@salesforce/label/c.FEC_List_Value_Save';
import LABEL_LIST_VALUE_CONFIRM_DELETE_TITLE from '@salesforce/label/c.FEC_List_Value_Confirm_Delete_Title';
import LABEL_LIST_VALUE_CONFIRM_DELETE_MSG from '@salesforce/label/c.FEC_List_Value_Confirm_Delete_Message';
import LABEL_DELETE from '@salesforce/label/c.FEC_Button_Delete';
import LABEL_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_SUCCESS_SAVE from '@salesforce/label/c.LABEL_SUCCESS_SAVE';
import LABEL_SUCCESS_DELETE from '@salesforce/label/c.LABEL_SUCCESS_DELETE';

const COLUMNS = [
    { label: 'Name EN', fieldName: 'Name', type: 'text' },
    { label: 'Name VN', fieldName: 'FEC_Name_VN__c', type: 'text' },
    { label: 'Order', fieldName: 'FEC_Order__c', type: 'number', sortable: true },// THÊM CỘT NÀY VÀO ĐÂY
    {
        label: 'Process Status',
        fieldName: 'Process_Change_Status__c',
        type: 'text',
        initialWidth: 120
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
    labelListValueName = LABEL_NAME;
    labelListValueNameVN = LABEL_NAME_VN;
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
        } else if (result.error) {
            this.showToast('Error', 'Failed to load list values', 'error');
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.listValueRecordIdForEdit = row.Id;
            this.isAddEditModalOpen = true;
        } else if (actionName === 'delete') {
            this.recordIdToDelete = row.Id;
            this.isDeleteModalOpen = true;
        }
    }

    openAddEditModal() {
        this.listValueRecordIdForEdit = null;
        this.isAddEditModalOpen = true;
    }

    closeAddEditModal() {
        this.isAddEditModalOpen = false;
    }

    closeDeleteModal() {
        this.isDeleteModalOpen = false;
        this.recordIdToDelete = null;
    }

    async handleFormSuccess() {
        this.showToast('Success', LABEL_SUCCESS_SAVE, 'success');
        this.closeAddEditModal();
        this.isLoading = true;
        try {
            await refreshApex(this.wiredListValuesResult);
        } finally {
            this.isLoading = false;
        }
    }

    handleFormError(event) {
        let message = 'Lỗi khi lưu dữ liệu';
        if (event && event.detail && event.detail.message) {
            message = event.detail.message;
        }
        this.showToast('Error', message, 'error');
    }

    async confirmDelete() {
        this.isLoading = true;
        try {
            await deleteFieldListValue({ recordId: this.recordIdToDelete });
            this.showToast('Success', LABEL_SUCCESS_DELETE, 'success');
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