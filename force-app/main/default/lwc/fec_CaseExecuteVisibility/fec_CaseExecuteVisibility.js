import { LightningElement, api, wire } from "lwc";

import canExecute from "@salesforce/apex/FEC_CaseExecuteService.canExecute";
import forceHideExecute from "@salesforce/apex/FEC_CaseExecuteService.forceHideExecute";

import {
  MessageContext,
  subscribe,
  unsubscribe,
} from "lightning/messageService";

import CASE_ACTION_CHANNEL from "@salesforce/messageChannel/FEC_CaseAction__c";

const caseExecuteStorageKey = (recordId) => `CaseExecute-${recordId}`;

export default class Fec_CaseExecuteVisibility extends LightningElement {
  @api recordId;

  @wire(MessageContext)
  messageContext;

  canExecute = false;
  executeMessage = "";

  loaded = false;
  subscription = null;

  connectedCallback() {
    this.subscribeMessageChannel();
  }

  subscribeMessageChannel() {
    if (this.subscription) {
      return;
    }

    this.subscription = subscribe(
      this.messageContext,
      CASE_ACTION_CHANNEL,
      async (message) => {
        console.log("CASE_ACTION_CHANNEL = ", message);

        localStorage.removeItem(caseExecuteStorageKey(this.recordId));
        localStorage.removeItem(`${this.recordId}`);

        try {
          await forceHideExecute({
            caseId: this.recordId,
          });
          this.canExecute = false;
        } catch (e) {
          console.error(e);
        }
      },
    );
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }
  }

  renderedCallback() {
    if (!this.recordId || this.loaded) {
      return;
    }

    this.loaded = true;
    this.syncExecuteVisibility();
  }

  syncExecuteVisibility() {
    canExecute({
      caseId: this.recordId,
    })
      .then((result) => {
        console.log("canExecute RESULT = ", result);
        this.canExecute = result?.value === true;

        this.executeMessage = result?.message || "";

        /*
         * Debug business reason
         */
        if (!this.canExecute) {
          console.warn("Execute hidden reason = ", this.executeMessage);
        }
      })
      .catch((error) => {
        console.error("canExecute ERROR = ", error);
        this.canExecute = false;

        this.executeMessage = "Unexpected error";
      });
  }
}
