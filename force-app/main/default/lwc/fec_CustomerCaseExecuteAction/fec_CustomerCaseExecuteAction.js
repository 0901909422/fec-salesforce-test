import { LightningElement, api, wire } from "lwc";

import { publish, MessageContext } from "lightning/messageService";

import { CloseActionScreenEvent } from "lightning/actions";

import { RefreshEvent } from "lightning/refresh";

import { ShowToastEvent } from "lightning/platformShowToastEvent";

import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";

import { setMode } from "c/fec_CustomerCaseModeStore";

import executeCase from "@salesforce/apex/FEC_CaseExecuteService.executeCase";
export default class Fec_CustomerCaseExecuteAction extends LightningElement {
  _recordId;

  loaded = false;

  @wire(MessageContext)
  messageContext;

  /*
   * Quick Action injects recordId later
   */
  @api
  set recordId(value) {
    console.log("recordId setter = ", value);

    this._recordId = value;

    /*
     * Run only once
     */
    if (value && !this.loaded) {
      this.loaded = true;

      this.startExecute();
    }
  }

  get recordId() {
    return this._recordId;
  }

  async startExecute() {
    try {
      console.log("START EXECUTE");

      console.log("recordId = ", this.recordId);

      /*
       * Change owner
       */
      await executeCase({
        caseId: this.recordId,
      });

      console.log("Owner updated");

      localStorage.setItem(`CaseExecute-${this.recordId}`, "handling");

      /*
       * Enable edit mode
       */

      await this.handlePublishMessageChanel();

      /*
       * Refresh page
       */
      this.dispatchEvent(new RefreshEvent());
    } catch (e) {
      console.error("ERROR = ", e);

      const message = e?.body?.message || "Execute case failed";

      /*
       * Force refresh visibility component
       */
      this.dispatchEvent(new RefreshEvent());

      /*
       * Show warning
       */
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Warning",
          message,
          variant: "warning",
        }),
      );
    } finally {
      this.dispatchEvent(new CloseActionScreenEvent());
    }
  }

  async handlePublishMessageChanel() {
    const payload = {
      caseId: this.recordId,
      isModeEdit: true,
    };

    setMode(true);

    publish(this.messageContext, IS_MODE_EDIT, payload);
  }
}
