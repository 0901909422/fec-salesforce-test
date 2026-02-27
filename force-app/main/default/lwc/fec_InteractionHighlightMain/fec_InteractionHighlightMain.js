import { LightningElement, api, track, wire } from "lwc";
import { IsConsoleNavigation, openTab } from "lightning/platformWorkspaceApi";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";

import FIRST_ACCESS from "@salesforce/schema/Case.FEC_First_Access__c";
import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import ISCLOSED from "@salesforce/schema/Case.IsClosed";
import ISOWNER from "@salesforce/schema/Case.FEC_Is_Owner__c";
import HAS_ACCOUNT_OR_CONTRACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";
import INTERACTION_RECORD_ID from "@salesforce/schema/Case.FEC_Interaction__c";
import {
  publish,
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";

import FEC_INTERACTION_ID_LABEL from "@salesforce/label/c.FEC_Interaction_ID";
import FEC_INTERACTION_STATUS_LABEL from "@salesforce/label/c.FEC_Interaction_Status_Label";
import FEC_INTERACTION_DURATION_LABEL from "@salesforce/label/c.FEC_Interaction_Duration_Label";
import FEC_LAST_UPDATED_BY_LABEL from "@salesforce/label/c.FEC_Last_Updated_By_Label";
import FEC_LAST_UPDATED_ON_LABEL from "@salesforce/label/c.FEC_Last_Updated_On_Label";
import FEC_EXECUTE_LABEL from "@salesforce/label/c.FEC_Execute_Label";
import FEC_CREATE_CASE_BTN_LABEL from "@salesforce/label/c.FEC_Create_Case_Btn_Label";
import FEC_WRAP_UP_BTN_LABEL from "@salesforce/label/c.FEC_Wrap_up_Btn_Label";

import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import CUSTOMER_TYPE from "@salesforce/schema/Case.FEC_Customer_Type__c";

export default class Fec_InteractionHighlightMain extends NavigationMixin(
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

  @wire(MessageContext)
  messageContext;
  @track interactionRecordId;
  @api recordId;
  @api isModeEdit = false;

  @track interactionId = "";
  @track customerSegment = "";

  viewMode; // handling | review
  firstAccess;
  recordTypeId;
  recordTypeDevName;
  hasAccountOrContract;
  customerType;
  _resetDone = false;

  // ===============================
  // CONSOLE CHECK
  // ===============================
  @wire(IsConsoleNavigation)
  isConsoleNavigation;

  isCaseClosed = false;
  isOwner = false;

  // ===============================
  // LOAD CASE DATA
  // ===============================
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [
      VIEW_MODE,
      RECORDTYPE_ID,
      HAS_ACCOUNT_OR_CONTRACT,
      ISCLOSED,
      ISOWNER,
      INTERACTION_RECORD_ID,
      CUSTOMER_TYPE,
    ],
  })
  wiredCase({ data, error }) {
    if (data) {
      this.firstAccess = getFieldValue(data, FIRST_ACCESS);
      this.interactionRecordId = getFieldValue(data, INTERACTION_RECORD_ID);
      this.viewMode = getFieldValue(data, VIEW_MODE);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);
      this.hasAccountOrContract = getFieldValue(data, HAS_ACCOUNT_OR_CONTRACT);
      this.isCaseClosed = getFieldValue(data, ISCLOSED);
      this.isOwner = getFieldValue(data, ISOWNER);
      this.customerType = getFieldValue(data, CUSTOMER_TYPE);
      if (this.recordTypeId) {
        this.loadRecordType();
      }

      this.tryResetViewMode();
    } else if (error) {
      console.error("getRecord error:", error);
    }
  }

  // ===============================
  // LOAD RECORD TYPE NAME
  // ===============================
  async loadRecordType() {
    try {
      this.recordTypeDevName = await getRecordTypeName({
        recordId: this.recordId,
      });
    } catch (e) {
      console.error("getRecordTypeName error:", e);
    }
  }

  // ===============================
  // MODE CHECK
  // ===============================
  get isHandling() {
    return this.viewMode === "handling";
  }

  get showExecute() {
    return !this.isHandling && !this.isCaseClosed && this.isOwner;
  }

  get isInteractionCase() {
    return this.recordTypeDevName === "Interaction";
  }

  get isCustomerCase() {
    return this.recordTypeDevName === "Customer_Case";
  }
  get createCaseSourceId() {
    // Nếu là Interaction → dùng record hiện tại
    if (this.isInteractionCase) {
      return this.recordId;
    }

    // Nếu là Customer Case → dùng Interaction Id
    return this.interactionRecordId || this.recordId;
  }

  get showHighlight() {
    if (this.isInteractionCase) {
      if (this.hasAccountOrContract) {
        return true;
      } else {
        // Nếu là Interaction nhưng không có Account hoặc Contract liên kết
        return false;
      }
    } else if (this.isCustomerCase) {
      // Nếu là Customer Case thì hiển thị highlight khi có tài khoản liên kết và customer type = existing
      if (this.hasAccountOrContract && this.customerType != "Non-existing") {
        return true;
      } else {
        return false;
      }
    }
  }
  // ===============================
  // RESET VIEW MODE (ONE TIME ONLY)
  // ===============================
  tryResetViewMode() {
    if (!this._resetDone) {
      this._resetDone = true;
      if (this.viewMode === "handling") {
        resetViewMode({
          recordId: this.recordId,
          viewMode: "review",
        })
          .then((res) => {
            this.viewMode = res;
            console.log(
              "Update viewMode to review successfully in Fec_InteractionHighlightMain",
            );
            this.handlePublishMode(this.viewMode === "handling");
          })
          .catch((error) => {
            console.error("resetViewMode error:", error);
          });
      }
    }
  }

  // ===============================
  // CHILD DATA UPDATE
  // ===============================
  handleDataUpdate(event) {
    const data = event.detail?.data;
    if (!data) return;

    const interactionIdValue =
      data.interactionId || data.interactionIdSearch || "";

    if (interactionIdValue) {
      const tempDiv = document.createElement("div");
      tempDiv.innerHTML = interactionIdValue;
      this.interactionId =
        tempDiv.textContent || tempDiv.innerText || interactionIdValue;
    }

    this.customerSegment = data.customerSegment || "";
  }

  // ===============================
  // ACTIONS
  // ===============================
  handleWrapUpClick() {
    const slaComponent = this.template.querySelector(
      "c-fec_-interaction-s-l-a",
    );
    slaComponent?.handleWrapUpClick?.();
  }

  handleExecute() {
    resetViewMode({ recordId: this.recordId, viewMode: "handling" })
      .then(() => {
        this.viewMode = "handling";
        //this._resetDone = false;
        console.log(
          "Update viewMode to handling successfully in Fec_InteractionHighlightMain handleExecute",
        );
      })
      .catch((error) => {
        console.error("resetViewMode error:", error);
      });

    this.handlePublishMode(true);
  }

  async handleCreateCase() {
    console.log("handleCreateCase from creation highlight");
    if (this.isConsoleNavigation) {
      await openTab({
        url: `/lightning/cmp/c__fec_InteractionCreateCase?c__recordId=${this.createCaseSourceId}`,
        focus: true,
      });
    } else {
      this[NavigationMixin.Navigate]({
        type: "standard__component",
        attributes: {
          componentName: "c__fec_InteractionCreateCase",
        },
        state: {
          c__recordId: this.createCaseSourceId,
        },
      });
    }
  }

  async handlePublishMode(isEdit) {
    const payload = {
      isModeEdit: isEdit,
    };

    publish(this.messageContext, IS_MODE_EDIT, payload);
  }

  // subscription = null;

  // ===============================
  // LIFECYCLE HOOKS (SUBSCRIBE)
  // ===============================
  connectedCallback() {
    console.log("connectedCallback");
  }

}
