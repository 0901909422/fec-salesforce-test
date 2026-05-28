import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getChatMessages from '@salesforce/apex/FEC_ChatHistoryController.getChatMessages';
import saveManualChatHistory from '@salesforce/apex/FEC_ChatHistoryController.saveManualChatHistory';
import { formatDatetimeLocal } from 'c/fecChathubUtils';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import FEC_CHAT_UPDATE from '@salesforce/messageChannel/FecChatUpdate__c';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';
import VIEW_MODE from '@salesforce/schema/Case.FEC_Interaction_View_Mode__c';
import labelNoChatHistory from '@salesforce/label/c.FEC_Label_NoChatHistory';
import labelFileNotFound from '@salesforce/label/c.FEC_Label_FileNotFound';
import { VIEW_MODE_REVIEW, VIEW_MODE_HANDLING } from 'c/fec_CommonConst';

/**
 * Chat history component for Case records.
 * - Automation cases: displays chat messages from FEC_ChatHistory__c records.
 * - Non-automation cases: allows user to manually input chat history (saved to Case.FEC_Chat_History__c).
 *   Once saved, the content is read-only.
 */
export default class ChatHistory extends LightningElement {
    @api recordId;
    chatMessages;
    error;
    wiredMessagesResult;
    @wire(MessageContext) messageContext;
    subscription = null;
    modeSubscription = null;
    activeSections = ['chatHistory'];

    isChatAutomation = false;
    manualMessage = '';
    manualChatHistoryContent = '';
    isSaving = false;
    viewMode;

    // Custom Labels
    labelChatHistory = 'Chat Conversation';
    labelNoChatHistory = labelNoChatHistory;
    labelFileNotFound = labelFileNotFound;

    @wire(getRecord, { recordId: '$recordId', fields: [VIEW_MODE] })
    wiredCase({ data }) {
        if (data) {
            this.viewMode = getFieldValue(data, VIEW_MODE);
        }
    }

    /**
     * Lifecycle hook: Register listener when component is connected
     * Subscribe to message channels
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
        if (!this.modeSubscription) {
            this.modeSubscription = subscribe(
                this.messageContext,
                IS_MODE_EDIT,
                (msg) => {
                    if (msg && typeof msg.isModeEdit !== 'undefined' && msg.caseId === this.recordId) {
                        this.viewMode = msg.isModeEdit ? VIEW_MODE_HANDLING : VIEW_MODE_REVIEW;
                    }
                },
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
        unsubscribe(this.modeSubscription);
        this.modeSubscription = null;
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
     * Sync manual message value into textarea after render
     */
    renderedCallback() {
        const ta = this.template.querySelector('.manual-textarea');
        if (ta && ta.value !== this.manualMessage) {
            ta.value = this.manualMessage;
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

            if (this.isChatAutomation) {
                // Automation case: map chat history records for display
                const fileMap = data.fileMap;
                this.chatMessages = data.messages.map(msg => {
                    const isOutbound = msg.FEC_IsAgent__c;
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
            } else {
                // Non-automation case: load existing manual history content if any
                if (data.hasManualChatHistory) {
                    this.manualChatHistoryContent = data.manualChatHistoryContent;
                    this.manualMessage = data.manualChatHistoryContent;
                }
            }
        } else if (error) {
            this.error = error;
        }
    }

    /**
     * Getter to check if there are any messages
     */
    get hasMessages() {
        return this.isChatAutomation && this.chatMessages && this.chatMessages.length > 0;
    }

    get formattedManualContent() {
        if (!this.manualChatHistoryContent) return '';
        return this.manualChatHistoryContent.replace(/\n/g, '<br>');
    }

    /**
     * Check if there is manual content to display
     */
    get hasManualContent() {
        return !!this.manualChatHistoryContent && this.manualChatHistoryContent.trim() !== '';
    }

    /**
     * Whether the case is in review mode (read-only)
     */
    get isReview() {
        return this.viewMode === VIEW_MODE_REVIEW;
    }

    /**
     * Show manual input area when case is NOT chat automation
     */
    get showManualInput() {
        return !this.isChatAutomation;
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
            this.manualChatHistoryContent = this.manualMessage;
            // Refresh wire cache
            await refreshApex(this.wiredMessagesResult);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Thành công',
                    message: 'Lưu chat thành công',
                    variant: 'success'
                })
            );
        } catch (error) {
            console.error('Error saving chat history:', error);
            this.error = error;
        } finally {
            this.isSaving = false;
        }
    }
}
