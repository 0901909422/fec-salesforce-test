import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getListTeam from '@salesforce/apex/FEC_TeamQueue.getListTeam';
import getQueuesForTeam from '@salesforce/apex/FEC_TeamQueue.getQueuesForTeam';
import validateQueueName from '@salesforce/apex/DepartmentAdmin.getQueueValidBaseNameOrId';
import createQueue from '@salesforce/apex/FEC_TeamQueue.createQueue';
import createTeamQueueRecord from '@salesforce/apex/FEC_TeamQueue.createTeamQueueRecord';
import CreateNewTeam from '@salesforce/apex/FEC_TeamQueue.CreateNewTeam';
import { customLabels } from 'c/fec_ResourceHelper';

export default class fec_TeamQueueTree extends LightningElement {
    customLabels = customLabels;
    @track treeItems = [];
    @track columns = [];
    @track expandedTeams = [];
    @track showModalNewQueue = false;
    @track queueLabel = '';
    @track queueName = '';
    @track queueLabelStatus = '';
    @track errorMessage = '';
    @track currentTeamName = '';
    @track currentTeamID = '';
    @track isLoading = false;

    // States for Add New Team modal
    @track showModalNewTeam = false;
    @track teamLabel = '';
    @track teamName = '';
    @track teamDescription = '';
    @track teamErrorMessage = '';
    @track isLoadingTeam = false;

    connectedCallback() {
        this.loadTeams();
        this.initializeColumns();
        // Listen for external refresh events (dispatched from sibling components)
    }

    initializeColumns() {
        this.columns = [
            {
                label: this.customLabels.CS_OrgChart_Text_TeamQueue_Label,
                fieldName: 'name',
                type: 'button',
                typeAttributes: {
                    label: { fieldName: 'name' },
                    name: 'id', // Action will use for child records
                    iconName: { fieldName: 'rowIcon' },
                    variant: 'base'
                }
            }
        ];
    }

    async loadTeams() {
        try {
            const result = await getListTeam();
            // Transform the data into the format required by lightning-tree-grid
            this.treeItems = result.map(team => {
                return {
                    name: team.teamLabel,
                    id: team.teamId,
                    teamQueueID: team.teamId,
                    expanded: false,
                    _children: [],
                    hasChildren: true
                };
            });
            this.treeItems.unshift({
                name: this.customLabels.CS_OrgChart_Btn_TeamQueue_Add_New,
                rowIcon: 'utility:add',
                rowType: 'ADD_TEAM',
                hasChildren: false,
                queueId: null
            });
        } catch (error) {
            console.error('Error loading teams:', error);
        }
    }

    handleToggle(event) {
        this.doToggle(event.detail.rowKey, event.detail.isExpanded);
    }
    // Handle tree item expand/collapse for lazy loading
    handleTreeItemClick(event) {
        // Determine if this is an expand/collapse event or a row click event
        let rowName = '';
        let rowType = '';
        let queueId = '';
        let teamQueueID = '';
        let teamQueueRecordID = '';
        let rowId = '';
        
        // Check if it's an expand/collapse event (from onexpand/oncollapse)
       if (event.detail && event.detail.row) {
            let detailRow = event.detail.row;
            rowName = detailRow.name ? detailRow.name : '';
            rowType = detailRow.rowType ? detailRow.rowType : '';
            queueId = detailRow.queueId ? detailRow.queueId : '';
            teamQueueID = detailRow.teamQueueID ? detailRow.teamQueueID : '';
            teamQueueRecordID = detailRow.teamQueueRecordID ? detailRow.teamQueueRecordID : '';
            rowId = detailRow.id ? detailRow.id : '';
        }
        console.log('rowId: ', rowId, ' rowName:', rowName, ' rowType:', rowType, ' queueId:', queueId, ' teamQueueID:', teamQueueID, ' ;teamQueueRecordID: ', teamQueueRecordID);
        if (rowType === 'QUEUE' && queueId) {
            // New custom event to get queue users show on parent LWC
            this.dispatchEvent(new CustomEvent('getqueueusers', { detail: { queueId: queueId, teamQueueRecordID: teamQueueRecordID, curentTeamId: teamQueueID} }));
        } else if (rowType === 'ADD_QUEUE' && teamQueueID) {
            // Handle show model Add queue form
            this.openModal(teamQueueID);
        } else if (rowType === 'ADD_TEAM') {
            this.openAddTeamModal();
        } else if (!this.expandedTeams.includes(rowId) && !rowType) {
            // Expand row
            this.expandedTeams = [...this.expandedTeams, rowId];
            // Call loadHistory
            this.dispatchEvent(new CustomEvent('selectteam', { detail: { teamId: rowId, teamName: rowName} }));
            this.loadQueuesForTeam(rowId);
        } else if (this.expandedTeams.includes(rowId)) {
            // Handle collapse row
            this.expandedTeams = this.expandedTeams.filter(id => id !== rowId);
        }
    }

    async loadQueuesForTeam(teamID) {
        try {
            // Load queues for this team
            const result = await getQueuesForTeam({ teamID: teamID });            
            // Create queue items
            const queueItems = result.map(queue => ({
                name: queue.displayname, // Queue label
                id: queue.name,
                rowType: 'QUEUE',
                teamQueueID: teamID,
                teamQueueRecordID: queue.id,
                queueId: queue.queueId
            }));
           
            // Record Add Queue in Team
            queueItems.unshift({
                name: this.customLabels.CS_OrgChart_Btn_TeamQueue_Add_NewQueue,
                rowIcon: 'utility:add',
                rowType: 'ADD_QUEUE',
                teamQueueID: teamID,
                hasChildren: false,
                queueId: null
            });
            // Find the team in treeItems and add children
            const teamItem = this.findAndAddChildren(this.treeItems, teamID, queueItems);
            if (teamItem) {
                this.treeItems = [...this.treeItems]; // Trigger re-render
            }
        } catch (error) {
            console.error('Error loading queues for team:', teamName, error);
        }
    }

    findAndAddChildren(items, teamID, children) {
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item.id === teamID) {
                item._children = children;
                item.expanded = true;
                return item;
            }
            if (item._children && item._children.length > 0) {
                const found = this.findAndAddChildren(item._children, teamID, children);
                if (found) return found;
            }
        }
        return null;
    }

    // Open modal for adding new queue
    openModal(teamID) {
        this.showModalNewQueue = true;
        this.queueLabel = '';
        this.queueName = '';
        this.queueLabelStatus = '';
        this.errorMessage = '';
        this.currentTeamID = teamID;
    }

    // Close modal
    closeModal() {
        this.showModalNewQueue = false;
        this.queueLabel = '';
        this.queueName = '';
        this.queueLabelStatus = '';
        this.errorMessage = '';
    }

    // Open modal for Add new Team
    openAddTeamModal() {
        this.showModalNewTeam = true;
        this.teamLabel = '';
        this.teamName = '';
        this.teamDescription = '';
        this.teamErrorMessage = '';
    }

    // Handle input changes
    handleQueueLabelChange(event) {
        this.queueLabel = event.target.value;
    }

    handleQueueNameChange(event) {
        this.queueName = event.target.value;
    }

    handleQueueLabelStatusChange(event) {
        this.queueLabelStatus = event.target.value;
    }

    // Validate queue name format using regex
    validateQueueNameFormat(queueName) {
        const regex = /^[a-zA-Z](?!.*__)(?!.*_$)[a-zA-Z0-9_]*$/;
        return regex.test(queueName);
    }

    // Handlers for Add Team modal inputs
    handleTeamLabelChange(event) {
        this.teamLabel = event.target.value;
    }
    handleTeamNameChange(event) {
        this.teamName = event.target.value;
    }
    handleTeamDescriptionChange(event) {
        this.teamDescription = event.target.value;
    }

    // Close Add Team modal
    closeTeamModal() {
        this.showModalNewTeam = false;
        this.teamLabel = '';
        this.teamName = '';
        this.teamDescription = '';
        this.teamErrorMessage = '';
        this.isLoadingTeam = false;
    }

    // Local validation for teamName (same rules as Apex)
    validateTeamApiName(name) {
        if (!name) return false;
        const trimmed = name.trim();
        if (trimmed.length === 0) return false;
        const pattern = /^[A-Za-z](?:[A-Za-z0-9_]*[A-Za-z0-9])?$/;
        if (!pattern.test(trimmed)) return false;
        if (trimmed.includes('__')) return false; // no double underscores
        return true;
    }

    // Save new Team: call Apex CreateNewTeam, toast, close modal, and refresh team tree
    async saveNewTeam() {
        this.teamErrorMessage = '';
        this.isLoadingTeam = true;
        try {
            // Basic client-side validations
            if (!this.teamLabel || this.teamLabel.trim().length === 0) {
                this.teamErrorMessage = this.customLabels.CS_OrgChart_Text_AddTeamModal_Label_Require_Err;
                return;
            }
            if (!this.validateTeamApiName(this.teamName)) {
                this.teamErrorMessage = this.customLabels.CS_OrgChart_Text_AddTeamModal_Name_Require_Err;
                return;
            }

            const newId = await CreateNewTeam({
                teamLabel: this.teamLabel,
                teamName: this.teamName,
                teamDescription: this.teamDescription
            });
            if (newId) {
                // Reload teams to include the new team
                await this.loadTeams();
                // Show success toast
                this.dispatchEvent(new ShowToastEvent({
                    title: this.customLabels.CS_OrgChart_Text_Save_Success_Title,
                    message: this.customLabels.CS_OrgChart_Text_AddTeamModal_Success_Message,
                    variant: 'success',
                    mode: 'dismissable'
                }));
                // Close modal
                this.closeTeamModal();
            }
        } catch (error) {
            // Extract server message if available
            console.log('Error create new team: ', error)
            const message = (error && error.body && error.body.message) ? error.body.message : 'Failed to create team.';
            this.teamErrorMessage = message;
            this.dispatchEvent(new ShowToastEvent({
                title: this.customLabels.CS_OrgChart_Text_Save_Error_Title,
                message: message,
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.isLoadingTeam = false;
        }
    }

    // Validate queue name using existing method
    async validateQueueName() {
        try {
            // Call the existing method to check if queue name already exists
            const result = await validateQueueName({ developerName: this.queueName, queueId: null });
            return result != null; // Return true if queue name exists, false otherwise
        } catch (error) {
            console.error('Error validating queue name:', error);
            return false; // Assume validation fails on error
        }
    }

    // Save new queue and new queue team
    // MIXED_DML_OPERATION, DML operation on setup object is not permitted after you have updated a non-setup object
    async saveNewQueue() {
        // Reset any previous errors
        this.errorMessage = '';
        this.isLoading = true;

        try {
            // Validate queue name format first
            if (!this.validateQueueNameFormat(this.queueName)) {
                this.errorMessage = this.customLabels.CS_OrgChart_Text_AddQueueModal_InvalidName_Err;
                this.isLoading = false;
                return;
            }

            // Validate that queue name doesn't already exist
            const queueExists = await this.validateQueueName();
            if (queueExists) {
                this.errorMessage = this.customLabels.CS_OrgChart_Text_AddQueueModal_InvalidName_Exist;
                this.isLoading = false;
                return;
            }

            // Create the new queue in Salesforce with proper field mapping
            const queueResultId = await createQueue({ queueLabel: this.queueLabel, queueName: this.queueName });
            if (queueResultId !== null) {
                // Create record in FEC_Team_Queue__c custom object
                const teamQueueResult = await createTeamQueueRecord({ teamID: this.currentTeamID, queueName: this.queueName, labelStatus: this.queueLabelStatus });
                if (teamQueueResult) {
                    // Refresh the queue list for the team
                    await this.refreshQueuesForTeam(this.currentTeamID);
                    this.dispatchEvent(new CustomEvent('selectteam', { detail: {teamId: null} }));
                    // Show success toast
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: this.customLabels.CS_OrgChart_Text_Save_Success_Title,
                            message: this.customLabels.CS_OrgChart_Text_AddQueueModal_AddQueue_Success,
                            variant: 'success',
                            mode: 'dismissable'
                        })
                    );
                    
                    // Close modal
                    this.closeModal();
                } else {
                    this.errorMessage = this.customLabels.CS_OrgChart_Text_AddQueueModal_AddQueue_Error;
                }
            } else {
                this.errorMessage = 'Failed to create queue in Salesforce';
            }
        } catch (error) {
            console.error('Error creating new queue:', error);
            this.errorMessage = this.customLabels.CS_OrgChart_Text_AddQueueModal_AddQueue_Error_Catch;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.customLabels.CS_OrgChart_Text_Save_Error_Title,
                    message: this.errorMessage,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    // Refresh queues for a team
    @api
    async refreshQueuesForTeam(teamID) {
        try {
            // Reload queues for this team to reflect the newly added queue
            await this.loadQueuesForTeam(teamID);
        } catch (error) {
            console.error('Error refreshing queues for team:', teamID, error);
        }
    }
}