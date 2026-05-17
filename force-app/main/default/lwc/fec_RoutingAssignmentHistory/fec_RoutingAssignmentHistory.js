import { LightningElement, api, wire, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';
import LABEL_HISTORY_TITLE from '@salesforce/label/c.FEC_Label_RA_History';
import LABEL_PAGE_SIZE from '@salesforce/label/c.FEC_Label_Page_Size';
import LABEL_GO_TO_PAGE from '@salesforce/label/c.FEC_Label_Go_To_Page';
import LABEL_GO from '@salesforce/label/c.FEC_Label_Go';
import LABEL_NO_HISTORY from '@salesforce/label/c.FEC_Label_No_History';
import getRoutingAssignmentHistory from '@salesforce/apex/FEC_NocRoutingAssignmentController.getRoutingAssignmentHistory';

export default class Fec_RoutingAssignmentHistory extends LightningElement {
    @api recordId;
    @track allHistories = [];
    @track pageNumber = 1;
    @track pageSize = 10;
    @track goToPage = 1;

    labels = {
        historyTitle: LABEL_HISTORY_TITLE,
        pageSize: LABEL_PAGE_SIZE,
        goToPage: LABEL_GO_TO_PAGE,
        go: LABEL_GO,
        noHistory: LABEL_NO_HISTORY,
        ofPages: 'of'
    };

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
    }

    @wire(getRoutingAssignmentHistory, { recordId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.allHistories = data;
            this.pageNumber = 1;
        } else if (error) {
            this.allHistories = [];
        }
    }

    @api refresh() {
        // wire auto-refreshes when recordId changes
    }

    get histories() {
        const start = (this.pageNumber - 1) * this.pageSize;
        return this.allHistories.slice(start, start + this.pageSize);
    }

    get totalPages() { return Math.max(1, Math.ceil(this.allHistories.length / this.pageSize)); }
    get isFirstPage() { return this.pageNumber === 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }
    get showEmpty() { return !this.allHistories || this.allHistories.length === 0; }

    get columns() {
        return [
            { label: 'Date', fieldName: 'historyDate', type: 'text' },
            { label: 'Field', fieldName: 'historyField', type: 'text' },
            { label: 'User', fieldName: 'userName', type: 'text' },
            { label: 'Original Value', fieldName: 'oldValue', type: 'text' },
            { label: 'New Value', fieldName: 'newValue', type: 'text' }
        ];
    }

    handlePrev() { if (!this.isFirstPage) { this.pageNumber--; this.goToPage = this.pageNumber; } }
    handleNext() { if (!this.isLastPage) { this.pageNumber++; this.goToPage = this.pageNumber; } }
    handleGoToPage(e) { this.goToPage = e.target.value; }
    handleGo() {
        const p = parseInt(this.goToPage, 10);
        if (p >= 1 && p <= this.totalPages) this.pageNumber = p;
    }
    handlePageSizeChange(e) {
        const s = parseInt(e.target.value, 10);
        if (s > 0) { this.pageSize = s; this.pageNumber = 1; this.goToPage = 1; }
    }
}
