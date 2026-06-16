import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import VALIDATE_INTERACTION_PHONE from "@salesforce/messageChannel/FEC_Validate_Interaction_Phone__c";
// ================= APEX =================
import getInteraction from "@salesforce/apex/FEC_InteractionInforHandler.getInteraction";
import getInteractionPhoneReveal from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionPhoneReveal";
import updateInteractionPhone from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionPhone";
import updateInteractionEmail from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionEmail";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionIdFromCustomerCase";

// ================= SCHEMA =================
import ISCLOSED from "@salesforce/schema/Case.IsClosed";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";
import INTERACTION_EMAIL_FIELD from "@salesforce/schema/Case.FEC_Interaction_Email__c";
//==================== LABELED CONSTANTS ====================
import FEC_INTERACTION_PHONE_LABEL from "@salesforce/label/c.FEC_Interaction_Phone_Label";
import FEC_INTERACTION_CREATED_ON_LABEL from "@salesforce/label/c.FEC_Interaction_Created_On_Label";
import FEC_INTERACTION_CREATED_BY_LABEL from "@salesforce/label/c.FEC_Interaction_Created_By_Label";
import FEC_Interaction_Information_Label from "@salesforce/label/c.FEC_Interaction_Information_Label";
import FEC_Interaction_Email_Label from "@salesforce/label/c.FEC_Interaction_Email_Label";
import FEC_PHONE_IS_REQUIRED_MSG from "@salesforce/label/c.FEC_PHONE_IS_REQUIRED_MSG";
import FEC_Complete_This_Field from "@salesforce/label/c.FEC_Complete_This_Field";
import FEC_PHONE_IS_INVALID_FORMAT_1_MSG from "@salesforce/label/c.FEC_PHONE_IS_INVALID_FORMAT_1_MSG";
import FEC_PHONE_IS_INVALID_FORMAT_2_MSG from "@salesforce/label/c.FEC_PHONE_IS_INVALID_FORMAT_2_MSG";
import FEC_PHONE_IS_INVALID_FORMAT_3_MSG from "@salesforce/label/c.FEC_PHONE_IS_INVALID_FORMAT_3_MSG";
import FEC_OUTCOME_CODE_LABEL from "@salesforce/label/c.FEC_Outcome_Code_Label";
import FEC_REMARKS_LABEL from "@salesforce/label/c.FEC_Interaction_Remark_Label";
import FEC_Interaction_Email_Invalid_Msg from "@salesforce/label/c.FEC_Interaction_Email_Invalid_Msg";
import FEC_Interaction_Email_Save_Error from "@salesforce/label/c.FEC_Interaction_Email_Save_Error";
import FEC_Empty from "@salesforce/label/c.FEC_Empty";
import { formatDateTime } from "c/fec_CommonUtils";

import {
  RECORD_TYPES,
  VIEW_MODE_REVIEW,
  ICON_HIDE,
  ICON_PREVIEW,
  CLOSED_STATUS,
  STR_EMPTY,
  EMAIL_REGEX,
} from "c/fec_CommonConst";

const MANUAL_PHONE_CHANNELS = new Set([
  "Inbound",
  "Outbound",
  "F2F",
  "Letter",
  "External",
]);
const SUBCHANNEL_INTERNAL_EMAIL = "Internal Email";

function isManualPhoneRequiredChannel(record) {
  if (!record) {
    return false;
  }
  const channel = record.FEC_Channel__c;
  if (MANUAL_PHONE_CHANNELS.has(channel)) {
    return true;
  }
  if (channel === "Internal") {
    return record.FEC_Interaction_Subchannel__c !== SUBCHANNEL_INTERNAL_EMAIL;
  }
  return false;
}

export default class Fec_InteractionInfoF2F_Letter extends LightningElement {
  labels = {
    interactionPhone: FEC_INTERACTION_PHONE_LABEL,
    interactionEmail: FEC_Interaction_Email_Label,
    interactionCreatedOn: FEC_INTERACTION_CREATED_ON_LABEL,
    interactionCreatedBy: FEC_INTERACTION_CREATED_BY_LABEL,
    interactionInformation: FEC_Interaction_Information_Label,
    outcomeCode: FEC_OUTCOME_CODE_LABEL,
    remarks: FEC_REMARKS_LABEL,
    emailInvalidMsg: FEC_Interaction_Email_Invalid_Msg,
    emailSaveError: FEC_Interaction_Email_Save_Error,
    empty: FEC_Empty,
  };
  // ================= API =================
  @api recordId;

  // ================= STATE =================
  record;
  revealedPhone;
  phoneDraft;

  @track emailDraft = STR_EMPTY;
  @track emailError = STR_EMPTY;
  isEditingEmail = false;

  isLoaded = false;
  isMasked = true;
  isEditingPhone = false;

  isClosed = false;
  viewMode;
  recordTypeId;
  recordTypeDevName;

  interactionId;

  activeSections = ["interactionInfo"];
  completeFieldMsg = FEC_Complete_This_Field;
  validatePhoneSubscription = null;

  @wire(MessageContext)
  messageContext;

  // ================= WIRE: CASE CONTEXT =================
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [ISCLOSED, VIEW_MODE, RECORDTYPE_ID],
  })
  async wiredCase({ data, error }) {
    if (data) {
      this.isClosed = getFieldValue(data, ISCLOSED);
      this.viewMode = getFieldValue(data, VIEW_MODE);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);

      await this.resolveRecordType();
      await this.resolveInteractionId();

      this.loadInteraction();
    } else if (error) {
      console.error("getRecord error", error);
    }
  }

  // ================= LIFECYCLE =================
  connectedCallback() {
    this.loadStyles();
    this.subscribeToValidatePhoneChannel();
  }

  disconnectedCallback() {
    this.unsubscribeFromValidatePhoneChannel();
  }

  subscribeToValidatePhoneChannel() {
    if (!this.validatePhoneSubscription) {
      this.validatePhoneSubscription = subscribe(
        this.messageContext,
        VALIDATE_INTERACTION_PHONE,
        (message) => this.handleValidatePhoneMessage(message),
        { scope: APPLICATION_SCOPE },
      );
    }
  }

  unsubscribeFromValidatePhoneChannel() {
    if (this.validatePhoneSubscription) {
      unsubscribe(this.validatePhoneSubscription);
      this.validatePhoneSubscription = null;
    }
  }

  handleValidatePhoneMessage(message) {
    if (!message?.recordId || message.recordId !== this.recordId) {
      return;
    }
    this.showInlinePhoneRequiredError();
  }

  loadStyles() {
    loadStyle(this, COMMON_STYLES).catch((e) =>
      console.error("Load style error", e),
    );
  }

  // ================= RECORD TYPE =================
  async resolveRecordType() {
    if (!this.recordTypeId) return;

    try {
      this.recordTypeDevName = await getRecordTypeName({
        recordId: this.recordId,
      });
    } catch (e) {
      console.error("getRecordTypeName error", e);
    }
  }

  // ================= INTERACTION ID =================
  async resolveInteractionId() {
    if (this.isInteractionCase) {
      this.interactionId = this.recordId;
    } else if (this.isCustomerCase) {
      try {
        this.interactionId = await getInteractionIdFromCustomerCase({
          caseId: this.recordId,
        });
      } catch (e) {
        console.error("getInteractionIdFromCustomerCase error", e);
      }
    }
  }

  // ================= LOAD INTERACTION =================
  loadInteraction() {
    if (!this.interactionId) return;

    getInteraction({ recordId: this.interactionId })
      .then((result) => {
        this.record = result;
        this.isLoaded = true;
      })
      .catch((error) => {
        console.error("getInteraction error", error);
      });
  }

  // ================= GETTERS =================
  get isInteractionCase() {
    return this.recordTypeDevName === RECORD_TYPES.INTERACTION;
  }

  get isCustomerCase() {
    return this.recordTypeDevName === RECORD_TYPES.CUSTOMER_CASE;
  }

  get hasInteractionEmail() {
    return !!this.record?.[INTERACTION_EMAIL_FIELD.fieldApiName];
  }

  get isEmailReadOnly() {
    return this.hasInteractionEmail && !this.isEditingEmail;
  }

  get showEmailEditIcon() {
    return !this.hasInteractionEmail && !this.isEditingEmail;
  }

  get displayInteractionEmail() {
    return this.record?.[INTERACTION_EMAIL_FIELD.fieldApiName] || STR_EMPTY;
  }

  get isReview() {
    return this.viewMode === VIEW_MODE_REVIEW;
  }

  get isInteractionClosed() {
    if (
      this.record?.FEC_Interaction_Status__c === CLOSED_STATUS ||
      this.record?.FEC_Interaction_Status__c === "Auto-Closed"
    ) {
      return true;
    }
    return false;
  }

  get showField() {
    return this.isReview && this.isInteractionClosed;
  }

  get hasPhone() {
    return !!(
      this.record?.FEC_Phone_Number__c ||
      this.record?.FEC_Interaction_Masked_Phone__c
    );
  }

  get displayPhone() {
    if (!this.hasPhone) return null;

    return this.isMasked
      ? this.record?.FEC_Interaction_Masked_Phone__c
      : this.revealedPhone;
  }

  get eyeIcon() {
    return this.isMasked ? ICON_HIDE : ICON_PREVIEW;
  }

  get createdOn() {
    const value = this.record?.FEC_Created_On__c;
    if (!value) return "";
    return formatDateTime(new Date(value));
  }

  get createdBy() {
    return this.record?.FEC_Created_by__c;
  }

  get outcomeCode() {
    return this.record?.FEC_Outcome_Code__c;
  }

  get interactionRemark() {
    return this.record?.FEC_Interaction_Remarks__c;
  }

  get isPhoneRequired() {
    return (
      !this.isReview &&
      this.record?.FEC_Is_Manual__c === true &&
      isManualPhoneRequiredChannel(this.record)
    );
  }

  get isPhoneReadOnly() {
    if (this.isReview) {
      return true;
    }
    if (this.hasPhone && !this.isEditingPhone) {
      return true;
    }
    if (!this.hasPhone && !this.isPhoneRequired && !this.isEditingPhone) {
      return true;
    }
    return false;
  }

  get showPhoneEditIcon() {
    return !this.isPhoneRequired && !this.hasPhone && !this.isEditingPhone;
  }

  get showPhoneSaveIcon() {
    return (
      !this.isReview &&
      !this.hasPhone &&
      (this.isEditingPhone || this.isPhoneRequired)
    );
  }

  getPhoneInput() {
    return this.template.querySelector('[data-id="interactionPhone"]');
  }

  clearPhoneInputValidity() {
    const input = this.getPhoneInput();
    if (input) {
      input.setCustomValidity("");
      input.reportValidity();
    }
  }

  showInlinePhoneRequiredError() {
    if (!this.isPhoneRequired || this.record?.FEC_Phone_Number__c) {
      return false;
    }

    this.activeSections = ["interactionInfo"];
    this.isEditingPhone = true;
    this.phoneDraft = this.phoneDraft || "";

    // eslint-disable-next-line @lwc/lwc/no-async-operation
    requestAnimationFrame(() => {
      const input = this.getPhoneInput();
      if (input) {
        input.setCustomValidity(FEC_Complete_This_Field);
        input.reportValidity();
        input.focus();
      }
    });

    return true;
  }

  // ================= PHONE ACTIONS =================
  handleToggleMask() {
    if (this.isMasked) {
      this.revealPhone();
    } else {
      this.isMasked = true;
    }
  }

  handleEditPhone() {
    this.isEditingPhone = true;
    this.phoneDraft = "";
    this.clearPhoneInputValidity();
  }

  handlePhoneChange(event) {
    this.phoneDraft = event.target.value;

    const input = event.target;
    const value = (this.phoneDraft || "").trim();

    input.setCustomValidity("");

    if (this.isPhoneRequired && !value) {
      input.setCustomValidity(FEC_PHONE_IS_REQUIRED_MSG);
    } else if (value) {
      if (value.startsWith("0")) {
        if (!/^\d{10}$/.test(value)) {
          input.setCustomValidity(FEC_PHONE_IS_INVALID_FORMAT_1_MSG);
        }
      } else if (value.startsWith("84")) {
        if (!/^\d{11}$/.test(value)) {
          input.setCustomValidity(FEC_PHONE_IS_INVALID_FORMAT_2_MSG);
        }
      } else {
        input.setCustomValidity(FEC_PHONE_IS_INVALID_FORMAT_3_MSG);
      }
    }

    input.reportValidity();
  }

  async handleSavePhone() {
    const input = this.getPhoneInput();
    const value = (this.phoneDraft || "").trim();

    const isPhoneRequired =
      this.record?.FEC_Is_Manual__c === true &&
      isManualPhoneRequiredChannel(this.record);

    if (isPhoneRequired && !value) {
      input.setCustomValidity(FEC_PHONE_IS_REQUIRED_MSG);
      input.reportValidity();
      return;
    }

    if (input) {
      input.setCustomValidity("");
    }

    if (!input || !input.checkValidity()) {
      input?.reportValidity();
      return;
    }

    if (!value || !this.interactionId) return;

    try {
      const maskedPhone = await updateInteractionPhone({
        recordId: this.interactionId,
        phone: value,
      });

      this.record = {
        ...this.record,
        FEC_Interaction_Masked_Phone__c: maskedPhone,
        FEC_Phone_Number__c: value,
      };

      this.isEditingPhone = false;
      this.isMasked = true;
      this.phoneDraft = null;
    } catch (error) {
      console.error("updateInteractionPhone error", error);
    }
  }

  async revealPhone() {
    if (!this.interactionId) return;

    try {
      const result = await getInteractionPhoneReveal({
        recordId: this.interactionId,
      });

      this.revealedPhone = result;
      this.isMasked = false;
    } catch (e) {
      console.error("revealPhone error", e);
    }
  }

  // ================= EMAIL ACTIONS =================
  handleEditEmail() {
    this.isEditingEmail = true;
    this.emailDraft = STR_EMPTY;
    this.emailError = STR_EMPTY;
  }

  handleEmailChange(event) {
    this.emailDraft = event.target.value;
    this.emailError = STR_EMPTY;
  }

  validateEmail(value) {
    if (!EMAIL_REGEX.test(value.trim())) return this.labels.emailInvalidMsg;
    return STR_EMPTY;
  }

  handleSaveEmail() {
    const trimmed = this.emailDraft?.trim() || "";
    this.emailError = this.validateEmail(trimmed);
    if (this.emailError) return;
    if (!this.interactionId) return;

    updateInteractionEmail({ recordId: this.interactionId, email: trimmed })
      .then(() => {
        this.record = {
          ...this.record,
          [INTERACTION_EMAIL_FIELD.fieldApiName]: trimmed,
        };
        this.isEditingEmail = false;
        this.emailDraft = STR_EMPTY;
        this.emailError = STR_EMPTY;
      })
      .catch((error) => {
        console.error("updateInteractionEmail error", error);
        this.emailError = error?.body?.message || this.labels.emailSaveError;
      });
  }
}