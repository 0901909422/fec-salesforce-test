import { LightningElement, track, wire } from 'lwc';
import { HEADER_ACTIONS } from 'c/fecUtils';
import { refreshApex } from '@salesforce/apex';
import getUploadedConfigs from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getUploadedConfigs';
import getExistingConfigs from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getExistingConfigs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FecCustomerAdditionalInfoList extends LightningElement {
    @track columnsProcessed = [
        { 
            label: 'Trường liên kết dữ liệu', fieldName: 'FEC_KeyIdentifier__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        }, 
        { 
            label: 'Tên trường dữ liệu', fieldName: 'FEC_FieldName__c', type: 'text', sortable: true, wrapText: true, 
            actions: HEADER_ACTIONS 
        }, 
        { 
            label: 'Tình trạng yêu cầu', fieldName: 'FEC_Status__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        },
        { 
            label: 'Khả dụng', fieldName: 'FEC_IsActive__c', type: 'boolean', sortable: true, 
            actions: HEADER_ACTIONS 
        },
        { 
            label: 'Ngày bắt đầu', fieldName: 'FEC_StartDate__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        },
        { 
            label: 'Ngày kết thúc', fieldName: 'FEC_EndDate__c', type: 'text', sortable: true,
            actions: HEADER_ACTIONS 
        },
        { type: 'button', initialWidth: 100, typeAttributes: { label: 'Lịch sử', name: 'view_history', variant: 'brand-outline' }},
        { type: 'button-icon', fixedWidth: 50, typeAttributes: { iconName: 'utility:edit', name: 'edit', variant: 'bare' }}
    ];
    @track columnsPending = [
        { label: 'Trường liên kết dữ liệu', fieldName: 'FEC_KeyIdentifier__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: 'Mã trường dữ liệu', fieldName: 'FEC_FieldID__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: 'Tên trường dữ liệu', fieldName: 'FEC_FieldName__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: 'Tình trạng yêu cầu', fieldName: 'FEC_Status__c', type: 'text', sortable: true, actions: HEADER_ACTIONS },
        { label: 'Ngày bắt đầu', fieldName: 'FEC_StartDate__c', type: 'date', sortable: true, actions: HEADER_ACTIONS },
        { label: 'Ngày kết thúc', fieldName: 'FEC_EndDate__c', type: 'date', sortable: true, actions: HEADER_ACTIONS },
        
        // CỘT HÀNH ĐỘNG 1: Edit Icon
        { 
            type: 'button-icon', 
            fixedWidth: 50, 
            typeAttributes: { 
                iconName: 'utility:edit', 
                name: 'edit', 
                variant: 'bare', 
                alternativeText: 'Chỉnh sửa'
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
    @track modalTitle = 'Thêm mới Trường Thông Tin';
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
        this.wiredProcessedResults = result; // Lưu lại để refreshApex
        if (result.data) {
            this.processedData = result.data;
        }
    }

     // Row Actions
    handleProcessedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'view_history') this.openHistoryModal(row);
        else if (action === 'edit') this.openEditModal(row);
    }
    
    handleUploadedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
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
        this.modalTitle = 'Thêm mới Trường Thông Tin';
        this.formData = { ...this.DEFAULT_FORM_DATA };
        this.isEditModalOpen = true;
    }
    openEditModal(row) {
        this.modalTitle = 'Chỉnh sửa: ' + row.FEC_KeyIdentifier__c;
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