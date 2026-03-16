import { LightningElement, api, track, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";

// ================= APEX =================
import getInteraction from "@salesforce/apex/FEC_InteractionInforHandler.getInteraction";
import getInteractionPhoneReveal from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionPhoneReveal";
import updateInteractionPhone from "@salesforce/apex/FEC_InteractionInforHandler.updateInteractionPhone";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";
import getInteractionIdFromCustomerCase from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionIdFromCustomerCase";

// ================= SCHEMA =================
import ISCLOSED from "@salesforce/schema/Case.IsClosed";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";

//==================== LABELED CONSTANTS ====================
import FEC_INTERACTION_PHONE_LABEL from "@salesforce/label/c.FEC_Interaction_Phone_Label";
import FEC_INTERACTION_CREATED_ON_LABEL from "@salesforce/label/c.FEC_Interaction_Created_On_Label";
import FEC_INTERACTION_CREATED_BY_LABEL from "@salesforce/label/c.FEC_Interaction_Created_By_Label";
import FEC_Interaction_Information_Label from "@salesforce/label/c.FEC_Interaction_Information_Label";

import {
  formatDateTime,
  RECORD_TYPES,
  VIEW_MODE_HANDLING,
  VIEW_MODE_REVIEW,
} from "c/fec_CommonUtils";

export default class Fec_InteractionInfoF2F_Letter extends LightningElement {
  labels = {
    interactionPhone: FEC_INTERACTION_PHONE_LABEL,
    interactionCreatedOn: FEC_INTERACTION_CREATED_ON_LABEL,
    interactionCreatedBy: FEC_INTERACTION_CREATED_BY_LABEL,
    interactionInformation: FEC_Interaction_Information_Label,
  };
  // ================= API =================
  @api recordId;

  // ================= STATE =================
  record;
  revealedPhone;
  phoneDraft;

  isLoaded = false;
  isMasked = true;
  isEditingPhone = false;

  isClosed = false;
  viewMode;
  recordTypeId;
  recordTypeDevName;

  interactionId; // 🔥 ID dùng thực sự để load Interaction

  activeSections = ["interactionInfo"];

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

  get isReview() {
    return this.viewMode === VIEW_MODE_REVIEW;
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
    return this.isMasked ? "utility:hide" : "utility:preview";
  }

  get createdOn() {
    const value = this.record?.FEC_Created_On__c;
    if (!value) return "";
    return formatDateTime(new Date(value));
  }

  get createdBy() {
    return this.record?.FEC_Created_by__c;
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
  }

  handlePhoneChange(event) {
    this.phoneDraft = event.target.value;
  }

  handleSavePhone() {
    if (!this.phoneDraft || !this.interactionId) return;

    updateInteractionPhone({
      recordId: this.interactionId,
      phone: this.phoneDraft,
    })
      .then((maskedPhone) => {
        this.record = {
          ...this.record,
          FEC_Interaction_Masked_Phone__c: maskedPhone,
        };

        this.isEditingPhone = false;
        this.isMasked = true;
        this.phoneDraft = null;
      })
      .catch((error) => {
        console.error("updateInteractionPhone error", error);
      });
  }

  revealPhone() {
    if (!this.interactionId) return;

    getInteractionPhoneReveal({ recordId: this.interactionId })
      .then((result) => {
        this.revealedPhone = result;
        this.isMasked = false;
      })
      .catch((e) => console.error("revealPhone error", e));
  }
}
