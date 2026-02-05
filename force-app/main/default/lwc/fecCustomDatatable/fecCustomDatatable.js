import { LightningElement, api, track } from 'lwc';
import { sortData, FILTER_ACTION } from 'c/fecUtils';

export default class FecCustomDatatable extends LightningElement {
    @api keyField = 'id';
    @api hideCheckboxColumn = false;
    
    @track _originalData = [];
    @track displayData = [];
    @track internalColumns = [];
    
    // Sử dụng getter/setter để xử lý dữ liệu khi cha truyền vào
    @api 
    set tableData(value) {
        this._originalData = value || [];
        this.executeFiltering();
    }
    get tableData() { return this._originalData; }

    @api 
    set columns(value) {
        this.internalColumns = value ? JSON.parse(JSON.stringify(value)) : [];
    }
    get columns() { return this.internalColumns; }

    // State nội bộ cho Filter
    @track isFilterOpen = false;
    @track isPopupInsideClick = false;
    @track activeFilters = {}; 
    @track filterOptions = [];
    @track currentFilterColumn = '';
    @track currentFilterLabel = '';
    @track popoverStyle = '';
    @track sortedBy;
    @track sortDirection = 'asc';
    @track lastClickX = 0;
    @track lastClickY = 0;

    connectedCallback() {
        window.addEventListener('click', this.handleWindowClick);
    }

    disconnectedCallback() {
        window.removeEventListener('click', this.handleWindowClick);
    }

    handleWindowClick = () => {
        // Nếu popup đang mở VÀ không phải là click từ bên trong (hoặc nút mở)
        if (this.isFilterOpen && !this.isPopupInsideClick) {
            this.closeFilter();
        }
        this.isPopupInsideClick = false;
    }

    captureClickPosition(event) {
        this.lastClickX = event.clientX;
        this.lastClickY = event.clientY;
    }

    // --- XỬ LÝ SORT ---
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortDirection = sortDirection;
        this.displayData = sortData(this.displayData, fieldName, sortDirection);
    }

    // --- XỬ LÝ FILTER ---
    handleHeaderAction(event) {
        const actionName = event.detail.action.name;
        const colDef = event.detail.columnDefinition;
        if (actionName === FILTER_ACTION) {
            this.currentFilterColumn = colDef.fieldName;
            this.currentFilterLabel = colDef.label;
            this.prepareOptions(colDef.fieldName);
            this.calculatePopoverPosition();
            this.isFilterOpen = true;
            this.isPopupInsideClick = true;
        }
    }

    prepareOptions(fieldName) {
        const values = [...new Set(this._originalData.map(item => item[fieldName]))];
        const currentSelected = this.activeFilters[fieldName] || [];
        
        this.filterOptions = values.map(val => ({
            label: val || '(Trống)',
            value: String(val),
            checked: currentSelected.includes(String(val))
        }));
    }

    calculatePopoverPosition() {
        // Lấy tọa độ của container bảng
        const container = this.template.querySelector('.table-wrapper');
        const containerRect = container.getBoundingClientRect();

        // Tính toán vị trí dựa trên tọa độ chuột cuối cùng đã bắt được
        let leftPos = this.lastClickX - containerRect.left - 200; 
        let topPos = this.lastClickY - containerRect.top + 15;

        // Kiểm tra xem có đang ở trong Modal không
        const isInModal = this.template.host.closest('section.slds-modal') !== null;

        if (isInModal) {
            // Nếu trong Modal, dùng Fixed để tránh lỗi scroll
            // -200 để popup dịch sang trái, giúp mũi tên chỉ đúng vào icon
            this.popoverStyle = `position: fixed; top: ${this.lastClickY + 20}px; left: ${this.lastClickX - 350}px; width: 250px; z-index: 10001;`;
        } else {
            // Nếu bảng ngoài, dùng Absolute căn theo .table-wrapper
            const tableWidth = containerRect.width;
            if (leftPos + 250 > tableWidth) leftPos = tableWidth - 250;
            if (leftPos < 5) leftPos = 5;

            this.popoverStyle = `position: absolute; top: ${topPos + 15}px; left: ${leftPos - 50}px; width: 250px; z-index: 1000;`;
        }
    }

    handleApplyFilter(event) {
        const selectedValues = event.detail.values;
        if (selectedValues.length > 0) {
            this.activeFilters[this.currentFilterColumn] = selectedValues;
            this.updateColumnIcon(this.currentFilterColumn, true);
        } else {
            delete this.activeFilters[this.currentFilterColumn];
            this.updateColumnIcon(this.currentFilterColumn, false);
        }
        this.executeFiltering();
        this.closeFilter();
    }

    executeFiltering() {
        let result = [...this._originalData];
        Object.keys(this.activeFilters).forEach(field => {
            const values = this.activeFilters[field];
            result = result.filter(row => values.includes(String(row[field])));
        });
        this.displayData = result;
    }

    updateColumnIcon(fieldName, isFiltered) {
        this.internalColumns = this.internalColumns.map(col => {
            if (col.fieldName === fieldName) {
                return {
                    ...col,
                    actions: col.actions.map(a => 
                        a.name === FILTER_ACTION ? { ...a, checked: isFiltered } : a
                    )
                };
            }
            return col;
        });
    }

    handleInsideClick(){this.isPopupInsideClick = true;}
    closeFilter() { this.isFilterOpen = false; }

    handleRowAction(event) {
        // Chuyển tiếp sự kiện row action lên cha
        this.dispatchEvent(new CustomEvent('rowaction', { detail: event.detail }));
    }
}