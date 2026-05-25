import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";

import FEC_NFU_DESCRIPTION_RESULT from "@salesforce/schema/Case.FEC_NFU_Description_Result__c";
import FEC_NFU_STATUS from "@salesforce/schema/Case.FEC_NFU_Status__c";
import FEC_NFU_CODE from "@salesforce/schema/Case.FEC_NFU_Code__c";
import FEC_NFU_STARTED_DATE from "@salesforce/schema/Case.FEC_NFU_Started_Date__c";
import FEC_NFU_EXPIRY_DATE from "@salesforce/schema/Case.FEC_NFU_Expiry_Date__c";
import FEC_NFU_REASON from "@salesforce/schema/Case.FEC_NFU_Reason__c";
import FEC_TEAM from "@salesforce/schema/Case.FEC_Team__c";
import CASE_IS_CLOSED from "@salesforce/schema/Case.IsClosed";

import FEC_Hold_Case from "@salesforce/label/c.FEC_Hold_Case";
import FEC_NFU_Code from "@salesforce/label/c.FEC_NFU_Code";
import FEC_NFU_Reason from "@salesforce/label/c.FEC_NFU_Reason";
import FEC_NFUStatus from "@salesforce/label/c.FEC_NFUStatus";
import FEC_NFUStartDate from "@salesforce/label/c.FEC_NFUStartDate";
import FEC_NFUExpiryDate from "@salesforce/label/c.FEC_NFUExpiryDate";
import FEC_STOP_IMPACT_ALREADY_MARKED_MSG from "@salesforce/label/c.FEC_STOP_IMPACT_ALREADY_MARKED_MSG";
import FEC_MSG_SUCCESS from "@salesforce/label/c.FEC_MSG_SUCCESS";
import FEC_MSG_ERROR from "@salesforce/label/c.FEC_MSG_ERROR";
import FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY from "@salesforce/label/c.FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY";
import FEC_Show_Action_Hold_Case from "@salesforce/label/c.FEC_Show_Action_Hold_Case";
import { formatDateTimeVN } from "c/fec_CommonUtils";
import { STR_EMPTY } from "c/fec_CommonConst";

const CASE_FIELDS = [
  FEC_NFU_DESCRIPTION_RESULT,
  FEC_NFU_STATUS,
  FEC_NFU_CODE,
  FEC_NFU_STARTED_DATE,
  FEC_NFU_EXPIRY_DATE,
  FEC_NFU_REASON,
  FEC_TEAM,
  CASE_IS_CLOSED,
];

const RESULT_PENDING = "PENDING";
const RESULT_ALREADY_MARKED = "ALREADY_MARKED";
const RESULT_SUCCESS = "SUCCESS";
const RESULT_ERROR = "ERROR";
const TEAM_CS_SUPPORT = "CS Support";
const TEAM_CS_CUSTOMER_CARE = "CS Customer Care";

const MODE_DEFAULT = "DEFAULT";
const MODE_ERROR_RETRY = "ERROR_RETRY";
const MODE_ERROR_RETRY_INFO_NO_AUTO = "ERROR_RETRY_INFO_NO_AUTO";
const MODE_INFO_NO_AUTO_ONLY = "INFO_NO_AUTO_ONLY";
const MODE_INFO_HAS_AUTO_BUTTON = "INFO_HAS_AUTO_BUTTON";

export default class Fec_holdCaseAuto extends NavigationMixin(LightningElement) {
  @api recordId;
  /** Fallback từ Manual Hold (sessionStorage) khi LDS chưa refresh field trên Case. */
  @api resultOverride;

  /** Stage 2+ NOC change — từ FEC_HoldCaseStage2DisplayService.evaluate */
  @api stage2DisplayMode = MODE_DEFAULT;
  @api stage2InfoMessage;
  @api stage2ErrorMessage;
  @api stage2ShowManualHoldButton = false;

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
    messageError: FEC_MSG_ERROR,
    messageErrorRetry: FEC_MSG_HOLD_CASE_AUTO_FAIL_RETRY,
    messageProcessing: "Đang xử lý yêu cầu Hold Case...",
    manualHoldCaseAction: FEC_Show_Action_Hold_Case || FEC_Hold_Case,
  };

  @wire(getRecord, { recordId: "$recordId", fields: CASE_FIELDS })
  wiredCase(result) {
    this.wiredCaseResult = result;
  }

  /** Parent gọi sau Submit khi Queueable Mark NFU hoàn tất. */
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

  get resultType() {
    if (this.resultOverride) {
      return this.resultOverride;
    }
    return getFieldValue(this.wiredCaseResult?.data, FEC_NFU_DESCRIPTION_RESULT) || STR_EMPTY;
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

  /** Ẩn section khi chưa có kết quả Auto Hold Case. */
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
    return (
      this._isStage2Override &&
      (this.stage2DisplayMode === MODE_ERROR_RETRY_INFO_NO_AUTO ||
        this.stage2DisplayMode === MODE_INFO_NO_AUTO_ONLY ||
        this.stage2DisplayMode === MODE_INFO_HAS_AUTO_BUTTON) &&
      !!this.stage2InfoMessage
    );
  }

  get responseMessage() {
    if (this.stage2DisplayMode === MODE_ERROR_RETRY ||
        this.stage2DisplayMode === MODE_ERROR_RETRY_INFO_NO_AUTO) {
      return this.stage2ErrorMessage || this.customLabel.messageErrorRetry;
    }
    if (this.resultType === RESULT_ALREADY_MARKED) {
      return this.customLabel.messageAlreadyMarked;
    }
    if (this.resultType === RESULT_SUCCESS) {
      return this.customLabel.messageSuccess;
    }
    if (this.resultType === RESULT_ERROR) {
      return this.customLabel.messageErrorRetry;
    }
    return STR_EMPTY;
  }

  /** TH1 & TH2: hiển thị block NFU Details read-only. */
  get showNfuDetails() {
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

  get isCaseClosed() {
    return getFieldValue(this.wiredCaseResult?.data, CASE_IS_CLOSED) === true;
  }

  /** TH3 / TH1: nút Hold Case thủ công (Quick Action). */
  get showManualHoldCaseButton() {
    if (this.stage2ShowManualHoldButton === true) {
      return !this.isCaseClosed;
    }
    return (
      this.resultType === RESULT_ERROR &&
      !this.isCaseClosed &&
      (this.caseTeam === TEAM_CS_SUPPORT ||
        this.caseTeam === TEAM_CS_CUSTOMER_CARE)
    );
  }

  handleManualHoldCaseClick(event) {
    event.preventDefault();
    if (!this.recordId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__quickAction",
      attributes: {
        apiName: "Case.Hold_Case",
      },
      state: {
        recordId: this.recordId,
      },
    });
  }
}
