import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';
import VALIDATE_INTERACTION_CHAT from '@salesforce/messageChannel/FEC_Validate_Interaction_Chat__c';

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
import FEC_Chat_Phone_Invalid from '@salesforce/label/c.FEC_Chat_Phone_Invalid';
import FEC_Chat_Save_Failed from '@salesforce/label/c.FEC_Chat_Save_Failed';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';

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
        phoneInvalid: FEC_Chat_Phone_Invalid,
        saveFailed: FEC_Chat_Save_Failed,
    };

    completeFieldMsg = FEC_Complete_This_Field;

    @api recordId;

    @track record;
    @track usernameDraft = STR_EMPTY;
    @track phoneDraft = STR_EMPTY;
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
    modeSubscription = null;
    validateChatSubscription = null;

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
        this.subscribeToMessageChannels();
    }

    disconnectedCallback() {
        this.unsubscribeFromMessageChannels();
    }

    subscribeToMessageChannels() {
        if (!this.modeSubscription) {
            this.modeSubscription = subscribe(this.messageContext, IS_MODE_EDIT, (msg) => {
                if (msg && typeof msg.isModeEdit !== 'undefined') {
                    this.viewMode = msg.isModeEdit ? VIEW_MODE_HANDLING : VIEW_MODE_REVIEW;
                    if (!msg.isModeEdit) {
                        this.isEditingUsername = false;
                        this.isEditingPhone = false;
                        this.isEditingKycStatus = false;
                        this.isEditingExternalInteractionId = false;
                        this.usernameDraft = STR_EMPTY;
                        this.phoneDraft = STR_EMPTY;
                        this.clearUsernameInputValidity();
                        this.clearPhoneInputValidity();
                    }
                }
            }, { scope: APPLICATION_SCOPE });
        }
        if (!this.validateChatSubscription) {
            this.validateChatSubscription = subscribe(
                this.messageContext,
                VALIDATE_INTERACTION_CHAT,
                (message) => this.handleValidateChatMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    unsubscribeFromMessageChannels() {
        if (this.modeSubscription) {
            unsubscribe(this.modeSubscription);
            this.modeSubscription = null;
        }
        if (this.validateChatSubscription) {
            unsubscribe(this.validateChatSubscription);
            this.validateChatSubscription = null;
        }
    }

    handleValidateChatMessage(message) {
        if (!message?.recordId || message.recordId !== this.recordId) {
            return;
        }
        this.showInlineChatRequiredErrors();
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

    get isReview() { return this.viewMode === VIEW_MODE_REVIEW; }
    get isInteractionCase() { return this.recordTypeDevName === RECORD_TYPE_INTERACTION; }
    get canEditChatFields() {
        return this.isInteractionCase && this.hasAccountOrContract !== true && this.record?.hasRelatedCustomerCase !== true;
    }
    get canEditManualInteractionFields() {
        return this.isInteractionCase && this.record?.FEC_Is_Manual__c === true;
    }

    get isManualChatInteraction() {
        if (this.record?.FEC_Is_Manual__c !== true) {
            return false;
        }
        const channel = this.record?.FEC_Channel__c;
        return channel === 'Chat' || channel == null;
    }

    get isUsernameRequired() {
        return !this.isReview && this.isManualChatInteraction && this.canEditChatFields;
    }

    get isPhoneRequired() {
        return false;
    }

    get customerUsername() { return this.record?.FEC_Customer_Username__c || STR_EMPTY; }
    get hasUsername() { return !!this.customerUsername?.trim(); }
    get maskedPhone() { return this.record?.FEC_Interaction_Masked_Phone__c || null; }
    get realPhone() { return this.record?.FEC_Phone_Number__c || STR_EMPTY; }
    get hasPhone() { return !!this.realPhone?.trim(); }
    get hasRequiredChatFields() {
        return this.hasUsername;
    }
    get createdOn() { return formatDateTimeVN(this.record?.FEC_Created_On__c); }
    get createdBy() { return this.record?.FEC_Created_by__c || STR_EMPTY; }
    get kycStatus() { return this.record?.FEC_KYC_Status__c || STR_EMPTY; }
    get externalInteractionId() { return this.record?.FEC_External_Interaction_ID__c || STR_EMPTY; }
    get outcomeCode() { return this.record?.FEC_Outcome_Code__c || STR_EMPTY; }
    get interactionRemark() { return this.record?.FEC_Interaction_Remarks__c || STR_EMPTY; }
    get showClosedOnlyFields() { return this.record?.IsClosed === true; }

    get isUsernameReadOnly() {
        if (!this.canEditChatFields || this.isReview) return true;
        if (this.hasUsername && !this.isEditingUsername) return true;
        if (!this.hasUsername && !this.isUsernameRequired && !this.isEditingUsername) return true;
        return false;
    }

    get showUsernameEditIcon() {
        return this.canEditChatFields && !this.isUsernameRequired && !this.hasUsername && !this.isEditingUsername;
    }

    get showUsernameSaveActions() {
        return this.canEditChatFields && !this.isReview && (this.isEditingUsername || (this.isUsernameRequired && !this.hasUsername));
    }

    get isPhoneReadOnly() {
        if (!this.canEditChatFields || this.isReview) return true;
        if (this.hasPhone && !this.isEditingPhone) return true;
        if (!this.hasPhone && !this.isPhoneRequired && !this.isEditingPhone) return true;
        return false;
    }

    get showPhoneEditIcon() {
        return this.canEditChatFields && !this.isPhoneRequired && !this.hasPhone && !this.isEditingPhone;
    }

    get showPhoneSaveActions() {
        return this.canEditChatFields && !this.isReview && (this.isEditingPhone || (this.isPhoneRequired && !this.hasPhone));
    }

    get isKycStatusReadOnly() {
        return !this.canEditManualInteractionFields || (!!this.kycStatus && !this.isEditingKycStatus);
    }
    get showKycStatusEditIcon() {
        return this.canEditManualInteractionFields && !this.isReview && !this.kycStatus && !this.isEditingKycStatus;
    }
    get isExternalInteractionIdReadOnly() {
        return !this.canEditManualInteractionFields
            || (!!this.externalInteractionId && !this.isEditingExternalInteractionId);
    }
    get showExternalInteractionIdEditIcon() {
        return this.canEditManualInteractionFields
            && !this.isReview
            && !this.externalInteractionId
            && !this.isEditingExternalInteractionId;
    }

    get displayPhone() {
        return this.maskedPhone || this.realPhone || '';
    }

    getUsernameInput() {
        return this.template.querySelector('[data-id="chat-username-input"]');
    }

    getPhoneInput() {
        return this.template.querySelector('[data-id="chat-phone-input"]');
    }

    clearUsernameInputValidity() {
        const input = this.getUsernameInput();
        if (input) {
            input.setCustomValidity(STR_EMPTY);
            input.reportValidity();
        }
    }

    clearPhoneInputValidity() {
        const input = this.getPhoneInput();
        if (input) {
            input.setCustomValidity(STR_EMPTY);
            input.reportValidity();
        }
    }

    showInlineChatRequiredErrors() {
        if (!this.isManualChatInteraction || this.isReview) {
            return false;
        }
        if (!this.canEditChatFields) {
            return false;
        }

        if (this.hasRequiredChatFields) {
            return false;
        }

        const needsUsername = this.isUsernameRequired && !this.hasUsername;
        // const needsPhone = this.isPhoneRequired && !this.hasPhone;
        if (!needsUsername ) {
            return false;
        }

        this.activeSections = ['interactionChatInfo'];
        if (needsUsername) {
            this.isEditingUsername = true;
            this.usernameDraft = this.usernameDraft || STR_EMPTY;
        }
        // if (needsPhone) {
        //     this.isEditingPhone = true;
        //     this.phoneDraft = this.phoneDraft || STR_EMPTY;
        // }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            let focused = false;
            if (needsUsername) {
                const usernameInput = this.getUsernameInput();
                if (usernameInput) {
                    usernameInput.setCustomValidity(FEC_Complete_This_Field);
                    usernameInput.reportValidity();
                    if (!focused) {
                        usernameInput.focus();
                        focused = true;
                    }
                }
            }
            // if (needsPhone) {
            //     const phoneInput = this.getPhoneInput();
            //     if (phoneInput) {
            //         phoneInput.setCustomValidity(FEC_Complete_This_Field);
            //         phoneInput.reportValidity();
            //         if (!focused) {
            //             phoneInput.focus();
            //         }
            //     }
            // }
        });

        return true;
    }

    handleEditUsername() {
        if (!this.canEditChatFields) return;
        this.isEditingUsername = true;
        this.usernameDraft = this.customerUsername;
        this.clearUsernameInputValidity();
    }

    handleUsernameChange(e) {
        this.usernameDraft = e.target.value;
        const input = e.target;
        input.setCustomValidity(STR_EMPTY);
        input.reportValidity();
    }

    handleCancelEditUsername() {
        this.isEditingUsername = false;
        this.usernameDraft = STR_EMPTY;
        this.clearUsernameInputValidity();
    }

    handleSaveUsername() {
        if (!this.canEditChatFields) return;
        const val = this.usernameDraft?.trim();
        if (!val) {
            if (this.isUsernameRequired) {
                this.showInlineChatRequiredErrors();
            }
            return;
        }
        updateChatInteractionFields({ recordId: this.recordId, username: val, phone: null, kycStatus: null, externalInteractionId: null })
            .then(() => {
                this.record = { ...this.record, FEC_Customer_Username__c: val };
                this.isEditingUsername = false;
                this.usernameDraft = STR_EMPTY;
                this.clearUsernameInputValidity();
            })
            .catch(e => {
                const input = this.getUsernameInput();
                if (input) {
                    input.setCustomValidity(e?.body?.message || this.labels.saveFailed);
                    input.reportValidity();
                }
            });
    }

    handleEditPhone() {
        if (!this.canEditChatFields) return;
        this.isEditingPhone = true;
        this.phoneDraft = this.realPhone;
        this.clearPhoneInputValidity();
    }

    handlePhoneChange(e) {
        this.phoneDraft = e.target.value;
        const input = e.target;
        const value = (this.phoneDraft || '').trim();
        input.setCustomValidity(STR_EMPTY);
        if (value && !PHONE_REGEX_0.test(value) && !PHONE_REGEX_84.test(value)) {
            input.setCustomValidity(this.labels.phoneInvalid);
        }
        input.reportValidity();
    }

    handleCancelEditPhone() {
        this.isEditingPhone = false;
        this.phoneDraft = STR_EMPTY;
        this.clearPhoneInputValidity();
    }

    handleEditKycStatus() {
        if (!this.canEditManualInteractionFields) return;
        this.isEditingKycStatus = true;
        this.kycDraft = this.kycStatus;
    }

    handleKycStatusChange(e) {
        this.kycDraft = e.target.value;
        this.kycError = STR_EMPTY;
    }

    handleCancelEditKycStatus() {
        this.isEditingKycStatus = false;
        this.kycDraft = STR_EMPTY;
        this.kycError = STR_EMPTY;
    }

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

    handleEditExternalInteractionId() {
        if (!this.canEditManualInteractionFields) return;
        this.isEditingExternalInteractionId = true;
        this.externalInteractionIdDraft = this.externalInteractionId;
    }

    handleExternalInteractionIdChange(e) {
        this.externalInteractionIdDraft = e.target.value;
        this.externalInteractionIdError = STR_EMPTY;
    }

    handleCancelEditExternalInteractionId() {
        this.isEditingExternalInteractionId = false;
        this.externalInteractionIdDraft = STR_EMPTY;
        this.externalInteractionIdError = STR_EMPTY;
    }

    handleSaveExternalInteractionId() {
        if (!this.canEditManualInteractionFields || this.isReview || this.externalInteractionId) return;
        const val = this.externalInteractionIdDraft?.trim();
        if (!val) return;
        updateChatInteractionFields({ recordId: this.recordId, username: null, phone: null, kycStatus: null, externalInteractionId: val })
            .then(() => {
                this.record = { ...this.record, FEC_External_Interaction_ID__c: val };
                this.isEditingExternalInteractionId = false;
                this.externalInteractionIdDraft = STR_EMPTY;
            })
            .catch(e => { this.externalInteractionIdError = e?.body?.message || this.labels.saveFailed; });
    }

    handleSavePhone() {
        if (!this.canEditChatFields) return;
        const input = this.getPhoneInput();
        const val = this.phoneDraft?.trim();
        if (!val) {
            if (this.isPhoneRequired) {
                this.showInlineChatRequiredErrors();
            }
            return;
        }
        if (!PHONE_REGEX_0.test(val) && !PHONE_REGEX_84.test(val)) {
            if (input) {
                input.setCustomValidity(this.labels.phoneInvalid);
                input.reportValidity();
            }
            return;
        }
        updateChatInteractionFields({ recordId: this.recordId, username: null, phone: val, kycStatus: null, externalInteractionId: null })
            .then(() => {
                this.record = { ...this.record, FEC_Phone_Number__c: val };
                this.isEditingPhone = false;
                this.phoneDraft = STR_EMPTY;
                this.clearPhoneInputValidity();
            })
            .catch(e => {
                if (input) {
                    input.setCustomValidity(e?.body?.message || this.labels.saveFailed);
                    input.reportValidity();
                }
            });
    }
}