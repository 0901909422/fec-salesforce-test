import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { refreshApex } from '@salesforce/apex';
import { subscribe, MessageContext } from 'lightning/messageService';
import getHistory from '@salesforce/apex/FEC_GeneralAssignmentHistoryController.getHistory';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';
import FEC_GA_SAVED from '@salesforce/messageChannel/FEC_GA_Saved__c';

// tungnm37: WATCH_FIELDS bỏ vì component dùng chung cho cả 2 object

export default class Fec_GeneralAssignmentHistory extends LightningElement {
    @api recordId;
    @track allHistories = [];
    @track pageNumber = 1;
    @track pageSize = 10;
    @track goToPage = 1;
    _wiredHistoryResult;
    _firstLoad = true;
    @wire(MessageContext) messageContext;

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
    }

    @api
    refresh() {
        if (this._wiredHistoryResult) {
            refreshApex(this._wiredHistoryResult);
        }
    }

    @wire(getHistory, { recordId: '$recordId' })
    wiredHistory(result) {
        this._wiredHistoryResult = result;
        if (result.data) {
            this.allHistories = result.data;
            this.pageNumber = 1;
        } else if (result.error) {
            this.allHistories = [];
        }
    }

    get histories() {
        const start = (this.pageNumber - 1) * this.pageSize;
        return this.allHistories.slice(start, start + this.pageSize);
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.allHistories.length / this.pageSize));
    }

    get isFirstPage() { return this.pageNumber === 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }

    get columns() {
        return [
            { label: 'Date', fieldName: 'CreatedDate', type: 'date',
              typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
            { label: 'User', fieldName: 'User', type: 'text' },
            { label: 'Field', fieldName: 'Field', type: 'text' },
            { label: 'Original Value', fieldName: 'OldValue', type: 'text' },
            { label: 'New Value', fieldName: 'NewValue', type: 'text' }
        ];
    }

    get showEmptyTable() { return !this.allHistories || this.allHistories.length === 0; }

    handlePrev() { if (!this.isFirstPage) { this.pageNumber--; this.goToPage = this.pageNumber; } }
    handleNext() { if (!this.isLastPage) { this.pageNumber++; this.goToPage = this.pageNumber; } }

    handleGoToPage(event) {
        this.goToPage = event.target.value;
    }

    handleGo() {
        const p = parseInt(this.goToPage, 10);
        if (p >= 1 && p <= this.totalPages) {
            this.pageNumber = p;
        }
    }

    handlePageSizeChange(event) {
        const size = parseInt(event.target.value, 10);
        if (size > 0) {
            this.pageSize = size;
            this.pageNumber = 1;
            this.goToPage = 1;
        }
    }
}

