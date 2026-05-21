import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getRoutingAssignment from '@salesforce/apex/FEC_NocRoutingAssignmentController.getRoutingAssignment';
import getTeamOptions from '@salesforce/apex/FEC_NocRoutingAssignmentController.getTeamOptions';
import getQueuesByTeam from '@salesforce/apex/FEC_NocRoutingAssignmentController.getQueuesByTeam';
import getChannelOptions from '@salesforce/apex/FEC_NocRoutingAssignmentController.getChannelOptions';
import updateRoutingAssignment from '@salesforce/apex/FEC_NocRoutingAssignmentController.updateRoutingAssignment';

import LABEL_SUCCESS from '@salesforce/label/c.FEC_RA_Save_Success';
import LABEL_UPDATE_SUCCESS from '@salesforce/label/c.FEC_RA_Update_Success';
import LABEL_ERROR from '@salesforce/label/c.FEC_RA_Save_Error';
import LABEL_CUSTOMER_TYPE_REQUIRED from '@salesforce/label/c.FEC_RA_Customer_Type_Required';
import LABEL_CHANNEL_REQUIRED from '@salesforce/label/c.FEC_RA_Channel_Required';
import LABEL_TEAM_REQUIRED from '@salesforce/label/c.FEC_RA_Team_Required';
import LABEL_QUEUE_REQUIRED from '@salesforce/label/c.FEC_RA_Queue_Required';
import LABEL_RA_NAME from '@salesforce/label/c.FEC_Label_RA_Name';
import LABEL_CUSTOMER_TYPE from '@salesforce/label/c.FEC_Label_Customer_Type';
import LABEL_CHANNEL from '@salesforce/label/c.FEC_Label_Channel';
import LABEL_TEAM from '@salesforce/label/c.FEC_Label_Team';
import LABEL_QUEUE from '@salesforce/label/c.FEC_Label_Queue';
import LABEL_ACTIVE from '@salesforce/label/c.FEC_Label_Active';
import LABEL_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_REQUIRED_INFO from '@salesforce/label/c.FEC_Label_Required_Info';
import LABEL_SEARCH_CHANNEL from '@salesforce/label/c.FEC_Label_Search_Channel';
import LABEL_EDIT_RA from '@salesforce/label/c.FEC_Label_Edit_RA';
import LABEL_NOC from '@salesforce/label/c.FEC_Label_Nature_of_Cases';
import LABEL_ERROR_UPDATE from '@salesforce/label/c.FEC_RA_Error_Update';
import LABEL_ERROR_LOAD from '@salesforce/label/c.FEC_RA_Error_Load';
import LABEL_CUSTOMER_ALL from '@salesforce/label/c.FEC_Label_Customer_All';
import LABEL_CUSTOMER_EXISTING from '@salesforce/label/c.FEC_Label_Customer_Existing';
import LABEL_CUSTOMER_NON_EXISTING from '@salesforce/label/c.FEC_Label_Customer_Non_Existing';

export default class FecRoutingAssignmentEditForm extends LightningElement {
    @api recordId;

    @track isLoading = false;
    @track errorMsg = '';

    // Record properties
    @track raName = '';
    @track customerType = '';
    @track team = '';
    @track queue = '';
    @track active = true;
    @track nocId = '';
    @track nocName = '';

    // Channel multi-select search state
    @track selectedChannelIds = [];
    @track channelSearchTerm = '';
    @track showChannelDropdown = false;

    // Picklist options
    @track teamOptions = [];
    @track queueOptions = [];
    @track channelOptions = [];

    labels = {
        requiredInfo: LABEL_REQUIRED_INFO,
        raName: LABEL_RA_NAME,
        customerType: LABEL_CUSTOMER_TYPE,
        channel: LABEL_CHANNEL,
        team: LABEL_TEAM,
        queue: LABEL_QUEUE,
        active: LABEL_ACTIVE,
        cancel: LABEL_CANCEL,
        save: LABEL_SAVE,
        searchChannel: LABEL_SEARCH_CHANNEL,
        editRa: LABEL_EDIT_RA,
        noc: LABEL_NOC
    };

    get titleText() {
        return this.raName ? `${LABEL_EDIT_RA}: ${this.raName}` : LABEL_EDIT_RA;
    }

    get customerTypeOptions() {
        return [
            { label: LABEL_CUSTOMER_ALL, value: 'All' },
            { label: LABEL_CUSTOMER_EXISTING, value: 'Existing' },
            { label: LABEL_CUSTOMER_NON_EXISTING, value: 'Non-Existing' }
        ];
    }

    connectedCallback() {
        this.isLoading = true;
        this._loadOptions();
        this._loadRecordDetails();
    }

    _loadOptions() {
        // Load Team options
        getTeamOptions()
            .then(data => {
                this.teamOptions = data || [];
            })
            .catch(e => {
                console.error('Error fetching team options', e);
            });

        // Load Channel options
        getChannelOptions()
            .then(data => {
                this.channelOptions = data || [];
            })
            .catch(e => {
                console.error('Error fetching channel options', e);
            });
    }

    _loadRecordDetails() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }

        getRoutingAssignment({ recordId: this.recordId })
            .then(data => {
                if (data) {
                    this.raName = data.name;
                    this.customerType = data.customerType || '';
                    this.team = data.team || '';
                    this.queue = data.queue || '';
                    this.active = data.active !== false;
                    this.nocId = data.nocId || '';
                    this.nocName = data.nocName || '';

                    // Initialize selected channels from comma-separated string
                    this.selectedChannelIds = data.channel
                        ? data.channel.split(',').map(s => s.trim()).filter(s => s)
                        : [];

                    // Load queue options for the current team
                    if (this.team) {
                        this._loadQueuesByTeam(this.team);
                    }
                }
                this.isLoading = false;
            })
            .catch(e => {
                console.error('Error fetching record details', e);
                this.errorMsg = e?.body?.message || e?.message || LABEL_ERROR_LOAD;
                this.isLoading = false;
            });
    }

    _loadQueuesByTeam(teamName) {
        if (!teamName) {
            this.queueOptions = [];
            return;
        }
        getQueuesByTeam({ teamName })
            .then(data => {
                this.queueOptions = data || [];
            })
            .catch(e => {
                console.error('Error fetching queue options for team ' + teamName, e);
                this.queueOptions = [];
            });
    }

    // Input handlers
    handleCustomerTypeChange(event) {
        this.customerType = event.detail.value;
    }

    handleActiveChange(event) {
        this.active = event.target.checked;
    }

    handleTeamChange(event) {
        this.team = event.detail.value;
        this.queue = '';
        this.queueOptions = [];
        this._loadQueuesByTeam(this.team);
    }

    handleQueueChange(event) {
        this.queue = event.detail.value;
    }

    // Channel multi-select search logic
    get filteredChannelOptions() {
        const term = this.channelSearchTerm.toLowerCase();
        return this.channelOptions.filter(o =>
            !this.selectedChannelIds.includes(o.value) &&
            (!term || o.label.toLowerCase().startsWith(term))
        );
    }

    handleChannelSearch(event) {
        this.channelSearchTerm = event.target.value;
        this.showChannelDropdown = this.channelSearchTerm.length > 0;
    }

    handleChannelFocus() {
        if (this.channelSearchTerm.length > 0) {
            this.showChannelDropdown = true;
        }
    }

    handleChannelBlur() {
        // Delay closing to allow onmousedown selection to execute
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.showChannelDropdown = false;
        }, 200);
    }

    handleChannelSelect(event) {
        const val = event.currentTarget.dataset.value;
        if (!this.selectedChannelIds.includes(val)) {
            this.selectedChannelIds = [...this.selectedChannelIds, val];
        }
        this.channelSearchTerm = '';
        this.showChannelDropdown = false;
    }

    handleChannelRemove(event) {
        const val = event.target.name;
        this.selectedChannelIds = this.selectedChannelIds.filter(v => v !== val);
    }

    // Save and Cancel actions — dispatch close event only, no navigation
    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSave() {
        // Validate inputs
        if (!this.customerType) {
            this._toast(LABEL_ERROR, LABEL_CUSTOMER_TYPE_REQUIRED, 'error');
            return;
        }
        if (!this.selectedChannelIds.length) {
            this._toast(LABEL_ERROR, LABEL_CHANNEL_REQUIRED, 'error');
            return;
        }
        if (!this.team) {
            this._toast(LABEL_ERROR, LABEL_TEAM_REQUIRED, 'error');
            return;
        }
        if (!this.queue) {
            this._toast(LABEL_ERROR, LABEL_QUEUE_REQUIRED, 'error');
            return;
        }

        this.isLoading = true;
        const channelStr = this.selectedChannelIds.join(',');

        updateRoutingAssignment({
            recordId: this.recordId,
            customerType: this.customerType,
            channel: channelStr,
            team: this.team,
            queue: this.queue,
            active: this.active
        })
        .then(() => {
            this.isLoading = false;
            this._toast(LABEL_SUCCESS, LABEL_UPDATE_SUCCESS, 'success');
            this.dispatchEvent(new CustomEvent('close'));
        })
        .catch(e => {
            this.isLoading = false;
            const msg = e?.body?.message || e?.message || LABEL_ERROR_UPDATE;
            this._toast(LABEL_ERROR, msg, 'error');
        });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
