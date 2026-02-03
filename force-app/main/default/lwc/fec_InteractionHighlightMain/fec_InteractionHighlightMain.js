import { LightningElement, api, track, wire } from "lwc";
import { IsConsoleNavigation, openTab } from "lightning/platformWorkspaceApi";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import getRecordTypeName from "@salesforce/apex/FEC_InteractionInforHandler.getRecordTypeName";

import VIEW_MODE from "@salesforce/schema/Case.FEC_Interaction_View_Mode__c";
import HAS_ACCOUNT_OR_CONTRACT from "@salesforce/schema/Case.FEC_Has_Account_or_Contract__c";
import RECORDTYPE_ID from "@salesforce/schema/Case.RecordTypeId";

import {
  publish,
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";

import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";

export default class Fec_InteractionHighlightMain extends NavigationMixin(
  LightningElement
) {
  @wire(MessageContext)
  messageContext;

  @api recordId;
  @api isModeEdit = false;

  @track interactionId = "";
  @track customerSegment = "";

  viewMode; // handling | review
  recordTypeId;
  recordTypeDevName;
  hasAccountOrContract;
  _resetDone = false;

  // ===============================
  // CONSOLE CHECK
  // ===============================
  @wire(IsConsoleNavigation)
  isConsoleNavigation;

  // ===============================
  // LOAD CASE DATA
  // ===============================
  @wire(getRecord, {
    recordId: "$recordId",
    fields: [VIEW_MODE, RECORDTYPE_ID, HAS_ACCOUNT_OR_CONTRACT],
  })
  wiredCase({ data, error }) {
    if (data) {
      this.viewMode = getFieldValue(data, VIEW_MODE);
      this.recordTypeId = getFieldValue(data, RECORDTYPE_ID);
      this.hasAccountOrContract = getFieldValue(data, HAS_ACCOUNT_OR_CONTRACT);

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
        recordId: this.recordId
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

  get isInteractionCase() {
    return this.recordTypeDevName === "Interaction";
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
          viewMode: "review"
        }).then(() => {
          this.viewMode = "review";
        }).catch(error => {
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
      "c-fec_-interaction-s-l-a"
    );
    slaComponent?.handleWrapUpClick?.();
  }

  handleExecute() {
    resetViewMode({ recordId: this.recordId, viewMode: "handling" }).then(() => {
      this.viewMode = "handling";
      this._resetDone = false;
    }).catch(error => {
      console.error("resetViewMode error:", error);
    });
    

    this.handlePublishMode(true);
  }

  async handleCreateCase() {
    if (this.isConsoleNavigation) {
      await openTab({
        url: `/lightning/cmp/c__fec_InteractionCreateCase?c__recordId=${this.recordId}`,
        focus: true
      });
    } else {
      this[NavigationMixin.Navigate]({
        type: "standard__component",
        attributes: {
          componentName: "c__fec_InteractionCreateCase"
        },
        state: {
          c__recordId: this.recordId
        }
      });
    }
  }

  async handlePublishMode(isEdit) {
    const payload = {
      isModeEdit: isEdit
    };

    publish(this.messageContext, IS_MODE_EDIT, payload);
  }

  // subscription = null; 

  // ===============================
  // LIFECYCLE HOOKS (SUBSCRIBE)
  // ===============================
  connectedCallback() {
    console.log('connectedCallback');
  }

  // disconnectedCallback() {
  //   this.unsubscribeToMessageChannel();
  // }

  // // ===============================
  // // LMS HANDLERS
  // // ===============================
  // subscribeToMessageChannel() {
  //   if (!this.subscription) {
  //     this.subscription = subscribe(
  //       this.messageContext,
  //       IS_MODE_EDIT,
  //       (message) => this.handleMessage(message),
  //       { scope: APPLICATION_SCOPE }
  //     );
  //   }
  // }

  // unsubscribeToMessageChannel() {
  //   unsubscribe(this.subscription);
  //   this.subscription = null;
  // }

  // handleMessage(message) {
  //   // Check if the message contains the isModeEdit property
  //   if (message && typeof message.isModeEdit !== 'undefined') {
  //       this.isModeEdit = message.isModeEdit;

  //       // Optional: If you need to verify it matches the current record
  //       // if (message.recordId === this.recordId) { ... }
  //   }
  // }
}