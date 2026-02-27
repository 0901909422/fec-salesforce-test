import { LightningElement, api, track } from 'lwc';

export default class Fec_RelatedListPaging extends LightningElement {

    /* ================= API ================= */
    @api columns = [];
    @api sortedBy;
    @api pageSize = 10;
    @api showRefresh = false;
    @api updatedTime; // Timestamp or Date object
    @api hideRowNumber = false; // Hide row number column

    /* ================= STATE ================= */
    _records = [];
    @track currentPage = 1;
    _gotoPage;
    
    // Sorting state - single column sort (giống fec_CustomTablePaging)
    sortedBy = null;
    sortedDirection = 'asc';

    /* ===== NEW: eye mask state ===== */
    @track eyeStates = {};

    /* ===== hover state ===== */
    @track hoverCell = {
        rowId: null,
        fieldName: null
    };

    /* ================= RECORDS ================= */
    @api
    get records() {
        return this._records;
    }
    set records(value) {
        this._records = Array.isArray(value) ? [...value] : [];
        this.currentPage = 1;
        
        // Re-apply existing sort if any
        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        }
        
        this.eyeStates = {};
    }

    /* ================= GETTERS ================= */
    get hasRecords() {
        return this._records.length > 0;
    }

    get recordCount() {
        return this._records.length;
    }

    get recordCountPlural() {
        return this.recordCount !== 1 ? 's' : '';
    }

    get totalPages() {
        return Math.ceil(this.recordCount / this.pageSize) || 1;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    /* ================= SORTED BY LABEL (Single Column - giống fec_CustomTablePaging) ================= */
    /**
     * Get the label of the currently sorted field for display in header.
     */
    get currentSortedByLabel() {
        if (!this.sortedBy) return '';
        const sortedCol = this.columns.find(col => col.fieldName === this.sortedBy);
        return sortedCol ? sortedCol.label : '';
    }

    /* ================= UPDATED TIME (giống fec_CustomTablePaging) ================= */
    /**
     * Format updated time for display.
     */
    get updatedTimeLabel() {
        if (!this.updatedTime) return '';
        
        const now = new Date();
        const updated = new Date(this.updatedTime);
        const diffMs = now - updated;
        const diffMins = Math.floor(diffMs / 60000);
        
        if (diffMins < 1) return 'Updated just now';
        if (diffMins === 1) return 'Updated 1 minute ago';
        if (diffMins < 60) return `Updated ${diffMins} minutes ago`;
        
        const diffHours = Math.floor(diffMins / 60);
        if (diffHours === 1) return 'Updated 1 hour ago';
        if (diffHours < 24) return `Updated ${diffHours} hours ago`;
        
        const diffDays = Math.floor(diffHours / 24);
        if (diffDays === 1) return 'Updated 1 day ago';
        return `Updated ${diffDays} days ago`;
    }

    /* ================= SORT UI ================= */
    get columnsWithSort() {
        return this.columns.map(col => {
            const isSorted = this.sortedBy === col.fieldName;
            
            return {
                ...col,
                iconName: isSorted
                    ? (this.sortedDirection === 'asc'
                        ? 'utility:arrowup'
                        : 'utility:arrowdown')
                    : 'utility:arrowdown',
                iconClass: isSorted
                    ? 'sort-icon active'
                    : 'sort-icon inactive'
            };
        });
    }

    /* ================= PAGING ================= */
    get pagedRecords() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this._records.slice(start, start + this.pageSize);
    }

    /* ================= DISPLAY RECORDS ================= */
    get displayRecords() {
        return this.pagedRecords.map((row, index) => {

            const rowIndex = (this.currentPage - 1) * this.pageSize + index;

            return {
                id: row.Id || `${this.currentPage}-${index}`,
                rowNumber: rowIndex + 1,
                cells: this.columns.map(col => {

                    /* ===== LINK TYPE ===== */
                    if (col.type === 'link') {
                        const hoverItems = Array.isArray(col.hoverFields)
                            ? col.hoverFields.map(h => ({
                                label: h.label,
                                value: h.fieldName
                                    ? (row[h.fieldName] ?? '-')
                                    : '-'
                            }))
                            : [];

                        return {
                            key: col.fieldName,
                            fieldName: col.fieldName,
                            isLink: true,
                            label: row[col.fieldName],
                            recordId: row[col.recordIdField],
                            hoverTitle: col.hoverTitle || col.label,
                            hoverItems,
                            hasHover: hoverItems.length > 0,
                            hoverBodyClass:
                                hoverItems.length === 1
                                    ? 'hover-body one-column'
                                    : 'hover-body two-column',
                            showHover:
                                hoverItems.length > 0 &&
                                this.hoverCell.rowId === row.Id &&
                                this.hoverCell.fieldName === col.fieldName
                        };
                    }

                    /* ===== EYE TYPE ===== */
                    if (col.type === 'eye') {
                        const eyeKey = `${rowIndex}-${col.fieldName}`;
                        const isMasked = this.eyeStates[eyeKey] !== false;
                        const rawValue = row[col.fieldName];

                        return {
                            key: col.fieldName,
                            isEye: true,
                            fieldName: col.fieldName,
                            rowIndex,
                            value: this.getEyeDisplayValue(rawValue, isMasked),
                            iconName: isMasked ? 'utility:hide' : 'utility:preview'
                        };
                    }

                    /* ===== RICH TEXT TYPE ===== */
                    if (col.type === 'richText') {
                        return {
                            key: col.fieldName,
                            isHtml: true,
                            value: row[col.fieldName]
                        };
                    }

                    /* ===== TEXT TYPE WITH DYNAMIC CLASS ===== */
                    let cellClass = '';
                    if (col.cellAttributes && col.cellAttributes.class) {
                        if (typeof col.cellAttributes.class === 'object' && col.cellAttributes.class.fieldName) {
                            cellClass = row[col.cellAttributes.class.fieldName] || '';
                        } else if (typeof col.cellAttributes.class === 'string') {
                            cellClass = col.cellAttributes.class;
                        }
                    }
                    /* ===== ADD NEGATIVE CHECK ===== */
                    const isNeg = this.isNegative(row[col.fieldName]);
                    if (isNeg) {
                        cellClass = (cellClass ? cellClass + ' ' : '') + 'text-negative';
                    }

                    return {
                        key: col.fieldName,
                        isLink: false,
                        isEye: false,
                        isHtml: false,
                        value: row[col.fieldName],
                        cellClass: cellClass,
                        alignment: col.cellAttributes?.alignment || 'left'
                    };
                })
            };
        });
    }

    /* ================= EYE HELPERS ================= */
    getEyeDisplayValue(value, isMasked) {
        if (!value) return value;
        if (!isMasked) return value;
        if (value.length < 7) return value;

        const first = value.substring(0, 4);
        const last = value.substring(value.length - 3);
        return `${first}***${last}`;
    }

    handleToggleEye(event) {
        const rowIndex = event.currentTarget.dataset.rowIndex;
        const fieldName = event.currentTarget.dataset.field;
        const key = `${rowIndex}-${fieldName}`;

        this.eyeStates = {
            ...this.eyeStates,
            [key]: !(this.eyeStates[key] !== false)
        };
    }

    /* ================= HOVER ================= */
   handleMouseEnter(event) {
        const wrapper = event.currentTarget;

        this.hoverCell = {
            rowId: wrapper.dataset.rowId,
            fieldName: wrapper.dataset.field
        };

        requestAnimationFrame(() => {
            const hover = wrapper.querySelector('.hover-popover');
            if (!hover) return;

            hover.style.visibility = 'hidden';

            const rect = wrapper.getBoundingClientRect();
            const hoverRect = hover.getBoundingClientRect();

            const viewportHeight = window.innerHeight;
            const viewportWidth = window.innerWidth;

            let top;
            let left = rect.left;

            if (rect.bottom + hoverRect.height > viewportHeight) {
                top = rect.top - hoverRect.height - 6;
            } else {
                top = rect.bottom + 6;
            }

            if (left + hoverRect.width > viewportWidth) {
                left = viewportWidth - hoverRect.width - 8;
            }

            hover.style.top = `${top}px`;
            hover.style.left = `${left}px`;

            hover.style.visibility = 'visible';
        });
    }

    handleMouseLeave() {
        this.hoverCell = { rowId: null, fieldName: null };
    }

    /* ================= SORT LOGIC (giống fec_CustomTablePaging) ================= */
    handleSort(event) {
        const fieldName = event.currentTarget.dataset.field;
        if (!fieldName) return;

        // Toggle sort direction if clicking the same column
        if (this.sortedBy === fieldName) {
            this.sortedDirection = this.sortedDirection === 'asc' ? 'desc' : 'asc';
        } else {
            // Sort by new column, default to asc
            this.sortedBy = fieldName;
            this.sortedDirection = 'asc';
        }

        this.currentPage = 1;
        this.sortData(fieldName, this.sortedDirection);
    }

    sortData(fieldName, direction) {
        if (!fieldName) return;

        const dir = direction === 'asc' ? 1 : -1;
        
        this._records = [...this._records].sort((a, b) => {
            const valA = a[fieldName] ?? '';
            const valB = b[fieldName] ?? '';

            if (valA > valB) return dir;
            if (valA < valB) return -dir;
            return 0;
        });
    }

    renderedCallback() {
        this.template
            .querySelectorAll('span[lwc\\:dom="manual"]')
            .forEach(el => {
                if (el.dataset.value) {
                    el.innerHTML = el.dataset.value;
                }
            });
    }

    /* ================= NEGATIVE HELPER ================= */
    isNegative(value) {
        if (value === null || value === undefined) return false;
        let str = value.toString().trim();
        if (!str) return false;
        str = str.replace(/,/g, '');
        if (str.startsWith('(') && str.endsWith(')')) {
            return true;
        }
        const num = Number(str);
        return !isNaN(num) && num < 0;
    }

    /* ================= PAGINATION ================= */
    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value, 10);
        this.currentPage = 1;
    }

    handlePrevPage() {
        if (!this.isFirstPage) this.currentPage--;
    }

    handleNextPage() {
        if (!this.isLastPage) this.currentPage++;
    }

    handleGoToPageInput(event) {
        const value = parseInt(event.target.value, 10);
        
        // Validate: chỉ chấp nhận số dương từ 1 trở lên
        if (isNaN(value) || value < 1) {
            this._gotoPage = 1;
            event.target.value = 1;
        } else if (value > this.totalPages) {
            this._gotoPage = this.totalPages;
            event.target.value = this.totalPages;
        } else {
            this._gotoPage = value;
        }
    }

    handleGoToPage() {
        if (this._gotoPage && this._gotoPage >= 1 && this._gotoPage <= this.totalPages) {
            this.currentPage = this._gotoPage;
        }
    }

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refresh'));
    }

    handleLinkClick(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.recordId;

        if (!recordId) {
            console.error('Missing recordId on link click');
            return;
        }

        this.dispatchEvent(
            new CustomEvent('rowselect', {
                detail: { recordId },
                bubbles: true,
                composed: true
            })
        );
    }
}