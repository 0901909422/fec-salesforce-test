import { LightningElement, api } from 'lwc';

const DEFAULT_PAGE_SIZE = 10;
const PAGE_SIZE_LIST = [10, 15, 20, 50, 100];
const MAX_VISIBLE_PAGES = 5;

export default class FecPagination extends LightningElement {
    @api currentPage = 1;
    @api totalRecords = 0;
    @api pageSize = DEFAULT_PAGE_SIZE;

    goToValue = '';

    // --- Computed ---

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get isPrevDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    get isGoToDisabled() {
        const v = parseInt(this.goToValue, 10);
        return !v || v < 1 || v > this.totalPages || v === this.currentPage;
    }

    get pageSizeOptions() {
        return PAGE_SIZE_LIST.map(s => ({
            value: String(s),
            label: String(s),
            selected: s === this.pageSize
        }));
    }

    get pageButtons() {
        const total = this.totalPages;
        const current = this.currentPage;
        const buttons = [];

        if (total <= MAX_VISIBLE_PAGES) {
            for (let i = 1; i <= total; i++) {
                buttons.push(this._buildBtn(i, current));
            }
        } else {
            let start = Math.max(1, current - Math.floor(MAX_VISIBLE_PAGES / 2));
            let end = start + MAX_VISIBLE_PAGES - 1;
            if (end > total) {
                end = total;
                start = Math.max(1, end - MAX_VISIBLE_PAGES + 1);
            }
            if (start > 1) {
                buttons.push(this._buildBtn(1, current));
                if (start > 2) {
                    buttons.push({ key: 'dots-start', label: '...', page: null, isCurrent: false, className: 'slds-button slds-button_neutral slds-button_small page-btn dots', ariaLabel: 'More pages', ariaCurrent: undefined });
                }
            }
            for (let i = start; i <= end; i++) {
                if (i === 1 && start > 1) continue;
                if (i === total && end < total) continue;
                buttons.push(this._buildBtn(i, current));
            }
            if (end < total) {
                if (end < total - 1) {
                    buttons.push({ key: 'dots-end', label: '...', page: null, isCurrent: false, className: 'slds-button slds-button_neutral slds-button_small page-btn dots', ariaLabel: 'More pages', ariaCurrent: undefined });
                }
                buttons.push(this._buildBtn(total, current));
            }
        }
        return buttons;
    }

    // --- Handlers ---

    handlePrev() {
        if (this.currentPage > 1) {
            this._firePage(this.currentPage - 1);
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this._firePage(this.currentPage + 1);
        }
    }

    handlePageClick(event) {
        const page = parseInt(event.currentTarget.dataset.page, 10);
        if (page && page !== this.currentPage) {
            this._firePage(page);
        }
    }

    handlePageSizeChange(event) {
        const newSize = parseInt(event.target.value, 10);
        this.dispatchEvent(new CustomEvent('pagesizechange', {
            detail: { pageSize: newSize }
        }));
    }

    handleGoToChange(event) {
        this.goToValue = event.target.value;
    }

    handleGoToKeyUp(event) {
        if (event.key === 'Enter') {
            this.handleGoTo();
        }
    }

    handleGoTo() {
        const page = parseInt(this.goToValue, 10);
        if (page && page >= 1 && page <= this.totalPages && page !== this.currentPage) {
            this._firePage(page);
            this.goToValue = '';
        }
    }

    // --- Private ---

    _firePage(page) {
        this.dispatchEvent(new CustomEvent('pagechange', {
            detail: { page }
        }));
    }

    _buildBtn(page, current) {
        const isCurrent = page === current;
        return {
            key: `p-${page}`,
            label: String(page),
            page,
            isCurrent,
            className: `slds-button slds-button_small page-btn ${isCurrent ? 'slds-button_brand current-page' : 'slds-button_neutral'}`,
            ariaLabel: `Page ${page}`,
            ariaCurrent: isCurrent ? 'page' : undefined
        };
    }
}