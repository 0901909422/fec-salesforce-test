import { LightningElement, api, wire } from "lwc";
import { IsConsoleNavigation, openTab } from "lightning/platformWorkspaceApi";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInteractionHighlightData from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionHighlightData";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import getCurrentUserProfileName from '@salesforce/apex/FEC_SearchController.getCurrentUserProfileName';
import HAS_ACCOUNT_OR_CONTRACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import { refreshApex } from "@salesforce/apex";
import FEC_INTERACTION_ID_LABEL from "@salesforce/label/c.FEC_Interaction_ID";
import FEC_INTERACTION_STATUS_LABEL from "@salesforce/label/c.FEC_Interaction_Status_Label";
import FEC_INTERACTION_DURATION_LABEL from "@salesforce/label/c.FEC_Interaction_Duration_Label";
import FEC_LAST_UPDATED_BY_LABEL from "@salesforce/label/c.FEC_Last_Updated_By_Label";
import FEC_LAST_UPDATED_ON_LABEL from "@salesforce/label/c.FEC_Last_Updated_On_Label";
import FEC_EXECUTE_LABEL from "@salesforce/label/c.FEC_Execute_Label";
import FEC_CREATE_CASE_BTN_LABEL from "@salesforce/label/c.FEC_Create_Case_Btn_Label";
import FEC_WRAP_UP_BTN_LABEL from "@salesforce/label/c.FEC_Wrap_up_Btn_Label";
import FEC_INTERACTION_CHANNEL from "@salesforce/label/c.FEC_Interaction_Channel_Label";
import FEC_INTERACTION_SUB_CHANNEL from "@salesforce/label/c.FEC_Interaction_Sub_Channel_Label";
import FEC_No_Permission_Msg from '@salesforce/label/c.FEC_No_Permission_Msg';
import { formatDateTime } from "c/fec_CommonUtils";
import { PROFILE_RELEVANT_DEPTS } from 'c/fec_CommonConst';

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
    interactionChannel: FEC_INTERACTION_CHANNEL,
    interactionSubChannel: FEC_INTERACTION_SUB_CHANNEL,
  };

  @api recordId;

  record;
  viewMode; // handling | review
  wiredViewModeResult;
  _resetDone = false;
  isOpen = false;
  _userProfile;

  // ===============================
  // CONSOLE CHECK
  // ===============================
  @wire(IsConsoleNavigation)
  isConsoleNavigation;

  @wire(getCurrentUserProfileName)
  wiredProfile({ data }) {
    if (data) this._userProfile = data;
  }

  // ===============================
  // LOAD VIEW MODE (LDS)
  // ===============================
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [VIEW_MODE],
  })
  wiredViewMode(result) {
    this.wiredViewModeResult = result;

    const { data, error } = result;

    if (data) {
      this.viewMode = getFieldValue(data, VIEW_MODE);
      //await this.tryResetViewMode();
    } else if (error) {
      console.error("ViewMode load error", error);
    }
  }

  // ===============================
  // RESET VIEW MODE (SAFE – ONE TIME)
  // ===============================
  // async tryResetViewMode() {
  //   if (this.viewMode === "handling" && !this._resetDone) {
  //     console.log(
  //       "Reset viewMode to review in FecInteractionCreationHighlight",
  //     );
  //     try {
  //       await resetViewMode({
  //         recordId: this.recordId,
  //         viewMode: "review",
  //       });
  //       await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
  //     } catch (error) {
  //       console.error("Error in resetViewMode:", error);
  //     }
  //   }
  //   if (this._resetDone) return;
  //   this._resetDone = true;
  // }

  async connectedCallback() {
    try {
        await resetViewMode({
          recordId: this.recordId,
          viewMode: "review",
        });
        await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      } catch (error) {
        console.error("Error in resetViewMode:", error);
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

  get isNotRelevantDepts() {
    return this._userProfile !== PROFILE_RELEVANT_DEPTS;
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

  get interactionChannel() {
    return this.record?.FEC_Channel__c || "";
  }

  get interactionSubChannel() {
    return this.record?.FEC_Interaction_Subchannel__c || "";
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
      await refreshApex(this.wiredViewModeResult); // 🔥 KEY FIX
      // await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.viewMode = "handling";
      console.log("Update viewMode to handling successfully");
    } catch (error) {
      console.error("Error in handleExecute:", error);
    }
  }

  async handleCreateCase() {
    console.log("handleCreateCase from creation highlight");
    if (this._userProfile === PROFILE_RELEVANT_DEPTS) {
      this.dispatchEvent(new ShowToastEvent({ title: 'Lỗi', message: FEC_No_Permission_Msg, variant: 'error' }));
      return;
    }
    this.isOpen = true;
  }

  close() {
    this.isOpen = false;
  }
}