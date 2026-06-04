import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLiveChannels from '@salesforce/apex/FEC_LiveDataViewController.getLiveChannels';
import getLiveCaseChannels from '@salesforce/apex/FEC_LiveDataViewController.getLiveCaseChannels';
import getLiveAdditionalFields from '@salesforce/apex/FEC_LiveDataViewController.getLiveAdditionalFields';
import getLiveFieldListValues from '@salesforce/apex/FEC_LiveDataViewController.getLiveFieldListValues';
import {
    FIELD_NAME,
    FIELD_CHANNEL_ID,
    FIELD_CHANNEL_VN_NAME,
    FIELD_CHANNEL_STATUS,
    FIELD_CODE,
    FIELD_SELF_SERVICE_FLAG,
    FIELD_PROCESS_CHANGE_STATUS,
    FIELD_FEC_UNIQUE_ID,
    FIELD_FEC_TYPE,
    FIELD_FIELD_STATUS,
    FIELD_FIELD_MANDATORY,
    FIELD_ORDER,
    FIELD_NAME_VN
} from 'c/fecConstants';
import LABEL_COL_NAME from '@salesforce/label/c.FEC_Col_Name';
import LABEL_COL_CHANNEL_ID from '@salesforce/label/c.FEC_Col_Channel_ID';
import LABEL_COL_CHANNEL_VN_NAME from '@salesforce/label/c.FEC_Col_Channel_VN_Name';
import LABEL_COL_CHANNEL_STATUS from '@salesforce/label/c.FEC_Col_Channel_Status';
import LABEL_UNIQUE_ID from '@salesforce/label/c.FEC_Label_Unique_ID';
import LABEL_TYPE from '@salesforce/label/c.FEC_Label_Type';
import LABEL_FIELD_STATUS from '@salesforce/label/c.FEC_Label_Field_Status';
import LABEL_MANDATORY from '@salesforce/label/c.FEC_Label_Mandatory';
import LABEL_PROCESS_STATUS from '@salesforce/label/c.FEC_Label_Process_Status';

const CHANNEL_COLUMNS = [
    { label: LABEL_COL_NAME, fieldName: FIELD_NAME, type: 'text', sortable: true },
    { label: LABEL_COL_CHANNEL_ID, fieldName: FIELD_CHANNEL_ID, type: 'text', sortable: true },
    { label: LABEL_COL_CHANNEL_VN_NAME, fieldName: FIELD_CHANNEL_VN_NAME, type: 'text', sortable: true },
    { label: LABEL_COL_CHANNEL_STATUS, fieldName: FIELD_CHANNEL_STATUS, type: 'boolean', sortable: true }
];

const CASE_CHANNEL_COLUMNS = [
    { label: LABEL_COL_NAME, fieldName: FIELD_NAME, type: 'text', sortable: true },
    { label: 'Code', fieldName: FIELD_CODE, type: 'text', sortable: true },
    { label: LABEL_COL_CHANNEL_STATUS, fieldName: FIELD_CHANNEL_STATUS, type: 'boolean', sortable: true },
    { label: 'Self-Service Flag', fieldName: FIELD_SELF_SERVICE_FLAG, type: 'boolean', sortable: true },
    { label: LABEL_PROCESS_STATUS, fieldName: FIELD_PROCESS_CHANGE_STATUS, type: 'text', sortable: true }
];

const ADDITIONAL_FIELD_COLUMNS = [
    { label: LABEL_UNIQUE_ID, fieldName: FIELD_FEC_UNIQUE_ID, type: 'text', sortable: true },
    { label: LABEL_COL_NAME, fieldName: FIELD_NAME, type: 'text', sortable: true },
    { label: LABEL_TYPE, fieldName: FIELD_FEC_TYPE, type: 'text', sortable: true },
    { label: LABEL_FIELD_STATUS, fieldName: FIELD_FIELD_STATUS, type: 'boolean', sortable: true },
    { label: LABEL_MANDATORY, fieldName: FIELD_FIELD_MANDATORY, type: 'boolean', sortable: true },
    { label: LABEL_PROCESS_STATUS, fieldName: FIELD_PROCESS_CHANGE_STATUS, type: 'text', sortable: true }
];

const FIELD_LIST_VALUE_COLUMNS = [
    { label: LABEL_COL_NAME, fieldName: FIELD_NAME, type: 'text', sortable: true },
    { label: 'Code', fieldName: FIELD_CODE, type: 'text', sortable: true },
    { label: 'Vietnamese Name', fieldName: FIELD_NAME_VN, type: 'text', sortable: true },
    { label: 'Order', fieldName: FIELD_ORDER, type: 'number', sortable: true }
];

export default class FecLiveMasterData extends LightningElement {
    selectedItem = {};

    channelColumns = CHANNEL_COLUMNS;
    caseChannelColumns = CASE_CHANNEL_COLUMNS;
    channels = [];
    caseChannels = [];
    isLoadingChannels = true;
    isLoadingCaseChannels = true;

    additionalFieldColumns = ADDITIONAL_FIELD_COLUMNS;
    fieldListValueColumns = FIELD_LIST_VALUE_COLUMNS;
    additionalFields = [];
    fieldListValues = [];
    selectedFieldId = null;
    selectedFieldName = '';
    isLoadingFields = true;
    isLoadingListValues = false;

    handleItemSelect(event) {
        this.selectedItem = (event.detail && event.detail.name) ? event.detail : {};
    }

    handleRefreshTree() {
        const treeComp = this.template.querySelector('c-fec-live-noc-tree');
        if (treeComp) treeComp.refreshTreeData();
    }

    @wire(getLiveChannels)
    wiredChannels({ data, error }) {
        this.isLoadingChannels = false;
        if (data) this.channels = data;
        else if (error) { this.channels = []; this.showErrorToast(error.body?.message || error.message || 'Error loading channels'); }
    }

    @wire(getLiveCaseChannels)
    wiredCaseChannels({ data, error }) {
        this.isLoadingCaseChannels = false;
        if (data) this.caseChannels = data;
        else if (error) { this.caseChannels = []; this.showErrorToast(error.body?.message || error.message || 'Error loading case channels'); }
    }

    @wire(getLiveAdditionalFields)
    wiredAdditionalFields({ data, error }) {
        this.isLoadingFields = false;
        if (data) this.additionalFields = data;
        else if (error) { this.additionalFields = []; this.showErrorToast(error.body?.message || error.message || 'Error loading fields'); }
    }

    handleFieldRowSelect(event) {
        const selectedRows = event.detail.selectedRows;
        if (!selectedRows || selectedRows.length === 0) { this.selectedFieldId = null; this.fieldListValues = []; return; }
        const row = selectedRows[0];
        if (!row || !row.Id || row.Id === this.selectedFieldId) return;
        this.selectedFieldId = row.Id;
        this.selectedFieldName = row[FIELD_NAME] || '';
        this.fieldListValues = [];
        this.isLoadingListValues = true;
        getLiveFieldListValues({ fieldId: row.Id })
            .then(result => { this.fieldListValues = result || []; })
            .catch(error => { this.fieldListValues = []; this.showErrorToast(error.body?.message || error.message || 'Error'); })
            .finally(() => { this.isLoadingListValues = false; });
    }

    get hasChannels() { return this.channels && this.channels.length > 0; }
    get hasCaseChannels() { return this.caseChannels && this.caseChannels.length > 0; }
    get hasAdditionalFields() { return this.additionalFields && this.additionalFields.length > 0; }
    get hasFieldListValues() { return this.fieldListValues && this.fieldListValues.length > 0; }
    get showFieldListValuesSection() { return this.selectedFieldId != null; }
    get fieldListValuesTitle() { return this.selectedFieldName ? `List Values: ${this.selectedFieldName}` : 'List Values'; }

    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message, variant: 'error' }));
    }
}