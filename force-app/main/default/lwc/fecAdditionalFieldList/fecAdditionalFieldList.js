import { LightningElement, track, wire } from 'lwc';
import getAdditionalFields from '@salesforce/apex/FEC_AdditionalFieldController.getAdditionalFields';
import deleteAdditionalField from '@salesforce/apex/FEC_AdditionalFieldController.deleteRecord'; // IMPORT MỚI
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

// Shared constants and labels
import { FIELD_FEC_UNIQUE_ID, FIELD_NAME, FIELD_NAME_VN, FIELD_FEC_TYPE, FIELD_FIELD_STATUS, FIELD_FIELD_MANDATORY, FIELD_PROCESS_CHANGE_STATUS, FIELD_EXTERNAL_ID } from 'c/fecConstants/fecConstants';
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
    @track recordIdForEdit; // Lưu ID của bản ghi đang chỉnh sửa
    @track isEditModalOpen = false; // Trạng thái Modal Edit
    @track isListValueModalOpen = false; // Biến kiểm soát Modal mới
    @track selectedFieldRecord = {};    // Lưu record đang được chọn để quản lý List
    @track showDeleteConfirm = false; // for delete confirmation modal
    @track recordIdToDelete = null; // store record id to delete
    wiredFieldsResult;

    sortedBy;
    sortDirection = 'asc';

    // expose labels to template
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
            this.showToast(LABEL_ERROR_TITLE, LABEL_ERROR_RETRIEVE + (result.error.body?.message || result.error.message), 'error');
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
        } catch (error) {
            this.showToast(LABEL_ERROR_TITLE, error?.body?.message || error?.message || 'Failed to delete record.', 'error');
            // Optionally log error
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Xử lý khi người dùng chọn Edit hoặc Delete từ Row Actions.
     */
    handleRowAction(event) {
        this.modalTitle = LABEL_EDIT + ' ' + LABEL_NAME;
        this.actionClick = true;
        const actionName = event.detail.action.name;
        const row = event.detail.row; // Dữ liệu của bản ghi được chọn

        switch (actionName) {
            case 'edit':
                this.handleEdit(row.Id);
                break;
            case 'delete':
                this.recordIdToDelete = row.Id;
                this.showDeleteConfirm = true;
                break;
            case 'manage_list_values':
                this.handleManageListValues(row);
                break; // HÀNH ĐỘNG MỚI
            default:
        }
    }

    /**
     * @description Xử lý hành động Manage List Values: kiểm tra FEC Type và mở Modal.
     */
    handleManageListValues(record) {
        if (record.FEC_Type__c === 'List') {
            this.selectedFieldRecord = record; // Lưu toàn bộ bản ghi
            this.modalTitle = LABEL_MANAGE_LIST_VALUES + ': ' + record.Name; // Cập nhật tiêu đề
            this.isListValueModalOpen = true; // Mở Modal quản lý List Value
        } else {
            // Use label with placeholder
            this.showToast(LABEL_WARNING_TITLE, LABEL_WARNING_TYPE_NOT_LIST.replace('{0}', record.Name), 'warning');
        }
    }

    /**
     * @description Đóng Modal quản lý List Values.
     */
    closeListValueModal() {
        this.isListValueModalOpen = false;
        this.selectedFieldRecord = {}; // Reset bản ghi đã chọn
    }

    /**
    * @description Đóng Modal.
    */
    closeSettingModal() {
        this.isModalOpen = false;
        this.recordIdForEdit = null;
        this.actionClick = false;
    }

    /**
     * @description Mở Modal chỉnh sửa cho bản ghi được chọn.
     */
    handleEdit(recordId) {
        this.recordIdForEdit = recordId;
        this.isEditModalOpen = true;
        this.isModalOpen = true;
    }

    // Delete confirmation modal logic
    cancelDelete() {
        this.showDeleteConfirm = false;
        this.recordIdToDelete = null;
    }

    async confirmDelete() {
        await this.deleteRecord(this.recordIdToDelete);
        this.showDeleteConfirm = false;
        this.recordIdToDelete = null;
    }

    /**
     * @description Đóng Modal.
     */
    closeModal() {
        this.isModalOpen = false;
        this.recordIdForEdit = null;
        this.actionClick = false;
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
            return refreshApex(this.wiredFieldsResult);
        }
    }

    /**
     * @description Xử lý sự kiện sắp xếp cột (datatable).
     * @param event Dữ liệu sự kiện chứa cột được sắp xếp và hướng sắp xếp.
     * @return void
     * @date 2025-12-03
     * @author DAT NGO
     */
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortDirection);
    }

    /**
     * @description Hàm sắp xếp dữ liệu (Client-side sorting).
     * @param fieldName Tên trường để sắp xếp.
     * @param direction Hướng sắp xếp ('asc' hoặc 'desc').
     * @return void
     * @date 2025-12-03
     * @author DAT NGO
     */
    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.fieldList));

        // Comment Giải thích Source Code: Sắp xếp dữ liệu theo trường và hướng đã chọn.
        let isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = (x[fieldName] === undefined || x[fieldName] === null) ? '' : x[fieldName];
            y = (y[fieldName] === undefined || y[fieldName] === null) ? '' : y[fieldName];

            return isReverse * ((x > y) - (y > x));
        });
        this.fieldList = parseData;
    }

    /**
     * @description Hiển thị thông báo Toast.
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}