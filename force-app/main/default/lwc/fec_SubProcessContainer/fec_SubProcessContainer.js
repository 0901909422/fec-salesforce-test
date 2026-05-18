import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import FEC_NFU_DESCRIPTION_RESULT from "@salesforce/schema/Case.FEC_NFU_Description_Result__c";

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

  wiredCaseAutoResultWire;
  /** Case đã có kết quả Manual/Auto Hold (SUCCESS | ALREADY_MARKED | ERROR | PENDING). */
  holdCaseResultOnCase = false;
  /** Fallback từ Manual Hold popup (sessionStorage) khi field Case chưa kịp refresh. */
  holdCaseResultOverride = null;

  @wire(getRecord, { recordId: "$recordId", fields: [FEC_NFU_DESCRIPTION_RESULT] })
  wiredCaseAutoResult(result) {
    this.wiredCaseAutoResultWire = result;
    const resultVal = getFieldValue(result.data, FEC_NFU_DESCRIPTION_RESULT);
    this.holdCaseResultOnCase = !!resultVal;
    if (resultVal) {
      this.showHoldCase = true;
      this.showHoldCaseAuto = true;
    }
  }

  subscription = null;
  params;
  showHoldCase = false;
  showHoldCaseManual = false;
  /** Từ Hold Case Config type Auto — không ghi đè khi Case đã có FEC_NFU_Description_Result__c. */
  showHoldCaseAuto = false;
  showRemovePhone = false;
  showDoNotBother = false;
  showTransferCall = false;

  connectedCallback() {
    this.params = { recordId: this.recordId };
    this.subscribeToMessageChannel();
    this.initializeCase();
    this._boundCheckHoldCaseRefresh = this._checkHoldCaseRefreshFlag.bind(this);
    window.addEventListener("focus", this._boundCheckHoldCaseRefresh);
    this._checkHoldCaseRefreshFlag();
  }

  disconnectedCallback() {
    this.unsubscribeFromMessageChannel();
    if (this._boundCheckHoldCaseRefresh) {
      window.removeEventListener("focus", this._boundCheckHoldCaseRefresh);
    }
  }

  /** Manual Hold Case (Quick Action) báo refresh qua sessionStorage sau TH1/TH2/TH3. */
  _checkHoldCaseRefreshFlag() {
    if (!this.recordId) {
      return;
    }
    try {
      const key = "fec_hold_case_refresh_" + this.recordId;
      const displayKey = "fec_hold_case_display_" + this.recordId;
      const displayVal = sessionStorage.getItem(displayKey);
      if (displayVal) {
        this.holdCaseResultOverride = displayVal;
        console.log("[fec_SubProcessContainer] holdCaseResultOverride=", displayVal);
      }
      if (sessionStorage.getItem(key)) {
        sessionStorage.removeItem(key);
        sessionStorage.removeItem(displayKey);
        this.refreshAutoHoldCase();
        // Poll thêm khi Quick Action đóng — component có thể mount sau
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => this.refreshAutoHoldCase(), 600);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => this.refreshAutoHoldCase(), 1200);
      }
    } catch (e) {
      // ignore
    }
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

    this._checkHoldCaseRefreshFlag();

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

  /** Hiển thị block Hold Case (Manual/Auto/đã có kết quả trên Case). */
  get showHoldCaseSection() {
    return (
      this.showHoldCaseAuto ||
      this.showHoldCaseManual ||
      this.holdCaseResultOnCase ||
      !!this.holdCaseResultOverride
    );
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
      this.showHoldCase = !!data.showHoldCase || this.holdCaseResultOnCase;
      this.showHoldCaseManual = !!data.showHoldCaseManual;
      // tungnm37: không reset khi Case đã có kết quả Hold (TH1/TH2/TH3 Manual)
      if (!this.holdCaseResultOnCase) {
        this.showHoldCaseAuto = !!data.showHoldCaseAuto;
      }
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

      // release-uat-3: visibility sau submit; giữ Hold Case khi Case đã có kết quả
      this.showHoldCase = !!result.showHoldCase || this.holdCaseResultOnCase;
      this.showRemovePhone = !!result.showRemovePhone;
      this.showDoNotBother = !!result.showDNB;
      this.showTransferCall = !!result.showTransferCall;
    } catch (error) {
      console.error("[initializeCase] ERROR", error);
    }
  }

  /** Gọi từ fec_CaseBussiness sau Submit / Manual Hold để refresh kết quả Hold Case. */
  @api
  refreshAutoHoldCase() {
    this._checkHoldCaseRefreshFlag();
    const promises = [];
    if (this.wiredCaseAutoResultWire) {
      promises.push(
        refreshApex(this.wiredCaseAutoResultWire).then(() => {
          const resultVal = getFieldValue(
            this.wiredCaseAutoResultWire?.data,
            FEC_NFU_DESCRIPTION_RESULT,
          );
          this.holdCaseResultOnCase = !!resultVal;
          if (resultVal) {
            this.showHoldCase = true;
            this.showHoldCaseAuto = true;
          }
        }),
      );
    }
    if (this.holdCaseResultOverride) {
      this.showHoldCase = true;
      this.showHoldCaseAuto = true;
    }
    return Promise.all(promises).then(() => {
      // tungnm37: mount fec_holdCaseAuto sau khi showHoldCaseSection = true rồi refresh
      const autoCmp = this.template.querySelector("c-fec_hold-case-auto");
      if (autoCmp?.refresh) {
        return autoCmp.refresh();
      }
      return undefined;
    });
  }
}