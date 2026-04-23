import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';
import VIEW_MODE from '@salesforce/schema/Case.FEC_Interaction_View_Mode__c';
import CHAT_HISTORY from '@salesforce/schema/Case.FEC_Chat_History__c';
import saveChatHistory from '@salesforce/apex/FEC_InteractionInforHandler.saveChatHistory';
import FEC_Conversations_Label from '@salesforce/label/c.FEC_Chat_Conversations_Label';
import FEC_Chat_History_Label from '@salesforce/label/c.FEC_Chat_History_Label';
import FEC_Button_Save from '@salesforce/label/c.FEC_Button_Save';
import FEC_Chat_Save_Failed from '@salesforce/label/c.FEC_Chat_Save_Failed';
import FEC_Save_Success_Title from '@salesforce/label/c.LBL_SaveSuccess';
import FEC_Save_Failed_Title from '@salesforce/label/c.LBL_SaveFailed';
import { VIEW_MODE_REVIEW, VIEW_MODE_HANDLING } from 'c/fec_CommonConst';

export default class FecInteractionChatConversations extends LightningElement {
    labels = {
        conversations: FEC_Conversations_Label,
        chatHistory: FEC_Chat_History_Label,
        save: FEC_Button_Save,
    };

    @api recordId;
    @track chatHistory = '';
    activeSections = ['conversations'];
    viewMode;
    subscription = null;

    @wire(MessageContext)
    messageContext;

    @wire(getRecord, { recordId: '$recordId', fields: [VIEW_MODE, CHAT_HISTORY] })
    wiredCase({ data, error }) {
        if (data) {
            this.viewMode = getFieldValue(data, VIEW_MODE);
            this.chatHistory = getFieldValue(data, CHAT_HISTORY) || '';
        }
    }

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(this.messageContext, IS_MODE_EDIT, (msg) => {
                if (msg && typeof msg.isModeEdit !== 'undefined') {
                    this.viewMode = msg.isModeEdit ? VIEW_MODE_HANDLING : VIEW_MODE_REVIEW;
                }
            }, { scope: APPLICATION_SCOPE });
        }
    }

    get isReview() { return this.viewMode === VIEW_MODE_REVIEW; }

    renderedCallback() {
        const ta = this.template.querySelector('.fec-conv-textarea');
        if (ta && ta.value !== this.chatHistory) {
            ta.value = this.chatHistory;
        }
    }

    handleChange(e) {
        this.chatHistory = e.target.value;
    }

    handleSave() {
        saveChatHistory({ recordId: this.recordId, chatHistory: this.chatHistory })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: FEC_Save_Success_Title, message: FEC_Save_Success_Title, variant: 'success' }));
            })
            .catch(e => {
                this.dispatchEvent(new ShowToastEvent({ title: FEC_Save_Failed_Title, message: e?.body?.message || FEC_Chat_Save_Failed, variant: 'error' }));
            });
    }
}
