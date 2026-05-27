/**
 * @description Thin wrapper for Stage Transition Decision Table.
 *              Handles item setter (leaf node detection, businessProcessId extraction),
 *              loads dropdown options for stage / action button / queue / user group
 *              and passes dropdownHints to the generic fecDecisionEngineView core.
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMDMStageOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMStageOptions';
import getMDMActionButtonOptions from '@salesforce/apex/FEC_BusinessProcessService.getMDMActionButtonOptions';
import getQueueOptions from '@salesforce/apex/FEC_BusinessProcessService.getQueueOptions';
import getUserGroupOptions from '@salesforce/apex/FEC_MasterDataSettingController.getUserGroupOptions';

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
                this._loadAllDropdowns();
            }
        }
    }
    _item;

    @track _businessProcessId = null;
    @track _selectedBPLabel = '';
    @track _showLeafMessage = false;
    @track _dropdownHints = {};

    // Default columns required by the engine — locked, can't be deleted
    _defaultConditionColumns = ['Current Stage'];
    _defaultActionColumns = ['Available Decisions', 'Next Stage', 'Next Queue', 'Team User Group'];

    _suggestedConditionColumns = ['Current Stage'];
    _suggestedActionColumns = ['Next Stage', 'Next Queue', 'Available Decisions', 'Team User Group'];

    connectedCallback() {
        this._boundRefreshHandler = () => { this._loadAllDropdowns(); };
        window.addEventListener('refreshall', this._boundRefreshHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('refreshall', this._boundRefreshHandler);
    }

    /** Public method: parent can call to force reload all dropdown options */
    @api
    refreshStageOptions() {
        if (this._businessProcessId) {
            this._loadAllDropdowns();
        }
    }

    _loadAllDropdowns() {
        Promise.all([
            getMDMStageOptions({ businessProcessId: this._businessProcessId }),
            getMDMActionButtonOptions(),
            getQueueOptions(),
            getUserGroupOptions()
        ])
            .then(([stageOpts, actionOpts, queueOpts, userGroupOpts]) => {
                this._dropdownHints = {
                    'Previous Stage': stageOpts || [],
                    'Current Stage': stageOpts || [],
                    'Next Stage': stageOpts || [],
                    'Available Decisions': actionOpts || [],
                    'Action Button': actionOpts || [],
                    'Next Queue': queueOpts || [],
                    'Team User Group': userGroupOpts || []
                };
            })
            .catch(err => {
                this._dropdownHints = {};
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Lỗi',
                    message: err.body?.message || err.message || 'Không thể tải dropdown options',
                    variant: 'error'
                }));
            });
    }
}