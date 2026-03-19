import { LightningElement, track, wire } from 'lwc';
import getAdditionalFields from '@salesforce/apex/FEC_AdditionalFieldController.getAdditionalFields';
import deleteAdditionalField from '@salesforce/apex/FEC_AdditionalFieldController.deleteRecord'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import { FIELD_FEC_UNIQUE_ID, FIELD_NAME, FIELD_NAME_VN, FIELD_FEC_TYPE, FIELD_FIELD_STATUS, FIELD_FIELD_MANDATORY, FIELD_PROCESS_CHANGE_STATUS, FIELD_EXTERNAL_ID } from 'c/fecConstants';
import LABEL_EDIT from '@salesforce/label/c.FEC_Edit';
import LABEL_DELETE from '@salesforce/label/c.FEC_Delete';
import LABEL_MANAGE_LIST_VALUES from '@salesforce/label/c.FEC_Manage_List_Values';
import LABEL_UNIQUE_ID from '@salesforce/label/c.FEC_Label_Unique_ID';
import LABEL_NAME from '@salesforce/label/c.FEC_Label_Name';
import LABEL_NAME_VN from '@salesforce/label/c.FEC_Label_Name_VN';
import LABEL_TYPE from '@salesforce/label/c.FEC_Label_Type';
import LABEL_FIELD_STATUS from '@salesforce/label/c.FEC_Label_Field_Status';
import LABEL_MANDATORY from '@salesforce/label/c.FEC_Label_Mandatory';
import LABEL_PROCESS_STATUS from '@salesforce/label/c.FEC_Label_Process_Status';
import LABEL_DELETE_SUCCESS from '@salesforce/label/c.FEC_Delete_Success_Message';
import LABEL_ERROR_RETRIEVE from '@salesforce/label/c.FEC_Error_Retrieve_Additional_Fields';
import LABEL_SUCCESS_TITLE from '@salesforce/label/c.FEC_Success_Title'; 
import LABEL_ERROR_TITLE from '@salesforce/label/c.FEC_Error_Title'; 
import LABEL_SAVE_SUCCESS_MSG from '@salesforce/label/c.FEC_Save_Success_Message'; 
import LABEL_WARNING_TYPE_NOT_LIST from '@salesforce/label/c.FEC_Warning_Type_Not_List';
import LABEL_WARNING_TITLE from '@salesforce/label/c.FEC_Warning_Title';
import LABEL_LIST_TITLE from '@salesforce/label/c.FEC_Additional_Fields_List_Title';
import LABEL_NEW_ADDITIONAL_FIELD from '@salesforce/label/c.FEC_New_Additional_Field';
import LABEL_CONFIRM_DELETE_TITLE from '@salesforce/label/c.FEC_Confirm_Delete_Title';
import LABEL_CONFIRM_DELETE_MSG from '@salesforce/label/c.FEC_Confirm_Delete_Message';
import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_DELETE from '@salesforce/label/c.FEC_Button_Delete';
import LABEL_BUTTON_CLOSE from '@salesforce/label/c.FEC_Button_Close';

const ACTIONS = [
    { label: LABEL_EDIT, name: 'edit' },
    { label: LABEL_DELETE, name: 'delete' },
    { label: LABEL_MANAGE_LIST_VALUES, name: 'manage_list_values' }
];
const COLUMNS = [
    { label: LABEL_UNIQUE_ID, fieldName: FIELD_FEC_UNIQUE_ID, type: 'text', sortable: true },
    { label: LABEL_NAME, fieldName: FIELD_NAME, type: 'text', sortable: true },
    { label: LABEL_NAME_VN, fieldName: FIELD_NAME_VN, type: 'text', sortable: true },
    { label: LABEL_TYPE, fieldName: FIELD_FEC_TYPE, type: 'text', sortable: true },
    { label: LABEL_FIELD_STATUS, fieldName: FIELD_FIELD_STATUS, type: 'boolean', sortable: true },
    { label: LABEL_MANDATORY, fieldName: FIELD_FIELD_MANDATORY, type: 'boolean', sortable: true },
    { label: LABEL_PROCESS_STATUS, fieldName: FIELD_PROCESS_CHANGE_STATUS, type: 'text', cellAttributes: { class: { fieldName: 'statusColor' } } },
    { type: 'action', typeAttributes: { rowActions: ACTIONS } }
];

export default class FecAdditionalFieldList extends LightningElement {

    @track fieldList;
    @track error;
    @track columns = COLUMNS;
    @track isLoading = false;
    @track isModalOpen = false;
    @track actionClick = false;
    @track modalTitle = "";
    @track recordIdForEdit; 
    @track isEditModalOpen = false; 
    @track showDeleteConfirm = false; 
    @track recordIdToDelete = null; 
    @track isListValueModalOpen = false; 
    @track selectedFieldRecord = {};    
    wiredFieldsResult;

    sortedBy;
    sortDirection = 'asc';

    // ==========================================================
    // KHỐI CODE BỔ SUNG CHỈ DÀNH CHO HISTORY (GIAO DIỆN)
    // ==========================================================
    @track isHistoryVisible = false;
    @track historyRecordId = ''; 

    get mainPanelSize() { return this.isHistoryVisible ? 9 : 12; }
    get toggleHistoryIcon() { return this.isHistoryVisible ? 'utility:close' : 'utility:history'; }
    get toggleHistoryLabel() { return this.isHistoryVisible ? 'Đóng Lịch sử' : 'Xem Lịch sử'; }
    get toggleButtonVariant() { return this.isHistoryVisible ? 'neutral' : 'brand-outline'; }

    handleToggleHistory() {
        this.isHistoryVisible = !this.isHistoryVisible;
    }

    refreshHistoryPanel() {
        const historyComp = this.template.querySelector('[data-id="historyComponent"]');
        if (historyComp) {
            historyComp.refreshData();
        }
    }
    // ==========================================================

    labelListTitle = LABEL_LIST_TITLE;
    labelNewField = LABEL_NEW_ADDITIONAL_FIELD;
    labelConfirmDeleteTitle = LABEL_CONFIRM_DELETE_TITLE;
    labelConfirmDeleteMsg = LABEL_CONFIRM_DELETE_MSG;
    labelButtonCancel = LABEL_BUTTON_CANCEL;
    labelButtonDelete = LABEL_BUTTON_DELETE;
    labelButtonClose = LABEL_BUTTON_CLOSE;

    @wire(getAdditionalFields)
    wiredAdditionalFields(result) {
        this.wiredFieldsResult = result;
        this.isLoading = true;
        if (result.data) {
            this.fieldList = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.fieldList = undefined;
            this.showToast(LABEL_ERROR_TITLE, LABEL_ERROR_RETRIEVE + ': ' + (result.error.body?.message || result.error.message), 'error');
        }
        this.isLoading = false;
    }

    async deleteRecord(recordId) {
        this.isLoading = true;
        try {
            await deleteAdditionalField({ recordId: recordId });
            this.showToast(LABEL_SUCCESS_TITLE, LABEL_DELETE_SUCCESS, 'success');
            if (this.wiredFieldsResult) {
                await refreshApex(this.wiredFieldsResult);
            }
            // Gọi refresh lịch sử nếu đang mở
            if (this.isHistoryVisible) {
                this.refreshHistoryPanel();
            }
        } catch (error) {
            this.showToast(LABEL_ERROR_TITLE, error?.body?.message || error?.message || 'Failed to delete record.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRowAction(event) {
        this.modalTitle = LABEL_EDIT + ' ' + LABEL_NAME;
        this.actionClick = true;
        const actionName = event.detail.action.name;
        const row = event.detail.row; 

        switch (actionName) {
            case 'edit':
                this.handleEdit(row.Id);
                break;
            case 'delete':
                // KIỂM TRA ĐIỀU KIỆN XÓA TẠI ĐÂY
                if (row[FIELD_PROCESS_CHANGE_STATUS] !== 'New') {
                    this.showToast(LABEL_WARNING_TITLE, 'Chỉ được phép xóa bản ghi có Process Status là "New".', 'warning');
                    return; // Dừng lại, không mở xác nhận xóa
                }
                this.recordIdToDelete = row.Id;
                this.showDeleteConfirm = true;
                break;
            case 'manage_list_values':
                this.handleManageListValues(row);
                break; 
            default:
        }
    }

    handleManageListValues(record) {
        if (record.FEC_Type__c === 'List') {
            this.selectedFieldRecord = { ...record }; 
            this.modalTitle = LABEL_MANAGE_LIST_VALUES + ': ' + record.Name;
            this.isListValueModalOpen = true;
        } else {
            this.showToast(LABEL_WARNING_TITLE, LABEL_WARNING_TYPE_NOT_LIST.replace('{0}', record.Name), 'warning');
        }
    }

    closeListValueModal() {
        this.isListValueModalOpen = false;
        this.selectedFieldRecord = {}; 
    }

    closeSettingModal() {
        this.isModalOpen = false;
        this.isEditModalOpen = false;
        this.recordIdForEdit = null;
        this.actionClick = false;
    }

    closeModal() {
        this.closeSettingModal();
    }

    handleCancelEvent() {
        this.closeSettingModal();
    }

    handleEdit(recordId) {
        this.recordIdForEdit = recordId;
        this.isEditModalOpen = true;
        this.isModalOpen = true;
    }

    cancelDelete() {
        this.showDeleteConfirm = false;
        this.recordIdToDelete = null;
    }

    async confirmDelete() {
        await this.deleteRecord(this.recordIdToDelete);
        this.showDeleteConfirm = false;
        this.recordIdToDelete = null;
    }

    openNewFieldModal() {
        this.modalTitle = LABEL_NEW_ADDITIONAL_FIELD;
        this.actionClick = false;
        this.isModalOpen = true;
        this.recordIdForEdit = null;
    }

    handleSuccess() {
        this.closeModal();
        this.showToast(LABEL_SUCCESS_TITLE, LABEL_SAVE_SUCCESS_MSG, 'success');
        if (this.wiredFieldsResult) {
            refreshApex(this.wiredFieldsResult);
        }
        // Gọi refresh lịch sử nếu đang mở
        if (this.isHistoryVisible) {
            this.refreshHistoryPanel();
        }
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortDirection);
    }

    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.fieldList));
        let isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = (x[fieldName] === undefined || x[fieldName] === null) ? '' : x[fieldName];
            y = (y[fieldName] === undefined || y[fieldName] === null) ? '' : y[fieldName];
            return isReverse * ((x > y) - (y > x));
        });
        this.fieldList = parseData;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}