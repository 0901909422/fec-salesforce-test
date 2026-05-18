import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";

import FEC_NFU_DESCRIPTION_RESULT from "@salesforce/schema/Case.FEC_NFU_Description_Result__c";
import FEC_NFU_STATUS from "@salesforce/schema/Case.FEC_NFU_Status__c";
import FEC_NFU_CODE from "@salesforce/schema/Case.FEC_NFU_Code__c";
import FEC_NFU_STARTED_DATE from "@salesforce/schema/Case.FEC_NFU_Started_Date__c";
import FEC_NFU_EXPIRY_DATE from "@salesforce/schema/Case.FEC_NFU_Expiry_Date__c";
import FEC_NFU_REASON from "@salesforce/schema/Case.FEC_NFU_Reason__c";

import FEC_Hold_Case from "@salesforce/label/c.FEC_Hold_Case";
import FEC_NFU_Code from "@salesforce/label/c.FEC_NFU_Code";
import FEC_NFU_Reason from "@salesforce/label/c.FEC_NFU_Reason";
import FEC_NFUStatus from "@salesforce/label/c.FEC_NFUStatus";
import FEC_NFUStartDate from "@salesforce/label/c.FEC_NFUStartDate";
import FEC_NFUExpiryDate from "@salesforce/label/c.FEC_NFUExpiryDate";
import FEC_STOP_IMPACT_ALREADY_MARKED_MSG from "@salesforce/label/c.FEC_STOP_IMPACT_ALREADY_MARKED_MSG";
import FEC_MSG_SUCCESS from "@salesforce/label/c.FEC_MSG_SUCCESS";
import FEC_MSG_ERROR from "@salesforce/label/c.FEC_MSG_ERROR";
import { formatDateTimeVN } from "c/fec_CommonUtils";
import { STR_EMPTY } from "c/fec_CommonConst";

const CASE_FIELDS = [
  FEC_NFU_DESCRIPTION_RESULT,
  FEC_NFU_STATUS,
  FEC_NFU_CODE,
  FEC_NFU_STARTED_DATE,
  FEC_NFU_EXPIRY_DATE,
  FEC_NFU_REASON,
];

const RESULT_PENDING = "PENDING";
const RESULT_ALREADY_MARKED = "ALREADY_MARKED";
const RESULT_SUCCESS = "SUCCESS";
const RESULT_ERROR = "ERROR";

export default class Fec_holdCaseAuto extends LightningElement {
  @api recordId;
  /** Fallback từ Manual Hold (sessionStorage) khi LDS chưa refresh field trên Case. */
  @api resultOverride;

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
    messageProcessing: "Đang xử lý yêu cầu Hold Case...",
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
    return (
      this.resultType === RESULT_ALREADY_MARKED ||
      this.resultType === RESULT_SUCCESS ||
      this.resultType === RESULT_ERROR
    );
  }

  /** Ẩn section khi chưa có kết quả Auto Hold Case. */
  get hasVisibleContent() {
    return this.isPending || this.hasResult;
  }

  get isPending() {
    return this.resultType === RESULT_PENDING;
  }

  get isSuccessMessage() {
    return (
      this.resultType === RESULT_ALREADY_MARKED ||
      this.resultType === RESULT_SUCCESS
    );
  }

  get isErrorMessage() {
    return this.resultType === RESULT_ERROR;
  }

  get responseMessage() {
    if (this.resultType === RESULT_ALREADY_MARKED) {
      return this.customLabel.messageAlreadyMarked;
    }
    if (this.resultType === RESULT_SUCCESS) {
      return this.customLabel.messageSuccess;
    }
    if (this.resultType === RESULT_ERROR) {
      return this.customLabel.messageError;
    }
    return STR_EMPTY;
  }

  /** TH1 & TH2: hiển thị block NFU Details read-only. */
  get showNfuDetails() {
    return (
      this.resultType === RESULT_ALREADY_MARKED ||
      this.resultType === RESULT_SUCCESS
    );
  }
}
