import { LightningElement, track, wire } from 'lwc';
import { EnclosingUtilityId, updateUtility, updatePanel, minimize } from 'lightning/platformUtilityBarApi';
import { publish, subscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import FEC_CHATHUB_STATUS from '@salesforce/messageChannel/FecChatHubStatus__c';

/**
 * FecAgentStatusUtility - Utility bar component for managing agent status
 * 
 * Responsibilities:
 * - Display and manage agent status selection in Salesforce Utility Bar
 * - Synchronize status changes with ChatHub container via message service
 * - Update utility panel label based on selected agent status
 * - Handle bidirectional communication with ChatHub iframe
 */
export default class FecAgentStatusUtility extends LightningElement {
    // ===== CLASS PROPERTIES & VARIABLES =====

    // --- Reactive Properties (UI State) ---
    @track agentStatuses = null;        // Array of available agent status options
    @track selectedStatus = '';         // Currently selected agent status ID

    // --- Wire Adapters ---
    @wire(EnclosingUtilityId) utilityId;
    @wire(MessageContext) messageContext;

    // --- Event Management & Subscriptions ---
    subscription = null;                // Message service subscription reference

    // ===== LIFECYCLE HOOKS =====

    /**
     * connectedCallback - Lifecycle hook when component is inserted into DOM
     * @return {void}
     */
    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    // ===== MESSAGE SERVICE & EVENT HANDLERS =====

    /**
     * Subscribes to FecChatHubStatus message channel
     * Listens for messages from ChatHub container and utility bar
     * Uses APPLICATION_SCOPE for global message distribution
     * @return {void}
     */
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                FEC_CHATHUB_STATUS,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    /**
     * Handles incoming messages from message channel
     * Processes two main message types:
     * 1. INIT_STATUS_FROM_IFRAME - Initialize status list and current selection from ChatHub
     * 2. STATUS_CHANGED_FROM_IFRAME - Update status when changed from ChatHub
     * 
     * @param {Object} message - Message object from message service
     * @param {string} message.action - Action identifier (INIT_STATUS_FROM_IFRAME, STATUS_CHANGED_FROM_IFRAME)
     * @param {Object} message.payload - Message payload (for INIT_STATUS_FROM_IFRAME)
     * @param {string} message.newStatusId - New status ID (for STATUS_CHANGED_FROM_IFRAME)
     * @return {void}
     */
    handleMessage(message) {
        // Handle initialization of status list from ChatHub iframe
        if (message.action === 'INIT_STATUS_FROM_IFRAME') {
            const payload = message.payload;

            // Transform status data from ChatHub format to component format
            if (payload && payload.status) {
                this.agentStatuses = payload.status.map(item => ({
                    label: item.name,
                    value: item.id
                }));
            }

            // Set initial selected status if agent info is available
            if (payload && payload.agentInfo && payload.agentInfo.agentStatusID) {
                this.selectedStatus = payload.agentInfo.agentStatusID;
                this.updateUtilityLabel(this.selectedStatus);
            }
        }
        // Handle status change from ChatHub iframe
        else if (message.action === 'STATUS_CHANGED_FROM_IFRAME') {
            this.selectedStatus = message.newStatusId;
            this.updateUtilityLabel(this.selectedStatus);
        }
    }

    // ===== UI EVENT HANDLERS =====

    /**
     * Handles agent status change from component dropdown
     * Updates local selection and notifies ChatHub container of the change
     * 
     * Flow:
     * 1. Update local selectedStatus property
     * 2. Update utility panel label to reflect new status
     * 3. Publish event to notify ChatHub container of status change
     * 
     * @param {Event} event - Change event from lightning-combobox
     * @param {string} event.detail.value - Selected status ID
     * @return {void}
     */
    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;

        // Update utility panel label display
        this.updateUtilityLabel(this.selectedStatus);

        // Publish status change to ChatHub container
        publish(this.messageContext, FEC_CHATHUB_STATUS, {
            action: 'STATUS_CHANGED_FROM_UTILITY',
            newStatusId: this.selectedStatus
        });
        if (this.utilityId) {
            minimize(this.utilityId)
                .catch(err => {
                    console.error('[FEC-AgentStatus] Error calling minimize:', err);
                });
        }
    }

    // ===== UTILITY FUNCTIONS =====

    /**
     * Updates the Salesforce Utility Bar panel label based on selected status
     * Displays selected status name instead of generic "Status" text
     * 
     * @param {string} statusId - Status ID to lookup and display
     * @return {void}
     */
    async updateUtilityLabel(statusId) {
        // Guard: Cannot proceed without utility ID or status list
        if (!this.utilityId || !this.agentStatuses) return;

        // Find the label for current status
        const currentStatus = this.agentStatuses.find(s => s.value === statusId);
        const statusName = currentStatus ? currentStatus.label : 'Status';

        try {
            // Update both utility panel and utility label
            updatePanel(this.utilityId, { label: statusName });
            updateUtility(this.utilityId, { label: statusName });
        } catch (error) {
            console.error('Error updating Utility Tab label:', error);
        }
    }
}