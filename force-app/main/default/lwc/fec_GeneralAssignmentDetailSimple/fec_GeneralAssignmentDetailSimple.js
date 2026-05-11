import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { subscribe, MessageContext } from 'lightning/messageService';
import { loadStyle } from 'lightning/platformResourceLoader';
import FEC_GA_EDIT_MODE from '@salesforce/messageChannel/FEC_GA_Edit_Mode__c';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';
import LABEL_SUCCESS from '@salesforce/label/c.FEC_GA_Save_Success';
import LABEL_SAVED from '@salesforce/label/c.FEC_GA_Saved_Message';
import LABEL_ERROR from '@salesforce/label/c.FEC_GA_Save_Error';
import LABEL_SAVE_ERROR from '@salesforce/label/c.FEC_GA_Save_Error_Message';
import LABEL_CHANNEL_REQUIRED from '@salesforce/label/c.FEC_GA_Channel_Required';
import LABEL_NAME_REQUIRED from '@salesforce/label/c.FEC_GA_Name_Required';
import getChannels from '@salesforce/apex/FEC_GeneralAssignmentController.getChannels';
import getGeneralAssignmentNames from '@salesforce/apex/FEC_GeneralAssignmentController.getGeneralAssignmentNames';
import getGACodeByName from '@salesforce/apex/FEC_GeneralAssignmentController.getGACodeByName';
import updateGeneralAssignment from '@salesforce/apex/FEC_GeneralAssignmentController.updateGeneralAssignment';

const FIELDS = [
    'FEC_General_Assignment__c.Name',
    'FEC_General_Assignment__c.FEC_General_Assignment_Name__c',
    'FEC_General_Assignment__c.FEC_General_Assignment_Code__c',
    'FEC_General_Assignment__c.FEC_Active__c',
    'FEC_General_Assignment__c.FEC_Customer_Type__c',
    'FEC_General_Assignment__c.FEC_Channel__c'
];

export default class Fec_GeneralAssignmentDetailSimple extends LightningElement {
    @api recordId;
    @track isEditMode = false;
    @track record = {};
    @wire(MessageContext) messageContext;

    // Edit form state
    @track editCustomerType = '';
    @track editActive = false;
    // Channel search+tag
    @track channelSearchTerm = '';
    @track channelOptions = [];
    @track selectedChannels = [];
    @track showChannelDropdown = false;
    // GA Name search+tag (multiple)
    @track gaSearchTerm = '';
    @track gaOptions = [];
    @track selectedGANames = [];
    @track showGADropdown = false;
    @track selectedGACodes = [];

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
        subscribe(this.messageContext, FEC_GA_EDIT_MODE, (msg) => {
            if (msg.recordId === this.recordId) {
                this._enterEditMode();
            }
        });
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) {
            this.record = {
                Name: data.fields.Name?.value,
                FEC_General_Assignment_Name__c: data.fields.FEC_General_Assignment_Name__c?.value,
                FEC_General_Assignment_Code__c: data.fields.FEC_General_Assignment_Code__c?.value,
                FEC_Active__c: data.fields.FEC_Active__c?.value,
                FEC_Customer_Type__c: data.fields.FEC_Customer_Type__c?.value,
                FEC_Channel__c: data.fields.FEC_Channel__c?.value
            };
        }
    }

    _enterEditMode() {
        this.isEditMode = true;
        this.editCustomerType = this.record.FEC_Customer_Type__c || '';
        this.editActive = this.record.FEC_Active__c || false;
        // Init channel tags from comma-separated string
        const ch = this.record.FEC_Channel__c || '';
        this.selectedChannels = ch ? ch.split(',').map(s => s.trim()).filter(Boolean) : [];
        // Init GA Name - comma-separated to array
        const gaName = this.record.FEC_General_Assignment_Name__c || '';
        this.selectedGANames = gaName ? gaName.split(',').map(s => s.trim()).filter(Boolean) : [];
        const gaCode = this.record.FEC_General_Assignment_Code__c || '';
        this.selectedGACodes = gaCode ? gaCode.split(',').map(s => s.trim()).filter(Boolean) : [];
        this.channelSearchTerm = '';
        this.gaSearchTerm = '';
        // Load options
        this._loadChannels('');
        this._loadGANames();
    }

    _loadChannels(search) {
        getChannels({ searchTerm: search })
            .then(result => {
                this.channelOptions = result.map(c => ({ label: c.FEC_Channel_ID__c || c.Name, value: c.FEC_Channel_ID__c || c.Name }));
            })
            .catch(() => {});
    }

    _loadGANames() {
        getGeneralAssignmentNames()
            .then(result => {
                this.gaOptions = result;
            })
            .catch(() => {});
    }

    get gaCodeDisplay() {
        return this.selectedGACodes.join(',');
    }

    get customerTypeOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Existing', value: 'Existing' },
            { label: 'Non-existing', value: 'Non-existing' }
        ];
    }

    get filteredChannelOptions() {
        const term = this.channelSearchTerm.toLowerCase();
        return this.channelOptions.filter(o =>
            !this.selectedChannels.includes(o.value) &&
            (!term || o.label.toLowerCase().includes(term))
        );
    }

    get filteredGAOptions() {
        const term = this.gaSearchTerm.toLowerCase();
        return this.gaOptions.filter(o =>
            !this.selectedGANames.includes(o.value) &&
            (!term || o.label.toLowerCase().includes(term))
        );
    }

    get channelComboboxClass() {
        return this.showChannelDropdown
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    get gaComboboxClass() {
        return this.showGADropdown
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    handleChannelSearch(event) {
        this.channelSearchTerm = event.target.value;
        this.showChannelDropdown = this.channelSearchTerm.length > 0;
        if (this.channelSearchTerm.length > 0) this._loadChannels(this.channelSearchTerm);
    }

    handleChannelFocus() {
        if (this.channelSearchTerm.length > 0) this.showChannelDropdown = true;
    }

    handleChannelBlur() {
        setTimeout(() => { this.showChannelDropdown = false; }, 200);
    }

    handleChannelSelect(event) {
        const val = event.currentTarget.dataset.value;
        if (!this.selectedChannels.includes(val)) {
            this.selectedChannels = [...this.selectedChannels, val];
        }
        this.channelSearchTerm = '';
        this.showChannelDropdown = false;
    }

    handleChannelRemove(event) {
        const val = event.target.name;
        this.selectedChannels = this.selectedChannels.filter(c => c !== val);
    }

    handleGASearch(event) {
        this.gaSearchTerm = event.target.value;
        this.showGADropdown = this.gaSearchTerm.length > 0;
    }

    handleGAFocus() {
        if (this.gaSearchTerm.length > 0) this.showGADropdown = true;
    }

    handleGABlur() {
        setTimeout(() => { this.showGADropdown = false; }, 200);
    }

    handleGASelect(event) {
        const val = event.currentTarget.dataset.value;
        if (!this.selectedGANames.includes(val)) {
            this.selectedGANames = [...this.selectedGANames, val];
            // Auto-load GA Code for each selected name
            getGACodeByName({ gaName: val })
                .then(code => {
                    if (code) {
                        this.selectedGACodes = [...this.selectedGACodes, code];
                    }
                })
                .catch(() => {});
        }
        this.gaSearchTerm = '';
        this.showGADropdown = false;
    }

    handleGARemove(event) {
        const val = event.target.name;
        const idx = this.selectedGANames.indexOf(val);
        this.selectedGANames = this.selectedGANames.filter(n => n !== val);
        if (idx >= 0) {
            this.selectedGACodes = this.selectedGACodes.filter((_, i) => i !== idx);
        }
    }

    handleCustomerTypeChange(event) {
        this.editCustomerType = event.detail.value;
    }

    handleActiveChange(event) {
        this.editActive = event.target.checked;
    }

    handleGACodeChange(event) {
        // GA Code is auto-filled, but allow manual edit for first code
        const codes = [...this.selectedGACodes];
        codes[0] = event.target.value;
        this.selectedGACodes = codes;
    }

    handleCancel() {
        this.isEditMode = false;
    }

    handleSave() {
        if (this.selectedChannels.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: LABEL_CHANNEL_REQUIRED, variant: 'error' }));
            return;
        }
        if (this.selectedGANames.length === 0) {
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: LABEL_NAME_REQUIRED, variant: 'error' }));
            return;
        }
        updateGeneralAssignment({
            recordId: this.recordId,
            customerType: this.editCustomerType,
            channelIds: this.selectedChannels.join(','),
            generalAssignmentName: this.selectedGANames.join(','),
            generalAssignmentCode: this.selectedGACodes.join(','),
            active: this.editActive
        })
        .then(() => {
            this.isEditMode = false;
            try {
                getRecordNotifyChange([{ recordId: this.recordId }]);
                publish(this.messageContext, FEC_GA_SAVED, { recordId: this.recordId });
                this.dispatchEvent(new CustomEvent('savesuccess'));
            } catch(e) {
                console.error('Post-save notification error:', e);
            }
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_SUCCESS, message: LABEL_SAVED, variant: 'success' }));
        })
        .catch(err => {
            const msg = err?.body?.message || err?.body?.fieldErrors?.FEC_General_Assignment_Name__c?.[0]?.message || LABEL_SAVE_ERROR;
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: msg, variant: 'error' }));
        });
    }
}

