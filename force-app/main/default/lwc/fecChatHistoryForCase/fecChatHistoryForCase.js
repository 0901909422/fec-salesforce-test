import { LightningElement, api, wire } from 'lwc';
import getChatMessages from '@salesforce/apex/FEC_ChatHistoryController.getChatMessages';
import { formatDatetimeLocal } from 'c/fecUtils';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import FEC_CHAT_UPDATE from '@salesforce/messageChannel/FecChatUpdate__c';

/**
 * Chat history component for displaying messages associated with a Case record
 * Retrieves and formats chat messages, handles file attachments
 */
export default class ChatHistory extends LightningElement {
    @api recordId;
    chatMessages;
    error;
    wiredMessagesResult;
    @wire(MessageContext) messageContext;
    subscription = null;

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
                { scope: APPLICATION_SCOPE } // Important to capture events from Utility Bar
            );
        }
    }

    /**
     * Lifecycle hook: Unsubscribe when component is disconnected
     * Prevent memory leaks by cleaning up message channel subscriptions
     */
    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    /**
     * Handle incoming message from the chat update channel
     * Refresh chat messages if the update is for the current case
     * @param {Object} message - Message object containing recordId from the channel
     */
    handleMessage(message) {
        // Verify the correct Case ID is open before refreshing
        if (message.recordId === this.recordId && this.wiredMessagesResult) {
            refreshApex(this.wiredMessagesResult);
        }
    }


    /**
     * Wire adapter to fetch chat messages for the current case
     * @param {Object} error - Error object if request fails
     * @param {Object} data - Response containing messages and file map
     * @return {void}
     */
    @wire(getChatMessages, { caseId: '$recordId' })
    wiredMessages(result) {
        this.wiredMessagesResult = result;
        const { error, data } = result;
        if (data) {
            const messages = data.messages;
            const fileMap = data.fileMap;
            this.chatMessages = messages.map(msg => {
                // Logic: If the record creator is the current user, consider it an outgoing message (Outbound)
                const isOutbound = msg.FEC_IsAgent__c;
                const isFile = msg.FEC_MessageType__c === 'attachment' || msg.FEC_MessageType__c === 'image';
                let downloadUrl = null;
                let fileName = msg.FEC_Message__c;
                if (isFile) {
                    // Find file ID based on filename stored in message
                    const fileId = fileMap[fileName];
                    if (fileId) {
                        downloadUrl = `/sfc/servlet.shepherd/version/download/${fileId}`;
                    }
                }
                return {
                    ...msg,
                    isOutbound,
                    isFile,
                    isText: !isFile,
                    downloadUrl,
                    fileName,
                    bodyClass: isOutbound ? 'container-chat-history__body--outbound w-full' : 'container-chat-history__body--inbound w-full',
                    itemClass: isOutbound ? 'slds-chat-list__item slds-chat-list__item_outbound' : 'slds-chat-list__item slds-chat-list__item_inbound',
                    bubbleClass: isOutbound ? 'slds-chat-message__text slds-chat-message__text_outbound' : 'slds-chat-message__text slds-chat-message__text_inbound',
                    formattedTime: formatDatetimeLocal(msg.FEC_CreatedAt__c)
                };
            });
        } else if (error) {
            this.error = error;
        }
    }

    /**
     * Getter to check if there are any messages
     * @return {boolean} - True if chatMessages array is not empty
     */
    get hasMessages() {
        return this.chatMessages && this.chatMessages.length > 0;
    }
}