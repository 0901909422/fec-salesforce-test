import { LightningElement, api, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import { CloseActionScreenEvent } from "lightning/actions";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import ASSIGNMENT_MODE from "@salesforce/messageChannel/FEC_Assignment_Mode__c";
import {
  setMode,
} from "c/fec_CustomerCaseModeStore";
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

  async handlePublishMessageChannel() {
    this.isPublished = true;

    try {
      // reset view mode before publish
      await resetViewMode({
        recordId: this.recordId,
        viewMode: 'handling'
      });

      const payload = {
        caseId: this.recordId,
        isEditMode: true,
      };

      console.log("Publishing payload:", JSON.stringify(payload));

      setMode(true);

      publish(this.messageContext, ASSIGNMENT_MODE, payload);
    } catch (error) {
      console.error("Error resetting view mode:", error);
    } finally {
      // close action after publish
      this.dispatchEvent(new CloseActionScreenEvent());
    }
  }
}