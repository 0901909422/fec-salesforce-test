import { api, LightningElement, wire, track } from 'lwc';
import getLiveCaseStagesByBP from '@salesforce/apex/FEC_LiveDataViewController.getLiveCaseStagesByBP';
import getLiveMasterDataSettings from '@salesforce/apex/FEC_LiveDataViewController.getLiveMasterDataSettings';
import getLiveStageChangeRules from '@salesforce/apex/FEC_LiveDataViewController.getLiveStageChangeRules';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LABEL_TAB_PROPERTY_CONFIGURATION from '@salesforce/label/c.FEC_Tab_Property_Configuration';
import LABEL_TAB_FRAUD_INTEGRATION from '@salesforce/label/c.FEC_Tab_Fraud_Integration_Mapping';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LABEL_COL_STATUS from '@salesforce/label/c.FEC_Col_Status';
import LABEL_LABEL_READONLY from '@salesforce/label/c.FEC_Label_ReadOnly';
import LABEL_LABEL_MANDATORY from '@salesforce/label/c.FEC_Label_Mandatory';
import LABEL_COL_ORDER from '@salesforce/label/c.FEC_Col_Order';

// Node types that have a Business Process context (BP level or below)
const BP_LEVEL_TYPES = new Set(['Business Process', 'Category', 'Sub Category', 'Sub Code']);

const PROPERTY_COLUMNS = [
    { label: 'Field API Name', fieldName: 'FEC_Field_API_Name__c', type: 'text', sortable: true },
    { label: 'Field Label Name', fieldName: 'FEC_Field_Label_Name__c', type: 'text', sortable: true },
    { label: 'Field Object Name', fieldName: 'FEC_Field_Object_Name__c', type: 'text', sortable: true },
    { label: 'Index', fieldName: 'Name', type: 'text', sortable: true },
    { label: 'Section', fieldName: 'FEC_Section__c', type: 'text', sortable: true },
    { label: 'Sub Section', fieldName: 'FEC_Sub_Section__c', type: 'text', sortable: true },
    { label: 'Sub Section Order', fieldName: 'FEC_Sub_Section_Order__c', type: 'number', sortable: true },
    { label: 'Sub Section Layout', fieldName: 'FEC_Sub_Section_Layout__c', type: 'number' },
    { label: 'Sub Section Field Layout', fieldName: 'FEC_Sub_Section_Field_Layout__c', type: 'number' },
    { label: 'Channel', fieldName: 'FEC_Channel__c', type: 'text', sortable: true },
    { label: 'Applicable Role', fieldName: 'FEC_Applicable_Role__c', type: 'text', sortable: true },
    { label: LABEL_COL_STATUS, fieldName: 'FEC_Field_Status__c', type: 'boolean' },
    { label: LABEL_LABEL_READONLY, fieldName: 'FEC_Field_ReadOnly__c', type: 'boolean' },
    { label: LABEL_LABEL_MANDATORY, fieldName: 'FEC_Field_Mandatory__c', type: 'boolean' },
    { label: 'Editable', fieldName: 'FEC_Field_Editable__c', type: 'boolean' },
    { label: 'Masking', fieldName: 'FEC_Field_Masking__c', type: 'boolean' },
    { label: 'Masking Type', fieldName: 'FEC_Masking_Type__c', type: 'text' },
    { label: 'Reverted', fieldName: 'FEC_Field_Reverted__c', type: 'boolean' },
    { label: 'Editable Role', fieldName: 'FEC_Editable_Role__c', type: 'text' },
    { label: LABEL_COL_ORDER, fieldName: 'FEC_Field_Order_Display__c', type: 'number', sortable: true }
];

const FRAUD_COLUMNS = [
    { label: 'Field API Name', fieldName: 'FEC_Field_API_Name__c', type: 'text', sortable: true },
    { label: 'Field Label Name', fieldName: 'FEC_Field_Label_Name__c', type: 'text', sortable: true },
    { label: 'Field Object Name', fieldName: 'FEC_Field_Object_Name__c', type: 'text', sortable: true },
    { label: 'Integration Mapping', fieldName: 'integrationMappingName', type: 'text' },
    { label: 'Section', fieldName: 'FEC_Section__c', type: 'text', sortable: true },
    { label: 'Sub Section', fieldName: 'FEC_Sub_Section__c', type: 'text', sortable: true },
    { label: 'Sub Section Order', fieldName: 'FEC_Sub_Section_Order__c', type: 'number', sortable: true },
    { label: 'Channel', fieldName: 'FEC_Channel__c', type: 'text', sortable: true },
    { label: 'Applicable Role', fieldName: 'FEC_Applicable_Role__c', type: 'text', sortable: true },
    { label: LABEL_COL_STATUS, fieldName: 'FEC_Field_Status__c', type: 'boolean' },
    { label: LABEL_LABEL_READONLY, fieldName: 'FEC_Field_ReadOnly__c', type: 'boolean' },
    { label: LABEL_LABEL_MANDATORY, fieldName: 'FEC_Field_Mandatory__c', type: 'boolean' },
    { label: 'Editable', fieldName: 'FEC_Field_Editable__c', type: 'boolean' },
    { label: 'Masking', fieldName: 'FEC_Field_Masking__c', type: 'boolean' },
    { label: 'Masking Type', fieldName: 'FEC_Masking_Type__c', type: 'text' },
    { label: 'Reverted', fieldName: 'FEC_Field_Reverted__c', type: 'boolean' },
    { label: 'Editable Role', fieldName: 'FEC_Editable_Role__c', type: 'text' },
    { label: LABEL_COL_ORDER, fieldName: 'FEC_Field_Order_Display__c', type: 'number', sortable: true }
];

const DECISION_TABLE_COLUMNS = [
    { label: 'Previous Stage', fieldName: 'previousStage', type: 'text', sortable: true },
    { label: 'Action/Button', fieldName: 'actionButton', type: 'text', sortable: true },
    { label: 'Next Stage', fieldName: 'nextStage', type: 'text', sortable: true },
    { label: 'Next Queue', fieldName: 'nextQueue', type: 'text' },
    { label: 'Transition Group', fieldName: 'teamUserGroup', type: 'text' }
];

/**
 * @description Read-only component displaying stage tabs and sub-tabs
 * (Property Configuration, Fraud Integration Mapping, Decision Table Stage)
 * for the selected NOC tree node.
 */
export default class FecLiveMasterDataSetting extends LightningElement {
    // Labels
    labelTabPropertyConfig = LABEL_TAB_PROPERTY_CONFIGURATION;
    labelTabFraudIntegration = LABEL_TAB_FRAUD_INTEGRATION;
    labelTabDecisionTable = 'Decision Table Stage';

    // Column definitions
    propertyColumns = PROPERTY_COLUMNS;
    fraudColumns = FRAUD_COLUMNS;
    decisionTableColumns = DECISION_TABLE_COLUMNS;

    // State
    @track stages = [];
    @track propertyData = [];
    @track fraudData = [];
    @track decisionTableData = [];
    isLoadingStages = false;
    isLoadingProperty = false;
    isLoadingFraud = false;
    isLoadingDecisionTable = false;
    selectedStageId;
    _item;

    @api
    get item() {
        return this._item;
    }
    set item(value) {
        this._item = value;
        // Reset state when item changes
        this.selectedStageId = undefined;
        this.propertyData = [];
        this.fraudData = [];
        this.stages = [];
    }

    /**
     * @description Extract Business Process ID from the selected item.
     * For BP-level nodes, idType IS the BP ID.
     * For nodes below BP (CAT, SCAT, SC), we extract BP ID from the name.
     * Name format: BP_<ptId>_<bpId>, CAT_<ptId>_<bpId>_<catId>, etc.
     */
    get bpId() {
        if (!this._item || !this._item.name) return undefined;
        const itemType = this._item.type;
        if (!BP_LEVEL_TYPES.has(itemType)) return undefined;

        const name = this._item.name;
        const parts = name.split('_');
        // BP_<ptId>_<bpId> → parts[0]=BP, parts[1]=ptId, parts[2]=bpId
        // CAT_<ptId>_<bpId>_<catId> → parts[0]=CAT, parts[1]=ptId, parts[2]=bpId
        // SCAT_<ptId>_<bpId>_<catId>_<scatId>
        // SC_<ptId>_<bpId>_<catId>_<scatId>_<scodeId>
        if (parts.length >= 3) {
            return parts[2];
        }
        // Fallback: for BP type, idType is the BP record ID
        if (itemType === 'Business Process') {
            return this._item.idType;
        }
        return undefined;
    }

    /**
     * @description The NOC record ID for the selected item.
     * Used to query Master Data Settings.
     */
    get nocId() {
        if (!this._item) return undefined;
        return this._item.id;
    }

    /**
     * @description Whether stage tabs should be shown.
     * Only for BP-level nodes and below.
     */
    get showStageTabs() {
        return this._item && this._item.type && BP_LEVEL_TYPES.has(this._item.type);
    }

    /**
     * @description Whether to show the empty state (Product Type level or no item).
     */
    get showEmptyState() {
        return !this._item || !this._item.name || !this.showStageTabs;
    }

    get hasStages() {
        return this.stages && this.stages.length > 0;
    }

    get hasPropertyData() {
        return this.propertyData && this.propertyData.length > 0;
    }

    get hasFraudData() {
        return this.fraudData && this.fraudData.length > 0;
    }

    get hasDecisionTableData() {
        return this.decisionTableData && this.decisionTableData.length > 0;
    }

    // ── Wire Adapters ─────────────────────────────────────────────────

    @wire(getLiveCaseStagesByBP, { businessProcessId: '$bpId' })
    wiredStages({ data, error }) {
        this.isLoadingStages = false;
        if (data) {
            this.stages = data;
            // Auto-select first stage
            if (data.length > 0 && !this.selectedStageId) {
                this.selectedStageId = data[0].value;
            }
        } else if (error) {
            this.stages = [];
            this.showErrorToast(error.body?.message || error.message || 'Failed to load stages');
        }
    }

    @wire(getLiveMasterDataSettings, {
        nocId: '$nocId',
        stageId: '$selectedStageId',
        isIntegration: false
    })
    wiredPropertyConfig({ data, error }) {
        this.isLoadingProperty = false;
        if (data) {
            this.propertyData = data;
        } else if (error) {
            this.propertyData = [];
            this.showErrorToast(error.body?.message || error.message || 'Failed to load property configuration');
        }
    }

    @wire(getLiveMasterDataSettings, {
        nocId: '$nocId',
        stageId: '$selectedStageId',
        isIntegration: true
    })
    wiredFraudMapping({ data, error }) {
        this.isLoadingFraud = false;
        if (data) {
            this.fraudData = data.map(row => ({
                ...row,
                integrationMappingName: row.FEC_Data_Integration_Mapping__r
                    ? row.FEC_Data_Integration_Mapping__r.Name
                    : ''
            }));
        } else if (error) {
            this.fraudData = [];
            this.showErrorToast(error.body?.message || error.message || 'Failed to load fraud mapping');
        }
    }

    @wire(getLiveStageChangeRules, { businessProcessId: '$bpId' })
    wiredDecisionTable({ data, error }) {
        this.isLoadingDecisionTable = false;
        if (data) {
            this.decisionTableData = data.map(row => ({
                ...row,
                id: row.rowId
            }));
        } else if (error) {
            this.decisionTableData = [];
            this.showErrorToast(error.body?.message || error.message || 'Failed to load decision table');
        }
    }

    // ── Event Handlers ────────────────────────────────────────────────

    handleStageActive(event) {
        this.selectedStageId = event.target.value;
        // Reset sub-tab data when stage changes
        this.propertyData = [];
        this.fraudData = [];
        this.isLoadingProperty = true;
        this.isLoadingFraud = true;
    }

    // ── Utility ───────────────────────────────────────────────────────

    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: LABEL_TOAST_ERROR,
                message: message,
                variant: 'error'
            })
        );
    }
}