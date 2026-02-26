import { LightningElement, api, wire } from "lwc";
import { IsConsoleNavigation, openTab } from "lightning/platformWorkspaceApi";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import getInteractionHighlightData from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionHighlightData";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import HAS_ACCOUNT_OR_CONTRACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";

import FEC_INTERACTION_ID_LABEL from "@salesforce/label/c.FEC_Interaction_ID";
import FEC_INTERACTION_STATUS_LABEL from "@salesforce/label/c.FEC_Interaction_Status_Label";
import FEC_INTERACTION_DURATION_LABEL from "@salesforce/label/c.FEC_Interaction_Duration_Label";
import FEC_LAST_UPDATED_BY_LABEL from "@salesforce/label/c.FEC_Last_Updated_By_Label";
import FEC_LAST_UPDATED_ON_LABEL from "@salesforce/label/c.FEC_Last_Updated_On_Label";
import FEC_EXECUTE_LABEL from "@salesforce/label/c.FEC_Execute_Label";
import FEC_CREATE_CASE_BTN_LABEL from "@salesforce/label/c.FEC_Create_Case_Btn_Label";
import FEC_WRAP_UP_BTN_LABEL from "@salesforce/label/c.FEC_Wrap_up_Btn_Label";

import { formatDateTime } from 'c/fec_CommonUtils';

export default class FecInteractionCreationHighlight extends NavigationMixin(
  LightningElement,
) {
  labels = {
    interactionId: FEC_INTERACTION_ID_LABEL,
    interactionStatus: FEC_INTERACTION_STATUS_LABEL,
    interactionDuration: FEC_INTERACTION_DURATION_LABEL,
    lastUpdatedBy: FEC_LAST_UPDATED_BY_LABEL,
    lastUpdatedOn: FEC_LAST_UPDATED_ON_LABEL,
    execute: FEC_EXECUTE_LABEL,
    createCase: FEC_CREATE_CASE_BTN_LABEL,
    wrapUp: FEC_WRAP_UP_BTN_LABEL,
  };

  @api recordId;

  record;
  viewMode; // handling | review
  _resetDone = false;
  isOpen = false;

  // ===============================
  // CONSOLE CHECK
  // ===============================
  @wire(IsConsoleNavigation)
  isConsoleNavigation;

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
      let hasAccountOrContract = getFieldValue(data, HAS_ACCOUNT_OR_CONTRACT);
      // if (hasAccountOrContract == false) {

      // }
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
      console.log(
        "Reset viewMode to review in FecInteractionCreationHighlight",
      );
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

    return formatDateTime(value);
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

  async handleExecute() {
    try {
      await resetViewMode({
        recordId: this.recordId,
        viewMode: "handling",
      });

      await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.viewMode = "handling";
      this._resetDone = false;

      console.log("Update viewMode to handling successfully");
    } catch (error) {
      console.error("Error in handleExecute:", error);
    }
  }

  async handleCreateCase() {
    console.log("handleCreateCase from creation highlight");
    this.isOpen = true;
    
  }

  close() {
    this.isOpen = false;
  }
}
