import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';

import getChatInteractionInfo from '@salesforce/apex/FEC_InteractionInforHandler.getChatInteractionInfo';
import updateChatInteractionFields from '@salesforce/apex/FEC_InteractionInforHandler.updateChatInteractionFields';

import ISCLOSED from '@salesforce/schema/Case.IsClosed';
import VIEW_MODE from '@salesforce/schema/Case.FEC_Interaction_View_Mode__c';

import FEC_Interaction_Information_Label from '@salesforce/label/c.FEC_Interaction_Information_Label';
import FEC_Interaction_Created_On_Label from '@salesforce/label/c.FEC_Interaction_Created_On_Label';
import FEC_Interaction_Created_By_Label from '@salesforce/label/c.FEC_Interaction_Created_By_Label';
import FEC_Chat_Customer_Username_Label from '@salesforce/label/c.FEC_Chat_Customer_Username_Label';
import FEC_Chat_Interaction_Phone_Label from '@salesforce/label/c.FEC_Chat_Interaction_Phone_Label';
import FEC_Chat_KYC_Status_Label from '@salesforce/label/c.FEC_Chat_KYC_Status_Label';
import FEC_Chat_External_Interaction_ID_Label from '@salesforce/label/c.FEC_Chat_External_Interaction_ID_Label';
import FEC_Outcome_Code_Label from '@salesforce/label/c.FEC_Outcome_Code_Label';
import FEC_Interaction_Remark_Label from '@salesforce/label/c.FEC_Interaction_Remark_Label';
import FEC_Chat_Username_Placeholder from '@salesforce/label/c.FEC_Chat_Username_Placeholder';
import FEC_Chat_Phone_Placeholder from '@salesforce/label/c.FEC_Chat_Phone_Placeholder';
import FEC_Chat_Username_Required from '@salesforce/label/c.FEC_Chat_Username_Required';
import FEC_Chat_Phone_Required from '@salesforce/label/c.FEC_Chat_Phone_Required';
import FEC_Chat_Phone_Invalid from '@salesforce/label/c.FEC_Chat_Phone_Invalid';
import FEC_Chat_Save_Failed from '@salesforce/label/c.FEC_Chat_Save_Failed';

import { VIEW_MODE_HANDLING, VIEW_MODE_REVIEW, STR_EMPTY } from 'c/fec_CommonConst';
import { formatDateTimeVN } from 'c/fec_CommonUtils';

const PHONE_REGEX_0 = /^0\d{9}$/;
const PHONE_REGEX_84 = /^84\d{9}$/;

export default class FecInteractionChatInfo extends LightningElement {
    labels = {
        interactionInformation: FEC_Interaction_Information_Label,
        interactionCreatedOn: FEC_Interaction_Created_On_Label,
        interactionCreatedBy: FEC_Interaction_Created_By_Label,
        customerUsername: FEC_Chat_Customer_Username_Label,
        interactionPhone: FEC_Chat_Interaction_Phone_Label,
        kycStatus: FEC_Chat_KYC_Status_Label,
        externalInteractionId: FEC_Chat_External_Interaction_ID_Label,
        outcomeCode: FEC_Outcome_Code_Label,
        interactionRemark: FEC_Interaction_Remark_Label,
        usernamePlaceholder: FEC_Chat_Username_Placeholder,
        phonePlaceholder: FEC_Chat_Phone_Placeholder,
        usernameRequired: FEC_Chat_Username_Required,
        phoneRequired: FEC_Chat_Phone_Required,
        phoneInvalid: FEC_Chat_Phone_Invalid,
        saveFailed: FEC_Chat_Save_Failed,
    };

    @api recordId;

    @track record;
    @track usernameDraft = STR_EMPTY;
    @track usernameError = STR_EMPTY;
    @track phoneDraft = STR_EMPTY;
    @track phoneError = STR_EMPTY;

    isEditingUsername = false;
    isEditingPhone = false;
    viewMode;
    activeSections = ['interactionChatInfo'];
    subscription = null;

    @wire(MessageContext)
    messageContext;

    @wire(getRecord, { recordId: '$recordId', fields: [ISCLOSED, VIEW_MODE] })
    wiredCase({ data, error }) {
        if (data) {
            this.viewMode = getFieldValue(data, VIEW_MODE);
            this.loadRecord();
        } else if (error) {
            console.error('getRecord error', error);
        }
    }

    connectedCallback() {
        loadStyle(this, COMMON_STYLES).catch(e => console.error('Load style error', e));
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(this.messageContext, IS_MODE_EDIT, (msg) => {
                if (msg && typeof msg.isModeEdit !== 'undefined') {
                    this.viewMode = msg.isModeEdit ? VIEW_MODE_HANDLING : VIEW_MODE_REVIEW;
                    if (!msg.isModeEdit) {
                        this.isEditingUsername = false;
                        this.isEditingPhone = false;
                    }
                }
            }, { scope: APPLICATION_SCOPE });
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    loadRecord() {
        if (!this.recordId) return;
        getChatInteractionInfo({ recordId: this.recordId })
            .then(result => { this.record = result; })
            .catch(e => console.error('getChatInteractionInfo error', e));
    }

    // ===== GETTERS =====
    get isReview() { return this.viewMode === VIEW_MODE_REVIEW; }

    get customerUsername() { return this.record?.FEC_Customer_Username__c || STR_EMPTY; }
    get maskedPhone() { return this.record?.FEC_Interaction_Masked_Phone__c || null; }
    get realPhone() { return this.record?.FEC_Phone_Number__c || STR_EMPTY; }
    get createdOn() { return formatDateTimeVN(this.record?.FEC_Created_On__c); }
    get createdBy() { return this.record?.FEC_Created_by__c || STR_EMPTY; }
    get kycStatus() { return this.record?.FEC_KYC_Status__c || STR_EMPTY; }
    get externalInteractionId() { return this.record?.FEC_External_Interaction_ID__c || STR_EMPTY; }
    get outcomeCode() { return this.record?.FEC_Outcome_Code__c || STR_EMPTY; }
    get interactionRemark() { return this.record?.FEC_Interaction_Remarks__c || STR_EMPTY; }

    get isUsernameReadOnly() { return !!this.customerUsername && !this.isEditingUsername; }
    get showUsernameEditIcon() { return !this.isReview && !this.isEditingUsername; }

    get isPhoneReadOnly() { return !!(this.maskedPhone || this.realPhone) && !this.isEditingPhone; }
    get showPhoneEditIcon() { return !this.isReview && !this.isEditingPhone; }

    get displayPhone() {
        return this.maskedPhone || this.realPhone || '';
    }

    // ===== USERNAME ACTIONS =====
    handleEditUsername() { this.isEditingUsername = true; this.usernameDraft = this.customerUsername; }
    handleUsernameChange(e) { this.usernameDraft = e.target.value; this.usernameError = STR_EMPTY; }
    handleCancelEditUsername() { this.isEditingUsername = false; this.usernameDraft = STR_EMPTY; this.usernameError = STR_EMPTY; }
    handleSaveUsername() {
        const val = this.usernameDraft?.trim();
        if (!val) { this.usernameError = this.labels.usernameRequired; return; }
        updateChatInteractionFields({ recordId: this.recordId, username: val, phone: null })
            .then(() => {
                this.record = { ...this.record, FEC_Customer_Username__c: val };
                this.isEditingUsername = false;
                this.usernameDraft = STR_EMPTY;
            })
            .catch(e => { this.usernameError = e?.body?.message || this.labels.saveFailed; });
    }

    // ===== PHONE ACTIONS =====
    handleEditPhone() { this.isEditingPhone = true; this.phoneDraft = this.realPhone; }
    handlePhoneChange(e) { this.phoneDraft = e.target.value; this.phoneError = STR_EMPTY; }
    handleCancelEditPhone() { this.isEditingPhone = false; this.phoneDraft = STR_EMPTY; this.phoneError = STR_EMPTY; }
    handleSavePhone() {
        const val = this.phoneDraft?.trim();
        if (!val) { this.phoneError = this.labels.phoneRequired; return; }
        if (!PHONE_REGEX_0.test(val) && !PHONE_REGEX_84.test(val)) {
            this.phoneError = this.labels.phoneInvalid;
            return;
        }
        updateChatInteractionFields({ recordId: this.recordId, username: null, phone: val })
            .then(() => {
                this.record = { ...this.record, FEC_Phone_Number__c: val };
                this.isEditingPhone = false;
                this.phoneDraft = STR_EMPTY;
            })
            .catch(e => { this.phoneError = e?.body?.message || this.labels.saveFailed; });
    }
}