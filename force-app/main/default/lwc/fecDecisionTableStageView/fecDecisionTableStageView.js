/**
 * @description LWC Controller for Decision Table Stage View (PEGA-style)
 *              Displays Stage Change rules in a Decision Table format
 *              with dynamic condition columns and fixed action columns.
 *              Uses FEC_MDM_Stage_Change__c + FEC_MDM_Stage_Change_Condition__c
 *              (NOT the EAV pattern).
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import getDecisionTableData from '@salesforce/apex/FEC_MDM_WorkflowEngine.getDecisionTableData';
import getFieldsForBusinessProcess from '@salesforce/apex/FEC_MDM_WorkflowEngine.getFieldsForBusinessProcess';
import saveRuleWithConditions from '@salesforce/apex/FEC_MDM_WorkflowEngine.saveRuleWithConditions';
import deleteRule from '@salesforce/apex/FEC_MDM_WorkflowEngine.deleteRule';
import deleteConditionColumn from '@salesforce/apex/FEC_MDM_WorkflowEngine.deleteConditionColumn';
import testRuleEvaluation from '@salesforce/apex/FEC_MDM_WorkflowEngine.testRuleEvaluation';
import updateColumnProperties from '@salesforce/apex/FEC_MDM_WorkflowEngine.updateColumnProperties';
import getMDMStageOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMStageOptions';
import getMDMActionButtonOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMActionButtonOptions';

export default class FecDecisionTableStageView extends LightningElement {

    // ════════════════════════════════════════════════════════
    // @api tableKey — generic key to support multiple Decision Table types
    // Default: empty (uses FEC_MDM_Stage_Change__c as before)
    // When set (e.g. "STAGE_TRANSITION"), uses FEC_MDM_Decision_Rule__c
    // ════════════════════════════════════════════════════════
    @api tableKey = '';

    // ════════════════════════════════════════════════════════
    // @api item property setter
    // ════════════════════════════════════════════════════════
    @api
    get item() {
        return this._item;
    }
    set item(value) {
        this._item = value;

        if (!value) {
            this._resetState();
            return;
        }

        this._selectedBPLabel = value.label || '';
        this.searchFilter = '';

        const rawType = (value.type || '').replace(/\s+/g, '');
        const nodeType = rawType || 'BusinessProcess';
        const leafTypes = new Set(['Stage', 'Category', 'SubCategory', 'SubCode']);
        const isLeaf = leafTypes.has(nodeType);

        if (isLeaf) {
            this._clearData();
            this._showLeafMessage = true;
        } else {
            this._currentBPId = value.idType || null;
            this._showLeafMessage = false;
            if (this._currentBPId) {
                this.loadDecisionTable();
            } else {
                this._clearData();
            }
        }
    }
    _item;

    // ════════════════════════════════════════════════════════
    // State management
    // ════════════════════════════════════════════════════════
    @track fixedConditionColumns = [
        { key: 'previousStage', label: 'Previous Stage', type: 'fixed' },
        { key: 'actionButton', label: 'Action Button', type: 'fixed' }
    ];
    @track dynamicConditionColumns = [];
    @track actionColumns = [
        { key: 'nextStage', label: 'Next Stage' },
        { key: 'nextQueue', label: 'Next Queue' },
        { key: 'teamUserGroup', label: 'Team/User Group' }
    ];
    @track rows = [];
    @track originalRows = [];
    selectedColKey = null;
    selectedColGroup = null; // 'condition' | 'action'
    selectedRowId = null;
    @track searchFilter = '';
    @track fieldOptions = [];
    @track showAddRuleModal = false;
    @track showAddColModal = false;
    @track newColGroup = 'condition'; // 'condition' | 'action'
    @track newColActionName = '';
    @track selectedNewColOperator = 'EQUALS'; // operator for new condition column
    _addColDirection = 'right'; // 'left' | 'right'
    @track dynamicActionColumns = [];
    @track isEditMode = false;
    @track editingRowId = null;
    @track isLoading = false;
    @track error = null;

    // ── Inline Edit state ───────────────────────────────────
    editingCellKey = null;   // format: `${ruleId}_${fieldId}_${valueIndex}`
    @track editingCellValue = '';
    hoverCellKey = null;     // for mini toolbar on cells with value (format: `${ruleId}_${fieldId}_${valueIndex}`)

    // ── Edit Column Modal state ─────────────────────────────
    @track showEditColModal = false;
    @track editColFieldId = null;
    @track editColFieldName = '';
    @track editColOperator = 'EQUALS';
    @track editColExpression = '';

    // ── Expression Mode state (Add Column modal) ────────────
    @track showExpressionMode = false;
    @track expressionValue = '';

    // ── Expression options (combobox select) ─────────────────
    expressionOptions = [
        { label: '-- Không áp dụng --', value: '' },
        { label: 'TRIM — Bỏ khoảng trắng đầu/cuối', value: 'TRIM' },
        { label: 'UPPER — Chuyển thành chữ hoa', value: 'UPPER' },
        { label: 'LOWER — Chuyển thành chữ thường', value: 'LOWER' },
        { label: 'LENGTH — Độ dài chuỗi', value: 'LENGTH' },
        { label: 'LEFT(n) — Lấy n ký tự đầu', value: 'LEFT' },
        { label: 'RIGHT(n) — Lấy n ký tự cuối', value: 'RIGHT' }
    ];

    _currentBPId = null;
    _selectedBPLabel = '';
    _showLeafMessage = false;

    // ── Modal form data ─────────────────────────────────────
    @track formData = {
        previousStageId: '',
        actionButtonId: '',
        nextStageId: '',
        nextQueue: '',
        teamUserGroup: '',
        priority: 1,
        conditions: []
    };

    // ── Modal options ───────────────────────────────────────
    @track stageOptions = [];
    @track actionButtonOptions = [];
    @track selectedNewColFieldId = null;

    // ── Operator options ────────────────────────────────────
    operatorOptions = [
        { label: '=', value: 'EQUALS' },
        { label: '!=', value: 'NOT_EQUALS' },
        { label: '>', value: 'GREATER_THAN' },
        { label: '<', value: 'LESS_THAN' },
        { label: '>=', value: 'GREATER_THAN_OR_EQUAL' },
        { label: '<=', value: 'LESS_THAN_OR_EQUAL' },
        { label: 'IN', value: 'IN' },
        { label: 'NOT IN', value: 'NOT_IN' },
        { label: 'Contains', value: 'CONTAINS' },
        { label: 'Starts With', value: 'STARTS_WITH' },
        { label: 'Ends With', value: 'ENDS_WITH' }
    ];

    // ── Operator label map (value → display symbol) ────────
    operatorLabelMap = {
        'EQUALS': '=',
        'NOT_EQUALS': '!=',
        'GREATER_THAN': '>',
        'LESS_THAN': '<',
        'GREATER_THAN_OR_EQUAL': '>=',
        'LESS_THAN_OR_EQUAL': '<=',
        'IN': 'IN',
        'NOT_IN': 'NOT IN',
        'CONTAINS': 'Contains',
        'STARTS_WITH': 'Starts With',
        'ENDS_WITH': 'Ends With',
        'BETWEEN': 'BETWEEN'
    };

    // ── Reverse operator map (display → value) ─────────────
    reverseOperatorMap = {
        '=': 'EQUALS',
        '!=': 'NOT_EQUALS',
        'Contains': 'CONTAINS',
        'Not Contains': 'NOT_CONTAINS',
        '>': 'GREATER_THAN',
        '<': 'LESS_THAN',
        '>=': 'GREATER_THAN_OR_EQUAL',
        '<=': 'LESS_THAN_OR_EQUAL',
        'IN': 'IN',
        'NOT IN': 'NOT_IN',
        'Starts With': 'STARTS_WITH',
        'Ends With': 'ENDS_WITH',
        'BETWEEN': 'BETWEEN'
    };

    // conditionRequirementOptions removed — AND implicit always applied

    // ════════════════════════════════════════════════════════
    // LOAD DECISION TABLE DATA
    // ════════════════════════════════════════════════════════
    loadDecisionTable() {
        if (!this._currentBPId) return;
        this.isLoading = true;
        this.error = null;
        this._clearTestResult();

        getDecisionTableData({ businessProcessId: this._currentBPId })
            .then(result => {
                this.transformToDecisionTable(result);
                this._loadModalOptions();
            })
            .catch(err => {
                this.error = err.body?.message || err.message || 'Có lỗi khi tải Decision Table';
                this._clearData();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ════════════════════════════════════════════════════════
    // TRANSFORM RULES DATA → DECISION TABLE FORMAT
    // ════════════════════════════════════════════════════════
    transformToDecisionTable(data) {
        const rulesData = data.rules || [];
        const serverColumns = data.conditionColumns || [];

        // 1. Build unique dynamic condition columns from server data (MDS fields)
        const fieldMap = new Map();
        for (const col of serverColumns) {
            const fId = col.fieldId;
            if (fId && !fieldMap.has(fId)) {
                fieldMap.set(fId, {
                    fieldId: fId,
                    fieldName: col.fieldName || '',
                    fieldApiName: col.fieldApiName || '',
                    dataType: col.dataType || 'Text',
                    operator: 'EQUALS' // default, will be overridden below
                });
            }
        }

        // 2. Extract operator + expression per column from conditions
        //    Range detection: if any condition has expression 'RANGE_START' or 'RANGE_END' → range column
        //    Fallback: if same field has both start (>=, >) and end (<=, <) operators → range column
        const startOps = new Set(['>=', '>', 'GREATER_THAN_OR_EQUAL', 'GREATER_THAN']);
        const endOps = new Set(['<=', '<', 'LESS_THAN_OR_EQUAL', 'LESS_THAN']);
        const fieldOpsMap = new Map(); // fieldId → Set of operators
        const fieldRangeMarkers = new Map(); // fieldId → { hasStart, hasEnd, startOp, endOp }
        for (const rule of rulesData) {
            const conditions = this._parseConditions(rule.conditions);
            for (const cond of conditions) {
                if (cond.fieldId && fieldMap.has(cond.fieldId)) {
                    if (!fieldOpsMap.has(cond.fieldId)) {
                        fieldOpsMap.set(cond.fieldId, new Set());
                    }
                    fieldOpsMap.get(cond.fieldId).add(cond.operator);

                    // Check RANGE markers
                    if (!fieldRangeMarkers.has(cond.fieldId)) {
                        fieldRangeMarkers.set(cond.fieldId, { hasStart: false, hasEnd: false, startOp: '>=', endOp: '<=' });
                    }
                    const markers = fieldRangeMarkers.get(cond.fieldId);
                    if (cond.expression === 'RANGE_START') {
                        markers.hasStart = true;
                        markers.startOp = cond.operator || '>=';
                    } else if (cond.expression === 'RANGE_END') {
                        markers.hasEnd = true;
                        markers.endOp = cond.operator || '<=';
                    }

                    // Set non-range expression
                    const col = fieldMap.get(cond.fieldId);
                    if (!col.expression && cond.expression && cond.expression !== 'RANGE_START' && cond.expression !== 'RANGE_END') {
                        col.expression = cond.expression;
                    }
                }
            }
        }

        // Determine column type
        const opNorm = { 'GREATER_THAN_OR_EQUAL': '>=', 'GREATER_THAN': '>', 'LESS_THAN_OR_EQUAL': '<=', 'LESS_THAN': '<' };
        for (const [fId, ops] of fieldOpsMap) {
            const col = fieldMap.get(fId);
            const markers = fieldRangeMarkers.get(fId);

            // Range detection: RANGE markers take priority
            if (markers && (markers.hasStart || markers.hasEnd)) {
                col.operator = 'BETWEEN';
                col.rangeStartOp = opNorm[markers.startOp] || markers.startOp || '>=';
                col.rangeEndOp = opNorm[markers.endOp] || markers.endOp || '<=';
            } else {
                // Fallback: detect from operator pairs
                const hasStart = [...ops].some(op => startOps.has(op));
                const hasEnd = [...ops].some(op => endOps.has(op));
                if (hasStart && hasEnd) {
                    col.operator = 'BETWEEN';
                    const sOp = [...ops].find(op => startOps.has(op)) || '>=';
                    const eOp = [...ops].find(op => endOps.has(op)) || '<=';
                    col.rangeStartOp = opNorm[sOp] || sOp;
                    col.rangeEndOp = opNorm[eOp] || eOp;
                } else if (ops.size > 0) {
                    const firstOp = [...ops][0];
                    col.operator = this.reverseOperatorMap[firstOp] || firstOp;
                }
            }
        }

        this.dynamicConditionColumns = [...fieldMap.values()];

        // Preserve operator/range info from previous local state for columns
        // where condition-based detection couldn't determine the operator
        // (e.g., range column with no cell values yet, or newly added column)
        if (this._prevDynamicConditionColumns) {
            for (const col of this.dynamicConditionColumns) {
                if (col.operator === 'EQUALS') {
                    const prev = this._prevDynamicConditionColumns.find(p => p.fieldId === col.fieldId);
                    if (prev && prev.operator && prev.operator !== 'EQUALS') {
                        col.operator = prev.operator;
                        if (prev.operator === 'BETWEEN') {
                            col.rangeStartOp = prev.rangeStartOp || '>=';
                            col.rangeEndOp = prev.rangeEndOp || '<=';
                        }
                    }
                }
            }
        }
        this._prevDynamicConditionColumns = [...this.dynamicConditionColumns];

        // 3. Transform each rule into a row with separated conditionValues / actionValues
        //    OR support: group multiple conditions for same field into values array
        const transformedRows = rulesData.map(rule => {
            const conditions = this._parseConditions(rule.conditions);

            // Group conditions by fieldId — multiple conditions for same field = OR sub-values
            const condGroupMap = new Map();
            for (const cond of conditions) {
                if (cond.fieldId) {
                    if (!condGroupMap.has(cond.fieldId)) {
                        condGroupMap.set(cond.fieldId, []);
                    }
                    condGroupMap.get(cond.fieldId).push({
                        conditionId: cond.id || null,
                        operator: cond.operator || '',
                        value: cond.value || '',
                        expression: cond.expression || '',
                        order: cond.order
                    });
                }
            }

            // Dynamic MDS condition cells — each cell has a values array for OR support
            const conditionCells = this.dynamicConditionColumns.map(col => {
                const condGroup = condGroupMap.get(col.fieldId) || [];
                const colOperator = col.operator || 'EQUALS';
                const isInOperator = colOperator === 'IN' || colOperator === 'NOT_IN';
                const isRange = colOperator === 'BETWEEN';

                // Range: merge RANGE_START + RANGE_END into combined "start,end" value
                if (isRange && condGroup.length > 0) {
                    let startVal = '';
                    let endVal = '';
                    for (const cond of condGroup) {
                        // Use expression marker or operator to determine start/end
                        const expr = cond.expression || '';
                        if (expr === 'RANGE_START') {
                            startVal = cond.value || '';
                        } else if (expr === 'RANGE_END') {
                            endVal = cond.value || '';
                        } else {
                            // Fallback: use operator to guess
                            const op = cond.operator || '';
                            if (op === '>=' || op === '>') startVal = cond.value || '';
                            else if (op === '<=' || op === '<') endVal = cond.value || '';
                        }
                    }
                    const combinedValue = `${startVal},${endVal}`;
                    return {
                        fieldId: col.fieldId,
                        conditionId: condGroup[0].conditionId || null,
                        operator: condGroup[0].operator || '',
                        value: combinedValue,
                        displayValue: combinedValue,
                        isMultiValue: false,
                        valuePills: [],
                        values: [{
                            key: `val_${col.fieldId}_0`,
                            conditionId: condGroup[0].conditionId || null,
                            value: combinedValue,
                            displayValue: combinedValue,
                            isMultiValue: false,
                            valuePills: []
                        }],
                        hasOrValues: false
                    };
                }

                // Build values array (OR sub-values)
                let values;
                if (condGroup.length > 0) {
                    values = condGroup.map((cond, vi) => {
                        const valuePills = isInOperator && cond.value
                            ? cond.value.split(',').map((v, pi) => ({ key: `pill_${col.fieldId}_${vi}_${pi}`, label: v.trim() }))
                            : [];
                        return {
                            key: `val_${col.fieldId}_${vi}`,
                            conditionId: cond.conditionId,
                            value: cond.value,
                            displayValue: cond.value || '',
                            isMultiValue: isInOperator && valuePills.length > 0,
                            valuePills
                        };
                    });
                } else {
                    values = [{ key: `val_${col.fieldId}_0`, conditionId: null, value: '', displayValue: '', isMultiValue: false, valuePills: [] }];
                }

                // Backward compat: single-value shorthand
                const firstVal = values[0] || {};
                return {
                    fieldId: col.fieldId,
                    conditionId: firstVal.conditionId || null,
                    operator: condGroup.length > 0 ? condGroup[0].operator : '',
                    value: firstVal.value || '',
                    displayValue: firstVal.displayValue || '',
                    isMultiValue: firstVal.isMultiValue || false,
                    valuePills: firstVal.valuePills || [],
                    values,
                    hasOrValues: values.length > 1
                };
            });

            return {
                ruleId: rule.rowId,
                priority: rule.priority,
                active: rule.active,
                conditionLogic: rule.conditionLogic || '',
                conditionRequirement: rule.conditionRequirement || 'AND',
                processChangeStatus: rule.processChangeStatus || '',
                // Fixed conditions (input used to match rule)
                conditionValues: {
                    previousStage: rule.currentStage || '',
                    previousStageId: rule.currentStageId || '',
                    actionButton: rule.action || '',
                    actionButtonId: rule.actionId || ''
                },
                // Actions (output when rule matches)
                actionValues: {
                    nextStage: rule.nextStage || '',
                    nextStageId: rule.nextStageId || '',
                    nextQueue: rule.nextQueue || '',
                    teamUserGroup: rule.teamUserGroup || ''
                },
                conditionCells,
                conditions
            };
        });

        this.rows = transformedRows;
        this.originalRows = [...transformedRows];
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

    // ════════════════════════════════════════════════════════
    // SEARCH / FILTER
    // ════════════════════════════════════════════════════════
    handleSearchChange(event) {
        this.searchFilter = event.target.value;
    }

    handleClearSearch() {
        this.searchFilter = '';
    }

    get filteredRows() {
        if (!this.searchFilter || !this.searchFilter.trim()) {
            return this.originalRows;
        }
        const term = this.searchFilter.toLowerCase();
        return this.originalRows.filter(row => {
            // Search in dynamic condition cells — check all OR sub-values
            const matchCondition = (row.conditionCells || []).some(cell =>
                (cell.values || []).some(v => (v.displayValue || v.value || '').toLowerCase().includes(term))
            );
            if (matchCondition) return true;

            // Search in fixed condition values (previousStage, actionButton)
            const cv = row.conditionValues || {};
            if ((cv.previousStage || '').toLowerCase().includes(term)) return true;
            if ((cv.actionButton || '').toLowerCase().includes(term)) return true;

            // Search in action values (nextStage, nextQueue, teamUserGroup)
            const av = row.actionValues || {};
            return (av.nextStage || '').toLowerCase().includes(term) ||
                   (av.nextQueue || '').toLowerCase().includes(term) ||
                   (av.teamUserGroup || '').toLowerCase().includes(term);
        });
    }

    // ════════════════════════════════════════════════════════
    // SELECTION HANDLERS
    // ════════════════════════════════════════════════════════
    handleSelectColumn(event) {
        const colKey = event.currentTarget.dataset.colKey;
        const colGroup = event.currentTarget.dataset.colGroup;
        if (this.selectedColKey === colKey) {
            this.selectedColKey = null;
            this.selectedColGroup = null;
        } else {
            this.selectedColKey = colKey;
            this.selectedColGroup = colGroup || null;
        }
        this.selectedRowId = null;
        this.hoverCellKey = null;
        this.editingCellKey = null;
    }

    handleSelectRow(event) {
        if (event.target.tagName === 'LIGHTNING-ICON' || event.target.tagName === 'BUTTON') return;
        const rowId = event.currentTarget.dataset.rowId;
        this.selectedRowId = (this.selectedRowId === rowId) ? null : rowId;
        this.selectedColKey = null;
        this.selectedColGroup = null;
        this.hoverCellKey = null;
        this.editingCellKey = null;
    }

    // ════════════════════════════════════════════════════════
    // ADD COLUMN — Left / Right
    // ════════════════════════════════════════════════════════
    handleAddColLeft() {
        this._addColDirection = 'left';
        this._openAddColModal();
    }

    handleAddColRight() {
        this._addColDirection = 'right';
        this._openAddColModal();
    }

    _openAddColModal() {
        this.isLoading = true;
        this.selectedNewColFieldId = null;
        this.newColGroup = this.selectedColGroup || 'condition';
        this.newColActionName = '';

        getFieldsForBusinessProcess({ businessProcessId: this._currentBPId })
            .then(data => {
                this.fieldOptions = (data || []).map(f => ({
                    label: f.label || f.fieldName,
                    value: f.value || f.fieldId,
                    fieldApiName: f.fieldApiName || '',
                    dataType: f.dataType || 'Text'
                }));
                this.showAddColModal = true;
            })
            .catch(err => {
                this.showToast('Lỗi', err.body?.message || err.message || 'Không thể tải danh sách fields', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleNewColGroupChange(event) {
        this.newColGroup = event.detail.value;
    }

    handleNewColFieldChange(event) {
        this.selectedNewColFieldId = event.detail.value;
    }

    handleNewColActionNameChange(event) {
        this.newColActionName = event.target.value;
    }

    handleNewColOperatorChange(event) {
        this.selectedNewColOperator = event.detail.value;
    }

    // ── Use Range (Add Column) ──
    useRange = false;
    rangeStartOp = '>=';
    rangeEndOp = '<=';

    get startRangeOperatorOptions() {
        return [
            { label: '>= (lớn hơn hoặc bằng)', value: '>=' },
            { label: '> (lớn hơn)', value: '>' }
        ];
    }

    get endRangeOperatorOptions() {
        return [
            { label: '<= (nhỏ hơn hoặc bằng)', value: '<=' },
            { label: '< (nhỏ hơn)', value: '<' }
        ];
    }

    handleToggleUseRange(event) {
        this.useRange = event.target.checked;
        if (this.useRange) {
            this.selectedNewColOperator = 'BETWEEN';
            this.rangeStartOp = '>=';
            this.rangeEndOp = '<=';
        } else {
            this.selectedNewColOperator = 'EQUALS';
        }
    }

    handleRangeStartOpChange(event) {
        this.rangeStartOp = event.detail.value;
    }

    handleRangeEndOpChange(event) {
        this.rangeEndOp = event.detail.value;
    }

    // ── Use Range (Edit Column) ──
    editColUseRange = false;
    editColRangeStartOp = '>=';
    editColRangeEndOp = '<=';

    handleToggleEditColUseRange(event) {
        this.editColUseRange = event.target.checked;
        if (this.editColUseRange) {
            this.editColOperator = 'BETWEEN';
            this.editColRangeStartOp = '>=';
            this.editColRangeEndOp = '<=';
        } else {
            this.editColOperator = 'EQUALS';
        }
    }

    handleEditColRangeStartOpChange(event) {
        this.editColRangeStartOp = event.detail.value;
    }

    handleEditColRangeEndOpChange(event) {
        this.editColRangeEndOp = event.detail.value;
    }

    handleToggleExpression() {
        this.showExpressionMode = !this.showExpressionMode;
        if (!this.showExpressionMode) {
            this.expressionValue = '';
        }
    }

    handleExpressionChange(event) {
        this.expressionValue = event.detail?.value ?? event.target.value ?? '';
    }

    get isConditionColGroup() {
        return this.newColGroup === 'condition';
    }

    get isActionColGroup() {
        return this.newColGroup === 'action';
    }

    get colGroupOptions() {
        return [
            { label: 'Condition', value: 'condition' },
            { label: 'Action', value: 'action' }
        ];
    }

    handleConfirmAddCol() {
        if (this.newColGroup === 'condition') {
            this._confirmAddConditionCol();
        } else {
            this._confirmAddActionCol();
        }
    }

    _confirmAddConditionCol() {
        if (!this.selectedNewColFieldId) {
            this.showToast('Lỗi', 'Vui lòng chọn một field', 'error');
            return;
        }

        // Allow same field with different operator (PEGA style: 2 columns for same field)
        const selectedField = this.fieldOptions.find(f => f.value === this.selectedNewColFieldId);
        if (!selectedField) return;

        const operator = this.selectedNewColOperator || 'EQUALS';

        // Check if exact same field+operator combo already exists
        const exists = this.dynamicConditionColumns.some(
            c => c.fieldId === this.selectedNewColFieldId && c.operator === operator
        );
        if (exists) {
            this.showToast('Lỗi', 'Cột với field và operator này đã tồn tại', 'error');
            return;
        }

        const newCol = {
            fieldId: selectedField.value,
            fieldName: selectedField.label.replace(/\s*\(.*?\)\s*$/, '').trim() || selectedField.label,
            fieldApiName: selectedField.fieldApiName || '',
            dataType: selectedField.dataType || 'Text',
            operator: operator,
            expression: this.expressionValue || '',
            rangeStartOp: this.useRange ? this.rangeStartOp : '',
            rangeEndOp: this.useRange ? this.rangeEndOp : ''
        };

        // Determine insert position relative to selected column
        const insertIdx = this._getConditionInsertIndex();
        const updated = [...this.dynamicConditionColumns];
        updated.splice(insertIdx, 0, newCol);
        this.dynamicConditionColumns = updated;
        this._prevDynamicConditionColumns = [...updated];

        // Add empty condition cells to all existing rows at the same index
        this.originalRows = this.originalRows.map(row => {
            const cells = [...(row.conditionCells || [])];
            cells.splice(insertIdx, 0, {
                fieldId: selectedField.value,
                conditionId: null,
                operator: '',
                value: '',
                displayValue: '',
                values: [{ key: `val_${selectedField.value}_0`, conditionId: null, value: '', displayValue: '', isMultiValue: false, valuePills: [] }],
                hasOrValues: false
            });
            return { ...row, conditionCells: cells };
        });
        this.rows = [...this.originalRows];

        this._closeAddColModal();
    }

    _confirmAddActionCol() {
        if (!this.newColActionName || !this.newColActionName.trim()) {
            this.showToast('Lỗi', 'Vui lòng nhập tên cột Action', 'error');
            return;
        }

        const colName = this.newColActionName.trim();
        const colKey = `customAction_${Date.now()}`;
        const newCol = {
            key: colKey,
            label: colName,
            type: 'dynamicAction'
        };

        // Determine insert position relative to selected column in action columns
        const insertIdx = this._getActionInsertIndex();
        const updated = [...this.dynamicActionColumns];
        updated.splice(insertIdx, 0, newCol);
        this.dynamicActionColumns = updated;

        this._closeAddColModal();
    }

    /**
     * Calculate insert index for a new condition column relative to selected column.
     * If selected column is a dynamic condition column, insert left/right of it.
     * Otherwise, append at end.
     */
    _getConditionInsertIndex() {
        if (!this.selectedColKey) return this.dynamicConditionColumns.length;

        const idx = this.dynamicConditionColumns.findIndex(c => c.fieldId === this.selectedColKey);
        if (idx === -1) {
            // Selected column is not a dynamic condition column — append at end
            return this.dynamicConditionColumns.length;
        }
        return this._addColDirection === 'left' ? idx : idx + 1;
    }

    /**
     * Calculate insert index for a new action column relative to selected column.
     */
    _getActionInsertIndex() {
        if (!this.selectedColKey) return this.dynamicActionColumns.length;

        const idx = this.dynamicActionColumns.findIndex(c => c.key === this.selectedColKey);
        if (idx === -1) {
            return this.dynamicActionColumns.length;
        }
        return this._addColDirection === 'left' ? idx : idx + 1;
    }

    _closeAddColModal() {
        this.showAddColModal = false;
        this.selectedNewColFieldId = null;
        this.selectedNewColOperator = 'EQUALS';
        this.newColGroup = 'condition';
        this.newColActionName = '';
        this.showExpressionMode = false;
        this.expressionValue = '';
        this.useRange = false;
        this.rangeStartOp = '>=';
        this.rangeEndOp = '<=';
    }

    handleCloseAddColModal() {
        this._closeAddColModal();
    }

    // ════════════════════════════════════════════════════════
    // DELETE COLUMN
    // ════════════════════════════════════════════════════════
    async handleDeleteColumn() {
        if (!this.selectedColKey || this._isFixedColumn(this.selectedColKey)) return;

        const confirmed = await LightningConfirm.open({
            message: 'Xóa cột sẽ xóa tất cả điều kiện liên quan trên mọi dòng. Tiếp tục?',
            variant: 'header',
            label: 'Xác nhận xóa cột',
            theme: 'warning'
        });
        if (!confirmed) return;

        // Check if it's a dynamic action column (UI-only)
        const isDynamicAction = this.dynamicActionColumns.some(c => c.key === this.selectedColKey);
        if (isDynamicAction) {
            this.dynamicActionColumns = this.dynamicActionColumns.filter(c => c.key !== this.selectedColKey);
            this.selectedColKey = null;
            this.selectedColGroup = null;
            this.showToast('Thành công', 'Đã xóa cột action', 'success');
            return;
        }

        // Dynamic condition column — call Apex
        this.isLoading = true;
        deleteConditionColumn({
            businessProcessId: this._currentBPId,
            masterDataSettingId: this.selectedColKey
        })
            .then(() => {
                this.showToast('Thành công', 'Đã xóa cột điều kiện', 'success');
                this.selectedColKey = null;
                this.selectedColGroup = null;
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Lỗi', err.body?.message || err.message || 'Không thể xóa cột', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _isFixedColumn(colKey) {
        const FIXED_COL_KEYS = new Set(['previousStage', 'actionButton', 'nextStage', 'nextQueue', 'teamUserGroup']);
        return FIXED_COL_KEYS.has(colKey);
    }

    // ════════════════════════════════════════════════════════
    // ADD ROW — Above / Below
    // ════════════════════════════════════════════════════════
    handleAddRowAbove() {
        this._addRowAtPosition('above');
    }

    handleAddRowBelow() {
        this._addRowAtPosition('below');
    }

    _addRowAtPosition(position) {
        if (!this._currentBPId) {
            this.showToast('Lỗi', 'Vui lòng chọn một Business Process', 'error');
            return;
        }

        this.isLoading = true;
        this._loadModalOptions()
            .then(() => {
                this.isEditMode = false;
                this.editingRowId = null;

                let newPriority = this.originalRows ? this.originalRows.length + 1 : 1;

                if (this.selectedRowId) {
                    const selectedRow = this.originalRows.find(r => r.ruleId === this.selectedRowId);
                    if (selectedRow) {
                        const selectedPriority = selectedRow.priority || 1;
                        const sortedRows = [...this.originalRows].sort((a, b) => (a.priority || 0) - (b.priority || 0));
                        const selectedIdx = sortedRows.findIndex(r => r.ruleId === this.selectedRowId);

                        if (position === 'above') {
                            const prevRow = selectedIdx > 0 ? sortedRows[selectedIdx - 1] : null;
                            const prevPriority = prevRow ? (prevRow.priority || 0) : 0;
                            newPriority = (prevPriority + selectedPriority) / 2;
                        } else {
                            const nextRow = selectedIdx < sortedRows.length - 1 ? sortedRows[selectedIdx + 1] : null;
                            const nextPriority = nextRow ? (nextRow.priority || 0) : selectedPriority + 1;
                            newPriority = (selectedPriority + nextPriority) / 2;
                        }
                    }
                }

                this.formData = {
                    previousStageId: '',
                    actionButtonId: '',
                    nextStageId: '',
                    nextQueue: '',
                    teamUserGroup: '',
                    priority: newPriority,
                    conditions: this.dynamicConditionColumns.map((col, idx) => ({
                        key: `new_${Date.now()}_${idx}`,
                        index: idx,
                        displayIndex: idx + 1,
                        order: idx + 1,
                        fieldId: col.fieldId,
                        fieldName: col.fieldName,
                        fieldApiName: col.fieldApiName || '',
                        operator: col.operator || 'EQUALS',
                        value: ''
                    }))
                };

                this.showAddRuleModal = true;
            })
            .catch(err => {
                this.showToast('Lỗi', err.body?.message || err.message || 'Không thể tải dữ liệu', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ════════════════════════════════════════════════════════
    // EDIT ROW (Rule)
    // ════════════════════════════════════════════════════════
    handleEditRow(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const row = this.originalRows.find(r => r.ruleId === rowId);
        if (!row) {
            this.showToast('Lỗi', 'Không tìm thấy dữ liệu dòng để chỉnh sửa', 'error');
            return;
        }

        this.isLoading = true;
        this.isEditMode = true;
        this.editingRowId = rowId;

        // Build column operator map for PEGA style
        const colOperatorMap = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOperatorMap.set(col.fieldId, col.operator || 'EQUALS');
        }

        this._loadModalOptions()
            .then(() => {
                // Map condition cells back to form conditions — flatten OR sub-values
                const mappedConditions = [];
                this.dynamicConditionColumns.forEach((col) => {
                    const cell = (row.conditionCells || []).find(c => c.fieldId === col.fieldId);
                    const values = cell ? (cell.values || []) : [];
                    if (values.length === 0 || (values.length === 1 && !values[0].value)) {
                        // Single empty slot
                        mappedConditions.push({
                            key: `edit_${Date.now()}_${mappedConditions.length}`,
                            index: mappedConditions.length,
                            displayIndex: mappedConditions.length + 1,
                            order: mappedConditions.length + 1,
                            fieldId: col.fieldId,
                            fieldName: col.fieldName,
                            fieldApiName: col.fieldApiName || '',
                            conditionId: values[0] ? values[0].conditionId : null,
                            operator: col.operator || 'EQUALS',
                            value: values[0] ? (values[0].value || '') : ''
                        });
                    } else {
                        // One entry per OR sub-value
                        for (const val of values) {
                            mappedConditions.push({
                                key: `edit_${Date.now()}_${mappedConditions.length}`,
                                index: mappedConditions.length,
                                displayIndex: mappedConditions.length + 1,
                                order: mappedConditions.length + 1,
                                fieldId: col.fieldId,
                                fieldName: col.fieldName,
                                fieldApiName: col.fieldApiName || '',
                                conditionId: val.conditionId || null,
                                operator: col.operator || 'EQUALS',
                                value: val.value || ''
                            });
                        }
                    }
                });

                const cv = row.conditionValues || {};
                const av = row.actionValues || {};
                this.formData = {
                    previousStageId: cv.previousStageId || '',
                    actionButtonId: cv.actionButtonId || '',
                    nextStageId: av.nextStageId || '',
                    nextQueue: av.nextQueue || '',
                    teamUserGroup: av.teamUserGroup || '',
                    priority: row.priority || 1,
                    conditions: mappedConditions
                };

                this.showAddRuleModal = true;
            })
            .catch(err => {
                this.showToast('Lỗi', err.body?.message || err.message || 'Không thể tải dữ liệu rule', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ════════════════════════════════════════════════════════
    // DELETE ROW (Rule)
    // ════════════════════════════════════════════════════════
    async handleDeleteRow() {
        if (!this.selectedRowId) return;

        // Prevent deleting otherwise row
        const selectedRow = this.originalRows.find(r => r.ruleId === this.selectedRowId);
        if (selectedRow && this._isOtherwiseRow(selectedRow)) {
            this.showToast('Lỗi', 'Không thể xóa dòng otherwise (fallback)', 'error');
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: 'Bạn có chắc muốn xóa rule này không? Tất cả điều kiện liên quan sẽ bị xóa.',
            variant: 'header',
            label: 'Xác nhận xóa rule',
            theme: 'warning'
        });
        if (!confirmed) return;

        this.isLoading = true;
        deleteRule({ ruleId: this.selectedRowId })
            .then(() => {
                this.showToast('Thành công', 'Đã xóa rule', 'success');
                this.selectedRowId = null;
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Lỗi', err.body?.message || err.message || 'Không thể xóa rule', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ════════════════════════════════════════════════════════
    // SAVE RULE (Add / Edit)
    // ════════════════════════════════════════════════════════
    handleSaveRule() {
        if (!this._validateForm()) return;
        this.isLoading = true;

        const operatorMap = {
            'EQUALS': '=',
            'NOT_EQUALS': '!=',
            'CONTAINS': 'Contains',
            'NOT_CONTAINS': 'Not Contains',
            'GREATER_THAN': '>',
            'LESS_THAN': '<',
            'GREATER_THAN_OR_EQUAL': '>=',
            'LESS_THAN_OR_EQUAL': '<=',
            'IN': 'IN',
            'NOT_IN': 'NOT IN',
            'STARTS_WITH': 'Starts With',
            'ENDS_WITH': 'Ends With'
        };

        const rangeOpToPicklist = {
            '>=': '>=', '>': '>', '<=': '<=', '<': '<'
        };

        // Build maps of fieldId → column operator + column info
        const colOperatorMap = new Map();
        const colInfoMap = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOperatorMap.set(col.fieldId, col.operator || 'EQUALS');
            colInfoMap.set(col.fieldId, col);
        }

        // Build conditions — range columns split into 2 separate records
        const builtConditions = [];
        for (const c of (this.formData.conditions || [])) {
            if (!c.fieldId || !c.value) continue;
            const colOp = colOperatorMap.get(c.fieldId) || c.operator || 'EQUALS';
            const colInfo = colInfoMap.get(c.fieldId);
            const isRange = colOp === 'BETWEEN';

            if (isRange) {
                const parts = c.value.includes(',') ? c.value.split(',') : [c.value, ''];
                const startVal = (parts[0] || '').trim();
                const endVal = (parts[1] || '').trim();
                const startOp = colInfo ? (colInfo.rangeStartOp || '>=') : '>=';
                const endOp = colInfo ? (colInfo.rangeEndOp || '<=') : '<=';

                // Always create both start and end records for range detection on reload
                builtConditions.push({
                    id: null,
                    fieldId: c.fieldId,
                    operator: rangeOpToPicklist[startOp] || '>=',
                    value: startVal || '',
                    expression: 'RANGE_START',
                    order: builtConditions.length + 1
                });
                builtConditions.push({
                    id: null,
                    fieldId: c.fieldId,
                    operator: rangeOpToPicklist[endOp] || '<=',
                    value: endVal || '',
                    expression: 'RANGE_END',
                    order: builtConditions.length + 1
                });
            } else {
                builtConditions.push({
                    id: c.conditionId && !String(c.conditionId).startsWith('new') ? c.conditionId : null,
                    fieldId: c.fieldId || null,
                    operator: operatorMap[colOp] || colOp,
                    value: c.value,
                    order: c.order
                });
            }
        }

        const payload = {
            recordId: this.isEditMode ? this.editingRowId : null,
            previousStageId: this.formData.previousStageId,
            actionButtonId: this.formData.actionButtonId,
            nextStageId: this.formData.nextStageId,
            nextQueue: this.formData.nextQueue || null,
            teamUserGroup: this.formData.teamUserGroup || null,
            priority: this.formData.priority || 1,
            conditionRequirement: 'AND',
            conditionLogic: '', // No longer auto-generated — runtime engine evaluates directly
            conditions: builtConditions
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => {
                this.showToast(
                    'Thành công',
                    this.isEditMode ? 'Đã cập nhật rule' : 'Đã thêm rule mới',
                    'success'
                );
                this.showAddRuleModal = false;
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Lỗi', err.body?.message || err.message || 'Không thể lưu rule', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _validateForm() {
        const errors = [];
        if (!this.formData.previousStageId) errors.push('Vui lòng chọn Previous Stage');
        if (!this.formData.actionButtonId) errors.push('Vui lòng chọn Action Button');
        if (!this.formData.nextStageId) errors.push('Vui lòng chọn Next Stage');

        if (errors.length > 0) {
            this.showToast('Lỗi', errors.join('. '), 'error');
            return false;
        }
        return true;
    }

    _autoConditionLogic() {
        const count = (this.formData.conditions || []).filter(c => c.fieldId && c.value).length;
        if (count === 0) return '';
        const nums = Array.from({ length: count }, (_, i) => i + 1);
        return nums.join(' AND ');
    }

    /**
     * Generate condition logic with OR grouping for a rule's condition cells.
     * Groups conditions by fieldId: OR within same field, AND between fields.
     * Example: field A has conditions 1,2 and field B has condition 3 → (1 OR 2) AND 3
     */
    _autoConditionLogicForRule(conditionsPayload) {
        if (!conditionsPayload || conditionsPayload.length === 0) return '';

        // Group by fieldId
        const fieldGroups = new Map();
        conditionsPayload.forEach((cond, idx) => {
            const num = idx + 1;
            const fId = cond.fieldId;
            if (!fieldGroups.has(fId)) {
                fieldGroups.set(fId, []);
            }
            fieldGroups.get(fId).push(num);
        });

        // Build logic string
        const parts = [];
        for (const nums of fieldGroups.values()) {
            if (nums.length === 1) {
                parts.push(String(nums[0]));
            } else {
                parts.push('(' + nums.join(' OR ') + ')');
            }
        }
        return parts.join(' AND ');
    }

    // ════════════════════════════════════════════════════════
    // MODAL HELPERS
    // ════════════════════════════════════════════════════════
    _loadModalOptions() {
        const p1 = getMDMStageOptions({ businessProcessId: this._currentBPId })
            .then(data => { this.stageOptions = data || []; })
            .catch(() => { this.stageOptions = []; });

        const p2 = getMDMActionButtonOptions()
            .then(data => { this.actionButtonOptions = data || []; })
            .catch(() => { this.actionButtonOptions = []; });

        return Promise.all([p1, p2]);
    }

    handleModalInputChange(event) {
        const field = event.target.name || event.target.dataset.fieldName;
        const value = event.detail?.value ?? event.target.value;
        this.formData = { ...this.formData, [field]: value };
    }

    // handleRequirementChange removed — AND implicit always applied

    handleConditionFieldChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        if (isNaN(idx)) return;

        const field = event.target.dataset.field;
        const val = event.target.value || event.detail?.value;

        const conditions = [...(this.formData.conditions || [])];
        if (!conditions[idx]) return;

        conditions[idx] = { ...conditions[idx], [field]: val };
        this.formData = { ...this.formData, conditions };
    }

    /**
     * Handle range input change in modal (start or end value).
     * Merges start + end into "start,end" format.
     */
    handleRangeConditionChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        if (isNaN(idx)) return;

        const rangePart = event.target.dataset.rangePart; // 'start' or 'end'
        const newVal = event.target.value || '';

        const conditions = [...(this.formData.conditions || [])];
        if (!conditions[idx]) return;

        const currentValue = conditions[idx].value || '';
        const parts = currentValue.includes(',') ? currentValue.split(',') : [currentValue, ''];
        let startVal = (parts[0] || '').trim();
        let endVal = (parts[1] || '').trim();

        if (rangePart === 'start') {
            startVal = newVal.trim();
        } else {
            endVal = newVal.trim();
        }

        const combined = (startVal || endVal) ? `${startVal},${endVal}` : '';
        conditions[idx] = { ...conditions[idx], value: combined };
        this.formData = { ...this.formData, conditions };
    }

    handleAddPillValue(event) {
        const idx = parseInt(event.target.dataset.index || event.currentTarget.dataset.index, 10);
        if (isNaN(idx)) return;

        // Find the input in the same pill-input-container
        const container = event.target.closest('.pill-input-container') || event.currentTarget.closest('.pill-input-container');
        const input = container ? container.querySelector('lightning-input') : null;
        const newVal = input ? (input.value || '').trim() : '';
        if (!newVal) return;

        const conditions = [...(this.formData.conditions || [])];
        if (!conditions[idx]) return;

        const existing = conditions[idx].value ? conditions[idx].value.split(',').map(v => v.trim()).filter(Boolean) : [];
        existing.push(newVal);
        conditions[idx] = { ...conditions[idx], value: existing.join(',') };
        this.formData = { ...this.formData, conditions };

        // Clear input
        if (input) input.value = '';
    }

    handlePillInputKeyup(event) {
        if (event.key === 'Enter') {
            this.handleAddPillValue(event);
        }
    }

    handleRemovePillValue(event) {
        event.stopPropagation();
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const pillKey = event.currentTarget.dataset.pillKey;
        if (isNaN(idx)) return;

        const conditions = [...(this.formData.conditions || [])];
        if (!conditions[idx]) return;

        const existing = conditions[idx].value ? conditions[idx].value.split(',').map(v => v.trim()).filter(Boolean) : [];
        // pillKey format: fpill_{condIdx}_{pillIdx}
        const pillIdx = parseInt(pillKey.split('_').pop(), 10);
        if (!isNaN(pillIdx) && pillIdx < existing.length) {
            existing.splice(pillIdx, 1);
        }
        conditions[idx] = { ...conditions[idx], value: existing.join(',') };
        this.formData = { ...this.formData, conditions };
    }

    handleCloseModal() {
        this.showAddRuleModal = false;
    }

    handleOverlayClick() {
        this.showAddRuleModal = false;
        this.showAddColModal = false;
        this.showEditColModal = false;
    }

    handleDialogClick(event) {
        event.stopPropagation();
    }

    // isCustomLogic getter removed — AND implicit always applied

    get formConditions() {
        // Build column operator map for label display
        const colOpMap = new Map();
        const colInfoMap = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOpMap.set(col.fieldId, col.operator || 'EQUALS');
            colInfoMap.set(col.fieldId, col);
        }

        return (this.formData.conditions || []).map((c, i) => {
            const colOp = colOpMap.get(c.fieldId) || c.operator || 'EQUALS';
            const colInfo = colInfoMap.get(c.fieldId);
            const isMulti = colOp === 'IN' || colOp === 'NOT_IN';
            const isRange = colOp === 'BETWEEN';
            const pillValues = isMulti && c.value
                ? c.value.split(',').map((v, idx) => ({ key: `fpill_${i}_${idx}`, label: v.trim() })).filter(p => p.label)
                : [];
            const opLabel = this.operatorLabelMap[colOp] || colOp;

            // Range: parse "start,end" into separate values
            let rangeStartValue = '';
            let rangeEndValue = '';
            let rangeStartOp = '>=';
            let rangeEndOp = '<=';
            if (isRange) {
                const parts = (c.value || '').includes(',') ? (c.value || '').split(',') : [c.value || '', ''];
                rangeStartValue = (parts[0] || '').trim();
                rangeEndValue = (parts[1] || '').trim();
                rangeStartOp = colInfo ? (colInfo.rangeStartOp || '>=') : '>=';
                rangeEndOp = colInfo ? (colInfo.rangeEndOp || '<=') : '<=';
            }

            return {
                ...c,
                index: i,
                orderNum: i + 1,
                fieldLabel: isRange ? `${c.fieldName} (Range)` : `${c.fieldName} (${opLabel})`,
                isMultiValueOperator: isMulti,
                isRange,
                rangeStartValue,
                rangeEndValue,
                rangeStartOp,
                rangeEndOp,
                pillValues
            };
        });
    }

    get hasFormConditions() {
        return this.formData.conditions && this.formData.conditions.length > 0;
    }

    get modalTitle() {
        return this.isEditMode ? 'Chỉnh sửa Rule' : 'Thêm Rule mới';
    }

    get modalSaveLabel() {
        return this.isEditMode ? 'Cập nhật' : 'Lưu';
    }

    // ════════════════════════════════════════════════════════
    // GETTERS
    // ════════════════════════════════════════════════════════
    get hasData() {
        return this.originalRows.length > 0;
    }

    get hasNoSearchResults() {
        return this.originalRows.length > 0 && this.filteredRows.length === 0;
    }

    get isBPSelected() {
        return !!this._currentBPId && !this._showLeafMessage;
    }

    get conditionColSpan() {
        let count = this.fixedConditionColumns.length;
        for (const col of this.dynamicConditionColumns) {
            count += col.operator === 'BETWEEN' ? 2 : 1;
        }
        return count;
    }

    get actionColSpan() {
        return this.actionColumns.length + this.dynamicActionColumns.length;
    }

    get disableDeleteCol() {
        if (!this.selectedColKey) return true;
        return this._isFixedColumn(this.selectedColKey);
    }

    get disableAddCol() {
        return !this.selectedColKey;
    }

    get disableDeleteRow() {
        if (!this.selectedRowId) return true;
        // Disable delete for otherwise rows
        const selectedRow = this.originalRows.find(r => r.ruleId === this.selectedRowId);
        if (selectedRow && this._isOtherwiseRow(selectedRow)) return true;
        return false;
    }

    get disableAddRow() {
        // Allow adding first row when table is empty
        if (this.originalRows.length === 0) return false;
        return !this.selectedRowId;
    }

    get showLeafMessage() {
        return this._showLeafMessage;
    }

    get selectedItemLabel() {
        return this._selectedBPLabel || '';
    }

    get totalRuleCount() {
        return this.originalRows.length;
    }

    get hasConditionColumns() {
        return this.fixedConditionColumns.length + this.dynamicConditionColumns.length > 0;
    }

    get hasSearchFilter() {
        return !!(this.searchFilter && this.searchFilter.trim());
    }

    get displayConditionColumns() {
        const fixed = this.fixedConditionColumns.map(col => {
            const isSelected = this.selectedColKey === col.key;
            return {
                ...col,
                colKey: col.key,
                colGroup: 'condition',
                fieldId: col.key,
                fieldName: col.label,
                isRange: false,
                headerClass: isSelected
                    ? 'col-header selected-col-header'
                    : 'col-header'
            };
        });
        const dynamic = [];
        for (const col of this.dynamicConditionColumns) {
            const isSelected = this.selectedColKey === col.fieldId;
            const operatorLabel = this.operatorLabelMap[col.operator] || col.operator || '=';
            const cleanFieldName = col.fieldName.replace(/\s*\(.*?\)\s*$/, '').trim() || col.fieldName;
            if (col.operator === 'BETWEEN') {
                const startOp = col.rangeStartOp || '>=';
                const endOp = col.rangeEndOp || '<=';
                // Range column → 2 sub-columns
                dynamic.push({
                    ...col,
                    colKey: col.fieldId,
                    colGroup: 'condition',
                    fieldName: `${cleanFieldName} (Range)`,
                    isDynamic: true,
                    isRange: true,
                    rangeColspan: 2,
                    startOp,
                    endOp,
                    startSubHeader: `${startOp} (Start)`,
                    endSubHeader: `${endOp} (End)`,
                    startSubKey: `${col.fieldId}_start_sub`,
                    endSubKey: `${col.fieldId}_end_sub`,
                    headerClass: isSelected
                        ? 'col-header selected-col-header clickable-header'
                        : 'col-header clickable-header'
                });
            } else {
                dynamic.push({
                    ...col,
                    colKey: col.fieldId,
                    colGroup: 'condition',
                    fieldName: `${cleanFieldName} (${operatorLabel})`,
                    isDynamic: true,
                    isRange: false,
                    headerClass: isSelected
                        ? 'col-header selected-col-header clickable-header'
                        : 'col-header clickable-header'
                });
            }
        }
        return [...fixed, ...dynamic];
    }

    get hasRangeColumns() {
        return this.dynamicConditionColumns.some(c => c.operator === 'BETWEEN');
    }

    get headerRowspan() {
        return this.hasRangeColumns ? 3 : 2;
    }

    get headerRowspanNonRange() {
        return this.hasRangeColumns ? 2 : 1;
    }

    get displayActionColumns() {
        const fixed = this.actionColumns.map(col => {
            const isSelected = this.selectedColKey === col.key;
            return {
                ...col,
                colKey: col.key,
                colGroup: 'action',
                headerClass: isSelected
                    ? 'col-header selected-col-header'
                    : 'col-header'
            };
        });
        const dynamic = this.dynamicActionColumns.map(col => {
            const isSelected = this.selectedColKey === col.key;
            return {
                ...col,
                colKey: col.key,
                colGroup: 'action',
                headerClass: isSelected
                    ? 'col-header selected-col-header'
                    : 'col-header'
            };
        });
        return [...fixed, ...dynamic];
    }

    get displayRows() {
        const isRowSelection = !!this.selectedRowId;
        const isColSelection = !!this.selectedColKey;

        return this.filteredRows.map((row, index) => {
            const isSelectedRow = row.ruleId === this.selectedRowId;
            const isOtherwise = this._isOtherwiseRow(row);

            // Priority display: "otherwise" for fallback rows, 1-based index for normal rows
            const priorityDisplay = isOtherwise ? 'otherwise' : (index + 1);

            // Build fixed condition cells with cellClass
            const fixedConditionCells = [
                {
                    key: 'previousStage',
                    value: row.conditionValues.previousStage,
                    cellClass: this._cellClass('previousStage', isSelectedRow, isRowSelection, isColSelection)
                },
                {
                    key: 'actionButton',
                    value: row.conditionValues.actionButton,
                    cellClass: this._cellClass('actionButton', isSelectedRow, isRowSelection, isColSelection)
                }
            ];

            // Build dynamic condition cells with OR sub-values support
            // Also build a column operator map for range detection
            const colMap = new Map();
            for (const col of this.dynamicConditionColumns) {
                colMap.set(col.fieldId, col);
            }

            const dynamicCells = (row.conditionCells || []).map(cell => {
                const colInfo = colMap.get(cell.fieldId);
                const isRange = colInfo && colInfo.operator === 'BETWEEN';

                if (isRange) {
                    // Range cell → split into startValue and endValue
                    const firstVal = (cell.values || [])[0] || { value: '', conditionId: null };
                    const rawValue = firstVal.value || '';
                    const parts = rawValue.includes(',') ? rawValue.split(',') : [rawValue, ''];
                    const startValue = (parts[0] || '').trim();
                    const endValue = (parts[1] || '').trim();

                    const startCellKey = `${row.ruleId}_${cell.fieldId}_start`;
                    const endCellKey = `${row.ruleId}_${cell.fieldId}_end`;
                    const isEditingStart = this.editingCellKey === startCellKey;
                    const isEditingEnd = this.editingCellKey === endCellKey;
                    const showStartToolbar = this.hoverCellKey === startCellKey && !!startValue;
                    const showEndToolbar = this.hoverCellKey === endCellKey && !!endValue;

                    return {
                        ...cell,
                        isRange: true,
                        conditionId: firstVal.conditionId || null,
                        startValue,
                        endValue,
                        startCellKey,
                        endCellKey,
                        isEditingStart,
                        isEditingEnd,
                        editStartValue: isEditingStart ? this.editingCellValue : '',
                        editEndValue: isEditingEnd ? this.editingCellValue : '',
                        showStartToolbar,
                        showEndToolbar,
                        hasStartValue: !!startValue,
                        hasEndValue: !!endValue,
                        startTdKey: `${cell.fieldId}_start_td`,
                        endTdKey: `${cell.fieldId}_end_td`,
                        cellClass: this._cellClass(cell.fieldId, isSelectedRow, isRowSelection, isColSelection)
                    };
                }

                const cellValues = (cell.values || []).map((val, vi) => {
                    const valCellKey = `${row.ruleId}_${cell.fieldId}_${vi}`;
                    const isEditing = this.editingCellKey === valCellKey;
                    const showToolbar = this.hoverCellKey === valCellKey;
                    const hasValue = val.value && val.value.trim();
                    return {
                        ...val,
                        key: val.key || `val_${cell.fieldId}_${vi}`,
                        valueIndex: vi,
                        cellKey: valCellKey,
                        isEditing,
                        showToolbar: showToolbar && !!hasValue,
                        editValue: isEditing ? this.editingCellValue : '',
                        hasValue: !!hasValue
                    };
                });

                return {
                    ...cell,
                    isRange: false,
                    values: cellValues,
                    hasOrValues: cellValues.length > 1,
                    cellClass: this._cellClass(cell.fieldId, isSelectedRow, isRowSelection, isColSelection)
                };
            });

            // Build action cells with cellClass
            const actionCells = [
                {
                    key: 'nextStage',
                    value: row.actionValues.nextStage,
                    cellClass: this._cellClass('nextStage', isSelectedRow, isRowSelection, isColSelection)
                },
                {
                    key: 'nextQueue',
                    value: row.actionValues.nextQueue,
                    cellClass: this._cellClass('nextQueue', isSelectedRow, isRowSelection, isColSelection)
                },
                {
                    key: 'teamUserGroup',
                    value: row.actionValues.teamUserGroup,
                    cellClass: this._cellClass('teamUserGroup', isSelectedRow, isRowSelection, isColSelection)
                }
            ];

            // Build dynamic action cells
            const dynamicActionCells = this.dynamicActionColumns.map(col => ({
                key: col.key,
                value: '',
                cellClass: this._cellClass(col.key, isSelectedRow, isRowSelection, isColSelection)
            }));

            const isTestMatched = (this.testMatchedRuleIds || []).includes(row.ruleId);

            return {
                ...row,
                priorityDisplay,
                isOtherwise,
                priorityCellClass: isOtherwise ? 'priority-cell otherwise-priority' : 'priority-cell',
                fixedConditionCells,
                displayConditionCells: dynamicCells,
                displayActionCells: [...actionCells, ...dynamicActionCells],
                rowClass: isTestMatched
                    ? 'slds-hint-parent test-matched-row'
                    : isSelectedRow
                        ? 'slds-hint-parent selected-row'
                        : isOtherwise
                            ? 'slds-hint-parent otherwise-row'
                            : 'slds-hint-parent',
                editCellClass: isSelectedRow ? 'action-buttons selected-row-cell' : 'action-buttons'
            };
        });
    }

    /**
     * Check if a row is an "otherwise" (fallback) row — no dynamic conditions with values.
     */
    _isOtherwiseRow(row) {
        if (!row || !row.conditionCells) return false;
        // Only detect otherwise if there are dynamic condition columns
        if (this.dynamicConditionColumns.length === 0) return false;
        // Only the LAST row can be "otherwise" — not every empty row
        const rows = this.filteredRows;
        if (rows.length === 0) return false;
        const lastRow = rows[rows.length - 1];
        if (row.ruleId !== lastRow.ruleId) return false;
        // Check if this last row has no condition values
        const hasAnyConditionValue = row.conditionCells.some(cell =>
            (cell.values || []).some(v => v.value && v.value.trim())
        );
        return !hasAnyConditionValue;
    }

    _cellClass(colKey, isSelectedRow, isRowSelection, isColSelection) {
        const classes = [];
        if (isColSelection && this.selectedColKey === colKey) {
            classes.push('selected-col');
        }
        if (isRowSelection && isSelectedRow) {
            classes.push('selected-row-cell');
        }
        return classes.join(' ');
    }

    // ════════════════════════════════════════════════════════
    // INLINE EDIT — Condition Cells
    // ════════════════════════════════════════════════════════

    /**
     * Click on a condition cell value:
     * - Empty cell → enter edit mode (show input)
     * - Cell with value → show mini toolbar [OR] [✏️] [🗑]
     */
    handleCellClick(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        const valueIndex = parseInt(event.currentTarget.dataset.valueIndex || '0', 10);
        if (!ruleId || !fieldId) return;

        const cellKey = `${ruleId}_${fieldId}_${valueIndex}`;
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;

        const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
        const values = cell ? (cell.values || []) : [];
        const val = values[valueIndex];
        const hasValue = val && val.value && val.value.trim();

        if (hasValue) {
            // Toggle mini toolbar
            if (this.hoverCellKey === cellKey) {
                this.hoverCellKey = null;
            } else {
                this.hoverCellKey = cellKey;
                this.editingCellKey = null;
            }
        } else {
            // Empty cell → enter edit mode
            this.hoverCellKey = null;
            this.editingCellKey = cellKey;
            this.editingCellValue = '';
            // Focus input after render
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const input = this.template.querySelector(`input[data-cell-key="${cellKey}"]`);
                if (input) input.focus();
            }, 50);
        }
    }

    /**
     * Prevent click on inline input from triggering cell click
     */
    handleInlineInputClick(event) {
        event.stopPropagation();
    }

    /**
     * Mini toolbar: Edit button → switch to edit mode with current value
     */
    handleCellEdit(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        const valueIndex = parseInt(event.currentTarget.dataset.valueIndex || '0', 10);
        if (!ruleId || !fieldId) return;

        const cellKey = `${ruleId}_${fieldId}_${valueIndex}`;
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;

        const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
        const values = cell ? (cell.values || []) : [];
        const val = values[valueIndex];
        this.editingCellKey = cellKey;
        this.editingCellValue = val ? (val.value || '') : '';
        this.hoverCellKey = null;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const input = this.template.querySelector(`input[data-cell-key="${cellKey}"]`);
            if (input) {
                input.focus();
                input.select();
            }
        }, 50);
    }

    /**
     * Mini toolbar: Delete button → clear value (remove condition record).
     * For OR sub-values: removes just that sub-value. If last sub-value, clears the cell.
     */
    handleCellDelete(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        const valueIndex = parseInt(event.currentTarget.dataset.valueIndex || '0', 10);
        if (!ruleId || !fieldId) return;

        this.hoverCellKey = null;
        this.editingCellKey = null;
        this._saveCellValue(ruleId, fieldId, '', valueIndex);
    }

    /**
     * Inline input: handle keydown (Enter = save, Escape = cancel)
     */
    handleCellInputKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            const ruleId = event.target.dataset.ruleId;
            const fieldId = event.target.dataset.fieldId;
            const valueIndex = parseInt(event.target.dataset.valueIndex || '0', 10);
            const value = event.target.value || '';
            this.editingCellKey = null;
            this.editingCellValue = '';
            this._saveCellValue(ruleId, fieldId, value.trim(), valueIndex);
        } else if (event.key === 'Escape') {
            event.preventDefault();
            this.editingCellKey = null;
            this.editingCellValue = '';
        }
    }

    /**
     * Inline input: handle blur → cancel edit (same as Escape)
     */
    handleCellInputBlur(event) {
        // Small delay to allow button clicks to register first
        const ruleId = event.target.dataset.ruleId;
        const fieldId = event.target.dataset.fieldId;
        const valueIndex = event.target.dataset.valueIndex || '0';
        const cellKey = `${ruleId}_${fieldId}_${valueIndex}`;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            if (this.editingCellKey === cellKey) {
                this.editingCellKey = null;
                this.editingCellValue = '';
            }
        }, 200);
    }

    /**
     * Save a single cell value by rebuilding the full rule payload and calling saveRuleWithConditions.
     * Supports OR sub-values: valueIndex specifies which sub-value to update/delete.
     */
    _saveCellValue(ruleId, fieldId, newValue, valueIndex = 0) {
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;

        this.isLoading = true;

        // Build column operator map + range info
        const colOperatorMap = new Map();
        const colInfoMap = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOperatorMap.set(col.fieldId, col.operator || 'EQUALS');
            colInfoMap.set(col.fieldId, col);
        }

        const operatorMap = {
            'EQUALS': '=', 'NOT_EQUALS': '!=', 'CONTAINS': 'Contains',
            'NOT_CONTAINS': 'Not Contains', 'GREATER_THAN': '>', 'LESS_THAN': '<',
            'GREATER_THAN_OR_EQUAL': '>=', 'LESS_THAN_OR_EQUAL': '<=',
            'IN': 'IN', 'NOT_IN': 'NOT IN', 'STARTS_WITH': 'Starts With', 'ENDS_WITH': 'Ends With'
        };

        const rangeOpToPicklist = {
            '>=': '>=', '>': '>', '<=': '<=', '<': '<'
        };

        // Build conditions from all cells, supporting OR sub-values
        const conditions = [];
        for (const cell of (row.conditionCells || [])) {
            if (!cell.fieldId) continue;
            const colOp = colOperatorMap.get(cell.fieldId) || 'EQUALS';
            const colInfo = colInfoMap.get(cell.fieldId);
            const isRange = colOp === 'BETWEEN';
            const values = cell.values || [{ conditionId: cell.conditionId, value: cell.value || '' }];

            for (let vi = 0; vi < values.length; vi++) {
                const val = values[vi];
                const isTarget = cell.fieldId === fieldId && vi === valueIndex;
                let finalValue = isTarget ? newValue : (val.value || '');

                // If deleting (empty value) and this is an OR sub-value (not the only one), skip it entirely
                if (isTarget && !finalValue && values.length > 1) {
                    continue;
                }

                // Range: always create both start and end records (even with empty values)
                if (isRange) {
                    const rangeVal = isTarget ? newValue : (val.value || '');
                    const parts = rangeVal.includes(',') ? rangeVal.split(',') : [rangeVal, ''];
                    const startVal = (parts[0] || '').trim();
                    const endVal = (parts[1] || '').trim();
                    const startOp = colInfo ? (colInfo.rangeStartOp || '>=') : '>=';
                    const endOp = colInfo ? (colInfo.rangeEndOp || '<=') : '<=';

                    conditions.push({
                        id: null,
                        fieldId: cell.fieldId,
                        operator: rangeOpToPicklist[startOp] || '>=',
                        value: startVal || '',
                        expression: 'RANGE_START',
                        order: conditions.length + 1
                    });
                    conditions.push({
                        id: null,
                        fieldId: cell.fieldId,
                        operator: rangeOpToPicklist[endOp] || '<=',
                        value: endVal || '',
                        expression: 'RANGE_END',
                        order: conditions.length + 1
                    });
                    break; // Only process first value entry for range (combined value)
                }

                if (!finalValue) continue;

                conditions.push({
                    id: val.conditionId && !String(val.conditionId).startsWith('new') ? val.conditionId : null,
                    fieldId: cell.fieldId,
                    operator: operatorMap[colOp] || colOp,
                    value: finalValue,
                    order: conditions.length + 1
                });
            }
        }

        const cv = row.conditionValues || {};
        const av = row.actionValues || {};

        const payload = {
            recordId: ruleId,
            previousStageId: cv.previousStageId || '',
            actionButtonId: cv.actionButtonId || '',
            nextStageId: av.nextStageId || '',
            nextQueue: av.nextQueue || null,
            teamUserGroup: av.teamUserGroup || null,
            priority: row.priority || 1,
            conditionRequirement: 'AND',
            conditionLogic: '', // No longer auto-generated
            conditions: conditions
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => {
                this.showToast('Thành công', 'Đã cập nhật giá trị', 'success');
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Lỗi', err.body?.message || err.message || 'Không thể lưu giá trị', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * OR button handler: adds a new empty value slot to a condition cell.
     * The new slot auto-focuses for inline edit.
     */
    handleCellOR(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        if (!ruleId || !fieldId) return;

        this.hoverCellKey = null;

        // Find the row and cell, add a new empty value slot
        const rowIdx = this.originalRows.findIndex(r => r.ruleId === ruleId);
        if (rowIdx === -1) return;

        const row = this.originalRows[rowIdx];
        const cellIdx = (row.conditionCells || []).findIndex(c => c.fieldId === fieldId);
        if (cellIdx === -1) return;

        const cell = row.conditionCells[cellIdx];
        const values = [...(cell.values || [])];
        const newIndex = values.length;
        values.push({
            key: `val_${fieldId}_${newIndex}_${Date.now()}`,
            conditionId: null,
            value: '',
            displayValue: '',
            isMultiValue: false,
            valuePills: []
        });

        // Update the cell in originalRows
        const updatedCells = [...row.conditionCells];
        updatedCells[cellIdx] = { ...cell, values, hasOrValues: values.length > 1 };
        const updatedRow = { ...row, conditionCells: updatedCells };
        const updatedRows = [...this.originalRows];
        updatedRows[rowIdx] = updatedRow;
        this.originalRows = updatedRows;
        this.rows = [...updatedRows];

        // Auto-focus the new empty value slot for inline edit
        const newCellKey = `${ruleId}_${fieldId}_${newIndex}`;
        this.editingCellKey = newCellKey;
        this.editingCellValue = '';

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const input = this.template.querySelector(`input[data-cell-key="${newCellKey}"]`);
            if (input) input.focus();
        }, 100);
    }

    // ════════════════════════════════════════════════════════
    // INLINE EDIT — Range Cells (Start/End)
    // ════════════════════════════════════════════════════════

    /**
     * Click on a range cell (start or end):
     * - Empty → enter edit mode
     * - Has value → show mini toolbar
     */
    handleRangeCellClick(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        const rangePart = event.currentTarget.dataset.rangePart; // 'start' or 'end'
        if (!ruleId || !fieldId || !rangePart) return;

        const cellKey = `${ruleId}_${fieldId}_${rangePart}`;
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;

        const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
        const rawValue = cell && cell.values && cell.values[0] ? (cell.values[0].value || '') : '';
        const parts = rawValue.includes(',') ? rawValue.split(',') : [rawValue, ''];
        const partValue = rangePart === 'start' ? (parts[0] || '').trim() : (parts[1] || '').trim();

        if (partValue) {
            if (this.hoverCellKey === cellKey) {
                this.hoverCellKey = null;
            } else {
                this.hoverCellKey = cellKey;
                this.editingCellKey = null;
            }
        } else {
            this.hoverCellKey = null;
            this.editingCellKey = cellKey;
            this.editingCellValue = '';
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const input = this.template.querySelector(`input[data-cell-key="${cellKey}"]`);
                if (input) input.focus();
            }, 50);
        }
    }

    /**
     * Range cell mini toolbar: Edit button
     */
    handleRangeCellEdit(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        const rangePart = event.currentTarget.dataset.rangePart;
        if (!ruleId || !fieldId || !rangePart) return;

        const cellKey = `${ruleId}_${fieldId}_${rangePart}`;
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;

        const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
        const rawValue = cell && cell.values && cell.values[0] ? (cell.values[0].value || '') : '';
        const parts = rawValue.includes(',') ? rawValue.split(',') : [rawValue, ''];
        const partValue = rangePart === 'start' ? (parts[0] || '').trim() : (parts[1] || '').trim();

        this.editingCellKey = cellKey;
        this.editingCellValue = partValue;
        this.hoverCellKey = null;

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const input = this.template.querySelector(`input[data-cell-key="${cellKey}"]`);
            if (input) {
                input.focus();
                input.select();
            }
        }, 50);
    }

    /**
     * Range cell mini toolbar: Delete button — clear start or end value
     */
    handleRangeCellDelete(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        const rangePart = event.currentTarget.dataset.rangePart;
        if (!ruleId || !fieldId || !rangePart) return;

        this.hoverCellKey = null;
        this.editingCellKey = null;
        this._saveRangeCellValue(ruleId, fieldId, rangePart, '');
    }

    /**
     * Range cell inline input: keydown
     * Enter on Start → store start value locally, move focus to End cell (no server save yet)
     * Enter on End → save combined start+end value to server
     * Escape → cancel
     */
    handleRangeCellInputKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            const ruleId = event.target.dataset.ruleId;
            const fieldId = event.target.dataset.fieldId;
            const rangePart = event.target.dataset.rangePart;
            const value = event.target.value || '';

            if (rangePart === 'start') {
                // Store start value locally, move focus to end cell (no save yet)
                this._pendingRangeStart = { ruleId, fieldId, value: value.trim() };
                const endCellKey = `${ruleId}_${fieldId}_end`;
                this.editingCellKey = endCellKey;
                // Read current end value
                const row = this.originalRows.find(r => r.ruleId === ruleId);
                if (row) {
                    const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
                    const rawVal = cell && cell.values && cell.values[0] ? (cell.values[0].value || '') : '';
                    const parts = rawVal.includes(',') ? rawVal.split(',') : [rawVal, ''];
                    this.editingCellValue = (parts[1] || '').trim();
                } else {
                    this.editingCellValue = '';
                }
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    const input = this.template.querySelector(`input[data-cell-key="${endCellKey}"]`);
                    if (input) {
                        input.focus();
                        input.select();
                    }
                }, 50);
            } else {
                // End cell: save combined start+end value
                this.editingCellKey = null;
                this.editingCellValue = '';
                const endValue = value.trim();
                // Check if we have a pending start value from the same range
                if (this._pendingRangeStart && this._pendingRangeStart.ruleId === ruleId && this._pendingRangeStart.fieldId === fieldId) {
                    const startValue = this._pendingRangeStart.value;
                    this._pendingRangeStart = null;
                    const combinedValue = (startValue || endValue) ? `${startValue},${endValue}` : '';
                    this._saveCellValue(ruleId, fieldId, combinedValue, 0);
                } else {
                    this._saveRangeCellValue(ruleId, fieldId, rangePart, endValue);
                }
            }
        } else if (event.key === 'Escape') {
            event.preventDefault();
            this.editingCellKey = null;
            this.editingCellValue = '';
            this._pendingRangeStart = null;
        }
    }

    /**
     * Range cell inline input: blur → auto-save value
     * If blurring from Start while transitioning to End (via Enter), skip save (End Enter will save both).
     * If blurring from Start by clicking away, save start value normally.
     */
    handleRangeCellInputBlur(event) {
        const ruleId = event.target.dataset.ruleId;
        const fieldId = event.target.dataset.fieldId;
        const rangePart = event.target.dataset.rangePart;
        const value = event.target.value || '';
        const cellKey = `${ruleId}_${fieldId}_${rangePart}`;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            // If editingCellKey moved to end cell (Enter on start), skip — End Enter will handle save
            const endCellKey = `${ruleId}_${fieldId}_end`;
            if (rangePart === 'start' && this.editingCellKey === endCellKey) {
                return;
            }
            if (this.editingCellKey === cellKey) {
                this.editingCellKey = null;
                this.editingCellValue = '';
                this._pendingRangeStart = null;
                if (value.trim()) {
                    this._saveRangeCellValue(ruleId, fieldId, rangePart, value.trim());
                }
            }
        }, 200);
    }

    /**
     * Save a range cell value by updating the combined "start,end" value
     * in the condition record.
     */
    _saveRangeCellValue(ruleId, fieldId, rangePart, newValue) {
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;

        // Get current combined value
        const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
        const rawValue = cell && cell.values && cell.values[0] ? (cell.values[0].value || '') : '';
        const parts = rawValue.includes(',') ? rawValue.split(',') : [rawValue, ''];
        let startVal = (parts[0] || '').trim();
        let endVal = (parts[1] || '').trim();

        if (rangePart === 'start') {
            startVal = newValue;
        } else {
            endVal = newValue;
        }

        // Combine back to "start,end" format
        const combinedValue = (startVal || endVal) ? `${startVal},${endVal}` : '';
        this._saveCellValue(ruleId, fieldId, combinedValue, 0);
    }

    // ════════════════════════════════════════════════════════
    // DOUBLE-CLICK COLUMN HEADER → EDIT COLUMN MODAL
    // ════════════════════════════════════════════════════════
    handleColumnDblClick(event) {
        event.stopPropagation();
        const colKey = event.currentTarget.dataset.colKey;
        if (!colKey) return;

        // Only allow editing dynamic condition columns
        const col = this.dynamicConditionColumns.find(c => c.fieldId === colKey);
        if (!col) return;

        this.editColFieldId = col.fieldId;
        this.editColFieldName = col.fieldName;
        this.editColOperator = col.operator || 'EQUALS';
        this.editColExpression = col.expression || '';
        this.editColUseRange = col.operator === 'BETWEEN';
        this.editColRangeStartOp = col.rangeStartOp || '>=';
        this.editColRangeEndOp = col.rangeEndOp || '<=';
        this.showEditColModal = true;
    }

    handleEditColOperatorChange(event) {
        this.editColOperator = event.detail.value;
    }

    handleEditColFieldNameChange(event) {
        this.editColFieldName = event.target.value;
    }

    handleEditColExpressionChange(event) {
        this.editColExpression = event.detail?.value ?? event.target.value ?? '';
    }

    handleConfirmEditCol() {
        if (!this.editColFieldId) return;

        const idx = this.dynamicConditionColumns.findIndex(c => c.fieldId === this.editColFieldId);
        if (idx === -1) return;

        const currentCol = this.dynamicConditionColumns[idx];
        const finalOperator = this.editColUseRange ? 'BETWEEN' : (this.editColOperator || currentCol.operator);

        // Update local state immediately
        const updated = [...this.dynamicConditionColumns];
        updated[idx] = {
            ...currentCol,
            fieldName: this.editColFieldName || currentCol.fieldName,
            operator: finalOperator,
            expression: this.editColExpression || '',
            rangeStartOp: this.editColUseRange ? this.editColRangeStartOp : '',
            rangeEndOp: this.editColUseRange ? this.editColRangeEndOp : ''
        };
        this.dynamicConditionColumns = updated;
        this._prevDynamicConditionColumns = [...updated];

        // Save to DB — update all conditions of this field in BP
        // For BETWEEN (range), skip updating operator on existing conditions
        // because range creates 2 separate records with >=/<= operators
        if (finalOperator === 'BETWEEN') {
            // Only update expression if changed, don't touch operator
            if (this.editColExpression) {
                this.isLoading = true;
                updateColumnProperties({
                    businessProcessId: this._currentBPId,
                    masterDataSettingId: this.editColFieldId,
                    newOperator: '>=',
                    newExpression: this.editColExpression || ''
                })
                    .then(() => {
                        this.showToast('Thành công', 'Đã cập nhật cột', 'success');
                        this.loadDecisionTable();
                    })
                    .catch(err => {
                        this.showToast('Lỗi', err.body?.message || err.message || 'Không thể cập nhật cột', 'error');
                    })
                    .finally(() => {
                        this.isLoading = false;
                    });
            } else {
                this.showToast('Thành công', 'Đã cập nhật cột', 'success');
            }
        } else {
            this.isLoading = true;
            updateColumnProperties({
                businessProcessId: this._currentBPId,
                masterDataSettingId: this.editColFieldId,
                newOperator: finalOperator,
                newExpression: this.editColExpression || ''
            })
                .then(() => {
                    this.showToast('Thành công', 'Đã cập nhật cột', 'success');
                    this.loadDecisionTable();
                })
                .catch(err => {
                    this.showToast('Lỗi', err.body?.message || err.message || 'Không thể cập nhật cột', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }

        this._closeEditColModal();
    }

    handleCloseEditColModal() {
        this._closeEditColModal();
    }

    _closeEditColModal() {
        this.showEditColModal = false;
        this.editColFieldId = null;
        this.editColFieldName = '';
        this.editColOperator = 'EQUALS';
        this.editColExpression = '';
        this.editColUseRange = false;
        this.editColRangeStartOp = '>=';
        this.editColRangeEndOp = '<=';
    }

    // ════════════════════════════════════════════════════════
    // STATE RESET HELPERS
    // ════════════════════════════════════════════════════════
    // TEST PANEL
    // ════════════════════════════════════════════════════════
    isTestPanelOpen = false;
    testFormData = { previousStageId: '', actionButtonId: '', fieldValues: {} };
    testResult = null;
    testMatchedRuleId = null;

    get testPanelChevronIcon() {
        return this.isTestPanelOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get hasTestConditionFields() {
        return this.dynamicConditionColumns && this.dynamicConditionColumns.length > 0;
    }

    get testConditionFields() {
        return this.dynamicConditionColumns.map(col => {
            const opLabel = col.operator || '=';
            return {
                fieldId: col.fieldId,
                fieldApiName: col.fieldApiName,
                label: col.fieldName + ' (' + opLabel + ')',
                placeholder: opLabel + ' nhập giá trị...',
                value: this.testFormData.fieldValues[col.fieldApiName] || ''
            };
        });
    }

    get disableTestButton() {
        return false; // Always enabled — filters are optional
    }

    get hasEvaluationTrace() {
        return this.testResult && this.testResult.evaluationTrace && this.testResult.evaluationTrace.length > 0;
    }

    get matchedTraceRows() {
        if (!this.testResult || !this.testResult.evaluationTrace) return [];
        return this.testResult.evaluationTrace.filter(rt => rt.isMatch);
    }

    get hasNoTestFilters() {
        return !this.testFormData.previousStageId && !this.testFormData.actionButtonId
            && Object.keys(this.testFormData.fieldValues || {}).every(k => !this.testFormData.fieldValues[k] || !this.testFormData.fieldValues[k].trim());
    }

    handleToggleTestPanel() {
        this.isTestPanelOpen = !this.isTestPanelOpen;
    }

    handleTestInputChange(event) {
        const name = event.target.name;
        if (name === 'testPrevStage') {
            this.testFormData = { ...this.testFormData, previousStageId: event.detail.value };
        } else if (name === 'testAction') {
            this.testFormData = { ...this.testFormData, actionButtonId: event.detail.value };
        }
        this._clearTestResult();
    }

    handleTestFieldChange(event) {
        const apiName = event.target.dataset.fieldApi;
        const val = event.detail.value;
        const updated = { ...this.testFormData.fieldValues, [apiName]: val };
        this.testFormData = { ...this.testFormData, fieldValues: updated };
        this._clearTestResult();
    }

    handleRunTest() {
        this._clearTestHighlight();

        const stageFilter = this.testFormData.previousStageId || null;
        const actionFilter = this.testFormData.actionButtonId || null;

        // Collect non-empty condition field values (keep original case for comparison)
        const fieldFilters = {};
        for (const key of Object.keys(this.testFormData.fieldValues || {})) {
            const val = this.testFormData.fieldValues[key];
            if (val && val.trim()) {
                fieldFilters[key] = val.trim();
            }
        }

        // Build column operator map: fieldId → operator (EQUALS, GREATER_THAN, BETWEEN, etc.)
        const colOpMap = new Map();
        const colByApi = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOpMap.set(col.fieldId, col.operator || 'EQUALS');
            if (col.fieldApiName) {
                colByApi.set(col.fieldApiName.toLowerCase(), col);
            }
        }

        // Evaluate rows from current table data (client-side)
        const allRows = this.originalRows || [];
        const matchedRuleIds = [];
        const trace = [];
        let firstMatchFound = false;

        allRows.forEach((row, idx) => {
            const stt = idx + 1;
            const cv = row.conditionValues || {};
            const av = row.actionValues || {};
            let match = true;
            const condDetails = [];

            // Filter by Previous Stage
            if (stageFilter && cv.previousStageId !== stageFilter) {
                match = false;
                condDetails.push({
                    key: row.ruleId + '-ps',
                    fieldLabel: 'Previous Stage',
                    operator: '=',
                    expectedValue: cv.previousStage || cv.previousStageId || '',
                    actualValue: this._getStageName(stageFilter),
                    result: false
                });
            }

            // Filter by Action
            if (actionFilter && cv.actionButtonId !== actionFilter) {
                match = false;
                condDetails.push({
                    key: row.ruleId + '-act',
                    fieldLabel: 'Action',
                    operator: '=',
                    expectedValue: cv.actionButton || cv.actionButtonId || '',
                    actualValue: this._getActionName(actionFilter),
                    result: false
                });
            }

            // Evaluate condition fields with proper operator logic
            if (match) {
                const cells = row.conditionCells || [];
                // Group by field for OR logic (same field = OR, different fields = AND)
                for (const apiName of Object.keys(fieldFilters)) {
                    const inputVal = fieldFilters[apiName];
                    const col = colByApi.get(apiName.toLowerCase());
                    if (!col) continue;

                    const cell = cells.find(c => c.fieldId === col.fieldId);
                    const colOp = colOpMap.get(col.fieldId) || 'EQUALS';

                    // No condition on this field for this rule → always pass (skip)
                    if (!cell || !cell.values || cell.values.every(v => !v.value)) {
                        continue;
                    }

                    // OR logic: any value in the cell matching = pass
                    const values = cell.values || [];
                    let fieldMatch = false;
                    for (const v of values) {
                        const condVal = v.value || '';
                        if (!condVal) continue;
                        const result = this._evaluateOperator(colOp, inputVal, condVal, col);
                        if (result) {
                            fieldMatch = true;
                            condDetails.push({
                                key: row.ruleId + '-' + col.fieldId + '-' + condVal,
                                fieldLabel: col.fieldName,
                                operator: this._operatorLabel(colOp),
                                expectedValue: condVal,
                                actualValue: inputVal,
                                result: true
                            });
                            break;
                        }
                    }
                    if (!fieldMatch) {
                        match = false;
                        const firstCondVal = values.find(v => v.value)?.value || '';
                        condDetails.push({
                            key: row.ruleId + '-' + col.fieldId,
                            fieldLabel: col.fieldName,
                            operator: this._operatorLabel(colOp),
                            expectedValue: firstCondVal,
                            actualValue: inputVal,
                            result: false
                        });
                    }
                }
            }

            // Determine trace status
            const isFirstMatch = match && !firstMatchFound;
            if (match) {
                matchedRuleIds.push(row.ruleId);
                if (isFirstMatch) firstMatchFound = true;
            }

            trace.push({
                ruleId: row.ruleId,
                stt,
                previousStage: cv.previousStage || '',
                action: cv.actionButton || '',
                nextStage: av.nextStage || '',
                nextQueue: av.nextQueue || '',
                team: av.teamUserGroup || '',
                isMatch: match,
                isFirstMatch,
                isNotMatch: !match,
                isSkipped: false,
                hasConditions: condDetails.length > 0,
                traceClass: 'trace-rule ' + (isFirstMatch ? 'trace-rule-first-match' : match ? 'trace-rule-match' : 'trace-rule-fail'),
                conditions: condDetails
            });
        });

        this.testResult = {
            matched: matchedRuleIds.length > 0,
            matchCount: matchedRuleIds.length,
            totalCount: allRows.length,
            firstMatchRuleId: matchedRuleIds.length > 0 ? matchedRuleIds[0] : null,
            evaluationTrace: trace
        };
        this.testMatchedRuleIds = matchedRuleIds;
    }

    /**
     * Evaluate a single condition: does inputVal satisfy the operator against condVal?
     * Mirrors Apex evaluateCondition logic. Applies expression transformation if set.
     */
    _evaluateOperator(operator, inputVal, condVal, col) {
        let input = (inputVal || '').trim();
        const cond = (condVal || '').trim();
        if (!cond) return true; // Empty condition = always pass

        // Apply expression transformation (mirrors Apex applyExpression)
        const expr = col?.expression || '';
        if (expr && expr !== 'RANGE_START' && expr !== 'RANGE_END') {
            input = this._applyExpression(expr, input);
        }

        switch (operator) {
            case 'EQUALS':
                return input.toLowerCase() === cond.toLowerCase();
            case 'NOT_EQUALS':
                return input.toLowerCase() !== cond.toLowerCase();
            case 'GREATER_THAN': {
                const n1 = parseFloat(input), n2 = parseFloat(cond);
                return !isNaN(n1) && !isNaN(n2) ? n1 > n2 : input > cond;
            }
            case 'LESS_THAN': {
                const n1 = parseFloat(input), n2 = parseFloat(cond);
                return !isNaN(n1) && !isNaN(n2) ? n1 < n2 : input < cond;
            }
            case 'GREATER_THAN_OR_EQUAL': {
                const n1 = parseFloat(input), n2 = parseFloat(cond);
                return !isNaN(n1) && !isNaN(n2) ? n1 >= n2 : input >= cond;
            }
            case 'LESS_THAN_OR_EQUAL': {
                const n1 = parseFloat(input), n2 = parseFloat(cond);
                return !isNaN(n1) && !isNaN(n2) ? n1 <= n2 : input <= cond;
            }
            case 'IN':
                return cond.split(',').some(v => v.trim().toLowerCase() === input.toLowerCase());
            case 'NOT_IN':
                return !cond.split(',').some(v => v.trim().toLowerCase() === input.toLowerCase());
            case 'CONTAINS':
                return input.toLowerCase().includes(cond.toLowerCase());
            case 'STARTS_WITH':
                return input.toLowerCase().startsWith(cond.toLowerCase());
            case 'ENDS_WITH':
                return input.toLowerCase().endsWith(cond.toLowerCase());
            case 'BETWEEN': {
                // condVal = "startVal,endVal", evaluate using column rangeStartOp/rangeEndOp
                const parts = cond.split(',');
                if (parts.length !== 2) return false;
                const startVal = parseFloat(parts[0].trim());
                const endVal = parseFloat(parts[1].trim());
                const actual = parseFloat(input);
                if (isNaN(actual)) return false;
                if (isNaN(startVal) && isNaN(endVal)) return false;
                const startOp = col?.rangeStartOp || '>=';
                const endOp = col?.rangeEndOp || '<=';
                const startOk = isNaN(startVal) ? true : (startOp === '>=' ? actual >= startVal : actual > startVal);
                const endOk = isNaN(endVal) ? true : (endOp === '<=' ? actual <= endVal : actual < endVal);
                return startOk && endOk;
            }
            default:
                return input.toLowerCase() === cond.toLowerCase();
        }
    }

    /**
     * Get human-readable operator label for trace display.
     */
    _operatorLabel(op) {
        const map = {
            'EQUALS': '=', 'NOT_EQUALS': '!=', 'GREATER_THAN': '>',
            'LESS_THAN': '<', 'GREATER_THAN_OR_EQUAL': '>=', 'LESS_THAN_OR_EQUAL': '<=',
            'IN': 'IN', 'NOT_IN': 'NOT IN', 'CONTAINS': 'Contains',
            'STARTS_WITH': 'Starts With', 'ENDS_WITH': 'Ends With', 'BETWEEN': 'Range'
        };
        return map[op] || op;
    }

    _getStageName(stageId) {
        const opt = (this.stageOptions || []).find(o => o.value === stageId);
        return opt ? opt.label : stageId || '';
    }

    _getActionName(actionId) {
        const opt = (this.actionButtonOptions || []).find(o => o.value === actionId);
        return opt ? opt.label : actionId || '';
    }

    /**
     * Apply expression transformation to a value before comparison.
     * Mirrors Apex applyExpression: TRIM, UPPER, LOWER, LENGTH, LEFT(n), RIGHT(n)
     */
    _applyExpression(expression, value) {
        if (!expression || !value) return value || '';
        const expr = expression.toUpperCase().trim();
        if (expr.startsWith('TRIM')) return value.trim();
        if (expr.startsWith('UPPER')) return value.toUpperCase();
        if (expr.startsWith('LOWER')) return value.toLowerCase();
        if (expr.startsWith('LENGTH')) return String(value.length);
        if (expr.startsWith('LEFT')) {
            const n = this._extractExprNumber(expression);
            return n != null && value.length >= n ? value.substring(0, n) : value;
        }
        if (expr.startsWith('RIGHT')) {
            const n = this._extractExprNumber(expression);
            return n != null && value.length >= n ? value.substring(value.length - n) : value;
        }
        return value;
    }

    _extractExprNumber(expression) {
        const match = expression.match(/,\s*(\d+)\s*\)/);
        return match ? parseInt(match[1], 10) : null;
    }

    handleClearTestResult() {
        this._clearTestResult();
        this._clearTestHighlight();
    }

    _clearTestResult() {
        this.testResult = null;
        this.testMatchedRuleId = null;
        this.testMatchedRuleIds = [];
    }

    _clearTestHighlight() {
        this.testMatchedRuleId = null;
        this.testMatchedRuleIds = [];
    }

    // ════════════════════════════════════════════════════════
    _resetState() {
        this._currentBPId = null;
        this._selectedBPLabel = '';
        this._showLeafMessage = false;
        this.dynamicConditionColumns = [];
        this._prevDynamicConditionColumns = null;
        this.dynamicActionColumns = [];
        this.rows = [];
        this.originalRows = [];
        this.selectedColKey = null;
        this.selectedColGroup = null;
        this.selectedRowId = null;
        this.searchFilter = '';
        this.error = null;
        this.isLoading = false;
        this.showEditColModal = false;
        this.editColFieldId = null;
        this.editColFieldName = '';
        this.editColOperator = 'EQUALS';
        this.editColExpression = '';
        this.editingCellKey = null;
        this.editingCellValue = '';
        this.hoverCellKey = null;
        this.showExpressionMode = false;
        this.expressionValue = '';
        this.testResult = null;
        this.testMatchedRuleId = null;
        this.testMatchedRuleIds = [];
        this.testFormData = { previousStageId: '', actionButtonId: '', fieldValues: {} };
    }

    _clearData() {
        this.dynamicConditionColumns = [];
        this._prevDynamicConditionColumns = null;
        this.dynamicActionColumns = [];
        this.rows = [];
        this.originalRows = [];
        this.selectedColKey = null;
        this.selectedColGroup = null;
        this.selectedRowId = null;
        this.error = null;
        this.editingCellKey = null;
        this.editingCellValue = '';
        this.hoverCellKey = null;
        this.testResult = null;
        this.testMatchedRuleId = null;
        this.testMatchedRuleIds = [];
    }

    // ════════════════════════════════════════════════════════
    // TOAST HELPER
    // ════════════════════════════════════════════════════════
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}