import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getBusinessProcessTree from '@salesforce/apex/FEC_BusinessProcessService.getBusinessProcessTree';
import getDecisionTableByBP from '@salesforce/apex/FEC_BusinessProcessService.getDecisionTableByBP';
import getStagesByBP from '@salesforce/apex/FEC_BusinessProcessService.getStagesByBP';
import getActionButtonsByBP from '@salesforce/apex/FEC_BusinessProcessService.getActionButtonsByBP';
import saveStagChangeRule from '@salesforce/apex/FEC_BusinessProcessService.saveStagChangeRule';
import deleteStagChangeRule from '@salesforce/apex/FEC_BusinessProcessService.deleteStagChangeRule';

export default class FecDecisionTableView extends LightningElement {
    // Tree state
    @track selectedNode = null;
    @track isTreeExpanded = true;
    @track treeData = [];
    @track treeError = null;

    // Decision Table state
    @track isLoading = false;
    @track error = null;
    @track decisionRows = [];
    @track groupedRows = [];
    @track searchFilter = '';
    @track filteredGroupedRows = [];

    // Column headers
    colCurrentStage = 'Current Stage';
    colConditions   = 'Điều kiện';
    colAction       = 'Action';
    colNextStage    = 'Next Stage';
    colNextQueue    = 'Next Queue';
    colTeamUserGroup = 'Team/User Group';

    // Modal & Edit state
    @track showAddRuleModal = false;
    @track editingRule = null;
    @track selectedRuleForEdit = null;
    @track formData = {
        previousStageId: '',
        actionButtonId: '',
        nextStageId: '',
        nextQueue: '',
        teamUserGroup: ''
    };
    @track formErrors = {};
    
    // Form options
    @track stageOptions = [];
    @track actionOptions = [];

    // Giữ wire result để dùng refreshApex
    _wiredDecisionTable;
    _currentBPId = null;

    /**
     * Load Business Process tree data từ Apex
     */
    @wire(getBusinessProcessTree)
    wiredBusinessProcessTree({ error, data }) {
        console.log('[DecisionTableView] wiredBusinessProcessTree called');
        if (data) {
            console.log('[DecisionTableView] Tree data loaded:', data);
            this.treeData = this.buildTreeData(data);
            this.treeError = null;
        } else if (error) {
            console.error('[DecisionTableView] Error loading tree:', error);
            this.treeError = error?.body?.message || 'Lỗi khi tải Business Process tree';
            this.treeData = [];
        }
    }

    /**
     * Xây dựng tree structure từ Apex data
     * Convert flat list thành hierarchical tree
     */
    buildTreeData(data) {
        const treeItems = [];

        if (!Array.isArray(data) || data.length === 0) {
            console.log('[DecisionTableView] No data to build tree');
            return treeItems;
        }

        data.forEach((bp) => {
            const bpItem = {
                label: bp.label,
                name: bp.id,
                expanded: false,
                type: bp.type,
                icon: bp.icon,
                code: bp.code,
                nameVN: bp.nameVN,
                items: []
            };

            // Thêm children (Stages) vào node Business Process
            if (Array.isArray(bp.children) && bp.children.length > 0) {
                bp.children.forEach((stage) => {
                    bpItem.items.push({
                        label: `${stage.label}${stage.code ? ' (' + stage.code + ')' : ''}`,
                        name: stage.id,
                        type: stage.type,
                        icon: stage.icon,
                        parentId: stage.parentId,
                        disabled: false
                    });
                });
            }

            treeItems.push(bpItem);
        });

        console.log('[DecisionTableView] Built tree items:', treeItems);
        return treeItems;
    }

    /**
     * Nhận event từ tree khi người dùng chọn node
     */
    handleNodeSelect(event) {
        console.log('[DecisionTableView] handleNodeSelect called:', event);
        console.log('[DecisionTableView] event.detail:', event.detail);
        
        const name = event.detail?.name;
        console.log('[DecisionTableView] Extracted name:', name);
        
        if (!name) {
            console.warn('[DecisionTableView] Node name is empty, skipping');
            return;
        }

        // Tìm node trong treeData để lấy type
        let nodeType = 'BUSINESS_PROCESS';
        let nodeLabel = name;
        for (const bp of this.treeData) {
            if (bp.name === name) {
                nodeType = bp.type || 'BUSINESS_PROCESS';
                nodeLabel = bp.label;
                console.log('[DecisionTableView] Found BP node:', { nodeType, nodeLabel });
                break;
            }
            const stage = (bp.items || []).find(s => s.name === name);
            if (stage) {
                nodeType = stage.type || 'STAGE';
                nodeLabel = stage.label;
                console.log('[DecisionTableView] Found Stage node:', { nodeType, nodeLabel });
                break;
            }
        }

        this.selectedNode = { idType: name, label: nodeLabel, type: nodeType };
        console.log('[DecisionTableView] Node selected:', this.selectedNode);
        console.log('[DecisionTableView] selectedNode state updated, hasSelection:', this.hasSelection);

        // Chỉ load Decision Table khi chọn Business Process
        if (nodeType === 'BUSINESS_PROCESS') {
            console.log('[DecisionTableView] Loading Decision Table for BP:', name);
            this.loadDecisionTable(name);
            this.loadStageAndActionOptions(name); // Load options ngay, không đợi Decision Table
        } else {
            console.log('[DecisionTableView] Node is Stage, clearing Decision Table');
            this.decisionRows = [];
            this.groupedRows = [];
            this.error = null;
        }
    }

    /**
     * Expand/Collapse tree
     */
    handleToggleTree() {
        this.isTreeExpanded = !this.isTreeExpanded;
    }

    /**
     * Wire: Load Decision Table — dùng @wire để có thể refreshApex
     */
    @wire(getDecisionTableByBP, { businessProcessId: '$_currentBPId' })
    wiredDecisionTable(result) {
        this._wiredDecisionTable = result;
        const { data, error } = result;
        if (data) {
            console.log('[DecisionTableView] Decision Table wired data:', data.length, 'rows');
            const rows = Array.isArray(data) ? data : [];
            this.decisionRows = rows;
            this.groupedRows = this.buildGroupedRows(rows);
            this.applySearchFilter();
            this.error = null;
        } else if (error) {
            console.error('[DecisionTableView] Wire error:', error);
            this.error = error?.body?.message || 'Lỗi khi tải Decision Table';
            this.decisionRows = [];
            this.groupedRows = [];
            this.filteredGroupedRows = [];
        }
        this.isLoading = false;
    }

    /**
     * Load Decision Table — set _currentBPId để trigger @wire
     */
    loadDecisionTable(businessProcessId) {
        if (!businessProcessId) return;
        console.log('[DecisionTableView] loadDecisionTable:', businessProcessId);
        this.isLoading = true;
        this.error = null;
        this.decisionRows = [];
        this.groupedRows = [];
        this.filteredGroupedRows = [];
        this._currentBPId = businessProcessId;
    }

    /**
     * Refresh Decision Table sau khi add/edit/delete
     */
    refreshDecisionTable() {
        this.isLoading = true;
        refreshApex(this._wiredDecisionTable)
            .then(() => {
                console.log('[DecisionTableView] refreshApex success');
            })
            .catch((err) => {
                console.error('[DecisionTableView] refreshApex error:', err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Load Stage và Action options từ Apex theo BP ID
     */
    loadStageAndActionOptions(businessProcessId) {
        if (!businessProcessId) return;

        // Load Stages của BP
        getStagesByBP({ businessProcessId })
            .then((stages) => {
                console.log('[DecisionTableView] Stages loaded:', stages);
                this.stageOptions = Array.isArray(stages)
                    ? stages.map(s => ({ label: s.label, value: s.value }))
                    : [];
            })
            .catch((err) => {
                console.error('[DecisionTableView] Error loading stages:', err);
            });

        // Load Action Buttons của BP
        getActionButtonsByBP({ businessProcessId })
            .then((actions) => {
                console.log('[DecisionTableView] Actions loaded:', actions);
                this.actionOptions = Array.isArray(actions)
                    ? actions.map(a => ({ label: a.label, value: a.value }))
                    : [];
            })
            .catch((err) => {
                console.error('[DecisionTableView] Error loading actions:', err);
            });
    }

    /**
     * Group rows theo Current Stage, đánh dấu isFirst cho rowspan
     */
    buildGroupedRows(data) {
        const groups = [];
        const stageMap = new Map();

        data.forEach((row, index) => {
            const stageKey = row.currentStage || '--';
            if (!stageMap.has(stageKey)) {
                const group = { stageName: stageKey, stageId: row.currentStageId, rules: [], rowCount: 0 };
                stageMap.set(stageKey, group);
                groups.push(group);
            }
            const group = stageMap.get(stageKey);
            group.rules.push({
                rowId:          row.rowId         || `row-${index}`,
                action:         row.action         || '--',
                actionCode:     row.actionCode     || '--',
                nextStage:      row.nextStage       || '--',
                nextQueue:      row.nextQueue       || '--',
                teamUserGroup:  row.teamUserGroup   || '--',
                currentStageId: row.currentStageId || '',
                nextStageId:    row.nextStageId     || '',
                actionButtonId: row.actionButtonId  || '',
                isFirst:        false,
                isLast:         false
            });
            group.rowCount++;
        });

        groups.forEach(group => {
            if (group.rules.length > 0) {
                group.rules[0].isFirst = true;
                group.rules[group.rules.length - 1].isLast = true;
                // Thêm rowClass cho mỗi rule
                group.rules.forEach((rule, idx) => {
                    const classes = ['decision-row'];
                    if (rule.isFirst) classes.push('row-group-first');
                    if (rule.isLast) classes.push('row-group-last');
                    if (!rule.isFirst) classes.push('row-group-middle');
                    rule.rowClass = classes.join(' ');
                });
            }
        });

        console.log('[DecisionTableView] Grouped rows:', groups);
        this.filteredGroupedRows = groups;
        return groups;
    }

    /**
     * Filter grouped rows theo search text
     */
    applySearchFilter() {
        if (!this.searchFilter.trim()) {
            this.filteredGroupedRows = [...this.groupedRows];
            return;
        }

        const searchText = this.searchFilter.toLowerCase();
        const filtered = [];

        this.groupedRows.forEach(group => {
            const filteredRules = group.rules.filter(rule => {
                return (
                    rule.action.toLowerCase().includes(searchText) ||
                    rule.actionCode.toLowerCase().includes(searchText) ||
                    rule.nextStage.toLowerCase().includes(searchText) ||
                    group.stageName.toLowerCase().includes(searchText)
                );
            });

            if (filteredRules.length > 0) {
                // Đánh dấu isFirst cho rule đầu tiên của group
                filteredRules.forEach((rule, index) => {
                    rule.isFirst = (index === 0);
                });
                filtered.push({
                    ...group,
                    rules: filteredRules,
                    rowCount: filteredRules.length
                });
            }
        });

        console.log('[DecisionTableView] Filtered rows:', filtered);
        this.filteredGroupedRows = filtered;
    }

    /**
     * Handle search input change
     */
    handleSearchChange(event) {
        this.searchFilter = event.target.value;
        this.applySearchFilter();
        console.log('[DecisionTableView] Search filter updated:', this.searchFilter);
    }

    /**
     * Clear search filter
     */
    handleClearSearch() {
        this.searchFilter = '';
        this.filteredGroupedRows = [...this.groupedRows];
        console.log('[DecisionTableView] Search cleared');
    }

    /**
     * Open modal để thêm rule mới
     */
    handleAddRule() {
        if (!this.isBPSelected) {
            this.error = 'Vui lòng chọn Business Process trước';
            return;
        }
        console.log('[DecisionTableView] Opening Add Rule modal for BP:', this.selectedNode.idType);
        
        // Reset form data cho rule mới
        this.editingRule = null;
        this.selectedRuleForEdit = null;
        this.formData = {
            previousStageId: '',
            actionButtonId: '',
            nextStageId: '',
            nextQueue: '',
            teamUserGroup: ''
        };
        this.formErrors = {};
        
        this.showAddRuleModal = true;
    }

    /**
     * Edit existing rule
     */
    handleEditRule(event) {
        const rowId = event.currentTarget.dataset.rowId;
        console.log('[DecisionTableView] Editing rule rowId:', rowId);
        
        // Tìm rule từ groupedRows (có lưu IDs)
        let foundRule = null;
        for (const group of this.groupedRows) {
            foundRule = group.rules.find(r => r.rowId === rowId);
            if (foundRule) break;
        }

        console.log('[DecisionTableView] Rule found for edit:', foundRule);

        if (foundRule) {
            this.editingRule = rowId;
            this.selectedRuleForEdit = { ...foundRule };
            this.formErrors = {};

            // Populate form với dữ liệu rule hiện tại
            this.formData = {
                previousStageId: foundRule.currentStageId || '',
                actionButtonId:  foundRule.actionButtonId  || '',
                nextStageId:     foundRule.nextStageId     || '',
                nextQueue:       foundRule.nextQueue !== '--' ? foundRule.nextQueue : '',
                teamUserGroup:   foundRule.teamUserGroup !== '--' ? foundRule.teamUserGroup : ''
            };

            console.log('[DecisionTableView] formData for edit:', this.formData);
            this.showAddRuleModal = true;
        } else {
            console.warn('[DecisionTableView] Rule not found for rowId:', rowId);
        }
    }

    /**
     * Delete rule
     */
    handleDeleteRule(event) {
        const rowId = event.currentTarget.dataset.rowId;
        console.log('[DecisionTableView] Deleting rule:', rowId);
        
        if (!confirm('Bạn có chắc chắn muốn xóa rule này?')) {
            return;
        }

        this.isLoading = true;
        this.error = null;

        console.log('[DecisionTableView] Calling Apex deleteStagChangeRule:', rowId);

        deleteStagChangeRule({ recordId: rowId })
            .then((result) => {
                console.log('[DecisionTableView] Rule deleted successfully');
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Thành công!',
                        message: 'Rule đã được xóa',
                        variant: 'success'
                    })
                );

                this.refreshDecisionTable();
            })
            .catch((err) => {
                console.error('[DecisionTableView] Error deleting rule:', err);
                this.error = err?.body?.message || 'Lỗi khi xóa Rule';
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Lỗi!',
                        message: this.error,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Close modal
     */
    handleCloseModal() {
        this.showAddRuleModal = false;
        this.editingRule = null;
        this.selectedRuleForEdit = null;
    }

    /**
     * Save rule (add or edit)
     */
    handleSaveRule(event) {
        console.log('[DecisionTableView] handleSaveRule called');
        
        // Validation
        const errors = {};
        if (!this.formData.previousStageId) {
            errors.previousStageId = 'Current Stage là bắt buộc';
        }
        if (!this.formData.actionButtonId) {
            errors.actionButtonId = 'Action Button là bắt buộc';
        }
        if (!this.formData.nextStageId) {
            errors.nextStageId = 'Next Stage là bắt buộc';
        }

        if (Object.keys(errors).length > 0) {
            this.formErrors = errors;
            console.log('[DecisionTableView] Validation errors:', errors);
            return;
        }

        this.isLoading = true;
        this.error = null;

        // Prepare data for Apex
        const stagChangeData = {
            previousStageId: this.formData.previousStageId,
            actionButtonId: this.formData.actionButtonId,
            nextStageId: this.formData.nextStageId,
            nextQueue: this.formData.nextQueue || '',
            teamUserGroup: this.formData.teamUserGroup || '',
            businessProcessId: this.selectedNode.idType
        };

        if (this.editingRule) {
            stagChangeData.recordId = this.editingRule;
        }

        console.log('[DecisionTableView] Calling Apex saveStagChangeRule:', stagChangeData);

        saveStagChangeRule({ stagChangeData })
            .then((result) => {
                console.log('[DecisionTableView] Rule saved successfully:', result);
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Thành công!',
                        message: this.editingRule ? 'Rule đã được cập nhật' : 'Rule mới đã được thêm',
                        variant: 'success'
                    })
                );

                this.handleCloseModal();
                this.refreshDecisionTable();
            })
            .catch((err) => {
                console.error('[DecisionTableView] Error saving rule:', err);
                this.error = err?.body?.message || 'Lỗi khi lưu Rule';
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Lỗi!',
                        message: this.error,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Handle modal input changes (lightning-combobox & input)
     */
    handleModalInputChange(event) {
        // lightning-combobox dùng event.detail.value, input dùng event.target.value
        const fieldName = event.target.name || event.target.dataset.fieldName;
        const value = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        
        this.formData = { ...this.formData, [fieldName]: value };
        
        // Clear error khi user chỉnh sửa
        if (this.formErrors[fieldName]) {
            const updatedErrors = { ...this.formErrors };
            delete updatedErrors[fieldName];
            this.formErrors = updatedErrors;
        }
        
        console.log('[DecisionTableView] Modal input changed:', { fieldName, value });
    }

    /**
     * Handle overlay click (close modal when clicking outside)
     */
    handleOverlayClick() {
        this.handleCloseModal();
    }

    /**
     * Handle dialog click (prevent closing when clicking inside dialog)
     */
    handleDialogClick(event) {
        event.stopPropagation();
    }

    get treeArrowIcon() {
        return this.isTreeExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get selectedItemLabel() {
        return this.selectedNode?.label || '';
    }

    get hasSelection() {
        return !!this.selectedNode?.idType;
    }

    get isBPSelected() {
        return this.selectedNode?.type === 'BUSINESS_PROCESS';
    }

    get isStageSelected() {
        return this.selectedNode?.type === 'STAGE';
    }

    get hasTreeData() {
        return this.treeData && this.treeData.length > 0;
    }

    get hasDecisionData() {
        return this.groupedRows && this.groupedRows.length > 0;
    }

    get hasNoSearchResults() {
        return this.hasSearchFilter && this.filteredGroupedRows && this.filteredGroupedRows.length === 0;
    }

    get totalRuleCount() {
        return this.decisionRows.length;
    }

    get stageCount() {
        return this.groupedRows.length;
    }

    get hasSearchFilter() {
        return this.searchFilter.trim().length > 0;
    }

    get displaySearchMessage() {
        if (!this.hasSearchFilter) return '';
        const matchCount = this.filteredGroupedRows.reduce((sum, g) => sum + g.rowCount, 0);
        return `Kết quả tìm kiếm: ${matchCount} rule`;
    }

    get previousStageClass() {
        return this.formErrors?.previousStageId ? 'slds-select select-error' : 'slds-select';
    }

    get actionButtonClass() {
        return this.formErrors?.actionButtonId ? 'slds-select select-error' : 'slds-select';
    }

    get nextStageClass() {
        return this.formErrors?.nextStageId ? 'slds-select select-error' : 'slds-select';
    }

    get modalSaveLabel() {
        return this.editingRule ? 'Cập nhật' : 'Thêm Rule';
    }

    /**
     * Lifecycle hook
     */
    connectedCallback() {
        console.log('[DecisionTableView] Component initialized');
    }
}
