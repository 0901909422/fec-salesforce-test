import { LightningElement, api, track, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { NavigationMixin } from "lightning/navigation";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";

// ================= APEX =================
import getInteraction from "@salesforce/apex/FEC_InteractionInforHandler.getInteraction";
import updateInteractionEmail from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionEmail";
import updateInteractionOnHold from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionOnHold";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionIdFromCustomerCase";

// ================= SCHEMA =================
import ISCLOSED from "@salesforce/schema/Case.IsClosed";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";

import CASE_OBJECT from "@salesforce/schema/Case";
import INTERACTION_EMAIL_FIELD from "@salesforce/schema/Case.FEC_Interaction_Email__c";
import CREATED_ON_FIELD from "@salesforce/schema/Case.FEC_Created_On__c";
 import CREATED_BY_FIELD from "@salesforce/schema/Case.FEC_Created_by__c";
import SEND_TO_FIELD from "@salesforce/schema/Case.FEC_Send_To__c";
import PARENT_ID_FIELD from "@salesforce/schema/Case.ParentId";
import ON_HOLD_FIELD from "@salesforce/schema/Case.FEC_On_Hold__c";
import CHANNEL_FIELD from "@salesforce/schema/Case.FEC_Channel__c";
import SUBCHANNEL_FIELD from "@salesforce/schema/Case.FEC_Interaction_Subchannel__c";

// ================= LABELS =================
import FEC_Interaction_Information_Label from "@salesforce/label/c.FEC_Interaction_Information_Label";
import FEC_Interaction_Email_Label from "@salesforce/label/c.FEC_Interaction_Email_Label";
import FEC_Interaction_Created_On_Label from "@salesforce/label/c.FEC_Interaction_Created_On_Label";
import FEC_Interaction_Created_By_Label from "@salesforce/label/c.FEC_Interaction_Created_By_Label";
import FEC_Send_To_Label from "@salesforce/label/c.FEC_Send_To_Label";
import FEC_Parent_ID_Label from "@salesforce/label/c.FEC_Parent_ID_Label";
import FEC_Interaction_Email_Input_Placeholder from "@salesforce/label/c.FEC_Interaction_Email_Input_Placeholder";
import FEC_Interaction_Email_Required_Msg from "@salesforce/label/c.FEC_Interaction_Email_Required_Msg";
import FEC_Interaction_Email_Invalid_Msg from "@salesforce/label/c.FEC_Interaction_Email_Invalid_Msg";
import FEC_Interaction_Email_Save_Error from "@salesforce/label/c.FEC_Interaction_Email_Save_Error";
import FEC_Empty from "@salesforce/label/c.FEC_Empty";
import FEC_On_Hold_Label from "@salesforce/label/c.FEC_On_Hold_Label";
import FEC_On_Hold_Help_Text from "@salesforce/label/c.FEC_On_Hold_Help_Text";
import UBankCustomberServiceEmail from "@salesforce/label/c.UBankCustomberServiceEmail";

import {
  STR_EMPTY,
  EMAIL_REGEX,
  VIEW_MODE_HANDLING,
  VIEW_MODE_REVIEW,
  RECORD_TYPE_INTERACTION,
  RECORD_TYPE_CUSTOMER_CASE,
  RECORD_TYPE_INTERNAL_CASE,
  NAV_ACTION_VIEW,
  CHANNEL_EMAIL,
  CHANNEL_INTERNAL,
  SUB_CHANNEL_INTERNAL_EMAIL,
} from "c/fec_CommonConst";
import { formatDateTimeVN } from "c/fec_CommonUtils";

export default class FecInteractionEmailInfo extends NavigationMixin(LightningElement) {
  labels = {
    interactionEmailInfo: FEC_Interaction_Information_Label,
    interactionEmail: FEC_Interaction_Email_Label,
    interactionCreatedOn: FEC_Interaction_Created_On_Label,
    interactionCreatedBy: FEC_Interaction_Created_By_Label,
    sendTo: FEC_Send_To_Label,
    parentId: FEC_Parent_ID_Label,
    inputPlaceholder: FEC_Interaction_Email_Input_Placeholder,
    emailRequiredMsg: FEC_Interaction_Email_Required_Msg,
    emailInvalidMsg: FEC_Interaction_Email_Invalid_Msg,
    emailSaveError: FEC_Interaction_Email_Save_Error,
    empty: FEC_Empty,
    onHold: FEC_On_Hold_Label,
    onHoldHelpText: FEC_On_Hold_Help_Text
  };

  @api recordId;

  @track record;
  @track emailDraft = STR_EMPTY;
  @track emailError = STR_EMPTY;

  isLoaded = false;
  isEditingEmail = false;

  isClosed = false;
  viewMode;
  recordTypeId;
  recordTypeDevName;

  interactionId;
  activeSections = ["interactionEmailInfo"];
  subscription = null;

  @wire(MessageContext)
  messageContext;

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

  connectedCallback() {
    this.loadStyles();
    this.subscribeToMessageChannel();
  }

  disconnectedCallback() {
    this.unsubscribeToMessageChannel();
  }

  // ================= LMS HANDLERS =================
  subscribeToMessageChannel() {
    if (!this.subscription) {
      this.subscription = subscribe(
        this.messageContext,
        IS_MODE_EDIT,
        (message) => this.handleMessage(message),
        { scope: APPLICATION_SCOPE }
      );
    }
  }

  unsubscribeToMessageChannel() {
    unsubscribe(this.subscription);
    this.subscription = null;
  }

  handleMessage(message) {
    if (message && typeof message.isModeEdit !== "undefined") {
      this.viewMode = message.isModeEdit ? VIEW_MODE_HANDLING : VIEW_MODE_REVIEW;
      // Close editing mode if switched to review
      if (!message.isModeEdit) {
        this.isEditingEmail = false;
        this.emailDraft = STR_EMPTY;
        this.emailError = STR_EMPTY;
      }
    }
  }

  loadStyles() {
    loadStyle(this, COMMON_STYLES).catch((e) =>
      console.error("Load style error", e)
    );
  }

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
  get isReview() {
    return this.viewMode === VIEW_MODE_REVIEW;
  }

  get isInteractionCase() {
    return this.recordTypeDevName === RECORD_TYPE_INTERACTION;
  }

  get isCustomerCase() {
    return (
      this.recordTypeDevName === RECORD_TYPE_CUSTOMER_CASE ||
      this.recordTypeDevName === RECORD_TYPE_INTERNAL_CASE
    );
  }

  get hasInteractionEmail() {
    return !!this.record?.[INTERACTION_EMAIL_FIELD.fieldApiName];
  }

  /**
   * Readonly: chỉ hiển thị text khi đã có dữ liệu và không đang edit.
   * Edit enable: khi đã có dữ liệu (click icon edit) hoặc khi trống (nhập mới).
   */
  get isEmailReadOnly() {
    return this.hasInteractionEmail && !this.isEditingEmail;
  }

  /** Chỉ hiện icon Edit khi trường trống (cho phép nhập mới). Có dữ liệu thì không hiện icon edit. */
  get showEmailEditIcon() {
    return !this.isReview && !this.hasInteractionEmail && !this.isEditingEmail;
  }

  get displayInteractionEmail() {
    return this.record?.[INTERACTION_EMAIL_FIELD.fieldApiName] || STR_EMPTY;
  }

  get createdOn() {
    return formatDateTimeVN(this.record?.[CREATED_ON_FIELD.fieldApiName]);
  }

  get createdBy() {
    return this.record?.[CREATED_BY_FIELD.fieldApiName] || STR_EMPTY;
  }

  get channel() {
    return (this.record?.[CHANNEL_FIELD.fieldApiName] || STR_EMPTY).trim();
  }

  get subChannel() {
    return (this.record?.[SUBCHANNEL_FIELD.fieldApiName] || STR_EMPTY).trim();
  }

  get sendTo() {
    return (this.record?.[SEND_TO_FIELD.fieldApiName] || STR_EMPTY).trim();
  }

  get showOnHold() {
    if (!this.record) return false;
    
    const channel = this.channel.toLowerCase();
    const subChannel = this.subChannel.toLowerCase();
    const sendTo = this.sendTo;

    // 1. Luôn ẩn nếu là Internal Email
    if (channel.includes("internal") && subChannel.includes("internal email")) {
      return false;
    }

    // 2. Hiển thị nếu là channel Email
    // Nếu quý khách thấy thông tin đã đủ mà vẫn ẩn, chúng tôi tạm bỏ check sendTo rỗng để đảm bảo nút xuất hiện
    return channel.includes("email") || channel === "email";
  }

  get onHold() {
    return this.record?.[ON_HOLD_FIELD.fieldApiName] || false;
  }

  get parentId() {
    return this.record?.[PARENT_ID_FIELD.fieldApiName] || STR_EMPTY;
  }

  get parentIdUrl() {
    if (!this.parentId) return null;
    return `/lightning/r/${CASE_OBJECT.objectApiName}/${this.parentId}/view`;
  }

  get showParentIdLink() {
    return !!this.parentId;
  }

  // ================= EMAIL/ON HOLD ACTIONS =================
  async handleOnHoldChange(event) {
    const isChecked = event.target.checked;
    if (!this.interactionId) return;

    try {
      await updateInteractionOnHold({
        recordId: this.interactionId,
        onHold: isChecked,
      });
      this.record = {
        ...this.record,
        [ON_HOLD_FIELD.fieldApiName]: isChecked,
      };
    } catch (error) {
      console.error("updateInteractionOnHold error", error);
      // Revert UI on error
      event.target.checked = !isChecked;
    }
  }

  handleEditEmail() {
    this.isEditingEmail = true;
    this.emailDraft = this.displayInteractionEmail || STR_EMPTY;
    this.emailError = STR_EMPTY;
  }

  handleEmailChange(event) {
    this.emailDraft = event.target.value;
    this.emailError = STR_EMPTY;
  }

  validateEmail(value) {
    if (!value || !value.trim()) return this.labels.emailRequiredMsg;
    if (!EMAIL_REGEX.test(value.trim())) return this.labels.emailInvalidMsg;
    return STR_EMPTY;
  }

  handleSaveEmail() {
    const trimmed = this.emailDraft?.trim() || STR_EMPTY;
    this.emailError = this.validateEmail(trimmed);
    if (this.emailError) return;
    if (!this.interactionId) return;

    updateInteractionEmail({
      recordId: this.interactionId,
      email: trimmed,
    })
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

  handleCancelEditEmail() {
    this.isEditingEmail = false;
    this.emailDraft = STR_EMPTY;
    this.emailError = STR_EMPTY;
  }

  handleNavigateToParent() {
    if (!this.parentId) return;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.parentId,
        objectApiName: CASE_OBJECT.objectApiName,
        actionName: NAV_ACTION_VIEW,
      },
    });
  }
}