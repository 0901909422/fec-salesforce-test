import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";

import CUSTOMER_TYPE from "@salesforce/schema/Case.FEC_Customer_Type__c";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import checkDNB from "@salesforce/apex/FEC_DNBHandler.checkDNB";

export default class fec_DoNotBotherHandling extends LightningElement {
  @api recordId;

  @wire(MessageContext)
  messageContext;

  subscription = null;
  lastKey;

  dnb = false;

  // ===== LIFECYCLE =====
  connectedCallback() {
    console.log("🔥 [INIT] connectedCallback");
    this.subscribeToMessageChannel();
  }

  disconnectedCallback() {
    console.log("🧹 [CLEANUP] disconnectedCallback");
    this.unsubscribeFromMessageChannel();
  }

  // ===== LMS =====
  subscribeToMessageChannel() {
    console.log("[LMS] Subscribing...");

    if (this.subscription) {
      console.log("[LMS] Already subscribed");
      return;
    }

    this.subscription = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE },
    );

    console.log("[LMS] Subscribed:", this.subscription);
  }

  unsubscribeFromMessageChannel() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
      console.log("[LMS] Unsubscribed");
    }
  }

  // ===== HANDLE MESSAGE =====
  async handleMessage(message) {
    console.log("[LMS] Received message:", JSON.stringify(message));

    if (!message) {
      console.log("[LMS] message is null");
      return;
    }

    const { categoryId, subCategoryId, subCodeId } = message;

    console.log(
      "[LMS] Parsed values:",
      JSON.stringify({
        categoryId,
        subCategoryId,
        subCodeId,
      }),
    );

    const key = `${categoryId}-${subCategoryId}-${subCodeId}`;
    console.log("[LMS] Generated key:", key);

    if (this.lastKey === key) {
      console.log("[LMS] Duplicate key → skip");
      return;
    }

    this.lastKey = key;

    this.categoryId = categoryId;
    this.subCategoryId = subCategoryId;
    this.subCodeId = subCodeId;

    console.log("[LMS] Calling checkDNB...");
    await this.checkDNB();
  }

  // ===== APEX CALL =====
  async checkDNB() {
    try {
      console.log("📡 [APEX] Request payload:", {
        categoryId: this.categoryId,
        subCategoryId: this.subCategoryId,
        subCodeId: this.subCodeId,
      });

      const result = await checkDNB({
        categoryId: this.categoryId,
        subCategoryId: this.subCategoryId,
        subCodeId: this.subCodeId,
      });

      console.log("[APEX] Raw result:", result);

      if (result === true) {
        this.handleDNBTrue();
      } else {
        this.handleDNBFalse();
      }
    } catch (e) {
      console.error("❌ [APEX ERROR]", e);
    }
  }

  // ===== RESULT HANDLER =====
  handleDNBTrue() {
    this.dnb = true;
  }

  handleDNBFalse() {
    this.dnb = false;
  }

  get isShowDoNotBother() {
    return this.dnb;
  }

  // ===== CASE =====
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [CUSTOMER_TYPE],
  })
  caseRecord;

  get customerType() {
    return getFieldValue(this.caseRecord.data, CUSTOMER_TYPE);
  }

  get isCustormerExisting() {
    return this.customerType === "Existing";
  }

  @api
  validate() {
    /*
     * Existing customer component
     */
    const existingCmp = this.template.querySelector(
      "c-fec_-do-not-bother-existing-customer",
    );

    if (existingCmp?.validate && !existingCmp.validate()) {
      return false;
    }

    /*
     * Non existing customer component
     */
    const nonExistingCmp = this.template.querySelector(
      "c-fec_-do-not-bother-non-existing-customer",
    );

    if (nonExistingCmp?.validate && !nonExistingCmp.validate()) {
      return false;
    }

    return true;
  }
}
