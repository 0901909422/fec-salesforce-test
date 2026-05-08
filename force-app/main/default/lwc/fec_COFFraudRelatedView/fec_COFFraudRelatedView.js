import { LightningElement, api, wire, track } from "lwc";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import { getRecord } from "lightning/uiRecordApi";
import CASE_OBJECT from "@salesforce/schema/Case";
import COMPLAINT_TYPE from "@salesforce/schema/Case.FEC_Complain_Type__c";
import COMPLAINT_SOURCE from "@salesforce/schema/Case.FEC_Complaint_Source__c";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import CASE_ACTION_CHANNEL from "@salesforce/messageChannel/FEC_CaseAction__c";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import getCategory from "@salesforce/apex/FEC_COFFraudRelatedHandler.getCategory";
import updateCase from "@salesforce/apex/FEC_COFFraudRelatedHandler.updateCase";
import {
  CATEGORY,
  COMPLAINT_TYPE_TEXT,
  COMPLAINT_SOURCE_LABEL,
} from "c/fec_CommonConst";
import { getFieldValue } from "lightning/uiRecordApi";
const FIELDS = [
  "Case.RecordTypeId",
  "Case.FEC_Complain_Type__c",
  "Case.FEC_Complaint_Source__c",
];
export default class Fec_COFFraudRelatedView extends LightningElement {
  @api recordId;

  @track complaintTypeOptions = [];
  @track complaintSourceOptions = [];

  @track complaintTypeValue = null;
  @track complaintSourceValue = null;

  productTypeId;
  categoryId;
  subCategoryId;
  natureOfCaseId;

  @track categoryValue = "";

  recordTypeId;
  subscription = null;
  subscriptionCaseAction = null;

  modeEditCase = false;
  modeSubscription = null;

  @wire(MessageContext)
  messageContext;
  connectedCallback() {
    this.subscribeToMessageChannel();
    this.subscribeCaseActionChannel();
    this.subscribeModeChannel();
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }

    if (this.subscriptionCaseAction) {
      unsubscribe(this.subscriptionCaseAction);
      this.subscriptionCaseAction = null;
    }
  }

  subscribeToMessageChannel() {
    if (this.subscription) return;

    this.subscription = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this.handleCaseNOCMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  subscribeCaseActionChannel() {
    if (this.subscriptionCaseAction) return;

    this.subscriptionCaseAction = subscribe(
      this.messageContext,
      CASE_ACTION_CHANNEL,
      (message) => this.handleCaseActionMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  subscribeModeChannel() {
    if (this.modeSubscription) return;

    this.modeSubscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleModeMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  // =====================
  // LMS Handler
  // =====================
  async handleCaseNOCMessage(message) {
    if (!message) return;

    console.log("📩 CASE_NOC:", JSON.stringify(message));

    this.productTypeId = message.productTypeId;
    this.categoryId = message.categoryId;
    this.subCategoryId = message.subCategoryId;
    this.subCodeId = message.subCodeId;
    this.natureOfCaseId = message.natureOfCaseId;

    if (!this.categoryId) return;

    try {
      this.categoryValue = await getCategory({
        categoryId: this.categoryId,
      });

      if (this.categoryValue === CATEGORY.COMPLAINT) {
        console.log("Complaint category detected");
      }
    } catch (error) {
      console.error("getCategory error:", error);
    }
  }

  handleCaseActionMessage(message) {
    if (!message?.action || !message?.recordId) return;

    // chỉ xử lý đúng record
    if (message.recordId !== this.recordId) return;

    console.log("📩 CASE_ACTION:", JSON.stringify(message));

    // chỉ update khi có data
    if (!this.complaintTypeValue && !this.complaintSourceValue) return;

    updateCase({
      recordId: this.recordId,
      complaintTypeValue: this.complaintTypeValue,
      complaintSourceValue: this.complaintSourceValue,
    })
      .then(() => {
        console.log("✅ Case updated");
      })
      .catch((error) => {
        console.error("❌ updateCase error:", error);
      });
  }

  handleModeMessage(message) {
    console.log("MODE MESSAGE:", JSON.stringify(message));

    if (message?.caseId !== this.recordId) {
      return;
    }

    this.modeEditCase = message?.isModeEdit || false;

    console.log("modeEditCase =", this.modeEditCase);
  }
  // Lấy metadata object
  // @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
  // objectInfo({ data, error }) {
  //   if (data) {
  //     this.recordTypeId = data.defaultRecordTypeId;
  //   }
  // }

  @wire(getRecord, {
    recordId: "$recordId",
    fields: FIELDS,
  })
  wiredCase({ data, error }) {
    if (data) {
      this.recordTypeId = data.fields.RecordTypeId.value;

      // lấy trực tiếp từ DB
      this.complaintTypeValue = getFieldValue(data, COMPLAINT_TYPE);

      this.complaintSourceValue = getFieldValue(data, COMPLAINT_SOURCE);

      console.log("Complaint Type:", this.complaintTypeValue);

      console.log("Complaint Source:", this.complaintSourceValue);
    }

    if (error) {
      console.error("wiredCase error:", error);
    }
  }

  // Picklist Complaint Type
  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: COMPLAINT_TYPE,
  })
  wiredComplaintType({ data, error }) {
    if (data) {
      this.complaintTypeOptions = data.values;
    }
  }

  // Picklist Complaint Source
  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: COMPLAINT_SOURCE,
  })
  wiredComplaintSource({ data, error }) {
    if (data) {
      this.complaintSourceOptions = data.values;
    }
  }

  // Handlers
  handleComplaintTypeChange(event) {
    console.log("RAW VALUE=", JSON.stringify(event.detail.value));

    console.log("HIGH_RISK=", JSON.stringify(COMPLAINT_TYPE_TEXT.HIGH_RISK));

    console.log("EQUAL=", event.detail.value === COMPLAINT_TYPE_TEXT.HIGH_RISK);

    this.complaintTypeValue = event.detail.value;

    this.complaintSourceValue = null;
  }

  handleComplaintSourceChange(event) {
    this.complaintSourceValue = event.detail.value;
  }

  // Conditions
  get isComplaintCategory() {
    return this.categoryValue === CATEGORY.COMPLAINT;
  }

  get showComplaintSource() {
    return (
      this.complaintTypeValue === COMPLAINT_TYPE_TEXT.HIGH_RISK ||
      this.complaintTypeValue === COMPLAINT_TYPE_TEXT.URGENT
    );
  }

  get helpText() {
    return COMPLAINT_SOURCE_LABEL[this.complaintSourceValue] || "";
  }
}
