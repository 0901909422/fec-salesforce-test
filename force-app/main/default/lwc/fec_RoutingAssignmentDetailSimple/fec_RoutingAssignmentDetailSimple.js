import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import FEC_RA_EDIT_MODE from '@salesforce/messageChannel/FEC_RA_Edit_Mode__c';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';
import updateRoutingAssignment from '@salesforce/apex/FEC_NocRoutingAssignmentController.updateRoutingAssignment';
import getTeamOptions from '@salesforce/apex/FEC_NocRoutingAssignmentController.getTeamOptions';
import getQueuesByTeam from '@salesforce/apex/FEC_NocRoutingAssignmentController.getQueuesByTeam';
import getChannelOptions from '@salesforce/apex/FEC_NocRoutingAssignmentController.getChannelOptions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LABEL_SAVE_SUCCESS_TITLE from '@salesforce/label/c.FEC_Toast_Save_Success_Title';
import LABEL_SAVE_SUCCESS_MSG from '@salesforce/label/c.FEC_Toast_Save_Success_Message';
import LABEL_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LABEL_SAVE_ERROR_MSG from '@salesforce/label/c.FEC_Toast_Save_Error_Message';

const FIELDS = [
    'FEC_Routing_Assignment__c.Name',
    'FEC_Routing_Assignment__c.FEC_Customer_Type__c',
    'FEC_Routing_Assignment__c.FEC_Channel__c',
    'FEC_Routing_Assignment__c.FEC_Team__c',
    'FEC_Routing_Assignment__c.FEC_Queue__c',
    'FEC_Routing_Assignment__c.FEC_Active__c'
];

export default class Fec_RoutingAssignmentDetailSimple extends LightningElement {
    @api recordId;
    @api
    get isEditMode() { return this._isEditMode; }
    set isEditMode(val) {
        this._isEditMode = val;
        if (val && this.record.Name) this._initEditForm();
    }
    _isEditMode = false;

    record = {};
    isLoaded = false;

    // edit form
    @track editCustomerType = '';
    @track editTeam = '';
    @track editQueue = '';
    @track editActive = true;
    @track editChannelIds = [];
    @track channelSearchTerm = '';
    @track showChannelDropdown = false;
    @track teamOptions = [];
    @track queueOptions = [];
    @track channelOptions = [];

    @wire(MessageContext) messageContext;
    _subscription = null;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = {
                Name: getFieldValue(data, 'FEC_Routing_Assignment__c.Name'),
                FEC_Customer_Type__c: getFieldValue(data, 'FEC_Routing_Assignment__c.FEC_Customer_Type__c'),
                FEC_Channel__c: getFieldValue(data, 'FEC_Routing_Assignment__c.FEC_Channel__c'),
                FEC_Team__c: getFieldValue(data, 'FEC_Routing_Assignment__c.FEC_Team__c'),
                FEC_Queue__c: getFieldValue(data, 'FEC_Routing_Assignment__c.FEC_Queue__c'),
                FEC_Active__c: getFieldValue(data, 'FEC_Routing_Assignment__c.FEC_Active__c')
            };
            this.isLoaded = true;
            if (this._isEditMode) this._initEditForm();
        } else if (error) {
            this.isLoaded = true;
        }
    }

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
        getTeamOptions().then(d => { this.teamOptions = d || []; });
        getChannelOptions().then(d => { this.channelOptions = d || []; });
        // tungnm37: subscribe message channel từ fec_RoutingAssignmentActions
        this._subscription = subscribe(this.messageContext, FEC_RA_EDIT_MODE, (msg) => {
            if (msg.recordId === this.recordId) {
                this._isEditMode = true;
                if (this.record.Name) this._initEditForm();
            }
        }, { scope: APPLICATION_SCOPE });
    }

    disconnectedCallback() {
        if (this._subscription) {
            unsubscribe(this._subscription);
            this._subscription = null;
        }
    }

    _initEditForm() {
        this.editCustomerType = this.record.FEC_Customer_Type__c || '';
        this.editTeam = this.record.FEC_Team__c || '';
        this.editQueue = this.record.FEC_Queue__c || '';
        this.editActive = this.record.FEC_Active__c !== false;
        this.editChannelIds = this.record.FEC_Channel__c
            ? this.record.FEC_Channel__c.split(',').map(s => s.trim()).filter(s => s)
            : [];
        this.channelSearchTerm = '';
        if (this.editTeam) {
            getQueuesByTeam({ teamName: this.editTeam }).then(d => { this.queueOptions = d || []; });
        }
    }

    get customerTypeOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Existing Customer', value: 'Existing' },
            { label: 'Non-existing Customer', value: 'Non-Existing' }
        ];
    }

    get filteredChannelOptions() {
        const term = this.channelSearchTerm.toLowerCase();
        return this.channelOptions.filter(o =>
            !this.editChannelIds.includes(o.value) &&
            (!term || o.label.toLowerCase().startsWith(term))
        );
    }

    handleCustomerTypeChange(e) { this.editCustomerType = e.detail.value; }
    handleActiveChange(e) { this.editActive = e.target.checked; }
    handleTeamChange(e) {
        this.editTeam = e.detail.value;
        this.editQueue = '';
        this.queueOptions = [];
        getQueuesByTeam({ teamName: this.editTeam }).then(d => { this.queueOptions = d || []; });
    }
    handleQueueChange(e) { this.editQueue = e.detail.value; }

    handleChannelSearch(e) { this.channelSearchTerm = e.target.value; this.showChannelDropdown = !!e.target.value; }
    handleChannelFocus() { if (this.channelSearchTerm) this.showChannelDropdown = true; }
    handleChannelBlur() { setTimeout(() => { this.showChannelDropdown = false; }, 200); }
    handleChannelSelect(e) {
        const val = e.currentTarget.dataset.value;
        if (!this.editChannelIds.includes(val)) this.editChannelIds = [...this.editChannelIds, val];
        this.channelSearchTerm = '';
        this.showChannelDropdown = false;
    }
    handleChannelRemove(e) {
        const val = e.target.name;
        this.editChannelIds = this.editChannelIds.filter(v => v !== val);
    }

    // tungnm37: nút Edit trong header
    handleEdit() {
        this._isEditMode = true;
        if (this.record.Name) this._initEditForm();
    }

    handleCancel() {
        this._isEditMode = false;
        this.dispatchEvent(new CustomEvent('canceledit'));
        this.dispatchEvent(new CustomEvent('editchange', { detail: { isEdit: false } }));
    }

    handleSave() {
        updateRoutingAssignment({
            recordId: this.recordId,
            customerType: this.editCustomerType,
            channel: this.editChannelIds.join(','),
            team: this.editTeam,
            queue: this.editQueue,
            active: this.editActive
        }).then(() => {
            this._isEditMode = false;
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_SAVE_SUCCESS_TITLE, message: LABEL_SAVE_SUCCESS_MSG, variant: 'success' }));
            this.dispatchEvent(new CustomEvent('savesuccess'));
        }).catch(e => {
            this.dispatchEvent(new ShowToastEvent({ title: LABEL_ERROR, message: e?.body?.message || LABEL_SAVE_ERROR_MSG, variant: 'error' }));
        });
    }
}
