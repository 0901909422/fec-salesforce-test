import { LightningElement, api, wire } from "lwc";

import resetViewMode from "@salesforce/apex/FEC_AssignmentExecuteService.setAssignmentViewMode";

import canExecute from "@salesforce/apex/FEC_AssignmentExecuteService.canExecuteAssignment";

import forceShowExecute from "@salesforce/apex/FEC_AssignmentExecuteService.forceShowExecuteAssignment";
import {
  MessageContext,
  subscribe,
  unsubscribe,
} from "lightning/messageService";

import ASSIGNMENT_MODE from "@salesforce/messageChannel/FEC_Assignment_Mode__c";

export default class Fec_AssignmentExecuteVisibility extends LightningElement {
  @api recordId;

  @wire(MessageContext)
  messageContext;

  canExecute = false;

  isLoaded = false;

  subscription = null;

  connectedCallback() {
    this.subscribeMessageChannel();
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);

      this.subscription = null;
    }
  }

  subscribeMessageChannel() {
    if (this.subscription) {
      return;
    }

    this.subscription = subscribe(
      this.messageContext,
      ASSIGNMENT_MODE,
      async (message) => {
        console.log("ASSIGNMENT_MODE = ", message);

        if (message?.isEditMode) {
          const storageKey = `assignment-${this.recordId}`;

          /*
           * Clear handling session
           */
          localStorage.removeItem(storageKey);

          console.log("localStorage removed");
        }
      },
    );
  }

  async renderedCallback() {
    if (this.isLoaded || !this.recordId) {
      return;
    }

    this.isLoaded = true;

    console.log("recordId=", this.recordId);

    const storageKey = `assignment-${this.recordId}`;

    /*
     * PRIORITY:
     * Restore handling session
     */
    const localStatus = localStorage.getItem(storageKey);

    console.log("localStatus = ", localStatus);

    /*
     * Existing handling session
     */
    if (localStatus === "handling") {
      console.log("RESTORE HANDLING SESSION");

      this.canExecute = true;

      try {
        /*
         * Force backend visibility
         */
        await forceShowExecute({
          caseId: this.recordId,
        });

        console.log("forceShowExecute SUCCESS");

        /*
         * Restore review mode
         */
        await resetViewMode({
          recordId: this.recordId,
          viewMode: "review",
        });

        console.log("resetViewMode SUCCESS");
      } catch (error) {
        console.error("RESTORE ERROR=", error);
      }

      return;
    }

    /*
     * STEP 1
     * Reset mode to review
     */
    await this.initializeMode();

    /*
     * STEP 2
     * Check visibility
     */
    canExecute({
      caseId: this.recordId,
    })
      .then((result) => {
        console.log("RESULT=", result);

        this.canExecute = result.value;
      })
      .catch((error) => {
        console.error("ERROR=", error);
      });
  }

  async initializeMode() {
    try {
      await resetViewMode({
        recordId: this.recordId,
        viewMode: "review",
      });

      console.log("resetViewMode SUCCESS");
    } catch (error) {
      console.error("resetViewMode ERROR=", error);
    }
  }
}
