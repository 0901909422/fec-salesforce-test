import { LightningElement, api, track, wire } from "lwc";
import Toast from "lightning/toast";
import getByCase from "@salesforce/apex/FEC_CaseBusinessService.getByCase";
import getTransferUsers from "@salesforce/apex/FEC_CaseBusinessService.getTransferUsers";
import getTransferQueues from "@salesforce/apex/FEC_CaseBusinessService.getTransferQueues";
import run from "@salesforce/apex/FEC_CaseBusinessService.run";
import saveCaseNOC from "@salesforce/apex/FEC_CaseBusinessService.saveCaseNOC";
import markCaseSubmittedWithoutRouting from "@salesforce/apex/FEC_CaseBusinessService.markCaseSubmittedWithoutRouting";
import logSensitiveAccess from "@salesforce/apex/FEC_InteractionHighlightController.logSensitiveAccess";
import { getRecord, getFieldValue, updateRecord } from "lightning/uiRecordApi";
import USER_ID from "@salesforce/user/Id";
import USER_GROUP_FIELD from "@salesforce/schema/User.FEC_User_Group__c";
import ID_FIELD from "@salesforce/schema/Case.Id";
import IS_ROUTING_ACTION_DISPLAY_FIELD from "@salesforce/schema/Case.FEC_Is_Routing_Action_Display__c";
import {
  mask,
  maskValue,
  formatToDDMMYYYY,
  validateUpdatedInfoPhone,
  applyPhoneInputMaxLength,
  validateUpdatedInfoEmail,
  validateIdNumber,
  validateNationalId,
  validateUpdatedInfoNationalID,
  checkNoUpdateInSubmit,
  findPicklistOptionByRaw,
  isOnlyNumber
} from "c/fec_CommonUtils";

import { MASKING_TYPE_PHONE, MASKING_TYPE_PASSPORT, STR_EMPTY, ICON_HIDE, ICON_PREVIEW, INTERNAL_REQUEST } from "c/fec_CommonConst";
import FEC_MSG_UPDATED_INFO_NOT_UPDATED from "@salesforce/label/c.FEC_MSG_UPDATED_INFO_NOT_UPDATED";
import FEC_MSG_Can_Not_Find_Next_Stage from "@salesforce/label/c.FEC_MSG_Can_Not_Find_Next_Stage";
import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";
import FEC_Warning_Title from "@salesforce/label/c.FEC_Warning_Title";
import FEC_ACTION_PHONE_UPDATE_HEADER from "@salesforce/label/c.FEC_ACTION_PHONE_UPDATE_HEADER";
import FEC_MSG_ACTION_PHONE_UPDATE from "@salesforce/label/c.FEC_MSG_ACTION_PHONE_UPDATE";
import FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS from "@salesforce/label/c.FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS";
import FEC_MSG_ACTION_PHONE_UPDATE_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_PHONE_UPDATE_ERROR";
import FEC_Reason_Label from "@salesforce/label/c.FEC_Reason_Label";
import FEC_Routing_Action_Label from "@salesforce/label/c.FEC_Routing_Action_Label";
import FEC_Action_Label from "@salesforce/label/c.FEC_Action_Label";
import FEC_Team_Label from "@salesforce/label/c.FEC_Team_Label";
import FEC_Queue_Label from "@salesforce/label/c.FEC_Queue_Label";
import FEC_Decision_Label from "@salesforce/label/c.FEC_Decision_Label";
import FEC_Choose_Decision_Label from "@salesforce/label/c.FEC_Choose_Decision_Label";
import FEC_Sub_Decision_Label from "@salesforce/label/c.FEC_Sub_Decision_Label";
import FEC_Choose_Sub_Decision_Label from "@salesforce/label/c.FEC_Choose_Sub_Decision_Label";
import FEC_Block_Card_Header from '@salesforce/label/c.FEC_Block_Card_Header';
import FEC_Block_Card_Confirmation_Msg from '@salesforce/label/c.FEC_Block_Card_Confirmation_Msg';
import FEC_Block_Card_Success from '@salesforce/label/c.FEC_Block_Card_Success';
import FEC_Block_Card_Failed_Max from '@salesforce/label/c.FEC_Block_Card_Failed_Max';
import FEC_ACTION_UNBLOCK_CARD_HEADER from "@salesforce/label/c.FEC_ACTION_UNBLOCK_CARD_HEADER";
import FEC_MSG_ACTION_UNBLOCK_CARD from "@salesforce/label/c.FEC_MSG_ACTION_UNBLOCK_CARD";
import FEC_MSG_ACTION_UNBLOCK_CARD_SUCCESS from "@salesforce/label/c.FEC_MSG_ACTION_UNBLOCK_CARD_SUCCESS";
import FEC_MSG_ACTION_UNBLOCK_CARD_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_UNBLOCK_CARD_ERROR";
import FEC_ACTION_PIN_REISSUE_HEADER from "@salesforce/label/c.FEC_ACTION_PIN_REISSUE_HEADER";
import FEC_MSG_ACTION_PIN_REISSUE from "@salesforce/label/c.FEC_MSG_ACTION_PIN_REISSUE";
import FEC_MSG_ACTION_PIN_REISSUE_SUCCESS from "@salesforce/label/c.FEC_MSG_ACTION_PIN_REISSUE_SUCCESS";
import FEC_MSG_ACTION_PIN_REISSUE_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_PIN_REISSUE_ERROR";

import { publish, MessageContext } from "lightning/messageService";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";


const ACTION_PHONE_UPDATE = "Phone Update";
const ACTION_EMAIL_UPDATE = "Email Update";
const ACTION_FULLNAME_UPDATE = "Full Name Update";
const ACTION_DOB_UPDATE = "Date of Birth Update";
const ACTION_GENDER_UPDATE = "Gender Update";
const OC_001 = "Outbound Campaign - OU01";

const ACTION_ROUTE_TO = "Route to";
const ACTION_REVERT = "Revert";
const ACTION_REJECT = "Reject";
const ACTION_RESOLVE = "Resolve";
const ACTION_TRANSFER = "Transfer";
const ACTION_UPDATE = "Update";
const ACTION_ESCALATE = "Escalate";
const ACTION_CANCEL = "Cancel";

const OUTBOUND_CAMPAIGN = 'Outbound Campaign';

const ACTION_BLOCK_CARD = "Block Card";
const ACTION_UNBLOCK_CARD = "Unblock Card";
const ACTION_PIN_REISSUE = "Reissue PIN";

/** Các action không tự lưu NOC trong run() - cần gọi saveCaseNOC trước khi run */
const ACTIONS_NEED_NOC_BEFORE_RUN = [
  ACTION_ESCALATE,
  ACTION_REJECT,
  ACTION_RESOLVE,
  ACTION_CANCEL,
];

const CASE_UPDATED_INFO_PHONE_NUMBER = "Case.FEC_Updated_Info_Phone_Number__c";
const FIELD_UPDATED_INFO_PHONE_NUMBER = "FEC_Updated_Info_Phone_Number__c";
const FIELD_ORIGINAL_INFO_PHONE_NUMBER = "FEC_Original_Info_Phone_Number__c";
const CASE_REGISTERED_PHONE_NUMBER = "Case.FEC_Registered_Phone_Number__c";
const FIELD_REGISTERED_PHONE_NUMBER = "FEC_Registered_Phone_Number__c";
const FIELD_CASE_PHONE_NUMBER = "FEC_Case_Phone_Number__c";
const PHONE_MASK_FIELD_APIS = new Set([
  FIELD_ORIGINAL_INFO_PHONE_NUMBER,
  FIELD_UPDATED_INFO_PHONE_NUMBER,
  FIELD_REGISTERED_PHONE_NUMBER,
  FIELD_CASE_PHONE_NUMBER,
]);
const CASE_UPDATED_INFO_FIRST_NAME = "Case.FEC_Updated_Info_First_Name__c";
const CASE_UPDATED_INFO_MIDDLE_NAME = "Case.FEC_Updated_Info_Middle_Name__c";
const CASE_UPDATED_INFO_LAST_NAME = "Case.FEC_Updated_Info_Last_Name__c";
const CASE_UPDATED_INFO_EMAIL = "Case.FEC_Updated_Info_Email__c";
const FIELD_UPDATED_INFO_EMAIL = "FEC_Updated_Info_Email__c";
const FIELD_CASE_EMAIL = "FEC_Case_Email__c";
const CASE_UPDATED_INFO_DOB = "Case.FEC_Updated_Info_Date_of_Birth__c";
const CASE_ORIGINAL_INFO_DOB = "Case.FEC_Original_Info_Date_of_Birth__c";
const FIELD_UPDATED_INFO_DOB = "FEC_Updated_Info_Date_of_Birth__c";
const FIELD_ORIGINAL_INFO_DOB = "FEC_Original_Info_Date_of_Birth__c";
const FIELD_UPDATED_INFO_DATE_OF_ISSUE = "FEC_Updated_Info_Date_of_Issue__c";
const FIELD_ORIGINAL_INFO_DATE_OF_ISSUE = "FEC_Original_Info_Date_of_Issue__c";
const FIELD_ORIGINAL_INFO_PLACE_OF_ISSUE =
  "FEC_Original_Info_Place_of_Issue__c";
const FIELD_UPDATED_INFO_PLACE_OF_ISSUE = "FEC_Updated_Info_Place_of_Issue__c";
const FIELD_NEW_ISSUE_DATE = "FEC_New_Issue_Date__c";
const FIELD_OLD_ISSUE_DATE = "FEC_Old_Issue_Date__c";
const FIELD_NEW_CITIZEN_ID_NUMBER = "FEC_New_Citizen_ID_Number__c";
const FIELD_OLD_CITIZEN_ID_NUMBER = "FEC_Old_Citizen_ID_Number__c";
const FIELD_ORIGINAL_INFO_NATIONAL_ID = "FEC_Original_Info_National_ID__c";
const FIELD_UPDATED_INFO_NATIONAL_ID = "FEC_Updated_Info_National_ID__c";
const FIELD_NATIONAL_ID_PASSPORT_ID = "FEC_National_ID_Passport_ID__c";
const NATIONAL_ID_PASSPORT_FIELDS = new Set([
  FIELD_ORIGINAL_INFO_NATIONAL_ID,
  FIELD_UPDATED_INFO_NATIONAL_ID,
  FIELD_NATIONAL_ID_PASSPORT_ID,
]);
const FIELD_CORRECT_DATE_OF_BIRTH = "FEC_Correct_Date_of_Birth__c";
const FIELD_INCORRECT_DATE_OF_BIRTH = "FEC_Incorrect_Date_of_Birth__c";
const DATE_FIELDS = new Set([
  FIELD_UPDATED_INFO_DOB,
  FIELD_ORIGINAL_INFO_DOB,
  FIELD_UPDATED_INFO_DATE_OF_ISSUE,
  FIELD_ORIGINAL_INFO_DATE_OF_ISSUE,
  FIELD_NEW_ISSUE_DATE,
  FIELD_OLD_ISSUE_DATE,
  FIELD_CORRECT_DATE_OF_BIRTH,
  FIELD_INCORRECT_DATE_OF_BIRTH,
]);
const CASE_UPDATED_INFO_GENDER = "Case.FEC_Updated_Info_Gender__c";
const CASE_UPDATED_INFO_NATIONAL_ID = "Case.FEC_Updated_Info_National_ID__c";
const CASE_UPDATED_INFO_DATE_OF_ISSUE =
  "Case.FEC_Updated_Info_Date_of_Issue__c";
const CASE_UPDATED_INFO_PLACE_OF_ISSUE =
  "Case.FEC_Updated_Info_Place_of_Issue__c";
const CASE_CS_D2C_ASSIGNMENT_TYPE = "Case.FEC_CS_D2C_Assessment_Type__c";
const CASE_CS_D2C_REQUIRED_CORRECTIVE_ACTION =
  "Case.FEC_CS_D2C_Required_Corrective_Action__c";
const CASE_CS_D2C_RISK_LEVEL = "Case.FEC_CS_D2C_Risk_Level__c";
const CASE_CS_SUPPORT_ASSESMENT_TYPE = "Case.FEC_CS_Support_Assessment_Type__c";
const CASE_CONFIRM_D2C_ASSESMENT = "Case.FEC_Confirm_D2C_Assessment__c";
const CASE_ACTIONS_TAKEN_D2C_ASSESMENT =
  "Case.FEC_Actions_Taken_D2C_Assessment__c";
const CASE_CONFIRM_CS_SP_ASSESMENT = "Case.FEC_Confirm_CS_SP_Assessment__c";

const CS_D2C_REQUIRED_CORRECTIVE_ACTION =
  "FEC_CS_D2C_Required_Corrective_Action__c";
const CS_D2C_RISK_LEVEL = "FEC_CS_D2C_Risk_Level__c";
const CS_SUPPORT_ASSESMENT_TYPE = "FEC_CS_Support_Assessment_Type__c";
const CONFIRM_D2C_ASSESMENT = "FEC_Confirm_D2C_Assessment__c";
const ACTIONS_TAKEN_D2C_ASSESMENT = "FEC_Actions_Taken_D2C_Assessment__c";
const CONFIRM_CS_SP_ASSESMENT = "Case.FEC_Confirm_CS_SP_Assessment__c";

const TYPE_QUALIFIED = "Qualified";
const TYPE_UNQUALIFIED = "Unqualified";
const TYPE_AGREE = "Agree";
const TYPE_DISAGREE = "Disagree";

const DECISION_USER = "User";
const DECISION_QUEUE = "Queue";
const NONE_STRING = '--None--';
const FIELD_ACCOUNT_CONTRACT_NUMBER_PL = 'FEC_Account_Contract_Number_PL__c';
const LABEL_ACCOUNT_CONTRACT_NUMBER = 'Account/ Contract Number';

const SLDS_MEDIUM_SIZE_OF_12 = {
  1: 'slds-medium-size_1-of-12',
  2: 'slds-medium-size_2-of-12',
  3: 'slds-medium-size_3-of-12',
  4: 'slds-medium-size_4-of-12',
  5: 'slds-medium-size_5-of-12',
  6: 'slds-medium-size_6-of-12',
  7: 'slds-medium-size_7-of-12',
  8: 'slds-medium-size_8-of-12',
  9: 'slds-medium-size_9-of-12',
  10: 'slds-medium-size_10-of-12',
  11: 'slds-medium-size_11-of-12',
  12: 'slds-medium-size_12-of-12'
};

const MAP_NEW_BLOCK_CODE = {
  'A': 'A',
  'Không sử dụng': 'L',
  'Thẻ bị mất/ đánh cắp có phát sinh giao dịch': 'S',
}
const MAP_NEW_BLOCK_CODE_CARD_REPLACE = {
  'Bị hư hỏng': 'L',
  'Bị mất/ đánh cắp': 'L',
  'Bị nuốt tại ATM': 'L',
  'Chưa nhận được thẻ': 'L',
  'Không còn nguyên vẹn': 'L',
  'Sai tên in nổi': 'L',
  'Thay thế lần đầu thẻ Money Tab': 'L',
  'Liên quan gian lận': 'S',
}
const MAP_CARD_REPLACEMENT_FEE_VALUE = {
  'Bị hư hỏng': '110000',
  'Bị mất/ đánh cắp': '110000',
  'Bị nuốt tại ATM': '',
  'Chưa nhận được thẻ': '',
  'Không còn nguyên vẹn': '',
  'Sai tên in nổi': '',
  'Thay thế lần đầu thẻ Money Tab': '',
  'Liên quan gian lận': '110000',
}
const MAP_CARD_REPLACEMENT_FEE_DISPLAY = {
  'Bị hư hỏng': '110,000 VND (include 10% VAT)',
  'Bị mất/ đánh cắp': '110,000 VND (include 10% VAT)',
  'Bị nuốt tại ATM': '',
  'Chưa nhận được thẻ': '',
  'Không còn nguyên vẹn': '',
  'Sai tên in nổi': '',
  'Thay thế lần đầu thẻ Money Tab': '',
  'Liên quan gian lận': '110,000 VND (include 10% VAT)',
}
const FIELD_CARD_BLOCK_REASON = 'FEC_Card_Block_Reason__c';
const FIELD_NEW_BLOCK_CODE = 'FEC_New_Block_Code__c';
const FIELD_CARD_REPLACEMENT_REASON = 'FEC_Card_Replacement_Reason__c';
const FIELD_NEW_BLOCK_CODE_CARD_REPLACE = 'FEC_New_Block_Code_Card_Replace__c';
const FIELD_CARD_REPLACEMENT_FEE = 'FEC_Card_Replacement_Fee__c';

/**
 * Registry of dynamically loadable components.
 * ADD a new entry here for every LWC name stored in FEC_LWC_Name__c metadata.
 * Each value must be a static `() => import('c/<name>')` arrow function —
 * LWC strict mode (LWC1121) forbids template-literal or variable import() arguments.
 *
 * Example:
 *   fec_IncorrectPaymentForm: () => import('c/fec_IncorrectPaymentForm'),
 */
const DYNAMIC_COMPONENT_REGISTRY = {
  fec_UpdateAddress: () => import('c/fec_UpdateAddress'),
  fec_CardInfo: () => import('c/fec_CardInfo'),
  fec_IPPClosureForm: () => import('c/fec_IPPClosureForm'),
  fec_CardClosureRefundForm: () => import('c/fec_CardClosureRefundForm'),
  fec_PinResetHandling: () => import('c/fec_PinResetHandling'),
  fec_CardBlock: () => import('c/fec_CardBlock'),
  fec_IncorrectPaymentForm: () => import('c/fec_IncorrectPaymentForm'),
  fec_IPPConversionRetailForm: () => import('c/fec_IPPConversionRetailForm'),
  fec_RemovePhoneForm: () => import('c/fec_RemovePhoneForm'),
  fec_RefundRequestForm: () => import('c/fec_RefundRequestForm'),
  fec_ContractClosureForm: () => import('c/fec_ContractClosureForm'),
  fec_BeneficiaryBankInfoBlock: () => import('c/fec_BeneficiaryBankInfoBlock'),
  fec_FastCashCaseForm: () => import('c/fec_FastCashCaseForm')
};

/**
 * Đọc FEC_Sub_Section_Order__c từ payload (Apex: Section.order, DynamicLwcComponent.order; slot LWC: sortOrder / fecSubSectionOrder).
 * Không dùng hasOwnProperty — object từ Apex/imperative có thể không báo `order` là own prop → tránh mất thứ tự và LWC rơi fallback maxField+1 (luôn nằm dưới field).
 */
function readFecSubSectionOrder(payload) {
  if (payload == null || typeof payload !== "object") {
    return undefined;
  }
  const keys = [
    "order",
    "sortOrder",
    "fecSubSectionOrder",
    "FEC_Sub_Section_Order__c",
  ];
  for (let i = 0; i < keys.length; i++) {
    const raw = payload[keys[i]];
    if (raw === undefined || raw === null || raw === "") {
      continue;
    }
    const n = Number(raw);
    if (!Number.isNaN(n) && Number.isFinite(n) && n >= 0) {
      return n;
    }
  }
  return undefined;
}

/**
 * Gộp subsection (field) + LWC đã resolve — sort theo FEC_Sub_Section_Order__c (thứ tự DOM).
 */
function mergeSectionSortedRows(section) {
  const rows = [];
  let seq = 0;

  (section.subSectionlst || []).forEach((sub, subIndex) => {
    const fecOrd = readFecSubSectionOrder(sub);
    const sortOrder =
      fecOrd !== undefined ? fecOrd : subIndex + 1;
    rows.push({
      rowKey: `fec-${section.id}-fld-${seq++}`,
      isFields: true,
      isLwc: false,
      sortOrder,
      outerClass: sub.className,
      sub,
    });
  });

  let maxFieldOrder = 0;
  rows.forEach((r) => {
    if (r.isFields) {
      maxFieldOrder = Math.max(maxFieldOrder, r.sortOrder);
    }
  });

  (section.resolvedComponentlst || []).forEach((dynCmp, idx) => {
    const fecOrd = readFecSubSectionOrder(dynCmp);
    const sortOrder =
      fecOrd !== undefined ? fecOrd : maxFieldOrder + 1 + idx;
    rows.push({
      rowKey: dynCmp.key || `fec-${section.id}-lwc-${idx}`,
      isFields: false,
      isLwc: true,
      sortOrder,
      outerClass: dynCmp.lwcColClassName,
      dynCmp,
    });
  });

  rows.sort((a, b) => {
    if (a.sortOrder !== b.sortOrder) {
      return a.sortOrder - b.sortOrder;
    }
    if (a.isFields !== b.isFields) {
      return a.isFields ? -1 : 1;
    }
    return String(a.rowKey).localeCompare(String(b.rowKey));
  });

  return rows;
}

/** Chuẩn hoá phần tử componentlst từ Apex (object DynamicLwcComponent hoặc legacy string). */
function normalizeMasterDataLwcEntry(entry) {
  if (typeof entry === "string") {
    return {
      componentName: entry,
      order: undefined,
      fieldLayout: 12,
      subSectionName: null,
      fecMasterDataSettingIsEdit: true,
    };
  }
  const o = entry || {};
  const ord = readFecSubSectionOrder(o);
  return {
    componentName: o.componentName,
    order: ord,
    fieldLayout:
      o.fieldLayout !== undefined && o.fieldLayout !== null
        ? Number(o.fieldLayout)
        : 12,
    subSectionName: o.subSectionName ?? null,
    fecMasterDataSettingIsEdit:
      Object.prototype.hasOwnProperty.call(o, "fecMasterDataSettingIsEdit") &&
      typeof o.fecMasterDataSettingIsEdit === "boolean"
        ? o.fecMasterDataSettingIsEdit
        : true,
  };
}

export default class Fec_CaseBussiness extends LightningElement {

  @api recordId;

  _isEdit = true;
  @api get isEdit() {
    return this._isEdit;
  }
  set isEdit(value) {
    const prev = this._isEdit;
    this._isEdit = value === true || value === "true";
    if (prev !== this._isEdit && this.business?.sectionlst) {
      this._applyEditModeToBusiness();
    }
  }

  @track business = {};

  isLoaded = true;

  businessLoaded = false;

  @track activeSectionlst = ["routing-action"];

  routingAccordionSectionKey = "routing-action";

  _ippClosureHasEligibleRows = false;

  // get eyeIcon() {
  //   return this.isMasked ? "utility:preview" : "utility:hide";
  // }
  updateDecision;
  @track decisionValue = STR_EMPTY;
  @track subDecisionValue = STR_EMPTY;
  @track subDecisionOptions = [];

  userGroup;

  @wire(getRecord, { recordId: USER_ID, fields: [USER_GROUP_FIELD] })
  wiredUser({ error, data }) {
    if (data) {
      this.userGroup = getFieldValue(data, USER_GROUP_FIELD);
    } else if (error) {
      console.error("Error fetching user group", error);
    }
  }
  
  @wire(MessageContext)
  messageContext;

  get iconHideConst() {
    return ICON_HIDE;
  }

  // Danh sách cố định cho Decision
  get decisionOptions() {
    return [
      { label: "User", value: DECISION_USER },
      { label: "Queue", value: DECISION_QUEUE },
    ];
  }

  get decisionUpdateOptions() {
    // 1. Define the base segments of your list
    const pendingList = [
      { label: "Pending CS", value: "Pending CS" },
      { label: "Pending Customer", value: "Pending Customer" },
      { label: "Pending Card Ops", value: "Pending Card Ops" },
      { label: "Pending Collections", value: "Pending Collections" },
      {
        label: "Pending Contract Processing",
        value: "Pending Contract Processing",
      },
      {
        label: "Pending Credit Assessment",
        value: "Pending Credit Assessment",
      },
      { label: "Pending Direct Sales", value: "Pending Direct Sales" },
      { label: "Pending Telesales", value: "Pending Telesales" },
      { label: "Pending IT", value: "Pending IT" },
      { label: "Pending Payment", value: "Pending Payment" },
      { label: "Pending Product", value: "Pending Product" },
      { label: "Pending RCP&A", value: "Pending RCP&A" },
      { label: "Pending Security", value: "Pending Security" },
    ];

    const vendorOption = { label: "Pending Vendor", value: "Pending Vendor" };

    const bottomList = [
      { label: "Out Of Process", value: "Out Of Process" },
      { label: "CIC Related", value: "CIC Related" },
      { label: "Document Preparation", value: "Document Preparation" },
      { label: "Task Under Review", value: "Task Under Review" },
    ];

    // 2. Return specific combinations based on User Group
    if (this.userGroup === "SP") {
      // CC: Pending list + Vendor (No "Out of Process" etc.)
      return [...pendingList, vendorOption];
    } else if (this.userGroup === "CC") {
      // SP: Pending list + Bottom list (EXCLUDES Vendor)
      return [...pendingList, ...bottomList];
    }

    // Default: Return everything
    return [...pendingList, vendorOption, ...bottomList];
  }

  draftKey = 'case-draft';
  handleChange(event) {
    const fieldName = event.target.name;
    const value = event.detail.value;

    if (fieldName === "decision") {
      this.decisionValue = value;
      this.subDecisionValue = STR_EMPTY; // Reset sub-decision khi đổi decision chính
      this.subDecisionOptions = [];

      if (value === DECISION_USER) {
        this.fetchTransferUsers();
      } else if (value === DECISION_QUEUE) {
        this.fetchTransferQueues();
      }
    } else if (fieldName === "sub-decision") {
      if (value != NONE_STRING) {
        this.subDecisionValue = value;
      } else {
        this.subDecisionValue = STR_EMPTY;
      }
    }
  }

  fetchTransferUsers() {
    this.isLoaded = false;
    getTransferUsers({ caseId: this.recordId })
      .then((result) => {
        const userOptions = result.map((user) => ({
          label: user.Name,
          value: user.Id,
        }));

        if (userOptions.length > 0) {
          this.subDecisionOptions = [...userOptions];
        } else {
          this.subDecisionOptions = [{ label: NONE_STRING, value: NONE_STRING }];
        }
        console.log("User options:", this.subDecisionOptions);
      })
      .catch((error) => {
        console.error("Error fetching users:", error);
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  updateRoutingActionDisplay(field) {
    let fields = {};
    fields[ID_FIELD.fieldApiName] = this.recordId;
    fields[IS_ROUTING_ACTION_DISPLAY_FIELD.fieldApiName] = field;
    let recordInput = { fields };

    updateRecord(recordInput)
      .then(() => {
        console.log("Record updated successfully");
      })
      .catch((error) => {
        console.error("Error updating record:", error);
      });
  }

  /** Khi load màn: Action (Routing) khớp với CS Support đánh giá yêu cầu nếu đã có giá trị. */
  /** Author: Toannd61 */
  _applyCsSupportAssessmentRoutingActionSync() {
    if (
      !this.isEdit ||
      !(this.business?.routingActionlst && this.business.routingActionlst.length > 0)
    ) {
      return;
    }
    if (OUTBOUND_CAMPAIGN == this.business.code) {
      return;
    }
    if (this.business.sectionlst?.some((s) => s.hasError)) {
      return;
    }

    const actions = this.business.routingActionlst || [];
    let assessmentVal;

    this.business.sectionlst?.forEach((section) => {
      section.subSectionlst?.forEach((sub) => {
        sub.objlst?.forEach((obj) => {
          if (obj.name !== "Case") {
            return;
          }
          const f = obj.fieldlst?.find(
            (fld) => fld.apiName === CS_SUPPORT_ASSESMENT_TYPE,
          );
          if (
            f &&
            f.value != null &&
            f.value !== STR_EMPTY &&
            assessmentVal === undefined
          ) {
            assessmentVal = f.value;
          }
        });
      });
    });

    if (!assessmentVal || assessmentVal === STR_EMPTY) {
      return;
    }

    this.showProcessAction = TYPE_QUALIFIED === assessmentVal;

    if (
      TYPE_QUALIFIED === assessmentVal &&
      actions.some((a) => a.value === ACTION_RESOLVE)
    ) {
      this.actionValue = ACTION_RESOLVE;
      return;
    }
    if (
      TYPE_UNQUALIFIED === assessmentVal &&
      actions.some((a) => a.value === ACTION_REJECT)
    ) {
      this.actionValue = ACTION_REJECT;
    }
  }

  // Nghiệp vụ: Lấy Queue theo Team Queue và Group Member
  fetchTransferQueues() {
    this.isLoaded = false;
    getTransferQueues()
      .then((result) => {
        const queueOptions = result.map((q) => ({
          label: q.Name,
          value: q.Id,
        }));

        if (queueOptions.length > 0) {
          this.subDecisionOptions = [...queueOptions];
        } else {
          this.subDecisionOptions = [{ label: NONE_STRING, value: NONE_STRING }];
        }
      })
      .catch((error) => console.error("Error fetching queues:", error))
      .finally(() => {
        this.isLoaded = true;
      });
  }

  get isSubDecisionOptionsDisplay() {
    return this.subDecisionOptions.length > 0;
  }

  @track actionValue;

  isModalOpen = false;
  header;
  content;

  get isRoutingActionDisabled() {
    return !this._isEdit;
  }

  get showRouteTo() {
    return ACTION_ROUTE_TO === this.actionValue;
  }

  get showRevert() {
    return ACTION_REVERT === this.actionValue;
  }

  get showTransfer() {
    return ACTION_TRANSFER === this.actionValue;
  }

  get showUpdate() {
    return ACTION_UPDATE === this.actionValue;
  }

  processActionMethod;

  processActionMsg;
  isProcessActionSuccessed = false;
  isProcessActionFailed = false;

  showProcessAction = false;
  isProcessActionValid = true;

  get finalShowProcessAction() {
    return this.showProcessAction && this.isProcessActionValid && this.isEdit;
  }
  customLabel = {
    reasonLabel: FEC_Reason_Label,
    routingActionLabel: FEC_Routing_Action_Label,
    actionLabel: FEC_Action_Label,
    teamLabel: FEC_Team_Label,
    queueLabel: FEC_Queue_Label,
    decisionLabel: FEC_Decision_Label,
    chooseDecisionLabel: FEC_Choose_Decision_Label,
    subDecisionLabel: FEC_Sub_Decision_Label,
    chooseSubDecisionLabel: FEC_Choose_Sub_Decision_Label
  }

  @api getNatureOfCaseId() {
    return this.business?.natureOfCase || null;
  }

  @api getStageName() {
    return this.business?.stageName ?? STR_EMPTY;
  }

  @api setNatureOfCaseId(id) {
    if (id && this.business) this.business = { ...this.business, natureOfCase: id };
  }

  _getCaseFieldValue(apiName) {
    const sections = this.business?.sectionlst ?? [];
    for (const section of sections) {
      for (const sub of section.subSectionlst ?? []) {
        for (const obj of sub.objlst ?? []) {
          if (obj.name !== "Case") continue;
          const f = obj.fieldlst?.find((x) => x.apiName === apiName);
          if (f != null) {
            const v = f.value;
            return typeof v === "string" ? v.trim() : (v ?? STR_EMPTY);
          }
        }
      }
    }
    return STR_EMPTY;
  }

  /** Case field apiName đang có trên form (form đổi theo NOC). */
  _getPresentCaseFieldApiNames() {
    const names = new Set();
    const sections = this.business?.sectionlst ?? [];
    for (const section of sections) {
      for (const sub of section.subSectionlst ?? []) {
        for (const obj of sub.objlst ?? []) {
          if (obj.name !== "Case") continue;
          for (const field of obj.fieldlst ?? []) {
            if (field?.apiName) names.add(field.apiName);
          }
        }
      }
    }
    return names;
  }

  /** Options cho checkNoUpdateInSubmit (picklist Case: label vs API value). */
  _getCheckNoUpdateInSubmitOptions() {
    return {
      presentUpdatedApiNames: this._getPresentCaseFieldApiNames(),
      picklistCaseFieldOptions: this.business?.picklistOptionsMap?.Case,
    };
  }

  /** Giá trị gốc (unmasked) để so sánh với updated. */
  _getCaseFieldOriginalValue(apiName) {
    const sections = this.business?.sectionlst ?? [];
    for (const section of sections) {
      for (const sub of section.subSectionlst ?? []) {
        for (const obj of sub.objlst ?? []) {
          if (obj.name !== "Case") continue;
          const f = obj.fieldlst?.find((x) => x.apiName === apiName);
          if (f != null) {
            const v = f.original != null ? f.original : f.value;
            return typeof v === "string" ? v.trim() : (v ?? STR_EMPTY);
          }
        }
      }
    }
    return STR_EMPTY;
  }

  @api getUpdatedInfoPhoneNumber() {
    const v = this._getCaseFieldValue(FIELD_UPDATED_INFO_PHONE_NUMBER);
    return v || null;
  }

  showToast(title, msg, type) {
    Toast.show(
      {
        label: title,
        message: msg,
        mode: "dismissible",
        variant: type,
      },
      this,
    );
  }

  /** Lấy mã Action đã chọn ở Routing Action (dùng cho lưu draft). */
  @api getRoutingActionCode() {
    return this.actionValue ?? null;
  }

  /** Trả về business object để validate (original/updated pairs) ở parent. */
  @api getBusiness() {
    return this.business ?? null;
  }

  /** true = bị chặn (đã show toast), false = được submit. Chỉ xét cặp Original/Updated đang hiển thị. */
  @api async checkSubmitBlock() {
    const noUpdate = checkNoUpdateInSubmit(
      this._getCaseFieldOriginalValue.bind(this),
      this._getCaseFieldValue.bind(this),
      this._getCheckNoUpdateInSubmitOptions(),
    );
    if (noUpdate) {
      this.showToast(FEC_Warning_Title, FEC_MSG_UPDATED_INFO_NOT_UPDATED, "warning");
      return true;
    }
    return false;
  }

  /**
   * Cập nhật readonly/editable cho toàn bộ field khi isEdit đổi.
   * Không gọi Apex, chỉ sửa dữ liệu đã có trong memory.
   */
  _applyEditModeToBusiness() {
    if (!this.business?.sectionlst) return;
    this.business.sectionlst.forEach((section) => {
      section.subSectionlst?.forEach((sub) => {
        sub.objlst?.forEach((obj) => {
          obj.fieldlst?.forEach((field) => {
            field.readonly = !this._isEdit;
            field.editable = this._isEdit;
          });
        });
      });
    });
    this.business.hasRoutingAction =
      Array.isArray(this.business.routingActionlst) &&
      this.business.routingActionlst.length > 0;
    this._updateDynCmpIsEditFlags();
    this.business = { ...this.business };
  }

  _updateDynCmpIsEditFlags() {
    if (!this.business?.sectionlst) return;
    this.business.sectionlst.forEach((section) => {
      section.resolvedComponentlst?.forEach((d) => {
        if (!d) return;
        const master =
          typeof d.fecMasterDataSettingIsEdit === "boolean" ? d.fecMasterDataSettingIsEdit : true;
        d.isEdit = this._isEdit && master;
      });
    });
  }

  connectedCallback() {
    console.log("🚀 ~ Fec_CaseBussiness ~ connectedCallback ~ this.business:", JSON.stringify(this.business))
    this._boundHandleIppClosureLoad = this.handleIppClosureLoad.bind(this);
    this._boundHandleIppClosureSelection = this.handleIppClosureSelection.bind(this);
    this.template.addEventListener(
      "fecippclosureload",
      this._boundHandleIppClosureLoad,
    );
    this.template.addEventListener(
      "fecippclosureselection",
      this._boundHandleIppClosureSelection,
    );
    this.getData();
    if (this.isEdit) {
      this.updateRoutingActionDisplay(STR_EMPTY);
    }
  }

  disconnectedCallback() {
    console.log("🚀 ~ Fec_CaseBussiness ~ disconnectedCallback ~ this._boundHandleIppClosureLoad:", this._boundHandleIppClosureLoad)
    if (this._boundHandleIppClosureLoad) {
      this.template.removeEventListener(
        "fecippclosureload",
        this._boundHandleIppClosureLoad,
      );
    }
    if (this._boundHandleIppClosureSelection) {
      this.template.removeEventListener(
        "fecippclosureselection",
        this._boundHandleIppClosureSelection,
      );
    }
    localStorage.removeItem(this.draftKey);
  }

  _maskDisplayPhone(raw) {
    if (raw == null || raw === STR_EMPTY) return STR_EMPTY;
    return maskValue(String(raw).replace(/\D/g, STR_EMPTY), false);
  }

  handleToggleMask(e) {
    let filter = {
      section: e.target.dataset.section,
      subSection: e.target.dataset.sub,
      obj: e.target.dataset.obj,
      field: e.target.dataset.field,
    };

    let { field } = this.find(filter);

    let isPreview = e.target.iconName === ICON_PREVIEW;
    e.target.iconName = isPreview ? ICON_HIDE : ICON_PREVIEW;

    if (isPreview) {
      if (
        field.maskingType === MASKING_TYPE_PHONE ||
        PHONE_MASK_FIELD_APIS.has(field.apiName)
      ) {
        field.value = this._maskDisplayPhone(field.original);
      } else if (NATIONAL_ID_PASSPORT_FIELDS.has(field.apiName)) {
        field.value = isOnlyNumber(field.original)
          ? mask(field.original, 3, 3)
          : mask(field.original, 2, 3);
      } else {
        field.value = mask(field.original, 4);
      }
    } else {
      field.value = field.original;

      logSensitiveAccess({
        fieldName: field.apiName,
        caseId: this.recordId,
      });
    }
    field.readonlyDisplayValue = field.masked
      ? field.value
      : field.displayValue;
    this.business = { ...this.business };
  }

  @api getData(
    productTypeId = null,
    categoryId = null,
    subCategoryId = null,
    subCodeId = null,
    natureOfCaseIdFallback = null,
  ) {
    this.businessLoaded = false;
    this._ippClosureHasEligibleRows = false;

    getByCase({
      caseId: this.recordId,
      productTypeId,
      categoryId,
      subCategoryId,
      subCodeId,
    })
      .then((res) => {
        if (!res) return;

        let sectionlst = [];
        const natureOfCase = res.natureOfCase || natureOfCaseIdFallback;
        this.business = { ...res, natureOfCase };

        this.activeSectionlst = ["routing-action"];

        // Hiện section Routing khi Apex trả ít nhất một option; chế độ xem vẫn thấy Action, chỉ khóa dropdown (isRoutingActionDisabled).
        this.business.hasRoutingAction =
          Array.isArray(this.business.routingActionlst) &&
          this.business.routingActionlst.length > 0;

        // Ưu tiên draft đã lưu, nếu không có hoặc không hợp lệ thì dùng option đầu tiên
        const draftCode = this.business.draftRoutingActionCode;
        const hasDraftInOptions =
          draftCode &&
          this.business.routingActionlst?.some((a) => a.value === draftCode);
        this.actionValue = hasDraftInOptions
          ? draftCode
          : this.business.routingActionlst[0]?.value;

        if (OUTBOUND_CAMPAIGN == this.business.code) {
          this.actionValue = ACTION_RESOLVE;
        }

        if (!this.business.nextQueue) {
          this.business.nextQueue = { label: STR_EMPTY, value: null };
        }

        this.business.sectionlst.forEach((section, index) => {
          // handle error
          if (section.error?.errorlst?.length > 0) {
            section.hasError = true;

            section.error.errorPanellst = [];

            section.error?.errorlst?.forEach((error, index1) => {
              section.error.errorPanellst.push({
                id: index1,
                value: error,
              });
            });

            this.actionValue = ACTION_REJECT;
          }
          section.id = crypto.randomUUID();

          sectionlst.push(section.id);
          
          section.isLastSection = index === this.business.sectionlst.length - 1;

          section.subSectionlst?.forEach((sub, subIndex) => {
            sub.className = 'slds-col slds-size_1-of-1 ' + (SLDS_MEDIUM_SIZE_OF_12[sub.layout] || SLDS_MEDIUM_SIZE_OF_12[12]) + ' slds-m-top_medium';
            sub.objlst.forEach((obj) => {
              let assignmentType;

              obj.fieldlst?.forEach((field) => {
                if (field.value == null || field.value === undefined) {
                  field.value = STR_EMPTY;
                }
               if (field.apiName === FIELD_ACCOUNT_CONTRACT_NUMBER_PL) {
                  field.isInternalRequest = field.value === INTERNAL_REQUEST;
                }

                field.className = 'slds-col slds-size_1-of-1 ' + (SLDS_MEDIUM_SIZE_OF_12[field.layout] || SLDS_MEDIUM_SIZE_OF_12[12]);
                if(field.hidden) {
                  field.className += ' slds-hide';
                }

                let currentField = `${obj.name}.${field.apiName}`;

                if (
                  currentField == CASE_CS_D2C_ASSIGNMENT_TYPE ||
                  currentField == CASE_CONFIRM_D2C_ASSESMENT
                ) {
                  assignmentType = field.value;
                }

                if (!field.readonly) {
                  if (
                    currentField === CASE_CS_D2C_REQUIRED_CORRECTIVE_ACTION ||
                    currentField === CASE_CS_D2C_RISK_LEVEL
                  ) {
                    field.isHidden =
                      !assignmentType || assignmentType === TYPE_QUALIFIED;
                  } else if (
                    currentField === CASE_ACTIONS_TAKEN_D2C_ASSESMENT
                  ) {
                    field.isHidden =
                      !assignmentType || assignmentType === TYPE_DISAGREE;
                } else {
                  field.isHidden = false;
                }
              }

              if (!this.isEdit) {
                field.readonly = true;
                field.editable = false;
              }

                field.original = field.value;

                field.isDate =
                  field.type === "DATE" || DATE_FIELDS.has(field.apiName);
                field.isPhone =
                  field.apiName === FIELD_UPDATED_INFO_PHONE_NUMBER ||
                  field.apiName === FIELD_REGISTERED_PHONE_NUMBER ||
                  field.apiName === FIELD_CASE_PHONE_NUMBER;
                if (field.isDate) {
                  field.displayValue = formatToDDMMYYYY(field.value);
                } else {
                  field.displayValue = field.value;
                }

                // Convert label to value for picklist fields
                const picklistOptions = this.business.picklistOptionsMap?.[obj.name]?.[field.apiName];
                if (picklistOptions?.length && field.value) {
                  const opt = findPicklistOptionByRaw(picklistOptions, field.value);
                  if (opt) {
                    field.value = opt.value;
                  }
                }

                field.hasHelpText =
                  field.helpText != null &&
                  field.helpText !== undefined &&
                  field.helpText !== STR_EMPTY;

                field.masked = field.masked && field.value && !field.editable;

                if (field.masked) {
                  if (
                    field.maskingType === MASKING_TYPE_PHONE ||
                    PHONE_MASK_FIELD_APIS.has(field.apiName)
                  ) {
                    field.value = this._maskDisplayPhone(field.original);
                  } else {
                  switch (field.maskingType) {
                    case MASKING_TYPE_PASSPORT:
                        if (isOnlyNumber(field.original)) {
                        field.value = mask(field.original, 3, 3);
                      } else {
                        field.value = mask(field.original, 2, 3);
                      }
                      break;
                    default:
                      if (NATIONAL_ID_PASSPORT_FIELDS.has(field.apiName)) {
                        if (isOnlyNumber(field.original)) {
                          field.value = mask(field.original, 3, 3);
                        } else {
                          field.value = mask(field.original, 2, 3);
                        }
                      } else {
                        field.value = mask(field.original, 4, 4);
                      }
                      break;
                  }
                  }
                }

                field.readonlyDisplayValue = field.masked
                  ? field.value
                  : field.displayValue;

                field.editWrapperClass =
                  "edit slds-p-around--x-small";
              });
            });
          });
        });

        // check show button process action PIN Reissue
        const processActions = this.business.processActionlst || [];
        processActions.forEach(processAction => {
          if (processAction.value === ACTION_BLOCK_CARD || processAction.value === ACTION_PIN_REISSUE) {
            this.showProcessAction = true;
          }
        });

        const actions = this.business.routingActionlst || [];
        const foundActions = [];

        if (actions.some((a) => a.value === "Reopen"))
          foundActions.push("Reopen");
        if (actions.some((a) => a.value === "Recall"))
          foundActions.push("Recall");

        // 2. Nếu có action (Reopen/Recall), gọi update trường hiển thị (chỉ khi user có quyền sửa Case)
        if (foundActions.length > 0 && this.isEdit) {
          this.updateRoutingActionDisplay(foundActions.join(";"));
        }
        this._applyCsSupportAssessmentRoutingActionSync();
        this._applyInternalFieldVisibility();
        this._applyRemovePhonePlacement();
        this._rebuildAllSectionSortedRows();
        this.businessLoaded = true;
        this.activeSectionlst = [ ...this.activeSectionlst , ...sectionlst];

        console.log("🚀 ~ Fec_CaseBussiness ~ getData ~ this.business:", JSON.stringify(this.business))
        this.applyDraft();
        this._applyCsSupportAssessmentRoutingActionSync();
        // Resolve LWC name strings from componentlst into constructors for lwc:is
        this._resolveComponentlst();
        console.log("🚀 ~ Fec_CaseBussiness ~ getData ~ this.business after:", JSON.stringify(this.business))

      })
      .catch((err) => {
        console.error(
          "🚀 ~ Fec_CaseBussiness ~ connectedCallback ~ err:",
          JSON.stringify(err),
        );
      })
      .finally(() => {
        this.businessLoaded = true;
      });
  }

  _applyInternalFieldVisibility() {
    if (!this.business?.sectionlst) return;

    const accountValue = this._getCaseFieldValue(FIELD_ACCOUNT_CONTRACT_NUMBER_PL);
    const isInternal = accountValue?.trim() === INTERNAL_REQUEST;

    this.business.sectionlst = this.business.sectionlst.map(section => ({
      ...section,
      subSectionlst: section.subSectionlst?.map(sub => ({
        ...sub,
        objlst: sub.objlst?.map(obj => ({
          ...obj,
          fieldlst: obj.fieldlst?.map(field => ({
            ...field,
            isHidden: isInternal
              ? field.apiName !== FIELD_ACCOUNT_CONTRACT_NUMBER_PL
              : false,
          })) || [],
        })) || [],
      })) || [],
    }));

    this.business = { ...this.business };
  }

  /** Form Remove Phone: trong section Case Information, ngay dưới subsection Property Info (không tạo accordion riêng). */
  _applyRemovePhonePlacement() {
    const sections = this.business?.sectionlst;
    if (!sections?.length) {
      return;
    }
    const show = Boolean(this.business.showRemovePhone);
    sections.forEach((section) => {
      section.subSectionlst?.forEach((sub) => {
        sub.showRemovePhoneAfter =
          show &&
          section.name === SECTION_CASE_INFORMATION &&
          sub.name === SUBSECTION_PROPERTY_INFO;
      });
    });
    this.business = { ...this.business };
  }

  handleInputKeydown(e) {
    const phoneFields = [
      FIELD_UPDATED_INFO_PHONE_NUMBER,
      FIELD_REGISTERED_PHONE_NUMBER,
      FIELD_CASE_PHONE_NUMBER,
    ];
    const nationalIdOnlyFields = [
      FIELD_NEW_CITIZEN_ID_NUMBER,
      FIELD_OLD_CITIZEN_ID_NUMBER,
    ];
    const nationalIdOrPassportFields = [FIELD_UPDATED_INFO_NATIONAL_ID];

    const fieldName = e.target.fieldName || e.target.dataset?.field;
    if (!fieldName) return;

    if (e.ctrlKey || e.metaKey) return;

    const key = e.key;
    const isDigit = key.length === 1 && /^\d$/.test(key);
    const isLetter = key.length === 1 && /^[A-Za-z]$/.test(key);
    const isLetterUppercase = key.length === 1 && /^[A-Z]$/.test(key);
    const isControl =
      key === "Backspace" ||
      key === "Delete" ||
      key === "Tab" ||
      key === "Enter" ||
      key === "Escape" ||
      key === "ArrowLeft" ||
      key === "ArrowRight" ||
      key === "ArrowUp" ||
      key === "ArrowDown" ||
      key === "Home" ||
      key === "End";

    if (phoneFields.includes(fieldName)) {
      if (!isDigit && !isControl) e.preventDefault();
      // Chặn gõ thêm số khi đã đủ độ dài: 0xxx → 10 ký tự, 84xxx → 11 ký tự
      if (isDigit) {
        const val = (e.target.value || STR_EMPTY).replace(/\D/g, STR_EMPTY);
        const maxLen = val.startsWith("84") ? 11 : 10;
        if (val.length >= maxLen) e.preventDefault();
      }
    } else if (nationalIdOnlyFields.includes(fieldName)) {
      if (!isDigit && !isControl) e.preventDefault();
    } else if (nationalIdOrPassportFields.includes(fieldName)) {
      const val = e.target.value || STR_EMPTY;
      const startsWithUppercase = /^[A-Z]/.test(val);
      if (isLetter && !isLetterUppercase) {
        e.preventDefault();
      } else if (isLetterUppercase && val.length > 0) {
        e.preventDefault();
      } else if (!isDigit && !isLetter && !isControl) {
        e.preventDefault();
      } else if (isDigit || isLetterUppercase) {
        const maxLen = startsWithUppercase ? 8 : 12;
        if (val.length >= maxLen) e.preventDefault();
      }
    }
  }

  /** Cho phép paste; sau khi paste chạy validation theo từng field (phone, email, full name, DOB, gender, ...). */
  handlePaste(e) {
    const el = e.currentTarget || e.target;
    setTimeout(() => {
      if (el && el.value !== undefined) {
        this.handleChangeInput({
          currentTarget: el,
          target: el,
          detail: { value: el.value },
        });
      }
    }, 0);
  }

  handleDateChange(e) {
    const el = e.currentTarget || e.target;
    const value = e.detail?.value ?? el.value;
    const fieldName = el.fieldName || el.dataset?.field;
    const objId = el.dataset.obj;
    this.setDraft(objId, fieldName, value);
  }

  handlePhoneChange(e) {
    const el = e.currentTarget || e.target;
    const value = e.detail?.value ?? el.value;
    const fieldName = el.fieldName || el.dataset?.field;
    const objId = el.dataset.obj;
    this.setDraft(objId, fieldName, value);
  }

  handleChangeInput(e) {
    // lightning-input-field: change có thể bubble từ shadow — dùng currentTarget để có đủ data-* và fieldName;
    // giá trị picklist lấy từ detail.value (API value), không phụ thuộc target nội bộ.
    const el = e.currentTarget || e.target;
    let sectionName = el.dataset.section;
    let sub = el.dataset.sub;
    let fieldName = el.fieldName || el.dataset?.field;
    let objName = el.dataset.objName;
    let objId = el.dataset.obj;

    let value = e.detail?.value ?? el.value;
    if (
      objName === "Case" &&
      fieldName === CS_SUPPORT_ASSESMENT_TYPE &&
      this.business?.picklistOptionsMap?.Case?.[CS_SUPPORT_ASSESMENT_TYPE]?.length
    ) {
      const opt = findPicklistOptionByRaw(
        this.business.picklistOptionsMap.Case[CS_SUPPORT_ASSESMENT_TYPE],
        value,
      );
      if (opt) {
        value = opt.value;
      }
    }

    this.setDraft(objId, fieldName, value);

    if (
      fieldName === FIELD_UPDATED_INFO_PHONE_NUMBER ||
      fieldName === FIELD_REGISTERED_PHONE_NUMBER ||
      fieldName === FIELD_CASE_PHONE_NUMBER
    ) {
      value = applyPhoneInputMaxLength(value);
    }
    if (fieldName === FIELD_UPDATED_INFO_NATIONAL_ID) {
      value = validateUpdatedInfoNationalID(value);
    }

    let adHocFieldlst = [
      CASE_CS_D2C_ASSIGNMENT_TYPE,
      CASE_UPDATED_INFO_PHONE_NUMBER,
      CASE_UPDATED_INFO_FIRST_NAME,
      CASE_UPDATED_INFO_MIDDLE_NAME,
      CASE_UPDATED_INFO_LAST_NAME,
      CASE_UPDATED_INFO_EMAIL,
      CASE_UPDATED_INFO_DOB,
      CASE_UPDATED_INFO_GENDER,
      CASE_UPDATED_INFO_NATIONAL_ID,
      CASE_UPDATED_INFO_DATE_OF_ISSUE,
      CASE_UPDATED_INFO_PLACE_OF_ISSUE,
      CASE_CS_SUPPORT_ASSESMENT_TYPE,
      CASE_CONFIRM_D2C_ASSESMENT,
      CASE_CONFIRM_CS_SP_ASSESMENT,
    ];

    let toRouteTo;
    let toRevert;
    let toReject;
    let toResolve;

    let { obj, field } = this.find({
      section: sectionName,
      subSection: sub,
      obj: objId,
      field: fieldName,
    });

    if (field) {
      field.value = value;
      if (fieldName === FIELD_ACCOUNT_CONTRACT_NUMBER_PL) {
        // field.isInternalRequest = value === INTERNAL_REQUEST;
        publish(this.messageContext, CASE_NOC, {
          caseId: this.recordId,
          accountType: value
        });
        // this.business.sectionlst = this.business.sectionlst.map(section => ({
        //   ...section,
        //   subSectionlst: section.subSectionlst?.map(sub => ({
        //     ...sub,
        //     objlst: sub.objlst?.map(obj => ({
        //       ...obj,
        //       fieldlst: obj.fieldlst?.map(f => ({
        //         ...f,
        //         isHidden: value === INTERNAL_REQUEST
        //           ? f.apiName !== FIELD_ACCOUNT_CONTRACT_NUMBER_PL
        //           : false,
        //       })) || [],
        //     })) || [],
        //   })) || [],
        // }));
        // this.business = { ...this.business };
      }
      
      if (field.isDate) {
        field.displayValue = formatToDDMMYYYY(value);
      }
      field.readonlyDisplayValue = field.masked
        ? field.value
        : field.displayValue;
      this.business = { ...this.business };
    }

    if (
      (fieldName === FIELD_UPDATED_INFO_PHONE_NUMBER ||
        fieldName === FIELD_REGISTERED_PHONE_NUMBER ||
        fieldName === FIELD_CASE_PHONE_NUMBER) &&
      field
    ) {
      field.customError = validateUpdatedInfoPhone(value) || null;
      field.editWrapperClass =
        "edit slds-m-around--small slds-p-around--x-small" +
        (field.customError ? " slds-has-error" : STR_EMPTY);
      this.business = { ...this.business };
    }

    if (
      (fieldName === FIELD_UPDATED_INFO_EMAIL ||
        fieldName === FIELD_CASE_EMAIL) &&
      field
    ) {
      const emailResult = validateUpdatedInfoEmail(value);
      field.customError = emailResult.valid ? null : emailResult.message;
      field.editWrapperClass =
        "edit slds-m-around--small slds-p-around--x-small" +
        (field.customError ? " slds-has-error" : STR_EMPTY);
      this.business = { ...this.business };
    }

    if (fieldName === FIELD_NEW_CITIZEN_ID_NUMBER && field) {
      const trimmed =
        value != null && typeof value === "string" ? value.trim() : STR_EMPTY;
      const idResult = validateNationalId(value);
      field.customError =
        trimmed === STR_EMPTY ? null : idResult.isValid ? null : idResult.message;
      field.editWrapperClass =
        "edit slds-m-around--small slds-p-around--x-small" +
        (field.customError ? " slds-has-error" : STR_EMPTY);
      this.business = { ...this.business };
    }
    if (fieldName === FIELD_OLD_CITIZEN_ID_NUMBER && field) {
      const trimmed =
        value != null && typeof value === "string" ? value.trim() : STR_EMPTY;
      const idResult = validateNationalId(value);
      field.customError =
        trimmed === STR_EMPTY ? null : idResult.isValid ? null : idResult.message;
      field.editWrapperClass =
        "edit slds-m-around--small slds-p-around--x-small" +
        (field.customError ? " slds-has-error" : STR_EMPTY);
      this.business = { ...this.business };
    }
    if (fieldName === FIELD_NATIONAL_ID_PASSPORT_ID && field) {
      const trimmed =
        value != null && typeof value === "string" ? value.trim() : STR_EMPTY;
      const idResult = validateIdNumber(value);
      field.customError =
        trimmed === STR_EMPTY
          ? null
          : idResult.isValid
            ? null
            : idResult.message;
      field.editWrapperClass =
        "edit slds-m-around--small slds-p-around--x-small" +
        (field.customError ? " slds-has-error" : STR_EMPTY);
      this.business = { ...this.business };
    }
    if (fieldName === FIELD_UPDATED_INFO_NATIONAL_ID && field) {
      const trimmed =
        value != null && typeof value === "string" ? value.trim() : STR_EMPTY;
      const idResult = validateIdNumber(value);
      field.customError =
        trimmed === STR_EMPTY ? null : idResult.isValid ? null : idResult.message;
      field.editWrapperClass =
        "edit slds-m-around--small slds-p-around--x-small" +
        (field.customError ? " slds-has-error" : STR_EMPTY);
      this.business = { ...this.business };
    }

    // check Updated Info fields + assessment fields → auto Route to / Revert / Reject
    if (adHocFieldlst.includes(`${objName}.${fieldName}`)) {
      switch (`${objName}.${fieldName}`) {
        case CASE_UPDATED_INFO_PHONE_NUMBER:
          toRouteTo = value && value.trim() != STR_EMPTY;
          break;
        case CASE_UPDATED_INFO_FIRST_NAME:
        case CASE_UPDATED_INFO_MIDDLE_NAME:
        case CASE_UPDATED_INFO_LAST_NAME:
        case CASE_UPDATED_INFO_EMAIL:
        case CASE_UPDATED_INFO_DOB:
        case CASE_UPDATED_INFO_GENDER:
        case CASE_UPDATED_INFO_NATIONAL_ID:
        case CASE_UPDATED_INFO_DATE_OF_ISSUE:
        case CASE_UPDATED_INFO_PLACE_OF_ISSUE:
          toRouteTo =
            value != null &&
            (typeof value !== "string" || String(value).trim() !== STR_EMPTY);
          break;

        case CASE_CS_D2C_ASSIGNMENT_TYPE:
          if (obj) {
            obj?.fieldlst?.forEach((item) => {
              if (
                item.apiName === CS_D2C_REQUIRED_CORRECTIVE_ACTION ||
                item.apiName === CS_D2C_RISK_LEVEL
              ) {
                item.isHidden = !(TYPE_UNQUALIFIED == value);
                item.value = undefined;
              }
            });
          }

          toRouteTo = TYPE_QUALIFIED == value;

          toRevert = TYPE_UNQUALIFIED == value;
          break;

        case CASE_CS_SUPPORT_ASSESMENT_TYPE:
          this.showProcessAction = TYPE_QUALIFIED == value;

          // Hợp lệ (Qualified) → Resolve; Không hợp lệ (Unqualified) → Reject
          if (TYPE_QUALIFIED == value) {
            const hasResolve = this.business.routingActionlst?.some(
              (a) => a.value === ACTION_RESOLVE,
            );
            if (hasResolve) {
              toResolve = true;
            }
          } else if (TYPE_UNQUALIFIED == value) {
            const hasReject = this.business.routingActionlst?.some(
              (a) => a.value === ACTION_REJECT,
            );
            if (hasReject) {
              toReject = true;
            }
          }
          break;

        case CASE_CONFIRM_D2C_ASSESMENT:
          toReject = TYPE_AGREE == value;
          toRouteTo = TYPE_DISAGREE == value;

          if (obj) {
            obj?.fieldlst?.forEach((item) => {
              if (item.apiName === ACTIONS_TAKEN_D2C_ASSESMENT) {
                item.isHidden = TYPE_DISAGREE == value;
                item.value = undefined;
              }
            });
          }
          break;

        case CASE_CONFIRM_CS_SP_ASSESMENT:
          toReject = TYPE_AGREE == value;
          toRouteTo = TYPE_DISAGREE == value;
          break;

        default:
          break;
      }

      let routeToEle = this.template.querySelector(
        'lightning-select[data-id="routing-action"]',
      );

      if (routeToEle) {
        if (toRouteTo === true) {
          routeToEle.value = ACTION_ROUTE_TO;
          this.actionValue = ACTION_ROUTE_TO;
        }

        if (toRevert === true) {
          routeToEle.value = ACTION_REVERT;
          this.actionValue = ACTION_REVERT;
        }

        if (toResolve === true) {
          routeToEle.value = ACTION_RESOLVE;
          this.actionValue = ACTION_RESOLVE;
        }

        if (toReject === true) {
          routeToEle.value = ACTION_REJECT;
          this.actionValue = ACTION_REJECT;
        }
      }
    }

    // card block
    if (fieldName === FIELD_CARD_BLOCK_REASON) {
      this.business.sectionlst.forEach(section => {
        section.subSectionlst.forEach(sub => {
          sub.objlst.forEach(obj => {
            obj.fieldlst.forEach(field => {
              if (field.editable) return; // ignore editable
              if (field.apiName === FIELD_NEW_BLOCK_CODE) {
                field.value = MAP_NEW_BLOCK_CODE[value];
                field.displayValue = field.value;
                field.readonlyDisplayValue = field.value;
              }
            });
          });
        });
      });
    }
    // card replacement
    else if (fieldName === FIELD_CARD_REPLACEMENT_REASON) {
      this.business.sectionlst.forEach(section => {
        section.subSectionlst.forEach(sub => {
          sub.objlst.forEach(obj => {
            obj.fieldlst.forEach(field => {
              if (field.editable) return; // ignore editable
              if (field.apiName === FIELD_NEW_BLOCK_CODE_CARD_REPLACE) {
                field.value = MAP_NEW_BLOCK_CODE_CARD_REPLACE[value];
                field.displayValue = field.value;
                field.readonlyDisplayValue = field.value;
              } else if (field.apiName === FIELD_CARD_REPLACEMENT_FEE) {
                field.value = MAP_CARD_REPLACEMENT_FEE_VALUE[value];
                field.displayValue = MAP_CARD_REPLACEMENT_FEE_DISPLAY[value];
                field.readonlyDisplayValue = field.displayValue;
              }
            });
          });
        });
      });
    }
  }

  handleChangeAction(e) {
    this.actionValue = e.detail.value;
  }

  @api validateNatureOfCase() {
    return !!this.business?.natureOfCase;
  }

  @api validate() {
    if (!this.validateNatureOfCase()) return false;

    //this._lastValidationError = null;
    let isAllValid = true;

    let inputFiellst = this.template.querySelectorAll("lightning-input-field");
    inputFiellst?.forEach((item) => {
      if (item.hasAttribute("data-is-date-field")) return;
      if (item.hasAttribute("data-is-phone-field")) return;
      isAllValid = item.reportValidity() && isAllValid;
    });

    let dateInputs = this.template.querySelectorAll(
      'lightning-input[data-field-type="date"]',
    );
    dateInputs?.forEach((input) => {
      isAllValid = input.reportValidity() && isAllValid;
    });

    let phoneInputs = this.template.querySelectorAll(
      "lightning-input[data-is-phone-field]",
    );
    phoneInputs?.forEach((input) => {
      isAllValid = input.reportValidity() && isAllValid;
    });

    // Custom validation (phone, updated info email format)
    this.business?.sectionlst?.forEach((section) => {
      section.subSectionlst?.forEach((sub) => {
        sub.objlst?.forEach((obj) => {
          obj.fieldlst?.forEach((field) => {
            if (field.customError) isAllValid = false;
          });
        });
      });
    });

    let routeToEle = this.template.querySelector(
      'lightning-select[data-id="routing-action"]',
    );

    if (routeToEle)
      isAllValid = routeToEle && routeToEle.reportValidity() && isAllValid;

    const ipEl = this._getIncorrectPaymentFormEl();
    if (ipEl && typeof ipEl.validateForSubmit === "function") {
      if (!ipEl.validateForSubmit()) {
        isAllValid = false;
      }
    }

    const benEl = this._getBeneficiaryBankInfoBlockEl();
    if (benEl && typeof benEl.validateForSubmit === "function") {
      if (!benEl.validateForSubmit()) {
        isAllValid = false;
      }
    }

    const refundReqEl = this._getRefundRequestFormEl();
    if (refundReqEl && typeof refundReqEl.validateForSubmit === "function") {
      if (!refundReqEl.validateForSubmit()) {
        isAllValid = false;
      }
    } else if (refundReqEl && typeof refundReqEl.validateRefund === "function") {
      if (!refundReqEl.validateRefund()) {
        isAllValid = false;
      }
    }

    // let accountContractField = this.template.querySelector(
    //   'lightning-input-field[data-field="' + FIELD_ACCOUNT_CONTRACT_NUMBER_PL + '"]',
    // );
    // if (accountContractField) {
    //   let val = accountContractField.value;
    //   if (val == null || val === STR_EMPTY || val === NONE_STRING) {
    //     isAllValid = false;
    //     this._lastValidationError = LABEL_ACCOUNT_CONTRACT_NUMBER;
    //   }
    // }

    return isAllValid;
  }

  // @api getLastValidationError() {
  //   return this._lastValidationError || null;
  // }

  _getIncorrectPaymentFormEl() {
    const wrap = this.template.querySelector(
      '[data-fec-lwc="fec_IncorrectPaymentForm"]',
    );
    const host = wrap && wrap.firstElementChild;
    if (
      host &&
      (typeof host.validateForSubmit === "function" ||
        typeof host.saveAdjustmentsIfApplicable === "function" ||
        typeof host.saveDraftIfApplicable === "function")
    ) {
      return host;
    }
    return null;
  }

  _getBeneficiaryBankInfoBlockEl() {
    const wrap = this.template.querySelector(
      '[data-fec-lwc="fec_BeneficiaryBankInfoBlock"]',
    );
    const host = wrap && wrap.firstElementChild;
    if (
      host &&
      (typeof host.validateForSubmit === "function" ||
        typeof host.saveBeneficiaryIfApplicable === "function" ||
        typeof host.saveDraftIfApplicable === "function")
    ) {
      return host;
    }
    return null;
  }

  _saveIncorrectPaymentAdjustmentsIfApplicable() {
    const el = this._getIncorrectPaymentFormEl();
    if (!el || typeof el.saveAdjustmentsIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveAdjustmentsIfApplicable();
  }

  _saveIncorrectPaymentDraftIfApplicable() {
    const el = this._getIncorrectPaymentFormEl();
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveDraftIfApplicable();
  }

  _saveBeneficiaryBankInfoDraftIfApplicable() {
    const el = this._getBeneficiaryBankInfoBlockEl();
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveDraftIfApplicable();
  }

  _saveBeneficiaryIfApplicable() {
    const el = this._getBeneficiaryBankInfoBlockEl();
    if (!el || typeof el.saveBeneficiaryIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveBeneficiaryIfApplicable();
  }

  _getCardClosureRefundFormEl() {
    const wrap = this.template.querySelector(
      '[data-fec-lwc="fec_CardClosureRefundForm"]',
    );
    const host = wrap && wrap.firstElementChild;
    if (
      host &&
      (typeof host.validateForSubmit === "function" ||
        typeof host.saveForSubmitIfApplicable === "function" ||
        typeof host.saveDraftIfApplicable === "function")
    ) {
      return host;
    }
    return null;
  }

  _saveCardClosureRefundDraftIfApplicable() {
    const el = this._getCardClosureRefundFormEl();
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveDraftIfApplicable();
  }

  _saveCardClosureRefundForSubmitIfApplicable() {
    const el = this._getCardClosureRefundFormEl();
    if (!el || typeof el.saveForSubmitIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveForSubmitIfApplicable();
  }

  _getRefundRequestFormEl() {
    const wrap = this.template.querySelector(
      '[data-fec-lwc="fec_RefundRequestForm"]',
    );
    const host = wrap && wrap.firstElementChild;
    if (
      host &&
      (typeof host.validateForSubmit === "function" ||
        typeof host.validateRefund === "function" ||
        typeof host.saveDraftIfApplicable === "function" ||
        typeof host.saveRefundDataIfApplicable === "function" ||
        typeof host.saveRefundDataIfVisible === "function")
    ) {
      return host;
    }
    return null;
  }

  _saveRefundRequestDraftIfApplicable() {
    const el = this._getRefundRequestFormEl();
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveDraftIfApplicable();
  }

  _saveRefundRequestIfApplicable() {
    const el = this._getRefundRequestFormEl();
    if (!el) {
      return Promise.resolve();
    }
    if (typeof el.saveRefundDataIfApplicable === "function") {
      return el.saveRefundDataIfApplicable();
    }
    if (typeof el.saveRefundDataIfVisible === "function") {
      return el.saveRefundDataIfVisible();
    }
    return Promise.resolve();
  }
  /*Lấy element của form IPP Closure*/
  _getIppClosureFormEl() {
    const wrapper = this.template.querySelector(
      '[data-fec-lwc="fec_IPPClosureForm"]',
    );
    if (wrapper && wrapper.firstElementChild) {
      const el = wrapper.firstElementChild;
      if (typeof el.validateSelectionRequiredForSubmit === "function") {
        return el;
      }
    }
    return (
      this.template.querySelector("c-fec_-i-p-p-closure-form") ||
      this.template.querySelector("c-fec_-ipp-closure-form")
    );
  }

  /* IPP Closure: không đủ IPP → auto Reject; Case đã có IPP chọn → auto Route to */									
  handleIppClosureLoad(event) {
    const d = event.detail || {};
    this._ippClosureHasEligibleRows = !!d.hasEligibleRows;

    if (d.noEligibleForClosure) {
      Promise.resolve().then(() => {
        const hasReject = this.business.routingActionlst?.some(
          (a) => a.value === ACTION_REJECT,
        );
        if (!hasReject) {
          return;
        }
        this.actionValue = ACTION_REJECT;
        const routeToEle = this.template.querySelector(
          'lightning-select[data-id="routing-action"]',
        );
        if (routeToEle) {
          routeToEle.value = ACTION_REJECT;
        }
      });
      return;
    }

    if (d.hasEligibleRows && d.savedIppToCloseOnCase) {
      Promise.resolve().then(() => {
        this._applyIppClosureRouteToWhenEditable();
      });
      return;
    }

  }

  handleIppClosureSelection(event) {
    const d = event.detail || {};
    const has = d.hasSelection === true;
    if (!this._ippClosureHasEligibleRows) {
      return;
    }
    if (!has) {
      return;
    }
    Promise.resolve().then(() => {
      this._applyIppClosureRouteToWhenEditable();				   
    });
  }

  _applyIppClosureRouteToWhenEditable() {
    if (
      !this.isEdit ||
      !(this.business?.routingActionlst && this.business.routingActionlst.length > 0)
    ) {
      return;
    }
    const hasRouteTo = this.business.routingActionlst?.some(
      (a) => a.value === ACTION_ROUTE_TO,
    );
    if (!hasRouteTo) {
      return;
    }
    const routeToEle = this.template.querySelector(
      'lightning-select[data-id="routing-action"]',
    );
    if (!routeToEle) {
      return;
    }
    routeToEle.value = ACTION_ROUTE_TO;
    this.actionValue = ACTION_ROUTE_TO;
  }

  _validateIPPClosureForSubmit() {
    const el = this._getIppClosureFormEl();
    if (el && typeof el.validateSelectionRequiredForSubmit === "function") {
      return el.validateSelectionRequiredForSubmit();
    }
    return true;
  }

  _saveIPPClosureIfApplicable() {
    const el = this._getIppClosureFormEl();
    if (el && typeof el.saveSelectedIPPIfApplicable === "function") {
      return el.saveSelectedIPPIfApplicable();
    }
    return Promise.resolve();
  }

  /**
   * Chỉ lưu dữ liệu form (Nature of Case, Account Info, Case Info, Process Action, Routing Action)
   * mà KHÔNG gọi run() - không chuyển sang Stage tiếp theo.
   * Dùng cho nút "Save & Close". Không validate input/select khi Save & Close.
   */
  @api saveOnly() {
    let formlst = this.template.querySelectorAll("lightning-record-edit-form");
    let formToSubmit = [];
    formlst?.forEach((item) => {
      if (!item) return;
      let fieldlst = item.querySelectorAll("lightning-input-field");
      if (fieldlst && fieldlst.length > 0 && item.recordId) {
        formToSubmit.push(item);
      }
    });

    const total = formToSubmit.length;
    const afterForms = () =>
      Promise.all([
        this._saveIncorrectPaymentDraftIfApplicable(),
        this._saveIPPClosureIfApplicable(),
        this._saveBeneficiaryBankInfoDraftIfApplicable(),
        this._saveCardClosureRefundDraftIfApplicable(),
        this._saveRefundRequestDraftIfApplicable(),
      ]);
    if (total === 0) {
      return afterForms();
    }

    return new Promise((resolve, reject) => {
      this._saveOnlyResolve = resolve;
      this._saveOnlyReject = reject;
      this._saveOnlyFormCount = 0;
      this._saveOnlyFormTotal = total;

      formToSubmit.forEach((item) => {
        this._applyPicklistLabelToApiValue(item);
        item.submit();
      });
    }).then(() => afterForms());
  }

  /** false = bị chặn (đã show toast), true = submit thành công. */
  @api async submit() {
    if (!this.validate()) return false;
    if (!this._validateIPPClosureForSubmit()) return false;

    // Có routing thì mới chặn khi chưa đổi thông tin Updated; không có routing cho phép chỉ submit remarks.
    let routeToEle = this.template.querySelector(
      'lightning-select[data-id="routing-action"]',
    );
    const noUpdate = checkNoUpdateInSubmit(
      this._getCaseFieldOriginalValue.bind(this),
      this._getCaseFieldValue.bind(this),
      this._getCheckNoUpdateInSubmitOptions(),
    );
    // Chỉ chặn khi có dropdown routing và user chưa cập nhật bất kỳ trường Updated nào.
    if (routeToEle && noUpdate) {
      this.showToast(FEC_Warning_Title, FEC_MSG_UPDATED_INFO_NOT_UPDATED, "warning");
      return false;
    }

    await this._submitFormsPromise();
    await Promise.all([
      this._saveIncorrectPaymentAdjustmentsIfApplicable(),
      this._saveIPPClosureIfApplicable(),
      this._saveBeneficiaryIfApplicable(),
      this._saveCardClosureRefundForSubmitIfApplicable(),
      this._saveRefundRequestIfApplicable(),
    ]);
    if (routeToEle) {
      let method = routeToEle.value;
      let actionId;
      this.business.routingActionlst?.forEach((item) => {
        if (item.value == method) {
          actionId = item.id;
        }
      });
      let params = { method };
      switch (method) {
        case ACTION_ROUTE_TO:
          params = {
            ...params,
            params: {
              caseId: this.recordId,
              queueId: this.business.nextQueue?.value,
              natureOfCaseId: this.business.natureOfCase,
              actionId: actionId,
            },
          };
          break;
        case ACTION_REVERT:
          params = { ...params, params: { caseId: this.recordId } };
          break;
        case ACTION_TRANSFER:
          params = {
            ...params,
            params: {
              caseId: this.recordId,
              userOrQueueId: this.subDecisionValue,
            },
          };
          break;
        case ACTION_UPDATE:
          params = {
            ...params,
            params: {
              caseId: this.recordId,
              decision: this.decisionValue,
            },
          };
          break;
        default:
          params = { ...params, params: { caseId: this.recordId } };
          break;
      }
      if (method === ACTION_ROUTE_TO && !this.business.nextQueue?.value) {
        this.showToast(FEC_Error_Title, FEC_MSG_Can_Not_Find_Next_Stage, "error");
        return false;
      }
      if (
        ACTIONS_NEED_NOC_BEFORE_RUN.includes(method) &&
        this.business?.natureOfCase
      ) {
        await saveCaseNOC({
          caseId: this.recordId,
          natureOfCaseId: this.business.natureOfCase,
        });
      }
      await run({ ...params });
    } else {
      if (this.business?.natureOfCase) {
        await saveCaseNOC({
          caseId: this.recordId,
          natureOfCaseId: this.business.natureOfCase,
        });
        await markCaseSubmittedWithoutRouting({ caseId: this.recordId });
      }
    }
    return true;
  }

  handleProcessAction(e) {
    let method = e.target.dataset.id;

    this.processActionMethod = method;

    let header;
    let content;
    if (method == ACTION_BLOCK_CARD) {
      header = FEC_Block_Card_Header;
      content = FEC_Block_Card_Confirmation_Msg;
    } else if (method == ACTION_UNBLOCK_CARD) {
      header = FEC_ACTION_UNBLOCK_CARD_HEADER;
      content = FEC_MSG_ACTION_UNBLOCK_CARD;
    } else if (method == ACTION_PIN_REISSUE) {
      header = FEC_ACTION_PIN_REISSUE_HEADER;
      content = FEC_MSG_ACTION_PIN_REISSUE;
    } else {
      header = FEC_ACTION_PHONE_UPDATE_HEADER;
      content = FEC_MSG_ACTION_PHONE_UPDATE;
    }

    this.header = header;
    this.content = content;
    this.isModalOpen = true;
  }

  handleCloseModal() {
    this.isModalOpen = false;
  }

  handleRun() {
    this.isLoaded = false;
    this.isModalOpen = false;
    this.isProcessActionSuccessed = false;
    this.isProcessActionFailed = false;
    this.processActionMsg = null;

    let params;

    switch (this.processActionMethod) {
      case ACTION_PHONE_UPDATE:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_EMAIL_UPDATE:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_FULLNAME_UPDATE:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_DOB_UPDATE:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_GENDER_UPDATE:
        params = {
          caseId: this.recordId,
        };
        break;

      case OC_001:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_BLOCK_CARD:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_UNBLOCK_CARD:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_PIN_REISSUE:
        params = {
          caseId: this.recordId,
        };
        break;

      default:
        break;
    }

    let msgSuccess;
    let msgError;
    if (this.processActionMethod == ACTION_BLOCK_CARD) {
      msgSuccess = FEC_Block_Card_Success;
      msgError = FEC_Block_Card_Failed_Max;
    } else if (this.processActionMethod == ACTION_UNBLOCK_CARD) {
      msgSuccess = FEC_MSG_ACTION_UNBLOCK_CARD_SUCCESS;
      msgError = FEC_MSG_ACTION_UNBLOCK_CARD_ERROR;
    } else if (this.processActionMethod == ACTION_PIN_REISSUE) {
      msgSuccess = FEC_MSG_ACTION_PIN_REISSUE_SUCCESS;
      msgError = FEC_MSG_ACTION_PIN_REISSUE_ERROR;
    } else {
      msgSuccess = FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS;
      msgError = FEC_MSG_ACTION_PHONE_UPDATE_ERROR;
    }
    
    run({ method: this.processActionMethod, params })
      .then((res) => {
        let isSuccess = res?.success;
        console.log('>>>>>>>isSuccess: ' + isSuccess);

        this.isProcessActionValid =
          res?.actionCount != -1 && res?.actionCount != 3;

        if (isSuccess) {
          this.processActionMsg = msgSuccess;
          this.isProcessActionSuccessed = true;
          this.isProcessActionFailed = false;
          this.actionValue = ACTION_RESOLVE;

          let routeToEle = this.template.querySelector(
            'lightning-select[data-id="routing-action"]',
          );

          if (routeToEle) {
            routeToEle.value = ACTION_RESOLVE;
          }
          // thangtv update logic for Jira KH-931
          this.removeRoutingActions([ACTION_REJECT, ACTION_CANCEL]);

        } else {
          this.processActionMsg = msgError;
          this.isProcessActionSuccessed = false;
          this.isProcessActionFailed = true;
        }

        // switch (this.processActionMethod) {
        //   case ACTION_PHONE_UPDATE:
        //     break;

        //   default:
        //     break;
        // }
      })
      .catch((err) => {
        console.error(
          "🚀 ~ Fec_CaseBussiness ~ handleRun ~ err:",
          JSON.stringify(err),
        );

        this.isProcessActionFailed = true;
        this.isProcessActionSuccessed = false;
        this.processActionMsg = msgError;
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  find(filter) {
    // let filter = {
    //   section: e.target.dataset.section,
    //   subSection: e.target.dataset.sub,
    //   obj: e.target.dataset.obj,
    //   field: e.target.dataset.field
    // };

    let section;
    let subSection;
    let obj;
    let field;

    section = this.business?.sectionlst?.find(
      (item) => item.id === filter.section,
    );

    if (section) {
      subSection = section.subSectionlst?.find(
        (item) => item.name === filter.subSection,
      );

      if (subSection) {
        obj = subSection.objlst?.find((item) => (item.id === filter.obj));

        if (obj) {
          field = obj.fieldlst.find((item) => item.apiName === filter.field);
        }
      }
    }

    return { section, subSection, obj, field };
  }

  handleSuccess() {
    if (this._submitFormsResolve != null) {
      this._submitFormsCount = (this._submitFormsCount || 0) + 1;
      if (this._submitFormsCount >= this._submitFormsTotal) {
        this._submitFormsResolve();
        this._submitFormsResolve = null;
        this._submitFormsReject = null;
      }
    }
    if (this._saveOnlyResolve != null) {
      this._saveOnlyFormCount = (this._saveOnlyFormCount || 0) + 1;
      if (this._saveOnlyFormCount >= this._saveOnlyFormTotal) {
        this._saveOnlyResolve();
        this._saveOnlyResolve = null;
        this._saveOnlyReject = null;
      }
    }
  }

  handleFormError(event) {
    const detail = event?.detail;
    if (this._submitFormsReject != null) {
      this._submitFormsReject(detail);
      this._submitFormsResolve = null;
      this._submitFormsReject = null;
    }
    if (this._saveOnlyReject != null) {
      this._saveOnlyReject(detail);
      this._saveOnlyResolve = null;
      this._saveOnlyReject = null;
    }
  }

  /**
   * Gán lại API value cho các trường picklist trước khi submit (data từ Apex dùng toLabel nên value đang là label).
   * Giữ toLabel để hiển thị tiếng Việt; khi gửi lên server phải dùng API name.
   */
  _applyPicklistLabelToApiValue(form) {
    const map = this.business?.picklistOptionsMap;
    if (!map) return;

    const fieldlst = form.querySelectorAll("lightning-input-field");
    fieldlst?.forEach((inputField) => {
      const objName = inputField.dataset?.objName;
      const fieldName = inputField.dataset?.field;
      if (!objName || !fieldName) return;

      const options = map[objName]?.[fieldName];
      if (!options || !Array.isArray(options) || options.length === 0) return;

      const currentVal = inputField.value;
      if (currentVal == null || currentVal === STR_EMPTY) return;

      const found = findPicklistOptionByRaw(options, currentVal);
      if (found) {
        inputField.value = found.value;
      }
    });
  }

  /**
   * Submit toàn bộ form và chờ tất cả hoàn thành.
   * Đảm bảo Account Info, Case Info đã lưu trước khi run().
   */
  _rebuildAllSectionSortedRows() {
    if (!this.business?.sectionlst) {
      return;
    }
    this.business.sectionlst.forEach((section) => {
      section.sortedSectionContentlst = mergeSectionSortedRows(section);
    });
    this.business = { ...this.business };
  }

  _submitFormsPromise() {
    let formlst = this.template.querySelectorAll("lightning-record-edit-form");
    let formToSubmit = [];
    formlst?.forEach((item) => {
      if (!item) return;
      let fieldlst = item.querySelectorAll("lightning-input-field");
      if (fieldlst && fieldlst.length > 0 && item.recordId) {
        formToSubmit.push(item);
      }
    });

    const total = formToSubmit.length;
    if (total === 0) return Promise.resolve();

    return new Promise((resolve, reject) => {
      this._submitFormsResolve = resolve;
      this._submitFormsReject = reject;
      this._submitFormsCount = 0;
      this._submitFormsTotal = total;

      formToSubmit.forEach((item) => {
        this._applyPicklistLabelToApiValue(item);
        item.submit();
      });
    });
  }

  /**
   * Resolves LWC name strings from Apex (section.componentlst — theo FEC_Section__c)
   * into component constructors required by lwc:is.
   *
   * LWC strict mode (LWC1121) forbids variable/template-literal import() arguments.
   * Each name is therefore looked up in DYNAMIC_COMPONENT_REGISTRY which holds
   * pre-declared static `() => import('c/<name>')` thunks. Unknown names are
   * skipped with a console warning — the rest of the UI is unaffected.
   *
   * Results are stored on each section as resolvedComponentlst [{key, ctor, componentName}].
   */
  _resolveComponentlst() {
    if (!this.business?.sectionlst) return;

    const resolvePromises = [];

    this.business.sectionlst.forEach((section) => {
      if (!section.componentlst?.length) return;

      const slots = section.componentlst.map(() => null);
      section._fecDynCmpSlots = slots;
      section.resolvedComponentlst = [];

      section.componentlst.forEach((entry, idx) => {
        if (!entry) return;

        const meta = normalizeMasterDataLwcEntry(entry);
        const name = meta.componentName;
        if (!name) return;

        const fecMasterDataSettingIsEdit = meta.fecMasterDataSettingIsEdit;

        const loader = DYNAMIC_COMPONENT_REGISTRY[name];
        if (!loader) {
          console.warn(
            `[fec_CaseBussiness] Component "${name}" is not registered in DYNAMIC_COMPONENT_REGISTRY. ` +
            `Add an entry: ${name}: () => import('c/${name}')`
          );
          return;
        }

        const p = loader()
          .then((mod) => {
            const layoutNum = Number(meta.fieldLayout);
            const layout =
              Number.isFinite(layoutNum) &&
              SLDS_MEDIUM_SIZE_OF_12[layoutNum]
                ? layoutNum
                : 12;
            const lwcColClassName =
              "slds-col slds-size_1-of-1 " +
              (SLDS_MEDIUM_SIZE_OF_12[layout] ||
                SLDS_MEDIUM_SIZE_OF_12[12]) +
              " slds-m-top_medium";
            const fecSubSectionOrder = meta.order;
            slots[idx] = {
              key: `${name}-${idx}`,
              ctor: mod.default,
              componentName: name,
              fecMasterDataSettingIsEdit,
              isEdit: this._isEdit && fecMasterDataSettingIsEdit,
              /** Thứ tự merge: cùng nguồn FEC_Sub_Section_Order__c (Apex → meta.order). */
              sortOrder: fecSubSectionOrder,
              fecSubSectionOrder,
              fieldLayout: meta.fieldLayout,
              subSectionName: meta.subSectionName,
              lwcColClassName,
            };
          })
          .catch((err) => {
            console.error(`[fec_CaseBussiness] Failed to load component "${name}":`, err);
          });

        resolvePromises.push(p);
      });
    });

    Promise.all(resolvePromises).then(() => {
      this.business.sectionlst.forEach((section) => {
        if (section._fecDynCmpSlots) {
          const lst = section._fecDynCmpSlots.filter(Boolean);
          lst.sort((a, b) => {
            const ao = readFecSubSectionOrder(a);
            const bo = readFecSubSectionOrder(b);
            const na = ao !== undefined ? ao : 1_000_000;
            const nb = bo !== undefined ? bo : 1_000_000;
            return na - nb;
          });
          section.resolvedComponentlst = lst;
          delete section._fecDynCmpSlots;
        }
      });
      this._updateDynCmpIsEditFlags();
      this._rebuildAllSectionSortedRows();
    });
  }

  applyDraft() {
    const draft = JSON.parse(localStorage.getItem(this.draftKey));
    if (!draft || !this.business) return;
    this.business.sectionlst.forEach(section => {
        section.subSectionlst.forEach(sub => {
            sub.objlst.forEach(obj => {
                obj.fieldlst.forEach(field => {
            if (!field.editable) return; // ignore non editable
                    const key = obj.id + '_' + field.apiName;
            // if (draft[key] && !field.value) {
            if (draft[key]) { // still applyDraft with existing data
              field.value = draft[key];
              field.displayValue = draft[key];
            }
          });
        });
      });
    });
  }

  setDraft(objId, fieldName, value) {
    let draft = JSON.parse(localStorage.getItem(this.draftKey)) || {};
    const key = objId + '_' + fieldName;
    draft[key] = value;
    localStorage.setItem(this.draftKey, JSON.stringify(draft));
  }
  //Thangtv update logic remove routing action Reject, Cancel after run API success
  removeRoutingActions(actionsToRemove = []) {
    if (!this.business?.routingActionlst) return;

    this.business.routingActionlst = this.business.routingActionlst.filter(
      (a) => !actionsToRemove.includes(a.value)
    );

    // If current selected value was removed, reset to Resolve
    if (actionsToRemove.includes(this.actionValue)) {
      this.actionValue = ACTION_RESOLVE;
    }

    // this._syncHasRoutingAction(); // PhuongNT cmt, method not exist
    this.business = { ...this.business };
  }
  //Thangtv update logic only show routing action when mode = handling
  get showRoutingSection() {
   return this.isEdit && this.business?.hasRoutingAction;
  }
}