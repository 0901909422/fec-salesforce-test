import { LightningElement, track } from 'lwc';
import getQueueMembers from '@salesforce/apex/DepartmentAdmin.getQueueMembers';
import searchActiveUsers from '@salesforce/apex/DepartmentAdmin.searchActiveUsers';
import addUsersToQueue from '@salesforce/apex/DepartmentAdmin.addUsersToQueue';
import removeUserFromQueue from '@salesforce/apex/DepartmentAdmin.removeUserFromQueue';
import getQueueValidBaseNameOrId from '@salesforce/apex/DepartmentAdmin.getQueueValidBaseNameOrId';
import getListTeam from '@salesforce/apex/FEC_TeamQueue.getListTeam';
import getQueueEditInfo from '@salesforce/apex/FEC_TeamQueue.getQueueEditInfo';
import updateQueueEdit from '@salesforce/apex/FEC_TeamQueue.updateQueueEdit';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { customLabels } from 'c/fec_ResourceHelper';

export default class Fec_DepartmentAdmin extends LightningElement {
    customLabels = customLabels;
    // Left panel state
    @track queues = [];
    @track isLoadingQueues = false;
    @track queuesError;

    // Right panel state
    @track users = [];
    @track isLoadingUsers = false;
    @track usersError;

    // Search and selection state
    @track searchTerm = '';
    @track suggestions = [];
    @track showSuggestions = false;
    @track selectedUsersToAdd = [];
    @track showSelectedUsersTable = false;
    @track isSearching = false;
    @track isAddingToQueue = false;

    // Multi-select for suggestions
    selectedSuggestionIds = new Set();

    get isAllSuggestionsSelected() {
        if (!this.suggestions || this.suggestions.length === 0) return false;
        return this.suggestions.every(s => this.selectedSuggestionIds.has(s.id));
    }

    // Modal state
    @track isAddUsersModalOpen = false;
    @track isUserQueuesModalOpen = false; // modal to show user's queues
    @track selectedUserId; // holds the clicked user's Id for queue detail
    @track selectedUserName; // optional: show name in modal header

    // Selection and pagination
    selectedQueueId;
    selectedQueueName;
    selectedQueueLabelStatus;
    pageSize = parseInt(this.customLabels.CS_OrgChart_Table_UserTable_Page_Size) || 100; // Number of users to load per page
    lastUserId = null; // For keyset pagination
    hasMore = false;

    // Datatable columns (Full Name, Username, Email, Profile, Role)
    userColumns = [
        { label: this.customLabels.CS_OrgChart_Table_UserTable_Name_Column, fieldName: 'name', type: 'text' },
        { label: this.customLabels.CS_OrgChart_Table_UserTable_Email_Column, fieldName: 'email', type: 'email' },
        { label: this.customLabels.CS_OrgChart_Table_UserTable_UserRole_Column, fieldName: 'userrole', type: 'text' },
        { type: 'button-icon', fixedWidth: 50, typeAttributes: {name: 'viewUserDetail', iconName: 'utility:table', title: this.customLabels.CS_OrgChart_Text_UserTable_View_ListQueue} },
        { type: 'button-icon', fixedWidth: 50, typeAttributes: {name: 'removeUserFromQueue', iconName: 'utility:delete', title: this.customLabels.CS_OrgChart_Text_UserTable_Remove_User_Title} }
    ];

    // --- Edit Queue modal state & handlers (integration) ---
    @track isLoadQueue = false;
    @track isEditQueueModalOpen = false;
    @track editQueueLabel = '';
    @track editQueueLabelStatus = '';
    @track curentTeamId = null;
    @track currentTeamName = null;
    @track editTeamId = null;
    @track teamOptions = [];
    @track editErrorMessage = '';
    @track isSavingEditQueue = false;
    @track editTeamQueueRecordId = null; // FEC_Team_Queue__c record id if exists

    // Open Edit Queue modal (button uses handleOpenEditQueueModal)
    async handleOpenEditQueueModal() {
        if (!this.selectedQueueId) return;
        this.editErrorMessage = '';
        this.isEditQueueModalOpen = true;
        // Load team options
        try {
            const teams = await getListTeam();
            this.teamOptions = (teams || []).map(t => ({
                label: t.teamLabel ? t.teamLabel : t.teamName,
                value: t.teamId
            }));
        } catch (e) {
            console.error('Failed to load teams for combobox', e);
            this.teamOptions = [];
        }
        // Load queue edit info
        try {
            const info = await getQueueEditInfo({ queueId: this.selectedQueueId, teamQueueRecordId: this.editTeamQueueRecordId });
            if (info) {
                this.editQueueLabel = info.queueLabel || '';
                this.editTeamId = info.teamId;
                this.editQueueLabelStatus = info.queueLabelStatus || '';
                this.selectedQueueLabelStatus = info.queueLabelStatus || '';
            } else {
                this.editQueueLabel = '';
                this.editTeamId = '';
                this.editQueueLabelStatus = '';
            }
        } catch (err) {
            console.error('Failed to load queue edit info', err);
            this.editErrorMessage = err && err.body && err.body.message ? err.body.message : this.customLabels.CS_OrgChart_Text_EditQueueModal_Error;
        }
    }

    handleCloseEditQueueModal() {
        this.isEditQueueModalOpen = false;
        this.editErrorMessage = '';
        this.isSavingEditQueue = false;
    }

    handleEditQueueLabelChange(event) {
        this.editQueueLabel = event.target.value;
    }

    handleEditTeamChange(event) {
        this.editTeamId = event.detail ? event.detail.value : event.target.value;
    }

    handleEditQueueLabelStatusChange(event) {
        this.editQueueLabelStatus = event.target.value;
    }
    validateInputFields() {
        const allValid = [
            ...this.template.querySelectorAll('.validate-input'),
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
        return allValid;
    }

    async handleSaveEditQueue() {
        if (!this.selectedQueueId || !this.editTeamQueueRecordId) return;
        this.editErrorMessage = '';
        this.isSavingEditQueue = true;
        try {
            const allValid = this.validateInputFields();
            if (!allValid) {
                return;
            }
            const teamChanged = this.curentTeamId !== this.editTeamId;
            const labelChanged = this.selectedQueueName !== this.editQueueLabel;
            const labelStatusChanged = this.selectedQueueLabelStatus !== this.editQueueLabelStatus;
            if (!teamChanged && !labelChanged && !labelStatusChanged) {
                this.dispatchEvent(new ShowToastEvent({ 
                    title: this.customLabels.CS_OrgChart_Text_Save_Waning_Title, 
                    message: this.customLabels.CS_OrgChart_Text_EditQueueModal_Warning_No_Changes_Detected, 
                    variant: 'warning'
                }));
                return;
            }
            // Show confirmation dialog
            const confirmed = confirm(this.customLabels.CS_OrgChart_Text_EditQueueModal_Confirm_Save);
            if (confirmed) {
                const queueEdit = {
                    queueId: this.selectedQueueId,
                    newQueueLabel: null,
                    teamQueueRecordId: this.editTeamQueueRecordId,
                    newTeamId: null,
                    newLabelStatus: null
                };
                if (teamChanged) {
                    queueEdit.newTeamId = this.editTeamId;
                }
                if (labelChanged) {
                    queueEdit.newQueueLabel = this.editQueueLabel;
                    this.selectedQueueName = this.editQueueLabel;
                }
                if (labelStatusChanged) {
                    queueEdit.newLabelStatus = this.editQueueLabelStatus;
                    this.selectedQueueLabelStatus = this.editQueueLabelStatus;
                }
                await updateQueueEdit(queueEdit);
                if (teamChanged) {
                    window.location.reload();
                } else if (labelChanged || labelStatusChanged) {
                    this.selectedQueueName = this.editQueueLabel;
                    this.selectedQueueLabelStatus = this.editQueueLabelStatus;
                    this.refreshTeamQueueTreeChild();
                    this.handleCloseEditQueueModal();
                }
                this.dispatchEvent(new ShowToastEvent({ title: this.customLabels.CS_OrgChart_Text_Save_Success_Title, message: this.customLabels.CS_OrgChart_Text_EditQueueModal_Save_Success_Message, variant: 'success' }));
                // send event to child history log
                this.refreshHistoryChild();
            }
        } catch (err) {
            const message = err && err.body && err.body.message ? err.body.message : (err.message ? err.message : 'Failed to save queue');
            this.editErrorMessage = message;
            this.dispatchEvent(new ShowToastEvent({ title: this.customLabels.CS_OrgChart_Text_Save_Error_Title, message: message, variant: 'error', mode: 'sticky' }));
        } finally {
            this.isSavingEditQueue = false;
        }
    }
    get hasQueues() {
        return Array.isArray(this.queues) && this.queues.length > 0;
    }

    get noQueueSelected() {
        return !this.selectedQueueId && !this.isLoadingUsers && !this.usersError;
    }

    get isEmptyUsers() {
        return this.selectedQueueId && !this.isLoadingUsers && !this.usersError && this.users.length === 0;
    }
    
    async handleSelectQueue(event) {
        const qid = event.detail.queueId;
        const teamQueueRecordID = event.detail.teamQueueRecordID;
        const curentTeamId = event.detail.curentTeamId;
        this.curentTeamId = curentTeamId;
        this.selectedQueueId = qid;
        this.isLoadQueue = true;
        
        // Get queue name using the new Apex method
        try {
            const queueInfo = await getQueueValidBaseNameOrId({ developerName: null, queueId: qid });
            this.editTeamQueueRecordId = teamQueueRecordID;
            if (queueInfo && queueInfo.name) {
                this.selectedQueueName = queueInfo.name;
            } else {
                this.selectedQueueName = this.customLabels.CS_OrgChart_Table_UserTable_Queue_Unknow;
            }
        } catch (error) {
            console.error('Error fetching queue name:', error);
            this.selectedQueueName = this.customLabels.CS_OrgChart_Table_UserTable_Queue_Unknow;
        }
        
        // reset pagination and users
        this.users = [];
        this.hasMore = false;
        this.lastUserId = null;
        this.usersError = undefined;
        this.loadUsers();
        this.refreshHistoryChild();
    }

    handleRefresh() {
        if (!this.selectedQueueId) return;
        this.users = [];
        this.hasMore = false;
        this.lastUserId = null;
        this.usersError = undefined;
        this.loadUsers();
    }

    // Modal open/close
    handleOpenAddUsersModal = () => {
        if (this.noQueueSelected) return;
        this.isAddUsersModalOpen = true;
        // reset search state for a new session
        this.searchTerm = '';
        this.suggestions = [];
        this.showSuggestions = false;
        this.selectedUsersToAdd = [];
        this.showSelectedUsersTable = false;
        this.selectedSuggestionIds = new Set();
    };

    handleCloseAddUsersModal = () => {
        this.isAddUsersModalOpen = false;
    };

    handleCloseUserQueuesModal = () => {
        this.isUserQueuesModalOpen = false;
        this.selectedUserId = null;
        this.selectedUserName = null;
    };

    async handleLoadMore(event) {
        if (this.isLoadingUsers || !this.hasMore) return;
        await this.loadUsers();
    }

    async loadUsers() {
        console.log('Page size for user loading:', this.pageSize);
        if (!this.selectedQueueId) return;
        this.isLoadingUsers = true;
        this.usersError = undefined;

        const container = this.template.querySelector('.table-user-container');
        const scrollTop = container ? container.scrollTop : 0;

        try {
            const res = await getQueueMembers({
                queueId: this.selectedQueueId,
                pageSize: this.pageSize,
                lastUserId: this.lastUserId,
            });
            const rows = (res && Array.isArray(res.users)) ? res.users : [];
            // Append for infinite scroll only when rows exist
            if (rows.length > 0) {
                this.users = [...this.users, ...rows];
                // Update cursor using the last row's id
                this.lastUserId = rows[rows.length - 1].id;
            }
            // hasMore is true only when a full page was received
            this.hasMore = rows.length === this.pageSize;
        } catch (e) {
            this.isLoadingUsers = false;
            this.usersError = this.reduceErrors(e);
        } finally {
            this.isLoadingUsers = false;
        }
    }

    // Search functionality
    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length > 0) {
            this.showSuggestions = true;
        } else {
            this.showSuggestions = false;
        }
    }

    handleSearch() {
        // Remove old timeout if the user is entering
        window.clearTimeout(this.delayTimeout);
        this.delayTimeout = setTimeout(() => {
            this.callSearchActiveUsers();
        }, 1000); // Wait 1000ms after user finish enter text
    }
    async callSearchActiveUsers() {
        if (!this.searchTerm.trim()) return;
        this.isSearching = true;
        try {
            const results = await searchActiveUsers({ searchTerm: this.searchTerm });
            const incoming = Array.isArray(results) ? results : [];
            const keep = new Set();
            // add UI flag isSelected for checkbox binding
            this.suggestions = incoming.map(r => {
                const isSel = this.selectedSuggestionIds.has(r.id);
                if (isSel) keep.add(r.id);
                return { ...r, isSelected: isSel };
            });
            // prune any ids that are no longer present
            this.selectedSuggestionIds = keep;
            // sync selected list
            this.selectedUsersToAdd = this.suggestions.filter(s => this.selectedSuggestionIds.has(s.id));
            this.showSelectedUsersTable = this.selectedUsersToAdd.length > 0;
            this.showSuggestions = true;
        } catch (e) {
            this.usersError = this.reduceErrors(e);
            this.suggestions = [];
            this.selectedSuggestionIds = new Set();
            this.selectedUsersToAdd = [];
            this.showSelectedUsersTable = false;
            this.showSuggestions = false;
        } finally {
            this.isSearching = false;
        }
    }

    // Checkbox toggle on a single suggestion
    handleToggleSuggestion(event) {
        const userId = event.target.dataset.userId;
        const userEmail = event.target.dataset.userEmail;
        const checked = event.target.checked;
        if (!userId) return;

        if (checked) {
            this.selectedSuggestionIds.add(userId);
        } else {
            this.selectedSuggestionIds.delete(userId);
        }

        this.suggestions = this.suggestions.map(s =>
            s.id === userId ? { ...s, isSelected: checked } : s
        );

        this.selectedUsersToAdd = this.suggestions.filter(s => this.selectedSuggestionIds.has(s.id));
        this.showSelectedUsersTable = this.selectedUsersToAdd.length > 0;
    }

    // Select/Deselect all in current suggestions
    handleToggleSelectAll(event) {
        const checked = event.target.checked;
        if (!Array.isArray(this.suggestions) || this.suggestions.length === 0) return;

        if (checked) {
            this.suggestions.forEach(s => this.selectedSuggestionIds.add(s.id));
        } else {
            this.suggestions.forEach(s => this.selectedSuggestionIds.delete(s.id));
        }

        this.suggestions = this.suggestions.map(s => ({ ...s, isSelected: checked }));
        this.selectedUsersToAdd = checked ? [...this.suggestions] : [];
        this.showSelectedUsersTable = this.selectedUsersToAdd.length > 0;
    }

    handleSelectedUsersChange(event) {
        // Handle selection changes if needed
        this.selectedUsersToAdd = event.detail.selectedRows;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'viewUserDetail') {
            // Open popup with fec_UserQueueDetail for the selected user
            if (row && row.id) {
                this.selectedUserId = row.id;
                // try to pick a friendly name if available in row
                this.selectedUserName = row.name || row.fullName || '';
                this.isUserQueuesModalOpen = true;
            } else {
                this.usersError = this.customLabels.CS_OrgChart_Text_UserQueueDetailModal_Error;
            }
        } else if (actionName === 'removeUserFromQueue') {
            // Remove user from queue with confirmation
            if (row && row.id && this.selectedQueueId) {
                const userName = row.name || row.fullName || 'User';
                const queueName = this.selectedQueueName || 'Queue';
                
                // Show confirmation dialog
                let messConfirmLabel = this.customLabels.CS_OrgChart_Text_RemoveUser_Message_Confirm;
                let messConfirm = messConfirmLabel.replace("{userName}", userName).replace("{queueName}", queueName);
                const confirmed = confirm(messConfirm);
                if (confirmed) {
                    this.removeUserFromQueueHandler(row.id);
                }
            }
        }
    }
    closeuserdetailmodal() {
        this.isUserQueuesModalOpen = false;
        this.selectedUserId = null;
        this.selectedUserName = null;
    }

    async handleAddSelectedUsersToQueue() {
        if (!this.selectedQueueId || this.selectedUsersToAdd.length === 0) return;

        this.isAddingToQueue = true;
        try {
            const userIds = this.selectedUsersToAdd.map(user => user.id);
            const success = await addUsersToQueue({ queueId: this.selectedQueueId, userIds });
            if (success) {
                // Refresh the user list after adding
                await this.handleRefresh();
                // Ask child component to reload history logs
                this.refreshHistoryChild();

                // Close modal and reset selection
                this.isAddUsersModalOpen = false;
                this.selectedUsersToAdd = [];
                this.showSelectedUsersTable = false;
            } else {
                this.usersError = this.customLabels.CS_OrgChart_Text_AddUserModal_AddAction_Eror;
            }
        } catch (e) {
            this.usersError = this.reduceErrors(e);
        } finally {
            this.isAddingToQueue = false;
        }
    }

        // Simple error flattener
    reduceErrors(errors) {
        if (!errors) return this.customLabels.CS_OrgChart_Text_Unknow_Eror;
        if (Array.isArray(errors)) {
            return errors
                .filter(e => !!e)
                .map(e => e.message || e.body && e.body.message || e.statusText || e.toString())
                .join(', ');
        }
        if (errors.body && Array.isArray(errors.body)) {
            return errors.body.map(e => e.message).join(', ');
        }
        if (errors.body && errors.body.message) {
            return errors.body.message;
        }
        if (errors.message) {
            return errors.message;
        }
        return this.customLabels.CS_OrgChart_Text_Unknow_Eror;
    }

    // Remove user from queue handler
    async removeUserFromQueueHandler(userId) {
        if (!userId || !this.selectedQueueId) return;

        try {
            // Call the Apex method to remove user from queue
            const result = await removeUserFromQueue({
                queueId: this.selectedQueueId,
                userId: userId
            });

            if (result) {
                // Refresh the user list to reflect the removal
                await this.handleRefresh();
                // Ask child component to reload history logs
                this.refreshHistoryChild();
            } else {
                this.usersError = this.customLabels.CS_OrgChart_Text_RemoveUser_Error;
            }
        } catch (error) {
            this.usersError = this.reduceErrors(error);
        }
    }

    // Notify fec_CustomHistoryLog child to reload history logs
    refreshHistoryChild(teamId) {
        try {
            const child = this.template.querySelector('c-fec_-custom-history-log');
            console.log('Refreshing child history log...');
            if (child && typeof child.loadHistory === 'function') {
                console.log('Calling loadHistory on child history log');
                child.loadHistory(teamId);
            }
        } catch (e) {
            console.error('Failed to refresh child history log', e);
        }
    }
    handleSelectTeam(event) {
        const teamId = event.detail.teamId;
        const teamName = event.detail.teamName;
        this.isLoadQueue = false;
        console.log('Team selected:', teamId, teamName);
        if (teamId) {
            this.curentTeamId = teamId;
            this.currentTeamName = teamName;
            this.selectedQueueId = null;
            this.refreshHistoryChild(teamId);
        }

        
    }
    refreshTeamQueueTreeChild() {
        try {
            const child = this.template.querySelector('c-fec_-team-queue-tree');
            console.log('Refreshing child team-queue-tree...');
            if (child && typeof child.refreshQueuesForTeam === 'function') {
                console.log('Calling refreshQueuesForTeam on child team queue');
                child.refreshQueuesForTeam(this.curentTeamId);
            }
        } catch (e) {
            console.error('Failed to refresh child history log', e);
        }
    }
}