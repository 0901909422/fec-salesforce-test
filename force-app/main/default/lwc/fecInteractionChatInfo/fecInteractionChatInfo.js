import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';

import getChatInteractionInfo from '@salesforce/apex/FEC_InteractionInforHandler.getChatInteractionInfo';
import updateChatInteractionFields from '@salesforce/apex/FEC_InteractionInforHandler.updateChatInteractionFields';
import getRecordTypeName from '@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName';

import ISCLOSED from '@salesforce/schema/Case.IsClosed';
import HAS_ACCOUNT_OR_CONTRACT from '@salesforce/schema/Case.FEC_Has_Account_or_Contract__c';
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

import { VIEW_MODE_HANDLING, VIEW_MODE_REVIEW, STR_EMPTY, RECORD_TYPE_INTERACTION } from 'c/fec_CommonConst';
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
    @track kycDraft = STR_EMPTY;
    @track kycError = STR_EMPTY;
    @track externalInteractionIdDraft = STR_EMPTY;
    @track externalInteractionIdError = STR_EMPTY;

    isEditingUsername = false;
    isEditingPhone = false;
    isEditingKycStatus = false;
    isEditingExternalInteractionId = false;
    viewMode;
    hasAccountOrContract = false;
    recordTypeDevName;
    activeSections = ['interactionChatInfo'];
    subscription = null;

    @wire(MessageContext)
    messageContext;

    @wire(getRecord, { recordId: '$recordId', fields: [ISCLOSED, VIEW_MODE, HAS_ACCOUNT_OR_CONTRACT] })
    wiredCase({ data, error }) {
        if (data) {
            this.viewMode = getFieldValue(data, VIEW_MODE);
            this.hasAccountOrContract = getFieldValue(data, HAS_ACCOUNT_OR_CONTRACT);
            this.loadRecordType();
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
                        this.isEditingKycStatus = false;
                        this.isEditingExternalInteractionId = false;
                    }
                }
            }, { scope: APPLICATION_SCOPE });
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    async loadRecordType() {
        if (!this.recordId) return;
        try {
            this.recordTypeDevName = await getRecordTypeName({ recordId: this.recordId });
        } catch (e) {
            console.error('getRecordTypeName error', e);
        }
    }
    loadRecord() {
        if (!this.recordId) return;
        getChatInteractionInfo({ recordId: this.recordId })
            .then(result => { this.record = result; })
            .catch(e => console.error('getChatInteractionInfo error', e));
    }

    // ===== GETTERS =====
    get isReview() { return this.viewMode === VIEW_MODE_REVIEW; }
    get isInteractionCase() { return this.recordTypeDevName === RECORD_TYPE_INTERACTION; }
    get canEditChatFields() {
        // 05/06/2026 10:00 tungnm37 - Allow edit only on new Interaction before selecting account/contract.
        return this.isInteractionCase && this.hasAccountOrContract !== true && this.record?.hasRelatedCustomerCase !== true;
    }
    get canEditManualInteractionFields() {
        return this.isInteractionCase && this.record?.FEC_Is_Manual__c === true;
    }

    get customerUsername() { return this.record?.FEC_Customer_Username__c || STR_EMPTY; }
    get maskedPhone() { return this.record?.FEC_Interaction_Masked_Phone__c || null; }
    get realPhone() { return this.record?.FEC_Phone_Number__c || STR_EMPTY; }
    get createdOn() { return formatDateTimeVN(this.record?.FEC_Created_On__c); }
    get createdBy() { return this.record?.FEC_Created_by__c || STR_EMPTY; }
    get kycStatus() { return this.record?.FEC_KYC_Status__c || STR_EMPTY; }
    get externalInteractionId() { return this.record?.FEC_External_Interaction_ID__c || STR_EMPTY; }
    get outcomeCode() { return this.record?.FEC_Outcome_Code__c || STR_EMPTY; }
    get interactionRemark() { return this.record?.FEC_Interaction_Remarks__c || STR_EMPTY; }
    get showClosedOnlyFields() { return this.record?.IsClosed === true; }

    get isUsernameReadOnly() { return !this.canEditChatFields || (!!this.customerUsername && !this.isEditingUsername); }
    get showUsernameEditIcon() { return this.canEditChatFields && !this.isEditingUsername; }

    get isPhoneReadOnly() { return !this.canEditChatFields || (!!(this.maskedPhone || this.realPhone) && !this.isEditingPhone); }
    get showPhoneEditIcon() { return this.canEditChatFields && !this.isEditingPhone; }

    get isKycStatusReadOnly() { return !this.canEditManualInteractionFields || !this.isEditingKycStatus; }
    get showKycStatusEditIcon() { return this.canEditManualInteractionFields && !this.isEditingKycStatus; }
    get isExternalInteractionIdReadOnly() { return !this.canEditManualInteractionFields || !this.isEditingExternalInteractionId; }
    get showExternalInteractionIdEditIcon() { return this.canEditManualInteractionFields && !this.isEditingExternalInteractionId; }

    get displayPhone() {
        return this.maskedPhone || this.realPhone || '';
    }

    // ===== USERNAME ACTIONS =====
    handleEditUsername() { if (!this.canEditChatFields) return; this.isEditingUsername = true; this.usernameDraft = this.customerUsername; }
    handleUsernameChange(e) { this.usernameDraft = e.target.value; this.usernameError = STR_EMPTY; }
    handleCancelEditUsername() { this.isEditingUsername = false; this.usernameDraft = STR_EMPTY; this.usernameError = STR_EMPTY; }
    handleSaveUsername() {
        if (!this.canEditChatFields) return;
        const val = this.usernameDraft?.trim();
        if (!val) { this.usernameError = this.labels.usernameRequired; return; }
        updateChatInteractionFields({ recordId: this.recordId, username: val, phone: null, kycStatus: null, externalInteractionId: null })
            .then(() => {
                this.record = { ...this.record, FEC_Customer_Username__c: val };
                this.isEditingUsername = false;
                this.usernameDraft = STR_EMPTY;
            })
            .catch(e => { this.usernameError = e?.body?.message || this.labels.saveFailed; });
    }


    // ===== MANUAL CHAT FIELDS ACTIONS =====
    handleEditKycStatus() { if (!this.canEditManualInteractionFields) return; this.isEditingKycStatus = true; this.kycDraft = this.kycStatus; }
    handleKycStatusChange(e) { this.kycDraft = e.target.value; this.kycError = STR_EMPTY; }
    handleCancelEditKycStatus() { this.isEditingKycStatus = false; this.kycDraft = STR_EMPTY; this.kycError = STR_EMPTY; }
    handleSaveKycStatus() {
        if (!this.canEditManualInteractionFields) return;
        const val = this.kycDraft?.trim() || null;
        updateChatInteractionFields({ recordId: this.recordId, username: null, phone: null, kycStatus: val, externalInteractionId: null })
            .then(() => {
                this.record = { ...this.record, FEC_KYC_Status__c: val || STR_EMPTY };
                this.isEditingKycStatus = false;
                this.kycDraft = STR_EMPTY;
            })
            .catch(e => { this.kycError = e?.body?.message || this.labels.saveFailed; });
    }

    handleEditExternalInteractionId() { if (!this.canEditManualInteractionFields) return; this.isEditingExternalInteractionId = true; this.externalInteractionIdDraft = this.externalInteractionId; }
    handleExternalInteractionIdChange(e) { this.externalInteractionIdDraft = e.target.value; this.externalInteractionIdError = STR_EMPTY; }
    handleCancelEditExternalInteractionId() { this.isEditingExternalInteractionId = false; this.externalInteractionIdDraft = STR_EMPTY; this.externalInteractionIdError = STR_EMPTY; }
    handleSaveExternalInteractionId() {
        if (!this.canEditManualInteractionFields) return;
        const val = this.externalInteractionIdDraft?.trim() || null;
        updateChatInteractionFields({ recordId: this.recordId, username: null, phone: null, kycStatus: null, externalInteractionId: val })
            .then(() => {
                this.record = { ...this.record, FEC_External_Interaction_ID__c: val || STR_EMPTY };
                this.isEditingExternalInteractionId = false;
                this.externalInteractionIdDraft = STR_EMPTY;
            })
            .catch(e => { this.externalInteractionIdError = e?.body?.message || this.labels.saveFailed; });
    }
    // ===== PHONE ACTIONS =====
    handleEditPhone() { if (!this.canEditChatFields) return; this.isEditingPhone = true; this.phoneDraft = this.realPhone; }
    handlePhoneChange(e) { this.phoneDraft = e.target.value; this.phoneError = STR_EMPTY; }
    handleCancelEditPhone() { this.isEditingPhone = false; this.phoneDraft = STR_EMPTY; this.phoneError = STR_EMPTY; }
    handleSavePhone() {
        if (!this.canEditChatFields) return;
        const val = this.phoneDraft?.trim();
        if (!val) { this.phoneError = this.labels.phoneRequired; return; }
        if (!PHONE_REGEX_0.test(val) && !PHONE_REGEX_84.test(val)) {
            this.phoneError = this.labels.phoneInvalid;
            return;
        }
        updateChatInteractionFields({ recordId: this.recordId, username: null, phone: val, kycStatus: null, externalInteractionId: null })
            .then(() => {
                this.record = { ...this.record, FEC_Phone_Number__c: val };
                this.isEditingPhone = false;
                this.phoneDraft = STR_EMPTY;
            })
            .catch(e => { this.phoneError = e?.body?.message || this.labels.saveFailed; });
    }
}
