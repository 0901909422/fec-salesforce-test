/**
 * @description LWC Controller for Custom Decision Table UI (Dynamic EAV)
 * @date 2026-03-10
 * @author DAT NGO
 */
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getBusinessProcessTree from '@salesforce/apex/FEC_BusinessProcessService.getBusinessProcessTree';
import getDynamicDecisionTable from '@salesforce/apex/FEC_DecisionTableController.getDynamicDecisionTable';
import getDynamicDecisionTableFresh from '@salesforce/apex/FEC_DecisionTableController.getDynamicDecisionTableFresh';
import saveDynamicRule from '@salesforce/apex/FEC_DecisionTableController.saveDynamicRule';
import deleteDynamicRule from '@salesforce/apex/FEC_DecisionTableController.deleteDynamicRule';
import addDynamicColumn from '@salesforce/apex/FEC_DecisionTableController.addDynamicColumn';
import deleteDynamicColumn from '@salesforce/apex/FEC_DecisionTableController.deleteDynamicColumn';
import addDynamicRow from '@salesforce/apex/FEC_DecisionTableController.addDynamicRow';
import getMDMFieldOptions from '@salesforce/apex/FEC_DecisionTableController.getMDMFieldOptions';

export default class FecDecisionTableView extends LightningElement {
    @track modalConditionCols = [];
    @track modalActionCols = [];
    @track editingRuleId = null;

    @track isTreeExpanded = true;
    @track treeData = [];
    @track treeError = null;
    @track selectedNode = null;

    @track isLoading = false;
    @track error = null;
    @track searchFilter = '';

    // --- Biến lưu trữ Dữ liệu Động ---
    @track dynamicData = {
        tableId: null,
        conditionCols: [],
        actionCols: [],
        rows: []
    };
    @track originalRows = []; // Backup dữ liệu gốc khi filter

    // --- Modal States ---
    @track showAddRuleModal = false;

    // ==========================================
    // TRACK SELECTION STATES
    // ==========================================
    @track selectedColId = null;
    @track selectedColType = null;
    @track selectedRowId = null;

    // --- Add Column Modal States ---
    @track showAddColModal = false;
    @track newColPosition = '';
    @track newColName = '';
    @track newColDataType = 'Text';
    @track newColType = 'Condition'; // Mặc định

    // BIẾN CHO TÍNH NĂNG SMART UI
    @track mdmFieldOptions = [];
    @track rawMdmFields = [];
    @track newMdmFieldId = null;

    colTypeOptions = [
        { label: 'Điều Kiện (Condition)', value: 'Condition' },
        { label: 'Hành Động (Action)', value: 'Action' }
    ];

    dataTypeOptions = [
        { label: 'Văn bản (Text)', value: 'Text' },
        { label: 'Đúng/Sai (Boolean)', value: 'Boolean' },
        { label: 'Số (Number)', value: 'Number' }
    ];

    _wiredDynamicTable;
    _currentBPId = null;
    _refreshCounter = 0;

    /**
     * Force full reload Decision Table — imperative call bypasses wire cache
     */
    refreshTable() {
        if (!this._currentBPId) return;
        this.isLoading = true;
        getDynamicDecisionTableFresh({ businessProcessId: this._currentBPId })
            .then(data => {
                if (data) {
                    const clonedConditionCols = (data.conditionCols || []).map(c => ({ ...c, cssClass: 'conditions-cell' }));
                    const clonedActionCols = (data.actionCols || []).map(c => ({ ...c, cssClass: 'action-cell' }));
                    const clonedRows = (data.rows || []).map(r => ({ ...r, cssClass: 'decision-row' }));
                    this.dynamicData = {
                        tableId: data.tableId,
                        conditionCols: clonedConditionCols,
                        actionCols: clonedActionCols,
                        rows: clonedRows
                    };
                    this.originalRows = [...clonedRows];
                    this.error = null;
                }
            })
            .catch(err => {
                this.error = err?.body?.message || err?.message || 'Error refreshing table';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showLog(methodName, message) {
        console.log(`[${methodName}] ${message}`);
    }

    // ==========================================
    // 1. LOAD BUSINESS PROCESS TREE
    // ==========================================
    @wire(getBusinessProcessTree)
    wiredBusinessProcessTree({ error, data }) {
        this.showLog('wiredBusinessProcessTree', 'START');
        if (data) {
            this.treeData = this.buildTreeData(data);
            this.treeError = null;
        } else if (error) {
            this.treeError = error?.body?.message || 'Lỗi khi tải Business Process tree';
            this.treeData = [];
        }
    }

    buildTreeData(data) {
        const treeItems = [];
        if (!Array.isArray(data)) return treeItems;

        data.forEach((bp) => {
            const bpItem = {
                label: bp.label, name: bp.id, expanded: false, type: bp.type,
                icon: bp.icon, code: bp.code, nameVN: bp.nameVN, items: []
            };
            if (Array.isArray(bp.children)) {
                bp.children.forEach((stage) => {
                    bpItem.items.push({
                        label: `${stage.label}${stage.code ? ' (' + stage.code + ')' : ''}`,
                        name: stage.id, type: stage.type, icon: stage.icon,
                        parentId: stage.parentId, disabled: false
                    });
                });
            }
            treeItems.push(bpItem);
        });
        return treeItems;
    }

    // ==========================================
    // 2. LOAD DYNAMIC DECISION TABLE
    // ==========================================
    @wire(getDynamicDecisionTable, { businessProcessId: '$_currentBPId' })
    wiredDynamicDecisionTable(result) {
        this._wiredDynamicTable = result;
        const { data, error } = result;
        if (data) {
            this.showLog('wiredDynamicDecisionTable', 'Loaded dynamic data successfully');

            // CÁCH FIX LỖI PROXY: Clone dữ liệu ra mảng mới (dùng .map) trước khi gán cssClass
            const clonedConditionCols = (data.conditionCols || []).map(c => ({ ...c, cssClass: 'conditions-cell' }));
            const clonedActionCols = (data.actionCols || []).map(c => ({ ...c, cssClass: 'action-cell' }));
            const clonedRows = (data.rows || []).map(r => ({ ...r, cssClass: 'decision-row' }));

            // Gán dữ liệu đã clone vào biến state của LWC
            this.dynamicData = {
                tableId: data.tableId,
                conditionCols: clonedConditionCols,
                actionCols: clonedActionCols,
                rows: clonedRows
            };

            this.originalRows = [...clonedRows];
            this.error = null;
        } else if (error) {
            this.error = error?.body?.message || 'Lỗi tải Decision Table động';
            this.dynamicData = { tableId: null, conditionCols: [], actionCols: [], rows: [] };
            this.originalRows = [];
        }
        this.isLoading = false;
    }
    // ==========================================
    // 3. UI EVENTS & ACTIONS
    // ==========================================
    handleToggleTree() {
        this.isTreeExpanded = !this.isTreeExpanded;
    }

    handleNodeSelect(event) {
        const name = event.detail?.name;
        if (!name) return;

        let nodeType = 'BUSINESS_PROCESS';
        let nodeLabel = name;
        for (const bp of this.treeData) {
            if (bp.name === name) {
                nodeType = bp.type || 'BUSINESS_PROCESS'; nodeLabel = bp.label; break;
            }
            const stage = (bp.items || []).find(s => s.name === name);
            if (stage) {
                nodeType = stage.type || 'STAGE'; nodeLabel = stage.label; break;
            }
        }

        this.selectedNode = { idType: name, label: nodeLabel, type: nodeType };

        if (nodeType === 'BUSINESS_PROCESS') {
            this.isLoading = true;
            this._currentBPId = name;
            // Clear selection states when switching BP
            this.selectedColId = null;
            this.selectedRowId = null;
        } else {
            this.dynamicData = { tableId: null, conditionCols: [], actionCols: [], rows: [] };
            this.originalRows = [];
            this.error = null;
        }
    }

    // ==========================================
    // 4. SEARCH & FILTER
    // ==========================================
    handleSearchChange(event) {
        this.searchFilter = event.target.value.toLowerCase();
        this.applySearchFilter();
    }

    handleClearSearch() {
        this.searchFilter = '';
        this.applySearchFilter();
    }

    applySearchFilter() {
        if (!this.searchFilter.trim()) {
            this.dynamicData.rows = [...this.originalRows];
            return;
        }
        this.dynamicData.rows = this.originalRows.filter(row => {
            return row.allSearchableCells.some(cell =>
                cell.value && cell.value.toLowerCase().includes(this.searchFilter)
            );
        });
    }

    // ==========================================
    // 5. GETTERS (Dành cho HTML)
    // ==========================================
    get hasTreeData() { return this.treeData && this.treeData.length > 0; }
    get conditionColSpan() { return this.dynamicData?.conditionCols?.length || 0; }
    get actionColSpan() { return this.dynamicData?.actionCols?.length || 0; }
    get hasDecisionData() { return this.originalRows.length > 0; }
    get hasNoSearchResults() { return this.hasSearchFilter && this.dynamicData?.rows?.length === 0; }

    get totalRuleCount() { return this.originalRows.length; }
    get stageCount() { return this.originalRows.length > 0 ? 'Dynamic' : 0; }

    get treeArrowIcon() { return this.isTreeExpanded ? 'utility:chevrondown' : 'utility:chevronright'; }
    get selectedItemLabel() { return this.selectedNode?.label || ''; }
    get hasSelection() { return !!this.selectedNode?.idType; }
    get isBPSelected() { return this.selectedNode?.type === 'BUSINESS_PROCESS'; }
    get isStageSelected() { return this.selectedNode?.type === 'STAGE'; }
    get hasSearchFilter() { return this.searchFilter.trim().length > 0; }
    get displaySearchMessage() { return `Kết quả tìm kiếm: ${this.dynamicData?.rows?.length || 0} rule`; }
    get modalTitle() { return this.editingRuleId ? 'Sửa Rule' : 'Thêm Rule Mới'; }

    // Disable các nút Xóa nếu không chọn, nhưng các nút Thêm thì luôn Mở để thêm mới
    get disableColButtons() { return !this.selectedColId; }
    get disableRowButtons() { return !this.selectedRowId; }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleOverlayClick() { this.handleCloseModal(); this.closeAddColModal(); }
    handleDialogClick(event) { event.stopPropagation(); }

    // ==========================================
    // 6.XỬ LÝ CLICK CHỌN (SELECTION)
    // ==========================================
    handleSelectColumn(event) {
        this.selectedColId = event.currentTarget.dataset.colId;
        this.selectedColType = event.currentTarget.dataset.colType;
        this.selectedRowId = null;
        this.updateSelectionCSS();
    }

    handleSelectRow(event) {
        if (event.target.tagName === 'LIGHTNING-ICON' || event.target.tagName === 'BUTTON') return;
        this.selectedRowId = event.currentTarget.dataset.rowId;
        this.selectedColId = null;
        this.updateSelectionCSS();
    }

    updateSelectionCSS() {
        if (!this.dynamicData) return;

        if (this.dynamicData.conditionCols) {
            this.dynamicData.conditionCols.forEach(c => {
                c.cssClass = (c.id === this.selectedColId) ? 'conditions-cell selected-header' : 'conditions-cell';
            });
        }

        if (this.dynamicData.actionCols) {
            this.dynamicData.actionCols.forEach(c => {
                c.cssClass = (c.id === this.selectedColId) ? 'action-cell selected-header' : 'action-cell';
            });
        }

        if (this.dynamicData.rows) {
            this.dynamicData.rows.forEach(r => {
                r.cssClass = (r.rowId === this.selectedRowId) ? 'decision-row selected-row' : 'decision-row';
            });
        }

        this.dynamicData = { ...this.dynamicData };
    }

    // ==========================================
    // 7.LOGIC THÊM / XÓA CỘT (DYNAMIC COLUMN)
    // ==========================================
    handleAddColLeft() { this.openAddColModal('left'); }
    handleAddColRight() { this.openAddColModal('right'); }

    openAddColModal(position) {
        this.newColPosition = position;
        this.newMdmFieldId = null;
        this.newColName = '';
        this.newColDataType = 'Text';
        this.newColType = this.selectedColType || 'Condition';
        this.showAddColModal = true;
    }

    // Hàm bắt sự kiện khi Admin chọn một Field trong Dropdown
    handleMdmFieldChange(e) {
        this.newMdmFieldId = e.detail.value;
        const selectedField = this.rawMdmFields.find(f => f.value === this.newMdmFieldId);

        if (selectedField) {
            // Strip API name nếu label có format "Label (API_Name__c)"
            let label = selectedField.label || '';
            label = label.replace(/\s*\(.*?\)\s*$/, '').trim();
            this.newColName = label;
            let mappedType = selectedField.dataType || 'Text';
            if (mappedType === 'Picklist') mappedType = 'Text';
            this.newColDataType = mappedType;
        }
    }

    closeAddColModal() { this.showAddColModal = false; }
    handleNewColNameChange(e) { this.newColName = e.target.value; }
    handleNewColTypeChange(e) { this.newColType = e.detail.value; }
    handleNewColDataTypeChange(e) { this.newColDataType = e.detail.value; }

    submitAddColumn() {
        if (!this.newMdmFieldId) {
            this.showToast('Error', 'Please select a Field from the list', 'error');
            return;
        }

        // Validate duplicate: check if field already exists as a column
        const existingCols = [...(this.dynamicData.conditionCols || []), ...(this.dynamicData.actionCols || [])];
        const isDuplicate = existingCols.some(c => c.label === this.newColName);
        if (isDuplicate) {
            this.showToast('Error', `Column "${this.newColName}" already exists. Please select a different field.`, 'error');
            return;
        }

        this.isLoading = true;
        addDynamicColumn({
            tableId: this.dynamicData.tableId,
            targetColId: this.selectedColId,
            position: this.newColPosition || 'right',
            colName: this.newColName,
            colType: this.newColType,
            dataType: this.newColDataType,
            mdmFieldId: this.newMdmFieldId
        }).then(() => {
            this.showToast('Success', 'Column added successfully', 'success');
            this.closeAddColModal();
            this.selectedColId = null;
            this.selectedColType = null;
            this.selectedRowId = null;
            this.refreshTable();
        }).catch(err => {
            this.showToast('Error', err.body?.message || err.message, 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }
    
    handleDeleteCol() {
        if (!this.selectedColId) return;
        if (!confirm('Cảnh báo: Xóa cột sẽ làm mất toàn bộ dữ liệu của cột này trên mọi dòng. Tiếp tục?')) return;

        this.isLoading = true;
        deleteDynamicColumn({ colId: this.selectedColId })
            .then(() => {
                this.showToast('Success', 'Column deleted successfully', 'success');
                this.selectedColId = null;
                this.refreshTable(); return;
            }).catch(err => {
                this.showToast('Error', err.body?.message || err.message, 'error');
            }).finally(() => {
                this.isLoading = false;
            });
    }

    // ==========================================
    // 8.LOGIC THÊM / XÓA DÒNG (DYNAMIC ROW)
    // ==========================================
    handleAddRowAbove() { this.callAddRowAPI('above'); }
    handleAddRowBelow() { this.callAddRowAPI('below'); }

    callAddRowAPI(position) {
        this.isLoading = true;
        addDynamicRow({
            tableId: this.dynamicData.tableId,
            targetRowId: this.selectedRowId,
            position: position || 'below'
        }).then(() => {
            this.showToast('Success', 'Row added successfully', 'success');
            this.selectedRowId = null;
            this.selectedColId = null;
            this.selectedColType = null;
            this.refreshTable(); return;
        }).catch(err => {
            this.showToast('Error', err.body?.message || err.message, 'error');
        }).finally(() => {
            this.isLoading = false;
        });
    }

    handleDeleteRowToolbar() {
        if (!this.selectedRowId) return;
        if (!confirm('Bạn có chắc muốn xóa dòng này?')) return;

        this.isLoading = true;
        deleteDynamicRule({ rowId: this.selectedRowId })
            .then(() => {
                this.showToast('Success', 'Row deleted successfully', 'success');
                this.selectedRowId = null;
                this.refreshTable(); return;
            }).catch(err => {
                this.showToast('Error', err.body?.message || err.message, 'error');
            }).finally(() => {
                this.isLoading = false;
            });
    }

    // ==========================================
    // 9.LOGIC SỬA DỮ LIỆU RULE (EDIT CELLS)
    // ==========================================
    handleAddRule() {
        this.editingRuleId = null;
        this.modalConditionCols = this.dynamicData.conditionCols.map(c => ({ id: c.id, label: c.label, value: '' }));
        this.modalActionCols = this.dynamicData.actionCols.map(c => ({ id: c.id, label: c.label, value: '' }));
        this.showAddRuleModal = true;
    }

    handleEditRule(event) {
        const rowId = event.currentTarget.dataset.rowId;
        this.editingRuleId = rowId;
        const targetRow = this.dynamicData.rows.find(r => r.rowId === rowId);

        if (targetRow) {
            this.modalConditionCols = this.dynamicData.conditionCols.map(c => {
                const existingCell = targetRow.conditionCells.find(cell => cell.colId === c.id);
                return { id: c.id, label: c.label, value: existingCell && existingCell.value !== '--' ? existingCell.value : '' };
            });
            this.modalActionCols = this.dynamicData.actionCols.map(c => {
                const existingCell = targetRow.actionCells.find(cell => cell.colId === c.id);
                return { id: c.id, label: c.label, value: existingCell && existingCell.value !== '--' ? existingCell.value : '' };
            });
            this.showAddRuleModal = true;
        }
    }

    handleDynamicInputChange(event) {
        const colId = event.target.dataset.id;
        const colType = event.target.dataset.type;
        const val = event.target.value;

        if (colType === 'condition') {
            const col = this.modalConditionCols.find(c => c.id === colId);
            if (col) col.value = val;
        } else {
            const col = this.modalActionCols.find(c => c.id === colId);
            if (col) col.value = val;
        }
    }

    handleSaveRule() {
        this.isLoading = true;
        let cellDataMap = {};
        this.modalConditionCols.forEach(c => { if (c.value) cellDataMap[c.id] = c.value; });
        this.modalActionCols.forEach(c => { if (c.value) cellDataMap[c.id] = c.value; });

        saveDynamicRule({
            tableId: this.dynamicData.tableId,
            rowId: this.editingRuleId,
            cellDataMap: cellDataMap
        })
            .then(() => {
                this.showToast('Success', 'Rule saved successfully', 'success');
                this.handleCloseModal();
                this.refreshTable();
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleDeleteRule(event) {
        if (!confirm('Bạn có chắc muốn xóa Rule này không?')) return;
        const rowId = event.currentTarget.dataset.rowId;
        this.isLoading = true;

        deleteDynamicRule({ rowId: rowId })
            .then(() => {
                this.showToast('Success', 'Rule deleted successfully', 'success');
                this.refreshTable();
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCloseModal() {
        this.showAddRuleModal = false;
    }

    // ==========================================
    // 10.LẤY DANH SÁCH FIELD TỪ MDM THƯ VIỆN
    // ==========================================
    @wire(getMDMFieldOptions, { businessProcessId: '$_currentBPId' })
    wiredMdmFields({ error, data }) {
        if (data) {
            this.rawMdmFields = data;
            this.mdmFieldOptions = data.map(f => ({
                label: (f.label || '').replace(/\s*\(.*?\)\s*$/, '').trim(),
                value: f.value
            }));
        } else if (error) {
            this.mdmFieldOptions = [];
            this.rawMdmFields = [];
        }
    }
}