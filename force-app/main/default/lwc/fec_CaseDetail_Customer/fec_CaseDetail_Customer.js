import { LightningElement, track, api, wire } from "lwc";
import {
  subscribe,
  unsubscribe,
  publish,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import {
  getFocusedTabInfo,
  closeTab,
  IsConsoleNavigation,
} from "lightning/platformWorkspaceApi";
import saveCaseDrafts from "@salesforce/apex/FEC_CaseBusinessService.saveCaseDrafts";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import clearDraftRemarks from "@salesforce/apex/FEC_CaseRemarkController.clearDraftRemarks";
import FEC_Button_Save_Close from "@salesforce/label/c.FEC_Button_Save_Close";
import FEC_Button_Submit from "@salesforce/label/c.FEC_Button_Submit";
import FEC_MSG_Submit from "@salesforce/label/c.FEC_MSG_Submit";
import FEC_Case_Remark_Label from "@salesforce/label/c.FEC_Case_Remark_Label";
import FEC_Tab_Nature_Of_Case from "@salesforce/label/c.FEC_Tab_Nature_Of_Case";
import getCase from "@salesforce/apex/FEC_CaseEditNOCController.getCase";

import { RefreshEvent } from "lightning/refresh";

import getRemarklst from "@salesforce/apex/FEC_CaseRemarkController.getRemarklst";

const REQUIRED_MSG = "{0} can't be Blank";

import { formatDateTime } from "c/fec_CommonUtils";
import {
  STR_EMPTY,
  STR_UNDEFINED,
  VIEW_MODE_HANDLING,
  VIEW_MODE_REVIEW,
  // RECORD_TYPE_INTERNAL_CASE
} from "c/fec_CommonConst";

export default class Fec_CaseDetail_Customer extends LightningElement {
  @api recordId;
  @api modeEditCase;

  @wire(MessageContext)
  messageContext;

  @wire(IsConsoleNavigation)
  isConsoleNavigation;

  subscription = null;
  nocSubscription = null;

  @track activeSections = ["case-remark-history"];

  @track errlst = [];

  get hasError() {
    return this.errlst && this.errlst.length > 0;
  }

  get labelSaveClose() {
    return FEC_Button_Save_Close;
  }

  get labelSubmit() {
    return FEC_Button_Submit;
  }

  get caseRemarkLabel() {
    return FEC_Case_Remark_Label;
  }

  get caseRemarkSectionLabel() {
    return "* " + FEC_Case_Remark_Label;
  }

  /** Disable nút Submit khi đang xử lý để tránh double-click tạo 2 bản ghi. */
  get isSubmitDisabled() {
    return !this.isLoaded;
  }

  @track remarklst = [];
  isLoaded = false;
  isSubmitting = false;

  get remarkColumnlst() {
    return [
      { label: FEC_Case_Remark_Label, fieldName: "FEC_Case_Remarks__c" },
      { label: "Stage Name", fieldName: "FEC_Stage_Name__c" },
      { label: "User", fieldName: "FEC_User__c" },
      { label: "User Role", fieldName: "FEC_User_Role__c" },
      { label: "Date Time", fieldName: "CreatedDate" },
    ];
  }

  loadRemarklst = false;

  /** Lưu natureOfCaseId cuối từ message NOC để dùng khi Submit (fallback khi getData không set). */
  lastNatureOfCaseIdFromNOC = null;

  /** Load lại Case Remarks History (dùng khi mở trang và sau khi submit remark). */
  loadRemarkHistory() {
    if (!this.recordId) return;
    getRemarklst({ caseId: this.recordId })
      .then((res) => {
        this.remarklst = res
          .filter((item) => item.Id)
          .map((item) => ({
            ...item,
            CreatedDate: formatDateTime(item.CreatedDate),
          }));

        this.loadRemarklst = true;
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseRemarks ~ loadRemarks ~ err:", err);
      })
      .finally(() => { });
  }

  async connectedCallback() {
    try {
      await resetViewMode({
        recordId: this.recordId,
        viewMode: VIEW_MODE_REVIEW,
      });

      this.subscribeToMessageChannel();
      this.loadRemarkHistory();
    } catch (err) {
      console.error("Failed to reset view mode:", err);
    } finally {
      this.isLoaded = true;
    }
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE },
    );

    this.nocSubscription = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this.handleNOCMsg(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  handleMessage(message) {
    console.log('>>>>>>handleMessage isModeEdit: ', message.isModeEdit);
    if (message == null || typeof message.isModeEdit === STR_UNDEFINED) return;

    this.modeEditCase = message.isModeEdit === true;

    resetViewMode({
      recordId: this.recordId,
      viewMode: this.modeEditCase ? VIEW_MODE_HANDLING : VIEW_MODE_REVIEW,
    })
      .then((res) => {
        this.dispatchEvent(new RefreshEvent());
      })
      .catch((err) => { })
      .finally(() => {
        if (this.modeEditCase) {
          if (!this.activeSections.includes("case-remark")) {
            this.activeSections = [...this.activeSections, "case-remark"];
          }
        } else {
          this.activeSections = this.activeSections.filter(
            (sec) => sec !== "case-remark",
          );
        }
      });

    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness",
    );

    if (caseBusinessEle) {
      // Luôn gọi getData khi đổi mode: review → load lại từ server (NOC, Account Info vừa lưu)
      caseBusinessEle.getData();
    }
  }

  handleNOCMsg(message) {
    if (message == null) return;
    if (message.natureOfCaseId) this.lastNatureOfCaseIdFromNOC = message.natureOfCaseId;
    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness",
    );

    if (caseBusinessEle) {
      caseBusinessEle.getData(
        message.productTypeId,
        message.categoryId,
        message.subCategoryId,
        message.subCodeId,
        message.natureOfCaseId,
      );
    }
  }

  async handlePublishMode(isEdit) {
    if (this.messageContext == null) return;
    const payload = {
      isModeEdit: Boolean(isEdit),
    };
    publish(this.messageContext, IS_MODE_EDIT, payload);
  }

  /**
   * Save & Close: Lưu toàn bộ thông tin (Nature of Case, Account Info, Case Info,
   * Process Action, Routing Action, Case Remarks) nhưng KHÔNG chuyển sang Stage tiếp theo.
   * Sau khi lưu xong đóng tab hiện tại.
   */
  handleSave() {
    const caseRemarksEle = this.template.querySelector("c-fec_-case-remarks");
    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness",
    );
    this.errlst = [];

    this.isLoaded = false;

    const natureOfCaseId = caseBusinessEle?.getNatureOfCaseId?.() ?? null;
    const updatedPhoneNumber =
      caseBusinessEle?.getUpdatedInfoPhoneNumber?.() ?? null;
    const routingActionCode = caseBusinessEle?.getRoutingActionCode?.() ?? null;
    const saveDraftsPromise = this.recordId
      ? saveCaseDrafts({
        caseId: this.recordId,
        natureOfCaseId: natureOfCaseId ?? STR_EMPTY,
        updatedPhoneNumber: updatedPhoneNumber ?? STR_EMPTY,
        routingActionCode: routingActionCode ?? null,
      })
      : Promise.resolve();
    const stageNameForSave = caseBusinessEle?.getStageName?.() ?? STR_EMPTY;
    const saveRemarkPromise = caseRemarksEle
      ? caseRemarksEle.createRemark(stageNameForSave)
      : Promise.resolve();
    const saveBusinessPromise = caseBusinessEle
      ? Promise.resolve(caseBusinessEle.saveOnly())
      : Promise.resolve();

    saveDraftsPromise
      .then(() => Promise.all([saveRemarkPromise, saveBusinessPromise]))
      .then(() => {
        setTimeout(async () => {
          this.handlePublishMode(false);
          await this.closeCurrentTab();
        }, 0);
      })
      .catch((error) => {
        console.error(
          "🚀 ~ Fec_CaseDetail_Customer ~ handleSave ~ error:",
          error,
        );
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  async closeCurrentTab() {
    if (!this.isConsoleNavigation) return;
    try {
      const tabInfo = await getFocusedTabInfo();
      if (tabInfo?.tabId) {
        await closeTab(tabInfo.tabId);
      }
    } catch (err) {
      console.warn("closeCurrentTab:", err);
    }
  }

  /** Tránh double-click Submit gây tạo 2 bản ghi Case Remark. */
  async handleSubmit() {
    if (this.isSubmitting) return;
    this.isSubmitting = true;

    let isAllValid = true;
    this.errlst = [];

    const caseRemarksEle = this.template.querySelector("c-fec_-case-remarks");
    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness",
    );

    if (caseBusinessEle && !caseBusinessEle.getNatureOfCaseId() && this.lastNatureOfCaseIdFromNOC) {
      caseBusinessEle.setNatureOfCaseId(this.lastNatureOfCaseIdFromNOC);
    }
    if (caseBusinessEle) {
      const validateResult = caseBusinessEle.validate();
      const validateNatureResult = caseBusinessEle.validateNatureOfCase();
      if (!validateResult) {
        isAllValid = false;
        if (!validateNatureResult) {
          this.errlst.push(REQUIRED_MSG.replace("{0}", FEC_Tab_Nature_Of_Case));
        }
        // const accountContractErr = caseBusinessEle.getLastValidationError?.();
        // if (accountContractErr) {
        //   this.errlst.push(REQUIRED_MSG.replace("{0}", accountContractErr));
        // }
      }
    }
    if (!caseRemarksEle || !caseRemarksEle.validate()) {
      isAllValid = false;
      this.errlst.push(REQUIRED_MSG.replace("{0}", FEC_Case_Remark_Label));
    }

    if (!isAllValid) {
      this.isSubmitting = false;
      return;
    }

    // Kiểm tra chặn submit (vd: original === updated phone)
    if (caseBusinessEle?.checkSubmitBlock) {
      const blocked = await caseBusinessEle.checkSubmitBlock();
      if (blocked) {
        this.isSubmitting = false;
        return;
      }
    }

    this.isLoaded = false;

    try {
      const stageName = caseBusinessEle?.getStageName?.() ?? STR_EMPTY;
      // Xóa draft cũ, chỉ lưu 1 bản ghi = nội dung hiện tại trong ô (tránh sinh nhiều bản ghi từ Save & Close trước đó)
      await clearDraftRemarks({ caseId: this.recordId });

      const submitted = await caseBusinessEle.submit();
      if (submitted === false) {
        return;
      }

      // Submit xóa draft trên Case — createRemark phải sau submit rồi mới submitRemark.
      await caseRemarksEle.createRemark(stageName);
      await caseRemarksEle.submitRemark(stageName);
      this.loadRemarkHistory();

      // Chuyển sang Case Review (chế độ xem), không đóng tab
      setTimeout(() => {
        this.modeEditCase = false;
        this.handlePublishMode(false);
      }, 0);
    } catch (error) {
      console.error("Submit failed:", error);
      this.errlst = [error?.body?.message || error?.message || FEC_MSG_Submit];
    } finally {
      this.isLoaded = true;
      this.isSubmitting = false;
    }
  }
}