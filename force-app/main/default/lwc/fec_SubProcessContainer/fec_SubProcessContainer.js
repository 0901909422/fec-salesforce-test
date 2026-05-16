import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import FEC_AUTO_HOLD_CASE_RESULT from "@salesforce/schema/Case.FEC_Auto_Hold_Case_Result__c";

import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";

import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import getSubProcesses from "@salesforce/apex/FEC_SubProcessService.getSubProcesses";
import getCase from "@salesforce/apex/FEC_SubProcessService.getCase";

export default class Fec_SubProcessContainer extends LightningElement {
  @api recordId;

  @wire(MessageContext)
  messageContext;

  wiredCaseAutoResultWire;

  @wire(getRecord, { recordId: "$recordId", fields: [FEC_AUTO_HOLD_CASE_RESULT] })
  wiredCaseAutoResult(result) {
    this.wiredCaseAutoResultWire = result;
    const resultVal = getFieldValue(result.data, FEC_AUTO_HOLD_CASE_RESULT);
    if (resultVal) {
      this.showHoldCaseAuto = true;
      this.showHoldCase = true;
    }
  }

  subscription = null;
  params;
  isSubmitted = false;
  showHoldCase = false;
  showHoldCaseManual = false;
  showHoldCaseAuto = false;
  showRemovePhone = false;
  showDoNotBother = false;
  showTransferCall = false;

  connectedCallback() {
    this.params = { recordId: this.recordId };
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
    recordId: "$recordId",
    productTypeId: "$params.productTypeId",
    categoryId: "$params.categoryId",
    subCategoryId: "$params.subCategoryId",
    subCodeId: "$params.subCodeId",
  })
  wiredSubProcesses({ data, error }) {
    if (data) {
      this.showHoldCase = !!data.showHoldCase;
      this.showHoldCaseManual = !!data.showHoldCaseManual;
      this.showHoldCaseAuto = !!data.showHoldCaseAuto;
      this.showRemovePhone = !!data.showRemovePhone;
      this.showDoNotBother = !!data.showDNB;
      this.showTransferCall = !!data.showTransferCall;
    }

    if (error) {
      console.error("[fec_SubProcessContainer] wire error", error);
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366: Save remove phone draft if applicable
  @api saveRemovePhoneDraftIfApplicable() {
    const el =
      this.template.querySelector("c-fec_-remove-phone-form") ||
      this.template.querySelector("c-fec-remove-phone-form");
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveDraftIfApplicable();
  }

  async initializeCase() {
    try {
      this.isSubmitted = await getCase({
        caseId: this.recordId,
      });

      console.log("isSubmitted = ", this.isSubmitted);

      /*
       * Force show all subprocesses except Hold Case (Hold Case depends on config)
       * tungnm37: bỏ force showHoldCase, để wire getSubProcesses quyết định
       */
      if (this.isSubmitted) {
        this.showRemovePhone = true;

        this.showDoNotBother = true;

        this.showTransferCall = true;
      }
    } catch (error) {
      console.error("[initializeCase] ERROR", error);
    }
  }

  /** Gọi từ fec_CaseBussiness sau Submit để refresh kết quả Auto Hold Case. */
  @api
  refreshAutoHoldCase() {
    const promises = [];
    if (this.wiredCaseAutoResultWire) {
      promises.push(refreshApex(this.wiredCaseAutoResultWire));
    }
    const autoCmp = this.template.querySelector("c-fec_hold-case-auto");
    if (autoCmp?.refresh) {
      promises.push(autoCmp.refresh());
    }
    return Promise.all(promises);
  }
}