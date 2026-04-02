import { LightningElement, api, track, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { NavigationMixin } from "lightning/navigation";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";

// ================= APEX =================
import getInteraction from "@salesforce/apex/FEC_InteractionInforHandler.getInteraction";
import updateInteractionEmail from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionEmail";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionIdFromCustomerCase";
import getParentCaseNumber from "@salesforce/apex/FEC_InteractionInforHandler.getParentCaseNumber";

// ================= SCHEMA =================
import ISCLOSED from "@salesforce/schema/Case.IsClosed";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";

import CASE_OBJECT from "@salesforce/schema/Case";
import INTERACTION_EMAIL_FIELD from "@salesforce/schema/Case.FEC_Interaction_Email__c";
import CREATED_ON_FIELD from "@salesforce/schema/Case.FEC_Created_On__c";
import CREATED_BY_FIELD from "@salesforce/schema/Case.FEC_Created_by__c";
import SEND_TO_FIELD from "@salesforce/schema/Case.FEC_Send_To__c";
import PARENT_ID_FIELD from "@salesforce/schema/Case.FEC_Parent_ID__c";
import EXTERNAL_INTERACTION_ID_FIELD from "@salesforce/schema/Case.FEC_External_Interaction_ID__c";

// ================= LABELS =================
import FEC_Interaction_Email_Info_Ubank_Label from "@salesforce/label/c.FEC_Interaction_Email_Info_Ubank_Label";
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
import FEC_External_Interaction_ID_Label from "@salesforce/label/c.FEC_External_Interaction_ID_Label";

import { STR_EMPTY, EMAIL_REGEX } from "c/fec_CommonConst";
import { formatDateTimeVN } from "c/fec_CommonUtils";

export default class FecInteractionEmailInfoUbank extends NavigationMixin(LightningElement) {
  labels = {
    sectionTitle: FEC_Interaction_Email_Info_Ubank_Label,
    interactionEmail: FEC_Interaction_Email_Label,
    interactionCreatedOn: FEC_Interaction_Created_On_Label,
    interactionCreatedBy: FEC_Interaction_Created_By_Label,
    sendTo: FEC_Send_To_Label,
    parentId: FEC_Parent_ID_Label,
    externalInteractionId: FEC_External_Interaction_ID_Label,
    inputPlaceholder: FEC_Interaction_Email_Input_Placeholder,
    emailRequiredMsg: FEC_Interaction_Email_Required_Msg,
    emailInvalidMsg: FEC_Interaction_Email_Invalid_Msg,
    emailSaveError: FEC_Interaction_Email_Save_Error,
    empty: FEC_Empty
  };

  @api recordId;

  @track record;
  @track emailDraft = STR_EMPTY;
  @track emailError = STR_EMPTY;
  @track parentCaseNumber = STR_EMPTY;

  isLoaded = false;
  isEditingEmail = false;
  isClosed = false;
  recordTypeId;
  recordTypeDevName;
  interactionId;
  activeSections = ["interactionEmailInfoUbank"];

  TARGET_ACTION_VIEW = "view";
  RECORD_TYPE_INTERACTION = "Interaction";
  RECORD_TYPE_CUSTOMER_CASE = "Customer_Case";

  @wire(getRecord, {
    recordId: "$recordId",
    fields: [ISCLOSED, VIEW_MODE, RECORDTYPE_ID]
  })
  async wiredCase({ data, error }) {
    if (data) {
      this.isClosed = getFieldValue(data, ISCLOSED);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);
      await this.resolveRecordType();
      await this.resolveInteractionId();
      this.loadInteraction();
    } else if (error) {
      console.error("getRecord error", error);
    }
  }

  connectedCallback() {
    loadStyle(this, COMMON_STYLES).catch((e) =>
      console.error("Load style error", e)
    );
  }

  async resolveRecordType() {
    if (!this.recordTypeId) return;
    try {
      this.recordTypeDevName = await getRecordTypeName({ recordId: this.recordId });
    } catch (e) {
      console.error("getRecordTypeName error", e);
    }
  }

  async resolveInteractionId() {
    if (this.isInteractionCase) {
      this.interactionId = this.recordId;
    } else if (this.isCustomerCase) {
      try {
        this.interactionId = await getInteractionIdFromCustomerCase({ caseId: this.recordId });
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
        getParentCaseNumber({ caseId: this.recordId })
          .then((num) => { this.parentCaseNumber = num || STR_EMPTY; })
          .catch(() => { this.parentCaseNumber = STR_EMPTY; });
      })
      .catch((error) => {
        console.error("getInteraction error", error);
      });
  }

  // ================= GETTERS =================
  get isInteractionCase() {
    return this.recordTypeDevName === this.RECORD_TYPE_INTERACTION;
  }

  get isCustomerCase() {
    return this.recordTypeDevName === this.RECORD_TYPE_CUSTOMER_CASE;
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

  get createdOn() {
    return formatDateTimeVN(this.record?.[CREATED_ON_FIELD.fieldApiName]);
  }

  get createdBy() {
    return this.record?.[CREATED_BY_FIELD.fieldApiName] || STR_EMPTY;
  }

  get sendTo() {
    return this.record?.[SEND_TO_FIELD.fieldApiName] || STR_EMPTY;
  }

  get parentId() {
    return this.parentCaseNumber || this.record?.ParentId || STR_EMPTY;
  }

  get showParentIdLink() {
    return !!(this.record?.ParentId || this.parentCaseNumber);
  }

  get externalInteractionId() {
    return this.record?.[EXTERNAL_INTERACTION_ID_FIELD.fieldApiName] || STR_EMPTY;
  }

  // ================= EMAIL ACTIONS =================
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
    const trimmed = this.emailDraft?.trim() || "";
    this.emailError = this.validateEmail(trimmed);
    if (this.emailError) return;
    if (!this.interactionId) return;

    updateInteractionEmail({ recordId: this.interactionId, email: trimmed })
      .then(() => {
        this.record = {
          ...this.record,
          [INTERACTION_EMAIL_FIELD.fieldApiName]: trimmed
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

  // ================= NAVIGATION =================
  handleNavigateToParent() {
    const pid = this.record?.ParentId;
    if (!pid) return;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: pid,
        objectApiName: CASE_OBJECT.objectApiName,
        actionName: this.TARGET_ACTION_VIEW
      }
    });
  }
}
