import { LightningElement, api, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import { CloseActionScreenEvent } from "lightning/actions";

import ASSIGNMENT_MODE from "@salesforce/messageChannel/FEC_Assignment_Mode__c";

export default class Fec_AssignmentExecuteAction extends LightningElement {
  _recordId;
  isPublished = false;

  @wire(MessageContext)
  messageContext;

  @api
  set recordId(value) {
    this._recordId = value;

    // publish only once when recordId is ready
    if (value && !this.isPublished) {
      this.handlePublishMessageChannel();
    }
  }

  get recordId() {
    return this._recordId;
  }

  handlePublishMessageChannel() {
    this.isPublished = true;

    const payload = {
      caseId: this.recordId,
      isEditMode: true,
    };

    console.log("Publishing payload:", JSON.stringify(payload));

    publish(this.messageContext, ASSIGNMENT_MODE, payload);

    // close action after publish
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}