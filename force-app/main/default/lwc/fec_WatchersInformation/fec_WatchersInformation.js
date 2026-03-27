import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { subscribe as lmsSubscribe, unsubscribe as lmsUnsubscribe, MessageContext } from 'lightning/messageService';
import WATCHER_REFRESH_CHANNEL from '@salesforce/messageChannel/FEC_Watcher_Refresh__c';
import getWatchersList from '@salesforce/apex/FEC_FollowUpController.getWatchersList';

const COLUMNS = [
    { label: 'User', fieldName: 'odtUser', type: 'text', sortable: true },
    { label: 'User Role', fieldName: 'odtUserRole', type: 'text', sortable: true },
    { label: 'Follow-up Type', fieldName: 'odtFollowUpType', type: 'text', sortable: true },
    { label: 'Date Time', fieldName: 'formattedDatetime', type: 'text', sortable: true }
];

export default class Fec_WatchersInformation extends NavigationMixin(LightningElement) {
    @api recordId;
    /** Flexipage ID của trang Case (vd: FEC_Customer_Case_Record_Page, FEC_Internal_Case_Record_Page) - dùng cho View All URL */
    @api flexipageId = 'FEC_Customer_Case_Record_Page';

    _watchers = [];
    error;
    isLoading = true;
    wiredWatchersResult;
    columns = COLUMNS;

    // Sorting
    sortedBy = 'formattedDatetime';
    sortDirection = 'desc';

    // Pagination
    currentPage = 1;
    pageSize = 10;
    _gotoPageValue;

    // Platform Event subscription
    subscription = null;
    channelName = '/event/FEC_Case_Follow_Update__e';

    // LMS subscription
    @wire(MessageContext) messageContext;
    lmsSubscription = null;

    connectedCallback() {
        this.subscribeToPlatformEvent();
        this.subscribeToLMS();
        this.registerErrorListener();
    }

    disconnectedCallback() {
        this.unsubscribeFromPlatformEvent();
        this.unsubscribeFromLMS();
    }

    subscribeToPlatformEvent() {
        if (this.subscription) return;
        
        subscribe(this.channelName, -1, (message) => {
            this.handlePlatformEvent(message);
        }).then(response => {
            this.subscription = response;
            console.log('Subscribed to Platform Event:', response.channel);
        }).catch(error => {
            console.error('Error subscribing to Platform Event:', error);
        });
    }

    unsubscribeFromPlatformEvent() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
                console.log('Unsubscribed from Platform Event');
                this.subscription = null;
            });
        }
    }

    handlePlatformEvent(message) {
        const eventCaseId = message.data.payload.FEC_Case_Id__c;
        if (eventCaseId === this.recordId) {
            console.log('Received Platform Event for Case:', eventCaseId);
            this.refreshData();
        }
    }

    subscribeToLMS() {
        if (this.lmsSubscription) return;
        this.lmsSubscription = lmsSubscribe(this.messageContext, WATCHER_REFRESH_CHANNEL, (message) => {
            if (message.caseId === this.recordId) {
                this.refreshData();
            }
        });
    }

    unsubscribeFromLMS() {
        if (this.lmsSubscription) {
            lmsUnsubscribe(this.lmsSubscription);
            this.lmsSubscription = null;
        }
    }

    registerErrorListener() {
        onError(error => {
            console.error('EMP API Error:', JSON.stringify(error));
        });
    }

    @wire(getWatchersList, { caseId: '$recordId' })
    wiredWatchers(result) {
        this.wiredWatchersResult = result;
        this.isLoading = false;
        if (result.data) {
            this._watchers = result.data.map(watcher => ({
                ...watcher,
                formattedDatetime: this.formatDatetime(watcher.odtDatetime)
            }));
            this.error = undefined;
            this.currentPage = 1;
        } else if (result.error) {
            this.error = result.error;
            this._watchers = [];
            this.showError('Lỗi khi tải danh sách Watchers: ' + (result.error.body?.message || result.error.message));
        }
    }

    @api
    refreshData() {
        this.isLoading = true;
        return refreshApex(this.wiredWatchersResult)
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error refreshing watchers:', error);
            });
    }

    handleRefresh() {
        this.refreshData();
    }

    // --- Computed getters ---

    get watchers() {
        const startIdx = (this.currentPage - 1) * this.pageSize;
        return this._watchers.slice(startIdx, startIdx + this.pageSize);
    }

    get hasWatchers() {
        return this._watchers && this._watchers.length > 0;
    }

    get watchersCount() {
        return this._watchers ? this._watchers.length : 0;
    }

    get cardTitle() {
        return `Watcher Information (${this.watchersCount})`;
    }

    get recordInfo() {
        const count = this.watchersCount;
        const sortCol = COLUMNS.find(c => c.fieldName === this.sortedBy);
        const sortLabel = sortCol ? sortCol.label : 'Date Time';
        return `${count} Item${count !== 1 ? 's' : ''} • Sorted by ${sortLabel}`;
    }

    get totalPages() {
        return Math.ceil(this.watchersCount / this.pageSize) || 1;
    }

    get showPagination() {
        return this.hasWatchers;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get pageSizeStr() {
        return String(this.pageSize);
    }

    get pageSizeOptions() {
        const sizes = [10, 20, 30, 40, 50];
        const opts = sizes.map(size => ({ label: String(size), value: String(size) }));
        const total = this.watchersCount;
        if (total > 0 && !sizes.includes(total)) {
            opts.push({ label: String(total), value: String(total) });
        }
        return opts;
    }

    get gotoPageInputValue() {
        return this._gotoPageValue || '';
    }

    get paginationLabel() {
        return `${this.currentPage} / ${this.totalPages}`;
    }

    // --- Sorting ---

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData();
    }

    sortData() {
        const data = [...this._watchers];
        const fieldName = this.sortedBy;
        const reverse = this.sortDirection === 'asc' ? 1 : -1;

        data.sort((a, b) => {
            const valA = a[fieldName] ? a[fieldName] : '';
            const valB = b[fieldName] ? b[fieldName] : '';
            return reverse * ((valA > valB) - (valB > valA));
        });

        this._watchers = data;
        this.currentPage = 1;
    }

    // --- Pagination ---

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.detail.value, 10);
        this.currentPage = 1;
    }

    handleViewAllKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleViewAll(event);
        }
    }

    handleViewAll(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        if (!this.recordId) {
            this.showError('Không tìm thấy Case.');
            return;
        }
        try {
            const ws = encodeURIComponent(`/lightning/r/Case/${this.recordId}/view`);
            const viewAllUrl = `/lightning/cmp/force__dynamicRelatedListViewAll?force__flexipageId=${encodeURIComponent(this.flexipageId)}&force__cmpId=lst_dynamicRelatedList4&force__recordId=${this.recordId}&ws=${ws}&uid=${Date.now()}`;

            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: viewAllUrl }
            });
        } catch (err) {
            console.error('View All navigation error:', err);
            this.showError(err?.body?.message || err?.message || 'Không thể điều hướng.');
        }
    }

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.currentPage++;
        }
    }

    handleGotoKeydown(event) {
        const allowed = ['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab', 'Home', 'End'];
        if (allowed.includes(event.key)) return;
        if (event.key < '0' || event.key > '9') {
            event.preventDefault();
        }
    }

    handleGoToPageInput(event) {
        const raw = event.target.value.replace(/\D/g, '');
        let val = parseInt(raw, 10);
        if (isNaN(val) || val < 1) {
            this._gotoPageValue = null;
            event.target.value = '';
            return;
        }
        if (val > this.totalPages) val = this.totalPages;
        this._gotoPageValue = val;
        event.target.value = String(val);
    }

    handleGoToPage() {
        if (this._gotoPageValue && this._gotoPageValue > 0 && this._gotoPageValue <= this.totalPages) {
            this.currentPage = this._gotoPageValue;
            this._gotoPageValue = null;
        }
    }

    // --- Helpers ---

    formatDatetime(datetimeValue) {
        if (!datetimeValue) return '';
        
        try {
            const date = new Date(datetimeValue);
            
            const day = String(date.getDate()).padStart(2, '0');
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const year = date.getFullYear();
            
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            const seconds = String(date.getSeconds()).padStart(2, '0');
            
            return `${day}/${month}/${year}, ${hours}:${minutes}:${seconds}`;
        } catch (e) {
            return String(datetimeValue);
        }
    }

    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }
}
