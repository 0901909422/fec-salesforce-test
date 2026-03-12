import { LightningElement, api, track, wire } from "lwc";
import { IsConsoleNavigation, openTab, EnclosingTabId, setTabLabel } from "lightning/platformWorkspaceApi";
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
import OWNERID from "@salesforce/schema/Case.OwnerId";
import INTERACTION_RECORD_ID from "@salesforce/schema/Case.FEC_Interaction__c";
import FEC_ID_SEARCH from "@salesforce/schema/Case.FEC_ID_Search__c";
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
  ownerId;
  interactionOwnerId;
  _resetDone = false;

  // ===============================
  // CONSOLE CHECK
  // ===============================
  @wire(IsConsoleNavigation)
  isConsoleNavigation;

  isCaseClosed = false;
  isInteractionClosed;
  isOwner = false;

  // ===============================
  // LOAD CASE DATA
  // ===============================
  @wire(EnclosingTabId)
  enclosingTabId;

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
      OWNERID,
      FEC_ID_SEARCH
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
      this.ownerId = getFieldValue(data, OWNERID);

      const fecIdSearch = getFieldValue(data, FEC_ID_SEARCH);
      if (fecIdSearch && this.enclosingTabId) {
        setTabLabel(this.enclosingTabId, fecIdSearch);
      }

      if (this.recordTypeId) {
        this.loadRecordType();
      }

      this.tryResetViewMode();
    } else if (error) {
      console.error("getRecord error:", error);
    }
  }

  @wire(getRecord, {
    recordId: "$interactionRecordId",
    fields: [
      ISCLOSED,
      OWNERID
    ],
  })
  getInteraction({ data, error }) {
    if (data) {
      this.isInteractionClosed = getFieldValue(data, ISCLOSED);
      this.interactionOwnerId = getFieldValue(data, OWNERID);
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

  get showWrapupAndCreateCase() {
    // 1. Chỉ người sở hữu (Owner) mới được quyền thấy nút
    if (!this.isOwner) {
      return false;
    }

    // 4. Interaction & Customer Case là cùng owner
    if (this.isCustomerCase && this.interactionOwnerId !== this.ownerId) {
      return false;
    }

    // 2. Trạng thái bản ghi (Interaction/Case) hiện tại phải đang mở (Open)
    // Nếu có Interaction đính kèm thì dùng isInteractionClosed để xét.
    // Nếu undefined thì dùng trạng thái của parent Case (isCaseClosed).
    const isRecordOpen = (this.isInteractionCase && !this.isCaseClosed)
      || !this.isInteractionClosed;

    if (!isRecordOpen) {
      return false;
    }

    // 3. Logic hiển thị thao tác (Wrapup/Create Case)
    // - Trường hợp không phải Interaction -> cho phép thao tác ở mọi chế độ
    // - Trường hợp là Interaction -> chỉ được phép khi cờ isHandling = true
    if (!this.isInteractionCase || this.isHandling) {
      return true;
    } else {
      return false;
    }
  }

  get showExecute() {
    // 1. Chỉ người sở hữu (Owner) mới được quyền thấy nút
    if (!this.isOwner) {
      return false;
    }

    // 2. Trạng thái bản ghi hiện tại phải đang mở (Open)
    const isRecordOpen =
      this.isInteractionClosed === false ||
      (this.isInteractionClosed === undefined && !this.isCaseClosed);

    if (!isRecordOpen) {
      return false;
    }

    // 3. Logic hiển thị nút "Execute" (Bắt đầu xử lý)
    // - Phải CHƯA Ở TRONG trong chế độ xử lý (!isHandling)
    if (!this.isHandling) {
      return true;
    } else {
      return false;
    }
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
      if (this.isHandling && this.hasAccountOrContract && this.customerType != "Non-existing") {
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

  subscription = null;

  // ===============================
  // LIFECYCLE HOOKS (SUBSCRIBE)
  // ===============================
  connectedCallback() {
    console.log("connectedCallback");
    this.subscribeToMessageChannel();
  }

  disconnectedCallback() {
    this.unsubscribeToMessageChannel();
  }

  // ===============================
  // LMS HANDLERS
  // ===============================
  subscribeToMessageChannel() {
    if (!this.subscription) {
      this.subscription = subscribe(
        this.messageContext,
        IS_MODE_EDIT,
        (message) => this.handleMessage(message),
        { scope: APPLICATION_SCOPE }
      );
    }
  }

  unsubscribeToMessageChannel() {
    unsubscribe(this.subscription);
    this.subscription = null;
  }

  handleMessage(message) {
    if (!this.isInteractionCase && message && typeof message.isModeEdit !== 'undefined') {
      this.viewMode = message.isModeEdit ? 'handling' : 'review';
    }
  }
}