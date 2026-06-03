/**
 * @description Generic Decision Table Engine View (PEGA-style)
 *              ALL columns are dynamic — discovered from Condition rows returned by server.
 *              Conditions with Type='Condition' → CONDITIONS group.
 *              Conditions with Type='Action' → ACTIONS group.
 *              The wrapper provides dropdownHints for convenience (e.g., combobox for stage fields).
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import getDecisionTableData from '@salesforce/apex/FEC_StageTransitionEngine.getDecisionTableData';
import getFieldsForBusinessProcess from '@salesforce/apex/FEC_StageTransitionEngine.getFieldsForBusinessProcess';
import saveRuleWithConditions from '@salesforce/apex/FEC_StageTransitionEngine.saveRuleWithConditions';
import deleteRule from '@salesforce/apex/FEC_StageTransitionEngine.deleteRule';
import deleteConditionColumn from '@salesforce/apex/FEC_StageTransitionEngine.deleteConditionColumn';
import testRuleEvaluation from '@salesforce/apex/FEC_StageTransitionEngine.testRuleEvaluation';
import updateColumnProperties from '@salesforce/apex/FEC_StageTransitionEngine.updateColumnProperties';

export default class FecDecisionEngineView extends LightningElement {

    // ════════════════════════════════════════════════════════
    // @api properties
    // ════════════════════════════════════════════════════════
    @api tableKey = 'STAGE_TRANSITION';

    @api
    get businessProcessId() {
        return this._currentBPId;
    }
    set businessProcessId(value) {
        this._currentBPId = value;
        this.searchFilter = '';
        if (value) {
            this.loadDecisionTable();
        } else {
            this._clearData();
        }
    }

    /** Map of label → dropdown options. E.g. { 'Previous Stage': [{label,value}] } */
    @api dropdownHints = {};

    /** Suggested condition column labels for Add Column modal (e.g., ['Current Stage', 'Action Button']) */
    @api suggestedConditionColumns = [];

    /** Suggested action column labels for Add Column modal (e.g., ['Next Stage', 'Next Queue']) */
    @api suggestedActionColumns = [];

    /** Display label for the selected context */
    @api contextLabel = '';

    // ════════════════════════════════════════════════════════
    // State management — ALL columns are dynamic
    // ════════════════════════════════════════════════════════
    @track conditionColumns = [];      // Type='Condition' columns discovered from data
    @track actionColumns = [];         // Type='Action' columns discovered from data
    @track dynamicConditionColumns = []; // MDS field columns (have fieldId, operator, etc.)
    @track dynamicActionColumns = [];    // Custom action columns added via UI
    @track rows = [];
    @track originalRows = [];
    selectedColKey = null;
    selectedColGroup = null;
    selectedRowId = null;
    @track searchFilter = '';
    @track fieldOptions = [];
    @track showAddRuleModal = false;
    @track showAddColModal = false;
    @track newColGroup = 'condition';
    @track newColActionName = '';
    @track selectedNewColOperator = 'EQUALS';
    _addColDirection = 'right';
    @track isEditMode = false;
    @track editingRowId = null;
    @track isLoading = false;
    @track error = null;

    // ── Inline Edit state ───────────────────────────────────
    editingCellKey = null;
    @track editingCellValue = '';
    hoverCellKey = null;

    // ── Edit Column Modal state ─────────────────────────────
    @track showEditColModal = false;
    @track editColFieldId = null;
    @track editColFieldName = '';
    @track editColOperator = 'EQUALS';
    @track editColExpression = '';

    // ── Expression Mode state ────────────────────────────────
    @track showExpressionMode = false;
    @track expressionValue = '';

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

    // ── Modal form data ─────────────────────────────────────
    @track formData = {
        conditionValues: {},   // label → value for Condition-type columns
        actionValues: {},      // label → value for Action-type columns
        customActions: {},
        priority: 1,
        conditions: []         // dynamic MDS field conditions
    };

    @track selectedNewColFieldId = null;

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

    operatorLabelMap = {
        'EQUALS': '=', 'NOT_EQUALS': '!=', 'GREATER_THAN': '>',
        'LESS_THAN': '<', 'GREATER_THAN_OR_EQUAL': '>=', 'LESS_THAN_OR_EQUAL': '<=',
        'IN': 'IN', 'NOT_IN': 'NOT IN', 'CONTAINS': 'Contains',
        'STARTS_WITH': 'Starts With', 'ENDS_WITH': 'Ends With', 'BETWEEN': 'BETWEEN'
    };

    reverseOperatorMap = {
        '=': 'EQUALS', '!=': 'NOT_EQUALS', 'Contains': 'CONTAINS',
        'Not Contains': 'NOT_CONTAINS', '>': 'GREATER_THAN', '<': 'LESS_THAN',
        '>=': 'GREATER_THAN_OR_EQUAL', '<=': 'LESS_THAN_OR_EQUAL',
        'IN': 'IN', 'NOT IN': 'NOT_IN', 'Starts With': 'STARTS_WITH',
        'Ends With': 'ENDS_WITH', 'BETWEEN': 'BETWEEN'
    };

    // ════════════════════════════════════════════════════════
    // LOAD DECISION TABLE DATA
    // ════════════════════════════════════════════════════════
    loadDecisionTable() {
        if (!this._currentBPId) return;
        this.isLoading = true;
        this.error = null;
        this._clearTestResult();

        getDecisionTableData({ businessProcessId: this._currentBPId, tableKey: this.tableKey })
            .then(result => {
                this.transformToDecisionTable(result);
            })
            .catch(err => {
                this.error = err.body?.message || err.message || 'Error loading Decision Table';
                this._clearData();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ════════════════════════════════════════════════════════
    // TRANSFORM RULES DATA → DECISION TABLE FORMAT
    // ALL columns discovered from Condition rows
    // ════════════════════════════════════════════════════════
    transformToDecisionTable(data) {
        const rulesData = data.rules || [];
        const serverColumns = data.conditionColumns || [];

        // 1. Build unique dynamic condition columns from server data (Label-based)
        const fieldMap = new Map();
        for (const col of serverColumns) {
            const labelKey = col.fieldName || '';
            if (labelKey && !fieldMap.has(labelKey)) {
                fieldMap.set(labelKey, {
                    fieldId: labelKey,
                    fieldName: col.fieldName || '',
                    fieldApiName: col.fieldApiName || '',
                    dataType: col.dataType || 'Text',
                    operator: 'EQUALS'
                });
            }
        }

        // 2. Discover ALL columns from conditions — group by label + type
        const discoveredConditionLabels = new Map(); // label → 'Condition'
        const discoveredActionLabels = new Map();    // label → 'Action'

        for (const rule of rulesData) {
            const conditions = this._parseConditions(rule.conditions);
            for (const cond of conditions) {
                const condLabel = cond.label || '';
                if (!condLabel) continue;
                const condType = cond.type || 'Condition';
                if (condType === 'Action') {
                    if (!discoveredActionLabels.has(condLabel)) {
                        discoveredActionLabels.set(condLabel, { label: condLabel });
                    }
                } else {
                    if (!discoveredConditionLabels.has(condLabel) && !fieldMap.has(condLabel)) {
                        discoveredConditionLabels.set(condLabel, { label: condLabel });
                    }
                }
            }
        }

        // Build conditionColumns (non-MDS Condition-type columns discovered from data)
        this.conditionColumns = [...discoveredConditionLabels.values()];

        // Build actionColumns (Action-type columns discovered from data)
        this.actionColumns = [...discoveredActionLabels.values()];

        // 3. Extract operator + expression per MDS column from conditions
        const startOps = new Set(['>=', '>', 'GREATER_THAN_OR_EQUAL', 'GREATER_THAN']);
        const endOps = new Set(['<=', '<', 'LESS_THAN_OR_EQUAL', 'LESS_THAN']);
        const fieldOpsMap = new Map();
        const fieldRangeMarkers = new Map();
        for (const rule of rulesData) {
            const conditions = this._parseConditions(rule.conditions);
            for (const cond of conditions) {
                const condKey = cond.label || cond.fieldId || '';
                if (condKey && fieldMap.has(condKey)) {
                    if (!fieldOpsMap.has(condKey)) {
                        fieldOpsMap.set(condKey, new Set());
                    }
                    fieldOpsMap.get(condKey).add(cond.operator);

                    if (!fieldRangeMarkers.has(condKey)) {
                        fieldRangeMarkers.set(condKey, { hasStart: false, hasEnd: false, startOp: '>=', endOp: '<=' });
                    }
                    const markers = fieldRangeMarkers.get(condKey);
                    if (cond.expression === 'RANGE_START') {
                        markers.hasStart = true;
                        markers.startOp = cond.operator || '>=';
                    } else if (cond.expression === 'RANGE_END') {
                        markers.hasEnd = true;
                        markers.endOp = cond.operator || '<=';
                    }

                    const col = fieldMap.get(condKey);
                    if (!col.expression && cond.expression && cond.expression !== 'RANGE_START' && cond.expression !== 'RANGE_END') {
                        col.expression = cond.expression;
                    }
                }
            }
        }

        const opNorm = { 'GREATER_THAN_OR_EQUAL': '>=', 'GREATER_THAN': '>', 'LESS_THAN_OR_EQUAL': '<=', 'LESS_THAN': '<' };
        for (const [fId, ops] of fieldOpsMap) {
            const col = fieldMap.get(fId);
            const markers = fieldRangeMarkers.get(fId);

            if (markers && (markers.hasStart || markers.hasEnd)) {
                col.operator = 'BETWEEN';
                col.rangeStartOp = opNorm[markers.startOp] || markers.startOp || '>=';
                col.rangeEndOp = opNorm[markers.endOp] || markers.endOp || '<=';
            } else {
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

        if (this._prevDynamicConditionColumns) {
            // Preserve column order from previous state
            const prevOrder = this._prevDynamicConditionColumns.map(p => p.fieldName || p.fieldId);
            const newCols = this.dynamicConditionColumns;
            const ordered = [];
            const remaining = new Map(newCols.map(c => [c.fieldName || c.fieldId, c]));

            // First: add columns in previous order
            for (const name of prevOrder) {
                if (remaining.has(name)) {
                    ordered.push(remaining.get(name));
                    remaining.delete(name);
                }
            }
            // Then: append any new columns not in previous order
            for (const col of remaining.values()) {
                ordered.push(col);
            }
            this.dynamicConditionColumns = ordered;

            // Restore operator settings from previous state
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

        // 4. Restore dynamic action columns from Action-type conditions (non-discovered)
        const discoveredDynActionCols = new Map();
        for (const rule of rulesData) {
            const conditions = this._parseConditions(rule.conditions);
            for (const cond of conditions) {
                if (cond.type === 'Action' && cond.label) {
                    // Only add to dynamicActionColumns if not already in actionColumns
                    const inAction = this.actionColumns.some(a => a.label === cond.label);
                    if (!inAction && !discoveredDynActionCols.has(cond.label)) {
                        discoveredDynActionCols.set(cond.label, { key: `customAction_${cond.label}`, label: cond.label, type: 'dynamic' });
                    }
                }
            }
        }
        if (discoveredDynActionCols.size > 0) {
            let newDynActions = [...discoveredDynActionCols.values()];
            // Preserve column order from previous state
            if (this._prevDynamicActionColumns) {
                const prevOrder = this._prevDynamicActionColumns.map(p => p.key);
                const ordered = [];
                const remaining = new Map(newDynActions.map(c => [c.key, c]));
                for (const k of prevOrder) {
                    if (remaining.has(k)) {
                        ordered.push(remaining.get(k));
                        remaining.delete(k);
                    }
                }
                for (const col of remaining.values()) {
                    ordered.push(col);
                }
                newDynActions = ordered;
            }
            this.dynamicActionColumns = newDynActions;
        }
        this._prevDynamicActionColumns = [...this.dynamicActionColumns];

        // 5. Transform each rule into a row
        const transformedRows = rulesData.map(rule => {
            const conditions = this._parseConditions(rule.conditions);

            // Extract condition values and action values by label
            const conditionValues = {};
            const actionValues = { customActions: {} };
            const conditionIdMap = {};
            const actionIdMap = {};

            for (const cond of conditions) {
                const condLabel = cond.label || '';
                const condType = cond.type || 'Condition';
                if (!condLabel) continue;

                // Skip MDS field conditions — handled separately in conditionCells
                if (fieldMap.has(condLabel)) continue;

                if (condType === 'Action') {
                    const isKnownAction = this.actionColumns.some(a => a.label === condLabel);
                    if (isKnownAction) {
                        actionValues[condLabel] = cond.value || '';
                        actionIdMap[condLabel] = cond.id || null;
                    } else {
                        actionValues.customActions[condLabel] = cond.value || '';
                        actionIdMap[condLabel] = cond.id || null;
                    }
                } else {
                    conditionValues[condLabel] = cond.value || '';
                    conditionIdMap[condLabel] = cond.id || null;
                }
            }

            // Group MDS conditions by label for OR sub-values
            const condGroupMap = new Map();
            for (const cond of conditions) {
                const condKey = cond.label || cond.fieldId || '';
                if (condKey && fieldMap.has(condKey)) {
                    if (!condGroupMap.has(condKey)) {
                        condGroupMap.set(condKey, []);
                    }
                    condGroupMap.get(condKey).push({
                        conditionId: cond.id || null,
                        operator: cond.operator || '',
                        value: cond.value || '',
                        expression: cond.expression || '',
                        order: cond.order
                    });
                }
            }

            // Build MDS condition cells
            const conditionCells = this.dynamicConditionColumns.map(col => {
                const condGroup = condGroupMap.get(col.fieldId) || [];
                const colOperator = col.operator || 'EQUALS';
                const isInOperator = colOperator === 'IN' || colOperator === 'NOT_IN';
                const isRange = colOperator === 'BETWEEN';

                if (isRange && condGroup.length > 0) {
                    let startVal = '';
                    let endVal = '';
                    for (const cond of condGroup) {
                        const expr = cond.expression || '';
                        if (expr === 'RANGE_START') {
                            startVal = cond.value || '';
                        } else if (expr === 'RANGE_END') {
                            endVal = cond.value || '';
                        } else {
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
                conditionValues,
                actionValues,
                conditionIdMap,
                actionIdMap,
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
        try { return JSON.parse(conditions); } catch (e) { return []; }
    }

    // ════════════════════════════════════════════════════════
    // SEARCH / FILTER — searches across ALL column values
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
            // Search in MDS condition cells
            const matchCondition = (row.conditionCells || []).some(cell =>
                (cell.values || []).some(v => (v.displayValue || v.value || '').toLowerCase().includes(term))
            );
            if (matchCondition) return true;

            // Search in discovered condition values
            const cv = row.conditionValues || {};
            for (const val of Object.values(cv)) {
                if ((val || '').toLowerCase().includes(term)) return true;
            }

            // Search in discovered action values
            const av = row.actionValues || {};
            for (const [key, val] of Object.entries(av)) {
                if (key === 'customActions') {
                    for (const v of Object.values(val || {})) {
                        if ((v || '').toLowerCase().includes(term)) return true;
                    }
                } else if ((val || '').toLowerCase().includes(term)) {
                    return true;
                }
            }
            return false;
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

        getFieldsForBusinessProcess({ businessProcessId: this._currentBPId, tableKey: this.tableKey })
            .then(data => {
                this.fieldOptions = (data || []).map(f => ({
                    label: (f.label || f.fieldName || '').replace(/\s*\(.*?\)\s*$/, '').trim(),
                    value: f.value || f.fieldId,
                    fieldApiName: f.fieldApiName || '',
                    dataType: f.dataType || 'Text'
                }));
                this.showAddColModal = true;
            })
            .catch(err => {
                this.showToast('Error', err.body?.message || err.message || 'Cannot load fields list', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /** Get suggested action column names for Add Column modal */
    get suggestedActionOptions() {
        const existing = new Set((this.actionColumns || []).map(c => c.label));
        return (this.suggestedActionColumns || []).filter(label => !existing.has(label));
    }

    /** Get suggested condition column names for Add Column modal */
    get suggestedConditionOptions() {
        const existingCond = new Set((this.conditionColumns || []).map(c => c.label));
        const existingDyn = new Set((this.dynamicConditionColumns || []).map(c => c.fieldId));
        return (this.suggestedConditionColumns || []).filter(label => !existingCond.has(label) && !existingDyn.has(label));
    }

    get hasSuggestedConditionOptions() {
        return this.suggestedConditionOptions.length > 0;
    }

    handleSelectSuggestedCondition(event) {
        const colName = event.currentTarget.dataset.colName;
        this.selectedNewColFieldId = colName;
        // Also add to fieldOptions if not present
        const exists = (this.fieldOptions || []).some(f => f.value === colName);
        if (!exists) {
            this.fieldOptions = [{ label: colName, value: colName, fieldApiName: colName, dataType: 'Text' }, ...this.fieldOptions];
        }
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

    handleSelectSuggestedAction(event) {
        const colName = event.currentTarget.dataset.colName;
        this.newColActionName = colName;
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

    handleRangeStartOpChange(event) { this.rangeStartOp = event.detail.value; }
    handleRangeEndOpChange(event) { this.rangeEndOp = event.detail.value; }

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

    handleEditColRangeStartOpChange(event) { this.editColRangeStartOp = event.detail.value; }
    handleEditColRangeEndOpChange(event) { this.editColRangeEndOp = event.detail.value; }

    handleToggleExpression() {
        this.showExpressionMode = !this.showExpressionMode;
        if (!this.showExpressionMode) this.expressionValue = '';
    }

    handleExpressionChange(event) {
        this.expressionValue = event.detail?.value ?? event.target.value ?? '';
    }

    get isConditionColGroup() { return this.newColGroup === 'condition'; }
    get isActionColGroup() { return this.newColGroup === 'action'; }

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
            this.showToast('Error', 'Please select a field', 'error');
            return;
        }

        const selectedField = this.fieldOptions.find(f => f.value === this.selectedNewColFieldId);
        if (!selectedField) return;

        const operator = this.selectedNewColOperator || 'EQUALS';
        const cleanLabel = selectedField.label.replace(/\s*\(.*?\)\s*$/, '').trim();
        
        // Duplicate check across all condition columns (by fieldId, fieldName, or label — regardless of operator)
        const existsDynamic = this.dynamicConditionColumns.some(
            c => c.fieldId === this.selectedNewColFieldId || c.fieldName === cleanLabel
        );
        const existsDiscovered = this.conditionColumns.some(
            c => c.label === cleanLabel
        );
        if (existsDynamic || existsDiscovered) {
            this.showToast('Error', `Condition column "${cleanLabel}" already exists`, 'error');
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

        const insertIdx = this._getConditionInsertIndex();
        const updated = [...this.dynamicConditionColumns];
        updated.splice(insertIdx, 0, newCol);
        this.dynamicConditionColumns = updated;
        this._prevDynamicConditionColumns = [...updated];

        this.originalRows = this.originalRows.map(row => {
            const cells = [...(row.conditionCells || [])];
            cells.splice(insertIdx, 0, {
                fieldId: selectedField.value,
                conditionId: null, operator: '', value: '', displayValue: '',
                values: [{ key: `val_${selectedField.value}_0`, conditionId: null, value: '', displayValue: '', isMultiValue: false, valuePills: [] }],
                hasOrValues: false
            });
            return { ...row, conditionCells: cells };
        });
        this.rows = [...this.originalRows];
        this._closeAddColModal();

        // Persist the new column to server by re-saving the first rule
        // This ensures the column survives a page refresh
        if (this.originalRows.length > 0) {
            this._persistNewColumn(this.originalRows[0].ruleId, newCol.fieldName || newCol.fieldId);
        }
    }

    /**
     * Persist a new column by re-saving a rule with all its current conditions + the new empty column.
     * This creates a Condition row on the server so the column survives refresh.
     */
    _persistNewColumn(ruleId, newColLabel) {
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;
        this.isLoading = true;

        // Rebuild all conditions from the row's current data
        const conditions = [];

        // Discovered condition columns
        const cv = row.conditionValues || {};
        for (const col of this.conditionColumns) {
            const val = cv[col.label];
            const existingId = (row.conditionIdMap || {})[col.label] || null;
            if (val || existingId) {
                conditions.push({ id: existingId, fieldId: null, operator: '=', value: val || '', expression: null, order: conditions.length + 1, type: 'Condition', label: col.label });
            }
        }

        // Discovered action columns
        const av = row.actionValues || {};
        for (const col of this.actionColumns) {
            const val = av[col.label];
            const existingId = (row.actionIdMap || {})[col.label] || null;
            if (val || existingId) {
                conditions.push({ id: existingId, fieldId: null, operator: null, value: val || '', expression: null, order: conditions.length + 1, type: 'Action', label: col.label });
            }
        }

        // Dynamic MDS condition columns (including the new one)
        for (const cell of (row.conditionCells || [])) {
            if (!cell.fieldId) continue;
            const colInfo = this.dynamicConditionColumns.find(c => c.fieldId === cell.fieldId);
            const cellLabel = colInfo ? colInfo.fieldName : cell.fieldId;
            const isRange = colInfo && colInfo.operator === 'BETWEEN';
            const values = cell.values || [{ value: cell.value || '' }];

            if (isRange) {
                // Range column: save as RANGE_START + RANGE_END pair
                const startVal = values[0] ? values[0].value || '' : '';
                const endVal = values[1] ? values[1].value || '' : '';
                conditions.push({
                    id: values[0]?.conditionId || null, fieldId: cell.fieldId,
                    operator: colInfo.rangeStartOp || '>=', value: startVal,
                    expression: 'RANGE_START', order: conditions.length + 1, type: 'Condition', label: cellLabel
                });
                conditions.push({
                    id: values[1]?.conditionId || null, fieldId: cell.fieldId,
                    operator: colInfo.rangeEndOp || '<=', value: endVal,
                    expression: 'RANGE_END', order: conditions.length + 1, type: 'Condition', label: cellLabel
                });
            } else {
                for (const val of values) {
                    if (val.value || val.conditionId) {
                        conditions.push({
                            id: val.conditionId || null, fieldId: cell.fieldId,
                            operator: cell.operator || '=', value: val.value || '',
                            order: conditions.length + 1, type: 'Condition', label: cellLabel
                        });
                    }
                }
            }
        }

        // Add the new column with empty placeholder
        const hasNewCol = conditions.some(c => c.label === newColLabel);
        if (!hasNewCol) {
            const newColInfo = this.dynamicConditionColumns.find(c => c.fieldName === newColLabel || c.fieldId === newColLabel);
            const isNewRange = newColInfo && newColInfo.operator === 'BETWEEN';
            if (isNewRange) {
                conditions.push({
                    id: null, fieldId: newColLabel, operator: newColInfo.rangeStartOp || '>=', value: ' ',
                    expression: 'RANGE_START', order: conditions.length + 1, type: 'Condition', label: newColLabel
                });
                conditions.push({
                    id: null, fieldId: newColLabel, operator: newColInfo.rangeEndOp || '<=', value: ' ',
                    expression: 'RANGE_END', order: conditions.length + 1, type: 'Condition', label: newColLabel
                });
            } else {
                conditions.push({
                    id: null, fieldId: newColLabel, operator: '=', value: ' ',
                    expression: null, order: conditions.length + 1, type: 'Condition', label: newColLabel
                });
            }
        }

        // Custom actions
        const customActions = av.customActions || {};
        for (const [label, value] of Object.entries(customActions)) {
            if (label && value) {
                conditions.push({ id: null, fieldId: null, operator: null, value, expression: null, order: conditions.length + 1, type: 'Action', label });
            }
        }

        const payload = {
            recordId: ruleId,
            priority: row.priority || 1,
            conditionRequirement: 'AND',
            conditionLogic: '',
            conditions,
            tableKey: this.tableKey,
            keyId: this._currentBPId
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => { this.loadDecisionTable(); this._notifyDataChanged(); })
            .catch(err => { this.isLoading = false; this.showToast('Error', err.body?.message || err.message || 'Cannot save new column', 'error'); });
    }

    _confirmAddActionCol() {
        if (!this.newColActionName || !this.newColActionName.trim()) {
            this.showToast('Error', 'Please enter an Action column name', 'error');
            return;
        }

        const colName = this.newColActionName.trim();

        // Duplicate check across all action columns
        const allActionLabels = [
            ...this.actionColumns.map(c => c.label),
            ...this.dynamicActionColumns.map(c => c.label)
        ];
        if (allActionLabels.includes(colName)) {
            this.showToast('Error', `Action column "${colName}" already exists`, 'error');
            return;
        }

        this._closeAddColModal();

        // Persist directly to server — don't add locally (server reload will discover it)
        if (this.originalRows.length > 0) {
            this._persistNewActionColumn(this.originalRows[0].ruleId, colName);
        } else {
            // No rows yet — just add locally
            const colKey = `customAction_${Date.now()}`;
            this.dynamicActionColumns = [...this.dynamicActionColumns, { key: colKey, label: colName, type: 'dynamicAction' }];
        }
    }

    _persistNewActionColumn(ruleId, newColLabel) {
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;
        this.isLoading = true;

        const conditions = [];

        // Rebuild discovered condition columns
        const cv = row.conditionValues || {};
        for (const col of this.conditionColumns) {
            const val = cv[col.label];
            const existingId = (row.conditionIdMap || {})[col.label] || null;
            if (val || existingId) {
                conditions.push({ id: existingId, fieldId: null, operator: '=', value: val || '', expression: null, order: conditions.length + 1, type: 'Condition', label: col.label });
            }
        }

        // Rebuild discovered action columns
        const av = row.actionValues || {};
        for (const col of this.actionColumns) {
            const val = av[col.label];
            const existingId = (row.actionIdMap || {})[col.label] || null;
            if (val || existingId) {
                conditions.push({ id: existingId, fieldId: null, operator: null, value: val || '', expression: null, order: conditions.length + 1, type: 'Action', label: col.label });
            }
        }

        // Rebuild dynamic MDS condition columns
        for (const cell of (row.conditionCells || [])) {
            if (!cell.fieldId) continue;
            const colInfo = this.dynamicConditionColumns.find(c => c.fieldId === cell.fieldId);
            const cellLabel = colInfo ? colInfo.fieldName : cell.fieldId;
            const isRange = colInfo && colInfo.operator === 'BETWEEN';

            if (isRange) {
                const values = cell.values || [];
                const startVal = values[0] ? values[0].value || '' : '';
                const endVal = values[1] ? values[1].value || '' : '';
                conditions.push({
                    id: values[0]?.conditionId || null, fieldId: cell.fieldId,
                    operator: colInfo.rangeStartOp || '>=', value: startVal,
                    expression: 'RANGE_START', order: conditions.length + 1, type: 'Condition', label: cellLabel
                });
                conditions.push({
                    id: values[1]?.conditionId || null, fieldId: cell.fieldId,
                    operator: colInfo.rangeEndOp || '<=', value: endVal,
                    expression: 'RANGE_END', order: conditions.length + 1, type: 'Condition', label: cellLabel
                });
            } else {
                for (const val of (cell.values || [])) {
                    if (val.value || val.conditionId) {
                        conditions.push({ id: val.conditionId || null, fieldId: cell.fieldId, operator: cell.operator || '=', value: val.value || '', order: conditions.length + 1, type: 'Condition', label: cellLabel });
                    }
                }
            }
        }

        // Existing custom actions
        const customActions = av.customActions || {};
        for (const [label, value] of Object.entries(customActions)) {
            if (label && value) {
                conditions.push({ id: null, fieldId: null, operator: null, value, expression: null, order: conditions.length + 1, type: 'Action', label });
            }
        }

        // Add new action column with placeholder
        conditions.push({ id: null, fieldId: null, operator: null, value: ' ', expression: null, order: conditions.length + 1, type: 'Action', label: newColLabel });

        const payload = {
            recordId: ruleId,
            priority: row.priority || 1,
            conditionRequirement: 'AND',
            conditionLogic: '',
            conditions,
            tableKey: this.tableKey,
            keyId: this._currentBPId
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => { this.loadDecisionTable(); this._notifyDataChanged(); })
            .catch(err => { this.isLoading = false; this.showToast('Error', err.body?.message || err.message || 'Cannot save new column', 'error'); });
    }

    _getConditionInsertIndex() {
        if (!this.selectedColKey) return this.dynamicConditionColumns.length;
        // Check dynamic MDS columns
        const dynIdx = this.dynamicConditionColumns.findIndex(c => c.fieldId === this.selectedColKey);
        if (dynIdx !== -1) return this._addColDirection === 'left' ? dynIdx : dynIdx + 1;
        // Check discovered condition columns — insert at start of dynamic columns (closest to discovered)
        const discIdx = this.conditionColumns.findIndex(c => c.label === this.selectedColKey);
        if (discIdx !== -1) return 0;
        return this.dynamicConditionColumns.length;
    }

    _getActionInsertIndex() {
        if (!this.selectedColKey) return this.dynamicActionColumns.length;
        const dynIdx = this.dynamicActionColumns.findIndex(c => c.key === this.selectedColKey);
        if (dynIdx !== -1) return this._addColDirection === 'left' ? dynIdx : dynIdx + 1;
        const discIdx = this.actionColumns.findIndex(c => c.label === this.selectedColKey);
        if (discIdx !== -1) return 0;
        return this.dynamicActionColumns.length;
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

    handleCloseAddColModal() { this._closeAddColModal(); }

    // ════════════════════════════════════════════════════════
    // DELETE COLUMN — ALL columns are deletable
    // ════════════════════════════════════════════════════════
    async handleDeleteColumn() {
        if (!this.selectedColKey) return;

        const confirmed = await LightningConfirm.open({
            message: 'Deleting this column will remove all related conditions on every row. Continue?',
            variant: 'header',
            label: 'Confirm Delete Column',
            theme: 'warning'
        });
        if (!confirmed) return;

        // Check if it's a dynamic action column (UI-only)
        const isDynamicAction = this.dynamicActionColumns.some(c => c.key === this.selectedColKey);
        if (isDynamicAction) {
            this.dynamicActionColumns = this.dynamicActionColumns.filter(c => c.key !== this.selectedColKey);
            this.selectedColKey = null;
            this.selectedColGroup = null;
            this.showToast('Success', 'Đã xóa cột action', 'success');
            return;
        }

        // Check if it's a discovered action column
        const isDiscoveredAction = this.actionColumns.some(c => c.label === this.selectedColKey);
        if (isDiscoveredAction) {
            // Delete from server
            this.isLoading = true;
            deleteConditionColumn({
                businessProcessId: this._currentBPId,
                labelText: this.selectedColKey,
                tableKey: this.tableKey
            })
                .then(() => {
                    this.showToast('Success', 'Đã xóa cột', 'success');
                    this.selectedColKey = null;
                    this.selectedColGroup = null;
                    this.loadDecisionTable();
                })
                .catch(err => {
                    this.showToast('Error', err.body?.message || err.message || 'Không thể xóa cột', 'error');
                })
                .finally(() => { this.isLoading = false; });
            return;
        }

        // Check if it's a discovered condition column
        const isDiscoveredCondition = this.conditionColumns.some(c => c.label === this.selectedColKey);
        if (isDiscoveredCondition) {
            this.isLoading = true;
            deleteConditionColumn({
                businessProcessId: this._currentBPId,
                labelText: this.selectedColKey,
                tableKey: this.tableKey
            })
                .then(() => {
                    this.showToast('Success', 'Đã xóa cột', 'success');
                    this.selectedColKey = null;
                    this.selectedColGroup = null;
                    this.loadDecisionTable();
                })
                .catch(err => {
                    this.showToast('Error', err.body?.message || err.message || 'Không thể xóa cột', 'error');
                })
                .finally(() => { this.isLoading = false; });
            return;
        }

        // Dynamic condition column (MDS field) — call Apex with label text
        const col = this.dynamicConditionColumns.find(c => c.fieldId === this.selectedColKey);
        const labelText = col ? col.fieldName : this.selectedColKey;
        this.isLoading = true;
        deleteConditionColumn({
            businessProcessId: this._currentBPId,
            labelText: labelText,
            tableKey: this.tableKey
        })
            .then(() => {
                this.showToast('Success', 'Đã xóa cột điều kiện', 'success');
                this.selectedColKey = null;
                this.selectedColGroup = null;
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Error', err.body?.message || err.message || 'Không thể xóa cột', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    // ALL columns are deletable — no fixed columns
    _isFixedColumn() {
        return false;
    }

    // ════════════════════════════════════════════════════════
    // ADD ROW — Above / Below
    // ════════════════════════════════════════════════════════
    handleAddRowAbove() { this._addRowAtPosition('above'); }
    handleAddRowBelow() { this._addRowAtPosition('below'); }

    _addRowAtPosition(position) {
        if (!this._currentBPId) {
            this.showToast('Error', 'Please select a Business Process', 'error');
            return;
        }

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

        // Build empty form with all discovered columns
        const conditionValues = {};
        for (const col of this.conditionColumns) {
            conditionValues[col.label] = '';
        }
        const actionValues = {};
        for (const col of this.actionColumns) {
            actionValues[col.label] = '';
        }

        this.formData = {
            conditionValues,
            actionValues,
            customActions: {},
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
    }

    // ════════════════════════════════════════════════════════
    // EDIT ROW (Rule)
    // ════════════════════════════════════════════════════════
    handleEditRow(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const row = this.originalRows.find(r => r.ruleId === rowId);
        if (!row) {
            this.showToast('Error', 'Cannot find row data to edit', 'error');
            return;
        }

        this.isEditMode = true;
        this.editingRowId = rowId;

        // Map condition cells back to form conditions
        const mappedConditions = [];
        this.dynamicConditionColumns.forEach((col) => {
            const cell = (row.conditionCells || []).find(c => c.fieldId === col.fieldId);
            const values = cell ? (cell.values || []) : [];
            if (values.length === 0 || (values.length === 1 && !values[0].value)) {
                const rawVal = values[0] ? (values[0].value || '') : '';
                // Resolve to dropdown ID if hints available
                const resolvedVal = this._resolveValueFromHint(col.fieldName, rawVal)
                    || this._resolveValueFromHint(col.fieldId, rawVal)
                    || rawVal;
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
                    value: resolvedVal
                });
            } else {
                for (const val of values) {
                    const rawVal = val.value || '';
                    const resolvedVal = this._resolveValueFromHint(col.fieldName, rawVal)
                        || this._resolveValueFromHint(col.fieldId, rawVal)
                        || rawVal;
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
                        value: resolvedVal
                    });
                }
            }
        });

        const cv = row.conditionValues || {};
        const av = row.actionValues || {};

        // Build condition values — resolve dropdown hints back to IDs for combobox
        const conditionValues = {};
        for (const col of this.conditionColumns) {
            const rawVal = cv[col.label] || '';
            conditionValues[col.label] = this._resolveValueFromHint(col.label, rawVal) || rawVal;
        }

        // Build action values — resolve dropdown hints back to IDs for combobox
        const actionValues = {};
        for (const col of this.actionColumns) {
            const rawVal = av[col.label] || '';
            actionValues[col.label] = this._resolveValueFromHint(col.label, rawVal) || rawVal;
        }

        this.formData = {
            conditionValues,
            actionValues,
            conditionIdMap: row.conditionIdMap || {},
            actionIdMap: row.actionIdMap || {},
            customActions: av.customActions || {},
            priority: row.priority || 1,
            conditions: mappedConditions
        };

        this.showAddRuleModal = true;
    }

    // ════════════════════════════════════════════════════════
    // DELETE ROW (Rule)
    // ════════════════════════════════════════════════════════
    async handleDeleteRow() {
        if (!this.selectedRowId) return;

        const selectedRow = this.originalRows.find(r => r.ruleId === this.selectedRowId);
        if (selectedRow && this._isOtherwiseRow(selectedRow)) {
            this.showToast('Error', 'Không thể xóa dòng otherwise (fallback)', 'error');
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: 'Are you sure you want to delete this rule? All related conditions will be removed.',
            variant: 'header',
            label: 'Confirm Delete Rule',
            theme: 'warning'
        });
        if (!confirmed) return;

        this.isLoading = true;
        deleteRule({ ruleId: this.selectedRowId })
            .then(() => {
                this.showToast('Success', 'Đã xóa rule', 'success');
                this.selectedRowId = null;
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Error', err.body?.message || err.message || 'Không thể xóa rule', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    // ════════════════════════════════════════════════════════
    // SAVE RULE (Add / Edit)
    // ════════════════════════════════════════════════════════
    handleSaveRule() {
        if (!this._validateForm()) return;
        this.isLoading = true;

        const operatorMap = {
            'EQUALS': '=', 'NOT_EQUALS': '!=', 'CONTAINS': 'Contains',
            'NOT_CONTAINS': 'Not Contains', 'GREATER_THAN': '>', 'LESS_THAN': '<',
            'GREATER_THAN_OR_EQUAL': '>=', 'LESS_THAN_OR_EQUAL': '<=',
            'IN': 'IN', 'NOT_IN': 'NOT IN', 'STARTS_WITH': 'Starts With', 'ENDS_WITH': 'Ends With'
        };
        const rangeOpToPicklist = { '>=': '>=', '>': '>', '<=': '<=', '<': '<' };

        const colOperatorMap = new Map();
        const colInfoMap = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOperatorMap.set(col.fieldId, col.operator || 'EQUALS');
            colInfoMap.set(col.fieldId, col);
        }

        // Build MDS field conditions
        const builtConditions = [];
        for (const c of (this.formData.conditions || [])) {
            if (!c.fieldId) continue;
            const colOp = colOperatorMap.get(c.fieldId) || c.operator || 'EQUALS';
            const colInfo = colInfoMap.get(c.fieldId);
            const isRange = colOp === 'BETWEEN';

            if (isRange) {
                const parts = c.value ? (c.value.includes(',') ? c.value.split(',') : [c.value, '']) : ['', ''];
                const startVal = (parts[0] || '').trim();
                const endVal = (parts[1] || '').trim();
                const startOp = colInfo ? (colInfo.rangeStartOp || '>=') : '>=';
                const endOp = colInfo ? (colInfo.rangeEndOp || '<=') : '<=';

                builtConditions.push({
                    id: null, fieldId: c.fieldId,
                    operator: rangeOpToPicklist[startOp] || '>=',
                    value: startVal || '', expression: 'RANGE_START',
                    order: builtConditions.length + 1, type: 'Condition',
                    label: c.fieldName || c.fieldId
                });
                builtConditions.push({
                    id: null, fieldId: c.fieldId,
                    operator: rangeOpToPicklist[endOp] || '<=',
                    value: endVal || '', expression: 'RANGE_END',
                    order: builtConditions.length + 1, type: 'Condition',
                    label: c.fieldName || c.fieldId
                });
            } else {
                // Resolve dropdown ID to display label if hints available
                const resolvedValue = this._resolveLabelFromHint(c.fieldName, c.value)
                    || this._resolveLabelFromHint(c.fieldId, c.value)
                    || c.value;
                builtConditions.push({
                    id: c.conditionId && !String(c.conditionId).startsWith('new') ? c.conditionId : null,
                    fieldId: c.fieldId || null,
                    operator: operatorMap[colOp] || colOp,
                    value: resolvedValue, order: c.order,
                    type: 'Condition', label: c.fieldName || c.fieldId
                });
            }
        }

        // Add custom action conditions
        const customActions = this.formData.customActions || {};
        for (const [label, value] of Object.entries(customActions)) {
            if (label && value) {
                builtConditions.push({
                    id: null, fieldId: null, operator: null,
                    value: value, expression: null,
                    order: builtConditions.length + 1, type: 'Action', label: label
                });
            }
        }

        // Add discovered condition columns (always persist to preserve column structure)
        const condVals = this.formData.conditionValues || {};
        for (const col of this.conditionColumns) {
            const rawValue = condVals[col.label];
            const existingId = (this.formData.conditionIdMap || {})[col.label] || null;
            const finalValue = rawValue ? (this._resolveLabelFromHint(col.label, rawValue) || rawValue) : '';
            builtConditions.push({
                id: existingId, fieldId: null, operator: '=',
                value: finalValue, expression: null,
                order: builtConditions.length + 1, type: 'Condition', label: col.label
            });
        }

        // Add action columns (deduplicated, always persist to preserve column structure)
        const actVals = this.formData.actionValues || {};
        const seenActionLabels = new Set();
        const allActionCols = [...this.actionColumns, ...this.dynamicActionColumns];
        for (const col of allActionCols) {
            if (seenActionLabels.has(col.label)) continue;
            seenActionLabels.add(col.label);
            const rawValue = actVals[col.label];
            const existingId = (this.formData.actionIdMap || {})[col.label] || null;
            const finalValue = rawValue ? (this._resolveLabelFromHint(col.label, rawValue) || rawValue) : '';
            builtConditions.push({
                id: existingId, fieldId: null, operator: null,
                value: finalValue, expression: null,
                order: builtConditions.length + 1, type: 'Action', label: col.label
            });
        }

        const payload = {
            recordId: this.isEditMode ? this.editingRowId : null,
            priority: this.formData.priority || 1,
            conditionRequirement: 'AND',
            conditionLogic: '',
            conditions: builtConditions,
            tableKey: this.tableKey,
            keyId: this._currentBPId
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => {
                this.showToast('Success', this.isEditMode ? 'Rule updated successfully' : 'New rule added successfully', 'success');
                this.showAddRuleModal = false;
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Error', err.body?.message || err.message || 'Cannot save rule', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    _validateForm() {
        // Check all lightning-input validity in the modal
        const allInputs = this.template.querySelectorAll('lightning-input');
        let allValid = true;
        allInputs.forEach(input => {
            if (!input.reportValidity()) {
                allValid = false;
            }
        });
        if (!allValid) return false;

        // Validate Range conditions: End >= Start
        for (const cond of (this.formData.conditions || [])) {
            if (!cond.isRange) continue;
            const startVal = cond.rangeStartValue;
            const endVal = cond.rangeEndValue;
            if (startVal && endVal && Number(endVal) < Number(startVal)) {
                this.showToast('Error', `"${cond.fieldName}" End value must be >= Start value`, 'error');
                return false;
            }
        }
        return true;
    }

    // ════════════════════════════════════════════════════════
    // DROPDOWN HINTS HELPERS
    // ════════════════════════════════════════════════════════
    /** Given a label and a dropdown value (ID), resolve to display label */
    _resolveLabelFromHint(colLabel, value) {
        const hints = this.dropdownHints || {};
        const options = hints[colLabel];
        if (!options || !Array.isArray(options)) return value;
        const opt = options.find(o => o.value === value);
        return opt ? opt.label : value;
    }

    /** Given a label and a display name, resolve back to dropdown value (ID) */
    _resolveValueFromHint(colLabel, displayName) {
        const hints = this.dropdownHints || {};
        const options = hints[colLabel];
        if (!options || !Array.isArray(options)) return null;
        const opt = options.find(o => o.label === displayName);
        return opt ? opt.value : null;
    }

    /** Check if a column label has dropdown hints */
    _hasDropdownHint(colLabel) {
        const hints = this.dropdownHints || {};
        const options = hints[colLabel];
        return !!(options && Array.isArray(options) && options.length > 0);
    }

    /** Get dropdown options for a column label */
    _getDropdownOptions(colLabel) {
        const hints = this.dropdownHints || {};
        return hints[colLabel] || [];
    }

    // ════════════════════════════════════════════════════════
    // MODAL HELPERS
    // ════════════════════════════════════════════════════════
    handleModalConditionValueChange(event) {
        const colLabel = event.target.dataset.colLabel || event.target.name;
        const value = event.detail?.value ?? event.target.value;
        const conditionValues = { ...this.formData.conditionValues, [colLabel]: value };
        this.formData = { ...this.formData, conditionValues };
    }

    handleModalActionValueChange(event) {
        const colLabel = event.target.dataset.colLabel || event.target.name;
        const value = event.detail?.value ?? event.target.value;
        const actionValues = { ...this.formData.actionValues, [colLabel]: value };
        this.formData = { ...this.formData, actionValues };
    }

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

    handleRangeConditionChange(event) {
        const idx = parseInt(event.target.dataset.index, 10);
        if (isNaN(idx)) return;
        const rangePart = event.target.dataset.rangePart;
        const newVal = event.target.value || '';
        const conditions = [...(this.formData.conditions || [])];
        if (!conditions[idx]) return;
        const currentValue = conditions[idx].value || '';
        const parts = currentValue.includes(',') ? currentValue.split(',') : [currentValue, ''];
        let startVal = (parts[0] || '').trim();
        let endVal = (parts[1] || '').trim();
        if (rangePart === 'start') { startVal = newVal.trim(); } else { endVal = newVal.trim(); }
        const combined = (startVal || endVal) ? `${startVal},${endVal}` : '';
        conditions[idx] = { ...conditions[idx], value: combined };
        this.formData = { ...this.formData, conditions };
    }

    handleAddPillValue(event) {
        const idx = parseInt(event.target.dataset.index || event.currentTarget.dataset.index, 10);
        if (isNaN(idx)) return;
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
        if (input) input.value = '';
    }

    handlePillInputKeyup(event) {
        if (event.key === 'Enter') this.handleAddPillValue(event);
    }

    handleRemovePillValue(event) {
        event.stopPropagation();
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const pillKey = event.currentTarget.dataset.pillKey;
        if (isNaN(idx)) return;
        const conditions = [...(this.formData.conditions || [])];
        if (!conditions[idx]) return;
        const existing = conditions[idx].value ? conditions[idx].value.split(',').map(v => v.trim()).filter(Boolean) : [];
        const pillIdx = parseInt(pillKey.split('_').pop(), 10);
        if (!isNaN(pillIdx) && pillIdx < existing.length) existing.splice(pillIdx, 1);
        conditions[idx] = { ...conditions[idx], value: existing.join(',') };
        this.formData = { ...this.formData, conditions };
    }

    handleCloseModal() { this.showAddRuleModal = false; }
    handleOverlayClick() { this.showAddRuleModal = false; this.showAddColModal = false; this.showEditColModal = false; }
    handleDialogClick(event) { event.stopPropagation(); }

    handleCustomActionChange(event) {
        const colLabel = event.target.dataset.colLabel;
        const val = event.target.value;
        const updated = { ...(this.formData.customActions || {}), [colLabel]: val };
        this.formData = { ...this.formData, customActions: updated };
    }

    get formConditions() {
        const colOpMap = new Map();
        const colInfoMap = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOpMap.set(col.fieldId, col.operator || 'EQUALS');
            colInfoMap.set(col.fieldId, col);
        }

        const seenFields = new Map(); // fieldId → count
        return (this.formData.conditions || []).map((c, i) => {
            const colOp = colOpMap.get(c.fieldId) || c.operator || 'EQUALS';
            const colInfo = colInfoMap.get(c.fieldId);
            const isMulti = colOp === 'IN' || colOp === 'NOT_IN';
            const isRange = colOp === 'BETWEEN';
            const pillValues = isMulti && c.value
                ? c.value.split(',').map((v, idx) => ({ key: `fpill_${i}_${idx}`, label: v.trim() })).filter(p => p.label)
                : [];
            const opLabel = this.operatorLabelMap[colOp] || colOp;

            let rangeStartValue = '', rangeEndValue = '', rangeStartOp = '>=', rangeEndOp = '<=';
            if (isRange) {
                const parts = (c.value || '').includes(',') ? (c.value || '').split(',') : [c.value || '', ''];
                rangeStartValue = (parts[0] || '').trim();
                rangeEndValue = (parts[1] || '').trim();
                rangeStartOp = colInfo ? (colInfo.rangeStartOp || '>=') : '>=';
                rangeEndOp = colInfo ? (colInfo.rangeEndOp || '<=') : '<=';
            }

            // Detect OR continuation — same fieldId appearing multiple times
            const fieldKey = c.fieldId || c.fieldName;
            const fieldCount = seenFields.get(fieldKey) || 0;
            seenFields.set(fieldKey, fieldCount + 1);
            const isOrContinuation = fieldCount > 0;

            return {
                ...c, index: i, orderNum: i + 1,
                fieldLabel: isOrContinuation
                    ? `↳ OR`
                    : (isRange ? `${c.fieldName} (Range)` : `${c.fieldName} (${opLabel})`),
                isOrContinuation,
                isMultiValueOperator: isMulti, isRange,
                hasDropdown: this._hasDropdownHint(c.fieldName) || this._hasDropdownHint(c.fieldId),
                dropdownOptions: this._getDropdownOptions(c.fieldName).length > 0 ? this._getDropdownOptions(c.fieldName) : this._getDropdownOptions(c.fieldId),
                rangeStartValue, rangeEndValue, rangeStartOp, rangeEndOp, pillValues
            };
        });
    }

    get hasFormConditions() { return this.formData.conditions && this.formData.conditions.length > 0; }

    /** Modal fields for discovered condition columns */
    get modalConditionFields() {
        return this.conditionColumns.map(col => ({
            key: col.label,
            label: col.label,
            hasDropdown: this._hasDropdownHint(col.label),
            dropdownOptions: this._getDropdownOptions(col.label),
            value: (this.formData.conditionValues || {})[col.label] || ''
        }));
    }

    /** Modal fields for discovered action columns */
    get modalActionFields() {
        const seen = new Set();
        const allCols = [...this.actionColumns, ...this.dynamicActionColumns];
        return allCols
            .filter(col => {
                if (seen.has(col.label)) return false;
                seen.add(col.label);
                return true;
            })
            .map(col => ({
                key: col.label,
                label: col.label,
                hasDropdown: this._hasDropdownHint(col.label),
                dropdownOptions: this._getDropdownOptions(col.label),
                value: (this.formData.actionValues || {})[col.label] || (this.formData.customActions || {})[col.label] || ''
            }));
    }

    get dynamicActionFields() {
        return this.dynamicActionColumns.map(col => ({
            key: col.key,
            label: col.label,
            hasDropdown: this._hasDropdownHint(col.label),
            dropdownOptions: this._getDropdownOptions(col.label),
            value: (this.formData.customActions || {})[col.label] || ''
        }));
    }

    get hasDynamicActionFields() { return this.dynamicActionColumns.length > 0; }
    get hasModalConditionFields() { return this.conditionColumns.length > 0; }
    get hasModalActionFields() { return this.actionColumns.length > 0 || this.dynamicActionColumns.length > 0; }

    get modalTitle() { return this.isEditMode ? 'Edit Rule' : 'Add New Rule'; }
    get modalSaveLabel() { return this.isEditMode ? 'Update' : 'Save'; }

    // ════════════════════════════════════════════════════════
    // GETTERS
    // ════════════════════════════════════════════════════════
    get hasData() { return this.originalRows.length > 0; }
    get hasNoSearchResults() { return this.originalRows.length > 0 && this.filteredRows.length === 0; }
    get isBPSelected() { return !!this._currentBPId; }
    get showTestPanel() { return false; } // Hidden — feature not in use

    get conditionColSpan() {
        let count = this.conditionColumns.length;
        for (const col of this.dynamicConditionColumns) {
            count += col.operator === 'BETWEEN' ? 2 : 1;
        }
        return count;
    }

    get actionColSpan() {
        return this.actionColumns.length + this.dynamicActionColumns.length;
    }

    get disableDeleteCol() { return !this.selectedColKey; }
    get disableAddCol() { return this.isLoading; }

    get disableDeleteRow() {
        if (!this.selectedRowId) return true;
        const selectedRow = this.originalRows.find(r => r.ruleId === this.selectedRowId);
        if (selectedRow && this._isOtherwiseRow(selectedRow)) return true;
        return false;
    }

    get disableAddRow() {
        if (this.originalRows.length === 0) return false;
        return !this.selectedRowId;
    }

    get selectedItemLabel() { return this.contextLabel || ''; }
    get totalRuleCount() { return this.originalRows.length; }

    get hasConditionColumns() {
        return this.conditionColumns.length + this.dynamicConditionColumns.length > 0;
    }

    get hasSearchFilter() { return !!(this.searchFilter && this.searchFilter.trim()); }

    get displayConditionColumns() {
        // Discovered condition columns (non-MDS, from data)
        const discovered = this.conditionColumns.map(col => {
            const isSelected = this.selectedColKey === col.label;
            return {
                colKey: col.label,
                colGroup: 'condition',
                fieldId: col.label,
                fieldName: col.label,
                label: col.label,
                isRange: false,
                isDynamic: false,
                headerClass: isSelected ? 'col-header selected-col-header' : 'col-header'
            };
        });

        // MDS dynamic condition columns
        const dynamic = [];
        for (const col of this.dynamicConditionColumns) {
            const isSelected = this.selectedColKey === col.fieldId;
            const operatorLabel = this.operatorLabelMap[col.operator] || col.operator || '=';
            const cleanFieldName = col.fieldName.replace(/\s*\(.*?\)\s*$/, '').trim() || col.fieldName;
            if (col.operator === 'BETWEEN') {
                const startOp = col.rangeStartOp || '>=';
                const endOp = col.rangeEndOp || '<=';
                dynamic.push({
                    ...col, colKey: col.fieldId, colGroup: 'condition',
                    fieldName: `${cleanFieldName} (Range)`,
                    isDynamic: true, isRange: true, rangeColspan: 2,
                    startOp, endOp,
                    startSubHeader: `${startOp} (Start)`, endSubHeader: `${endOp} (End)`,
                    startSubKey: `${col.fieldId}_start_sub`, endSubKey: `${col.fieldId}_end_sub`,
                    headerClass: isSelected ? 'col-header selected-col-header clickable-header' : 'col-header clickable-header'
                });
            } else {
                dynamic.push({
                    ...col, colKey: col.fieldId, colGroup: 'condition',
                    fieldName: `${cleanFieldName} (${operatorLabel})`,
                    isDynamic: true, isRange: false,
                    headerClass: isSelected ? 'col-header selected-col-header clickable-header' : 'col-header clickable-header'
                });
            }
        }
        return [...discovered, ...dynamic];
    }

    get hasRangeColumns() { return this.dynamicConditionColumns.some(c => c.operator === 'BETWEEN'); }
    get headerRowspan() { return this.hasRangeColumns ? 3 : 2; }
    get headerRowspanNonRange() { return this.hasRangeColumns ? 2 : 1; }

    get displayActionColumns() {
        const seen = new Set();
        const discovered = this.actionColumns
            .filter(col => { if (seen.has(col.label)) return false; seen.add(col.label); return true; })
            .map(col => {
                const isSelected = this.selectedColKey === col.label;
                return {
                    colKey: col.label, colGroup: 'action', key: col.label, label: col.label,
                    headerClass: isSelected ? 'col-header selected-col-header' : 'col-header'
                };
            });
        const dynamic = this.dynamicActionColumns
            .filter(col => { if (seen.has(col.label)) return false; seen.add(col.label); return true; })
            .map(col => {
                const isSelected = this.selectedColKey === col.key;
                return {
                    ...col, colKey: col.key, colGroup: 'action',
                    headerClass: isSelected ? 'col-header selected-col-header' : 'col-header'
                };
            });
        return [...discovered, ...dynamic];
    }

    get displayRows() {
        const isRowSelection = !!this.selectedRowId;
        const isColSelection = !!this.selectedColKey;

        return this.filteredRows.map((row, index) => {
            const isSelectedRow = row.ruleId === this.selectedRowId;
            const isOtherwise = this._isOtherwiseRow(row);
            const priorityDisplay = isOtherwise ? 'otherwise' : (index + 1);

            // Build discovered condition cells
            const fixedConditionCells = this.conditionColumns.map(col => ({
                key: col.label,
                value: (row.conditionValues || {})[col.label] || '',
                cellClass: this._cellClass(col.label, isSelectedRow, isRowSelection, isColSelection)
            }));

            // Build MDS dynamic condition cells
            const colMap = new Map();
            for (const col of this.dynamicConditionColumns) { colMap.set(col.fieldId, col); }

            const dynamicCells = (row.conditionCells || []).map(cell => {
                const colInfo = colMap.get(cell.fieldId);
                const isRange = colInfo && colInfo.operator === 'BETWEEN';

                if (isRange) {
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
                        ...cell, isRange: true, conditionId: firstVal.conditionId || null,
                        startValue, endValue, startCellKey, endCellKey,
                        isEditingStart, isEditingEnd,
                        editStartValue: isEditingStart ? this.editingCellValue : '',
                        editEndValue: isEditingEnd ? this.editingCellValue : '',
                        showStartToolbar, showEndToolbar,
                        hasStartValue: !!startValue, hasEndValue: !!endValue,
                        startTdKey: `${cell.fieldId}_start_td`, endTdKey: `${cell.fieldId}_end_td`,
                        cellClass: this._cellClass(cell.fieldId, isSelectedRow, isRowSelection, isColSelection)
                    };
                }

                const cellValues = (cell.values || []).map((val, vi) => {
                    const valCellKey = `${row.ruleId}_${cell.fieldId}_${vi}`;
                    const isEditing = this.editingCellKey === valCellKey;
                    const showToolbar = this.hoverCellKey === valCellKey;
                    const hasValue = val.value && val.value.trim();
                    return {
                        ...val, key: val.key || `val_${cell.fieldId}_${vi}`,
                        valueIndex: vi, cellKey: valCellKey, isEditing,
                        showToolbar: showToolbar && !!hasValue,
                        editValue: isEditing ? this.editingCellValue : '',
                        hasValue: !!hasValue
                    };
                });

                return {
                    ...cell, isRange: false, values: cellValues,
                    hasOrValues: cellValues.length > 1,
                    cellClass: this._cellClass(cell.fieldId, isSelectedRow, isRowSelection, isColSelection)
                };
            });

            // Build discovered action cells
            const actionCells = this.actionColumns.map(col => ({
                key: col.label,
                value: (row.actionValues || {})[col.label] || '',
                cellClass: this._cellClass(col.label, isSelectedRow, isRowSelection, isColSelection)
            }));

            // Build dynamic action cells
            const customActions = (row.actionValues || {}).customActions || {};
            const dynamicActionCells = this.dynamicActionColumns.map(col => ({
                key: col.key,
                value: customActions[col.label] || '',
                cellClass: this._cellClass(col.key, isSelectedRow, isRowSelection, isColSelection)
            }));

            const isTestMatched = (this.testMatchedRuleIds || []).includes(row.ruleId);

            return {
                ...row, priorityDisplay, isOtherwise,
                priorityCellClass: isOtherwise ? 'priority-cell otherwise-priority' : 'priority-cell',
                fixedConditionCells,
                displayConditionCells: dynamicCells,
                displayActionCells: [...actionCells, ...dynamicActionCells],
                rowClass: isTestMatched ? 'slds-hint-parent test-matched-row'
                    : isSelectedRow ? 'slds-hint-parent selected-row'
                    : isOtherwise ? 'slds-hint-parent otherwise-row'
                    : 'slds-hint-parent',
                editCellClass: isSelectedRow ? 'action-buttons selected-row-cell' : 'action-buttons'
            };
        });
    }

    _isOtherwiseRow(row) {
        if (!row || !row.conditionCells) return false;
        if (this.dynamicConditionColumns.length === 0) return false;
        const rows = this.filteredRows;
        if (rows.length === 0) return false;
        const lastRow = rows[rows.length - 1];
        if (row.ruleId !== lastRow.ruleId) return false;
        const hasAnyConditionValue = row.conditionCells.some(cell =>
            (cell.values || []).some(v => v.value && v.value.trim())
        );
        return !hasAnyConditionValue;
    }

    _cellClass(colKey, isSelectedRow, isRowSelection, isColSelection) {
        const classes = [];
        if (isColSelection && this.selectedColKey === colKey) classes.push('selected-col');
        if (isRowSelection && isSelectedRow) classes.push('selected-row-cell');
        return classes.join(' ');
    }

    // ════════════════════════════════════════════════════════
    // INLINE EDIT — Condition Cells
    // ════════════════════════════════════════════════════════
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
            if (this.hoverCellKey === cellKey) { this.hoverCellKey = null; }
            else { this.hoverCellKey = cellKey; this.editingCellKey = null; }
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

    handleInlineInputClick(event) { event.stopPropagation(); }

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
            if (input) { input.focus(); input.select(); }
        }, 50);
    }

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

    handleCellInputBlur(event) {
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

    _saveCellValue(ruleId, fieldId, newValue, valueIndex = 0) {
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;

        this.isLoading = true;

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
        const rangeOpToPicklist = { '>=': '>=', '>': '>', '<=': '<=', '<': '<' };

        // Build MDS conditions from all cells
        const conditions = [];
        for (const cell of (row.conditionCells || [])) {
            if (!cell.fieldId) continue;
            const colOp = colOperatorMap.get(cell.fieldId) || 'EQUALS';
            const colInfo = colInfoMap.get(cell.fieldId);
            const isRange = colOp === 'BETWEEN';
            const values = cell.values || [{ conditionId: cell.conditionId, value: cell.value || '' }];
            const cellLabel = colInfo ? colInfo.fieldName : cell.fieldId;

            for (let vi = 0; vi < values.length; vi++) {
                const val = values[vi];
                const isTarget = cell.fieldId === fieldId && vi === valueIndex;
                let finalValue = isTarget ? newValue : (val.value || '');

                if (isTarget && !finalValue && values.length > 1) continue;

                if (isRange) {
                    const rangeVal = isTarget ? newValue : (val.value || '');
                    const parts = rangeVal.includes(',') ? rangeVal.split(',') : [rangeVal, ''];
                    const startVal = (parts[0] || '').trim();
                    const endVal = (parts[1] || '').trim();
                    const startOp = colInfo ? (colInfo.rangeStartOp || '>=') : '>=';
                    const endOp = colInfo ? (colInfo.rangeEndOp || '<=') : '<=';

                    conditions.push({
                        id: null, fieldId: cell.fieldId,
                        operator: rangeOpToPicklist[startOp] || '>=',
                        value: startVal || '', expression: 'RANGE_START',
                        order: conditions.length + 1, type: 'Condition', label: cellLabel
                    });
                    conditions.push({
                        id: null, fieldId: cell.fieldId,
                        operator: rangeOpToPicklist[endOp] || '<=',
                        value: endVal || '', expression: 'RANGE_END',
                        order: conditions.length + 1, type: 'Condition', label: cellLabel
                    });
                    break;
                }

                if (!finalValue && !val.conditionId) continue;

                conditions.push({
                    id: val.conditionId && !String(val.conditionId).startsWith('new') ? val.conditionId : null,
                    fieldId: cell.fieldId,
                    operator: operatorMap[colOp] || colOp,
                    value: finalValue, order: conditions.length + 1,
                    type: 'Condition', label: cellLabel
                });
            }
        }

        // Add discovered condition columns from row data
        const cv = row.conditionValues || {};
        const fixedConditions = [];
        for (const col of this.conditionColumns) {
            const val = cv[col.label];
            const existingId = (row.conditionIdMap || {})[col.label] || null;
            if (val || existingId) {
                fixedConditions.push({
                    id: existingId, fieldId: null, operator: '=',
                    value: val || '', expression: null,
                    order: conditions.length + fixedConditions.length + 1,
                    type: 'Condition', label: col.label
                });
            }
        }

        // Add discovered action columns from row data
        const av = row.actionValues || {};
        for (const col of this.actionColumns) {
            const val = av[col.label];
            const existingId = (row.actionIdMap || {})[col.label] || null;
            if (val || existingId) {
                fixedConditions.push({
                    id: existingId, fieldId: null, operator: null,
                    value: val || '', expression: null,
                    order: conditions.length + fixedConditions.length + 1,
                    type: 'Action', label: col.label
                });
            }
        }

        // Add custom action conditions
        const customActions = av.customActions || {};
        for (const [label, value] of Object.entries(customActions)) {
            if (label && value) {
                fixedConditions.push({
                    id: null, fieldId: null, operator: null,
                    value: value, expression: null,
                    order: conditions.length + fixedConditions.length + 1,
                    type: 'Action', label: label
                });
            }
        }

        const payload = {
            recordId: ruleId,
            priority: row.priority || 1,
            conditionRequirement: 'AND',
            conditionLogic: '',
            conditions: [...conditions, ...fixedConditions],
            tableKey: this.tableKey,
            keyId: this._currentBPId
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => {
                this.showToast('Success', 'Value updated successfully', 'success');
                this.loadDecisionTable();
            })
            .catch(err => {
                this.showToast('Error', err.body?.message || err.message || 'Cannot save value', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    handleCellOR(event) {
        event.stopPropagation();
        const ruleId = event.currentTarget.dataset.ruleId;
        const fieldId = event.currentTarget.dataset.fieldId;
        if (!ruleId || !fieldId) return;

        this.hoverCellKey = null;
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
            conditionId: null, value: '', displayValue: '',
            isMultiValue: false, valuePills: []
        });

        const updatedCells = [...row.conditionCells];
        updatedCells[cellIdx] = { ...cell, values, hasOrValues: values.length > 1 };
        const updatedRow = { ...row, conditionCells: updatedCells };
        const updatedRows = [...this.originalRows];
        updatedRows[rowIdx] = updatedRow;
        this.originalRows = updatedRows;
        this.rows = [...updatedRows];

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
    handleRangeCellClick(event) {
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

        if (partValue) {
            if (this.hoverCellKey === cellKey) { this.hoverCellKey = null; }
            else { this.hoverCellKey = cellKey; this.editingCellKey = null; }
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
            if (input) { input.focus(); input.select(); }
        }, 50);
    }

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

    handleRangeCellInputKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            const ruleId = event.target.dataset.ruleId;
            const fieldId = event.target.dataset.fieldId;
            const rangePart = event.target.dataset.rangePart;
            const value = event.target.value || '';

            if (rangePart === 'start') {
                this._pendingRangeStart = { ruleId, fieldId, value: value.trim() };
                const endCellKey = `${ruleId}_${fieldId}_end`;
                this.editingCellKey = endCellKey;
                const row = this.originalRows.find(r => r.ruleId === ruleId);
                if (row) {
                    const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
                    const rawVal = cell && cell.values && cell.values[0] ? (cell.values[0].value || '') : '';
                    const parts = rawVal.includes(',') ? rawVal.split(',') : [rawVal, ''];
                    this.editingCellValue = (parts[1] || '').trim();
                } else { this.editingCellValue = ''; }
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    const input = this.template.querySelector(`input[data-cell-key="${endCellKey}"]`);
                    if (input) { input.focus(); input.select(); }
                }, 50);
            } else {
                this.editingCellKey = null;
                this.editingCellValue = '';
                const endValue = value.trim();
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

    handleRangeCellInputBlur(event) {
        const ruleId = event.target.dataset.ruleId;
        const fieldId = event.target.dataset.fieldId;
        const rangePart = event.target.dataset.rangePart;
        const value = event.target.value || '';
        const cellKey = `${ruleId}_${fieldId}_${rangePart}`;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const endCellKey = `${ruleId}_${fieldId}_end`;
            if (rangePart === 'start' && this.editingCellKey === endCellKey) return;
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

    _saveRangeCellValue(ruleId, fieldId, rangePart, newValue) {
        const row = this.originalRows.find(r => r.ruleId === ruleId);
        if (!row) return;
        const cell = (row.conditionCells || []).find(c => c.fieldId === fieldId);
        const rawValue = cell && cell.values && cell.values[0] ? (cell.values[0].value || '') : '';
        const parts = rawValue.includes(',') ? rawValue.split(',') : [rawValue, ''];
        let startVal = (parts[0] || '').trim();
        let endVal = (parts[1] || '').trim();
        if (rangePart === 'start') { startVal = newValue; } else { endVal = newValue; }
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

    handleEditColOperatorChange(event) { this.editColOperator = event.detail.value; }
    handleEditColFieldNameChange(event) { this.editColFieldName = event.target.value; }
    handleEditColExpressionChange(event) { this.editColExpression = event.detail?.value ?? event.target.value ?? ''; }

    handleConfirmEditCol() {
        if (!this.editColFieldId) return;
        const idx = this.dynamicConditionColumns.findIndex(c => c.fieldId === this.editColFieldId);
        if (idx === -1) return;

        const currentCol = this.dynamicConditionColumns[idx];
        const finalOperator = this.editColUseRange ? 'BETWEEN' : (this.editColOperator || currentCol.operator);

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

        if (finalOperator === 'BETWEEN') {
            if (this.editColExpression) {
                this.isLoading = true;
                updateColumnProperties({
                    businessProcessId: this._currentBPId,
                    labelText: currentCol.fieldName,
                    newOperator: '>=',
                    newExpression: this.editColExpression || '',
                    tableKey: this.tableKey
                })
                    .then(() => { this.showToast('Success', 'Đã cập nhật cột', 'success'); this.loadDecisionTable(); this._notifyDataChanged(); })
                    .catch(err => { this.showToast('Error', err.body?.message || err.message || 'Không thể cập nhật cột', 'error'); })
                    .finally(() => { this.isLoading = false; });
            } else {
                this.showToast('Success', 'Đã cập nhật cột', 'success');
            }
        } else {
            this.isLoading = true;
            updateColumnProperties({
                businessProcessId: this._currentBPId,
                labelText: currentCol.fieldName,
                newOperator: finalOperator,
                newExpression: this.editColExpression || '',
                tableKey: this.tableKey
            })
                .then(() => { this.showToast('Success', 'Đã cập nhật cột', 'success'); this.loadDecisionTable(); this._notifyDataChanged(); })
                .catch(err => { this.showToast('Error', err.body?.message || err.message || 'Không thể cập nhật cột', 'error'); })
                .finally(() => { this.isLoading = false; });
        }

        this._closeEditColModal();
    }

    handleCloseEditColModal() { this._closeEditColModal(); }

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
    // TEST PANEL — inputs for ALL Condition-type columns
    // ════════════════════════════════════════════════════════
    isTestPanelOpen = false;
    testFormData = { conditionValues: {}, fieldValues: {} };
    testResult = null;
    testMatchedRuleId = null;

    get testPanelChevronIcon() { return this.isTestPanelOpen ? 'utility:chevrondown' : 'utility:chevronright'; }

    get hasTestConditionFields() { return this.dynamicConditionColumns && this.dynamicConditionColumns.length > 0; }

    /** Test panel fields for discovered condition columns */
    get testDiscoveredConditionFields() {
        return this.conditionColumns.map(col => ({
            key: col.label,
            label: col.label,
            hasDropdown: this._hasDropdownHint(col.label),
            dropdownOptions: this._getDropdownOptions(col.label),
            value: (this.testFormData.conditionValues || {})[col.label] || ''
        }));
    }

    get hasTestDiscoveredConditionFields() { return this.conditionColumns.length > 0; }

    get testConditionFields() {
        return this.dynamicConditionColumns.map(col => {
            const opLabel = col.operator || '=';
            return {
                fieldId: col.fieldId,
                fieldApiName: col.fieldApiName,
                label: col.fieldName + ' (' + opLabel + ')',
                placeholder: opLabel + ' enter value...',
                value: this.testFormData.fieldValues[col.fieldApiName] || ''
            };
        });
    }

    get disableTestButton() { return false; }
    get hasEvaluationTrace() { return this.testResult && this.testResult.evaluationTrace && this.testResult.evaluationTrace.length > 0; }
    get matchedTraceRows() { return this.testResult && this.testResult.evaluationTrace ? this.testResult.evaluationTrace.filter(rt => rt.isMatch) : []; }

    get hasNoTestFilters() {
        const hasCondVal = Object.values(this.testFormData.conditionValues || {}).some(v => v && v.trim());
        const hasFieldVal = Object.values(this.testFormData.fieldValues || {}).some(v => v && v.trim());
        return !hasCondVal && !hasFieldVal;
    }

    handleToggleTestPanel() { this.isTestPanelOpen = !this.isTestPanelOpen; }

    handleTestDiscoveredConditionChange(event) {
        const colLabel = event.target.dataset.colLabel || event.target.name;
        const value = event.detail?.value ?? event.target.value;
        const conditionValues = { ...(this.testFormData.conditionValues || {}), [colLabel]: value };
        this.testFormData = { ...this.testFormData, conditionValues };
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

        const colOpMap = new Map();
        const colByApi = new Map();
        for (const col of this.dynamicConditionColumns) {
            colOpMap.set(col.fieldId, col.operator || 'EQUALS');
            if (col.fieldApiName) colByApi.set(col.fieldApiName.toLowerCase(), col);
        }

        const fieldFilters = {};
        for (const key of Object.keys(this.testFormData.fieldValues || {})) {
            const val = this.testFormData.fieldValues[key];
            if (val && val.trim()) fieldFilters[key] = val.trim();
        }

        // Resolve discovered condition test values
        const testCondVals = {};
        for (const col of this.conditionColumns) {
            const rawVal = (this.testFormData.conditionValues || {})[col.label];
            if (rawVal) {
                testCondVals[col.label] = this._resolveLabelFromHint(col.label, rawVal) || rawVal;
            }
        }

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

            // Check discovered condition columns
            for (const col of this.conditionColumns) {
                const testVal = testCondVals[col.label];
                if (!testVal) continue;
                const rowVal = cv[col.label] || '';
                if (rowVal !== testVal) {
                    match = false;
                    condDetails.push({
                        key: row.ruleId + '-' + col.label,
                        fieldLabel: col.label, operator: '=',
                        expectedValue: rowVal, actualValue: testVal, result: false
                    });
                }
            }

            // Evaluate MDS condition fields
            if (match) {
                const cells = row.conditionCells || [];
                for (const apiName of Object.keys(fieldFilters)) {
                    const inputVal = fieldFilters[apiName];
                    const col = colByApi.get(apiName.toLowerCase());
                    if (!col) continue;

                    const cell = cells.find(c => c.fieldId === col.fieldId);
                    const colOp = colOpMap.get(col.fieldId) || 'EQUALS';

                    if (!cell || !cell.values || cell.values.every(v => !v.value)) continue;

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
                                fieldLabel: col.fieldName, operator: this._operatorLabel(colOp),
                                expectedValue: condVal, actualValue: inputVal, result: true
                            });
                            break;
                        }
                    }
                    if (!fieldMatch) {
                        match = false;
                        const firstCondVal = values.find(v => v.value)?.value || '';
                        condDetails.push({
                            key: row.ruleId + '-' + col.fieldId,
                            fieldLabel: col.fieldName, operator: this._operatorLabel(colOp),
                            expectedValue: firstCondVal, actualValue: inputVal, result: false
                        });
                    }
                }
            }

            const isFirstMatch = match && !firstMatchFound;
            if (match) { matchedRuleIds.push(row.ruleId); if (isFirstMatch) firstMatchFound = true; }

            // Build trace display from discovered columns
            const traceCondLabel = this.conditionColumns.map(c => cv[c.label] || '').filter(Boolean).join(' → ');
            const traceActionLabel = this.actionColumns.map(c => av[c.label] || '').filter(Boolean).join(' → ');
            const customActionsObj = av.customActions || {};
            const customActionsDisplay = Object.entries(customActionsObj).filter(([, v]) => v).map(([k, v]) => `${k}: ${v}`).join(' │ ');

            trace.push({
                ruleId: row.ruleId, stt,
                previousStage: traceCondLabel,
                nextStage: traceActionLabel,
                nextQueue: '',
                availableDecisions: '',
                customActionsDisplay,
                hasCustomActions: Object.keys(customActionsObj).length > 0,
                isMatch: match, isFirstMatch, isNotMatch: !match, isSkipped: false,
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

    _evaluateOperator(operator, inputVal, condVal, col) {
        let input = (inputVal || '').trim();
        const cond = (condVal || '').trim();
        if (!cond) return true;

        const expr = col?.expression || '';
        if (expr && expr !== 'RANGE_START' && expr !== 'RANGE_END') {
            input = this._applyExpression(expr, input);
        }

        switch (operator) {
            case 'EQUALS': return input.toLowerCase() === cond.toLowerCase();
            case 'NOT_EQUALS': return input.toLowerCase() !== cond.toLowerCase();
            case 'GREATER_THAN': { const n1 = parseFloat(input), n2 = parseFloat(cond); return !isNaN(n1) && !isNaN(n2) ? n1 > n2 : input > cond; }
            case 'LESS_THAN': { const n1 = parseFloat(input), n2 = parseFloat(cond); return !isNaN(n1) && !isNaN(n2) ? n1 < n2 : input < cond; }
            case 'GREATER_THAN_OR_EQUAL': { const n1 = parseFloat(input), n2 = parseFloat(cond); return !isNaN(n1) && !isNaN(n2) ? n1 >= n2 : input >= cond; }
            case 'LESS_THAN_OR_EQUAL': { const n1 = parseFloat(input), n2 = parseFloat(cond); return !isNaN(n1) && !isNaN(n2) ? n1 <= n2 : input <= cond; }
            case 'IN': return cond.split(',').some(v => v.trim().toLowerCase() === input.toLowerCase());
            case 'NOT_IN': return !cond.split(',').some(v => v.trim().toLowerCase() === input.toLowerCase());
            case 'CONTAINS': return input.toLowerCase().includes(cond.toLowerCase());
            case 'STARTS_WITH': return input.toLowerCase().startsWith(cond.toLowerCase());
            case 'ENDS_WITH': return input.toLowerCase().endsWith(cond.toLowerCase());
            case 'BETWEEN': {
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
            default: return input.toLowerCase() === cond.toLowerCase();
        }
    }

    _operatorLabel(op) {
        const map = {
            'EQUALS': '=', 'NOT_EQUALS': '!=', 'GREATER_THAN': '>',
            'LESS_THAN': '<', 'GREATER_THAN_OR_EQUAL': '>=', 'LESS_THAN_OR_EQUAL': '<=',
            'IN': 'IN', 'NOT_IN': 'NOT IN', 'CONTAINS': 'Contains',
            'STARTS_WITH': 'Starts With', 'ENDS_WITH': 'Ends With', 'BETWEEN': 'Range'
        };
        return map[op] || op;
    }

    _applyExpression(expression, value) {
        if (!expression || !value) return value || '';
        const expr = expression.toUpperCase().trim();
        if (expr.startsWith('TRIM')) return value.trim();
        if (expr.startsWith('UPPER')) return value.toUpperCase();
        if (expr.startsWith('LOWER')) return value.toLowerCase();
        if (expr.startsWith('LENGTH')) return String(value.length);
        if (expr.startsWith('LEFT')) { const n = this._extractExprNumber(expression); return n != null && value.length >= n ? value.substring(0, n) : value; }
        if (expr.startsWith('RIGHT')) { const n = this._extractExprNumber(expression); return n != null && value.length >= n ? value.substring(value.length - n) : value; }
        return value;
    }

    _extractExprNumber(expression) {
        const match = expression.match(/,\s*(\d+)\s*\)/);
        return match ? parseInt(match[1], 10) : null;
    }

    handleClearTestResult() {
        this._clearTestResult();
        this._clearTestHighlight();
        this.testFormData = { conditionValues: {}, fieldValues: {} };
    }

    _clearTestResult() { this.testResult = null; this.testMatchedRuleId = null; this.testMatchedRuleIds = []; }
    _clearTestHighlight() { this.testMatchedRuleId = null; this.testMatchedRuleIds = []; }

    // ════════════════════════════════════════════════════════
    // STATE RESET
    // ════════════════════════════════════════════════════════
    _resetState() {
        this._currentBPId = null;
        this.conditionColumns = [];
        this.actionColumns = [];
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
        this.testFormData = { conditionValues: {}, fieldValues: {} };
    }

    _clearData() {
        this.conditionColumns = [];
        this.actionColumns = [];
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

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /**
     * Notify parent that data has been mutated (save/delete) so history can refresh.
     */
    _notifyDataChanged() {
        this.dispatchEvent(new CustomEvent('datachanged', { bubbles: true, composed: true }));
    }

    // ════════════════════════════════════════════════════════
    // EMPTY STATE — TẠO DECISION TABLE MỚI VỚI 5 CỘT DEFAULT
    // ════════════════════════════════════════════════════════

    /** True khi BP có context nhưng chưa có rule và chưa có cột nào */
    get isEmptyDecisionTable() {
        return this.isBPSelected
            && !this.isLoading
            && this.originalRows.length === 0
            && this.conditionColumns.length === 0
            && this.actionColumns.length === 0
            && this.dynamicConditionColumns.length === 0
            && this.dynamicActionColumns.length === 0;
    }

    /**
     * Khởi tạo Decision Table mới — seed các cột default + 1 row trống.
     * Save xuống DB ngay lập tức để rule có Id.
     */
    handleCreateNewDecisionTable() {
        if (!this._currentBPId) {
            this.showToast('Error', 'Please select a Business Process', 'error');
            return;
        }
        this.isLoading = true;

        const builtConditions = [];
        let order = 1;

        // Seed default condition columns (Type='Condition')
        for (const label of (this.defaultConditionColumns || [])) {
            builtConditions.push({
                id: null, fieldId: null, operator: '=',
                value: '', expression: null,
                order: order++, type: 'Condition', label
            });
        }

        // Seed default action columns (Type='Action')
        for (const label of (this.defaultActionColumns || [])) {
            builtConditions.push({
                id: null, fieldId: null, operator: null,
                value: '', expression: null,
                order: order++, type: 'Action', label
            });
        }

        const payload = {
            recordId: null,
            priority: 1,
            conditionRequirement: 'AND',
            conditionLogic: '',
            conditions: builtConditions,
            tableKey: this.tableKey,
            keyId: this._currentBPId
        };

        saveRuleWithConditions({ ruleData: JSON.stringify(payload) })
            .then(() => {
                this.showToast(LABEL_TOAST_SUCCESS, LABEL_MSG_CREATED, 'success');
                this.loadDecisionTable();
                this._notifyDataChanged();
            })
            .catch(err => {
                this.isLoading = false;
                this.showToast(LABEL_TOAST_ERROR, err.body?.message || err.message || 'Cannot create Decision Table', 'error');
            });
    }

    /**
     * Check label có nằm trong danh sách cột default (locked) không
     */
    _isDefaultColumn(label) {
        const allDefaults = [
            ...(this.defaultConditionColumns || []),
            ...(this.defaultActionColumns || [])
        ];
        return allDefaults.includes(label);
    }

    /**
     * Xoá toàn bộ Decision Table cho BP hiện tại — confirm trước.
     * Chỉ áp dụng MDM, chưa sync Live.
     */
    async handleClearAllRules() {
        if (!this._currentBPId) return;
        if (this.originalRows.length === 0) {
            this.showToast(LABEL_TOAST_SUCCESS, 'Table is already empty', 'info');
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: LABEL_CONFIRM_CLEAR_MSG,
            variant: 'header',
            label: LABEL_CONFIRM_CLEAR_TITLE,
            theme: 'warning'
        });
        if (!confirmed) return;

        this.isLoading = true;
        deleteAllRulesByBP({ businessProcessId: this._currentBPId, tableKey: this.tableKey })
            .then(count => {
                this.showToast(LABEL_TOAST_SUCCESS, LABEL_MSG_CLEARED.replace('{0}', count), 'success');
                this.selectedRowId = null;
                this.selectedColKey = null;
                this.selectedColGroup = null;
                this.loadDecisionTable();
                this._notifyDataChanged();
            })
            .catch(err => {
                this.showToast(LABEL_TOAST_ERROR, err.body?.message || err.message || 'Cannot clear table', 'error');
            })
            .finally(() => { this.isLoading = false; });
    }
}