import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import enqueueAutoHoldRetryForCase from "@salesforce/apex/FEC_AutoHoldCaseService.enqueueAutoHoldRetryForCase";

import FEC_NFU_DESCRIPTION_RESULT from "@salesforce/schema/Case.FEC_NFU_Description_Result__c";
import FEC_PROCESS_ACTION_COUNT from "@salesforce/schema/Case.FEC_Process_Action_Count__c";
import FEC_NFU_STATUS from "@salesforce/schema/Case.FEC_NFU_Status__c";
import FEC_NFU_CODE from "@salesforce/schema/Case.FEC_NFU_Code__c";
import FEC_NFU_STARTED_DATE from "@salesforce/schema/Case.FEC_NFU_Started_Date__c";
import FEC_NFU_EXPIRY_DATE from "@salesforce/schema/Case.FEC_NFU_Expiry_Date__c";
import FEC_NFU_REASON from "@salesforce/schema/Case.FEC_NFU_Reason__c";
import FEC_TEAM from "@salesforce/schema/Case.FEC_Team__c";
import FEC_PRODUCT_TYPE from "@salesforce/schema/Case.FEC_Product_Type__c";
import FEC_CATEGORY from "@salesforce/schema/Case.FEC_Category__c";
import FEC_SUB_CATEGORY from "@salesforce/schema/Case.FEC_SubCategory__c";
import FEC_SUB_CODE from "@salesforce/schema/Case.FEC_SubCode__c";
import CASE_STATUS from "@salesforce/schema/Case.Status";
import CASE_IS_CLOSED from "@salesforce/schema/Case.IsClosed";

import FEC_Hold_Case from "@salesforce/label/c.FEC_Hold_Case";
import FEC_NFU_Code from "@salesforce/label/c.FEC_NFU_Code";
import FEC_NFU_Reason from "@salesforce/label/c.FEC_NFU_Reason";
import FEC_NFUStatus from "@salesforce/label/c.FEC_NFUStatus";
import FEC_NFUStartDate from "@salesforce/label/c.FEC_NFUStartDate";
import FEC_NFUExpiryDate from "@salesforce/label/c.FEC_NFUExpiryDate";
import FEC_STOP_IMPACT_ALREADY_MARKED_MSG from "@salesforce/label/c.FEC_STOP_IMPACT_ALREADY_MARKED_MSG";
import FEC_MSG_SUCCESS from "@salesforce/label/c.FEC_MSG_SUCCESS";
import FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY from "@salesforce/label/c.FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY";
import FEC_MSG_ERROR from "@salesforce/label/c.FEC_MSG_ERROR";
import { formatDateTimeVN } from "c/fec_CommonUtils";
import { STR_EMPTY } from "c/fec_CommonConst";

/** Giới hạn retry — đọc Case.FEC_Process_Action_Count__c (giống Pin Reset). */
const MAX_HOLD_CASE_CLICKS = 3;

const CASE_FIELDS = [
  FEC_NFU_DESCRIPTION_RESULT,
  FEC_PROCESS_ACTION_COUNT,
  FEC_NFU_STATUS,
  FEC_NFU_CODE,
  FEC_NFU_STARTED_DATE,
  FEC_NFU_EXPIRY_DATE,
  FEC_NFU_REASON,
  FEC_TEAM,
  CASE_STATUS,
  CASE_IS_CLOSED,
];

const RESULT_PENDING = "PENDING";
const RESULT_ALREADY_MARKED = "ALREADY_MARKED";
const RESULT_SUCCESS = "SUCCESS";
const RESULT_ERROR = "ERROR";
const TEAM_CS_SUPPORT = "CS Support";
const TEAM_CS_SUPPORT_VALUE = "CSSupport";
const TEAM_CS_CUSTOMER_CARE = "CS Customer Care";

const MODE_DEFAULT = "DEFAULT";
const MODE_ERROR_RETRY = "ERROR_RETRY";
const MODE_ERROR_RETRY_INFO_NO_AUTO = "ERROR_RETRY_INFO_NO_AUTO";
const MODE_INFO_NO_AUTO_ONLY = "INFO_NO_AUTO_ONLY";
const MODE_SUCCESS_WITH_INFO_NO_AUTO = "SUCCESS_WITH_INFO_NO_AUTO";
const MODE_SUCCESS_WITH_INFO_HAS_AUTO = "SUCCESS_WITH_INFO_HAS_AUTO";
const MODE_INFO_HAS_AUTO_BUTTON = "INFO_HAS_AUTO_BUTTON";

export default class Fec_holdCaseAuto extends LightningElement {
  @api recordId;
  /** Từ fec_CaseBussiness — chỉ hiện nút Hold Case khi case ở chế độ edit (sau Execute). */
  @api isEdit;
  /** Stage hiện tại của Case; Stage 1 không hiển thị nút Hold Case Auto retry. */
  @api isStage1 = false;
  /** Fallback từ Manual Hold (sessionStorage) hoặc PENDING khi đang chạy Auto Hold retry. */
  @api resultOverride;

  /** Stage 2+ NOC change — từ FEC_HoldCaseStage2DisplayService.evaluate */
  @api stage2DisplayMode = MODE_DEFAULT;
  @api stage2InfoMessage;
  @api stage2ErrorMessage;
  @api stage2ShowManualHoldButton = false;

  /** Bộ NOC Stage 1 (baseline) — không dùng NOC draft trên UI khi retry Hold Case. */
  @api stage1ProductTypeId;
  @api stage1CategoryId;
  @api stage1SubCategoryId;
  @api stage1SubCodeId;

  isAutoHoldRetrying = false;
  wiredCaseResult;

  customLabel = {
    holdCase: FEC_Hold_Case,
    nfuDetails: "NFU Details",
    nfuStatus: FEC_NFUStatus,
    nfuCode: FEC_NFU_Code,
    nfuStartedDate: FEC_NFUStartDate,
    nfuExpiryDate: FEC_NFUExpiryDate,
    nfuReason: FEC_NFU_Reason,
    messageAlreadyMarked: FEC_STOP_IMPACT_ALREADY_MARKED_MSG,
    messageSuccess: FEC_MSG_SUCCESS,
    messageErrorRetry: FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY,
    messageErrorMaxFail: FEC_MSG_ERROR,
    messageProcessing: "Đang xử lý yêu cầu Hold Case...",
    holdCaseRetryAction: FEC_Hold_Case,
  };

  /** Số lần Hold Case Auto fail — Case.FEC_Process_Action_Count__c (-1/null → 0). */
  get holdCaseRetryCount() {
    const raw = getFieldValue(
      this.wiredCaseResult?.data,
      FEC_PROCESS_ACTION_COUNT,
    );
    if (raw === null || raw === undefined || raw < 0) {
      return 0;
    }
    return Number(raw);
  }

  /** Ẩn nút khi processActionCount >= 3 (giống Pin Reset). */
  get isMaxHoldCaseRetriesReached() {
    return this.holdCaseRetryCount >= MAX_HOLD_CASE_CLICKS;
  }

  /** Lần 3 bấm xong mà vẫn ERROR → thông báo max fail (giống FEC_RESET_PIN_FAILED). */
  get isThirdClickFailed() {
    return this.isMaxHoldCaseRetriesReached && this.resultType === RESULT_ERROR;
  }

  @wire(getRecord, { recordId: "$recordId", fields: CASE_FIELDS })
  wiredCase(result) {
    this.wiredCaseResult = result;
    const rt = getFieldValue(result?.data, FEC_NFU_DESCRIPTION_RESULT);
    if (rt && rt !== RESULT_PENDING) {
      this.isAutoHoldRetrying = false;
    }
    if (this.resultOverride === RESULT_PENDING) {
      this.isAutoHoldRetrying = false;
    }
  }

  @api
  refresh() {
    if (this.wiredCaseResult) {
      return refreshApex(this.wiredCaseResult);
    }
    return Promise.resolve();
  }

  get _isStage2Override() {
    return this.stage2DisplayMode && this.stage2DisplayMode !== MODE_DEFAULT;
  }

  /** Hold Case đã thành công ở Stage 1 — luôn giữ giao diện success + NFU ở các stage sau. */
  get _isStage1HoldSuccess() {
    return (
      this.resultType === RESULT_ALREADY_MARKED ||
      this.resultType === RESULT_SUCCESS
    );
  }

  get resultType() {
    const wiredResult =
      getFieldValue(this.wiredCaseResult?.data, FEC_NFU_DESCRIPTION_RESULT) ||
      STR_EMPTY;
    if (
      this.resultOverride === RESULT_PENDING &&
      wiredResult &&
      wiredResult !== RESULT_PENDING
    ) {
      return wiredResult;
    }
    if (this.resultOverride) {
      return this.resultOverride;
    }
    return wiredResult;
  }

  get nfuStatus() {
    return getFieldValue(this.wiredCaseResult?.data, FEC_NFU_STATUS) || STR_EMPTY;
  }

  get nfuCode() {
    return getFieldValue(this.wiredCaseResult?.data, FEC_NFU_CODE) || STR_EMPTY;
  }

  get nfuReason() {
    return getFieldValue(this.wiredCaseResult?.data, FEC_NFU_REASON) || STR_EMPTY;
  }

  get nfuStartedDateDisplay() {
    const raw = getFieldValue(this.wiredCaseResult?.data, FEC_NFU_STARTED_DATE);
    if (!raw) {
      return STR_EMPTY;
    }
    return formatDateTimeVN(raw) || STR_EMPTY;
  }

  get nfuExpiryDateDisplay() {
    const raw = getFieldValue(this.wiredCaseResult?.data, FEC_NFU_EXPIRY_DATE);
    if (!raw) {
      return STR_EMPTY;
    }
    return formatDateTimeVN(raw) || STR_EMPTY;
  }

  get hasResult() {
    if (this._isStage2Override) {
      return (
        this.isErrorMessage ||
        this.isSuccessMessage ||
        this.hasStage2InfoMessage
      );
    }
    return (
      this.resultType === RESULT_ALREADY_MARKED ||
      this.resultType === RESULT_SUCCESS ||
      this.resultType === RESULT_ERROR
    );
  }

  get hasVisibleContent() {
    if (this._isStage2Override) {
      return (
        this.hasStage2InfoMessage ||
        this.isErrorMessage ||
        this.isSuccessMessage ||
        this.showManualHoldCaseButton
      );
    }
    return this.isPending || this.hasResult;
  }

  get isPending() {
    if (this._isStage2Override) {
      return false;
    }
    return this.resultType === RESULT_PENDING;
  }

  get isSuccessMessage() {
    if (this._isStage1HoldSuccess) {
      return true;
    }
    if (this.stage2DisplayMode === MODE_INFO_NO_AUTO_ONLY) {
      return false;
    }
    if (this._isStage2Override && this.stage2DisplayMode !== MODE_DEFAULT) {
      return false;
    }
    return (
      this.resultType === RESULT_ALREADY_MARKED ||
      this.resultType === RESULT_SUCCESS
    );
  }

  get isErrorMessage() {
    if (this.stage2DisplayMode === MODE_ERROR_RETRY) {
      return true;
    }
    if (this.stage2DisplayMode === MODE_ERROR_RETRY_INFO_NO_AUTO) {
      return true;
    }
    return this.resultType === RESULT_ERROR;
  }

  get hasStage2InfoMessage() {
    if (!this.stage2InfoMessage) {
      return false;
    }
    return (
      this.stage2DisplayMode === MODE_SUCCESS_WITH_INFO_NO_AUTO ||
      this.stage2DisplayMode === MODE_SUCCESS_WITH_INFO_HAS_AUTO ||
      this.stage2DisplayMode === MODE_ERROR_RETRY_INFO_NO_AUTO ||
      this.stage2DisplayMode === MODE_INFO_NO_AUTO_ONLY ||
      this.stage2DisplayMode === MODE_INFO_HAS_AUTO_BUTTON
    );
  }

  _errorResponseMessage() {
    // Stage 1 submit auto-hold lỗi: chỉ hiển thị thông báo fail cuối, không kèm retry.
    if (this.isStage1 === true || this.isStage1 === "true") {
      return this.customLabel.messageErrorMaxFail;
    }
    if (this.isThirdClickFailed) {
      return this.customLabel.messageErrorMaxFail;
    }
    return this.customLabel.messageErrorRetry;
  }

  get responseMessage() {
    if (
      this.stage2DisplayMode === MODE_ERROR_RETRY ||
      this.stage2DisplayMode === MODE_ERROR_RETRY_INFO_NO_AUTO
    ) {
      if (this.stage2DisplayMode === MODE_ERROR_RETRY_INFO_NO_AUTO) {
        return this.stage2ErrorMessage || this.customLabel.messageErrorRetry;
      }
      return this._errorResponseMessage();
    }
    if (this.resultType === RESULT_ALREADY_MARKED) {
      return this.customLabel.messageAlreadyMarked;
    }
    if (this.resultType === RESULT_SUCCESS) {
      return this.customLabel.messageSuccess;
    }
    if (this.resultType === RESULT_ERROR) {
      return this._errorResponseMessage();
    }
    return STR_EMPTY;
  }

  get showNfuDetails() {
    if (this._isStage1HoldSuccess) {
      return true;
    }
    if (this._isStage2Override) {
      return false;
    }
    return (
      this.resultType === RESULT_ALREADY_MARKED ||
      this.resultType === RESULT_SUCCESS
    );
  }

  get caseTeam() {
    return getFieldValue(this.wiredCaseResult?.data, FEC_TEAM) || STR_EMPTY;
  }

  get caseStatus() {
    return getFieldValue(this.wiredCaseResult?.data, CASE_STATUS) || STR_EMPTY;
  }

  get isCaseClosed() {
    return getFieldValue(this.wiredCaseResult?.data, CASE_IS_CLOSED) === true;
  }

  _isEligibleHoldCaseTeam(team, caseStatus = STR_EMPTY) {
    const normalized = (team || STR_EMPTY).trim();
    if (normalized) {
      if (
        normalized === TEAM_CS_SUPPORT ||
        normalized === TEAM_CS_SUPPORT_VALUE ||
        normalized === TEAM_CS_CUSTOMER_CARE
      ) {
        return true;
      }
      const parts = normalized.split("_");
      if (
        parts.some(
          (p) =>
            p.trim() === TEAM_CS_SUPPORT ||
            p.trim() === TEAM_CS_SUPPORT_VALUE ||
            p.trim() === TEAM_CS_CUSTOMER_CARE,
        )
      ) {
        return true;
      }
    }
    const status = (caseStatus || STR_EMPTY).trim();
    return (
      status.includes(TEAM_CS_SUPPORT_VALUE) ||
      status.includes(TEAM_CS_SUPPORT) ||
      status.includes(TEAM_CS_CUSTOMER_CARE)
    );
  }

  get isHoldCaseRetryDisabled() {
    return (
      this.isCaseClosed ||
      this.isAutoHoldRetrying ||
      this.resultType === RESULT_PENDING ||
      this.isMaxHoldCaseRetriesReached
    );
  }

  get _inHoldCaseRetryFlow() {
    return (
      this.resultType === RESULT_ERROR ||
      this.resultType === RESULT_PENDING
    );
  }

  /** NOC Stage 1 gửi Apex — ưu tiên baseline từ parent, fallback Case đã lưu. */
  _resolvedStage1NocIds() {
    const pt =
      this.stage1ProductTypeId ||
      getFieldValue(this.wiredCaseResult?.data, FEC_PRODUCT_TYPE);
    const cat =
      this.stage1CategoryId ||
      getFieldValue(this.wiredCaseResult?.data, FEC_CATEGORY);
    const sub =
      this.stage1SubCategoryId ||
      getFieldValue(this.wiredCaseResult?.data, FEC_SUB_CATEGORY);
    const code =
      this.stage1SubCodeId !== undefined && this.stage1SubCodeId !== null
        ? this.stage1SubCodeId
        : getFieldValue(this.wiredCaseResult?.data, FEC_SUB_CODE);
    return {
      productTypeId: pt || null,
      categoryId: cat || null,
      subCategoryId: sub || null,
      subCodeId: code ?? null,
    };
  }

  get isCaseEditMode() {
    return this.isEdit === true || this.isEdit === "true";
  }

  /** User tạo Case có thể retry Hold Case ở Stage 2 khi còn đủ điều kiện. */
  get isCaseCreatorAfterSubmit() {
    return false;
  }

  /**
   * Luôn hiện nút Hold Case khi chưa max retry (không phụ thuộc đổi NOC trên UI).
   * PENDING chỉ disable, không ẩn.
   */
  get showManualHoldCaseButton() {
    if (this.isStage1 === true || this.isStage1 === "true") {
      return false;
    }
    if (!this.isCaseEditMode) {
      return false;
    }
    if (this.isCaseCreatorAfterSubmit) {
      return false;
    }
    if (this.isCaseClosed || this.isMaxHoldCaseRetriesReached) {
      return false;
    }
    if (
      this.stage2DisplayMode === MODE_INFO_NO_AUTO_ONLY ||
      this.stage2DisplayMode === MODE_SUCCESS_WITH_INFO_NO_AUTO ||
      this.stage2DisplayMode === MODE_SUCCESS_WITH_INFO_HAS_AUTO
    ) {
      return false;
    }
    if (this.stage2DisplayMode === MODE_ERROR_RETRY) {
      return this.stage2ShowManualHoldButton === true;
    }
    if (this._inHoldCaseRetryFlow) {
      return true;
    }
    if (
      this.stage2DisplayMode === MODE_INFO_HAS_AUTO_BUTTON ||
      this.stage2DisplayMode === MODE_ERROR_RETRY_INFO_NO_AUTO
    ) {
      return true;
    }
    if (this.stage2ShowManualHoldButton === true) {
      return true;
    }
    return (
      this.resultType === RESULT_ERROR &&
      this._isEligibleHoldCaseTeam(this.caseTeam, this.caseStatus)
    );
  }

  async handleManualHoldCaseClick(event) {
    event.preventDefault();
    if (
      !this.recordId ||
      !this.isCaseEditMode ||
      this.isCaseCreatorAfterSubmit ||
      this.isCaseClosed ||
      this.isAutoHoldRetrying ||
      this.resultType === RESULT_PENDING ||
      this.isMaxHoldCaseRetriesReached
    ) {
      return;
    }

    const clickNumber = this.holdCaseRetryCount + 1;
    const stage1Noc = this._resolvedStage1NocIds();
    this.isAutoHoldRetrying = true;
    try {
      await enqueueAutoHoldRetryForCase({
        caseId: this.recordId,
        attemptNumber: clickNumber,
        stage1ProductTypeId: stage1Noc.productTypeId,
        stage1CategoryId: stage1Noc.categoryId,
        stage1SubCategoryId: stage1Noc.subCategoryId,
        stage1SubCodeId: stage1Noc.subCodeId,
      });
      if (this.wiredCaseResult) {
        await refreshApex(this.wiredCaseResult);
      }
      this.isAutoHoldRetrying = false;
      this.dispatchEvent(
        new CustomEvent("autoholdretryrequested", {
          bubbles: true,
          composed: true,
          detail: { clickNumber },
        }),
      );
    } catch (error) {
      this.isAutoHoldRetrying = false;
      // eslint-disable-next-line no-console
      console.error("[fec_holdCaseAuto] enqueueAutoHoldRetryForCase", error);
    }
  }
}
