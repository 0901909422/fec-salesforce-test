import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { IsConsoleNavigation, getFocusedTabInfo, openTab, closeTab, focusTab } from 'lightning/platformWorkspaceApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';

import getRoutingAssignmentsByNoc from '@salesforce/apex/FEC_NocRoutingAssignmentController.getRoutingAssignmentsByNoc';
import getTeamOptions from '@salesforce/apex/FEC_NocRoutingAssignmentController.getTeamOptions';
import getQueuesByTeam from '@salesforce/apex/FEC_NocRoutingAssignmentController.getQueuesByTeam';
import getChannelOptions from '@salesforce/apex/FEC_NocRoutingAssignmentController.getChannelOptions';
import createRoutingAssignment from '@salesforce/apex/FEC_NocRoutingAssignmentController.createRoutingAssignment';
import updateRoutingAssignment from '@salesforce/apex/FEC_NocRoutingAssignmentController.updateRoutingAssignment';
import getRoutingAssignmentHistory from '@salesforce/apex/FEC_NocRoutingAssignmentController.getRoutingAssignmentHistory';

import LABEL_NEW from '@salesforce/label/c.FEC_Btn_Add_New';
import LABEL_PREVIOUS from '@salesforce/label/c.FEC_Previous_Btn_Label';
import LABEL_NEXT from '@salesforce/label/c.FEC_Next_Btn_Label';
import LABEL_PAGE_OF from '@salesforce/label/c.Pagination_Page_Of_Label';
import LABEL_SUCCESS from '@salesforce/label/c.FEC_RA_Save_Success';
import LABEL_CREATE_SUCCESS from '@salesforce/label/c.FEC_RA_Create_Success';
import LABEL_UPDATE_SUCCESS from '@salesforce/label/c.FEC_RA_Update_Success';
import LABEL_ERROR from '@salesforce/label/c.FEC_RA_Save_Error';
import LABEL_CUSTOMER_TYPE_REQUIRED from '@salesforce/label/c.FEC_RA_Customer_Type_Required';
import LABEL_CHANNEL_REQUIRED from '@salesforce/label/c.FEC_RA_Channel_Required';
import LABEL_TEAM_REQUIRED from '@salesforce/label/c.FEC_RA_Team_Required';
import LABEL_QUEUE_REQUIRED from '@salesforce/label/c.FEC_RA_Queue_Required';
import LABEL_DETAIL_INFO from '@salesforce/label/c.FEC_Label_Detail_Information';
import LABEL_RA_NAME from '@salesforce/label/c.FEC_Label_RA_Name';
import LABEL_CUSTOMER_TYPE from '@salesforce/label/c.FEC_Label_Customer_Type';
import LABEL_CHANNEL from '@salesforce/label/c.FEC_Label_Channel';
import LABEL_TEAM from '@salesforce/label/c.FEC_Label_Team';
import LABEL_QUEUE from '@salesforce/label/c.FEC_Label_Queue';
import LABEL_ACTIVE from '@salesforce/label/c.FEC_Label_Active';
import LABEL_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_SAVE from '@salesforce/label/c.FEC_Button_Save';
import LABEL_EDIT from '@salesforce/label/c.FEC_Label_Edit';
import LABEL_BACK from '@salesforce/label/c.FEC_Label_Back';
import LABEL_RA_HISTORY from '@salesforce/label/c.FEC_Label_RA_History';
import LABEL_NO_RECORDS from '@salesforce/label/c.FEC_Label_No_Records';
import LABEL_NO_HISTORY_SHORT from '@salesforce/label/c.FEC_Label_No_History_Short';
import LABEL_NEW_RA from '@salesforce/label/c.FEC_Label_New_RA';
import LABEL_REQUIRED_INFO from '@salesforce/label/c.FEC_Label_Required_Info';
import LABEL_SEARCH_CHANNEL from '@salesforce/label/c.FEC_Label_Search_Channel';

const PAGE_SIZE = 10;

export default class Fec_NocRoutingAssignment extends NavigationMixin(LightningElement) {
    @api recordId;

    @wire(IsConsoleNavigation)
    isConsoleNavigation;

    // list
    @track allRecords = [];
    @track pageNumber = 1;
    wiredResult;

    // modal new/edit
    @track showModal = false;
    @track isEditMode = false;
    @track editRecordId = null;

    // form fields
    @track formCustomerType = '';
    @track formTeam = '';
    @track formQueue = '';
    @track formActive = true;
    @track selectedChannelIds = []; // array of FEC_Channel_ID__c values
    @track channelSearchTerm = '';
    @track showChannelDropdown = false;

    // options
    @track teamOptions = [];
    @track queueOptions = [];
    @track channelOptions = [];

    // detail panel
    @track showDetail = false;
    @track detailRecord = null;
    @track historyRecords = [];
    @track historyPage = 1;
    @track allHistory = [];
    @track isDetailEdit = false;

    // detail edit form
    @track detailFormCustomerType = '';
    @track detailFormTeam = '';
    @track detailFormQueue = '';
    @track detailFormActive = true;
    @track detailSelectedChannelIds = [];
    @track detailChannelSearchTerm = '';
    @track detailShowChannelDropdown = false;
    @track detailQueueOptions = [];

    labels = {
        new: LABEL_NEW,
        previous: LABEL_PREVIOUS,
        next: LABEL_NEXT,
        pageOf: LABEL_PAGE_OF,
        detailInfo: LABEL_DETAIL_INFO,
        raName: LABEL_RA_NAME,
        customerType: LABEL_CUSTOMER_TYPE,
        channel: LABEL_CHANNEL,
        team: LABEL_TEAM,
        queue: LABEL_QUEUE,
        active: LABEL_ACTIVE,
        cancel: LABEL_CANCEL,
        save: LABEL_SAVE,
        edit: LABEL_EDIT,
        back: LABEL_BACK,
        raHistory: LABEL_RA_HISTORY,
        noRecords: LABEL_NO_RECORDS,
        noHistory: LABEL_NO_HISTORY_SHORT,
        newRA: LABEL_NEW_RA,
        requiredInfo: LABEL_REQUIRED_INFO,
        searchChannel: LABEL_SEARCH_CHANNEL
    };

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
        this._loadTeamOptions();
        this._loadChannelOptions();
    }

    // ─── Wire ────────────────────────────────────────────────────────────────

    @wire(getRoutingAssignmentsByNoc, { nocId: '$recordId' })
    wiredRecords(result) {
        this.wiredResult = result;
        if (result.data) {
            this.allRecords = result.data;
        } else if (result.error) {
            console.error('getRoutingAssignmentsByNoc error', result.error);
        }
    }

    // ─── Pagination ──────────────────────────────────────────────────────────

    get paginatedRecords() {
        const start = (this.pageNumber - 1) * PAGE_SIZE;
        return this.allRecords.slice(start, start + PAGE_SIZE);
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.allRecords.length / PAGE_SIZE));
    }

    get isFirstPage() { return this.pageNumber === 1; }
    get isLastPage() { return this.pageNumber >= this.totalPages; }
    get hasRecords() { return this.allRecords && this.allRecords.length > 0; }

    get pageInfo() {
        return LABEL_PAGE_OF.replace('{0}', this.pageNumber).replace('{1}', this.totalPages);
    }

    handlePreviousPage() { if (this.pageNumber > 1) this.pageNumber--; }
    handleNextPage() { if (this.pageNumber < this.totalPages) this.pageNumber++; }
    handlePageInput(event) {
        const v = parseInt(event.target.value, 10);
        if (v >= 1 && v <= this.totalPages) this.pageNumber = v;
    }

    // ─── Load options ────────────────────────────────────────────────────────

    _loadTeamOptions() {
        getTeamOptions()
            .then(data => { this.teamOptions = data || []; })
            .catch(e => console.error('getTeamOptions error', e));
    }

    _loadChannelOptions() {
        getChannelOptions()
            .then(data => { this.channelOptions = data || []; })
            .catch(e => console.error('getChannelOptions error', e));
    }

    _loadQueuesByTeam(teamName, isDetail) {
        if (!teamName) { if (isDetail) this.detailQueueOptions = []; else this.queueOptions = []; return; }
        getQueuesByTeam({ teamName })
            .then(data => {
                console.log('[RA] getQueuesByTeam team=' + teamName + ' result=' + JSON.stringify(data));
                if (isDetail) this.detailQueueOptions = data || []; else this.queueOptions = data || [];
            })
            .catch(e => {
                console.error('[RA] getQueuesByTeam error team=' + teamName, e);
            });
    }

    // ─── Channel search helpers ───────────────────────────────────────────────

    get filteredChannelOptions() {
        const term = this.channelSearchTerm.toLowerCase();
        return this.channelOptions.filter(o =>
            !this.selectedChannelIds.includes(o.value) &&
            (!term || o.label.toLowerCase().startsWith(term))
        );
    }

    get detailFilteredChannelOptions() {
        const term = this.detailChannelSearchTerm.toLowerCase();
        return this.channelOptions.filter(o =>
            !this.detailSelectedChannelIds.includes(o.value) &&
            (!term || o.label.toLowerCase().startsWith(term))
        );
    }

    // ─── New modal ───────────────────────────────────────────────────────────

    handleNew() {
        this.showModal = true;
        this.isEditMode = false;
        this.editRecordId = null;
        this.formCustomerType = '';
        this.formTeam = '';
        this.formQueue = '';
        this.formActive = true;
        this.selectedChannelIds = [];
        this.channelSearchTerm = '';
        this.queueOptions = [];
    }

    handleCancel() {
        this.showModal = false;
    }

    handleFormCustomerTypeChange(event) { this.formCustomerType = event.detail.value; }
    handleFormActiveChange(event) { this.formActive = event.target.checked; }

    handleFormTeamChange(event) {
        this.formTeam = event.detail.value;
        this.formQueue = '';
        this.queueOptions = []; // clear ngay lập tức
        this._loadQueuesByTeam(this.formTeam, false);
    }

    handleFormQueueChange(event) { this.formQueue = event.detail.value; }

    handleChannelSearch(event) {
        this.channelSearchTerm = event.target.value;
        this.showChannelDropdown = this.channelSearchTerm.length > 0;
    }
    handleChannelFocus() { if (this.channelSearchTerm.length > 0) this.showChannelDropdown = true; }
    handleChannelBlur() { setTimeout(() => { this.showChannelDropdown = false; }, 200); }
    handleChannelSelect(event) {
        const val = event.currentTarget.dataset.value;
        if (!this.selectedChannelIds.includes(val)) this.selectedChannelIds = [...this.selectedChannelIds, val];
        this.channelSearchTerm = '';
        this.showChannelDropdown = false;
    }
    handleChannelRemove(event) {
        const val = event.target.name;
        this.selectedChannelIds = this.selectedChannelIds.filter(v => v !== val);
    }

    handleSave() {
        // Validate
        if (!this.formCustomerType) { this._toast(LABEL_ERROR, LABEL_CUSTOMER_TYPE_REQUIRED, 'error'); return; }
        if (!this.selectedChannelIds.length) { this._toast(LABEL_ERROR, LABEL_CHANNEL_REQUIRED, 'error'); return; }
        if (!this.formTeam) { this._toast(LABEL_ERROR, LABEL_TEAM_REQUIRED, 'error'); return; }
        if (!this.formQueue) { this._toast(LABEL_ERROR, LABEL_QUEUE_REQUIRED, 'error'); return; }

        const channelStr = this.selectedChannelIds.join(',');
        createRoutingAssignment({
            nocId: this.recordId,
            customerType: this.formCustomerType,
            channel: channelStr,
            team: this.formTeam,
            queue: this.formQueue,
            active: this.formActive
        })
        .then(async (newRecordId) => {
            this.showModal = false;
            this._toast(LABEL_SUCCESS, LABEL_CREATE_SUCCESS, 'success');
            this.pageNumber = 1;

            const pageReference = {
                type: 'standard__recordPage',
                attributes: {
                    recordId: newRecordId,
                    objectApiName: 'FEC_Routing_Assignment__c',
                    actionName: 'view'
                }
            };

            await refreshApex(this.wiredResult);

            if (this.isConsoleNavigation) {
                let currentTabId;
                let parentTabId;
                try {
                    const focusedTab = await getFocusedTabInfo();
                    currentTabId = focusedTab?.tabId;
                    //tungnm37 2026-05-27 14:32 - Nếu đang đứng trong subtab của NOC thì phải mở record mới dưới parent tab của NOC
                    parentTabId = focusedTab?.parentTabId || focusedTab?.tabId;
                } catch (e) {
                    currentTabId = null;
                    parentTabId = null;
                }

                const newTabId = parentTabId
                    ? await openTab({
                        parentTabId,
                        pageReference,
                        focus: true
                    })
                    : await openTab({
                        pageReference,
                        focus: true
                    });

                if (newTabId) {
                    await focusTab(newTabId);
                }

                //tungnm37 2026-05-27 14:36 - Giữ nguyên tab NOC hiện tại, không đóng tab sau khi tạo mới
                return;
            }

            const url = await this[NavigationMixin.GenerateUrl](pageReference);
            if (url) {
                window.location.assign(url);
                return;
            }
            this[NavigationMixin.Navigate](pageReference);
        })
        .catch(e => {
            this._toast(LABEL_ERROR, e?.body?.message || e?.message || LABEL_ERROR, 'error');
        });
    }

    // ─── Row click → detail ──────────────────────────────────────────────────

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: id,
                actionName: 'view'
            }
        });
    }

    handleDetailBack() {
        this.showDetail = false;
        this.detailRecord = null;
        this.isDetailEdit = false;
    }

    // ─── Detail edit ─────────────────────────────────────────────────────────

    handleDetailEdit() {
        this.isDetailEdit = true;
        this.detailFormCustomerType = this.detailRecord.customerType || '';
        this.detailFormTeam = this.detailRecord.team || '';
        this.detailFormQueue = this.detailRecord.queue || '';
        this.detailFormActive = this.detailRecord.active !== false;
        this.detailSelectedChannelIds = this.detailRecord.channel
            ? this.detailRecord.channel.split(',').map(s => s.trim()).filter(s => s)
            : [];
        this.detailChannelSearchTerm = '';
        this._loadQueuesByTeam(this.detailFormTeam, true);
    }

    handleDetailCancel() { this.isDetailEdit = false; }

    handleDetailCustomerTypeChange(event) { this.detailFormCustomerType = event.detail.value; }
    handleDetailActiveChange(event) { this.detailFormActive = event.target.checked; }
    handleDetailTeamChange(event) {
        this.detailFormTeam = event.detail.value;
        this.detailFormQueue = '';
        this.detailQueueOptions = []; // clear ngay lập tức
        this._loadQueuesByTeam(this.detailFormTeam, true);
    }
    handleDetailQueueChange(event) { this.detailFormQueue = event.detail.value; }

    handleDetailChannelSearch(event) {
        this.detailChannelSearchTerm = event.target.value;
        this.detailShowChannelDropdown = this.detailChannelSearchTerm.length > 0;
    }
    handleDetailChannelFocus() { if (this.detailChannelSearchTerm.length > 0) this.detailShowChannelDropdown = true; }
    handleDetailChannelBlur() { setTimeout(() => { this.detailShowChannelDropdown = false; }, 200); }
    handleDetailChannelSelect(event) {
        const val = event.currentTarget.dataset.value;
        if (!this.detailSelectedChannelIds.includes(val)) this.detailSelectedChannelIds = [...this.detailSelectedChannelIds, val];
        this.detailChannelSearchTerm = '';
        this.detailShowChannelDropdown = false;
    }
    handleDetailChannelRemove(event) {
        const val = event.target.name;
        this.detailSelectedChannelIds = this.detailSelectedChannelIds.filter(v => v !== val);
    }

    handleDetailSave() {
        if (!this.detailFormCustomerType) { this._toast(LABEL_ERROR, LABEL_CUSTOMER_TYPE_REQUIRED, 'error'); return; }
        if (!this.detailSelectedChannelIds.length) { this._toast(LABEL_ERROR, LABEL_CHANNEL_REQUIRED, 'error'); return; }
        if (!this.detailFormTeam) { this._toast(LABEL_ERROR, LABEL_TEAM_REQUIRED, 'error'); return; }
        if (!this.detailFormQueue) { this._toast(LABEL_ERROR, LABEL_QUEUE_REQUIRED, 'error'); return; }

        updateRoutingAssignment({
            recordId: this.detailRecord.id,
            customerType: this.detailFormCustomerType,
            channel: this.detailSelectedChannelIds.join(','),
            team: this.detailFormTeam,
            queue: this.detailFormQueue,
            active: this.detailFormActive
        })
        .then(() => {
            this.isDetailEdit = false;
            this._toast(LABEL_SUCCESS, LABEL_UPDATE_SUCCESS, 'success');
            return refreshApex(this.wiredResult);
        })
        .then(() => {
            // Refresh detail record from updated list
            const updated = this.allRecords.find(r => r.id === this.detailRecord.id);
            if (updated) this.detailRecord = updated;
            this._loadHistory(this.detailRecord.id);
        })
        .catch(e => {
            this._toast(LABEL_ERROR, e?.body?.message || e?.message || LABEL_ERROR, 'error');
        });
    }

    // ─── History ─────────────────────────────────────────────────────────────

    _loadHistory(recordId) {
        getRoutingAssignmentHistory({ recordId })
            .then(data => {
                this.allHistory = data || [];
                this.historyPage = 1;
                this._updateHistoryPage();
            })
            .catch(e => console.error('getRoutingAssignmentHistory error', e));
    }

    _updateHistoryPage() {
        const start = (this.historyPage - 1) * PAGE_SIZE;
        this.historyRecords = this.allHistory.slice(start, start + PAGE_SIZE);
    }

    get historyTotalPages() { return Math.max(1, Math.ceil(this.allHistory.length / PAGE_SIZE)); }
    get isHistoryFirstPage() { return this.historyPage === 1; }
    get isHistoryLastPage() { return this.historyPage >= this.historyTotalPages; }
    get historyPageInfo() {
        return LABEL_PAGE_OF.replace('{0}', this.historyPage).replace('{1}', this.historyTotalPages);
    }
    get hasHistory() { return this.allHistory && this.allHistory.length > 0; }

    handleHistoryPrev() { if (this.historyPage > 1) { this.historyPage--; this._updateHistoryPage(); } }
    handleHistoryNext() { if (this.historyPage < this.historyTotalPages) { this.historyPage++; this._updateHistoryPage(); } }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get customerTypeOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Existing Customer', value: 'Existing' },
            { label: 'Non-existing Customer', value: 'Non-Existing' }
        ];
    }

    get columns() {
        return [
            {
                label: 'RA Name',
                fieldName: 'name',
                type: 'button',
                typeAttributes: {
                    label: { fieldName: 'name' },
                    name: 'view_detail',
                    variant: 'base'
                }
            },
            { label: 'Customer Type', fieldName: 'customerType', type: 'text' },
            { label: 'Channel', fieldName: 'channel', type: 'text' },
            { label: 'Team', fieldName: 'team', type: 'text' },
            { label: 'Queue', fieldName: 'queue', type: 'text' },
            { label: 'Status', fieldName: 'active', type: 'boolean' },
            {
                type: 'action',
                typeAttributes: {
                    rowActions: [{ label: 'View', name: 'view_detail' }]
                }
            }
        ];
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'view_detail') {
            // tungnm37: dùng standard__recordPage (LWC) thay vì Aura component
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: row.id,
                    actionName: 'view'
                }
            });
        }
    }
}
