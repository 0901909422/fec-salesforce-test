import { LightningElement, api, wire } from "lwc";
import { IsConsoleNavigation, openTab } from "lightning/platformWorkspaceApi";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInteractionHighlightData from "@salesforce/apex/FEC_InteractionInforHandler.getInteractionHighlightData";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import getCurrentUserProfileName from '@salesforce/apex/FEC_SearchController.getCurrentUserProfileName';
import canExecuteCase from '@salesforce/apex/FEC_CaseExecuteService.canExecute';
import canExecuteUbankEmailInteraction from '@salesforce/apex/FEC_CaseExecuteService.canExecuteUbankEmailInteraction';
import executeUbankEmailInteraction from '@salesforce/apex/FEC_CaseExecuteService.executeUbankEmailInteraction';
import HAS_ACCOUNT_OR_CONTRACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import ISOWNER from "@salesforce/schema/Case.FEC_Is_Owner__c";
import CAN_EXECUTE from "@salesforce/schema/Case.FEC_Can_Execute__c";
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
import isInteractionEmailActionBlocked from '@salesforce/apex/FEC_InteractionInforHandler.isInteractionEmailActionBlocked';
import isInteractionPhoneActionBlocked from '@salesforce/apex/FEC_InteractionInforHandler.isInteractionPhoneActionBlocked';
import isInteractionChatActionBlocked from '@salesforce/apex/FEC_InteractionInforHandler.isInteractionChatActionBlocked';
import VALIDATE_INTERACTION_EMAIL from "@salesforce/messageChannel/FEC_Validate_Interaction_Email__c";
import VALIDATE_INTERACTION_PHONE from "@salesforce/messageChannel/FEC_Validate_Interaction_Phone__c";
import VALIDATE_INTERACTION_CHAT from "@salesforce/messageChannel/FEC_Validate_Interaction_Chat__c";
import {
  publish,
  MessageContext,
} from "lightning/messageService";
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

  @wire(MessageContext)
  messageContext;

  record;
  viewMode; // handling | review
  wiredViewModeResult;
  _resetDone = false;
  isOpen = false;
  isOwner = false;
  canExecuteFlag = false;
  ubankExecuteAccess = false;
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
  @wire(canExecuteUbankEmailInteraction, { caseId: "$recordId" })
  wiredUbankExecuteAccess({ data, error }) {
    if (data !== undefined) {
      this.ubankExecuteAccess = data === true;
      if (this.ubankExecuteAccess) {
        this.canExecuteFlag = true;
      }
    } else if (error) {
      this.ubankExecuteAccess = false;
      console.error("canExecuteUbankEmailInteraction wire error", error);
    }
  }

  // ===============================
  // LOAD VIEW MODE (LDS)
  // ===============================
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [VIEW_MODE, ISOWNER, CAN_EXECUTE],
  })
  wiredViewMode(result) {
    this.wiredViewModeResult = result;

    const { data, error } = result;

    if (data) {
      this.viewMode = getFieldValue(data, VIEW_MODE);
      this.isOwner = getFieldValue(data, ISOWNER);
      this.canExecuteFlag = getFieldValue(data, CAN_EXECUTE);
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
        await refreshApex(this.wiredViewModeResult);
        await this.refreshExecuteAccess();
      } catch (error) {
        console.error("Error in connectedCallback:", error);
      }
  }

  async refreshExecuteAccess() {
    const result = await canExecuteCase({ caseId: this.recordId });
    if (result?.value === true) {
      this.canExecuteFlag = true;
      return;
    }

    const canExecuteUbank = await canExecuteUbankEmailInteraction({
      caseId: this.recordId,
    });
    this.ubankExecuteAccess = canExecuteUbank === true;
    this.canExecuteFlag = this.ubankExecuteAccess;
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

  get showExecute() {
    // 05/06/2026 10:00 tungnm37 - Hide Execute when current user is not Interaction owner on creation screen.
    // 15/06/2026 - Khi đã chuyển sang handling thì luôn ẩn Execute, chỉ hiển thị Wrap-up và Create Case.
    if (this.isHandling) {
      return false;
    }
    return this.canExecuteFlag === true || this.ubankExecuteAccess === true || (this.isOwner === true);
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
    return this.record?.FEC_Last_Updated_By_View__c || "";
  }

  get lastUpdated() {
    const value = this.record?.FEC_Last_Updated_On_View__c;
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
    if (!this.showExecute) {
      return;
    }
    try {
      // Ubank Email queue: change owner from queue to current user before resetViewMode
      if (this.ubankExecuteAccess === true) {
        try {
          const ownerChanged = await executeUbankEmailInteraction({
            caseId: this.recordId,
          });
          console.log("executeUbankEmailInteraction ownerChanged =", ownerChanged);
          if (ownerChanged === true) {
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
          }
        } catch (ubankError) {
          console.error("Error in executeUbankEmailInteraction:", ubankError);
        }
      }
      await resetViewMode({
        recordId: this.recordId,
        viewMode: "handling",
      });
      await refreshApex(this.wiredViewModeResult); // 🔥 KEY FIX
      // await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.viewMode = "handling";
      this.ubankExecuteAccess = false;
      this.canExecuteFlag = false;
      console.log("Update viewMode to handling successfully");
    } catch (error) {
      console.error("Error in handleExecute:", error);
    }
  }

  async ensureInteractionEmailBeforeCreateCase(recordId) {
    if (!recordId) {
      return true;
    }
    try {
      const blocked = await isInteractionEmailActionBlocked({ recordId });
      if (blocked) {
        publish(this.messageContext, VALIDATE_INTERACTION_EMAIL, { recordId });
        return false;
      }
      return true;
    } catch (error) {
      console.error("isInteractionEmailActionBlocked error", error);
      return true;
    }
  }

  async ensureInteractionPhoneBeforeCreateCase(recordId) {
    if (!recordId) {
      return true;
    }
    try {
      const blocked = await isInteractionPhoneActionBlocked({ recordId });
      if (blocked) {
        publish(this.messageContext, VALIDATE_INTERACTION_PHONE, { recordId });
        return false;
      }
      return true;
    } catch (error) {
      console.error("isInteractionPhoneActionBlocked error", error);
      return true;
    }
  }

  async ensureInteractionChatBeforeCreateCase(recordId) {
    if (!recordId) {
      return true;
    }
    try {
      const blocked = await isInteractionChatActionBlocked({ recordId });
      if (blocked) {
        publish(this.messageContext, VALIDATE_INTERACTION_CHAT, { recordId });
        return false;
      }
      return true;
    } catch (error) {
      console.error("isInteractionChatActionBlocked error", error);
      return true;
    }
  }

  async ensureInteractionFieldsBeforeCreateCase(recordId) {
    const emailOk = await this.ensureInteractionEmailBeforeCreateCase(recordId);
    if (!emailOk) {
      return false;
    }
    const phoneOk = await this.ensureInteractionPhoneBeforeCreateCase(recordId);
    if (!phoneOk) {
      return false;
    }
    return this.ensureInteractionChatBeforeCreateCase(recordId);
  }

  async handleCreateCase() {
    console.log("handleCreateCase from creation highlight");
    if (this._userProfile === PROFILE_RELEVANT_DEPTS) {
      this.dispatchEvent(new ShowToastEvent({ title: 'Lỗi', message: FEC_No_Permission_Msg, variant: 'error' }));
      return;
    }
    const canProceed = await this.ensureInteractionFieldsBeforeCreateCase(this.recordId);
    if (!canProceed) {
      return;
    }
    this.isOpen = true;
  }

  close() {
    this.isOpen = false;
  }
}