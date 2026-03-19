import { LightningElement, api, track } from 'lwc';
import getDecisionTableByBPMDM from '@salesforce/apex/FEC_BusinessProcessService.getDecisionTableByBPMDM';
import getMDMStageOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMStageOptions';
import getMDMActionButtonOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMActionButtonOptions';
import deleteMDMStageChangeRule from '@salesforce/apex/FEC_BusinessProcessService.deleteMDMStageChangeRule';
import getRulesWithConditions from '@salesforce/apex/FEC_MDM_WorkflowEngine.getRulesWithConditions';
import getAdditionalFieldOptions from '@salesforce/apex/FEC_MDM_WorkflowEngine.getAdditionalFieldOptions';
import saveRuleWithConditions from '@salesforce/apex/FEC_MDM_WorkflowEngine.saveRuleWithConditions';
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
            this._selectedBPId     = null;
            this._selectedBPLabel  = null;
            this._selectedNodeType = null;
            this.decisionRows = [];
            this.groupedRows  = [];
            return;
        }

        this._selectedBPLabel  = value.label || '';
        this.searchFilter = '';
        this.statusFilter = '';

        // idType là ID của node được click
        // Normalize type bằng cách bỏ khoảng trắng: 'Business Process' → 'BusinessProcess'
        const rawType  = (value.type || '').replace(/\s+/g, '');
        const nodeType = rawType || 'BusinessProcess';
        this._selectedNodeType = nodeType;

        console.log('[FlowControlDataView] rawType:', value.type, '| normalized:', nodeType, '| idType:', value.idType);

        // Các type là node lá (không phải BP)
        const leafTypes = new Set(['Stage','Category','SubCategory','SubCode']);
        // Normalize value.type cũng để so sánh
        const isLeaf = leafTypes.has(nodeType);

        if (isLeaf) {
            // Node lá: không load table vì không có BP ID trực tiếp
            // parentId không tồn tại trong data → không xử lý
            this.decisionRows = [];
            this.groupedRows  = [];
        } else {
            // BusinessProcess → dùng idType của node này = MDM BP ID
            // Lưu ý: idType từ live tree là Live BP ID,
            // cần map sang MDM BP ID qua FEC_Code__c
            this._selectedBPId = value.idType || null;
            if (this._selectedBPId) {
                this.loadDecisionTable(this._selectedBPId);
            } else {
                this.decisionRows = [];
                this.groupedRows  = [];
            }
        }
    }
    @track _item;

    // ── Table state ─────────────────────────────────────────
    @track decisionRows = [];
    @track groupedRows  = [];
    @track error;
    @track isLoading = false;

    // ── Filters ─────────────────────────────────────────────
    @track searchFilter = '';
    @track statusFilter = '';

    // ── Column labels ───────────────────────────────────────
    colCurrentStage  = 'Nếu Current Stage là...';
    colConditions    = 'Điều kiện';
    colAction        = 'Nếu chọn Action...';
    colNextStage     = 'Thì Next Stage sẽ là...';
    colNextQueue     = 'Next Queue';
    colTeamUserGroup = 'Team/User Group';
    colStatus        = 'Process Status';

    // ── Status filter options ───────────────────────────────
    statusFilterOptions = [
        { label: 'Tất cả',    value: '' },
        { label: 'New',       value: 'New' },
        { label: 'Update',    value: 'Update' },
        { label: 'Synced',    value: 'Synced' }
    ];

    // ── Condition Operator options ──────────────────────────
    operatorOptions = [
        { label: '= (Bằng)',                value: '='           },
        { label: '!= (Khác)',               value: '!='          },
        { label: '> (Lớn hơn)',             value: '>'           },
        { label: '>= (Lớn hơn hoặc bằng)', value: '>='          },
        { label: '< (Nhỏ hơn)',             value: '<'           },
        { label: '<= (Nhỏ hơn hoặc bằng)', value: '<='          },
        { label: 'IN (Nằm trong)',          value: 'IN'          },
        { label: 'NOT IN',                  value: 'NOT IN'      },
        { label: 'CONTAINS',               value: 'CONTAINS'    },
        { label: 'STARTS WITH',            value: 'STARTS WITH' },
        { label: 'ENDS WITH',              value: 'ENDS WITH'   }
    ];

    // ── Value Type options ──────────────────────────────────
    valueTypeOptions = [
        { label: 'Text',    value: 'String'  },
        { label: 'Number',  value: 'Number'  },
        { label: 'Boolean', value: 'Boolean' },
        { label: 'List',    value: 'List'    }
    ];

    // ── Modal state ─────────────────────────────────────────
    @track showAddRuleModal = false;
    @track isEditMode       = false;
    @track editingRowId;
    @track stageOptions          = [];
    @track actionOptions         = [];
    @track additionalFieldOptions = [];   // ← FEC_MDM_Additional_Field__c options
    @track formData         = {};
    @track formErrors       = {};

    // ── Condition expand/collapse per row ────────────────────
    @track expandedConditionRows = {};

    // ── Condition Side Panel ─────────────────────────────────
    @track showConditionPanel = false;
    @track activePanelRow     = {};

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
        this.error     = null;

        getRulesWithConditions({ businessProcessId: bpId })
            .then(data => {
                const arr = Array.isArray(data) ? data : [];
                console.log('[FlowControl] getRulesWithConditions loaded:', arr.length, 'rows');
                this.decisionRows = arr;
                this.groupedRows  = arr.length > 0 ? this._buildGroupedRows(arr) : [];
            })
            .catch(err => {
                console.warn('[FlowControl] getRulesWithConditions failed, fallback:', err);
                // Fallback to legacy method
                getDecisionTableByBPMDM({ businessProcessId: bpId })
                    .then(data => {
                        const arr = Array.isArray(data) ? data : [];
                        console.log('[FlowControl] Legacy fallback loaded:', arr.length, 'rows');
                        this.decisionRows = arr;
                        this.groupedRows  = arr.length > 0 ? this._buildGroupedRows(arr) : [];
                    })
                    .catch(err2 => {
                        console.error('[FlowControl] Load error:', err2);
                        this.error        = err2?.body?.message || 'Có lỗi khi tải MDM Decision Table';
                        this.decisionRows = [];
                        this.groupedRows  = [];
                    });
            })
            .finally(() => { this.isLoading = false; });
    }

    // ════════════════════════════════════════════════════════
    // BUILD GROUPED ROWS
    // ════════════════════════════════════════════════════════
    _buildGroupedRows(data) {
        const groups   = [];
        const stageMap = new Map();

        data.forEach((row, index) => {
            const key = row.currentStageId || row.currentStage || `stage-${index}`;
            if (!stageMap.has(key)) {
                const group = {
                    stageKey:  key,
                    stageName: row.currentStage || '--',
                    stageCode: row.currentStageCode || '',
                    stageId:   row.currentStageId,
                    rules:     []
                };
                stageMap.set(key, group);
                groups.push(group);
            }

            // Parse conditions from data
            const conditions = this._parseConditions(row.conditions);
            const conditionSummary = this._buildConditionSummary(conditions);

            stageMap.get(key).rules.push({
                rowId:               row.rowId || `row-${index}`,
                action:              row.action    || '--',
                actionCode:          row.actionCode || '',
                actionId:            row.actionId,
                nextStage:           row.nextStage  || '--',
                nextStageCode:       row.nextStageCode || '',
                nextStageId:         row.nextStageId,
                nextQueue:           row.nextQueue     || '',
                teamUserGroup:       row.teamUserGroup || '',
                priority:            row.priority,
                active:              row.active,
                conditionLogic:      row.conditionLogic || '',
                conditions:          conditions,
                conditionSummary:    conditionSummary,
                hasConditions:       conditions.length > 0,
                conditionCount:      conditions.length,
                processChangeStatus: row.processChangeStatus || '--',
                statusClass:         this._getStatusClass(row.processChangeStatus),
                currentStageId:      row.currentStageId
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
        if (status === 'Synced')   return 'slds-badge status-synced'; // Green
        if (status === 'Update')   return 'slds-badge status-updated'; // Yellow
        if (status === 'New')      return 'slds-badge status-new'; // Red
        return 'slds-badge';
    }

    // ════════════════════════════════════════════════════════
    // FLAT ROWS
    // ════════════════════════════════════════════════════════
    get flatRows() {
        const search = (this.searchFilter || '').toLowerCase();
        const status = this.statusFilter  || '';
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
                    (group.stageName       || '').toLowerCase().includes(search) ||
                    (rule.action           || '').toLowerCase().includes(search) ||
                    (rule.nextStage        || '').toLowerCase().includes(search) ||
                    (rule.conditionSummary || '').toLowerCase().includes(search);
                const matchStatus = !status || rule.processChangeStatus === status;
                return matchSearch && matchStatus;
            });

            filtered.forEach((rule) => {
                const isExpanded = !!this.expandedConditionRows[rule.rowId];
                result.push({
                    ...rule,
                    stageName:      group.stageName,
                    stageCode:      group.stageCode,
                    stageCellClass: 'col-current-stage stage-cell',
                    isExpanded:     isExpanded,
                    expandIcon:     isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                    formattedConditions: (rule.conditions || []).map((c, ci) => ({
                        ...c,
                        key:          `${rule.rowId}-cond-${ci}`,
                        label:        `${c.fieldName || c.fieldApiName || ''} ${c.operator} ${c.value}`,
                        typeLabel:    c.valueType || 'String',
                        order:        c.order || (ci + 1),
                        fieldName:    c.fieldName    || c.fieldApiName || '',
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
        this.statusFilter = '';
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.detail.value;
    }

    // ════════════════════════════════════════════════════════
    // MODAL – ADD / EDIT / DELETE
    // ════════════════════════════════════════════════════════
    handleAddRule() {
        this.isEditMode   = false;
        this.editingRowId = null;
        // Auto-priority = số rule hiện có + 1
        const nextPriority = this.decisionRows.length + 1;
        this.formData     = {
            previousStageId: '',
            actionButtonId:  '',
            nextStageId:     '',
            nextQueue:       '',
            teamUserGroup:   '',
            priority:        nextPriority,
            conditionLogic:  '',
            conditions:      []
        };
        this.formErrors = {};
        this._loadModalOptions();
        this.showAddRuleModal = true;
    }

    handleEditRule(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const row   = this.decisionRows.find(r => r.rowId === rowId);
        if (!row) return;

        const conditions = this._parseConditions(row.conditions);

        this.isEditMode      = true;
        this.editingRowId    = rowId;
        this.formErrors      = {};
        this.showAddRuleModal = true;

        // Load options first, then populate conditions so combobox has options ready
        this._loadModalOptions().then(() => {
            const mappedConditions = conditions.map((c, i) => ({
                id:           c.id || `existing-${i}`,
                fieldId:      c.fieldId      || '',
                fieldName:    c.fieldName    || '',
                fieldNameVN:  c.fieldNameVN  || '',
                fieldApiName: c.fieldApiName || '',
                operator:     c.operator     || '=',
                value:        c.value        || '',
                valueType:    c.valueType    || 'String',
                order:        c.order        || (i + 1)
            }));
            const condLogic = row.conditionLogic
                || this._autoConditionLogic(mappedConditions.length);
            this.formData = {
                previousStageId: row.currentStageId || '',
                actionButtonId:  row.actionId       || '',
                nextStageId:     row.nextStageId    || '',
                nextQueue:       row.nextQueue      || '',
                teamUserGroup:   row.teamUserGroup  || '',
                priority:        row.priority       || 1,
                conditionLogic:  condLogic,
                conditions:      mappedConditions
            };
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
            .then(data => { this.stageOptions  = data || []; })
            .catch(()  => { this.stageOptions  = []; });

        const p2 = getMDMActionButtonOptions()
            .then(data => { this.actionOptions = data || []; })
            .catch(()  => { this.actionOptions = []; });

        const p3 = getAdditionalFieldOptions()
            .then(data => {
                this.additionalFieldOptions = (data || []).map(f => ({
                    label:        f.label,
                    value:        f.value,        // ID của FEC_MDM_Additional_Field__c
                    fieldApiName: f.fieldApiName,
                    dataType:     f.dataType
                }));
            })
            .catch(() => { this.additionalFieldOptions = []; });

        // Return promise so callers can wait for all options to be ready
        return Promise.all([p1, p2, p3]);
    }

    handleModalInputChange(event) {
        const field = event.target.name || event.target.dataset.fieldName;
        const value = event.detail?.value ?? event.target.value;
        this.formData = { ...this.formData, [field]: value };
        if (this.formErrors[field]) {
            this.formErrors = { ...this.formErrors, [field]: null };
        }
    }

    // ── Auto-generate condition logic string: #1 AND #2 AND #3 ... ──
    _autoConditionLogic(count) {
        if (count === 0) return '';
        return Array.from({ length: count }, (_, i) => `#${i + 1}`).join(' AND ');
    }

    // ════════════════════════════════════════════════════════
    // MODAL – CONDITION MANAGEMENT
    // ════════════════════════════════════════════════════════
    handleAddCondition() {
        const newConditions = [
            ...(this.formData.conditions || []),
            {
                id:           `new-${Date.now()}`,
                fieldId:      '',
                fieldName:    '',
                fieldApiName: '',
                operator:     '=',
                value:        '',
                valueType:    'String',
                order:        (this.formData.conditions || []).length + 1
            }
        ];
        this.formData = {
            ...this.formData,
            conditions:     newConditions,
            conditionLogic: this._autoConditionLogic(newConditions.length)
        };
    }

    handleRemoveCondition(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const updated = (this.formData.conditions || [])
            .filter((_, i) => i !== idx)
            .map((c, i) => ({ ...c, order: i + 1 }));
        this.formData = {
            ...this.formData,
            conditions:     updated,
            conditionLogic: this._autoConditionLogic(updated.length)
        };
    }

    handleConditionFieldChange(event) {
        const idx   = parseInt(event.currentTarget.dataset.index, 10);
        const field = event.currentTarget.dataset.field;
        // native <select> uses event.target.value; lightning-combobox uses event.detail.value
        const value = event.detail?.value ?? event.target.value;

        const updated = (this.formData.conditions || []).map((c, i) => {
            if (i !== idx) return c;
            const updatedCond = { ...c, [field]: value };
            // When fieldId changes, auto-resolve fieldApiName & fieldName from additionalFieldOptions
            if (field === 'fieldId') {
                const found = this.additionalFieldOptions.find(opt => opt.value === value);
                if (found) {
                    updatedCond.fieldApiName = found.fieldApiName;
                    updatedCond.fieldName    = found.label;
                    // Auto-set valueType based on dataType
                    const dtMap = {
                        'Currency': 'Number', 'Number': 'Number', 'Double': 'Number',
                        'Integer': 'Number',  'Boolean': 'Boolean',
                        'Picklist': 'String', 'Text': 'String', 'Date': 'String',
                        'DateTime': 'String', 'Email': 'String', 'Phone': 'String'
                    };
                    updatedCond.valueType = dtMap[found.dataType] || 'String';
                }
            }
            return updatedCond;
        });
        this.formData = { ...this.formData, conditions: updated };

        // Re-sync native select selected value after re-render
        // (LWC does not auto-bind "selected" attr on <option>)
        if (field === 'fieldId' || field === 'operator' || field === 'valueType') {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this._syncNativeSelects(), 0);
        }
    }

    // Sync native <select> elements' selected value to match formData
    _syncNativeSelects() {
        const rows = this.template.querySelectorAll('.condition-row');
        rows.forEach((row, idx) => {
            const cond = (this.formData.conditions || [])[idx];
            if (!cond) return;
            const fieldSel    = row.querySelector('[data-field="fieldId"]');
            const opSel       = row.querySelector('[data-field="operator"]');
            const valTypeSel  = row.querySelector('[data-field="valueType"]');
            if (fieldSel   && cond.fieldId)   fieldSel.value   = cond.fieldId;
            if (opSel      && cond.operator)  opSel.value      = cond.operator;
            if (valTypeSel && cond.valueType) valTypeSel.value = cond.valueType;
        });
    }

    get formConditions() {
        return (this.formData.conditions || []).map((c, i) => ({
            ...c,
            index:    i,
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

        const payload = {
            recordId:        this.isEditMode ? this.editingRowId : null,
            previousStageId: this.formData.previousStageId,
            actionButtonId:  this.formData.actionButtonId,
            nextStageId:     this.formData.nextStageId,
            nextQueue:       this.formData.nextQueue      || null,
            teamUserGroup:   this.formData.teamUserGroup  || null,
            priority:        this.formData.priority       || 1,
            conditionLogic:  this.formData.conditionLogic || null,
            conditions:      (this.formData.conditions || []).map(c => ({
                id:        c.id && !c.id.startsWith('new-') ? c.id : null,
                fieldId:   c.fieldId   || null,
                operator:  c.operator,
                value:     c.value,
                valueType: c.valueType,
                order:     c.order
            }))
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => {
                this.showToast('Thành công', this.isEditMode ? 'Đã cập nhật rule.' : 'Đã thêm rule mới.', 'success');
                this.showAddRuleModal = false;
                this.loadDecisionTable(this._selectedBPId);
            })
            .catch(err => {
                this.showToast('Lỗi', err?.body?.message || 'Không thể lưu rule.', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    _validateForm() {
        const errors = {};
        if (!this.formData.previousStageId) errors.previousStageId = 'Vui lòng chọn Current Stage';
        if (!this.formData.actionButtonId)  errors.actionButtonId  = 'Vui lòng chọn Action Button';
        if (!this.formData.nextStageId)     errors.nextStageId     = 'Vui lòng chọn Next Stage';

        // Validate conditions: fieldId (lookup) is required
        (this.formData.conditions || []).forEach((c, i) => {
            if (!c.fieldId) {
                errors[`condition_${i}_field`] = `Điều kiện ${i + 1}: Vui lòng chọn Field`;
            }
            if (!c.operator) {
                errors[`condition_${i}_operator`] = `Điều kiện ${i + 1}: Vui lòng chọn Operator`;
            }
        });

        this.formErrors = errors;
        return Object.keys(errors).length === 0;
    }

    handleCloseModal()        { this.showAddRuleModal = false; }
    handleOverlayClick()      { this.showAddRuleModal = false; }
    handleDialogClick(event)  { event.stopPropagation(); }

    // ════════════════════════════════════════════════════════
    // COMPUTED GETTERS
    // ════════════════════════════════════════════════════════
    get hasSelection()    { return !!this._selectedBPId || !!this._selectedNodeType; }
    // isBPSelected = true khi đã có BP ID (dù type là gì), Stage chỉ khi type='Stage' VÀ không có bpId
    get isBPSelected()    { return !!this._selectedBPId; }
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

    get modalTitle()     { return this.isEditMode ? 'Chỉnh sửa MDM Rule' : 'Thêm MDM Rule mới'; }
    get modalSaveLabel() { return this.isEditMode ? 'Cập nhật' : 'Lưu'; }

    // ── Toast ────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}