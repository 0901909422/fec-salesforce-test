import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCaseChannels from '@salesforce/apex/FEC_CaseChannelController.getCaseChannels';
import saveCaseChannel from '@salesforce/apex/FEC_CaseChannelController.saveCaseChannel';
import deleteCaseChannel from '@salesforce/apex/FEC_CaseChannelController.deleteCaseChannel';
import { showLog } from 'c/fecMDMUtils';

const COLUMNS = [
    { label: 'Channel Name', fieldName: 'Name', type: 'text' },
    { label: 'Code', fieldName: 'FEC_Code__c', type: 'text' },
    { label: 'Channel Status', fieldName: 'FEC_Channel_Status__c', type: 'boolean' },
    { label: 'Self Service Flag', fieldName: 'FEC_Self_Service_Flag__c', type: 'boolean' },
    { label: 'Status', fieldName: 'FEC_Status__c', type: 'boolean' },
    { label: 'Name VN', fieldName: 'FEC_Name_VN__c', type: 'text' },
    { label: 'Alias', fieldName: 'FEC_Alias__c', type: 'text' },
    { label: 'Process Status', fieldName: 'Process_Change_Status__c', type: 'text' },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Edit', name: 'edit' }, { label: 'Delete', name: 'delete' }] }
    }
];

export default class FecCaseChannelManagement extends LightningElement {
    @track caseChannels = [];
    @track isLoading = false;
    @track isModalOpen = false;
    @track recordIdForEdit = null;
    @track formData = {
        name: '',
        code: '',
        channelStatus: false,
        selfServiceFlag: false,
        status: true,
        nameVN: '',
        alias: ''
    };

    columns = COLUMNS;
    wiredCaseChannelsResult;

    get modalTitle() {
        return this.recordIdForEdit ? 'Edit Case Channel' : 'New Case Channel';
    }

    @wire(getCaseChannels)
    wiredCaseChannels(result) {
        this.wiredCaseChannelsResult = result;
        const { data, error } = result;
        if (data) {
            showLog('[wiredCaseChannels] Data received', data);
            this.caseChannels = data;
            this.isLoading = false;
        } else if (error) {
            showLog('[wiredCaseChannels] Error', error);
            this.showToast('Error', 'Failed to load Case Channels', 'error');
            this.isLoading = false;
        }
    }

    handleAddNew() {
        this.recordIdForEdit = null;
        this.formData = {
            name: '',
            code: '',
            channelStatus: false,
            selfServiceFlag: false,
            status: true,
            nameVN: '',
            alias: ''
        };
        this.isModalOpen = true;
    }

    handleEditRow(recordId) {
        const record = this.caseChannels.find(r => r.Id === recordId);
        if (record) {
            this.recordIdForEdit = recordId;
            this.formData = {
                name: record.Name,
                code: record.FEC_Code__c,
                channelStatus: record.FEC_Channel_Status__c,
                selfServiceFlag: record.FEC_Self_Service_Flag__c,
                status: record.FEC_Status__c,
                nameVN: record.FEC_Name_VN__c,
                alias: record.FEC_Alias__c
            };
            this.isModalOpen = true;
        }
    }

    handleDeleteRow(recordId) {
        if (confirm('Are you sure you want to delete this record?')) {
            this.isLoading = true;
            deleteCaseChannel({ recordId })
                .then(() => {
                    this.showToast('Success', 'Record deleted successfully', 'success');
                    return refreshApex(this.wiredCaseChannelsResult);
                })
                .catch(error => {
                    showLog('[handleDeleteRow] Error', error);
                    this.showToast('Error', error.body?.message || 'Delete failed', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        
        if (action === 'edit') {
            this.handleEditRow(row.Id);
        } else if (action === 'delete') {
            this.handleDeleteRow(row.Id);
        }
    }

    handleInputChange(event) {
        const fieldName = event.target.dataset.fieldName;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.formData = { ...this.formData, [fieldName]: value };
    }

    handleSave() {
        if (!this.formData.name) {
            this.showToast('Validation Error', 'Channel Name is required', 'error');
            return;
        }

        this.isLoading = true;

        const mappingReq = {
            Id: this.recordIdForEdit,
            Name: this.formData.name,
            FEC_Code__c: this.formData.code,
            FEC_Channel_Status__c: this.formData.channelStatus,
            FEC_Self_Service_Flag__c: this.formData.selfServiceFlag,
            FEC_Status__c: this.formData.status,
            FEC_Name_VN__c: this.formData.nameVN,
            FEC_Alias__c: this.formData.alias
        };

        saveCaseChannel({ mappingReq })
            .then(() => {
                this.showToast('Success', 'Record saved successfully', 'success');
                this.isModalOpen = false;
                return refreshApex(this.wiredCaseChannelsResult);
            })
            .catch(error => {
                showLog('[handleSave] Error', error);
                this.showToast('Error', error.body?.message || 'Save failed', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.isModalOpen = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}