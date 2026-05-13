import { LightningElement, api, wire } from 'lwc';
import getChatMessages from '@salesforce/apex/FEC_ChatHistoryController.getChatMessages';
import saveManualChatHistory from '@salesforce/apex/FEC_ChatHistoryController.saveManualChatHistory';
import { formatDatetimeLocal } from 'c/fecChathubUtils';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import FEC_CHAT_UPDATE from '@salesforce/messageChannel/FecChatUpdate__c';
import labelChatHistory from '@salesforce/label/c.FEC_Label_ChatHistory';
import labelNoChatHistory from '@salesforce/label/c.FEC_Label_NoChatHistory';
import labelFileNotFound from '@salesforce/label/c.FEC_Label_FileNotFound';

/**
 * Chat history component for displaying messages associated with a Case record
 * Retrieves and formats chat messages, handles file attachments
 * Supports manual input for non-automation cases
 */
export default class ChatHistory extends LightningElement {
    @api recordId;
    chatMessages;
    error;
    wiredMessagesResult;
    @wire(MessageContext) messageContext;
    subscription = null;

    // Chat Automation flag
    isChatAutomation = false;
    // Manual input state
    manualMessage = '';
    isSaving = false;
    isSaved = false;

    // Custom Labels
    labelChatHistory = labelChatHistory;
    labelNoChatHistory = labelNoChatHistory;
    labelFileNotFound = labelFileNotFound;

    /**
     * Lifecycle hook: Register listener when component is connected
     * Subscribe to message channel to listen for chat updates
     */
    connectedCallback() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                FEC_CHAT_UPDATE,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    /**
     * Lifecycle hook: Unsubscribe when component is disconnected
     */
    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    /**
     * Handle incoming message from the chat update channel
     * Refresh chat messages if the update is for the current case
     */
    handleMessage(message) {
        if (message.recordId === this.recordId && this.wiredMessagesResult) {
            refreshApex(this.wiredMessagesResult);
        }
    }

    /**
     * Wire adapter to fetch chat messages for the current case
     */
    @wire(getChatMessages, { caseId: '$recordId' })
    wiredMessages(result) {
        this.wiredMessagesResult = result;
        const { error, data } = result;
        if (data) {
            this.isChatAutomation = data.isChatAutomation;
            const messages = data.messages;
            const fileMap = data.fileMap;
            this.chatMessages = messages.map(msg => {
                const isOutbound = msg.FEC_IsAgent__c;
                const isManual = msg.FEC_Is_Manual__c === true || msg.FEC_Is_Manual__c === 'true';
                const isFile = msg.FEC_MessageType__c === 'attachment' || msg.FEC_MessageType__c === 'image';
                let downloadUrl = null;
                let fileName = msg.FEC_Message__c;
                if (isFile) {
                    const fileId = fileMap[fileName];
                    if (fileId) {
                        downloadUrl = `/sfc/servlet.shepherd/version/download/${fileId}`;
                    }
                }
                return {
                    ...msg,
                    isOutbound,
                    isManual,
                    isFile,
                    isText: !isFile,
                    downloadUrl,
                    fileName,
                    bodyClass: isManual ? 'container-chat-history__body--manual w-full' : (isOutbound ? 'container-chat-history__body--outbound w-full' : 'container-chat-history__body--inbound w-full'),
                    itemClass: isManual ? 'slds-chat-list__item slds-chat-list__item_inbound' : (isOutbound ? 'slds-chat-list__item slds-chat-list__item_outbound' : 'slds-chat-list__item slds-chat-list__item_inbound'),
                    bubbleClass: isManual ? 'slds-chat-message__text slds-chat-message__text_manual' : (isOutbound ? 'slds-chat-message__text slds-chat-message__text_outbound' : 'slds-chat-message__text slds-chat-message__text_inbound'),
                    formattedTime: formatDatetimeLocal(msg.FEC_CreatedAt__c)
                };
            });

            // If not automation and already has messages, mark as saved (already submitted before)
            if (!this.isChatAutomation && this.chatMessages.length > 0) {
                this.isSaved = true;
            }
        } else if (error) {
            this.error = error;
        }
    }

    /**
     * Getter to check if there are any messages
     */
    get hasMessages() {
        return this.chatMessages && this.chatMessages.length > 0;
    }

    /**
     * Show manual input area when case is NOT chat automation and not yet saved
     */
    get showManualInput() {
        return !this.isChatAutomation && !this.isSaved;
    }

    /**
     * Disable save button when message is empty or currently saving
     */
    get isSaveDisabled() {
        return !this.manualMessage || this.manualMessage.trim() === '' || this.isSaving;
    }

    /**
     * Handle textarea input with auto-resize
     */
    handleMessageInput(event) {
        this.manualMessage = event.target.value;
        // Auto-resize textarea
        event.target.style.height = 'auto';
        event.target.style.height = event.target.scrollHeight + 'px';
    }

    /**
     * Save manual chat history message
     */
    async handleSaveMessage() {
        if (!this.manualMessage || this.manualMessage.trim() === '') return;

        this.isSaving = true;
        try {
            await saveManualChatHistory({
                caseId: this.recordId,
                message: this.manualMessage
            });
            this.isSaved = true;
            this.manualMessage = '';
            // Refresh to show the newly saved message in chat list
            await refreshApex(this.wiredMessagesResult);
        } catch (error) {
            console.error('Error saving chat history:', error);
            this.error = error;
        } finally {
            this.isSaving = false;
        }
    }
}
