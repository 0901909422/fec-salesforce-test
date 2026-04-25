/**
 * @description Thin wrapper for Stage Transition Decision Table.
 *              Handles item setter (leaf node detection, businessProcessId extraction),
 *              loads stage dropdown options via getMDMStageOptions,
 *              and passes dropdownHints to the generic fecDecisionEngineView core.
 */
import { LightningElement, api, track } from 'lwc';
import getMDMStageOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMStageOptions';

export default class FecDecisionTableStage extends LightningElement {

    @api
    get item() {
        return this._item;
    }
    set item(value) {
        this._item = value;

        if (!value) {
            this._businessProcessId = null;
            this._selectedBPLabel = '';
            this._showLeafMessage = false;
            this._dropdownHints = {};
            return;
        }

        this._selectedBPLabel = value.label || '';

        const rawType = (value.type || '').replace(/\s+/g, '');
        const nodeType = rawType || 'BusinessProcess';
        const leafTypes = new Set(['Stage', 'Category', 'SubCategory', 'SubCode']);

        if (leafTypes.has(nodeType)) {
            this._businessProcessId = null;
            this._showLeafMessage = true;
        } else {
            this._showLeafMessage = false;
            this._businessProcessId = value.idType || null;
            if (this._businessProcessId) {
                this._loadStageOptions();
            }
        }
    }
    _item;

    @track _businessProcessId = null;
    @track _selectedBPLabel = '';
    @track _showLeafMessage = false;
    @track _dropdownHints = {};
    _suggestedConditionColumns = ['Current Stage'];
    _suggestedActionColumns = ['Next Stage', 'Next Queue', 'Available Decisions', 'Team User Group'];

    connectedCallback() {
        this._boundRefreshHandler = () => { this._loadStageOptions(); };
        window.addEventListener('refreshall', this._boundRefreshHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('refreshall', this._boundRefreshHandler);
    }

    /**
     * Public method: parent can call to force reload stage options
     */
    @api
    refreshStageOptions() {
        if (this._businessProcessId) {
            this._loadStageOptions();
        }
    }

    _loadStageOptions() {
        getMDMStageOptions({ businessProcessId: this._businessProcessId })
            .then(data => {
                const stageOpts = data || [];
                this._dropdownHints = {
                    'Previous Stage': stageOpts,
                    'Current Stage': stageOpts,
                    'Next Stage': stageOpts
                };
            })
            .catch(() => {
                this._dropdownHints = {};
            });
    }
}