import { LightningElement, api, wire } from "lwc";

import canExecute from "@salesforce/apex/FEC_CaseExecuteService.canExecute";
import forceShowExecute from "@salesforce/apex/FEC_CaseExecuteService.forceShowExecute";

import {
  MessageContext,
  subscribe,
  unsubscribe,
} from "lightning/messageService";

import CASE_ACTION_CHANNEL from "@salesforce/messageChannel/FEC_CaseAction__c";
export default class Fec_CaseExecuteVisibility extends LightningElement {
  @api recordId;

  @wire(MessageContext)
  messageContext;

  canExecute = false;

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
      (message) => {
        console.log("CASE_ACTION_CHANNEL = ", message);

        /*
         * Clear local storage
         */
        localStorage.removeItem(`${this.recordId}`);

        console.log("localStorage removed");
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
    console.log("recordId = ", this.recordId);

    if (this.recordId && !this.loaded) {
      this.loaded = true;

      /*
       * PRIORITY:
       * Check local storage first
       */
      const localStatus = localStorage.getItem(`${this.recordId}`);

      console.log("localStatus = ", localStatus);

      /*
       * If handling
       * -> show execute immediately
       */
      if (localStatus === "handling") {
        console.log("SHOW EXECUTE FROM LOCAL STORAGE");

        this.canExecute = true;

        /*
         * IMPORTANT:
         * Sync backend immediately
         */
        forceShowExecute({
          caseId: this.recordId,
        })
          .then(() => {
            console.log("FEC_Can_Execute__c updated = true");
          })
          .catch((e) => {
            console.error(e);
          });

        return;
      }

      /*
       * Fallback:
       * call backend
       */
      canExecute({
        caseId: this.recordId,
      })
        .then((result) => {
          console.log("RESULT = ", result);

          this.canExecute = result.value;
        })
        .catch((error) => {
          console.error("ERROR = ", error);
        });
    }
  }
}
