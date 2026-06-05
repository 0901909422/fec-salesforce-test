import { LightningElement, wire } from 'lwc';
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
import LABEL_MANAGE_MAPPING from '@salesforce/label/c.FEC_Manage_Mapping';
import LABEL_SEARCH_PLACEHOLDER from '@salesforce/label/c.FEC_Search_Placeholder';
import LABEL_WARNING_DELETE_NEW_ONLY from '@salesforce/label/c.FEC_Warning_Delete_New_Only';
import LABEL_ERROR_DELETE_FAILED from '@salesforce/label/c.FEC_Error_Delete_Failed';

const ACTIONS = [
    { label: LABEL_EDIT, name: 'edit' },
    { label: LABEL_DELETE, name: 'delete' },
    { label: LABEL_MANAGE_LIST_VALUES, name: 'manage_list_values' },
    { label: LABEL_MANAGE_MAPPING, name: 'manage_mapping' }
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

    fieldList;
    error;
    columns = COLUMNS;
    isLoading = false;
    isModalOpen = false;
    actionClick = false;
    modalTitle = "";
    recordIdForEdit; 
    isEditModalOpen = false; 
    showDeleteConfirm = false; 
    recordIdToDelete = null; 
    isListValueModalOpen = false; 
    selectedFieldRecord = {};
    isMappingModalOpen = false;
    mappingRecordId = null;
    mappingModalTitle = '';
    wiredFieldsResult;

    sortedBy;
    sortDirection = 'asc';
    searchTerm = '';
    allFieldList;;
    pageSize = 15;
    currentPage = 1;
    totalRecords = 0;
    totalPages = 1;

    labelSearchPlaceholder = LABEL_SEARCH_PLACEHOLDER;

    // ==========================================================
    // KHỐI CODE BỔ SUNG CHỈ DÀNH CHO HISTORY (GIAO DIỆN)
    // ==========================================================
    isHistoryVisible = false;
    historyRecordId = ''; 

    get mainPanelSize() { return this.isHistoryVisible ? 9 : 12; }
    get toggleHistoryIcon() { return this.isHistoryVisible ? 'utility:close' : 'utility:history'; }
    get toggleHistoryLabel() { return this.isHistoryVisible ? 'Đóng Lịch sử' : 'Xem Lịch sử'; }
    get toggleButtonVariant() { return this.isHistoryVisible ? 'neutral' : 'brand-outline'; }

    handleToggleHistory() {
        this.isHistoryVisible = !this.isHistoryVisible;
        if (this.isHistoryVisible && this._pendingHistoryRefresh) {
            this._pendingHistoryRefresh = false;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { this.refreshHistoryPanel(); }, 200);
        }
    }

    refreshHistoryPanel() {
        const historyComp = this.template.querySelector('[data-id="historyComponent"]');
        if (historyComp) {
            historyComp.refreshData();
        } else {
            this._pendingHistoryRefresh = true;
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
            this.allFieldList = result.data;
            this.applySearch();
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.allFieldList = undefined;
            this.fieldList = undefined;
            this.showToast(LABEL_ERROR_TITLE, LABEL_ERROR_RETRIEVE + ': ' + (result.error.body?.message || result.error.message), 'error');
        }
        this.isLoading = false;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applySearch();
    }

    applySearch() {
        if (!this.allFieldList) {
            this.fieldList = undefined;
            return;
        }
        let filtered;
        if (!this.searchTerm || this.searchTerm.trim() === '') {
            filtered = [...this.allFieldList];
        } else {
            const key = this.searchTerm.toLowerCase().trim();
            filtered = this.allFieldList.filter(f => {
                const uid = (f[FIELD_FEC_UNIQUE_ID] || '').toLowerCase();
                const name = (f[FIELD_NAME] || '').toLowerCase();
                return uid.includes(key) || name.includes(key);
            });
        }
        this.fieldList = filtered;
        this.totalRecords = filtered.length;
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize) || 1;
        this.currentPage = 1;
    }

    get paginatedFieldList() {
        if (!this.fieldList) return [];
        const start = (this.currentPage - 1) * this.pageSize;
        return this.fieldList.slice(start, start + this.pageSize);
    }

    handlePageChange(event) {
        this.currentPage = event.detail.page;
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.pageSize;
        this.currentPage = 1;
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize) || 1;
    }

    async deleteRecord(recordId) {
        this.isLoading = true;
        try {
            await deleteAdditionalField({ recordId: recordId });
            this.showToast(LABEL_SUCCESS_TITLE, LABEL_DELETE_SUCCESS, 'success');
            if (this.wiredFieldsResult) {
                await refreshApex(this.wiredFieldsResult);
            }
            // Gọi refresh lịch sử
            this.refreshHistoryPanel();
        } catch (error) {
            this.showToast(LABEL_ERROR_TITLE, error?.body?.message || error?.message || LABEL_ERROR_DELETE_FAILED, 'error');
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
                    this.showToast(LABEL_WARNING_TITLE, LABEL_WARNING_DELETE_NEW_ONLY, 'warning');
                    return; // Dừng lại, không mở xác nhận xóa
                }
                this.recordIdToDelete = row.Id;
                this.showDeleteConfirm = true;
                break;
            case 'manage_list_values':
                this.handleManageListValues(row);
                break;
            case 'manage_mapping':
                this.handleManageMapping(row);
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

    handleManageMapping(record) {
        this.mappingRecordId = record.FEC_Unique_ID__c;
        this.mappingModalTitle = LABEL_MANAGE_MAPPING + ': ' + record.Name;
        this.isMappingModalOpen = true;
    }

    closeMappingModal() {
        this.isMappingModalOpen = false;
        this.mappingRecordId = null;
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

    async handleSuccess() {
        this.closeModal();
        this.showToast(LABEL_SUCCESS_TITLE, LABEL_SAVE_SUCCESS_MSG, 'success');
        if (this.wiredFieldsResult) {
            await refreshApex(this.wiredFieldsResult);
        }
        // Gọi refresh lịch sử — delay để History Tracking kịp commit
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.refreshHistoryPanel();
        }, 500);
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortDirection);
    }

    sortData(fieldName, direction) {
        let parseData = [...this.fieldList];
        let isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = (x[fieldName] === undefined || x[fieldName] === null) ? '' : x[fieldName];
            y = (y[fieldName] === undefined || y[fieldName] === null) ? '' : y[fieldName];
            return isReverse * ((x > y) - (y > x));
        });
        this.fieldList = parseData;
        this.currentPage = 1;
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