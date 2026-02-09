import { LightningElement, wire, track } from 'lwc';
import getChannels from '@salesforce/apex/FEC_ChannelController.getChannels';
import deleteChannel from '@salesforce/apex/FEC_ChannelController.deleteChannel';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { showLog } from 'c/fecUtils'; // Tận dụng fecUtils của bạn
import { FIELD_CHANNEL_ID, FIELD_CHANNEL_VN_NAME, FIELD_CHANNEL_STATUS, FIELD_NAME, VARIANT_SUCCESS, VARIANT_ERROR, OBJECT_MDM_CHANNEL, FIELD_CHANNEL_VN_NAME as UNUSED } from 'c/fecConstants';
import LABEL_COL_CHANNEL_ID from '@salesforce/label/c.FEC_Col_Channel_ID';
import LABEL_COL_CHANNEL_VN_NAME from '@salesforce/label/c.FEC_Col_Channel_VN_Name';
import LABEL_COL_CHANNEL_STATUS from '@salesforce/label/c.FEC_Col_Channel_Status';
import LABEL_COL_NAME from '@salesforce/label/c.FEC_Col_Name';
import LABEL_ACTION_EDIT from '@salesforce/label/c.FEC_Action_Edit';
import LABEL_ACTION_DELETE from '@salesforce/label/c.FEC_Action_Delete';
import LABEL_BUTTON_SAVE_CHANNEL from '@salesforce/label/c.FEC_Button_Save_Channel';
import LABEL_BUTTON_ADD_CHANNEL from '@salesforce/label/c.FEC_Button_Add_Channel';
import LABEL_BUTTON_CANCEL_EDIT from '@salesforce/label/c.FEC_Button_Cancel_Edit';
import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_CONFIRM_DELETE_CHANNEL from '@salesforce/label/c.FEC_Confirm_Delete_Channel';
import LABEL_TOAST_SAVE_SUCCESS from '@salesforce/label/c.FEC_Toast_Save_Success';
import LABEL_TOAST_DELETE_SUCCESS from '@salesforce/label/c.FEC_Toast_Delete_Success';
import LABEL_TOAST_ERROR_GENERIC from '@salesforce/label/c.FEC_Toast_Error_Generic';

const COLUMNS = [
    { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
    { label: LABEL_COL_CHANNEL_ID, fieldName: FIELD_CHANNEL_ID },
    { label: LABEL_COL_CHANNEL_VN_NAME, fieldName: FIELD_CHANNEL_VN_NAME },
    { label: LABEL_COL_CHANNEL_STATUS, fieldName: FIELD_CHANNEL_STATUS },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: LABEL_ACTION_EDIT, name: 'edit' },
                { label: LABEL_ACTION_DELETE, name: 'delete' }
            ]
        }
    }
];

export default class FecChannelManager extends LightningElement {
    @track channels = [];
    @track selectedId; // null = Add Mode, has ID = Edit Mode
    @track showForm = false;
    columns = COLUMNS;
    wiredResult;

    // expose labels and constants to template
    labelSaveChannel = LABEL_BUTTON_SAVE_CHANNEL;
    labelAddChannel = LABEL_BUTTON_ADD_CHANNEL;
    labelCancelEdit = LABEL_BUTTON_CANCEL_EDIT;
    labelCancel = LABEL_BUTTON_CANCEL;
    labelTitle = LABEL_COL_CHANNEL_ID; // temporary, override if specific title label exists
    objectApiName = OBJECT_MDM_CHANNEL;
    fieldChannelId = FIELD_CHANNEL_ID;
    fieldName = FIELD_NAME;
    fieldChannelVnName = FIELD_CHANNEL_VN_NAME;
    fieldChannelStatus = FIELD_CHANNEL_STATUS;

    get buttonLabel() {
        // When the add form is opened, always show 'Save Channel' on the button
        if (this.showForm) {
            return LABEL_BUTTON_SAVE_CHANNEL;
        }
        return LABEL_BUTTON_ADD_CHANNEL;
    }

    handleShowForm() {
        this.selectedId = null;
        this.showForm = true;
    }

    @wire(getChannels)
    wiredData(result) {
        this.wiredResult = result;
        if (result.data) {
            this.channels = result.data;
            showLog('Load Channels Success', result.data);
        } else if (result.error) {
            showLog('Load Channels Error', result.error);
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.selectedId = row.Id;
            this.showForm = true;
            // Optionally, scroll to form or focus first input for better UX
        } else if (actionName === 'delete') {
            this.handleDelete(row.Id);
        }
    }

    async handleSuccess() {
        this.showToast(LABEL_TOAST_SAVE_SUCCESS, '', VARIANT_SUCCESS);
        this.selectedId = null;
        this.showForm = false;
        await refreshApex(this.wiredResult);
    }

    async handleCancel() {
        this.selectedId = null;
        this.showForm = false;
        await refreshApex(this.wiredResult);
    }

    async handleDelete(id) {
        if (!id) {
            this.showToast('Lỗi', 'ID bản ghi không hợp lệ', 'error');
            return;
        }
        // Disable UI or show spinner here if desired
        if (confirm(LABEL_CONFIRM_DELETE_CHANNEL)) {
            try {
                await deleteChannel({ recordId: id });
                this.showToast(LABEL_TOAST_DELETE_SUCCESS, '', VARIANT_SUCCESS);
                await refreshApex(this.wiredResult);
            } catch (error) {
                const msg = error?.body?.message || 'Đã xảy ra lỗi khi xóa bản ghi';
                this.showToast(LABEL_TOAST_ERROR_GENERIC, msg, VARIANT_ERROR);
            }
        }
    }

    handleError(event) {
        const msg = event?.detail?.detail || 'Lỗi hệ thống không xác định';
        this.showToast(LABEL_TOAST_ERROR_GENERIC, msg, VARIANT_ERROR);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}