import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import getConfigsByNoc from '@salesforce/apex/FEC_HoldCaseConfigController.getConfigsByNoc';
import saveConfig from '@salesforce/apex/FEC_HoldCaseConfigController.saveConfig';
import deleteConfig from '@salesforce/apex/FEC_HoldCaseConfigController.deleteConfig';
import getNfuCodes from '@salesforce/apex/FEC_HoldCaseConfigController.getNfuCodes';
import getCaseStatusOptions from '@salesforce/apex/FEC_HoldCaseConfigController.getCaseStatusOptions';
import getChannelNameOptions from '@salesforce/apex/FEC_HoldCaseConfigController.getChannelNameOptions';

// Custom Labels
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_BUTTON_EDIT from '@salesforce/label/c.FEC_Edit';
import LABEL_BUTTON_DELETE from '@salesforce/label/c.FEC_Button_Delete';
import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_CONFIRM from '@salesforce/label/c.FEC_Button_Confirm';
import LABEL_BUTTON_DISCARD from '@salesforce/label/c.FEC_Button_Discard';
import LABEL_HOLD_CASE_TYPE from '@salesforce/label/c.FEC_Label_HoldCaseType';
import LABEL_STATUS from '@salesforce/label/c.FEC_Label_Status';
import LABEL_ACTIVE from '@salesforce/label/c.FEC_Label_Active';
import LABEL_CHANNEL from '@salesforce/label/c.FEC_Label_Channel';
import LABEL_CHANNEL_REQUIRED from '@salesforce/label/c.FEC_Label_Channel_Required';
import LABEL_NFU_CODE from '@salesforce/label/c.FEC_Label_NFU_Code';
import LABEL_NFU_CODES from '@salesforce/label/c.FEC_Label_NFU_Codes';
import LABEL_NFU_REASON from '@salesforce/label/c.FEC_Label_NFU_Reason';
import LABEL_CURRENT_STATUS from '@salesforce/label/c.FEC_Label_Current_Status';
import LABEL_CHANGED_STATUS from '@salesforce/label/c.FEC_Label_Changed_Status';
import LABEL_NO_NODE from '@salesforce/label/c.FEC_HoldCase_No_Node_Selected';
import LABEL_NO_NFU_ADDED from '@salesforce/label/c.FEC_HoldCase_No_NFU_Added';
import LABEL_ADD_NFU_BUTTON from '@salesforce/label/c.FEC_HoldCase_Add_NFU_Button';
import LABEL_NFU_MODAL_TITLE from '@salesforce/label/c.FEC_HoldCase_NFU_Modal_Title';
import LABEL_DELETE_CONFIRM from '@salesforce/label/c.FEC_HoldCase_Delete_Confirm';
import LABEL_DELETE_NOT_ALLOWED from '@salesforce/label/c.FEC_HoldCase_Delete_Not_Allowed';
import LABEL_VALIDATION_REQUIRED from '@salesforce/label/c.FEC_HoldCase_Validation_Required';
import LABEL_VALIDATION_CHANNEL from '@salesforce/label/c.FEC_HoldCase_Validation_Channel';
import LABEL_VALIDATION_NFU from '@salesforce/label/c.FEC_HoldCase_Validation_NFU';
import LABEL_SAVE_SUCCESS from '@salesforce/label/c.FEC_HoldCase_Save_Success';
import LABEL_DELETE_SUCCESS from '@salesforce/label/c.FEC_HoldCase_Delete_Success';
import LABEL_SEARCH_CHANNEL from '@salesforce/label/c.FEC_HoldCase_Search_Channel';
import LABEL_HISTORY_SECTION from '@salesforce/label/c.FEC_HoldCase_History_Section';
import LABEL_TOAST_SUCCESS from '@salesforce/label/c.FEC_Toast_Success';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';

const TYPE_OPTIONS = [
    { label: 'Auto', value: 'Auto' },
    { label: 'Manual', value: 'Manual' }
];

const STATUS_NEW = 'New';

export default class FecHoldCaseConfigList extends LightningElement {
    @api stageId;

    @track configList = [];
    @track formData = {};
    @track nfuCodesMaster = [];
    @track selectedNfuCodes = [];
    @track caseStatusOptions = [];
    @track channelOptions = [];
    @track selectedChannels = [];
    channelSearchTerm = '';
    isChannelDropdownOpen = false;
    isLoading = false;
    isEditing = false;   // in edit/create form
    isViewing = false;   // read-only detail after save
    editRecordId = null;
    isNfuModalOpen = false;
    wiredConfigResult;
    holdCaseTypeOptions = TYPE_OPTIONS;

    // Labels exposed to template
    labelSave = LABEL_BUTTON_SAVE;
    labelEdit = LABEL_BUTTON_EDIT;
    labelDelete = LABEL_BUTTON_DELETE;
    labelCancel = LABEL_BUTTON_CANCEL;
    labelConfirm = LABEL_BUTTON_CONFIRM;
    labelDiscard = LABEL_BUTTON_DISCARD;
    labelHoldCaseType = LABEL_HOLD_CASE_TYPE;
    labelStatus = LABEL_STATUS;
    labelActive = LABEL_ACTIVE;
    labelChannel = LABEL_CHANNEL;
    labelChannelRequired = LABEL_CHANNEL_REQUIRED;
    labelNfuCode = LABEL_NFU_CODE;
    labelNfuCodes = LABEL_NFU_CODES;
    labelNfuReason = LABEL_NFU_REASON;
    labelCurrentStatus = LABEL_CURRENT_STATUS;
    labelChangedStatus = LABEL_CHANGED_STATUS;
    labelNoNode = LABEL_NO_NODE;
    labelNoNfuAdded = LABEL_NO_NFU_ADDED;
    labelAddNfuButton = LABEL_ADD_NFU_BUTTON;
    labelNfuModalTitle = LABEL_NFU_MODAL_TITLE;
    labelSearchChannel = LABEL_SEARCH_CHANNEL;
    labelHistorySection = LABEL_HISTORY_SECTION;

    // Track nocId internally so we can reset state when it changes
    _nocId;
    @api
    get nocId() { return this._nocId; }
    set nocId(value) {
        const changed = this._nocId !== value;
        this._nocId = value;
        if (changed) {
            // Reset UI state when parent switches node → avoids stale data
            this._resetStateForNewNode();
        }
    }

    _resetStateForNewNode() {
        this.isEditing = false;
        this.isViewing = false;
        this.editRecordId = null;
        this.formData = {};
        this.selectedNfuCodes = [];
        this.selectedChannels = [];
        this.channelSearchTerm = '';
    }

    // ── Getters ──
    get hasNocId() { return !!this._nocId; }
    get hasConfigs() { return this.configList && this.configList.length > 0; }
    get showEmptyState() { return !this.isViewing && !this.isEditing && !this.hasConfigs; }
    get isManual() { return this.formData.Hold_Case_Type__c === 'Manual'; }
    get isAuto() { return this.formData.Hold_Case_Type__c === 'Auto'; }
    get hasSelectedNfu() { return this.selectedNfuCodes && this.selectedNfuCodes.length > 0; }
    get hasSelectedChannels() { return this.selectedChannels && this.selectedChannels.length > 0; }
    get nfuOptions() {
        return this.nfuCodesMaster.map(n => ({ label: n.code, value: n.code }));
    }
    get nfuCodesWithSelection() {
        const selectedSet = new Set(this.selectedNfuCodes.map(n => n.code));
        return this.nfuCodesMaster.map(n => ({
            ...n,
            isSelected: selectedSet.has(n.code)
        }));
    }
    get filteredChannelOptions() {
        const selected = new Set(this.selectedChannels);
        let opts = this.channelOptions.filter(o => !selected.has(o.value));
        if (this.channelSearchTerm) {
            const key = this.channelSearchTerm.toLowerCase();
            opts = opts.filter(o => o.label.toLowerCase().includes(key));
        }
        return opts;
    }
    get activeDisplay() { return this.formData.FEC_Active__c ? 'Active' : 'Inactive'; }
    get processChangeStatusDisplay() { return this.formData.Process_Change_Status__c || '—'; }

    /**
     * Only show Delete button when current record is still New
     * (not yet synced to Live via PushMDMToLive batch)
     */
    get canDelete() {
        return this.editRecordId
            && this.formData.Process_Change_Status__c === STATUS_NEW;
    }

    // ── Wire ──
    @wire(getConfigsByNoc, { nocId: '$_nocId' })
    wiredConfigs(result) {
        this.wiredConfigResult = result;
        if (result.data) {
            this.configList = [...result.data];
            // If we have an edit record id and it still exists in fresh data, reload it (keeps view after save)
            if (this.editRecordId && this.configList.find(c => c.Id === this.editRecordId)) {
                this._loadRecordIntoForm(this.editRecordId);
                // After a save, user is in view mode by default — don't flip state if currently editing
                if (!this.isEditing) this.isViewing = true;
            } else if (this.configList.length > 0 && !this.isEditing) {
                // Auto-show first record
                this._loadRecordIntoForm(this.configList[0].Id);
                this.isViewing = true;
                this.isEditing = false;
            } else if (this.configList.length === 0) {
                // No data for this node → show empty state with Add button
                this.isEditing = false;
                this.isViewing = false;
                this.editRecordId = null;
            }
        }
    }
    @wire(getNfuCodes)
    wiredNfu({ data }) { if (data) this.nfuCodesMaster = data; }
    @wire(getCaseStatusOptions)
    wiredStatus({ data }) { if (data) this.caseStatusOptions = data; }
    @wire(getChannelNameOptions)
    wiredChannels({ data }) { if (data) this.channelOptions = data; }

    // ── Actions ──
    handleNew() {
        this.editRecordId = null;
        this.formData = {
            Hold_Case_Type__c: 'Manual',
            FEC_Active__c: true,
            FEC_Channel__c: '',
            FEC_NFU_Code__c: '',
            FEC_Current_Status__c: '',
            FEC_Changed_Status__c: '',
            Process_Change_Status__c: STATUS_NEW
        };
        this.selectedNfuCodes = [];
        this.selectedChannels = [];
        this.isViewing = false;
        this.isEditing = true;
    }

    handleEditFromView() {
        this.isViewing = false;
        this.isEditing = true;
    }

    _loadRecordIntoForm(id) {
        const rec = this.configList.find(c => c.Id === id);
        if (!rec) return;
        this.editRecordId = id;
        this.formData = {
            Name: rec.Name || '',
            Hold_Case_Type__c: rec.Hold_Case_Type__c || 'Manual',
            FEC_Active__c: rec.FEC_Active__c || false,
            FEC_Channel__c: rec.FEC_Channel__c || '',
            FEC_NFU_Code__c: rec.FEC_NFU_Code__c || '',
            FEC_Current_Status__c: rec.FEC_Current_Status__c || '',
            FEC_Changed_Status__c: rec.FEC_Changed_Status__c || '',
            Process_Change_Status__c: rec.Process_Change_Status__c || ''
        };
        const chStr = rec.FEC_Channel__c || '';
        this.selectedChannels = chStr ? chStr.split(';').map(s => s.trim()).filter(s => s) : [];
        const nfuStr = rec.FEC_NFU_Code__c || '';
        if (nfuStr) {
            this.selectedNfuCodes = nfuStr.split(';').map(code => {
                const trimmed = code.trim();
                const master = this.nfuCodesMaster.find(m => m.code === trimmed);
                return { code: trimmed, reasonVN: master ? master.reasonVN : '' };
            }).filter(n => n.code);
        } else {
            this.selectedNfuCodes = [];
        }
    }

    async handleDelete() {
        if (!this.canDelete) {
            this.showToast(LABEL_TOAST_ERROR, LABEL_DELETE_NOT_ALLOWED, 'error');
            return;
        }
        const confirmed = await LightningConfirm.open({
            message: LABEL_DELETE_CONFIRM,
            variant: 'header',
            label: LABEL_BUTTON_DELETE,
            theme: 'warning'
        });
        if (!confirmed) return;
        this.isLoading = true;
        try {
            await deleteConfig({ configId: this.editRecordId });
            this.showToast(LABEL_TOAST_SUCCESS, LABEL_DELETE_SUCCESS, 'success');
            this.editRecordId = null;
            this.isEditing = false;
            this.isViewing = false;
            await refreshApex(this.wiredConfigResult);
        } catch (e) {
            this.showToast(LABEL_TOAST_ERROR, e.body?.message || e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Form ──
    handleFormChange(event) {
        const field = event.target.dataset.field;
        const value = (event.target.type === 'checkbox' || event.target.type === 'toggle')
            ? event.target.checked : event.target.value;
        this.formData = { ...this.formData, [field]: value };
    }

    handleChannelSearch(event) {
        this.channelSearchTerm = event.target.value;
        this.isChannelDropdownOpen = true;
    }
    handleChannelFocus() { this.isChannelDropdownOpen = true; }
    handleChannelBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.isChannelDropdownOpen = false; }, 200);
    }
    handleSelectChannel(event) {
        const val = event.currentTarget.dataset.value;
        if (val && !this.selectedChannels.includes(val)) {
            this.selectedChannels = [...this.selectedChannels, val];
        }
        this.channelSearchTerm = '';
        this.isChannelDropdownOpen = false;
    }
    handleRemoveChannel(event) {
        const val = event.detail.name || event.currentTarget.name;
        this.selectedChannels = this.selectedChannels.filter(c => c !== val);
    }

    handleDiscard() {
        if (this.editRecordId) {
            this._loadRecordIntoForm(this.editRecordId);
            this.isEditing = false;
            this.isViewing = true;
        } else if (this.configList.length > 0) {
            this._loadRecordIntoForm(this.configList[0].Id);
            this.isEditing = false;
            this.isViewing = true;
        } else {
            // No data exists → return to empty state
            this.isEditing = false;
            this.isViewing = false;
            this.formData = {};
            this.selectedNfuCodes = [];
            this.selectedChannels = [];
        }
    }

    /**
     * Validate all required fields based on Hold Case Type
     * Returns {valid: boolean, message: string}
     */
    _validateForm() {
        // 1. Native lightning-input / lightning-combobox validity
        const inputs = [
            ...this.template.querySelectorAll('lightning-combobox'),
            ...this.template.querySelectorAll('lightning-input')
        ];
        let allValid = true;
        inputs.forEach(el => {
            if (typeof el.reportValidity === 'function') {
                if (!el.reportValidity()) allValid = false;
            }
        });
        if (!allValid) {
            return { valid: false, message: LABEL_VALIDATION_REQUIRED };
        }

        // 2. Hold Case Type required
        if (!this.formData.Hold_Case_Type__c) {
            return { valid: false, message: LABEL_VALIDATION_REQUIRED };
        }

        // 3. Channel required
        if (!this.selectedChannels || this.selectedChannels.length === 0) {
            return { valid: false, message: LABEL_VALIDATION_CHANNEL };
        }

        // 4. Type-specific required fields
        if (this.isManual) {
            if (!this.selectedNfuCodes || this.selectedNfuCodes.length === 0) {
                return { valid: false, message: LABEL_VALIDATION_NFU };
            }
        } else if (this.isAuto) {
            if (!this.formData.FEC_NFU_Code__c
                || !this.formData.FEC_Current_Status__c
                || !this.formData.FEC_Changed_Status__c) {
                return { valid: false, message: LABEL_VALIDATION_REQUIRED };
            }
        }
        return { valid: true, message: '' };
    }

    async handleSave() {
        const validation = this._validateForm();
        if (!validation.valid) {
            this.showToast(LABEL_TOAST_ERROR, validation.message, 'error');
            return;
        }
        this.isLoading = true;
        try {
            const record = { sobjectType: 'FEC_MDM_Hold_Case_Config__c' };
            if (this.editRecordId) record.Id = this.editRecordId;
            record.Hold_Case_Type__c = this.formData.Hold_Case_Type__c || null;
            record.FEC_Active__c = this.formData.FEC_Active__c;
            record.FEC_Channel__c = this.selectedChannels.join(';') || null;
            record.FEC_Case_Stage__c = this.stageId || null;
            record.FEC_Nature_of_Case__c = this._nocId;
            if (this.isManual) {
                record.FEC_NFU_Code__c = this.selectedNfuCodes.map(n => n.code).join(';') || null;
                record.FEC_Current_Status__c = null;
                record.FEC_Changed_Status__c = null;
            } else {
                record.FEC_NFU_Code__c = this.formData.FEC_NFU_Code__c || null;
                record.FEC_Current_Status__c = this.formData.FEC_Current_Status__c || null;
                record.FEC_Changed_Status__c = this.formData.FEC_Changed_Status__c || null;
            }
            const savedId = await saveConfig({ config: record });
            this.showToast(LABEL_TOAST_SUCCESS, LABEL_SAVE_SUCCESS, 'success');
            // Track the saved record id so wiredConfigs can re-hydrate form after refresh
            if (savedId && typeof savedId === 'string') {
                this.editRecordId = savedId;
            }
            await refreshApex(this.wiredConfigResult);
            // After refresh, configList reflects fresh server state; _loadRecordIntoForm is called in wiredConfigs
            this.isEditing = false;
            this.isViewing = true;
            // Refresh history after save
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                const hists = this.template.querySelectorAll('c-fec-config-history');
                hists.forEach(h => { if (h && h.refreshData) h.refreshData(); });
            }, 500);
        } catch (e) {
            this.showToast(LABEL_TOAST_ERROR, e.body?.message || e.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── NFU Modal ──
    handleOpenNfuModal() { this.isNfuModalOpen = true; }
    handleCloseNfuModal() { this.isNfuModalOpen = false; }
    handleSelectNfu(event) {
        const code = event.currentTarget.dataset.code;
        const exists = this.selectedNfuCodes.find(n => n.code === code);
        if (exists) {
            this.selectedNfuCodes = this.selectedNfuCodes.filter(n => n.code !== code);
        } else {
            const master = this.nfuCodesMaster.find(m => m.code === code);
            this.selectedNfuCodes = [...this.selectedNfuCodes, { code, reasonVN: master ? master.reasonVN : '' }];
        }
    }
    handleRemoveNfu(event) {
        const code = event.currentTarget.dataset.code;
        this.selectedNfuCodes = this.selectedNfuCodes.filter(n => n.code !== code);
    }
    handleConfirmNfu() { this.isNfuModalOpen = false; }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}