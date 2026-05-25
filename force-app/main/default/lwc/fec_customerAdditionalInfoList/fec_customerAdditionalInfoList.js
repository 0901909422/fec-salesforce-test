import { LightningElement, track, wire } from 'lwc';
import { getTomorrowDate, formatDateDDMMYYYY, HEADER_ACTIONS, VIEW_HISTORY_ACTION, EDIT_ACTION, DELETE_ACTION, DELETED_DATA_SUCCESSFULLY_MSG, DELETE_CONFIRMATION_TITLE, DELETE_CONFIRMATION_MSG, SUCCESS_TITLE, FAIL_TITLE, WARNING_TITLE, DELETABLE_STATUSES, EDITABLE_STATUSES } from 'c/fecUtils';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import deleteConfig from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.deleteConfig';
import getUploadedConfigs from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getUploadedConfigs';
import getExistingConfigs from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getExistingConfigs';
import triggerBatchProcessing from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.triggerBatchProcessing';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import labels
import customerDataManagement from '@salesforce/label/c.FEC_Customer_Data_Management';
import addNew from '@salesforce/label/c.FEC_Btn_Add_New';
import reload from '@salesforce/label/c.FEC_Btn_Reload';
import titlePendingProcess from '@salesforce/label/c.FEC_Title_Pending_Process';
import titleExistingFields from '@salesforce/label/c.FEC_Title_Existing_Fields';
import cannotRefreshDataMsg from '@salesforce/label/c.FEC_Cannot_Refresh_Data';
import LBL_ADD_NEW_MODAL_TITLE from '@salesforce/label/c.FEC_Lbl_Add_New_Modal_Title';
import LBL_EDIT_TITLE from '@salesforce/label/c.FEC_Lbl_Edit_Title';
import LBL_DATA_LINKAGE from '@salesforce/label/c.FEC_Lbl_Data_Linkage';
import LBL_FIELD_ID from '@salesforce/label/c.FEC_Lbl_Field_ID';
import LBL_FIELD_NAME from '@salesforce/label/c.FEC_Lbl_Field_Name';
import LBL_STATUS from '@salesforce/label/c.FEC_Lbl_Status';
import LBL_IS_ACTIVE from '@salesforce/label/c.FEC_Lbl_Is_Active';
import LBL_START_DATE from '@salesforce/label/c.FEC_Lbl_Start_Date';
import LBL_END_DATE from '@salesforce/label/c.FEC_Lbl_End_Date';
import LBL_HISTORY from '@salesforce/label/c.FEC_Title_Change_History';
import errorCannotDeleteStatus from '@salesforce/label/c.FEC_Error_Cannot_Delete_Status';
import processNow from '@salesforce/label/c.FEC_Btn_Process_Now';
import processNowSuccess from '@salesforce/label/c.FEC_Process_Now_Success';
import updatedAt from '@salesforce/label/c.FEC_Lbl_Updated_At';

export default class FecCustomerAdditionalInfoList extends LightningElement {
    label = {
        customerDataManagement,
        addNew,
        reload,
        titlePendingProcess,
        titleExistingFields,
        processNow,
        processNowSuccess,
        updatedAt
    };

    @track columnsProcessed = [
        { 
            label: LBL_DATA_LINKAGE, 
            fieldName: 'FEC_KeyIdentifier__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        }, 
        { 
            label: LBL_FIELD_NAME, 
            fieldName: 'FEC_FieldName__c', type: 'text', sortable: true, wrapText: true, 
            actions: HEADER_ACTIONS 
        }, 
        { 
            label: LBL_STATUS, 
            fieldName: 'FEC_Status__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        },
        { 
            label: LBL_IS_ACTIVE, 
            fieldName: 'FEC_IsActive__c', type: 'boolean', sortable: true, 
            actions: HEADER_ACTIONS 
        },
        { 
            label: LBL_START_DATE, 
            fieldName: 'FEC_StartDate__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        },
        { 
            label: LBL_END_DATE, 
            fieldName: 'FEC_EndDate__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        },
        {
            type: 'button-icon',
            initialWidth: 50,
            typeAttributes: {
                iconName: 'utility:edit',
                alternativeText: LBL_EDIT_TITLE,
                title: LBL_EDIT_TITLE,
                name: EDIT_ACTION,
                variant: 'bare',
                disabled: { fieldName: 'disableEdit' }
            }
        },
        { 
            type: 'button-icon', 
            initialWidth: 50, 
            typeAttributes: { 
                iconName: 'utility:date_time',
                alternativeText: LBL_HISTORY,
                title: LBL_HISTORY,
                name: VIEW_HISTORY_ACTION, 
                variant: 'bare' 
            }
        }
    ];
    @track columnsPending = [
        { label: LBL_DATA_LINKAGE, fieldName: 'FEC_KeyIdentifier__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_FIELD_NAME, fieldName: 'FEC_FieldName__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_STATUS, fieldName: 'FEC_Status__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_START_DATE, fieldName: 'FEC_StartDate__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_END_DATE, fieldName: 'FEC_EndDate__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: updatedAt, fieldName: 'LastModifiedDate', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        {
            type: 'button-icon',
            initialWidth: 50,
            typeAttributes: {
                iconName: 'utility:edit',
                alternativeText: LBL_EDIT_TITLE,
                title: LBL_EDIT_TITLE,
                name: EDIT_ACTION,
                variant: 'bare',
                disabled: { fieldName: 'disableEdit' }
            }
        },
        {
            type: 'button-icon',
            initialWidth: 50,
            typeAttributes: {
                iconName: 'utility:delete',
                alternativeText: DELETE_CONFIRMATION_TITLE,
                title: DELETE_CONFIRMATION_TITLE,
                name: DELETE_ACTION,
                variant: 'bare',
                disabled: { fieldName: 'disableDelete' }
            }
        }
    ];
    @track DEFAULT_FORM_DATA = {
        FEC_KeyIdentifier__c: '',
        FEC_FieldID__c: '',
        FEC_FieldName__c: '',
        FEC_IsActive__c: true,
        FEC_StartDate__c: getTomorrowDate()
    };
    
    @track uploadedData = []; 
    @track processedData = []; 
    @track historyData = [];
    
    // Modal
    @track isHistoryModalOpen = false;
    @track isEditModalOpen = false;
    @track modalTitle = LBL_ADD_NEW_MODAL_TITLE;
    @track formData = { ...this.DEFAULT_FORM_DATA };
    @track configId;
    @track isLoading = false;

    wiredPendingResults;
    wiredProcessedResults;

    @wire(getUploadedConfigs)
    wiredConfigs(result) {
        this.wiredPendingResults = result;
        if (result.data) {
            this.uploadedData = result.data.map(row => {
                return {
                    ...row,
                    _rawStartDate: row.FEC_StartDate__c,
                    _rawEndDate: row.FEC_EndDate__c,
                    FEC_StartDate__c: formatDateDDMMYYYY(row.FEC_StartDate__c),
                    FEC_EndDate__c: formatDateDDMMYYYY(row.FEC_EndDate__c),
                    LastModifiedDate: formatDateDDMMYYYY(row.LastModifiedDate),
                    disableEdit: !EDITABLE_STATUSES.has(row.FEC_Status__c),
                    disableDelete: !DELETABLE_STATUSES.has(row.FEC_Status__c)
                };
            });
        } else if (result.error) {
            this.showToast(FAIL_TITLE, cannotRefreshDataMsg, 'error');
        }
    }

    @wire(getExistingConfigs)
    wiredProcessed(result) {
        this.wiredProcessedResults = result;
        if (result.data) {
            this.processedData = result.data.map(row => {
                return {
                    ...row,
                    _rawStartDate: row.FEC_StartDate__c,
                    _rawEndDate: row.FEC_EndDate__c,
                    FEC_StartDate__c: formatDateDDMMYYYY(row.FEC_StartDate__c),
                    FEC_EndDate__c: formatDateDDMMYYYY(row.FEC_EndDate__c),
                    disableEdit: !EDITABLE_STATUSES.has(row.FEC_Status__c)
                };
            });
        }
    }

     // Row Actions
    handleProcessedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === VIEW_HISTORY_ACTION) this.openHistoryModal(row);
        else if (action === EDIT_ACTION) {
            this.openEditModal(row);
        }
    }
    
    async handleUploadedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;

        if (action === EDIT_ACTION) {
            this.openEditModal(row);
        } else if (action === DELETE_ACTION) {
            await this.handleDeleteRow(row);
        }
    }
    
    async handleDeleteRow(row) {
        const result = await LightningConfirm.open({
            message: DELETE_CONFIRMATION_MSG,
            variant: 'header',
            label: DELETE_CONFIRMATION_TITLE,
            theme: 'warning',
        });

        if (result) {
            this.isLoading = true;
            try {
                await deleteConfig({ configId: row.Id });
                
                this.showToast(SUCCESS_TITLE, DELETED_DATA_SUCCESSFULLY_MSG, 'success');
                
                await this.handleReload();
            } catch (error) {
                this.showToast(FAIL_TITLE, error.body?.message || error.message, 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    async handleProcessNow() {
        this.isLoading = true;
        try {
            const result = await triggerBatchProcessing();
            this.showToast(SUCCESS_TITLE, result, 'success');
            await this.handleReload();
        } catch (error) {
            this.showToast(FAIL_TITLE, error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleReload() {
        this.isLoading = true;
        try {
            // Sử dụng Promise.all để refresh cả 2 song song cho nhanh
            await Promise.all([
                refreshApex(this.wiredPendingResults),
                refreshApex(this.wiredProcessedResults)
            ]);
        } catch (error) {
            console.error('Lỗi khi tải lại dữ liệu:', error);
        } finally {
            this.isLoading = false;
        }
    }

    openHistoryModal(data){
        this.configId = data.Id;
        this.isHistoryModalOpen = true; 
    }
    closeHistoryModal(){ this.isHistoryModalOpen = false; }
    handleAddNew() {
        this.modalTitle = LBL_ADD_NEW_MODAL_TITLE;
        this.formData = { ...this.DEFAULT_FORM_DATA };
        this.isEditModalOpen = true;
    }
    openEditModal(row) {
        this.modalTitle = LBL_EDIT_TITLE + ': ' + row.FEC_KeyIdentifier__c;
        this.formData = {
            Id: row.Id,
            FEC_KeyIdentifier__c: row.FEC_KeyIdentifier__c,
            FEC_FieldID__c: row.FEC_FieldID__c,
            FEC_FieldName__c: row.FEC_FieldName__c,
            FEC_IsActive__c: row.FEC_IsActive__c,
            FEC_Status__c: row.FEC_Status__c,
            FEC_StartDate__c: row._rawStartDate,
            FEC_EndDate__c: row._rawEndDate
        };
        this.isEditModalOpen = true;
    }
    handleCloseModal() { this.isEditModalOpen = false; }
    async handleSaveModal() {
        await this.handleReload();
        this.handleCloseModal();
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}