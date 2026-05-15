import { LightningElement, api, wire } from "lwc";

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

  async initializeCase() {
    try {
      this.isSubmitted = await getCase({
        caseId: this.recordId,
      });

      console.log("isSubmitted = ", this.isSubmitted);

      /*
       * Force show all subprocesses
       */
      if (this.isSubmitted) {
        this.showHoldCase = true;

        this.showRemovePhone = true;

        this.showDoNotBother = true;

        this.showTransferCall = true;
      }
    } catch (error) {
      console.error("[initializeCase] ERROR", error);
    }
  }
}
