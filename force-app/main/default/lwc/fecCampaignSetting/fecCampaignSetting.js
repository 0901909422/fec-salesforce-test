import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCampaignMappings from '@salesforce/apex/FecCampaignController.getCampaignMappings';
import getCampaignConfigs from '@salesforce/apex/FecCampaignController.getCampaignConfigs';
import saveMapping from '@salesforce/apex/FecCampaignController.saveMapping';
import deleteMapping from '@salesforce/apex/FecCampaignController.deleteMapping';

// Cấu hình cột cho Datatable
const COLUMNS = [
    { label: 'CS Campaign Name', fieldName: 'Name' },
    { label: 'Genesys Campaign', fieldName: 'GenesysName' },
    { label: 'Active', fieldName: 'FEC_IsActive__c', type: 'boolean' },
    {
        type: 'action',
        typeAttributes: { rowActions: [
            { label: 'Edit', name: 'edit' },
            { label: 'Delete', name: 'delete' }
        ] }
    }
];

export default class FecCampaignSettings extends LightningElement {
    columns = COLUMNS;
    @track mappingList = [];
    @track genesysOptions = [];
    isModalOpen = false;
    modalTitle = 'New Campaign Mapping';
    isLoading = false;
    wiredMappingResult;

    @track currentRecord = {
        Id: null,
        Name: '',
        FEC_Campaign__c: '',
        FEC_IsActive__c: true
    };

    @wire(getCampaignMappings)
    wiredMappings(result) {
        this.wiredMappingResult = result;
        if (result.data) {
            this.mappingList = result.data.map(row => ({
                ...row,
                GenesysName: row.FEC_Campaign__r ? row.FEC_Campaign__r.Name : ''
            }));
        } else if (result.error) {
            this.showToast('Error', 'Không tải được danh sách Mapping', 'error');
        }
    }

    @wire(getCampaignConfigs)
    wiredOptions({ data, error }) {
        if (data) {
            this.genesysOptions = data.map(camp => ({
                label: camp.FEC_CampaignId__c,
                value: camp.Id
            }));
        }
    }

    handleOpenModal() {
        this.resetForm();
        this.modalTitle = 'New Campaign Mapping';
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'edit') {
            this.currentRecord = { ...row };
            this.modalTitle = 'Edit Mapping: ' + row.Name;
            this.isModalOpen = true;
        } else if (actionName === 'delete') {
            this.handleDelete(row.Id);
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this.currentRecord[field] = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
    }

    handleCampaignChange(event) {
        this.currentRecord.FEC_Campaign__c = event.detail.value;
    }

    async handleSave() {
        if (!this.currentRecord.Name || !this.currentRecord.FEC_Campaign__c) {
            this.showToast('Lỗi', 'Vui lòng nhập CS Name và chọn Genesys Campaign', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            await saveMapping({ mappingData: this.currentRecord });
            this.showToast('Thành công', 'Đã lưu Mapping', 'success');
            this.handleCloseModal();
            refreshApex(this.wiredMappingResult);
        } catch (error) {
            this.showToast('Lỗi', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleDelete(recordId) {
        this.isLoading = true;
        try {
            await deleteMapping({ recordId: recordId });
            this.showToast('Thành công', 'Đã xóa Mapping', 'success');
            refreshApex(this.wiredMappingResult);
        } catch (error) {
            this.showToast('Lỗi xóa', error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.currentRecord = {
            Id: null,
            Name: '',
            FEC_Campaign__c: '',
            FEC_IsActive__c: true
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}