import { LightningElement, api, wire } from "lwc";

import { publish, MessageContext } from "lightning/messageService";

import { CloseActionScreenEvent } from "lightning/actions";

import { RefreshEvent } from "lightning/refresh";

import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";

import executeAssignment from "@salesforce/apex/FEC_AssignmentExecuteService.executeAssignment";

import ASSIGNMENT_MODE from "@salesforce/messageChannel/FEC_Assignment_Mode__c";

import { setMode } from "c/fec_CustomerCaseModeStore";

export default class Fec_AssignmentExecuteAction extends LightningElement {
  _recordId;

  isPublished = false;

  @wire(MessageContext)
  messageContext;

  @api
  set recordId(value) {
    console.log("recordId setter = ", value);

    this._recordId = value;

    /*
     * Run only once
     */
    if (value && !this.isPublished) {
      this.handleExecute();
    }
  }

  get recordId() {
    return this._recordId;
  }

  async handleExecute() {
    this.isPublished = true;

    try {
      console.log("START handleExecute");

      console.log("recordId = ", this.recordId);

      /*
       * STEP 1
       * Execute assignment ownership
       */
      await executeAssignment({
        caseId: this.recordId,
      });

      console.log("executeAssignment SUCCESS");

      /*
       * STEP 2
       * Reset view mode
       */
      await resetViewMode({
        recordId: this.recordId,
        viewMode: "handling",
      });

      console.log("resetViewMode SUCCESS");

      /*
       * STEP 3
       * Publish LMS
       */
      const payload = {
        caseId: this.recordId,
        isEditMode: true,
      };

      console.log("Publishing payload:", JSON.stringify(payload));

      setMode(true);

      publish(this.messageContext, ASSIGNMENT_MODE, payload);

      /*
       * STEP 4
       * Refresh page
       */
      this.dispatchEvent(new RefreshEvent());
      await new Promise((resolve) => setTimeout(resolve, 300));
    } catch (error) {
      console.error("ERROR:", JSON.stringify(error));
    } finally {
      /*
       * STEP 5
       * Close action
       */
      setTimeout(() => {
        this.dispatchEvent(new CloseActionScreenEvent());
      }, 800);
    }
  }
}
