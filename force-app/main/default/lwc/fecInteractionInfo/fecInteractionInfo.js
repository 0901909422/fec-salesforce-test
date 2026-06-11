import { LightningElement, api, track, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
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
import updateInteractionExternalId from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionExternalId";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionIdFromCustomerCase";

// ================= SCHEMA =================
import ISCLOSED from "@salesforce/schema/Case.IsClosed";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";
import PHONE_NUMBER from "@salesforce/schema/Case.FEC_Phone_Number__c";
import IS_MANUAL from "@salesforce/schema/Case.FEC_Is_Manual__c";
//==================== LABELED CONSTANTS ====================
import FEC_INTERACTION_PHONE_LABEL from "@salesforce/label/c.FEC_Interaction_Phone_Label";
import FEC_INTERACTION_CREATED_ON_LABEL from "@salesforce/label/c.FEC_Interaction_Created_On_Label";
import FEC_INTERACTION_CREATED_BY_LABEL from "@salesforce/label/c.FEC_Interaction_Created_By_Label";
import FEC_OUTCOME_CODE_LABEL from "@salesforce/label/c.FEC_Outcome_Code_Label";
import FEC_REMARKS_LABEL from "@salesforce/label/c.FEC_Interaction_Remark_Label";
import FEC_EXTERNAL_ID_LABEL from "@salesforce/label/c.FEC_External_Interaction_ID_Label";
import FEC_INTERACTION_CHANNEL_LABEL from "@salesforce/label/c.FEC_Interaction_Channel_Label";
import FEC_INTERACTION_SUB_CHANNEL_LABEL from "@salesforce/label/c.FEC_Interaction_Sub_Channel_Label";
import FEC_Interaction_Information_Label from "@salesforce/label/c.FEC_Interaction_Information_Label";

import FEC_PHONE_IS_REQUIRED_MSG from "@salesforce/label/c.FEC_PHONE_IS_REQUIRED_MSG";
import FEC_Complete_This_Field from "@salesforce/label/c.FEC_Complete_This_Field";
import FEC_PHONE_IS_INVALID_FORMAT_1_MSG from "@salesforce/label/c.FEC_PHONE_IS_INVALID_FORMAT_1_MSG";
import FEC_PHONE_IS_INVALID_FORMAT_2_MSG from "@salesforce/label/c.FEC_PHONE_IS_INVALID_FORMAT_2_MSG";
import FEC_PHONE_IS_INVALID_FORMAT_3_MSG from "@salesforce/label/c.FEC_PHONE_IS_INVALID_FORMAT_3_MSG";

import {
  formatDateTime,
  maskValue,
  normalizeInteractionResult,
} from "c/fec_CommonUtils";

import {
  RECORD_TYPES,
  VIEW_MODE_REVIEW,
  ICON_HIDE,
  ICON_PREVIEW,
  CLOSED_STATUS,
} from "c/fec_CommonConst";

export default class FecInteractionInfo extends LightningElement {
  labels = {
    interactionPhone: FEC_INTERACTION_PHONE_LABEL,
    interactionCreatedOn: FEC_INTERACTION_CREATED_ON_LABEL,
    interactionCreatedBy: FEC_INTERACTION_CREATED_BY_LABEL,
    outcomeCode: FEC_OUTCOME_CODE_LABEL,
    remarks: FEC_REMARKS_LABEL,
    externalId: FEC_EXTERNAL_ID_LABEL,
    channel: FEC_INTERACTION_CHANNEL_LABEL,
    subChannel: FEC_INTERACTION_SUB_CHANNEL_LABEL,
    interactionInformation: FEC_Interaction_Information_Label,
  };
  // ================= API =================
  @api recordId;

  // ================= STATE =================
  @track record;
  @track revealedPhone;
  @track phoneDraft;

  isLoaded = false;
  isMasked = true;
  isEditingPhone = false;

  isClosed = false;
  viewMode;
  recordTypeId;
  recordTypeDevName;

  interactionId;
  isManual = false;
  isEditingExternalId = false;
  externalIdDraft;
  activeSections = ["interactionInfo"];
  phoneRequiredMsg = FEC_PHONE_IS_REQUIRED_MSG;
  completeFieldMsg = FEC_Complete_This_Field;
  validatePhoneSubscription = null;

  @wire(MessageContext)
  messageContext;

  // ================= WIRE: CASE CONTEXT =================
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [ISCLOSED, VIEW_MODE, RECORDTYPE_ID, IS_MANUAL],
  })
  async wiredCase({ data, error }) {
    if (data) {
      this.isClosed = getFieldValue(data, ISCLOSED);
      this.viewMode = getFieldValue(data, VIEW_MODE);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);
      this.isManual = getFieldValue(data, IS_MANUAL);
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
        { scope: APPLICATION_SCOPE }
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

  @wire(getRecord, {
    recordId: "$interactionId",
    fields: [PHONE_NUMBER],
  })
  wiredInteractionPhone({ data }) {
    if (!data || !this.interactionId) {
      return;
    }

    const phone = getFieldValue(data, PHONE_NUMBER);
    if (phone && phone !== this.record?.FEC_Phone_Number__c) {
      this.loadInteraction();
    }
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
        this.record = normalizeInteractionResult(result);
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

  get isInteractionClosed() {
    if (
      this.record?.FEC_Interaction_Status__c === "Closed" ||
      this.record?.FEC_Interaction_Status__c === "Auto-Closed"
    )
      return true;
    return false;
  }

  get isReview() {
    return this.viewMode === VIEW_MODE_REVIEW;
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

    if (!this.isMasked) {
      return this.revealedPhone;
    }

    return (
      this.record?.FEC_Interaction_Masked_Phone__c ||
      maskValue(this.record?.FEC_Phone_Number__c, false)
    );
  }

  get canEditExternalId() {
    return this.isManual;
  }

  get eyeIcon() {
    return this.isMasked ? ICON_HIDE : ICON_PREVIEW;
  }

  get channel() {
    return this.record?.FEC_Channel__c;
  }

  get subChannel() {
    return this.record?.FEC_Interaction_Subchannel__c;
  }

  get externalId() {
    return this.record?.FEC_External_Interaction_ID__c;
  }

  get createdOn() {
    if (!this.record?.FEC_Created_On__c) return "";

    const d = new Date(this.record.FEC_Created_On__c);
    return formatDateTime(d);
  }

  get lastUpdatedOn() {
    if (!this.record?.FEC_Last_Updated_On_View__c) return "";

    const d = new Date(this.record.FEC_Last_Updated_On_View__c);
    return formatDateTime(d);
  }

  get createdBy() {
    return this.record?.FEC_Created_by__c;
  }

  get lastUpdatedBy() {
    return this.record?.FEC_Last_Updated_By_View__c;
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
      ["Inbound", "Outbound"].includes(this.record?.FEC_Channel__c)
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
    return !this.isReview && !this.hasPhone && (this.isEditingPhone || this.isPhoneRequired);
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

  handleEditExternalId() {
    this.isEditingExternalId = true;
    this.externalIdDraft = this.externalId || "";
  }

  handleExternalIdChange(event) {
    this.externalIdDraft = event.target.value;
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
    const input = this.template.querySelector('[data-id="interactionPhone"]');

    const value = (this.phoneDraft || "").trim();

    const isPhoneRequired =
      this.record?.FEC_Is_Manual__c === true &&
      ["Inbound", "Outbound"].includes(this.record?.FEC_Channel__c);

    if (isPhoneRequired && !value) {
      input.setCustomValidity(FEC_PHONE_IS_REQUIRED_MSG);
      input.reportValidity();
      return;
    }

    input.setCustomValidity("");

    if (!input || !input.checkValidity()) {
      input.reportValidity();
      return;
    }

    if (!value || !this.interactionId) {
      return;
    }

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

      await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    } catch (error) {
      console.error("updateInteractionPhone error", error);
    }
  }

  async handleSaveExternalId() {
    try {
      const result = await updateInteractionExternalId({
        recordId: this.interactionId,
        externalId: this.externalIdDraft,
      });

      console.log(JSON.stringify(result));

      this.record = {
        ...this.record,
        FEC_External_Interaction_ID__c: this.externalIdDraft,
      };

      this.isEditingExternalId = false;

      await notifyRecordUpdateAvailable([
        { recordId: this.recordId },
        { recordId: this.interactionId },
      ]);
    } catch (error) {
      console.error(
        "updateExternalId error",
        JSON.parse(JSON.stringify(error)),
      );

      console.error("message:", error?.body?.message);
      console.error("body:", error?.body);
      console.error("status:", error?.status);
      console.error("full:", error);
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

      // 🔥 refresh LDS nếu cần
      await notifyRecordUpdateAvailable([
        { recordId: this.recordId },
        { recordId: this.interactionId },
      ]);
    } catch (e) {
      console.error("revealPhone error", e);
    }
  }
}
