import { LightningElement, api, track } from 'lwc';
import getDecisionTableByBPMDM from '@salesforce/apex/FEC_BusinessProcessService.getDecisionTableByBPMDM';
import getMDMStageOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMStageOptions';
import getMDMActionButtonOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMActionButtonOptions';
import deleteMDMStageChangeRule from '@salesforce/apex/FEC_BusinessProcessService.deleteMDMStageChangeRule';
import getRulesWithConditions from '@salesforce/apex/FEC_MDM_WorkflowEngine.getRulesWithConditions';
import getFieldsForStage from '@salesforce/apex/FEC_MDM_WorkflowEngine.getFieldsForStage';
import saveRuleWithConditions from '@salesforce/apex/FEC_MDM_WorkflowEngine.saveRuleWithConditions';
import { showLog } from 'c/fecMDMUtils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class FecFlowControlDataView extends LightningElement {

    // ── @api: nhận từ component cha ─────────────────────────
    @track _selectedBPId;
    @track _selectedBPLabel;
    @track _selectedNodeType; // 'BusinessProcess' | 'Stage'

    @api
    get item() {
        return this._item;
    }
    set item(value) {
        this._item = value;
        console.log('[FlowControlDataView] item set:', JSON.stringify(value));

        if (!value) {
            this._selectedBPId = null;
            this._selectedBPLabel = null;
            this._selectedNodeType = null;
            this.decisionRows = [];
            this.groupedRows = [];
            return;
        }

        this._selectedBPLabel = value.label || '';
        this.searchFilter = '';
        this.statusFilter = '';

        // idType là ID của node được click
        // Normalize type bằng cách bỏ khoảng trắng: 'Business Process' → 'BusinessProcess'
        const rawType = (value.type || '').replace(/\s+/g, '');
        const nodeType = rawType || 'BusinessProcess';
        this._selectedNodeType = nodeType;

        console.log('[FlowControlDataView] rawType:', value.type, '| normalized:', nodeType, '| idType:', value.idType);

        // Các type là node lá (không phải BP)
        const leafTypes = new Set(['Stage', 'Category', 'SubCategory', 'SubCode']);
        // Normalize value.type cũng để so sánh
        const isLeaf = leafTypes.has(nodeType);

        if (isLeaf) {
            // Node lá: không load table vì không có BP ID trực tiếp
            // parentId không tồn tại trong data → không xử lý
            this.decisionRows = [];
            this.groupedRows = [];
        } else {
            // BusinessProcess → dùng idType của node này = MDM BP ID
            // Lưu ý: idType từ live tree là Live BP ID,
            // cần map sang MDM BP ID qua FEC_Code__c
            this._selectedBPId = value.idType || null;
            if (this._selectedBPId) {
                this.loadDecisionTable(this._selectedBPId);
            } else {
                this.decisionRows = [];
                this.groupedRows = [];
            }
        }
    }
    @track _item;

    // ── Table state ─────────────────────────────────────────
    @track decisionRows = [];
    @track groupedRows = [];
    @track error;
    @track isLoading = false;

    // ── Filters ─────────────────────────────────────────────
    @track searchFilter = '';
    @track statusFilter = '';

    // ── Column labels ───────────────────────────────────────
    colCurrentStage = 'Nếu Current Stage là...';
    colConditions = 'Điều kiện';
    colAction = 'Nếu chọn Action...';
    colNextStage = 'Thì Next Stage sẽ là...';
    colNextQueue = 'Next Queue';
    colTeamUserGroup = 'Team/User Group';
    colStatus = 'Process Status';

    // ── Status filter options ───────────────────────────────
    statusFilterOptions = [
        { label: 'Tất cả', value: '' },
        { label: 'New', value: 'New' },
        { label: 'Update', value: 'Update' },
        { label: 'Synced', value: 'Synced' }
    ];

    // ── Condition Operator options ──────────────────────────
    operatorOptions = [
        { label: '=', value: 'EQUALS' },
        { label: '!=', value: 'NOT_EQUALS' },
        { label: 'Contains', value: 'CONTAINS' },
        { label: 'Not Contains', value: 'NOT_CONTAINS' },
        { label: '>', value: 'GREATER_THAN' },
        { label: '<', value: 'LESS_THAN' }
    ];

    conditionRequirementOptions = [
        { label: 'All Conditions Are Met (AND)', value: 'AND' },
        { label: 'Any Condition Is Met (OR)', value: 'OR' },
        { label: 'Custom Condition Logic Is Met', value: 'CUSTOM' }
    ];

    get isCustomLogic() {
        return this.formData && this.formData.conditionRequirement === 'CUSTOM';
    }

    // ── Value Type options ──────────────────────────────────
    valueTypeOptions = [
        { label: 'Text', value: 'String' },
        { label: 'Number', value: 'Number' },
        { label: 'Boolean', value: 'Boolean' },
        { label: 'List', value: 'List' }
    ];

    // ── Modal state ─────────────────────────────────────────
    @track showAddRuleModal = false;
    @track isEditMode = false;
    @track editingRowId;
    @track stageOptions = [];
    @track actionOptions = [];
    @track conditionFieldOptions = [];   // ← FEC_MDM_Master_Data_Setting__c options based on current stage
    @track formData = {};
    @track formErrors = {};

    // ── Condition expand/collapse per row ────────────────────
    @track expandedConditionRows = {};

    // ── Condition Side Panel ─────────────────────────────────
    @track showConditionPanel = false;
    @track activePanelRow = {};

    // ════════════════════════════════════════════════════════
    // LIFECYCLE
    // ════════════════════════════════════════════════════════
    renderedCallback() {
        // Sync native <select> selected values after every re-render
        if (this.showAddRuleModal) {
            this._syncNativeSelects();
        }
    }

    // ════════════════════════════════════════════════════════
    // LOAD DATA
    // ════════════════════════════════════════════════════════
    loadDecisionTable(bpId) {
        if (!bpId) return;
        this.isLoading = true;
        this.error = null;

        getRulesWithConditions({ businessProcessId: bpId })
            .then(data => {
                const arr = Array.isArray(data) ? data : [];
                console.log('[FlowControl] getRulesWithConditions loaded:', arr.length, 'rows');
                this.decisionRows = arr;
                this.groupedRows = arr.length > 0 ? this._buildGroupedRows(arr) : [];
            })
            .catch(err => {
                console.warn('[FlowControl] getRulesWithConditions failed, fallback:', err);
                // Fallback to legacy method
                getDecisionTableByBPMDM({ businessProcessId: bpId })
                    .then(data => {
                        const arr = Array.isArray(data) ? data : [];
                        console.log('[FlowControl] Legacy fallback loaded:', arr.length, 'rows');
                        this.decisionRows = arr;
                        this.groupedRows = arr.length > 0 ? this._buildGroupedRows(arr) : [];
                    })
                    .catch(err2 => {
                        console.error('[FlowControl] Load error:', err2);
                        this.error = err2?.body?.message || 'Có lỗi khi tải MDM Decision Table';
                        this.decisionRows = [];
                        this.groupedRows = [];
                    });
            })
            .finally(() => { this.isLoading = false; });
    }

    // ════════════════════════════════════════════════════════
    // LOAD FIELDS FOR STAGE
    // ════════════════════════════════════════════════════════
    loadConditionFields(stageId) {
        if (!stageId) {
            this.conditionFieldOptions = [];
            return Promise.resolve();
        }

        return getFieldsForStage({ stageId: stageId })
            .then(data => {
                this.conditionFieldOptions = data || [];
            })
            .catch(error => {
                console.error('Lỗi lấy danh sách Master Data Setting:', error);
                this.conditionFieldOptions = [];
            });
    }

    // ════════════════════════════════════════════════════════
    // BUILD GROUPED ROWS
    // ════════════════════════════════════════════════════════
    _buildGroupedRows(data) {
        const groups = [];
        const stageMap = new Map();

        data.forEach((row, index) => {
            const key = row.currentStageId || row.currentStage || `stage-${index}`;
            if (!stageMap.has(key)) {
                const group = {
                    stageKey: key,
                    stageName: row.currentStage || '--',
                    stageCode: row.currentStageCode || '',
                    stageId: row.currentStageId,
                    rules: []
                };
                stageMap.set(key, group);
                groups.push(group);
            }

            // Parse conditions from data
            const conditions = this._parseConditions(row.conditions);
            const conditionSummary = this._buildConditionSummary(conditions);

            stageMap.get(key).rules.push({
                rowId: row.rowId || `row-${index}`,
                action: row.action || '--',
                actionCode: row.actionCode || '',
                actionId: row.actionId,
                nextStage: row.nextStage || '--',
                nextStageCode: row.nextStageCode || '',
                nextStageId: row.nextStageId,
                nextQueue: row.nextQueue || '',
                teamUserGroup: row.teamUserGroup || '',
                priority: row.priority,
                active: row.active,
                conditionLogic: row.conditionLogic || '',
                conditions: conditions,
                conditionSummary: conditionSummary,
                hasConditions: conditions.length > 0,
                conditionCount: conditions.length,
                processChangeStatus: row.processChangeStatus || '--',
                statusClass: this._getStatusClass(row.processChangeStatus),
                currentStageId: row.currentStageId
            });
        });
        return groups;
    }

    _parseConditions(conditions) {
        if (!conditions) return [];
        if (Array.isArray(conditions)) return conditions;
        try {
            return JSON.parse(conditions);
        } catch (e) {
            return [];
        }
    }

    _buildConditionSummary(conditions) {
        if (!conditions || conditions.length === 0) return 'Bất kỳ';
        return conditions
            .map(c => `${c.fieldName || c.fieldApiName || ''} ${c.operator || ''} ${c.value || ''}`)
            .join(' AND ');
    }

    _getStatusClass(status) {
        if (status === 'Synced') return 'slds-badge status-synced'; // Green
        if (status === 'Update') return 'slds-badge status-updated'; // Yellow
        if (status === 'New') return 'slds-badge status-new'; // Red
        return 'slds-badge';
    }

    // ════════════════════════════════════════════════════════
    // FLAT ROWS
    // ════════════════════════════════════════════════════════
    get flatRows() {
        const search = (this.searchFilter || '').toLowerCase();
        const status = this.statusFilter || '';
        const result = [];

        if (!this.groupedRows || this.groupedRows.length === 0) {
            return result;
        }

        this.groupedRows.forEach(group => {
            if (!group.rules || group.rules.length === 0) {
                return;
            }

            const filtered = group.rules.filter(rule => {
                const matchSearch = !search ||
                    (group.stageName || '').toLowerCase().includes(search) ||
                    (rule.action || '').toLowerCase().includes(search) ||
                    (rule.nextStage || '').toLowerCase().includes(search) ||
                    (rule.conditionSummary || '').toLowerCase().includes(search);
                const matchStatus = !status || rule.processChangeStatus === status;
                return matchSearch && matchStatus;
            });

            filtered.forEach((rule) => {
                const isExpanded = !!this.expandedConditionRows[rule.rowId];
                result.push({
                    ...rule,
                    stageName: group.stageName,
                    stageCode: group.stageCode,
                    stageCellClass: 'col-current-stage stage-cell',
                    isExpanded: isExpanded,
                    expandIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                    formattedConditions: (rule.conditions || []).map((c, ci) => ({
                        ...c,
                        key: `${rule.rowId}-cond-${ci}`,
                        label: `${c.fieldName || c.fieldApiName || ''} ${c.operator} ${c.value}`,
                        typeLabel: c.fieldType || 'Text',
                        order: c.order || (ci + 1),
                        fieldName: c.fieldName || c.fieldApiName || '',
                        fieldApiName: c.fieldApiName || '',
                        fieldDisplay: c.fieldName || c.fieldApiName || ''
                    }))
                });
            });
        });
        return result;
    }

    // ════════════════════════════════════════════════════════
    // CONDITION EXPAND/COLLAPSE (Expandable Row)
    // ════════════════════════════════════════════════════════
    handleToggleConditions(event) {
        const rowId = event.currentTarget.dataset.rowId;
        this.expandedConditionRows = {
            ...this.expandedConditionRows,
            [rowId]: !this.expandedConditionRows[rowId]
        };
    }

    // ════════════════════════════════════════════════════════
    // SEARCH / FILTER HANDLERS
    // ════════════════════════════════════════════════════════
    handleSearchChange(event) {
        this.searchFilter = event.target.value;
    }

    handleClearSearch() {
        this.searchFilter = '';
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
    }

    // ── Auto-generate condition logic string (Bỏ dấu #) ──
    _autoConditionLogic() {
        const count = (this.formData.conditions || []).length;
        if (count === 0) return '';
        if (this.formData.conditionRequirement === 'CUSTOM') return this.formData.conditionLogic;

        const nums = Array.from({ length: count }, (_, i) => i + 1);
        return nums.join(` ${this.formData.conditionRequirement} `); // Nối bằng AND hoặc OR
    }

    // Bắt sự kiện khi Dropdown Requirement thay đổi
    handleRequirementChange(event) {
        this.formData.conditionRequirement = event.detail.value;
        this.formData.conditionLogic = this._autoConditionLogic();
    }

    // ════════════════════════════════════════════════════════
    // MODAL – ADD / EDIT / DELETE
    // ════════════════════════════════════════════════════════
    handleAddRule() {
        // 1. Check if node is BP
        if (!this._selectedBPId || this._selectedNodeType !== 'BusinessProcess') {
            this.showToast('Lỗi', 'Vui lòng chọn một Business Process hợp lệ.', 'error');
            return;
        }

        this.isLoading = true; // Bật cờ loading xoay vòng vòng

        // 2. GỌI API LẤY DANH SÁCH STAGE VÀ ACTION TRƯỚC KHI MỞ MODAL
        this._loadModalOptions().then(() => {
            // 3. Reset form data
            this.isEditMode = false;
            this.editingRowId = null;

            // Auto-priority = số rule hiện có + 1
            const nextPriority = this.decisionRows ? this.decisionRows.length + 1 : 1;

            this.formData = {
                previousStageId: '',
                actionButtonId: '',
                nextStageId: '',
                nextQueue: '',
                teamUserGroup: '',
                priority: nextPriority,
                conditionRequirement: 'AND',
                conditionLogic: '',
                conditions: []
            };

            this.formErrors = {};
            this.conditionFieldOptions = []; // Reset Field Options vì chưa chọn Stage

            // 4. Mở Modal sau khi đã có data
            this.showAddRuleModal = true;
        }).catch(error => {
            this.showToast('Lỗi', 'Không thể tải danh sách Stage và Action', 'error');
            console.error(error);
        }).finally(() => {
            this.isLoading = false; // Tắt loading
        });
    }

    handleEditRule(event) {
        const rowId = event.currentTarget.dataset.rowId;
        console.log('[handleEditRule] Editing rowId: ' + rowId);

        const row = this.decisionRows.find(r => r.rowId === rowId);
        if (!row) {
            this.showToast('Lỗi', 'Không tìm thấy dữ liệu dòng để chỉnh sửa.', 'error');
            return;
        }

        const conditions = this._parseConditions(row.conditions);

        this.isEditMode = true;
        this.editingRowId = rowId;
        this.isLoading = true;

        // BỘ DỊCH NGƯỢC: Map giá trị DB thành giá trị UI của thẻ Select
        const reverseOperatorMap = {
            '=': 'EQUALS',
            '!=': 'NOT_EQUALS',
            'Contains': 'CONTAINS',
            'Not Contains': 'NOT_CONTAINS',
            '>': 'GREATER_THAN',
            '<': 'LESS_THAN'
        };

        this._loadModalOptions().then(() => {
            return this.loadConditionFields(row.currentStageId || row.previousStageId);
        }).then(() => {
            // Map existing conditions into formData format
            const mappedConditions = (conditions || []).map((c, idx) => ({
                id: c.id || `existing-${idx}`,
                index: idx,
                displayIndex: c.order || (idx + 1),
                order: c.order || (idx + 1),
                fieldId: c.fieldId || '',
                fieldApiName: c.fieldApiName || '',
                // SỬA TẠI ĐÂY: Dùng reverse map để khôi phục value cho UI
                operator: reverseOperatorMap[c.operator] || c.operator || 'EQUALS',
                value: c.value || ''
            }));

            this.formData = {
                previousStageId: row.currentStageId || row.previousStageId || '',
                actionButtonId: row.actionId || row.actionButtonId || '',
                nextStageId: row.nextStageId || '',
                nextQueue: row.nextQueue || '',
                teamUserGroup: row.teamUserGroup || '',
                priority: row.priority || 1,
                conditionRequirement: row.conditionRequirement || 'AND',
                conditionLogic: row.conditionLogic || '',
                conditions: mappedConditions
            };
            this.formErrors = {};

            this.showAddRuleModal = true;
        }).catch(error => {
            this.showToast('Lỗi', 'Không thể tải dữ liệu rule', 'error');
            console.error(error);
        }).finally(() => {
            this.isLoading = false;
        });
    }

    handleDeleteRule(event) {
        const rowId = event.currentTarget.dataset.rowId;
        // eslint-disable-next-line no-alert
        if (!confirm('Bạn có chắc muốn xóa rule này không?')) return;

        deleteMDMStageChangeRule({ recordId: rowId })
            .then(() => {
                this.showToast('Thành công', 'Đã xóa rule.', 'success');
                this.loadDecisionTable(this._selectedBPId);
            })
            .catch(err => {
                this.showToast('Lỗi', err?.body?.message || 'Không thể xóa rule.', 'error');
            });
    }

    _loadModalOptions() {
        const p1 = getMDMStageOptions({ businessProcessId: this._selectedBPId })
            .then(data => { this.stageOptions = data || []; })
            .catch(() => { this.stageOptions = []; });

        const p2 = getMDMActionButtonOptions()
            .then(data => { this.actionOptions = data || []; })
            .catch(() => { this.actionOptions = []; });

        // Return promise so callers can wait for all options to be ready
        return Promise.all([p1, p2]);
    }

    handleModalInputChange(event) {
        const field = event.target.name || event.target.dataset.fieldName;
        const value = event.detail?.value ?? event.target.value;
        this.formData = { ...this.formData, [field]: value };
        if (this.formErrors[field]) {
            this.formErrors = { ...this.formErrors, [field]: null };
        }

        // --- BỔ SUNG LOGIC LINK MASTER DATA SETTING ---
        if (field === 'previousStageId') {
            // Tải lại danh sách Field của Stage mới
            this.loadConditionFields(value);

            // Xóa rỗng các điều kiện cũ vì Field của Stage cũ không còn hợp lệ ở Stage mới
            this.formData.conditions = [];
            if (this.formData.conditionRequirement !== 'CUSTOM') {
                this.formData.conditionLogic = '';
            }
        }
    }

    // ════════════════════════════════════════════════════════
    // MODAL – CONDITION MANAGEMENT
    // ════════════════════════════════════════════════════════
    handleAddCondition() {
        if (!this.formData.conditions) this.formData.conditions = [];
        const index = this.formData.conditions.length;

        this.formData.conditions.push({
            key: `new_${Date.now()}_${index}`,
            index: index,         // <--- THÊM DÒNG NÀY ĐỂ HTML BẮT ĐƯỢC
            displayIndex: index + 1,
            order: index + 1,
            fieldId: '',
            fieldApiName: '',
            operator: 'EQUALS',
            value: ''
        });

        if (this.formData.conditionRequirement !== 'CUSTOM') {
            this.formData.conditionLogic = this._autoConditionLogic();
        }
        // LWC doesn't always track deep changes, so we shallow clone
        this.formData = { ...this.formData };
    }

    handleRemoveCondition(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const conditions = this.formData.conditions || [];
        conditions.splice(idx, 1);
        // Re-order
        conditions.forEach((c, i) => { c.order = i + 1; });

        if (this.formData.conditionRequirement !== 'CUSTOM') {
            this.formData.conditionLogic = this._autoConditionLogic();
        }
        this.formData = { ...this.formData, conditions };
    }

    handleConditionFieldChange(event) {
        const idx = parseInt(event.target.dataset.index || event.currentTarget.dataset.index, 10);

        // --- THÊM CHỐT CHẶN BẢO VỆ NÀY ---
        if (isNaN(idx)) {
            console.error('Lỗi: Không tìm thấy data-index của dòng điều kiện này!');
            return;
        }
        // ---------------------------------

        const field = event.target.dataset.field || event.currentTarget.dataset.field; // "fieldId", "operator", "value"
        const val = event.target.value;

        const conditions = this.formData.conditions || [];
        if (!conditions[idx]) return;

        conditions[idx][field] = val;

        if (field === 'fieldId') {
            conditions[idx].fieldApiName = this._getAdditionalFieldApiName(val);
        }

        this.formData.conditions = [...conditions];

        if (this.formData.conditionRequirement !== 'CUSTOM') {
            this.formData.conditionLogic = this._autoConditionLogic();
        }
    }

    // Hàm tìm fieldApiName dựa trên ID của Master Data Setting
    _getAdditionalFieldApiName(mdmSettingId) {
        if (!mdmSettingId) return '';
        const found = this.conditionFieldOptions.find(opt => opt.value === mdmSettingId);
        return found ? found.fieldApiName : '';
    }

    // Sync native <select> elements' selected value to match formData
    _syncNativeSelects() {
        const rows = this.template.querySelectorAll('.condition-row');
        rows.forEach((row, idx) => {
            const cond = (this.formData.conditions || [])[idx];
            if (!cond) return;
            const fieldSel = row.querySelector('[data-field="fieldId"]');
            const opSel = row.querySelector('[data-field="operator"]');
            const valTypeSel = row.querySelector('[data-field="valueType"]');
            if (fieldSel && cond.fieldId) fieldSel.value = cond.fieldId;
            if (opSel && cond.operator) opSel.value = cond.operator;
            if (valTypeSel && cond.valueType) valTypeSel.value = cond.valueType;
        });
    }

    get formConditions() {
        return (this.formData.conditions || []).map((c, i) => ({
            ...c,
            index: i,
            orderNum: i + 1
        }));
    }

    get hasFormConditions() {
        return this.formData.conditions && this.formData.conditions.length > 0;
    }

    // ════════════════════════════════════════════════════════
    // MODAL – SAVE (with conditions)
    // ════════════════════════════════════════════════════════
    handleSaveRule() {
        if (!this._validateForm()) return;
        this.isLoading = true;

        // Map UI values (EQUALS, etc.) back to Salesforce restricted picklist values
        const operatorMap = {
            'EQUALS': '=',
            'NOT_EQUALS': '!=',
            'CONTAINS': 'Contains',
            'NOT_CONTAINS': 'Not Contains',
            'GREATER_THAN': '>',
            'LESS_THAN': '<'
        };

        const payload = {
            recordId: this.isEditMode ? this.editingRowId : null,
            previousStageId: this.formData.previousStageId,
            actionButtonId: this.formData.actionButtonId,
            nextStageId: this.formData.nextStageId,
            nextQueue: this.formData.nextQueue || null,
            teamUserGroup: this.formData.teamUserGroup || null,
            priority: this.formData.priority || 1,
            conditionRequirement: this.formData.conditionRequirement, // <- Thêm trường này
            conditionLogic: this.formData.conditionRequirement === 'CUSTOM'
                ? this.formData.conditionLogic
                : this._autoConditionLogic(), // <- Luôn tính lại cho chuẩn trước khi save
            conditions: (this.formData.conditions || []).map(c => ({
                id: c.id && !c.id.startsWith('new-') ? c.id : null,
                fieldId: c.fieldId || null,
                operator: operatorMap[c.operator] || c.operator, // Chuyển đổi sang value Picklist chuẩn
                value: c.value,
                order: c.order
            }))
        };

        console.log('[DEBUG] Calling API saveRuleWithConditions with payload:', JSON.stringify(payload));

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(result => {
                this.showToast('Thành công', this.isEditMode ? 'Đã cập nhật rule.' : 'Đã thêm rule mới.', 'success');
                this.showAddRuleModal = false;
                this.loadDecisionTable(this._selectedBPId);
            })
            .catch(err => {
                this.showToast('Lỗi', err?.body?.message || 'Không thể lưu rule.', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    _validateConditionLogicString(logicStr, conditionCount) {
        if (!logicStr || logicStr.trim() === '') return 'Logic không được để trống.';
        let str = logicStr.toUpperCase().trim();

        const validFormatRegex = /^[0-9A-Z\s()]+$/;
        if (!validFormatRegex.test(str)) return 'Chỉ dùng số, AND, OR và ().';

        const openCount = (str.match(/\(/g) || []).length;
        const closeCount = (str.match(/\)/g) || []).length;
        if (openCount !== closeCount) return 'Thiếu hoặc thừa dấu ngoặc đơn ().';

        const numberMatches = str.match(/\d+/g) || [];
        const uniqueNumbers = [...new Set(numberMatches.map(n => parseInt(n, 10)))];

        if (uniqueNumbers.length !== conditionCount) return `Logic phải chứa đủ ${conditionCount} số điều kiện.`;

        for (let num of uniqueNumbers) {
            if (num < 1 || num > conditionCount) return `Điều kiện số ${num} không tồn tại.`;
        }
        return null;
    }

    _validateForm() {
        const errors = {};
        if (!this.formData.previousStageId) errors.previousStageId = 'Vui lòng chọn Current Stage';
        if (!this.formData.actionButtonId) errors.actionButtonId = 'Vui lòng chọn Action Button';
        if (!this.formData.nextStageId) errors.nextStageId = 'Vui lòng chọn Next Stage';

        const conditions = this.formData.conditions || [];
        conditions.forEach((c, i) => {
            if (!c.fieldId) errors[`condition_${i}_field`] = `Điều kiện ${i + 1}: Vui lòng chọn Field`;
            if (!c.operator) errors[`condition_${i}_operator`] = `Điều kiện ${i + 1}: Vui lòng chọn Operator`;
        });

        // Chỉ Validate bằng Regex khi chọn CUSTOM
        if (conditions.length > 0 && this.formData.conditionRequirement === 'CUSTOM') {
            let logicError = this._validateConditionLogicString(this.formData.conditionLogic, conditions.length);
            if (logicError) {
                errors['conditionLogic'] = logicError;
                this.showToast('Lỗi Logic Điều Kiện', logicError, 'error');
            }
        }

        this.formErrors = errors;
        return Object.keys(errors).length === 0;
    }

    handleCloseModal() { this.showAddRuleModal = false; }
    handleOverlayClick() { this.showAddRuleModal = false; }
    handleDialogClick(event) { event.stopPropagation(); }

    // ════════════════════════════════════════════════════════
    // COMPUTED GETTERS
    // ════════════════════════════════════════════════════════
    get hasSelection() { return !!this._selectedBPId || !!this._selectedNodeType; }
    // isBPSelected = true khi đã có BP ID (dù type là gì), Stage chỉ khi type='Stage' VÀ không có bpId
    get isBPSelected() { return !!this._selectedBPId; }
    get isStageSelected() { return this._selectedNodeType === 'Stage' && !this._selectedBPId; }
    get hasDecisionData() { return this.groupedRows && this.groupedRows.length > 0; }
    get hasSearchFilter() { return !!(this.searchFilter || this.statusFilter); }
    get selectedItemLabel() { return this._selectedBPLabel || ''; }

    get hasNoSearchResults() {
        return this.hasSearchFilter && this.flatRows.length === 0 && this.hasDecisionData;
    }

    get displaySearchMessage() {
        return `Hiển thị ${this.flatRows.length} / ${this.decisionRows.length} rule(s)`;
    }

    get totalRuleCount() {
        return this.decisionRows.length;
    }

    get stageCount() {
        return this.groupedRows.length;
    }

    get modalTitle() { return this.isEditMode ? 'Chỉnh sửa MDM Rule' : 'Thêm MDM Rule mới'; }
    get modalSaveLabel() { return this.isEditMode ? 'Cập nhật' : 'Lưu'; }

    // ── Toast ────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}