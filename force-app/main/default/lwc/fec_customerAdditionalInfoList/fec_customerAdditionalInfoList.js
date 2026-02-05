import { LightningElement, track, wire } from 'lwc';
import { HEADER_ACTIONS, VIEW_HISTORY_ACTION, EDIT_ACTION } from 'c/fecUtils';
import { refreshApex } from '@salesforce/apex';
import getUploadedConfigs from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getUploadedConfigs';
import getExistingConfigs from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getExistingConfigs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import labels
import customerDataManagement from '@salesforce/label/c.FEC_Customer_Data_Management';
import addNew from '@salesforce/label/c.FEC_Btn_Add_New';
import reload from '@salesforce/label/c.FEC_Btn_Reload';
import titlePendingProcess from '@salesforce/label/c.FEC_Title_Pending_Process';
import titleExistingFields from '@salesforce/label/c.FEC_Title_Existing_Fields';
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

export default class FecCustomerAdditionalInfoList extends LightningElement {
    label = {
        customerDataManagement,
        addNew,
        reload,
        titlePendingProcess,
        titleExistingFields
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
            type: 'button', 
            initialWidth: 100, 
            typeAttributes: { 
                label: LBL_HISTORY, 
                name: VIEW_HISTORY_ACTION, 
                variant: 'brand-outline' 
            }
        },
        { 
            type: 'button-icon', 
            fixedWidth: 50, 
            typeAttributes: { 
                iconName: 'utility:edit', 
                name: EDIT_ACTION, 
                variant: 'bare' 
            }
        }
    ];
    @track columnsPending = [
        { label: LBL_DATA_LINKAGE, fieldName: 'FEC_KeyIdentifier__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_FIELD_ID, fieldName: 'FEC_FieldID__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_FIELD_NAME, fieldName: 'FEC_FieldName__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_STATUS, fieldName: 'FEC_Status__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_START_DATE, fieldName: 'FEC_StartDate__c', type: 'date', sortable: true, actions: HEADER_ACTIONS },
        { label: LBL_END_DATE, fieldName: 'FEC_EndDate__c', type: 'date', sortable: true, actions: HEADER_ACTIONS },
        { 
            type: 'button-icon', 
            fixedWidth: 50, 
            typeAttributes: { 
                iconName: 'utility:edit', 
                name: EDIT_ACTION, 
                variant: 'bare'
            } 
        }
    ];
    @track DEFAULT_FORM_DATA = {
        FEC_KeyIdentifier__c: '',
        FEC_FieldID__c: '',
        FEC_FieldName__c: '',
        FEC_IsActive__c: true,
        FEC_Status__c: 'New',
        FEC_StartDate__c: new Date()
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
            this.uploadedData = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Không thể tải dữ liệu', 'error');
        }
    }

    @wire(getExistingConfigs)
    wiredProcessed(result) {
        this.wiredProcessedResults = result;
        if (result.data) {
            this.processedData = result.data;
        }
    }

     // Row Actions
    handleProcessedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === VIEW_HISTORY_ACTION) this.openHistoryModal(row);
        else if (action === EDIT_ACTION) this.openEditModal(row);
    }
    
    handleUploadedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === EDIT_ACTION) {
            this.openEditModal(row);
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
            FEC_StartDate__c: row.FEC_StartDate__c,
            FEC_EndDate__c: row.FEC_EndDate__c
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