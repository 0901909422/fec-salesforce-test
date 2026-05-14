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
//HieuTT74: [UPDATE - 5/5/2026]: Tạo message channel cho button save/submit
import CASE_ACTION from "@salesforce/messageChannel/FEC_CaseAction__c";
import {
  getFocusedTabInfo,
  closeTab,
  IsConsoleNavigation,
} from "lightning/platformWorkspaceApi";
// tungnm37 thêm: lấy businessCode để check COF/GSR
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CASE_BUSINESS_PROCESS_CODE from "@salesforce/schema/Case.FEC_Business_Process__r.FEC_Code__c";
import saveCaseDrafts from "@salesforce/apex/FEC_CaseBusinessService.saveCaseDrafts";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";
import clearDraftRemarks from "@salesforce/apex/FEC_CaseRemarkController.clearDraftRemarks";
import FEC_Button_Save_Close from "@salesforce/label/c.FEC_Button_Save_Close";
import FEC_Button_Submit from "@salesforce/label/c.FEC_Button_Submit";
import FEC_MSG_Submit from "@salesforce/label/c.FEC_MSG_Submit";
import FEC_Case_Remark_Label from "@salesforce/label/c.FEC_Case_Remark_Label";
import FEC_Tab_Nature_Of_Case from "@salesforce/label/c.FEC_Tab_Nature_Of_Case";
import FEC_MSG_CARD_REPLACEMENT_ADDRESS_SELECT from "@salesforce/label/c.FEC_MSG_CARD_REPLACEMENT_ADDRESS_SELECT";
import getCase from "@salesforce/apex/FEC_CaseEditNOCController.getCase";

import { RefreshEvent } from "lightning/refresh";
import { updateRecord } from "lightning/uiRecordApi";

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

const PROCESS_CARD_REPLACEMENT = "Card Replacement";

export default class Fec_CaseDetail_Customer extends LightningElement {
  @api recordId;
  @api modeEditCase;

  @wire(MessageContext)
  messageContext;

  // tungnm37 thêm: wire lấy businessCode để check COF/GSR
  @wire(getRecord, { recordId: '$recordId', fields: [CASE_BUSINESS_PROCESS_CODE] })
  wiredCase({ data }) {
    if (data) {
      const code = getFieldValue(data, CASE_BUSINESS_PROCESS_CODE);
      this._isCofGsr = typeof code === 'string' && (code.startsWith('COF') || code.startsWith('GSR'));
    }
  }

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

  // tungnm37 thêm: track COF/GSR để filter remark type Assignment
  _isCofGsr = false;

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
          // tungnm37: ẩn Assignment Remark của Stage 1 (Stage 1 chỉ hiện Case Remark)
          .filter((item) => {
            if (item.FEC_Remark_Type__c === 'Assignment') {
              const stageName = item.FEC_Stage_Name__c || '';
              return !/stage\s*1/i.test(stageName);
            }
            return true;
          })
          .map((item) => ({
            ...item,
            CreatedDate: formatDateTime(item.CreatedDate),
          }));

        this.loadRemarklst = true;
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseRemarks ~ loadRemarks ~ err:", err);
      })
      .finally(() => {});
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

    const prevModeEdit = this.modeEditCase === true;
    const nextModeEdit = message.isModeEdit === true;

    // Bỏ qua nếu mode không thực sự thay đổi (tránh reload NOC khi nhận broadcast từ tab khác)
    if (prevModeEdit === nextModeEdit) return;

    this.modeEditCase = nextModeEdit;

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
      // Chỉ gọi getData khi mode thực sự đổi: tránh reset NOC do broadcast từ tab khác
      caseBusinessEle.getData();
    }
  }

  handleNOCMsg(message) {
    if (message == null) return;
    if (message.caseId !== this.recordId) {
      return;
    }
    //PhongBT: fix th đổi từ bộ noc đủ subcode sang bộ thiếu subcode thì updatedNoc lại hiển thị bộ đủ subcode
    // Always sync latest NOC natureOfCase (including null) to avoid stale fallback.
    // this.lastNatureOfCaseIdFromNOC = message.natureOfCaseId ?? null;
    if (message.natureOfCaseId)
    this.lastNatureOfCaseIdFromNOC = message.natureOfCaseId;

    // Chỉ bật edit mode khi đây là hành động thực sự của user (không phải initial load)
    if (message.isUserAction && !this.modeEditCase) {
      this.modeEditCase = true;
      if (!this.activeSections.includes("case-remark")) {
        this.activeSections = [...this.activeSections, "case-remark"];
      }
    }

    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness",
    );

    if (caseBusinessEle) {
      caseBusinessEle.getData(
        message.productTypeId ?? null,
        message.categoryId ?? null,
        message.subCategoryId ?? null,
        message.subCodeId ?? null,
        message.natureOfCaseId,
      );
      // tungnm37 thêm: track COF/GSR sau khi getData
      setTimeout(() => {
        this._isCofGsr = !!caseBusinessEle.isRoutingAssignmentMode;
      }, 500);
    }
  }

  async handlePublishMode(isEdit) {
    if (this.messageContext == null) return;
    const payload = {
      isModeEdit: Boolean(isEdit),
    };
    publish(this.messageContext, IS_MODE_EDIT, payload);
  }

  async handlePublishCaseAction(action) {
    if (this.messageContext == null) return;

    const payload = {
      action: action, // SAVE | SUBMIT
      ...(this.recordId ? { recordId: this.recordId } : {}),
    };

    console.log("📤 CASE_ACTION:", payload);

    publish(this.messageContext, CASE_ACTION, payload);
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

          this.handlePublishCaseAction("SAVE");

          await new Promise((r) => setTimeout(r, 50));

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
    this.isLoaded = false; // tungnm37: disable button ngay lập tức trước mọi xử lý

    let isAllValid = true;
    this.errlst = [];

    const caseRemarksEle = this.template.querySelector("c-fec_-case-remarks");
    const caseBusinessEle = this.template.querySelector(
      "c-fec_-case-bussiness",
    );

    if (caseBusinessEle && !caseBusinessEle.getNatureOfCaseId() && this.lastNatureOfCaseIdFromNOC) {
      caseBusinessEle.setNatureOfCaseId(this.lastNatureOfCaseIdFromNOC);
    }
    let addressInfoId;
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
      // PhuongNT add validate card replacement select address
      if (caseBusinessEle.handleGetCurrentProcessAction() == PROCESS_CARD_REPLACEMENT) {
        addressInfoId = caseBusinessEle.handleValidateAddressSelected();
        if (!addressInfoId) {
          isAllValid = false;
          this.errlst.push(FEC_MSG_CARD_REPLACEMENT_ADDRESS_SELECT);
        }
      }
    }
    if (!caseRemarksEle || !caseRemarksEle.validate()) {
      // tungnm37 thêm: COF/GSR Stage 2 với manual items → không bắt buộc Case Remarks
      const isRoutingMode = caseBusinessEle?.isRoutingAssignmentMode;
      const hasManualItems = caseBusinessEle?._manualItems?.length > 0;
      if (!(isRoutingMode && hasManualItems)) {
      isAllValid = false;
      this.errlst.push(REQUIRED_MSG.replace("{0}", FEC_Case_Remark_Label));
      }
    }

    if (!isAllValid) {
      this.isSubmitting = false;
      this.isLoaded = true;
      return;
    }

    // Kiểm tra chặn submit (vd: original === updated phone)
    if (caseBusinessEle?.checkSubmitBlock) {
      const blocked = await caseBusinessEle.checkSubmitBlock();
      if (blocked) {
        this.isSubmitting = false;
        this.isLoaded = true;
        return;
      }
    }

    // this.isLoaded = false; // đã set ở đầu handleSubmit

    try {
      const stageName = caseBusinessEle?.getStageName?.() ?? STR_EMPTY;
      // Xóa draft cũ, chỉ lưu 1 bản ghi = nội dung hiện tại trong ô (tránh sinh nhiều bản ghi từ Save & Close trước đó)
      await clearDraftRemarks({ caseId: this.recordId });

      // tungnm37 thêm: lấy remark value trước khi submit để truyền vào Apex (createAssignmentsOnRoute cần)
      if (caseBusinessEle && caseRemarksEle) {
        caseBusinessEle.remarkContent = caseRemarksEle.getRemarkValue();
      }
      const isRoutingModeSubmit = !!caseBusinessEle?.isRoutingAssignmentMode || this._isCofGsr;
      // tungnm37: COF/GSR Stage 2 + Route to → Apex đã tạo Case Remark → LWC không gọi submitRemarkDirect
      // Stage 1 → Apex không tạo Case Remark → LWC phải gọi submitRemarkDirect
      // tungnm37 fix: các action khác Route to (Escalate, Reject, Resolve...) → LWC phải gọi submitRemarkDirect dù ở stage nào
      const isStage1 = /stage\s*1/i.test(stageName);
      const currentAction = caseBusinessEle?.getRoutingActionCode?.() ?? '';
      const isRouteToAction = currentAction === 'Route_to' || currentAction === 'Route to';
      // tungnm37 fix: skipSubmitRemark chỉ khi COF/GSR + Route to + Stage 2 (Apex đã xử lý remark)
      const skipSubmitRemark = isRoutingModeSubmit && isRouteToAction && !isStage1;
      console.log('[FEC_DEBUG] handleSubmit stageName=' + stageName + ' isRoutingMode=' + isRoutingModeSubmit + ' isStage1=' + isStage1 + ' action=' + currentAction + ' skipSubmitRemark=' + skipSubmitRemark);
      const submitted = await caseBusinessEle.submit();
      if (submitted === false) {
        return;
      }
      // PhuongNT add reset msg process action after submit success
      caseBusinessEle.resetMsgProcessAction();

      if (
        caseBusinessEle &&
        typeof caseBusinessEle.refreshFileUploadCards === "function"
      ) {
        caseBusinessEle.refreshFileUploadCards();
      }
      // tungnm37: COF/GSR Stage 2 + Route to → Apex đã tạo Case Remark → skip submitRemarkDirect
      // tungnm37 fix: action khác Route to → không skip, LWC tạo Case Remark
      const hasManualItemsSubmit = skipSubmitRemark; // alias for clarity
      if (!skipSubmitRemark) {
        await caseRemarksEle.submitRemarkDirect(stageName);
      }      // tungnm37 thêm: cập nhật _isCofGsr trước khi load remark history
      this._isCofGsr = isRoutingModeSubmit;
      this.loadRemarkHistory();

      // PhuongNT add update select address for Case
      if (addressInfoId) {
        let fields = {
          'Id': this.recordId,
          'FEC_Selected_Address__c': addressInfoId,
        };
        let recordInput = { fields };
        updateRecord(recordInput);
      }

      //linhdev: Fix jira FECREDIT_CSM_2025_KH-1226
      // Chuyển sang Case Review (chế độ xem), không đóng tab — publish mode trước để handleMessage nhận
      // đổi từ edit → review (không gán modeEditCase=false trước, nếu không prev===next và bỏ qua resetViewMode/getData).
      setTimeout(async () => {
        this.handlePublishMode(false);

        this.handlePublishCaseAction("SUBMIT");

        // optional: đảm bảo message dispatch ổn định
        await new Promise((resolve) => setTimeout(resolve, 50));
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