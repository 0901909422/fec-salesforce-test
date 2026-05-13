import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLiveBusinessProcessOptions from '@salesforce/apex/FEC_LiveDataViewController.getLiveBusinessProcessOptions';
import getLiveDynamicDecisionTable from '@salesforce/apex/FEC_LiveDataViewController.getLiveDynamicDecisionTable';

export default class FecLiveDecisionTable extends LightningElement {
    @track bpOptions = [];
    selectedBPId = '';

    @track tableData = {
        tableId: null,
        conditionCols: [],
        actionCols: [],
        rows: []
    };
    @track originalRows = [];
    isLoading = false;
    searchFilter = '';

    // ── Wire: Load BP options for combobox ────────────────────────────
    @wire(getLiveBusinessProcessOptions)
    wiredBPOptions({ data, error }) {
        if (data) {
            this.bpOptions = data.map(item => ({
                label: item.label,
                value: item.value
            }));
        } else if (error) {
            this.bpOptions = [];
            this.showErrorToast(error.body?.message || error.message || 'Error loading Business Process options');
        }
    }

    // ── BP Selection Handler ──────────────────────────────────────────
    handleBPChange(event) {
        this.selectedBPId = event.detail.value;
        this.searchFilter = '';
        if (this.selectedBPId) {
            this.loadDecisionTable();
        } else {
            this.tableData = { tableId: null, conditionCols: [], actionCols: [], rows: [] };
            this.originalRows = [];
        }
    }

    // ── Imperative: Load Decision Table ───────────────────────────────
    loadDecisionTable() {
        this.isLoading = true;
        getLiveDynamicDecisionTable({ businessProcessId: this.selectedBPId })
            .then(result => {
                if (result) {
                    const clonedConditionCols = (result.conditionCols || []).map(c => ({ ...c }));
                    const clonedActionCols = (result.actionCols || []).map(c => ({ ...c }));
                    const clonedRows = (result.rows || []).map(r => ({
                        ...r,
                        conditionCells: (r.conditionCells || []).map(cell => ({ ...cell })),
                        actionCells: (r.actionCells || []).map(cell => ({ ...cell })),
                        allSearchableCells: (r.allSearchableCells || []).map(cell => ({ ...cell }))
                    }));

                    this.tableData = {
                        tableId: result.tableId,
                        conditionCols: clonedConditionCols,
                        actionCols: clonedActionCols,
                        rows: clonedRows
                    };
                    this.originalRows = [...clonedRows];
                } else {
                    this.tableData = { tableId: null, conditionCols: [], actionCols: [], rows: [] };
                    this.originalRows = [];
                }
            })
            .catch(error => {
                this.tableData = { tableId: null, conditionCols: [], actionCols: [], rows: [] };
                this.originalRows = [];
                this.showErrorToast(error.body?.message || error.message || 'Error loading decision table');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ── Search Filter ─────────────────────────────────────────────────
    handleSearchChange(event) {
        this.searchFilter = event.target.value.toLowerCase();
        this.applySearchFilter();
    }

    applySearchFilter() {
        if (!this.searchFilter.trim()) {
            this.tableData = { ...this.tableData, rows: [...this.originalRows] };
            return;
        }
        const filtered = this.originalRows.filter(row => {
            return (row.allSearchableCells || []).some(cell =>
                cell.value && cell.value.toLowerCase().includes(this.searchFilter)
            );
        });
        this.tableData = { ...this.tableData, rows: filtered };
    }

    // ── Computed Getters ──────────────────────────────────────────────
    get hasDecisionData() {
        return this.originalRows.length > 0;
    }

    get displayRows() {
        return this.tableData.rows || [];
    }

    get conditionColSpan() {
        return this.tableData.conditionCols?.length || 0;
    }

    get actionColSpan() {
        return this.tableData.actionCols?.length || 0;
    }

    get hasNoSearchResults() {
        return this.searchFilter.trim().length > 0 && this.tableData.rows?.length === 0;
    }

    // ── Error Toast ───────────────────────────────────────────────────
    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        }));
    }
}