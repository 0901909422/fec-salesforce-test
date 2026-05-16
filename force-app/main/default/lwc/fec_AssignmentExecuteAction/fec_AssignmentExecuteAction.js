import { LightningElement, api, wire } from "lwc";

import { publish, MessageContext } from "lightning/messageService";

import { CloseActionScreenEvent } from "lightning/actions";

import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";

import resetViewMode from "@salesforce/apex/FEC_AssignmentExecuteService.setAssignmentViewMode";

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

      const storageKey = `assignment-${this.recordId}`;

      localStorage.setItem(storageKey, "handling");
      /*
       * STEP 2
       * Update interaction view mode
       */
      await resetViewMode({
        recordId: this.recordId,
        viewMode: "handling",
      });

      console.log("setAssignmentViewMode SUCCESS");

      /*
       * STEP 3
       * Notify LDS record update
       */
      await notifyRecordUpdateAvailable([
        {
          recordId: this.recordId,
        },
      ]);

      console.log("notifyRecordUpdateAvailable SUCCESS");

      /*
       * STEP 4
       * Publish LMS
       */
      const payload = {
        caseId: this.recordId,
        isEditMode: true,
      };

      console.log("Publishing payload:", JSON.stringify(payload));

      setMode(true);

      publish(this.messageContext, ASSIGNMENT_MODE, payload);
    } catch (error) {
      console.error("ERROR:", JSON.stringify(error));
    } finally {
      /*
       * STEP 5
       * Close action
       */
      this.dispatchEvent(new CloseActionScreenEvent());
    }
  }
}
