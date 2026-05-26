import { LightningElement, track, wire } from 'lwc';
import getAdditionalInfoRecords from '@salesforce/apex/FEC_AdditionalInfoController.getAdditionalInfoRecords';
import deleteRecord from '@salesforce/apex/FEC_AdditionalInfoController.deleteRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LABEL_SEARCH_ALL from '@salesforce/label/c.FEC_Search_All_Columns';

const PAGE_SIZE = 15;

const ACTIONS = [
    { label: 'Edit', name: 'edit' },
    { label: 'Delete', name: 'delete' }
];

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Case', fieldName: 'CaseNumber', type: 'text', sortable: true },
    { label: 'Callback', fieldName: 'FEC_Callback__c', type: 'text', sortable: true },
    { label: 'Callback Reason', fieldName: 'FEC_Callback_Reason__c', type: 'text', sortable: true },
    { label: 'Gender', fieldName: 'FEC_Gender__c', type: 'text', sortable: true },
    { label: 'Registered Phone', fieldName: 'FEC_Registered_Phone_Number__c', type: 'phone', sortable: true },
    { label: 'Settlement Category', fieldName: 'FEC_Settlement_Request_Category__c', type: 'text', sortable: true },
    { label: 'Verify Info', fieldName: 'FEC_Verify_Information__c', type: 'text', sortable: true },
    { label: 'NPS Score', fieldName: 'FEC_Q15_NPS_Score__c', type: 'text', sortable: true },
    { label: 'Issue Resolved', fieldName: 'FEC_Q9_Customer_Issue_Resolved__c', type: 'text', sortable: true },
    { type: 'action', typeAttributes: { rowActions: ACTIONS } }
];

const SEARCHABLE_FIELDS = COLUMNS.filter(c => c.fieldName).map(c => c.fieldName);

export default class FecAdditionalInfoList extends LightningElement {

    @track allData = [];
    @track error;
    @track isLoading = false;
    @track isModalOpen = false;
    @track recordIdForEdit = null;
    @track showDeleteConfirm = false;
    @track recordIdToDelete = null;
    @track modalTitle = '';

    columns = COLUMNS;
    sortedBy;
    sortDirection = 'asc';
    wiredRecordsResult;

    // Search & Pagination
    searchTerm = '';
    currentPage = 1;
    pageSize = PAGE_SIZE;
    labelSearchAll = LABEL_SEARCH_ALL;

    @wire(getAdditionalInfoRecords)
    wiredRecords(result) {
        this.wiredRecordsResult = result;
        this.isLoading = true;
        if (result.data) {
            this.allData = result.data.map(record => ({
                ...record,
                CaseNumber: record.FEC_Case__r ? record.FEC_Case__r.CaseNumber : null
            }));
            this.error = undefined;
            this.currentPage = 1;
        } else if (result.error) {
            this.error = result.error;
            this.allData = [];
            this.showToast('Error', result.error.body?.message || result.error.message || 'Failed to load Additional Info records.', 'error');
        }
        this.isLoading = false;
    }

    // --- Search & Pagination ---

    get filteredData() {
        const term = this.searchTerm.toLowerCase().trim();
        if (!term) return this.allData;
        return this.allData.filter(row =>
            SEARCHABLE_FIELDS.some(field => {
                const val = row[field];
                if (val == null) return false;
                return String(val).toLowerCase().includes(term);
            })
        );
    }

    get pagedData() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.filteredData.slice(start, start + this.pageSize);
    }

    get totalFilteredRecords() {
        return this.filteredData.length;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.currentPage = 1;
    }

    handlePageChange(event) {
        this.currentPage = event.detail.page;
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.pageSize;
        this.currentPage = 1;
    }

    // --- Original handlers ---

    openNewModal() {
        this.isModalOpen = true;
        this.recordIdForEdit = null;
        this.modalTitle = 'New Additional Info';
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'edit':
                this.handleEdit(row.Id);
                break;
            case 'delete':
                this.handleDelete(row);
                break;
            default:
        }
    }

    handleEdit(recordId) {
        this.recordIdForEdit = recordId;
        this.isModalOpen = true;
        this.modalTitle = 'Edit Additional Info';
    }

    handleDelete(row) {
        this.recordIdToDelete = row.Id;
        this.showDeleteConfirm = true;
    }

    async confirmDelete() {
        this.isLoading = true;
        try {
            await deleteRecord({ recordId: this.recordIdToDelete });
            this.showToast('Success', 'Record deleted successfully.', 'success');
            if (this.wiredRecordsResult) {
                await refreshApex(this.wiredRecordsResult);
            }
        } catch (error) {
            this.showToast('Error', error?.body?.message || error?.message || 'Failed to delete record.', 'error');
        } finally {
            this.showDeleteConfirm = false;
            this.recordIdToDelete = null;
            this.isLoading = false;
        }
    }

    cancelDelete() {
        this.showDeleteConfirm = false;
        this.recordIdToDelete = null;
    }

    handleSuccess() {
        this.closeModal();
        this.showToast('Success', 'Record saved successfully.', 'success');
        if (this.wiredRecordsResult) {
            refreshApex(this.wiredRecordsResult);
        }
    }

    handleCancelEvent() {
        this.closeModal();
    }

    closeModal() {
        this.isModalOpen = false;
        this.recordIdForEdit = null;
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortDirection);
    }

    sortData(fieldName, direction) {
        const isReverse = direction === 'asc' ? 1 : -1;
        this.allData = [...this.allData].sort((x, y) => {
            const a = x[fieldName] == null ? '' : x[fieldName];
            const b = y[fieldName] == null ? '' : y[fieldName];
            return isReverse * ((a > b) - (b > a));
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}