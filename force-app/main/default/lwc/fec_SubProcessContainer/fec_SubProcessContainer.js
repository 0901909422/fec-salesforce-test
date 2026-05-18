import { LightningElement, api, wire } from "lwc";

import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";

import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import getSubProcesses from "@salesforce/apex/FEC_SubProcessService.getSubProcesses";
import getSubmittedSubProcesses from "@salesforce/apex/FEC_SubProcessService.getSubmittedSubProcesses";

export default class Fec_SubProcessContainer extends LightningElement {
  @api recordId;

  @api lockApiLwcsAfterRevertToDefaultStage;

  @wire(MessageContext)
  messageContext;

  subscription = null;
  params;
  isSubmitted = false;
  showHoldCase = false;
  showRemovePhone = false;
  showDoNotBother = false;
  showTransferCall = false;

  connectedCallback() {
    this.subscribeToMessageChannel();

    this.initializeCase();
  }

  disconnectedCallback() {
    this.unsubscribeFromMessageChannel();
  }

  subscribeToMessageChannel() {
    if (this.subscription) {
      return;
    }

    this.subscription = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  unsubscribeFromMessageChannel() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }
  }

  handleMessage(message) {
    if (!message) {
      return;
    }

    const { productTypeId, categoryId, subCategoryId, subCodeId } = message;

    this.params = {
      recordId: this.recordId,
      productTypeId,
      categoryId,
      subCategoryId,
      subCodeId,
    };

    // tungnm37: lưu NOC IDs vào sessionStorage để fec_holdCaseManual đọc được
    // (holdCaseManual mount sau khi message đã publish nên không nhận được message)
    try {
      const key = 'fec_case_noc_' + this.recordId;
      sessionStorage.setItem(key, JSON.stringify({ productTypeId, categoryId, subCategoryId, subCodeId }));
    } catch (e) {
      // ignore
    }
  }

  @wire(getSubProcesses, {
    recordId: "$params.recordId",
    productTypeId: "$params.productTypeId",
    categoryId: "$params.categoryId",
    subCategoryId: "$params.subCategoryId",
    subCodeId: "$params.subCodeId",
  })
  wiredSubProcesses({ data, error }) {
    if (
      !this.params?.productTypeId ||
      !this.params?.categoryId ||
      !this.params?.subCategoryId
    ) {
      return;
    }

    if (data) {
      this.showHoldCase = !!data.showHoldCase;
      this.showRemovePhone = !!data.showRemovePhone;
      this.showDoNotBother = !!data.showDNB;
      this.showTransferCall = !!data.showTransferCall;
    }

    if (error) {
      console.error("[fec_SubProcessContainer] wire error", error);
    }
  }

  _findRemovePhoneFormEl() {
    const selectors = [
      "c-fec_-remove-phone-form",
      "c-fec-remove-phone-form",
    ];
    for (let i = 0; i < selectors.length; i++) {
      const el = this.template.querySelector(selectors[i]);
      if (el) {
        return el;
      }
    }
    return null;
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1368
  @api saveRemovePhoneDraftIfApplicable() {
    const el = this._findRemovePhoneFormEl();
    if (el && typeof el.saveDraftIfApplicable === "function") {
      return el.saveDraftIfApplicable();
    }
    return Promise.resolve();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1368
  @api saveRemovePhoneForSubmitIfApplicable() {
    const el = this._findRemovePhoneFormEl();
    if (el && typeof el.saveForSubmitIfApplicable === "function") {
      return el.saveForSubmitIfApplicable();
    }
    return Promise.resolve();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1368
  @api validateRemovePhoneForSubmit() {
    const el = this._findRemovePhoneFormEl();
    if (el && typeof el.validateForSubmit === "function") {
      return el.validateForSubmit();
    }
    return true;
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1368
  @api notifyRemovePhoneCaseSubmitted() {
    const el = this._findRemovePhoneFormEl();
    if (el && typeof el.notifyCaseSubmitted === "function") {
      el.notifyCaseSubmitted();
    }
  }

  async initializeCase() {
    try {
      const result = await getSubmittedSubProcesses({
        caseId: this.recordId,
      });

      console.log("submitted subprocesses = ", JSON.stringify(result));

      // tungnm37: Hold Case depends on config (wire getSubProcesses decides)
      this.showHoldCase = !!result.showHoldCase;

      this.showRemovePhone = !!result.showRemovePhone;

      this.showDoNotBother = !!result.showDNB;

      this.showTransferCall = !!result.showTransferCall;
    } catch (error) {
      console.error("[initializeCase] ERROR", error);
    }
  }
}