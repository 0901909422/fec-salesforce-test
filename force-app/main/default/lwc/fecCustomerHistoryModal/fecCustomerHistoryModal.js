import { LightningElement, track, wire, api } from 'lwc';
import getConfigHistory from '@salesforce/apex/FEC_CustomerAdditionalInfoListController.getConfigHistory';

export default class FecCustomerHistoryModal extends LightningElement {
    @api configId;
    
    @track historyData = [];
    @track columns = [];
    @track isLoading = false;

    columns = [
        { label: 'Trường liên kết dữ liệu', fieldName: 'FEC_KeyIdentifier__c', type: 'text' },
        { label: 'Tên trường dữ liệu', fieldName: 'FEC_FieldID__c', type: 'text' },
        { label: 'Tình trạng', fieldName: 'FEC_Status__c', type: 'text', sortable: true },
        { label: 'Khả dụng', fieldName: 'FEC_IsActive__c', type: 'boolean', sortable: true },
        { 
            label: 'Ngày bắt đầu', 
            fieldName: 'FEC_StartDate__c', 
            type: 'date', 
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric' },
            sortable: true
        },
        { 
            label: 'Ngày hoàn tất', 
            fieldName: 'FEC_EndDate__c', 
            type: 'date', 
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric' },
            sortable: true 
        },
        { label: 'Tạo bởi', fieldName: 'CreatedByName', type: 'text', sortable: true },
        { 
            label: 'Ngày tạo', 
            fieldName: 'CreatedDate', 
            type: 'date',
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' },
            sortable: true
        },
        { label: 'Sửa đổi bởi', fieldName: 'ModifiedByName', type: 'text' },
        { 
            label: 'Ngày sửa đổi', 
            fieldName: 'LastModifiedDate', 
            type: 'date',
            typeAttributes: { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' },
            sortable: true
        }
    ];

    async connectedCallback() {
        this.fetchData();
    }

    async fetchData() {
        this.isLoading = true;
        try {
            const data = await getConfigHistory({ configId: this.configId });
            this.historyData = data.map(row => ({
                ...row,
                CreatedByName: row.CreatedBy?.Name,
                ModifiedByName: row.LastModifiedBy?.Name
            }));
        } catch (error) {
            console.error('Error:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}