import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import getInteractionHighlightData
  from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionHighlightData";
import resetViewMode
  from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";

import VIEW_MODE
  from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";

export default class FecInteractionCreationHighlight extends LightningElement {
  @api recordId;

  record;
  viewMode; // handling | review
  _resetDone = false;

  // ===============================
  // LOAD VIEW MODE (LDS)
  // ===============================
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [VIEW_MODE],
  })
  wiredViewMode({ data, error }) {
    if (data) {
      this.viewMode = getFieldValue(data, VIEW_MODE);
      this.tryResetViewMode();
    } else if (error) {
      console.error("ViewMode load error", error);
    }
  }

  // ===============================
  // RESET VIEW MODE (SAFE – ONE TIME)
  // ===============================
  tryResetViewMode() {
    if (this.viewMode === "handling" && !this._resetDone) {
      this._resetDone = true;
      resetViewMode({
        recordId: this.recordId,
        viewMode: "review",
      });
    }
  }

  // ===============================
  // LOAD RECORD (APEX)
  // ===============================
  @wire(getInteractionHighlightData, { recordId: "$recordId" })
  wiredRecord({ data, error }) {
    if (data) {
      this.record = data;
    } else if (error) {
      console.error("Record load error", error);
    }
  }

  // ===============================
  // MODE CHECK
  // ===============================
  get isHandling() {
    return this.viewMode === "handling";
  }

  // ===============================
  // GETTERS
  // ===============================
  get interactionId() {
    return this.record?.FEC_Interaction_ID__c || "";
  }

  get status() {
    return this.record?.FEC_Interaction_Status__c || "";
  }

  get updatedBy() {
    return this.record?.FEC_Last_Updated_By__c || "";
  }

  get lastUpdated() {
    const value = this.record?.FEC_Last_Updated_On__c;
    if (!value) return "";

    return new Date(value).toLocaleString("en-GB", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
  }

  // ===============================
  // ACTIONS → SLA
  // ===============================
  handleQuickWrapUpClick() {
    this.template
      .querySelector("c-fec_-interaction-s-l-a")
      ?.handleQuickWrapUpClick?.();
  }

  handleWrapUpClick() {
    this.template
      .querySelector("c-fec_-interaction-s-l-a")
      ?.handleWrapUpClick?.();
  }

  // handleExecute() {
  //   resetViewMode({ recordId: this.recordId, viewMode: "handling" });
  //   this.viewMode = "handling";
  //   this._resetDone = false;

  // }
  async handleExecute() {
      try {
          await resetViewMode({ 
              recordId: this.recordId, 
              viewMode: "handling" 
          });
  
          await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
          this.viewMode = "handling";
          this._resetDone = false;
  
          console.log("Update viewMode to handling successfully");
      } catch (error) {
          console.error("Error in handleExecute:", error);
      }
    }

  handleCreateCase() {
    this.template
      .querySelector("c-fec_-interaction-s-l-a")
      ?.handleCreateCase?.();
  }
}