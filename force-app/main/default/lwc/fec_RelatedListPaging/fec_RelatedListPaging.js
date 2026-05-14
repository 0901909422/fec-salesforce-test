/****************************************************************************************
 * File Name    : Fec_RelatedListAddressesPaging.js
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { isNegative, maskValue } from 'c/fec_CommonUtils';
import FEC_Common_No_Results_Label from '@salesforce/label/c.FEC_Common_No_Results_Label';

export default class Fec_RelatedListPaging extends LightningElement {

    /* ================= API ================= */
    @api columns = [];
    @api sortedBy;
    @api pageSize = 10;
    @api showRefresh = false;
    @api updatedTime; // Timestamp or Date object
    @api hideRowNumber = false; // Hide row number column
    @api hideUpdatedTime = false; // Hide updated time display
    @api defaultSortedBy; // Default field to sort by (field name)
    @api defaultSortDirection = 'desc'; // Default sort direction
    /** Khi set: hiển thị cạnh số item (ví dụ gộp nhiều tiêu chí), thay cho label cột đơn. */
    @api sortedByDescription = '';
    @api pageSizeOptions = [10, 20, 30, 40, 50];
    @api columnCount = 2;
    @api compactColumns = false;
    /** Khi không có dòng dữ liệu; component cha có thể truyền empty-state-message khác (vd. fec_AppInfo). */
    @api emptyStateMessage = FEC_Common_No_Results_Label;

    /* ================= STATE ================= */
    _records = [];
    @track currentPage = 1;
    _gotoPage;

    // Sorting state - single column sort
    sortedDirection = 'desc';
    

    /* ================= LIFECYCLE ================= */
    connectedCallback() {
        // Initialize default sorting if provided
        if (this.defaultSortedBy) {
            this.sortedBy = this.defaultSortedBy;
            this.sortedDirection = this.defaultSortDirection || 'desc';
        }
        // records có thể được gán trước connectedCallback (thứ tự @api không bảo đảm) —
        // lúc đó setter chưa sort được; áp dụng sort sau khi đã có sortedBy.
        if (this.sortedBy && this._records.length > 0) {
            this.sortData(this.sortedBy, this.sortedDirection);
        }
    }

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

        // Nếu records đến trước connectedCallback, sortedBy chưa có → áp mặc định từ cha rồi sort
        if (!this.sortedBy && this.defaultSortedBy) {
            this.sortedBy = this.defaultSortedBy;
            this.sortedDirection = this.defaultSortDirection || 'desc';
        }
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

    /* ================= SORTED BY LABEL ================= */
    /**
     * Get the label of the currently sorted field for display in header.
     */
    get currentSortedByLabel() {
        if (!this.sortedBy) return '';
        const sortedCol = this.columns.find(col => col.fieldName === this.sortedBy);
        return sortedCol ? sortedCol.label : '';
    }

    /** Text hiển thị dòng "Sorted by …" (ưu tiên mô tả tùy chỉnh nếu có). */
    get displaySortedByLabel() {
        const hint = this.sortedByDescription != null ? String(this.sortedByDescription).trim() : '';
        if (hint) return hint;
        return this.currentSortedByLabel;
    }

    /* ================= UPDATED TIME ================= */
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
            const headerClass = col.headerClass || 'header-center';
            const widthStyle = this.compactColumns
                ? 'width:40px; min-width:40px; max-width:40px;'
                : (col.width ? `width:${col.width};` : null);
            return {
                ...col,
                headerClass,
                fullHeaderClass: 'sortable-header ' + headerClass,
                headerStyle: widthStyle,
                // asc = cũ→mới / A→Z → mũi tên lên; desc = mới→cũ → mũi tên xuống
                iconName: isSorted
                    ? (this.sortedDirection === 'desc'
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

    get gridStyle() {
        const cols = Number(this.columnCount) || 2;
        return `grid-template-columns: repeat(${cols}, minmax(0, 1fr));`;
    }

    isEyeVisible(row, column) {
        if (typeof column.eyeCondition === 'function') {
            try {
                return column.eyeCondition(row);
            } catch (e) {
                console.error('eyeCondition error', e);
                return false;
            }
        }
        return true;
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
                            ? (
                                
                                col.hoverFields[0]?.items
                                    ? col.hoverFields.map(section => ({
                                        section: section.section,
                                        showSectionTitle: !!section.section,
                                        items: section.items.map(h => ({
                                            label: h.label,
                                            value: h.fieldName ? (row[h.fieldName] || '-') : '-'
                                        }))
                                    }))
                                    : [{
                                        key: 'default-section',
                                        section: null,
                                        showSectionTitle: false,
                                        items: col.hoverFields.map(h => ({
                                            label: h.label,
                                            value: h.fieldName ? (row[h.fieldName] || '-') : '-'
                                        }))
                                    }]
                            )
                            : [];

                        return {
                            key: col.fieldName,
                            fieldName: col.fieldName,
                            isLink: true,
                            label: row[col.fieldName],
                            recordId: row[col.recordIdField],
                           hoverTitle: col.hasOwnProperty('hoverTitle') ? col.hoverTitle : null,
                            hoverItems,
                            hasHover: hoverItems.length > 0,
                            hoverBodyClass:
                                hoverItems.length === 1
                                    ? 'hover-body one-column'
                                    : 'hover-body two-column',
                            showHover:
                                hoverItems.length > 0 &&
                                this.hoverCell.rowId === row.Id &&
                                this.hoverCell.fieldName === col.fieldName,
                            cellClass: col.cellAlign
                                ? `cell-${col.cellAlign}`
                                : 'cell-center'
                        };
                    }

                    /* ===== EYE TYPE ===== */
                   if (col.type === 'eye') {
                        const shouldShowEye = col.eyeCondition
                            ? col.eyeCondition(row)
                            : true;

                        if (!shouldShowEye) {
                            return {
                                key: col.fieldName,
                                fieldName: col.fieldName,
                                value: row[col.fieldName],
                                isEye: false
                            };
                        }

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
                    if (col.fieldName === 'address') {
                        cellClass = 'cell-address-wrap';
                    }
                    else if (col.cellAttributes && col.cellAttributes.class) {
                        if (typeof col.cellAttributes.class === 'object' && col.cellAttributes.class.fieldName) {
                            cellClass = row[col.cellAttributes.class.fieldName] || '';
                        } else if (typeof col.cellAttributes.class === 'string') {
                            cellClass = col.cellAttributes.class;
                        }
                    }
                    /* ===== ADD NEGATIVE CHECK ===== */
                    const isNeg = isNegative(row[col.fieldName]);
                    if (isNeg) {
                        cellClass = (cellClass ? cellClass + ' ' : '') + 'text-negative';
                    }

                    const align = col.cellAlign
                        || (col.cellAttributes && col.cellAttributes.alignment)
                        || 'left';
                    const fullCellClass = [cellClass || '', 'cell-' + align].filter(Boolean).join(' ').trim();

                    // isMaskable column + masked row → render as eye-type cell with toggle icon
                    if (col.isMaskable === true && row.masked === true) {
                        const eyeKey = `${rowIndex}-${col.fieldName}`;
                        const isMasked = this.eyeStates[eyeKey] !== false;
                        return {
                            key: col.fieldName,
                            isEye: true,
                            fieldName: col.fieldName,
                            rowIndex,
                            value: this.getEyeDisplayValue(row[col.fieldName], isMasked),
                            iconName: isMasked ? 'utility:hide' : 'utility:preview'
                        };
                    }
                    return {
                        key: col.fieldName,
                        isLink: false,
                        isEye: false,
                        isHtml: false,
                        value: row[col.fieldName],
                        cellClass: fullCellClass || 'cell-left',
                        cellStyle: this.compactColumns
                        ? 'width:40px; min-width:40px; max-width:40px;'
                        : (col.width ? `width:${col.width};` : null)

                    };
                })
            };
        });
    }

    /* ================= EYE HELPERS ================= */
   getEyeDisplayValue(value, isMasked) {
        if (value === null || value === undefined) return value;
        if (!isMasked) return value;

        const v = String(value).trim();

        /* =====================
        * PHONE NUMBER: 84xxxxxxxxx (11 số)
        * Hiển thị: 5 số đầu + 3 số cuối
        * ===================== */
        if (/^84\d{9}$/.test(v)) {
            return (
                v.substring(0, 5) +
                '*'.repeat(v.length - 8) +
                v.slice(-3)
            );
        }

        /* =====================
        * LANDLINE bắt đầu bằng 02
        * Hiển thị: 3 số đầu + 3 số cuối
        * Ví dụ: 028*****456
        * ===================== */
        if (/^02\d{8,9}$/.test(v)) {
        return v.substring(0, 3) + "*".repeat(v.length - 6) + v.slice(-3);
        }

        /* =====================
        * PHONE bắt đầu bằng 0 (10 số)
        * Hiển thị: 4 số đầu + 3 số cuối
        * Ví dụ: 0123***456
        * ===================== */
        if (/^0\d{9}$/.test(v)) {
            return v.substring(0, 4) + "*".repeat(v.length - 7) + v.slice(-3);
        }

        /* =====================
        * CCCD (toàn số, > 6)
        * Hiển thị: 3 số đầu + 3 số cuối
        * ===================== */
        if (/^\d+$/.test(v)) {
            if (v.length <= 6) return v;
            return v.substring(0, 3) + "*".repeat(v.length - 6) + v.slice(-3);
        }

        /* =====================
        * DEFAULT MASK
        * Hiển thị: 4 ký tự đầu + 3 ký tự cuối
        * ===================== */
        if (v.length < 7) return v;

        const first = v.substring(0, 4);
        const last = v.substring(v.length - 3);
        return `${first}***${last}`;
    }

    handleToggleEye(event) {
        const rowIndex = event.currentTarget.dataset.rowIndex;
        const fieldName = event.currentTarget.dataset.field;
        const key = `${rowIndex}-${fieldName}`;

        const wasMasked = this.eyeStates[key] !== false;

        this.eyeStates = {
            ...this.eyeStates,
            [key]: !wasMasked
        };

        if (wasMasked) {
            this.dispatchEvent(
                new CustomEvent('sensitivelog', {
                    detail: {
                        fieldName
                    },
                    bubbles: true,
                    composed: true
                })
            );
        }
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

    /* ================= SORT LOGIC ================= */
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
        const records = [...this._records];

        const toTime = (v) => {
            if (!v) return null;

            if (typeof v === 'string') {
                // DD/MM/YYYY (fec_CommonUtils.formatDate)
                let m = v.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
                if (m) {
                    const [, d, mo, y] = m;
                    return new Date(+y, +mo - 1, +d).getTime();
                }
                // DD/MM/YYYY, HH:mm:ss hoặc DD/MM/YYYY HH:mm:ss (fec_CommonUtils.formatDateTime / VN)
                m = v.match(
                    /^(\d{2})\/(\d{2})\/(\d{4})(?:,\s*|\s+)(\d{2}):(\d{2}):(\d{2})$/
                );
                if (m) {
                    const [, d, mo, y, h, min, s] = m;
                    return new Date(+y, +mo - 1, +d, +h, +min, +s).getTime();
                }
            }

            const t = Date.parse(v);
            return Number.isNaN(t) ? null : t;
        };

        /** Chuỗi đã format (vd 735,287) hoặc số — dùng để sort đúng thứ tự số, không sort theo chữ cái */
        const toNumeric = (v) => {
            if (v == null || v === '') return null;
            if (typeof v === 'number' && !Number.isNaN(v)) return v;
            if (typeof v === 'string') {
                const s = v.replace(/,/g, '').trim();
                if (s === '' || s === '-') return null;
                if (/^-?\d+(\.\d+)?$/.test(s)) {
                    const n = Number(s);
                    return Number.isNaN(n) ? null : n;
                }
            }
            return null;
        };

        const parseCaseNumber = (s) => {
            if (!s) return NaN;
            const match = s.match(/\d+$/);
            return match ? Number(match[0]) : NaN;
        };
        

        this._records = records.sort((a, b) => {
            const rawA = a[fieldName];
            const rawB = b[fieldName];

            if (fieldName === 'caseIdText') {
                const numA = parseCaseNumber(rawA);
                const numB = parseCaseNumber(rawB);

                if (!isNaN(numA) && !isNaN(numB)) {
                    return (numA - numB) * dir;
                }
            }

            const timeA = toTime(rawA);
            const timeB = toTime(rawB);

            if (timeA !== null && timeB !== null) {
                return (timeA - timeB) * dir;
            }

            const numA = toNumeric(rawA);
            const numB = toNumeric(rawB);
            if (numA !== null && numB !== null) {
                if (numA !== numB) return (numA - numB) * dir;
                return 0;
            }

            if (rawA == null && rawB != null) return -dir;
            if (rawA != null && rawB == null) return dir;

            if (rawA > rawB) return dir;
            if (rawA < rawB) return -dir;
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