import { LightningElement, api, track, wire } from "lwc";
import Toast from "lightning/toast";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getByCase from "@salesforce/apex/FEC_CaseBusinessService.getByCase";
import updateRoutingActionDisplayApex from "@salesforce/apex/FEC_CaseInitUpdateService.updateRoutingActionDisplay";
import getTransferUsers from "@salesforce/apex/FEC_CaseBusinessService.getTransferUsers";
import getTransferQueues from "@salesforce/apex/FEC_CaseBusinessService.getTransferQueues";
import run from "@salesforce/apex/FEC_CaseBusinessService.run";
import saveCaseNOC from "@salesforce/apex/FEC_CaseBusinessService.saveCaseNOC";
import getRoutingConfig from "@salesforce/apex/FEC_RDPaymentContractAssessmentService.getRoutingConfig"; // Toannd61
import markCaseSubmittedWithoutRouting from "@salesforce/apex/FEC_CaseBusinessService.markCaseSubmittedWithoutRouting";
//PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu
import markCaseSubmittedWithoutRoutingWithHistory from "@salesforce/apex/FEC_CaseBusinessService.markCaseSubmittedWithoutRoutingWithHistory";
//PhongBT: query FEC_Case_Flow_History__c sau khi đổi bộ noc khác để lấy lại giá trị đã nhập lên
import getPropertyFieldsFromFlowHistory from "@salesforce/apex/FEC_CaseEditNOCController.getPropertyFieldsFromFlowHistory";
import logSensitiveAccess from "@salesforce/apex/FEC_InteractionHighlightController.logSensitiveAccess";
import getCardStatus from "@salesforce/apex/FEC_CardLockUnLockController.getCardStatus";
import checkProcessActionCardBlock from "@salesforce/apex/FEC_CardLockUnLockController.checkProcessActionCardBlock";
import checkProcessAction from "@salesforce/apex/FEC_CardReplacementAddressController.checkProcessAction";
import { getRecord, getFieldValue, updateRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import FEC_NFU_DESCRIPTION_RESULT from "@salesforce/schema/Case.FEC_NFU_Description_Result__c";
import getSubProcesses from "@salesforce/apex/FEC_SubProcessService.getSubProcesses";
import getSubmittedSubProcesses from "@salesforce/apex/FEC_SubProcessService.getSubmittedSubProcesses";
import USER_ID from "@salesforce/user/Id";
import USER_GROUP_FIELD from "@salesforce/schema/User.FEC_User_Group__c";
import ID_FIELD from "@salesforce/schema/Case.Id";
// PhuongNT add field FEC_Stage_Name__c
import STAGE_NAME_FIELD from "@salesforce/schema/Case.FEC_Stage_Name__c";
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
  isOnlyNumber,
  formatCurrencyIncludeTax,
  formatCurrency2,
} from "c/fec_CommonUtils";

import { MASKING_TYPE_PHONE, MASKING_TYPE_PASSPORT, STR_EMPTY, ICON_HIDE, ICON_PREVIEW, INTERNAL_REQUEST, CASE_OBJECT_API_NAME, FIELD_CUSTOMER_PHONE_NUMBER, FIELD_RECEIVING_PHONE_NUMBER, FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX, FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX, FEC_POINTS_REDEMPTION_STORAGE_NOC_SELECTION_PREFIX } from "c/fec_CommonConst";
import FEC_MSG_UPDATED_INFO_NOT_UPDATED from "@salesforce/label/c.FEC_MSG_UPDATED_INFO_NOT_UPDATED";
import FEC_MSG_Can_Not_Find_Next_Stage from "@salesforce/label/c.FEC_MSG_Can_Not_Find_Next_Stage";
import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";
import FEC_Warning_Title from "@salesforce/label/c.FEC_Warning_Title";
import FEC_ACTION_PHONE_UPDATE_HEADER from "@salesforce/label/c.FEC_ACTION_PHONE_UPDATE_HEADER";
import FEC_MSG_ACTION_PHONE_UPDATE from "@salesforce/label/c.FEC_MSG_ACTION_PHONE_UPDATE";
import FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS from "@salesforce/label/c.FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS";
import FEC_MSG_ACTION_PHONE_UPDATE_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_PHONE_UPDATE_ERROR";
import FEC_MSG_ACTION_ADDRESS_UPDATE_MAX_FAIL from "@salesforce/label/c.FEC_MSG_ACTION_ADDRESS_UPDATE_MAX_FAIL";
import FEC_MSG_ACTION_ADDRESS_UPDATE_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_ADDRESS_UPDATE_ERROR";
import FEC_Reason_Label from "@salesforce/label/c.FEC_Reason_Label";
import {
  applyMrcRl0502DupFieldLayout,
  ensureMrcReturnCaseFormInBusiness,
  FIELD_MRC_CUSTOMER_CONFIRMATION,
  FIELD_MRC_HANDLING_OPTION,
  getCaseFieldValue,
  getMrcReturnAutoRoutingActionCode,
  isMrcReturnTrackedField,
  isMrcRl05Branch,
  isMrcRl05CaseInformationBlocked,
  shouldActivateMrcReturnRouting,
  showMrcRl0502DupBanner,
  validateMrcReturnCase,
} from "c/fecMrcReturnCaseLogic";
import FEC_MSG_Param_Maxlength from "@salesforce/label/c.FEC_MSG_Param_Maxlength";
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
import FEC_Block_Card_Failed from '@salesforce/label/c.FEC_Block_Card_Failed';
import FEC_ACTION_UNBLOCK_CARD_HEADER from "@salesforce/label/c.FEC_ACTION_UNBLOCK_CARD_HEADER";
import FEC_MSG_ACTION_UNBLOCK_CARD from "@salesforce/label/c.FEC_MSG_ACTION_UNBLOCK_CARD";
import FEC_MSG_ACTION_UNBLOCK_CARD_SUCCESS from "@salesforce/label/c.FEC_MSG_ACTION_UNBLOCK_CARD_SUCCESS";
import FEC_MSG_ACTION_UNBLOCK_CARD_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_UNBLOCK_CARD_ERROR";
import FEC_MSG_ACTION_UNBLOCK_CARD_ERROR_RETRY from "@salesforce/label/c.FEC_MSG_ACTION_UNBLOCK_CARD_ERROR_RETRY";
import FEC_ACTION_PIN_REISSUE_HEADER from "@salesforce/label/c.FEC_ACTION_PIN_REISSUE_HEADER";
import FEC_MSG_ACTION_PIN_REISSUE from "@salesforce/label/c.FEC_MSG_ACTION_PIN_REISSUE";
import FEC_MSG_ACTION_PIN_REISSUE_SUCCESS from "@salesforce/label/c.FEC_MSG_ACTION_PIN_REISSUE_SUCCESS";
import FEC_MSG_ACTION_PIN_REISSUE_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_PIN_REISSUE_ERROR";
import FEC_MSG_ACTION_PIN_REISSUE_ERROR_RETRY from "@salesforce/label/c.FEC_MSG_ACTION_PIN_REISSUE_ERROR_RETRY";
import FEC_ACTION_CARD_REPLACEMENT_HEADER from "@salesforce/label/c.FEC_ACTION_CARD_REPLACEMENT_HEADER";
import FEC_MSG_ACTION_CARD_REPLACEMENT from "@salesforce/label/c.FEC_MSG_ACTION_CARD_REPLACEMENT";
import FEC_MSG_ACTION_CARD_REPLACEMENT_SUCCESS from "@salesforce/label/c.FEC_MSG_ACTION_CARD_REPLACEMENT_SUCCESS";
import FEC_MSG_ACTION_CARD_REPLACEMENT_ERROR from "@salesforce/label/c.FEC_MSG_ACTION_CARD_REPLACEMENT_ERROR";
import FEC_MSG_ACTION_CARD_REPLACEMENT_ERROR_RETRY from "@salesforce/label/c.FEC_MSG_ACTION_CARD_REPLACEMENT_ERROR_RETRY";
import FEC_Add_Item_Label from "@salesforce/label/c.FEC_Add_Item_Label";
import FEC_Assignment_Remark_Label from "@salesforce/label/c.FEC_Assignment_Remark_Label";
import FEC_Confirm_Label from "@salesforce/label/c.FEC_Confirm_Label";
// tungnm37 thêm: import label tên queue CS Support và Apex getTeamQueueOptions
import FEC_CS_Support_Queue_Name from "@salesforce/label/c.FEC_CS_Support_Queue_Name";
import FEC_Confirm_Before_Submit from "@salesforce/label/c.FEC_Confirm_Before_Submit"; // tungnm37 thêm
import FEC_Duplicate_Queue_Error from "@salesforce/label/c.FEC_Duplicate_Queue_Error"; // tungnm37 thêm
import getTeamQueueOptions from "@salesforce/apex/FEC_CaseBusinessService.getTeamQueueOptions";
//PhongBT 18/05/26: Document Request sử dụng cục routing action mới
import getDocumentRequestStageChangeRouting from "@salesforce/apex/FEC_DocumentRequestRoutingService.getStageChangeRouting";
import getRoutingActionsForRl0402Rl0403 from "@salesforce/apex/FEC_DocumentRequestRoutingActionService.getRoutingActionsForRl0402Rl0403";
import getRoutingActionsForMrcRl05 from "@salesforce/apex/FEC_DocumentRequestRoutingActionService.getRoutingActionsForMrcRl05";
import {
  getDocumentRequestRoutingContext,
  setBusinessFieldValue,
} from "./fecDocumentRequestStageChangeRouting";
import {
  getMrcReturnRoutingContext,
} from "c/fecMrcReturnStageChangeRouting";
import {
  computeShowScopedStageChangeRoutingSection,
  computeShowDocumentRequestStageChangeRoutingSection,
  computeShowMrcReturnStageChangeRoutingSection,
  computeShowStage1AutoRouteToRoutingSection,
  computeShowLegacyRoutingSectionForDisplay,
  computeRouteToActionButtonId,
  shouldPreferScopedRoutingFromStage2,
  applyRdPaymentStageChangeRoutingFromAssessment,
  applyRdPaymentAssessmentRoutingImmediate,
  resolveRoutingActionSelectEl,
  validateScopedRoutingSection,
  trySubmitScopedRouteTo,
} from "c/fec_CaseBussinessScopedRoutingIntegration";
//PhongBT 14/05/26: Document Request — save PDF to Case
import savePdfToCase from "@salesforce/apex/FEC_ClientPDFService.savePdfToCase";
import { getPdfConfigForSubCode, buildPdfDataForSubCode } from "./fecDocumentRequestPdfData";
import getPaymentHistoryRows from "@salesforce/apex/FEC_PaymentHistoryValidationService.getPaymentHistoryRows";
import getRepaymentScheduleRows from "@salesforce/apex/FEC_PaymentHistoryValidationService.getRepaymentScheduleRows";
//PhongBT 18/05/26: fix Document Request
import validatePaymentHistoryRequestForSubCode from "@salesforce/apex/FEC_PaymentHistoryValidationService.validatePaymentHistoryRequestForSubCode";
import getDocumentRequestPdfHeaderData from "@salesforce/apex/FEC_PaymentHistoryValidationService.getDocumentRequestPdfHeaderData";
import { publish, MessageContext } from "lightning/messageService";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import CASE_NOTIFICATION from "@salesforce/messageChannel/FEC_Case_Notification__c";
import PIN_REISSUE_MESSAGE_CHANNEL from "@salesforce/messageChannel/FEC_PinReissue__c";
import PROCESS_ACTION_MESSAGE_CHANNEL from "@salesforce/messageChannel/FEC_ProcessAction__c";
// [NOC-HANDLING-STAGE-UPDATE]: Import subscribe/unsubscribe để lắng nghe CASE_NOC channel
import { subscribe, unsubscribe, APPLICATION_SCOPE } from "lightning/messageService";


const ACTION_PHONE_UPDATE = "Phone Update";
const ACTION_EMAIL_UPDATE = "Email Update";
const ACTION_FULLNAME_UPDATE = "Full Name Update";
const ACTION_DOB_UPDATE = "Date of Birth Update";
const ACTION_GENDER_UPDATE = "Gender Update";
const ACTION_ADDRESS_UPDATE = "Address Update";
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

const SUB_CODE_RL0402 = "RL04.02";
const SUB_CODE_RL0403 = "RL04.03";

const ACTION_BLOCK_CARD = "Block Card";
const ACTION_UNBLOCK_CARD = "Unblock Card";
const ACTION_PIN_REISSUE = "Reissue PIN";
const ACTION_REPLACE_CARD = "Replace Card";

const PROCESS_BLOCK_CARD = "Card Block";
const PROCESS_UNBLOCK_CARD = "Card Unblock";
const PROCESS_PIN_REISSUE = "PIN Replacement";
const PROCESS_CARD_REPLACEMENT = "Card Replacement";

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
const FIELD_INVITED_PHONE = "FEC_Invited_Phone__c";
const FIELD_ZALO_USED = "FEC_Zalo_Used__c";
const FIELD_DEBT_COLLECTION_PHONE = "FEC_Debt_Collection_Phone__c";
const FIELD_RECIPIENT_PHONE_NUMBER = "FEC_Recipient_Phone_Number__c";
const FIELD_UNBLOCK_PHONE = "FEC_Unblock_Phone__c";
const CUSTOMER_PHONE_NUMBER_SUB = "FEC_Customer_Phone_Number__c";
const FIELD_FEOL_Phone__c = "FEC_FEOL_Phone__c";
const PHONE_MASK_FIELD_APIS = new Set([
  FIELD_ORIGINAL_INFO_PHONE_NUMBER,
  FIELD_UPDATED_INFO_PHONE_NUMBER,
  FIELD_REGISTERED_PHONE_NUMBER,
  FIELD_CASE_PHONE_NUMBER,
  FIELD_INVITED_PHONE,
  FIELD_DEBT_COLLECTION_PHONE,
  FIELD_UNBLOCK_PHONE,
]);
/** Case: input tel + validateUpdatedInfoPhone + giới hạn độ dài (0/84). */
const PHONE_VALIDATED_FIELD_APIS = new Set([
  FIELD_UPDATED_INFO_PHONE_NUMBER,
  FIELD_REGISTERED_PHONE_NUMBER,
  FIELD_CASE_PHONE_NUMBER,
  FIELD_RECIPIENT_PHONE_NUMBER,
  FIELD_INVITED_PHONE,
  FIELD_DEBT_COLLECTION_PHONE,
  FIELD_UNBLOCK_PHONE,
  CUSTOMER_PHONE_NUMBER_SUB,
  FIELD_FEOL_Phone__c,
  FIELD_CUSTOMER_PHONE_NUMBER,
  FIELD_RECEIVING_PHONE_NUMBER
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
const FIELD_DUE_DATE = "FEC_Due_Date__c";
const FIELD_TRANSACTION_DATE = "FEC_Transaction_Date__c";
const FIELD_STATEMENT_DATE = "FEC_Statement_Date__c";
const FIELD_NEW_CITIZEN_ID_NUMBER = "FEC_New_Citizen_ID_Number__c";
const FIELD_OLD_CITIZEN_ID_NUMBER = "FEC_Old_Citizen_ID_Number__c";
const FIELD_ORIGINAL_INFO_NATIONAL_ID = "FEC_Original_Info_National_ID__c";
const FIELD_UPDATED_INFO_NATIONAL_ID = "FEC_Updated_Info_National_ID__c";
const FIELD_NATIONAL_ID_PASSPORT_ID = "FEC_National_ID_Passport_ID__c";
const FIELD_NATIONAL_ID = "FEC_National_ID__c";
const FIELD_FEOL_ID = "FEC_FEOL_ID__c";
const OBJ_FEC_ADDITIONAL_INFO = "FEC_Additional_Info__c";
const FIELD_FEC_REF_NUMBER = "FEC_REF_Number__c";
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
  FIELD_DUE_DATE,
  FIELD_TRANSACTION_DATE,
  FIELD_STATEMENT_DATE,
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
const FIELD_COMPLAIN_TYPE = "FEC_Complain_Type__c";
const FIELD_COMPLAINT_SOURCE = "FEC_Complaint_Source__c";
const VALUE_COMPLAINT_SOURCE = ['High risk', 'Urgent'];

const TYPE_QUALIFIED = "Qualified";
const TYPE_QUALIFIED_VN = "Hợp lệ";
const TYPE_UNQUALIFIED = "Unqualified";
const TYPE_AGREE = "Agree";
const TYPE_DISAGREE = "Disagree";

const DECISION_USER = "User";
const DECISION_QUEUE = "Queue";
const NONE_STRING = '--None--';
const FIELD_ACCOUNT_CONTRACT_NUMBER_PL = 'FEC_Account_Contract_Number_PL__c';
const LABEL_ACCOUNT_CONTRACT_NUMBER = 'Account/ Contract Number';

//linhdev fix section Account Info + Case Info
const SECTION_NAME_ACCOUNT_INFORMATION = 'Account Information';
const SECTION_NAME_CASE_INFORMATION = 'Case Information';
const SUBSECTION_NAME_PROPERTY_INFO = 'Property Info';
const SUBSECTION_NAME_C360_INFO = 'C360 Info';

//linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
function pointsRedemptionHideTargetForSection(sectionName, hide) {
  if (!hide) {
    return null;
  }
  if (sectionName === SECTION_NAME_ACCOUNT_INFORMATION) {
    return 'c360';
  }
  if (sectionName === SECTION_NAME_CASE_INFORMATION) {
    return 'property';
  }
  return null;
}

function shouldHidePointsRedemptionSubSection(sectionName, subName, hide) {
  if (!hide) {
    return false;
  }
  return (
    (sectionName === SECTION_NAME_ACCOUNT_INFORMATION && subName === SUBSECTION_NAME_C360_INFO) ||
    (sectionName === SECTION_NAME_CASE_INFORMATION && subName === SUBSECTION_NAME_PROPERTY_INFO)
  );
}

function shouldSkipPointsRedemptionLwcDynCmp(prHideTarget, dynSubKey) {
  if (!prHideTarget || !dynSubKey) {
    return false;
  }
  if (prHideTarget === 'c360') {
    return dynSubKey === normalizeSubSectionName(SUBSECTION_NAME_C360_INFO);
  }
  if (prHideTarget === 'property') {
    return dynSubKey === normalizeSubSectionName(SUBSECTION_NAME_PROPERTY_INFO);
  }
  return false;
}

//linhdev fix jira FECREDIT_CSM_2025_KH-1366 — reload sau Có/Không: getData với bộ NOC session (Case DB có thể chưa có Category/Sub)
function isFastCashNocSelectionComplete(sel) {
  return !!(sel && sel.productTypeId && sel.categoryId && sel.subCategoryId);
}

function readFastCashNocSelectionFromStorage(caseId) {
  try {
    if (!caseId) {
      return null;
    }
    if (sessionStorage.getItem(FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX + caseId) !== "1") {
      return null;
    }
    const raw = sessionStorage.getItem(FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX + caseId);
    if (!raw) {
      return null;
    }
    const sel = JSON.parse(raw);
    if (!isFastCashNocSelectionComplete(sel)) {
      return null;
    }
    return sel;
  } catch (e) {
    return null;
  }
}

//linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — reload sau Execute / refresh: getData với bộ NOC session (giống Fast Cash)
function isPointsRedemptionNocSelectionComplete(sel) {
  return !!(
    sel &&
    sel.productTypeId &&
    sel.categoryId &&
    sel.subCategoryId &&
    sel.subCodeId
  );
}

function readPointsRedemptionNocSelectionFromStorage(caseId) {
  try {
    if (!caseId) {
      return null;
    }
    const raw = sessionStorage.getItem(FEC_POINTS_REDEMPTION_STORAGE_NOC_SELECTION_PREFIX + caseId);
    if (!raw) {
      return null;
    }
    const sel = JSON.parse(raw);
    if (!isPointsRedemptionNocSelectionComplete(sel)) {
      return null;
    }
    return sel;
  } catch (e) {
    return null;
  }
}

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
const FIELD_LOAN_AMOUNT = 'FEC_Loan_Amount__c';
const FIELD_CURRENT_CARD_STATUS = 'FEC_Current_Card_Status__c';
const FIELD_RECIPIENT_NAME = 'FEC_Recipient_Name__c';
const FIELD_LAST_4_DIGIT = 'FEC_Last_4_Digits__c';

// Toannd61
import {
  CASE_RD_PAYMENT_CONTRACT_ASSESSMENT,
  FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT,
  isRdPaymentSubCode,
  setRdPaymentScopedStageTeamMap,
  getRdPaymentScopedStageTeam,
} from "c/fec_RdPaymentRoutingUtils";

const FIELD_CONTRACT_PROCESSING_ASSESSMENT_TYPE =
  'FEC_Contract_Processing_Assessment_Type__c';

/** Picklist Case persist trước submit / Scoped Route to (no-op nếu field không trên form). */
const CASE_SUBMIT_PICKLIST_FIELD_API_NAMES = [
  FIELD_CONTRACT_PROCESSING_ASSESSMENT_TYPE,
  FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT,
];

const FIELD_READ_ONLY_UPDATE = [
  FIELD_NEW_BLOCK_CODE,
  FIELD_NEW_BLOCK_CODE_CARD_REPLACE,
  FIELD_CARD_REPLACEMENT_FEE,
  FIELD_CURRENT_CARD_STATUS,
];

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
  fec_CardReplacementAddress: () => import('c/fec_CardReplacementAddress'),
  fec_IncorrectPaymentForm: () => import('c/fec_IncorrectPaymentForm'),
  fec_IPPConversionRetailForm: () => import('c/fec_IPPConversionRetailForm'),
  fec_MRC: () => import('c/fec_MRC'),
  fec_MrcReturnCaseForm: () => import('c/fec_MrcReturnCaseForm'),
  fec_MrcReturnPanel: () => import('c/fec_MrcReturnPanel'),
  fec_MrcDeliveryForm: () => import('c/fec_MrcDeliveryForm'),
  fec_RefundRequestForm: () => import('c/fec_RefundRequestForm'),
  fec_ContractClosureForm: () => import('c/fec_ContractClosureForm'),
  fec_BeneficiaryBankInfoBlock: () => import('c/fec_BeneficiaryBankInfoBlock'),
  fec_FastCashCaseForm: () => import('c/fec_FastCashCaseForm'),
  // DungLT — đăng ký LWC upload file động (master data)
  fec_FileUploadCard: () => import('c/fec_FileUploadCard'),
  fec_OriginalInformation: () => import('c/fec_OriginalInformation'),
  fec_PointsRedemptionCaseForm: () => import('c/fec_PointsRedemptionCaseForm'),
  fec_COFFraudRelatedView: () => import('c/fec_COFFraudRelatedView')
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

function normalizeSubSectionName(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim().toLowerCase();
}

/**
 * Gộp subsection (field) + LWC đã resolve — sort theo FEC_Sub_Section_Order__c (thứ tự DOM).
 */
function mergeSectionSortedRows(section) {
  const rows = [];
  let seq = 0;
  const fieldOrderBySubSectionName = new Map();

  (section.subSectionlst || []).forEach((sub, subIndex) => {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1294
    if (sub._hideForFastCash) {
      return;
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
    if (sub._hideForPointsRedemption) {
      return;
    }
    if (sub._hideForMrcRl05 || sub.hideForMrcRl05) {
      return;
    }
    const fecOrd = readFecSubSectionOrder(sub);
    const sortOrder =
      fecOrd !== undefined ? fecOrd : subIndex + 1;
    const subSectionNameKey = normalizeSubSectionName(sub?.name);
    if (
      subSectionNameKey &&
      !fieldOrderBySubSectionName.has(subSectionNameKey)
    ) {
      fieldOrderBySubSectionName.set(subSectionNameKey, sortOrder);
    }
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
    const dynSubKey = normalizeSubSectionName(dynCmp?.subSectionName);
    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394 — RC33.01–03: ẩn LWC C360 / Property
    if (shouldSkipPointsRedemptionLwcDynCmp(section._pointsRedemptionHideTarget, dynSubKey)) {
      return;
    }
    if (dynCmp._hideForMrcRl05) {
      return;
    }
    const fecOrd = readFecSubSectionOrder(dynCmp);
    const subSectionNameKey = normalizeSubSectionName(dynCmp?.subSectionName);
    const matchedFieldOrder = subSectionNameKey
      ? fieldOrderBySubSectionName.get(subSectionNameKey)
      : undefined;
    const sortOrder =
      fecOrd !== undefined
        ? fecOrd
        : matchedFieldOrder !== undefined
          ? matchedFieldOrder
          : maxFieldOrder + 1 + idx;
    const showLwcSubHeading =
      Boolean(dynCmp?.subSectionName) && matchedFieldOrder === undefined;
    rows.push({
      rowKey: dynCmp.key || `fec-${section.id}-lwc-${idx}`,
      isFields: false,
      isLwc: true,
      sortOrder,
      outerClass: dynCmp.lwcColClassName,
      showLwcSubHeading:
        Boolean(dynCmp?.subSectionName) &&
        dynCmp?.hideSubSectionHeading !== true,
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
    hideSubSectionHeading: o.hideSubSectionHeading === true,
    isCollapsible: o.isCollapsible === true,
  };
}

export default class Fec_CaseBussiness extends NavigationMixin(LightningElement) {

  @api recordId;

  _isEdit = true;
  @api get isEdit() {
    return this._isEdit;
  }
  set isEdit(value) {
    const prev = this._isEdit;
    this._isEdit = value === true || value === "true";
    console.log(`[DEBUG][fec_CaseBussiness] set isEdit — rawValue=${JSON.stringify(value)} (type=${typeof value}), _isEdit=${this._isEdit}, prev=${prev}, businessReady=${!!this.business?.sectionlst}`);
    if (prev !== this._isEdit && this.business?.sectionlst) {
      this._applyEditModeToBusiness();
    }
  }

  @track business = {};

  isLoaded = true;

  businessLoaded = false;

  /** Auto Hold Case — hiển thị trong accordion Case Information. */
  holdCaseNocParams = { recordId: null };
  wiredCaseHoldResultWire;
  // wiredHoldCaseSubProcessesWire;
  holdCaseResultOnCase = false;
  holdCaseResultOverride = null;
  showHoldCase = false;
  showHoldCaseManual = false;
  showHoldCaseAuto = false;

  //linhdev: Fix jira FECREDIT_CSM_2025_KH-1226 — tách active name theo từng lightning-accordion
  // (tránh trộn "routing-action" với UUID section: active-section-name có tên lạ có thể làm co section).
  @track activeMainSectionlst = [];
  @track activeRoutingSectionlst = [];

  routingAccordionSectionKey = "routing-action";
  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  _documentRequestStageChangeRoutingActive = false;
  _documentRequestDeliveryEligible = false;
  _mrcReturnStageChangeRoutingActive = false;
  _mrcDeliveryOptionDraft = STR_EMPTY;

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  static DOC_REQ_FIELD_DELIVERY = "FEC_Delivery_Option_2__c";
  static DOC_REQ_FIELD_DOCUMENT_TYPE = "FEC_Document_Type__c";

  @track addressUpdateClickCount = 0;
  @track addressUpdateFailCount = 0;

  _ippClosureHasEligibleRows = false;

  //linhdev fix jira FECREDIT_CSM_2025_KH-1294
  _hidePropertyInfoForFastCash = false;

  //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
  _hideC360AndPropertyForPointsRedemption = false;

  // get eyeIcon() {
  //   return this.isMasked ? "utility:preview" : "utility:hide";
  // }
  updateDecision;
  @track decisionValue = STR_EMPTY;
  @track subDecisionValue = STR_EMPTY;
  @track subDecisionOptions = [];

  userGroup;
  newBlockCode;
  currentBlockCode;
  currentCardStatus;
  cardReplacementReason;
  newBlockCodeCardReplace;
  cardReplacementFee;
  last4Digit;
  isHiddenLwc = false;
  currentStageName;

  @wire(getRecord, { recordId: USER_ID, fields: [USER_GROUP_FIELD] })
  wiredUser({ error, data }) {
    if (data) {
      this.userGroup = getFieldValue(data, USER_GROUP_FIELD);
    } else if (error) {
      console.error("Error fetching user group", error);
    }
  }

  // PhuongNT add get Case data
  @wire(getRecord, { recordId: '$recordId', fields: [STAGE_NAME_FIELD] })
  wiredCase({ error, data }) {
    if (data) {
      this.currentStageName = getFieldValue(data, STAGE_NAME_FIELD);
    } else if (error) {
      console.error("Get Case record error:", error);
    }
  }

  get isStage1() {
    return (this.currentStageName || '').includes('Stage 1');
  }

  @wire(MessageContext)
  messageContext;

  @wire(getRecord, { recordId: "$recordId", fields: [FEC_NFU_DESCRIPTION_RESULT] })
  wiredCaseHoldResult(result) {
    this.wiredCaseHoldResultWire = result;
    const resultVal = getFieldValue(result.data, FEC_NFU_DESCRIPTION_RESULT);
    this.holdCaseResultOnCase = !!resultVal;
    if (resultVal) {
      this.showHoldCase = true;
      this.showHoldCaseAuto = true;
      if (!this.holdCaseResultOverride) {
        this.holdCaseResultOverride = resultVal;
      }
      this._ensureCaseInformationHoldCaseFlags();
      this.business = { ...this.business };
    } else if (result.error) {
      console.error("[fec_CaseBussiness] wiredCaseHoldResult error", result.error);
    }
  }

  @wire(getSubProcesses, {
    recordId: "$recordId",
    productTypeId: "$holdCaseNocParams.productTypeId",
    categoryId: "$holdCaseNocParams.categoryId",
    subCategoryId: "$holdCaseNocParams.subCategoryId",
    subCodeId: "$holdCaseNocParams.subCodeId",
  })
  wiredHoldCaseSubProcesses({ data, error }) {
    if (data) {
      this.showHoldCase = !!data.showHoldCase || this.holdCaseResultOnCase;
      this.showHoldCaseManual = !!data.showHoldCaseManual;
      if (!this.holdCaseResultOnCase) {
        this.showHoldCaseAuto = !!data.showHoldCaseAuto;
      }
    }
    if (error) {
      console.error("[fec_CaseBussiness] hold case subprocess wire error", error);
    }
  }

  // _applyHoldCaseSubProcessWireData(data) {
  //   this.showHoldCase = !!data.showHoldCase || this.holdCaseResultOnCase;
  //   this.showHoldCaseManual = !!data.showHoldCaseManual;
  //   if (!this.holdCaseResultOnCase) {
  //     this.showHoldCaseAuto = !!data.showHoldCaseAuto;
  //   }
  // }

  get showHoldCaseSection() {
    return (
      this.showHoldCaseAuto ||
      this.showHoldCaseManual ||
      this.holdCaseResultOnCase ||
      !!this.holdCaseResultOverride
    );
  }

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

  /** Mỗi Case một key — tránh tab Case khác ghi đè / xóa draft khi đổi tab Console. */
  get draftStorageKey() {
    return this.recordId ? `fec_case_business_draft_${this.recordId}` : "fec_case_business_draft";
  }

  //PhongBT 19/05/26: Fix mr chuyển routing action của document request sang lwc con
  handleDocReqRoutingFieldChange(event) {
    const { fieldName, value } = event.detail || {};
    this.handleChange({
      target: { name: fieldName },
      detail: { value },
    });
  }

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
    updateRoutingActionDisplayApex({
      caseId: this.recordId,
      routingActionDisplay: field
    })
      .then(() => {
        console.log("Record updated successfully");
      })
      .catch((error) => {
        console.error("Error updating record:", error);
      });
  }

  /** Khi load màn: đồng bộ hiển thị nút process theo CS Support đánh giá (không gán Action Routing). */
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
  }

  // Toannd61 — load assessment → FEC_Team_User_Group__c filter map từ Apex (không hardcode Team/Queue UI)
  _fetchRdPaymentQueues() {
    return getRoutingConfig()
      .then((result) => {
        setRdPaymentScopedStageTeamMap(result?.scopedStageTeamByAssessment);
        console.log(
          "[RD-Payment-Scoped] _fetchRdPaymentQueues",
          JSON.stringify({
            scopedStageTeamByAssessment: result?.scopedStageTeamByAssessment,
          }),
        );
      })
      .catch((err) => {
        console.error("_fetchRdPaymentQueues error:", JSON.stringify(err));
      });
  }

  /** Áp dụng routing (Team/Queue + action) dựa trên giá trị đã lưu của FEC_RD_Payment_Contract_Assessment__c khi load form. */
  _applyRdPaymentContractAssessmentRouting() {
    if (!this.isEdit) return;
    const assessmentVal = this._getCaseFieldValue(FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT);
    if (!assessmentVal || assessmentVal === STR_EMPTY) {
      return;
    }
    // Nếu filter map chưa load xong, fetch lại rồi mới apply
    if (!getRdPaymentScopedStageTeam(assessmentVal, this.business?.picklistOptionsMap?.Case?.[FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT])) {
      this._fetchRdPaymentQueues().then(() => {
        this._applyRdPaymentRoutingByAssessment(assessmentVal);
      });
    } else {
      this._applyRdPaymentRoutingByAssessment(assessmentVal);
    }
  }

  /**
   * Tự động set Team và Queue theo giá trị FEC_RD_Payment_Contract_Assessment__c.
   * Mapping được lấy từ Apex (không hardcode trong LWC).
   */
  async _applyRdPaymentRoutingByAssessment(assessmentVal) {
    console.log(
      "[RD-Payment-Scoped] _applyRdPaymentRoutingByAssessment",
      JSON.stringify({
        assessmentVal,
        isScopedStage2: shouldPreferScopedRoutingFromStage2(this),
        subCode: this.business?.subCodeCode,
        stageName: this.business?.stageName,
        scopedTeamFilterLoaded: !!getRdPaymentScopedStageTeam(
          assessmentVal,
          this.business?.picklistOptionsMap?.Case?.[FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT],
        ),
        lockRouteTo: this.rdPaymentScopedRouteToLocked,
      }),
    );
    await this._fetchRdPaymentQueues();
    const applied = await applyRdPaymentStageChangeRoutingFromAssessment(
      this,
      assessmentVal,
    );
    console.log("[RD-Payment-Scoped] _applyRdPaymentRoutingByAssessment:result", {
      applied,
      nextTeam: this.business?.nextTeam,
      nextQueue: this.business?.nextQueue,
      actionCode: this._getCurrentActionCode?.(),
    });
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

  // Toannd61 — assessment → team filter map từ Apex (SCOPED_STAGE_TEAM_BY_ASSESSMENT)

  get _isRdPaymentSubCode() {
    return isRdPaymentSubCode(this.business?.subCodeCode);
  }

  get isRoutingActionDisabled() {
    return !this._isEdit;
  }

  get showRouteTo() {
    if (
      this._documentRequestStageChangeRoutingActive &&
      !this._documentRequestDeliveryEligible
    ) {
      return false;
    }
    return ACTION_ROUTE_TO === this._getCurrentActionCode();
  }

  //Thangtv
  // Hiển thị Queue ổn định cho Route To (hỗ trợ cả string và object {label,value})
  get routeToQueueDisplayLabel() {
    const queue = this.business?.nextQueue;
    if (!queue) {
      return this.business?.nextQueueLabel || STR_EMPTY;
    }
    if (typeof queue === "string") {
      return queue;
    }
    if (typeof queue === "object") {
      return (
        queue.label ||
        queue.name ||
        queue.developerName ||
        queue.value ||
        this.business?.nextQueueLabel ||
        STR_EMPTY
      );
    }
    return STR_EMPTY;
  }

  // tungnm37 thêm: true khi NOC thuộc COF/GSR → dùng fec_RoutingAssignment thay thế Team/Queue cũ
  get isRoutingAssignmentMode() {
    const code = this.business?.code;
    return typeof code === 'string' && (code.startsWith('COF') || code.startsWith('GSR'));
  }

  // tungnm37 thêm: số lượng routing assignments để quyết định class container
  _routingAssignmentCount = 1;

  // tungnm37 thêm: class container cho routing assignment
  get routingAssignmentContainerClass() {
    if (this.isRoutingAssignmentMode) {
      // tungnm37: Stage 2 (isSubmited) → full width cho form Add Item
      // Stage 1, 1 record → 6-of-12 bên phải; Stage 1, nhiều record → full width
      if (this.business?.isSubmited) return 'route-to-info slds-col slds-size_1-of-1';
      return this._routingAssignmentCount === 1
        ? 'route-to-info slds-col slds-size_1-of-1 slds-medium-size_6-of-12'
        : 'route-to-info slds-col slds-size_1-of-1';
    }
    return 'route-to-info slds-col slds-size_1-of-1 slds-medium-size_6-of-12';
  }

  // tungnm37 thêm: nhận event từ fec_RoutingAssignment khi có data
  handleAssignmentsLoaded(event) {
    this._routingAssignmentCount = event.detail.count || 1;
  }

  // tungnm37 thêm: track manual items từ fec_RoutingAssignment (Stage 2)
  _manualItems = [];
  //PhongBT 18/05/26: fix Document Request
  /** Chặn gen PDF trùng khi đang tạo file. */
  _pdfGenerateInFlight = false;
  // tungnm37 thêm: remarkContent từ parent để truyền vào Apex khi submit COF/GSR
  @api remarkContent = '';
  handleManualItemsChange(event) {
    this._manualItems = event.detail?.items || [];
  }

  // tungnm37 thêm: hiển thị lỗi khi chọn Queue trùng
  handleDuplicateQueue(event) {
    const msg = event.detail?.message || FEC_Duplicate_Queue_Error;
    this.dispatchEvent(new ShowToastEvent({
      title: FEC_Error_Title,
      message: msg,
      variant: 'error'
    }));
  }

  // tungnm37 thêm: xử lý nút Add Item (Manual Assignment cho CC/SP)
  handleAddItem() {
    // TODO: mở modal hoặc form để user nhập Assignment thủ công
    // Hiện tại fire event để component cha xử lý nếu cần
    this.dispatchEvent(new CustomEvent('additem', { detail: { caseId: this.recordId } }));
  }
  //Toannd61: resolve method theo Action.code (FEC_Code__c), không theo value custom label — khớp run() REVERT/ROUTE_TO

  //Thangtv
  // Hiển thị Queue ổn định cho Route To (hỗ trợ cả string và object {label,value})
  get routeToQueueDisplayLabel() {
    const queue = this.business?.nextQueue;
    if (!queue) {
      return this.business?.nextQueueLabel || STR_EMPTY;
    }
    if (typeof queue === "string") {
      return queue;
    }
    if (typeof queue === "object") {
      return (
        queue.label ||
        queue.name ||
        queue.developerName ||
        queue.value ||
        this.business?.nextQueueLabel ||
        STR_EMPTY
      );
    }
    return STR_EMPTY;
  }
  _resolveRoutingMethodByAction(action) {
    const customActionLabel = action?.label?.trim();
    const KNOWN_ROUTING_METHODS = [
      ACTION_ROUTE_TO,
      ACTION_REVERT,
      ACTION_TRANSFER,
      ACTION_UPDATE,
      ACTION_ESCALATE,
      ACTION_REJECT,
      ACTION_RESOLVE,
      ACTION_CANCEL,
    ];
    // lightning-select value = Apex Action.value = custom label nếu có (vd "Route to"),
    // trong khi Action.code luôn là FEC_Code__c ("Revert", "Route to", ...).
    // Query Stage Change / run() phải theo code (nút thật), không theo label hiển thị.
    const codeRaw = action?.code != null ? String(action.code).trim() : "";
    const valueRaw = action?.value != null ? String(action.value).trim() : "";
    let resolvedMethod;
    if (codeRaw && KNOWN_ROUTING_METHODS.includes(codeRaw)) {
      resolvedMethod = codeRaw;
    } else if (valueRaw && KNOWN_ROUTING_METHODS.includes(valueRaw)) {
      resolvedMethod = valueRaw;
    } else {
      resolvedMethod = valueRaw || codeRaw;
    }
    console.log(
      "FEC_DEBUG _resolveRoutingMethodByAction",
      JSON.stringify({
        actionId: action?.id,
        actionValue: action?.value,
        actionCode: action?.code,
        actionLabel: action?.label,
        customActionLabel,
        resolvedMethod,
      }),
    );
    return resolvedMethod;
  }

  get showRevert() {
    // Ưu tiên code thật của action: code='Revert' luôn hiển thị decision logic của Revert
    // kể cả khi custom label/value hiển thị là "Route to".
    return ACTION_REVERT === this._getCurrentActionCode();
  }

  //thangtv
  get revertDecisionDisplayLabel() {
    const action = this._findRoutingActionByValueOrCode(this.actionValue);
    const isRouteToLabelOnRevertCode =
      action?.code === ACTION_REVERT && action?.value === ACTION_ROUTE_TO;
    if (isRouteToLabelOnRevertCode) {
      return this.business?.lastUserForRouteToLabel || this.business?.lastUser || STR_EMPTY;
    }
    return this.business?.lastUser || STR_EMPTY;
  }

  get showTransfer() {
    return ACTION_TRANSFER === this._getCurrentActionCode();
  }

  get showUpdate() {
    return ACTION_UPDATE === this._getCurrentActionCode();
  }

  processActionMethod;

  processActionMsg;
  isProcessActionSuccessed = false;
  isProcessActionFailed = false;
  isProcessActionInfo = false;

  showProcessAction = false;
  isProcessActionValid = true;
  mrcReturnHandlingOptionValue = STR_EMPTY;

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
    chooseSubDecisionLabel: FEC_Choose_Sub_Decision_Label,
    addItemLabel: FEC_Add_Item_Label,
    assignmentRemarkLabel: FEC_Assignment_Remark_Label,
    confirmLabel: FEC_Confirm_Label,
  }

  get showMrcRl0502DupBanner() {
    return showMrcRl0502DupBanner(this.business);
  }

  get mrcReturnCustomerConfirmationValue() {
    const draft = this.business?.mrcCustomerConfirmationDraft;
    if (typeof draft === "string" && draft.trim()) {
      return draft.trim();
    }
    const saved = this.business?.mrcCustomerConfirmationSaved;
    if (typeof saved === "string" && saved.trim()) {
      return saved.trim();
    }
    return getCaseFieldValue(this.business, FIELD_MRC_CUSTOMER_CONFIRMATION);
  }

  get mrcCustomerConfirmationOptions() {
    return this.business?.picklistOptionsMap?.Case?.[
      FIELD_MRC_CUSTOMER_CONFIRMATION
    ];
  }

  get mrcHandlingOptionOptions() {
    return this.business?.picklistOptionsMap?.Case?.[
      FIELD_MRC_HANDLING_OPTION
    ];
  }

  handleMrcReturnCustomerConfirmationChange(event) {
    const value = event.detail?.value ?? STR_EMPTY;
    let fieldUpdated = false;
    this.business?.sectionlst?.forEach((section) => {
      section.subSectionlst?.forEach((sub) => {
        sub.objlst?.forEach((obj) => {
          if (obj.name !== "Case") {
            return;
          }
          const field = obj.fieldlst?.find(
            (f) => f.apiName === FIELD_MRC_CUSTOMER_CONFIRMATION,
          );
          if (field) {
            field.value = value;
            fieldUpdated = true;
          }
        });
      });
    });
    if (!fieldUpdated && this.business) {
      this.business.mrcCustomerConfirmationDraft = value;
    }
    this._syncMrcReturnFieldsToRecordForm();
    this._applyMrcReturnCaseIntegration();
    this.business = { ...this.business };
  }

  _syncMrcDeliveryDraftFromCase() {
    if (!isMrcRl05Branch(this.business)) {
      return;
    }
    const saved = this._getCaseFieldValue(Fec_CaseBussiness.DOC_REQ_FIELD_DELIVERY);
    if (saved && !String(this._mrcDeliveryOptionDraft ?? STR_EMPTY).trim()) {
      this._mrcDeliveryOptionDraft = saved;
    }
  }

  handleMrcReturnHandlingOptionChange(event) {
    const detail = event.detail || {};
    const value = detail.value ?? STR_EMPTY;
    this.mrcReturnHandlingOptionValue = value;

    const hiddenFields = this.template.querySelectorAll(
      `[data-field="${FIELD_MRC_HANDLING_OPTION}"]`,
    );
    hiddenFields?.forEach((field) => {
      field.value = value;
    });

    this.handleChangeInput({
      currentTarget: {
        dataset: {
          section: detail.sectionId,
          sub: detail.subSectionName,
          obj: detail.objId,
          objName: "Case",
          field: FIELD_MRC_HANDLING_OPTION,
        },
        fieldName: FIELD_MRC_HANDLING_OPTION,
      },
      detail: { value },
    });
    this._syncMrcReturnFieldsToRecordForm();
    this._applyMrcReturnCaseIntegration();
    this.business = { ...this.business };
  }

  _applyMrcReturnCaseIntegration() {
    if (
      !this.business?.sectionlst ||
      !isMrcRl05Branch(this.business) ||
      isMrcRl05CaseInformationBlocked(this.business)
    ) {
      return;
    }
    const result = applyMrcRl0502DupFieldLayout(
      this.business,
      this.mrcReturnHandlingOptionValue,
      this.mrcReturnCustomerConfirmationValue,
    );
    this.mrcReturnHandlingOptionValue = result.handlingOptionValue;
    this.business = result.business;
    if (result.rebuildSections) {
      this._rebuildAllSectionSortedRows();
    }
    const actionCode = getMrcReturnAutoRoutingActionCode(
      this.business,
      this.isEdit,
      this.mrcReturnCustomerConfirmationValue,
    );
    if (actionCode) {
      this._setActionValueByCode(actionCode);
      this.business = { ...this.business };
    }
    this._loadMrcReturnStageChangeRouting().then(() => {
      this._syncActiveRoutingSection();
      this._syncDocumentRequestRoutingActionSelection();
    });
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

  @api async checkSubmitBlock() {
    const noUpdate = checkNoUpdateInSubmit(
      this._getCaseFieldOriginalValue.bind(this),
      this._getCaseFieldValue.bind(this),
      this._getCheckNoUpdateInSubmitOptions(),
    );
    const cmp = this._getFecUpdateAddressCmp();
    const hasAddressUpdate = cmp && typeof cmp.hasPendingAddressUpdates === 'function' && cmp.hasPendingAddressUpdates();
    const hasSubmitPicklistChange = this.hasAnySubmitCasePicklistFieldChanged();

    if (noUpdate && !hasAddressUpdate && !hasSubmitPicklistChange) {
      this.showToast(FEC_Warning_Title, FEC_MSG_UPDATED_INFO_NOT_UPDATED, "warning");
      return true;
    }
    return false;
  }

  _findCaseFieldByApiName(apiName) {
    if (!this.business?.sectionlst) {
      return null;
    }
    for (const section of this.business.sectionlst) {
      for (const sub of section.subSectionlst ?? []) {
        for (const obj of sub.objlst ?? []) {
          if (obj.name !== 'Case') continue;
          const field = obj.fieldlst?.find(
            (f) => f.apiName === apiName && f.isHidden !== true,
          );
          if (field) {
            return field;
          }
        }
      }
    }
    return null;
  }

  _casePicklistOptions(fieldApiName) {
    return this.business?.picklistOptionsMap?.Case?.[fieldApiName] ?? [];
  }

  /** Label hoặc API value → API value (lưu Case). */
  _casePicklistRawToApi(fieldApiName, raw) {
    if (raw == null || String(raw).trim() === STR_EMPTY) {
      return null;
    }
    let val = String(raw).trim();
    const options = this._casePicklistOptions(fieldApiName);
    if (options.length) {
      const found = findPicklistOptionByRaw(options, val);
      if (found) {
        val = found.value;
      }
    }
    return val;
  }

  _syncCasePicklistValueFromForm(fieldApiName) {
    if (!this.isEdit) {
      return;
    }
    const field = this._findCaseFieldByApiName(fieldApiName);
    if (!field) {
      return;
    }
    const els = this.template.querySelectorAll(
      `lightning-input-field[data-field="${fieldApiName}"]`,
    );
    for (const el of els) {
      if (el?.value != null && String(el.value).trim() !== STR_EMPTY) {
        field.value = el.value;
        return;
      }
    }
  }

  _applyPersistedCasePicklistField(field, fieldApiName, apiVal) {
    field.original = apiVal;
    field.value = apiVal;
    const options = this._casePicklistOptions(fieldApiName);
    if (options.length) {
      const opt = findPicklistOptionByRaw(options, apiVal);
      if (opt) {
        field.displayValue = opt.label;
        field.readonlyDisplayValue = opt.label;
      }
    }
  }

  hasCasePicklistFieldChanged(fieldApiName) {
    if (!this._findCaseFieldByApiName(fieldApiName)) {
      return false;
    }
    this._syncCasePicklistValueFromForm(fieldApiName);
    const field = this._findCaseFieldByApiName(fieldApiName);
    const apiVal = this._casePicklistRawToApi(fieldApiName, field.value);
    const originalApi =
      this._casePicklistRawToApi(fieldApiName, field.original) ?? STR_EMPTY;
    const next = apiVal == null ? STR_EMPTY : String(apiVal).trim();
    return originalApi !== next;
  }

  async _persistCasePicklistField(fieldApiName) {
    const field = this._findCaseFieldByApiName(fieldApiName);
    if (!field || !this.recordId) {
      return { success: true };
    }
    this._syncCasePicklistValueFromForm(fieldApiName);
    const apiVal = this._casePicklistRawToApi(fieldApiName, field.value);
    if (apiVal == null) {
      return { success: true };
    }
    const originalApi =
      this._casePicklistRawToApi(fieldApiName, field.original) ?? STR_EMPTY;
    if (originalApi === String(apiVal).trim()) {
      return { success: true };
    }
    try {
      await updateRecord({
        fields: {
          [ID_FIELD.fieldApiName]: this.recordId,
          [fieldApiName]: apiVal,
        },
      });
      this._applyPersistedCasePicklistField(field, fieldApiName, apiVal);
      this.business = { ...this.business };
      return { success: true };
    } catch (error) {
      console.error(
        `[fec_CaseBussiness] _persistCasePicklistField ${fieldApiName}`,
        error,
      );
      return {
        success: false,
        errorMessage:
          error?.body?.message || error?.message || FEC_Error_Title,
      };
    }
  }

  hasAnySubmitCasePicklistFieldChanged() {
    return CASE_SUBMIT_PICKLIST_FIELD_API_NAMES.some((apiName) =>
      this.hasCasePicklistFieldChanged(apiName),
    );
  }

  /** @api — Scoped Route to / submit: lưu các picklist assessment nếu đổi. */
  @api async persistSubmitCasePicklistFieldsBeforeSubmit() {
    for (const apiName of CASE_SUBMIT_PICKLIST_FIELD_API_NAMES) {
      const res = await this._persistCasePicklistField(apiName);
      if (res?.success === false) {
        return res;
      }
    }
    return { success: true };
  }

  hasContractProcessingAssessmentTypeChanged() {
    return this.hasCasePicklistFieldChanged(
      FIELD_CONTRACT_PROCESSING_ASSESSMENT_TYPE,
    );
  }

  /** Scoped Route to Stage 2+ */
  async persistContractProcessingAssessmentTypeBeforeScopedRouteTo() {
    return this._persistCasePicklistField(
      FIELD_CONTRACT_PROCESSING_ASSESSMENT_TYPE,
    );
  }

  hasRdPaymentContractAssessmentChanged() {
    return this.hasCasePicklistFieldChanged(
      FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT,
    );
  }

  async persistRdPaymentContractAssessmentBeforeSubmit() {
    return this._persistCasePicklistField(FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT);
  }

  /** COF Stage 1 sau Revert, hoặc GSR Stage 1 revert (trừ Stage 2 → Stage 1): master data read-only. */
  _isStage1RevertMasterReadonly() {
    const flags = this.business?.contextFlags;
    const gsrReadonly =
      flags?.isGsrStage1RevertMasterReadonly === true ||
      (flags?.isGsrStage1Revert === true &&
        flags?.isGsrStage2ToStage1Revert !== true);
    return flags?.isCOFStage1Revert === true || gsrReadonly;
  }

  /** GSR Stage 3 (đã có Assignment): subsection Property Info read-only. */
  _isGsrStage3PropertyInfoFieldReadonly(subSectionName) {
    return (
      this.business?.contextFlags?.isGsrStage3PropertyInfoReadonly === true &&
      subSectionName === SUBSECTION_NAME_PROPERTY_INFO
    );
  }

  /** Chỉ hiện section Routing khi thực sự có option (tránh dropdown trống RL04.02/03). */
  _syncHasRoutingAction() {
    if (!this.business) {
      return;
    }
    const hasOptions =
      Array.isArray(this.business.routingActionlst) &&
      this.business.routingActionlst.length > 0;
    const isCofGsr =
      typeof this.business.code === "string" &&
      (this.business.code.startsWith("COF") ||
        this.business.code.startsWith("GSR"));
    const docReqRoutingCtx = getDocumentRequestRoutingContext(
      this.business,
      this._documentRequestRoutingFieldOverrides(),
    );
    this.business.hasRoutingAction =
      isCofGsr ||
      hasOptions ||
      docReqRoutingCtx.subCodeSupported ||
      (shouldActivateMrcReturnRouting(this.business) &&
        !isMrcRl05CaseInformationBlocked(this.business));
    this.business = { ...this.business };
  }

  /**
   * Cập nhật readonly/editable cho toàn bộ field khi isEdit đổi.
   * Không gọi Apex, chỉ sửa dữ liệu đã có trong memory.
   */
  _applyEditModeToBusiness() {
    if (!this.business?.sectionlst) return;
    const stage1RevertReadonly = this._isStage1RevertMasterReadonly();
    this.business.sectionlst.forEach((section) => {
      section.subSectionlst?.forEach((sub) => {
        const gsrPropertyInfoReadonly = this._isGsrStage3PropertyInfoFieldReadonly(
          sub.name
        );
        sub.objlst?.forEach((obj) => {
          obj.fieldlst?.forEach((field) => {
            const forceReadonly = stage1RevertReadonly || gsrPropertyInfoReadonly;
            field.readonly = forceReadonly ? true : !this._isEdit;
            field.editable = forceReadonly ? false : this._isEdit;
          });
        });
      });
    });
    this._syncHasRoutingAction();
  }

  _isRl0402OrRl0403SubCode() {
    const code = this.business?.subCodeCode;
    return code === SUB_CODE_RL0402 || code === SUB_CODE_RL0403;
  }

  _hasDocumentRequestPaperValidationError() {
    return !!this.business?.sectionlst?.some(
      (section) =>
        section.name === SECTION_NAME_CASE_INFORMATION &&
        (section.hasError || section.error?.label),
    );
  }

  /**
   * RL04.02/RL04.03 — bổ sung routing actions riêng khi không đủ điều kiện phát hành giấy
   * (getByCase có thể trả routingActionlst rỗng).
   */
  async _supplementRl0402Rl0403RoutingActionsIfNeeded() {
    if (!this._isRl0402OrRl0403SubCode()) {
      return;
    }
    const hasOptions = (this.business?.routingActionlst?.length ?? 0) > 0;
    if (!hasOptions || this._hasDocumentRequestPaperValidationError()) {
      try {
        const actions = await getRoutingActionsForRl0402Rl0403({
          caseId: this.recordId,
        });
        if (Array.isArray(actions) && actions.length > 0) {
          this.business = { ...this.business, routingActionlst: actions };
          this._syncHasRoutingAction();
          if (!this.actionValue) {
            this.actionValue = actions[0]?.value;
          }
        }
      } catch (err) {
        console.error(
          "[RL04 routing supplement]",
          JSON.stringify(err),
        );
      }
    }
  }

  /** RL05 — bổ sung routing actions khi Stage Screen chưa trả option (Stage 1 / template). */
  async _supplementMrcRl05RoutingActionsIfNeeded() {
    if (
      !isMrcRl05Branch(this.business) ||
      !shouldActivateMrcReturnRouting(this.business) ||
      isMrcRl05CaseInformationBlocked(this.business)
    ) {
      return;
    }
    if ((this.business?.routingActionlst?.length ?? 0) > 0) {
      return;
    }
    try {
      const actions = await getRoutingActionsForMrcRl05({
        caseId: this.recordId,
      });
      if (Array.isArray(actions) && actions.length > 0) {
        this.business = { ...this.business, routingActionlst: actions };
        this._syncHasRoutingAction();
        if (!this.actionValue) {
          this.actionValue = actions[0]?.value;
        }
      }
    } catch (err) {
      console.error("[MRC RL05 routing supplement]", JSON.stringify(err));
    }
  }

  /** Đồng bộ action sau khi section Document Request / MRC Return routing mount. */
  _syncDocumentRequestRoutingActionSelection() {
    const stage1AutoRouteActive =
      this._documentRequestStageChangeRoutingActive ||
      this._mrcReturnStageChangeRoutingActive;
    if (
      !stage1AutoRouteActive ||
      !this.isEdit ||
      !(this.business?.routingActionlst?.length > 0)
    ) {
      return;
    }

    const actions = this.business.routingActionlst;
    const hasAction = (code) =>
      actions.some((a) => (a.code || a.value) === code);

    if (
      this._documentRequestStageChangeRoutingActive &&
      this._hasDocumentRequestPaperValidationError() &&
      hasAction(ACTION_REJECT)
    ) {
      this._setActionValueByCode(ACTION_REJECT);
      return;
    }

    if (
      this._documentRequestStageChangeRoutingActive &&
      !this._documentRequestDeliveryEligible &&
      this._getCurrentActionCode() === ACTION_ROUTE_TO
    ) {
      const fallback = actions.find(
        (a) => (a.code || a.value) !== ACTION_ROUTE_TO,
      );
      if (fallback?.value) {
        this.actionValue = fallback.value;
        const el = this._getRoutingActionSelectEl();
        if (el) {
          el.value = fallback.value;
        }
      }
      return;
    }

    if (
      this._mrcReturnStageChangeRoutingActive &&
      !this.business?.mrcRl05CaseInfoWarningOnly &&
      this._hasMrcBlockingCaseInformationError() &&
      hasAction(ACTION_REJECT)
    ) {
      this._setActionValueByCode(ACTION_REJECT);
      return;
    }

    if (this._mrcReturnStageChangeRoutingActive) {
      const ctx = getMrcReturnRoutingContext(
        this.business,
        this.mrcReturnHandlingOptionValue,
        this.mrcReturnCustomerConfirmationValue,
        this._mrcDeliveryOptionDraft,
      );
      if (ctx.eligible && hasAction(ACTION_ROUTE_TO)) {
        this._setActionValueByCode(ACTION_ROUTE_TO);
        return;
      }
    }

    if (this.actionValue) {
      const el = this._getRoutingActionSelectEl();
      if (el) {
        el.value = this.actionValue;
      }
    }
  }

  _hasMrcBlockingCaseInformationError() {
    return isMrcRl05CaseInformationBlocked(this.business);
  }

  //linhdev: Fix jira FECREDIT_CSM_2025_KH-1162
  _resolveDynCmpMasterIsEdit(componentName, fecMasterDataSettingIsEdit) {
    const master =
      typeof fecMasterDataSettingIsEdit === "boolean" ? fecMasterDataSettingIsEdit : true;
    if (this._isStage1RevertMasterReadonly()) {
      return false;
    }
    if (
      this.business?.lockApiLwcsAfterRevertToDefaultStage === true &&
      (componentName === "fec_IPPConversionRetailForm" ||
        componentName === "fec_CardClosureRefundForm" ||
        componentName === "fec_RemovePhoneForm")
    ) {
      return false;
    }
    return master;
  }

  _updateDynCmpIsEditFlags() {
    if (!this.business?.sectionlst) return;
    this.business.sectionlst.forEach((section) => {
      section.resolvedComponentlst?.forEach((d) => {
        if (!d) return;
        const master = this._resolveDynCmpMasterIsEdit(
          d.componentName,
          d.fecMasterDataSettingIsEdit,
        );
        d.isEdit = this._isEdit && master;
        console.log(`[DEBUG][fec_CaseBussiness] _updateDynCmpIsEditFlags — component="${d.componentName}", _isEdit=${this._isEdit}, master=${master}, finalIsEdit=${d.isEdit}`);
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
    // [NOC-HANDLING-STAGE-UPDATE]: Subscribe CASE_NOC channel để nhận NOC update từ fec_CaseEditNOC
    // Phân biệt 2 loại message: có 'accountType' (existing) vs có 'subCodeId' (NOC update mới)
    this._subscriptionCaseNOC = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this._handleCaseNOCMessage(message),
      { scope: APPLICATION_SCOPE }
    );
    this.holdCaseNocParams = { recordId: this.recordId };
    this._boundCheckHoldCaseRefresh = this._checkHoldCaseRefreshFlag.bind(this);
    window.addEventListener("focus", this._boundCheckHoldCaseRefresh);
    this._checkHoldCaseRefreshFlag();
    void this._initializeHoldCaseVisibility();
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    const fastCashNocSel = readFastCashNocSelectionFromStorage(this.recordId);
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    const pointsRedemptionNocSel = readPointsRedemptionNocSelectionFromStorage(this.recordId);
    if (fastCashNocSel && fastCashNocSel.productTypeId) {
      this.holdCaseNocParams = {
        recordId: this.recordId,
        productTypeId: fastCashNocSel.productTypeId,
        categoryId: fastCashNocSel.categoryId,
        subCategoryId: fastCashNocSel.subCategoryId,
        subCodeId: fastCashNocSel.subCodeId,
      };
      this.getData(
        fastCashNocSel.productTypeId,
        fastCashNocSel.categoryId,
        fastCashNocSel.subCategoryId,
        fastCashNocSel.subCodeId
      );
    } else if (pointsRedemptionNocSel && pointsRedemptionNocSel.productTypeId) {
      this.getData(
        pointsRedemptionNocSel.productTypeId,
        pointsRedemptionNocSel.categoryId,
        pointsRedemptionNocSel.subCategoryId,
        pointsRedemptionNocSel.subCodeId
      );
    } else {
      this.getData();
    }
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
    // [NOC-HANDLING-STAGE-UPDATE]: Unsubscribe CASE_NOC khi component bị destroy
    if (this._subscriptionCaseNOC) {
      unsubscribe(this._subscriptionCaseNOC);
      this._subscriptionCaseNOC = null;
    }
    if (this._boundCheckHoldCaseRefresh) {
      window.removeEventListener("focus", this._boundCheckHoldCaseRefresh);
    }
    localStorage.removeItem(this.draftStorageKey);
  }

  _maskDisplayPhone(raw) {
    if (raw == null || raw === STR_EMPTY) return STR_EMPTY;
    return maskValue(String(raw).replace(/\D/g, STR_EMPTY), false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // [NOC-HANDLING-STAGE-UPDATE]:
  // Xử lý NOC update từ fec_CaseEditNOC (Handling Stage)
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Handler cho CASE_NOC channel.
   * Phân biệt 2 loại message:
   *   - Có 'accountType' → existing behavior (không thay đổi)
   *   - Có 'subCodeId'   → NOC update từ Updated Information section → reload business
   */
  _handleCaseNOCMessage(message) {
    if (!message) return;

    // Chỉ xử lý message dành cho case này, tránh cross-tab interference
    if (message.caseId != null && message.caseId !== this.recordId) return;

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — message khóa NOC chỉ dành cho fec_CaseEditNOC, không reload business
    if (message.fastCashNocLocked === true) {
      return;
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    if (message.pointsRedemptionNocLocked === true) {
      return;
    }
    if (message.contextFlagsSync === true) {
      return;
    }

    if (Object.prototype.hasOwnProperty.call(message, 'accountType')) {
      // Existing behavior: account type change — không xử lý ở đây
      // (fec_CaseEditNOC đã tự xử lý)
      return;
    }
    //PhongBT 07/05/26: fix case nếu đang chọn bộ noc đủ subcode mà chuyển sang muốn submit bộ không có subcode thì lại
    //lưu bộ có subcode chứ không phải bộ không subcode định submit
    const hasNocSelectionPayload =
      Object.prototype.hasOwnProperty.call(message, 'productTypeId') ||
      Object.prototype.hasOwnProperty.call(message, 'categoryId') ||
      Object.prototype.hasOwnProperty.call(message, 'subCategoryId') ||
      Object.prototype.hasOwnProperty.call(message, 'subCodeId') ||
      Object.prototype.hasOwnProperty.call(message, 'natureOfCaseId');

    if (hasNocSelectionPayload) {
      // NOC update từ Updated Information section.
      // Lưu ý: bộ NOC không có Sub-Code sẽ publish subCodeId = null, vẫn phải reload.
      this.holdCaseNocParams = {
        recordId: this.recordId,
        productTypeId: message.productTypeId,
        categoryId: message.categoryId,
        subCategoryId: message.subCategoryId,
        subCodeId: message.subCodeId,
      };
      this._handleNOCUpdate(message);
    }
  }

  //PhongBT: query FEC_Case_Flow_History__c sau khi đổi bộ noc khác để lấy lại giá trị đã nhập lên
  _handleNOCUpdate(message) {
    //PhongBT: query FEC_Case_Flow_History__c sau khi đổi bộ noc khác để lấy lại giá trị đã nhập lên
    getPropertyFieldsFromFlowHistory({ caseId: this.recordId })
      .then((fieldListJson) => {
        // Parse JSON → map { apiName → value } để merge sau khi getData xong
        let snapshot = {};
        if (fieldListJson) {
          try {
            const fieldList = JSON.parse(fieldListJson);
            if (Array.isArray(fieldList)) {
              fieldList.forEach((item) => {
                if (item?.apiName) {
                  snapshot[item.apiName] = item.value ?? null;
                }
              });
            }
          } catch (e) {
            console.error('[NOC-UPDATE] Parse fieldListJson error:', e);
          }
        }

        // Lưu snapshot để _mergePropertyFieldSnapshot dùng sau khi getData hoàn thành
        this._pendingPropertySnapshot = snapshot;

        // Reload business với NOC mới
        return this.getData(
          message.productTypeId,
          message.categoryId,
          message.subCategoryId,
          message.subCodeId,
          message.natureOfCaseId
        );
      })
      .catch((err) => {
        console.error('[NOC-UPDATE] getPropertyFieldsFromFlowHistory error:', err);
        // Fallback: reload business mà không merge (không block flow)
        this._pendingPropertySnapshot = null;
        return this.getData(
          message.productTypeId,
          message.categoryId,
          message.subCategoryId,
          message.subCodeId,
          message.natureOfCaseId
        );
      })
      .then(() => {
        //PhongBT 18/05/26: fix Document Request
        // PhongBT: Document Request — gen PDF sau khi chọn sub-code (chỉ trên luồng CASE_NOC)
        if (message.subCodeId != null) {
          void this._generateAndSavePdfIfApplicable(message.subCodeId);
        }
      });
  }

  //PhongBT: query FEC_Case_Flow_History__c sau khi đổi bộ noc khác để lấy lại giá trị đã nhập lên
  // Merge field values từ FEC_Field_List__c JSON vào business data sau khi reload NOC mới.
  // Field có apiName trùng → restore value; field không có → giữ nguyên trống từ getData.
  _mergePropertyFieldSnapshot(snapshot) {
    if (!snapshot || !this.business?.sectionlst) return;
    this.business.sectionlst.forEach(section => {
      section.subSectionlst?.forEach(sub => {
        sub.objlst?.forEach(obj => {
          obj.fieldlst?.forEach(field => {
            if (field?.apiName && Object.prototype.hasOwnProperty.call(snapshot, field.apiName)) {
              field.value = snapshot[field.apiName];
              field.original = field.value;
            }
          });
        });
      });
    });
    this.business = { ...this.business };
  }

  // ─────────────────────────────────────────────────────────────────────────

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
    // Stage 2+ Scoped: reset flag PhongBT để không flash section routing cũ trước khi getData xong.
    this._documentRequestStageChangeRoutingActive = false;
    this._mrcReturnStageChangeRoutingActive = false;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1294
    this._hidePropertyInfoForFastCash = false;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
    this._hideC360AndPropertyForPointsRedemption = false;
    this._ippClosureHasEligibleRows = false;
    this._fetchRdPaymentQueues(); // Toannd61

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
        // NOC payload can carry 3 states for natureOfCaseId: undefined/null/id.
        // Only override when payload explicitly provides this field.
        const hasNocSelectionPayload =
          productTypeId !== null ||
          categoryId !== null ||
          subCategoryId !== null ||
          subCodeId !== null;
        const hasExplicitNatureFallback =
          natureOfCaseIdFallback !== undefined && natureOfCaseIdFallback != null;
        const natureOfCase =
          hasNocSelectionPayload && hasExplicitNatureFallback
            ? natureOfCaseIdFallback
            : (res.natureOfCase || natureOfCaseIdFallback);
        this.business = { ...res, natureOfCase };

        //linhdev: Fix jira FECREDIT_CSM_2025_KH-1226
        this.activeMainSectionlst = [];
        this.activeRoutingSectionlst = [];

        // Hiện section Routing khi Apex trả ít nhất một option; chế độ xem vẫn thấy Action, chỉ khóa dropdown (isRoutingActionDisabled).
        // tungnm37: COF/GSR luôn hiện section dù routingActionlst rỗng (chưa có stage)
        //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
        const docReqRoutingCtx = getDocumentRequestRoutingContext(
          this.business,
          this._documentRequestRoutingFieldOverrides(),
        );
        this._documentRequestDeliveryEligible = docReqRoutingCtx.deliveryEligible;
        this._syncHasRoutingAction();
        this._mrcReturnStageChangeRoutingActive =
          shouldActivateMrcReturnRouting(this.business);

        // Ưu tiên draft đã lưu, nếu không có hoặc không hợp lệ thì dùng option đầu tiên
        const draftCode = this.business.draftRoutingActionCode;
        const selectedDraftAction = this._findRoutingActionByValueOrCode(draftCode);
        this.actionValue = selectedDraftAction
          ? selectedDraftAction.value
          : this.business.routingActionlst[0]?.value;

        if (OUTBOUND_CAMPAIGN == this.business.code) {
          this._setActionValueByCode(ACTION_RESOLVE);
        }

        if (!this.business.nextQueue) {
          this.business.nextQueue = { label: STR_EMPTY, value: null };
        }

        this.business.sectionlst.forEach((section, index) => {
          // handle error
          if (section.error?.errorlst?.length > 0 || section.error?.label) {
            section.hasError = true;

            section.error.errorPanellst = [];

            section.error?.errorlst?.forEach((error, index1) => {
              section.error.errorPanellst.push({
                id: index1,
                value: error,
              });
            });

            if (section.error?.errorlst?.length > 0 || section.error?.label) {
            const mrcWarningOnly =
              section.name === SECTION_NAME_CASE_INFORMATION &&
              this.business?.mrcRl05CaseInfoWarningOnly === true;
            if (!mrcWarningOnly) {
              this._setActionValueByCode(ACTION_REJECT);
            }
            }
          }
          section.id = crypto.randomUUID();

          sectionlst.push(section.id);

          section.isLastSection = index === this.business.sectionlst.length - 1;
          section.isCaseInformationSection = section.name === SECTION_NAME_CASE_INFORMATION;
          section.holdCaseRowKey = `${section.id}-hold-case`;

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
                if (field.hidden) {
                  field.className += ' slds-hide';
                }

                let currentField = `${obj.name}.${field.apiName}`;

                if (
                  currentField == CASE_CS_D2C_ASSIGNMENT_TYPE ||
                  currentField == CASE_CONFIRM_D2C_ASSESMENT
                ) {
                  assignmentType = field.value;
                }
                if (field.apiName === FIELD_CARD_REPLACEMENT_REASON) {
                  this.cardReplacementReason = field.value;
                  this.isHiddenLwc = !field.value;
                }

                // PhuongNT cmt, still process for field read only
                // if (!field.readonly) {
                if (
                  currentField === CASE_CS_D2C_REQUIRED_CORRECTIVE_ACTION ||
                  currentField === CASE_CS_D2C_RISK_LEVEL
                ) {
                  field.isHidden =
                    !assignmentType || assignmentType === TYPE_QUALIFIED || assignmentType === TYPE_QUALIFIED_VN;
                } else if (
                  currentField === CASE_ACTIONS_TAKEN_D2C_ASSESMENT
                ) {
                  field.isHidden =
                    !assignmentType || assignmentType === TYPE_DISAGREE;
                } else {
                  field.isHidden = false;
                }
                // }

                if (
                  !this.isEdit ||
                  this._isStage1RevertMasterReadonly() ||
                  this._isGsrStage3PropertyInfoFieldReadonly(sub.name)
                ) {
                  field.readonly = true;
                  field.editable = false;
                }

                field.original = field.value;

                field.isDate =
                  field.type === "DATE" || DATE_FIELDS.has(field.apiName);
                field.isPhone = PHONE_VALIDATED_FIELD_APIS.has(field.apiName);
                if (field.isDate) {
                  field.displayValue = formatToDDMMYYYY(field.value);
                } else {
                  field.displayValue = field.value;
                }

                // Convert label to value for picklist fields
                const picklistOptions = this.business.picklistOptionsMap?.[obj.name]?.[field.apiName];
                if (picklistOptions?.length) {
                  if (field.value) {
                    const opt = findPicklistOptionByRaw(picklistOptions, field.value);
                    if (opt) {
                      field.value = opt.value;
                    }
                  } else {
                    const defaultOpt = picklistOptions.find(o => o.isDefault);
                    if (defaultOpt) {
                      field.value = defaultOpt.value;
                    }
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

                // PhuongNT add handle set display value for field "Card Replacement Fee"
                if (field.apiName === FIELD_CARD_REPLACEMENT_FEE) {
                  field.displayValue = formatCurrencyIncludeTax(field.value, 'VND (include 10% VAT)');
                  field.readonlyDisplayValue = field.displayValue;
                  // PhuongNT add set hidden field
                  field.isHidden = !this.cardReplacementReason;
                } else if (
                  field.apiName === FIELD_LOAN_AMOUNT
                  // field.apiName === FIELD_LOAN_AMOUNT &&
                  // row.sub?.name === SUBSECTION_NAME_C360_INFO
                ) {
                  field.displayValue = formatCurrency2(field.value);
                  field.readonlyDisplayValue = field.displayValue;
                }
                // PhuongNT add set newBlockCode
                else if (field.apiName === FIELD_NEW_BLOCK_CODE) {
                  this.newBlockCode = field.value;
                }
                // PhuongNT add set hidden field
                else if (field.apiName === FIELD_NEW_BLOCK_CODE_CARD_REPLACE) {
                  field.isHidden = !this.cardReplacementReason;
                } else if (field.apiName === FIELD_RECIPIENT_NAME) {
                  field.isHidden = !this.cardReplacementReason;
                } else if (field.apiName === FIELD_RECIPIENT_PHONE_NUMBER) {
                  field.isHidden = !this.cardReplacementReason;
                }
              });
            });
          });
        });

        // PhuongNT add show button process action with process PIN Reissue
        if (this.business?.code === PROCESS_PIN_REISSUE) {
          this.showProcessAction = true;
        }
        // PhuongNT add show button process action with process Card Replacement
        if (this.business?.code === PROCESS_CARD_REPLACEMENT && this._isEdit && this.isStage1) {
          this.handleCheckProcessAction();
        }

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
        //linhdev fix jira FECREDIT_CSM_2025_KH-1294
        this._applyFastCashPropertyInfoVisibility();
        //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — C360/Property: LWC Points Redemption quyết định sau initData (đủ điều kiện mới ẩn)
        this._setPointsRedemptionHideFlag(false);
        ensureMrcReturnCaseFormInBusiness(this.business);
        if (
          isMrcRl05Branch(this.business) &&
          !isMrcRl05CaseInformationBlocked(this.business)
        ) {
          this._initMrcReturnFieldsFromBusiness();
          const layoutResult = applyMrcRl0502DupFieldLayout(
            this.business,
            this.mrcReturnHandlingOptionValue,
            this.mrcReturnCustomerConfirmationValue,
          );
          this.mrcReturnHandlingOptionValue = layoutResult.handlingOptionValue;
          this.business = layoutResult.business;
          this._syncMrcDeliveryDraftFromCase();
          this._applyMrcReturnCaseIntegration();
        }
        this._rebuildAllSectionSortedRows();
        this._prepareRoutingSectionForDisplay();
        this._syncActiveRoutingSection();
        this.businessLoaded = true;
        this._syncRemovePhoneLockAfterRevert();
        //linhdev: Fix jira FECREDIT_CSM_2025_KH-1226 — mỗi accordion chỉ nhận đúng tên section của nó.
        this.activeMainSectionlst = [...sectionlst];
        //linhdev fix section Account Info + Case Info
        Promise.resolve().then(() => {
          this._ensureAccountCaseSectionsExpanded();
        });
        console.log("🚀 ~ Fec_CaseBussiness ~ getData ~ this.business:", JSON.stringify(this.business))
        this.applyDraft();
        this._applyCsSupportAssessmentRoutingActionSync();
        this._applyRdPaymentContractAssessmentRouting(); // Toannd61
        this._resolveComponentlst();
        Promise.resolve().then(() => {
          this._syncMrcReturnFieldsToRecordForm();
        });

        //PhongBT: query FEC_Case_Flow_History__c sau khi đổi bộ noc khác để lấy lại giá trị đã nhập lên
        // Sau khi getData hoàn thành, merge lại giá trị đã nhập từ FEC_Field_List__c vào NOC mới
        if (this._pendingPropertySnapshot) {
          this._mergePropertyFieldSnapshot(this._pendingPropertySnapshot);
          this._pendingPropertySnapshot = null;
        }
        //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
        void this._supplementRl0402Rl0403RoutingActionsIfNeeded()
          .then(() => this._supplementMrcRl05RoutingActionsIfNeeded())
          .then(() => this._loadDocumentRequestStageChangeRouting())
          .then(() => {
            this._syncActiveRoutingSection();
            this._syncDocumentRequestRoutingActionSelection();
          });
        // PhuongNT add get current card status for Card Block/Unblock
        if (this.business?.code === PROCESS_BLOCK_CARD || this.business?.code === PROCESS_UNBLOCK_CARD) {
          this.handleGetCardStatus();
        }
        // PhuongNT add handle set update field read only
        this.handleSetUpdateFieldReadOnly();

        console.log("🚀 ~ Fec_CaseBussiness ~ getData ~ this.business after:", JSON.stringify(this.business))
        publish(this.messageContext, CASE_NOTIFICATION, {
          caseId: this.recordId,
          productTypeId: productTypeId,
          categoryId: categoryId,
          subCategoryId: subCategoryId,
          subCodeId: subCodeId,
          stageId: res.stage
        });
        if (this.business?.contextFlags) {
          publish(this.messageContext, CASE_NOC, {
            caseId: this.recordId,
            contextFlagsSync: true,
            contextFlags: this.business.contextFlags,
          });
        }
        // void this._refreshHoldCaseAutoDisplay();
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

    let verifyInfoValue;
    this.business.sectionlst.forEach(section => {
      section.subSectionlst?.forEach(sub => {
        sub.objlst?.forEach(obj => {
          if (obj.name !== CASE_OBJECT_API_NAME) return;
          obj.fieldlst?.forEach(field => {
            if (field.apiName === FIELD_COMPLAIN_TYPE) {
              verifyInfoValue = field.value;
            }
          });
        });
      });
    });

    this.business.sectionlst = this.business.sectionlst.map(section => ({
      ...section,
      subSectionlst: section.subSectionlst?.map(sub => ({
        ...sub,
        objlst: sub.objlst?.map(obj => ({
          ...obj,
          fieldlst: obj.fieldlst?.map(field => {
            let isHidden = field.isHidden;
            if (isInternal) {
              isHidden = field.apiName !== FIELD_ACCOUNT_CONTRACT_NUMBER_PL;
            } else if (field.apiName === FIELD_COMPLAINT_SOURCE) {
              isHidden = !VALUE_COMPLAINT_SOURCE.includes(verifyInfoValue);
            }
            return {
              ...field,
              isHidden
            };
          }) || [],
        })) || [],
      })) || [],
    }));

    this.business = { ...this.business };
    console.log("🚀 ~ Fec_CaseBussiness ~ _applyInternalFieldVisibility ~ this.business:", JSON.stringify(this.business))
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1294
  handleFastCashPropertyInfoVisibility(event) {
    const hide = !!(event.detail && event.detail.hidePropertyInfo);
    this._hidePropertyInfoForFastCash = hide;
    this._applyFastCashPropertyInfoVisibility();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1367
  handleFastCashBlockConfirmed() {
    this.removeRoutingActions([ACTION_REJECT, ACTION_CANCEL]);
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1294
  _applyFastCashPropertyInfoVisibility() {
    if (!this.business?.sectionlst) {
      return;
    }
    let changed = false;
    this.business.sectionlst.forEach((section) => {
      if (section.name !== SECTION_NAME_CASE_INFORMATION) {
        return;
      }
      section.subSectionlst?.forEach((sub) => {
        if (sub.name !== SUBSECTION_NAME_PROPERTY_INFO) {
          return;
        }
        const next = !!this._hidePropertyInfoForFastCash;
        if (sub._hideForFastCash !== next) {
          sub._hideForFastCash = next;
          changed = true;
        }
      });
    });
    if (changed) {
      this._rebuildAllSectionSortedRows();
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
  handlePointsRedemptionSectionVisibility(event) {
    this._setPointsRedemptionHideFlag(!!(event.detail && event.detail.hideC360AndProperty));
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
  _setPointsRedemptionHideFlag(hide) {
    this._hideC360AndPropertyForPointsRedemption = !!hide;
    this._applyPointsRedemptionSectionVisibility();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1393-1394
  _applyPointsRedemptionSectionVisibility() {
    if (!this.business?.sectionlst) {
      return;
    }
    let changed = false;
    const hide = !!this._hideC360AndPropertyForPointsRedemption;
    this.business.sectionlst.forEach((section) => {
      const sectionName = section.name;
      const nextTarget = pointsRedemptionHideTargetForSection(sectionName, hide);
      if (section._pointsRedemptionHideTarget !== nextTarget) {
        section._pointsRedemptionHideTarget = nextTarget;
        changed = true;
      }
      section.subSectionlst?.forEach((sub) => {
        const shouldHideSub = shouldHidePointsRedemptionSubSection(sectionName, sub.name, hide);
        if (sub._hideForPointsRedemption !== shouldHideSub) {
          sub._hideForPointsRedemption = shouldHideSub;
          changed = true;
        }
      });
    });
    if (changed) {
      this._rebuildAllSectionSortedRows();
    }
  }

  handleInputKeydown(e) {
    const nationalIdOnlyFields = [
      FIELD_NEW_CITIZEN_ID_NUMBER,
      FIELD_OLD_CITIZEN_ID_NUMBER,
      FIELD_NATIONAL_ID,
      FIELD_FEOL_ID,
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

    if (PHONE_VALIDATED_FIELD_APIS.has(fieldName)) {
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

    if (PHONE_VALIDATED_FIELD_APIS.has(fieldName)) {
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
      CASE_RD_PAYMENT_CONTRACT_ASSESSMENT, // Toannd61
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
      if (
        objName === 'Case' &&
        (fieldName === FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT ||
          fieldName === FIELD_CONTRACT_PROCESSING_ASSESSMENT_TYPE)
      ) {
        const apiVal = this._casePicklistRawToApi(fieldName, value);
        if (apiVal != null) {
          value = apiVal;
          const opt = findPicklistOptionByRaw(
            this._casePicklistOptions(fieldName),
            apiVal,
          );
          if (opt) {
            field.displayValue = opt.label;
          }
        }
      }
      field.value = value;
      if (fieldName === FIELD_MRC_CUSTOMER_CONFIRMATION && this.business) {
        this.business.mrcCustomerConfirmationDraft = value;
        this._syncMrcReturnFieldsToRecordForm();
      }
      if (isMrcReturnTrackedField(fieldName)) {
        this._applyMrcReturnCaseIntegration();
      }
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

    // RD Payment Assessment — Route to + Team ngay khi onChange (không phụ thuộc find field)
    if (
      fieldName === FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT &&
      value &&
      value !== STR_EMPTY
    ) {
      applyRdPaymentAssessmentRoutingImmediate(this, value);
      void this._applyRdPaymentRoutingByAssessment(value);
    }

    if (fieldName === FIELD_COMPLAIN_TYPE) {
      this._applyInternalFieldVisibility();
      this._rebuildAllSectionSortedRows();
    }

    //PhongBT 18/05/26: Document Request — cập nhật Route To khi đổi delivery / hình thức văn bản
    if (
      fieldName === Fec_CaseBussiness.DOC_REQ_FIELD_DELIVERY ||
      fieldName === Fec_CaseBussiness.DOC_REQ_FIELD_DOCUMENT_TYPE
    ) {
      setBusinessFieldValue(this.business, fieldName, value);
      this.business = { ...this.business };
      this._syncDocumentRequestRoutingFromBusinessFields();
    }

    if (
      isMrcRl05Branch(this.business) &&
      fieldName === Fec_CaseBussiness.DOC_REQ_FIELD_DELIVERY
    ) {
      this._mrcDeliveryOptionDraft = value ?? STR_EMPTY;
      this._loadMrcReturnStageChangeRouting().then(() => {
        this._syncActiveRoutingSection();
      });
    }

    if (PHONE_VALIDATED_FIELD_APIS.has(fieldName) && field) {
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
    if ((fieldName === FIELD_NATIONAL_ID || fieldName === FIELD_FEOL_ID) && field) {
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
    if (obj && obj.name === OBJ_FEC_ADDITIONAL_INFO && fieldName === FIELD_FEC_REF_NUMBER && field) {
      const strVal = value == null || value === STR_EMPTY ? STR_EMPTY : String(value);
      const maxRefLen = 255;
      field.customError =
        strVal.length > maxRefLen
          ? FEC_MSG_Param_Maxlength.replace("{0}", field.label || FIELD_FEC_REF_NUMBER).replace("{1}", String(maxRefLen))
          : null;
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
          // PhuongNT add for Unblock Card
          if (this.business?.code === PROCESS_UNBLOCK_CARD) {
            this.showProcessAction = TYPE_QUALIFIED == value || TYPE_QUALIFIED_VN == value;
          }

          break;

        case CASE_CS_SUPPORT_ASSESMENT_TYPE:
          this.showProcessAction = TYPE_QUALIFIED == value;

          if (TYPE_UNQUALIFIED == value) {
            toRevert = true;
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

        // Toannd61 — RD Payment Assessment (backup: adHocFieldlst switch)
        case CASE_RD_PAYMENT_CONTRACT_ASSESSMENT:
          toRouteTo = !!value && value !== STR_EMPTY;
          break;

        default:
          break;
      }

      //PhongBT 19/05/26: Fix mr chuyển routing action của document request sang lwc con
      let routeToEle = this._getRoutingActionSelectEl();

      if (routeToEle) {
        if (toRouteTo === true) {
          this._setActionValueByCode(ACTION_ROUTE_TO);
        }

        if (toRevert === true) {
          this._setActionValueByCode(ACTION_REVERT);
        }

        if (toResolve === true) {
          this._setActionValueByCode(ACTION_RESOLVE);
        }

        if (toReject === true) {
          this._setActionValueByCode(ACTION_REJECT);
        }
      }
    }

    // card block
    if (fieldName === FIELD_CARD_BLOCK_REASON) {
      this.isProcessActionInfo = false;
      this.isProcessActionFailed = false;
      this.processActionMsg = '';
      if (!value) {
        this.showProcessAction = false;
      }

      this.business.sectionlst.forEach(section => {
        section.subSectionlst.forEach(sub => {
          sub.objlst.forEach(obj => {
            obj.fieldlst.forEach(field => {
              if (field.editable) return; // ignore editable
              if (field.apiName === FIELD_NEW_BLOCK_CODE) {
                field.value = MAP_NEW_BLOCK_CODE[value];
                field.displayValue = field.value;
                field.readonlyDisplayValue = field.value;
                this.newBlockCode = field.value;
              }
            });
          });
        });
      });
      this.handleCheckProcessActionCardBlock();
    }
    // card replacement
    else if (fieldName === FIELD_CARD_REPLACEMENT_REASON) {
      this.isHiddenLwc = !value;
      this.business.sectionlst.forEach(section => {
        section.subSectionlst.forEach(sub => {
          sub.objlst.forEach(obj => {
            obj.fieldlst.forEach(field => {
              // PhuongNT cmt, still process hidden with editable
              // if (field.editable) return; // ignore editable
              if (field.apiName === FIELD_NEW_BLOCK_CODE_CARD_REPLACE) {
                field.value = MAP_NEW_BLOCK_CODE_CARD_REPLACE[value];
                field.displayValue = field.value;
                field.readonlyDisplayValue = field.value;
                field.isHidden = !value;
              } else if (field.apiName === FIELD_CARD_REPLACEMENT_FEE) {
                field.value = MAP_CARD_REPLACEMENT_FEE_VALUE[value];
                field.displayValue = MAP_CARD_REPLACEMENT_FEE_DISPLAY[value];
                field.readonlyDisplayValue = field.displayValue;
                field.isHidden = !value;
              } else if (field.apiName === FIELD_RECIPIENT_NAME) {
                field.isHidden = !value;
              } else if (field.apiName === FIELD_RECIPIENT_PHONE_NUMBER) {
                field.isHidden = !value;
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

    // // Toannd61 19/05/26 jira 1423: Scoped routing section (Stage 2+)
    if (!validateScopedRoutingSection(this)) {
      isAllValid = false;
    }

    //PhongBT 19/05/26: Fix mr chuyển routing action của document request sang lwc con
    let routeToEle = this._getRoutingActionSelectEl();

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

    if (!this._validateFastCashForSubmit()) {
      isAllValid = false;
    }

    if (!this._validateRemovePhoneForSubmit()) {
      isAllValid = false;
    }

    const mrcPanel = this._getMrcReturnPanelEl();
    if (mrcPanel && typeof mrcPanel.validateForSubmit === "function") {
      if (!mrcPanel.validateForSubmit()) {
        isAllValid = false;
      }
    }

    const contractClosureEl = this._getContractClosureFormEl();
    if (
      contractClosureEl &&
      typeof contractClosureEl.validateForSubmit === "function"
    ) {
      if (!contractClosureEl.validateForSubmit()) {
        isAllValid = false;
      }
    }

    const pointsRedemptionEl = this._getPointsRedemptionCaseFormEl();
    if (
      pointsRedemptionEl &&
      typeof pointsRedemptionEl.validateForSubmit === "function"
    ) {
      if (!pointsRedemptionEl.validateForSubmit()) {
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

    if (
      !validateMrcReturnCase(
        this.business,
        this.mrcReturnHandlingOptionValue,
        this.mrcReturnCustomerConfirmationValue,
      )
    ) {
      isAllValid = false;
    }

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

  _getMrcReturnPanelEl() {
    const direct = this.template.querySelector("c-fec_-mrc-return-panel");
    if (direct) {
      return direct;
    }
    const wraps = this.template.querySelectorAll(
      '[data-fec-lwc="fec_MrcReturnPanel"]',
    );
    for (const wrap of wraps) {
      const panel = wrap.querySelector("c-fec_-mrc-return-panel");
      if (panel) {
        return panel;
      }
    }
    return null;
  }

  _getContractClosureFormEl() {
    const panel = this._getMrcReturnPanelEl();
    if (panel && typeof panel.getDeliveryForm === "function") {
      const delivery = panel.getDeliveryForm();
      if (
        delivery &&
        (typeof delivery.validateForSubmit === "function" ||
          typeof delivery.saveToCase === "function" ||
          typeof delivery.saveDraftIfApplicable === "function")
      ) {
        return delivery;
      }
    }
    return (
      this._getDynamicFormEl("fec_ContractClosureForm") ||
      this._getDynamicFormEl("fec_MrcDeliveryForm")
    );
  }

  _getDynamicFormEl(componentName) {
    const wrap = this.template.querySelector(
      `[data-fec-lwc="${componentName}"]`,
    );
    const host = wrap && wrap.firstElementChild;
    if (
      host &&
      (typeof host.validateForSubmit === "function" ||
        typeof host.saveToCase === "function" ||
        typeof host.saveDraftIfApplicable === "function")
    ) {
      return host;
    }
    return null;
  }

  _getPointsRedemptionCaseFormEl() {
    const wrap = this.template.querySelector(
      '[data-fec-lwc="fec_PointsRedemptionCaseForm"]',
    );
    const host = wrap && wrap.firstElementChild;
    if (
      host &&
      (typeof host.validateForSubmit === "function" ||
        typeof host.saveDraftIfApplicable === "function")
    ) {
      return host;
    }
    return null;
  }

  _saveContractClosureDraftIfApplicable() {
    const panel = this._getMrcReturnPanelEl();
    if (panel && typeof panel.saveDraftIfApplicable === "function") {
      return panel.saveDraftIfApplicable();
    }
    const el = this._getContractClosureFormEl();
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve({ valid: true, messages: [] });
    }
    return el.saveDraftIfApplicable();
  }

  _saveContractClosureIfApplicable() {
    const panel = this._getMrcReturnPanelEl();
    if (panel && typeof panel.saveToCase === "function") {
      return panel.saveToCase();
    }
    const el = this._getContractClosureFormEl();
    if (!el || typeof el.saveToCase !== "function") {
      return Promise.resolve({ valid: true, messages: [] });
    }
    return el.saveToCase();
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

  _savePointsRedemptionDraftIfApplicable() {
    const el = this._getPointsRedemptionCaseFormEl();
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveDraftIfApplicable();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — lưu FEC_Redeemed_Points__c qua record form khi submit
  _syncPointsRedemptionFieldToRecordForm() {
    const el = this._getPointsRedemptionCaseFormEl();
    if (!el || typeof el.getSelectedRedeemedPointsValue !== "function") {
      return;
    }
    const val = el.getSelectedRedeemedPointsValue();
    if (val == null || val === STR_EMPTY) {
      return;
    }
    const fields = this.template.querySelectorAll(
      'lightning-input-field[field-name="FEC_Redeemed_Points__c"]',
    );
    fields?.forEach((field) => {
      field.value = val;
    });
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

  _getFastCashCaseFormEl() {
    const wrap = this.template.querySelector(
      '[data-fec-lwc="fec_FastCashCaseForm"]',
    );
    const host = wrap && wrap.firstElementChild;
    if (
      host &&
      (typeof host.validateForCaseSubmit === "function" ||
        typeof host.saveDraftIfApplicable === "function" ||
        typeof host.saveForSubmitIfApplicable === "function")
    ) {
      return host;
    }
    return null;
  }

  _validateFastCashForSubmit() {
    const el = this._getFastCashCaseFormEl();
    if (!el || typeof el.validateForCaseSubmit !== "function") {
      return true;
    }
    return el.validateForCaseSubmit();
  }

  _saveFastCashDraftIfApplicable() {
    const el = this._getFastCashCaseFormEl();
    if (!el || typeof el.saveDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveDraftIfApplicable();
  }

  _saveFastCashForSubmitIfApplicable() {
    const el = this._getFastCashCaseFormEl();
    if (!el || typeof el.saveForSubmitIfApplicable !== "function") {
      return Promise.resolve();
    }
    return el.saveForSubmitIfApplicable();
  }

  _getSubProcessContainerEl() {
    return (
      this.template.querySelector("c-fec_-sub-process-container") ||
      this.template.querySelector("c-fec-sub-process-container")
    );
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1368
  _validateRemovePhoneForSubmit() {
    const host = this._getSubProcessContainerEl();
    if (!host || typeof host.validateRemovePhoneForSubmit !== "function") {
      return true;
    }
    return host.validateRemovePhoneForSubmit();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1368
  _saveRemovePhoneDraftIfApplicable() {
    const host = this._getSubProcessContainerEl();
    if (!host || typeof host.saveRemovePhoneDraftIfApplicable !== "function") {
      return Promise.resolve();
    }
    return host.saveRemovePhoneDraftIfApplicable();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1368
  _saveRemovePhoneForSubmitIfApplicable() {
    const host = this._getSubProcessContainerEl();
    if (!host || typeof host.saveRemovePhoneForSubmitIfApplicable !== "function") {
      return Promise.resolve();
    }
    return host.saveRemovePhoneForSubmitIfApplicable();
  }

  _notifyRemovePhoneCaseSubmitted() {
    const host = this._getSubProcessContainerEl();
    if (host && typeof host.notifyRemovePhoneCaseSubmitted === "function") {
      host.notifyRemovePhoneCaseSubmitted();
    }
    this._syncRemovePhoneLockAfterRevert();
  }

  _syncRemovePhoneLockAfterRevert() {
    const host = this._getSubProcessContainerEl();
    if (!host) {
      return;
    }
    host.lockApiLwcsAfterRevertToDefaultStage =
      this.business?.lockApiLwcsAfterRevertToDefaultStage === true;
  }

  _initMrcReturnFieldsFromBusiness() {
    if (!isMrcRl05Branch(this.business)) {
      return;
    }
    const savedHandling = String(this.business?.mrcHandlingOptionSaved ?? STR_EMPTY).trim();
    const fromSection = getCaseFieldValue(
      this.business,
      FIELD_MRC_HANDLING_OPTION,
    );
    this.mrcReturnHandlingOptionValue =
      savedHandling || fromSection || STR_EMPTY;

    const savedConf = String(
      this.business?.mrcCustomerConfirmationSaved ?? STR_EMPTY,
    ).trim();
    if (savedConf && !this.business.mrcCustomerConfirmationDraft) {
      this.business.mrcCustomerConfirmationDraft = savedConf;
    }
    this._syncMrcReturnFieldsToRecordForm();
  }

  _syncMrcReturnFieldsToRecordForm() {
    if (!isMrcRl05Branch(this.business)) {
      return;
    }
    const confirmation = this.mrcReturnCustomerConfirmationValue;
    const handlingOption = this.mrcReturnHandlingOptionValue;

    this.template
      .querySelectorAll(`[data-field="${FIELD_MRC_CUSTOMER_CONFIRMATION}"]`)
      ?.forEach((field) => {
        field.value = confirmation || null;
      });
    this.template
      .querySelectorAll(`[data-field="${FIELD_MRC_HANDLING_OPTION}"]`)
      ?.forEach((field) => {
        field.value = handlingOption || null;
      });

    this.business?.sectionlst?.forEach((section) => {
      section.subSectionlst?.forEach((sub) => {
        sub.objlst?.forEach((obj) => {
          if (obj.name !== "Case") {
            return;
          }
          obj.fieldlst?.forEach((field) => {
            if (field.apiName === FIELD_MRC_CUSTOMER_CONFIRMATION && confirmation) {
              field.value = confirmation;
            }
            if (field.apiName === FIELD_MRC_HANDLING_OPTION && handlingOption) {
              field.value = handlingOption;
            }
          });
        });
      });
    });
  }

  _syncMrcReturnCaseFieldsBeforeSubmit() {
    if (!isMrcRl05Branch(this.business)) {
      return Promise.resolve();
    }
    const fields = { [ID_FIELD.fieldApiName]: this.recordId };
    const confirmation = this.mrcReturnCustomerConfirmationValue;
    if (confirmation) {
      fields[FIELD_MRC_CUSTOMER_CONFIRMATION] = confirmation;
    }
    const handlingOption = this.mrcReturnHandlingOptionValue;
    if (handlingOption) {
      fields[FIELD_MRC_HANDLING_OPTION] = handlingOption;
    }
    if (Object.keys(fields).length <= 1) {
      return Promise.resolve();
    }
    return updateRecord({ fields });
  }

  _saveMrcReturnDeliveryIfApplicable() {
    if (!isMrcRl05Branch(this.business)) {
      return Promise.resolve({ valid: true, messages: [] });
    }
    const panel = this._getMrcReturnPanelEl();
    if (panel && typeof panel.saveToCase === "function") {
      return panel.saveToCase();
    }
    return Promise.resolve({ valid: true, messages: [] });
  }

  //linhdev: Persist child data before case record form submit
  _persistChildDataBeforeCaseRecordFormSubmit() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — gap 2: lưu Redeemed Points trước record form submit
    this._syncPointsRedemptionFieldToRecordForm();
    this._syncMrcReturnFieldsToRecordForm();
    return Promise.all([
      this._syncMrcReturnCaseFieldsBeforeSubmit(),
      this._saveRemovePhoneDraftIfApplicable(),
      this._savePointsRedemptionDraftIfApplicable(),
    ]);
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
          (a) => (a.code || a.value) === ACTION_REJECT,
        );
        if (!hasReject) {
          return;
        }
        this._setActionValueByCode(ACTION_REJECT);
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
      (a) => (a.code || a.value) === ACTION_ROUTE_TO,
    );
    if (!hasRouteTo) {
      return;
    }
    this._setActionValueByCode(ACTION_ROUTE_TO);
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
   * DungLT — Đẩy file từ các slot `fec_FileUploadCard` lên Case (ContentVersion) khi Save & Close / Submit.
   */
  _uploadFecFileUploadCardsIfApplicable() {
    const wrappers = this.template.querySelectorAll(
      '[data-fec-lwc="fec_FileUploadCard"]',
    );
    if (!wrappers || !wrappers.length) {
      return Promise.resolve();
    }
    const promises = [];
    wrappers.forEach((wrap) => {
      const el =
        wrap.querySelector("c-fec_-file-upload-card") ||
        wrap.querySelector("c-fec-file-upload-card");
      if (el && typeof el.flushUploadsToCase === "function") {
        promises.push(Promise.resolve(el.flushUploadsToCase()));
      }
    });
    return promises.length ? Promise.all(promises) : Promise.resolve();
  }

  /**
   * Chỉ lưu dữ liệu form (Nature of Case, Account Info, Case Info, Process Action, Routing Action)
   * mà KHÔNG gọi run() - không chuyển sang Stage tiếp theo.
   * Dùng cho nút "Save & Close". Không validate input/select khi Save & Close.
   */
  @api saveOnly() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    return this._persistChildDataBeforeCaseRecordFormSubmit().then(() => {
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
        this._saveFastCashDraftIfApplicable(),
        this._savePointsRedemptionDraftIfApplicable(),
        //linhdev fix jira FECREDIT_CSM_2025_KH-1368
        this._saveRemovePhoneDraftIfApplicable(),
      ])
        .then(() => this._saveContractClosureDraftIfApplicable())
        .then((closureRes) => {
          if (closureRes && closureRes.valid === false) {
            return Promise.reject(new Error("FEC_CONTRACT_CLOSURE_SAVE_FAILED"));
          }
          return this._syncDocumentRequestRoutingFromBusinessFields();
        });

    if (total === 0) {
      // DungLT — flush upload file trước khi lưu form
      //linhdev fix jira FECREDIT_CSM_2025_KH-1368
      return this._uploadFecFileUploadCardsIfApplicable()
        .then(() => afterForms())
        .then(() => this.handleSaveFieldReadOnly());
    }

    return new Promise((resolve, reject) => {
      this._saveOnlyResolve = resolve;
      this._saveOnlyReject = reject;
      this._saveOnlyFormCount = 0;
      this._saveOnlyFormTotal = total;

      //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
      this._syncPointsRedemptionFieldToRecordForm();
      formToSubmit.forEach((item) => {
        this._applyPicklistLabelToApiValue(item);
        item.submit();
      });
    })
      // DungLT — flush upload file sau khi submit record forms
      .then(() => this._uploadFecFileUploadCardsIfApplicable())
      .then(() => afterForms())
      .then(() => {
        // PhuongNT add handle save data for fields readonly were changed data by another field
        this.handleSaveFieldReadOnly();
      });
    });
  }

  /** false = bị chặn (đã show toast), true = submit thành công. */
  @api async submit() {
    const scopedSubmitResult = await trySubmitScopedRouteTo(this);
    if (scopedSubmitResult !== null) {
      return scopedSubmitResult;
    }

    if (!this.validate()) return false;
    if (!this._validateIPPClosureForSubmit()) return false;

    // Có routing thì mới chặn khi chưa đổi thông tin Updated; không có routing cho phép chỉ submit remarks.
    //PhongBT 19/05/26: Fix mr chuyển routing action của document request sang lwc con
    let routeToEle = this._getRoutingActionSelectEl();
    const noUpdate = checkNoUpdateInSubmit(
      this._getCaseFieldOriginalValue.bind(this),
      this._getCaseFieldValue.bind(this),
      this._getCheckNoUpdateInSubmitOptions(),
    );
    const cmp = this._getFecUpdateAddressCmp();
    const hasAddressUpdate = cmp && typeof cmp.hasPendingAddressUpdates === 'function' && cmp.hasPendingAddressUpdates();
    const hasSubmitPicklistChange = this.hasAnySubmitCasePicklistFieldChanged();

    // Chỉ chặn khi có dropdown routing và user chưa cập nhật bất kỳ trường Updated nào.
    if (routeToEle && noUpdate && !hasAddressUpdate && !hasSubmitPicklistChange) {
      this.showToast(FEC_Warning_Title, FEC_MSG_UPDATED_INFO_NOT_UPDATED, "warning");
      return false;
    }

    if (hasAddressUpdate) {
      const res = await cmp.commitPendingAddressUpdatesForProcessAction();
      if (!res?.success) {
        this.showToast(FEC_Error_Title, res?.errorMessage || FEC_Error_Title, "error");
        return false;
      }
      this._refreshFecUpdateAddressAfterProcessSuccess();
    }

    // Dữ liệu địa chỉ đã được lưu vào Case DB khi User A nhấn Save.
    // Không gọi API tại đây — API sẽ được user xử lý gọi qua Process Action "Address Update".

    await this._persistChildDataBeforeCaseRecordFormSubmit();
    await this._submitFormsPromise();
    // DungLT — flush upload file trước các bước lưu khác khi Submit
    await this._uploadFecFileUploadCardsIfApplicable();

    // PhuongNT add handle save data for fields readonly were changed data by another field
    this.handleSaveFieldReadOnly();

    const picklistPersistResult =
      await this.persistSubmitCasePicklistFieldsBeforeSubmit();
    if (picklistPersistResult?.success === false) {
      this.showToast(
        FEC_Error_Title,
        picklistPersistResult.errorMessage || FEC_Error_Title,
        'error',
      );
      return false;
    }

    await Promise.all([
      this._saveIncorrectPaymentAdjustmentsIfApplicable(),
      this._saveIPPClosureIfApplicable(),
      this._saveBeneficiaryIfApplicable(),
      this._saveCardClosureRefundForSubmitIfApplicable(),
      this._saveRefundRequestIfApplicable(),
      this._saveFastCashForSubmitIfApplicable(),
      this._savePointsRedemptionDraftIfApplicable(),
    ]);
    await this._saveRemovePhoneForSubmitIfApplicable();
    const closureSaveRes = await this._saveContractClosureIfApplicable();
    if (closureSaveRes && closureSaveRes.valid === false) {
      return false;
    }
    this._syncMrcDeliveryDraftFromCase();
    if (isMrcRl05Branch(this.business)) {
      await this._loadMrcReturnStageChangeRouting({
        showMissingQueueToast: false,
      });
      routeToEle = this._getRoutingActionSelectEl();
      this._syncActiveRoutingSection();
    }
    console.log('FEC_DEBUG submit before routeToEle check routeToEle=' + !!routeToEle + ' isRoutingAssignmentMode=' + this.isRoutingAssignmentMode + ' natureOfCase=' + this.business?.natureOfCase);

    // tungnm37: validate form Add Item chưa confirm
    if (this.isRoutingAssignmentMode) {
      const routingComp = this.template.querySelector('c-fec_-routing-assignment');
      if (routingComp && routingComp.hasUnconfirmedForm) {
        this.showToast(FEC_Error_Title, FEC_Confirm_Before_Submit, 'error');
        return false;
      }
      // tungnm37: validate phải add ít nhất 1 item khi nút Add Item đang hiển thị
      if (routingComp && routingComp.requiresManualItemButEmpty && routeToEle && routeToEle.value === ACTION_ROUTE_TO) {
        this.showToast(FEC_Error_Title, FEC_Confirm_Before_Submit, 'error');
        return false;
      }
    }

    if (routeToEle) {
      // tungnm37 thêm: COF/GSR shortcut - chỉ chạy khi action là Route to, các action khác (Cancel, Escalate...) chạy bình thường
      if (this.isRoutingAssignmentMode && routeToEle.value === ACTION_ROUTE_TO) {
        await run({
          method: 'Route to COF/GSR',
          params: {
            caseId: this.recordId,
            natureOfCaseId: this.business.natureOfCase,
            manualItemsJson: this._manualItems?.length > 0 ? JSON.stringify(this._manualItems) : null,
            fieldListJson: this._collectFieldListJson(),
            // tungnm37 thêm: truyền remarkContent để gắn vào Assignment Remark
            remarkContent: this.remarkContent || null,
          },
        });
        // tungnm37: clear manual items sau khi submit thành công
        this._manualItems = [];
        const routingComp = this.template.querySelector('c-fec_-routing-assignment');
        if (routingComp) routingComp.clearManualItems();
        return true;
      }
      let method = routeToEle.value;
      let actionId;
      let selectedAction;
      this.business.routingActionlst?.forEach((item) => {
        if (item.value == method) {
          actionId = item.id;
          selectedAction = item;
        }
      });
      method = this._resolveRoutingMethodByAction(selectedAction);
      let params = { method };
      switch (method) {
        case ACTION_ROUTE_TO:
          //PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu
          // tungnm37 thêm: COF/GSR → dùng method riêng, không đổi owner
          console.log('FEC_DEBUG submit ACTION_ROUTE_TO isRoutingAssignmentMode=' + this.isRoutingAssignmentMode + ' businessCode=' + this.business?.code);
          if (this.isRoutingAssignmentMode) {
            params = {
              method: 'Route to COF/GSR',
              params: {
                caseId: this.recordId,
                natureOfCaseId: this.business.natureOfCase,
                manualItemsJson: this._manualItems?.length > 0 ? JSON.stringify(this._manualItems) : null,
                fieldListJson: this._collectFieldListJson(),
                // tungnm37 thêm: truyền remarkContent để gắn vào Assignment Remark
                remarkContent: this.remarkContent || null,
              },
            };
          } else {
            params = {
              ...params,
              params: {
                caseId: this.recordId,
                queueId: this.business.nextQueue?.value,
                natureOfCaseId: this.business.natureOfCase,
                actionId: actionId,
                fieldListJson: this._collectFieldListJson()
              },
            };
          }
          break;
        case ACTION_REVERT:
          params = {
            ...params,
            params: {
              caseId: this.recordId,
              actionId: actionId,
              //Toannd61: action.value (label/value dropdown) cho Apex phân nhánh FEC_IsReverted__c + custom label history
              routingActionValue: selectedAction?.value ?? "",
//PhongBT: update bộ noc chọn ở updated khi revert về
              natureOfCaseId: this.business.natureOfCase,
            },
          };
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
      // tungnm37 sửa: COF/GSR không cần nextQueue
      if (method === ACTION_ROUTE_TO && !this.isRoutingAssignmentMode && !this.business.nextQueue?.value) {
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
        // tungnm37 thêm: COF/GSR không có routing section (chưa có stage) → vẫn gọi ROUTE_TO_COF_GSR
        if (this.isRoutingAssignmentMode) {
          console.log('FEC_DEBUG submit else branch isRoutingAssignmentMode=true natureOfCase=' + this.business.natureOfCase);
          await run({
            method: 'Route to COF/GSR',
            params: {
              caseId: this.recordId,
              natureOfCaseId: this.business.natureOfCase,
              manualItemsJson: this._manualItems?.length > 0 ? JSON.stringify(this._manualItems) : null,
              fieldListJson: this._collectFieldListJson(),
              // tungnm37 thêm: truyền remarkContent để gắn vào Assignment Remark
              remarkContent: this.remarkContent || null,
            },
          });
        } else {
          await saveCaseNOC({
            caseId: this.recordId,
            natureOfCaseId: this.business.natureOfCase,
          });
          //PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu
          await markCaseSubmittedWithoutRoutingWithHistory({
            caseId: this.recordId,
            natureOfCaseId: this.business.natureOfCase || null,
            fieldListJson: this._collectFieldListJson()
          });
        }
      }
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1368
    this._notifyRemovePhoneCaseSubmitted();
    return true;
  }

  //PhongBT 18/05/26: fix Document Request
  /**
   * PhongBT: Document Request — gen PDF theo sub-code RL04.02/RL04.03 và lưu vào Case.
   * Chỉ gọi từ _handleNOCUpdate khi user chọn sub-code (CASE_NOC), không gọi trong getData/submit.
   * Bỏ qua nếu FEC_PaymentHistoryValidationService không cho phép (allowed = false).
   * Header data lấy trực tiếp qua Apex getDocumentRequestPdfHeaderData(caseId)
   * (Case → FEC_Customer_History__c + FEC_Address_Info__c), không còn duyệt business.sectionlst.
   */
  async _generateAndSavePdfIfApplicable(subCodeId) {
    const config = getPdfConfigForSubCode(this.business?.subCodeCode);
    if (!config || subCodeId == null) return;
    if (this._pdfGenerateInFlight) return;

    try {
      const validation = await validatePaymentHistoryRequestForSubCode({
        caseId: this.recordId,
        subCodeId
      });
      if (!validation?.allowed) {
        return;
      }

      this._pdfGenerateInFlight = true;

      const headerData = await getDocumentRequestPdfHeaderData({ caseId: this.recordId });
      let paymentRows = [];
      let repaymentRows = [];
      if (config.needsPaymentRows) {
        paymentRows = await getPaymentHistoryRows({ caseId: this.recordId });
      }
      if (config.needsRepaymentRows) {
        repaymentRows = await getRepaymentScheduleRows({ caseId: this.recordId });
      }
      const pdfConfig = buildPdfDataForSubCode(this.business.subCodeCode, headerData, paymentRows, repaymentRows);
      if (!pdfConfig) {
        console.warn('[PDF] buildPdfDataForSubCode returned null, subCodeCode=', this.business?.subCodeCode);
        return;
      }
      console.log('[PDF] headerData', JSON.stringify(headerData));
      console.log('[PDF] data', JSON.stringify(pdfConfig.data));
      const generator = this.template.querySelector('c-fec-pdf-generator');
      if (!generator) {
        console.warn('[PDF] c-fec-pdf-generator not found in template');
        return;
      }
      const { base64, fileName } = await generator.generatePdf(pdfConfig.templateCode, pdfConfig.data);
      await savePdfToCase({
        base64Data: base64,
        fileName: fileName || pdfConfig.templateCode,
        caseId: this.recordId
      });
    } catch (err) {
      console.error('PDF generation/save failed:', err);
    } finally {
      this._pdfGenerateInFlight = false;
    }
  }

  /**
   * PhongBT: tạo FEC_Case_Flow_History__c khi submit case lần đầu
   * Collect tất cả field values từ business.sectionlst thành JSON string.
   * Chỉ lấy field có value, bỏ qua field masked/hidden.
   * Format: [{ apiName, label, value, objectName }]
   * value: ưu tiên nhãn hiển thị (tiếng Việt) — picklist dùng label từ picklistOptionsMap;
   * ngày dùng displayValue; không đổi field.value dùng cho bind form/Case.
   */
  _fieldValueForFlowHistoryJson(objectName, field) {
    const raw = field.value;
    const opts = this.business?.picklistOptionsMap?.[objectName]?.[field.apiName];
    if (opts?.length) {
      const opt = findPicklistOptionByRaw(opts, raw);
      if (opt?.label != null && String(opt.label).trim() !== STR_EMPTY) {
        return opt.label;
      }
    }
    if (field.isDate && field.displayValue) {
      return field.displayValue;
    }
    const rdv = field.readonlyDisplayValue;
    if (
      rdv != null &&
      String(rdv).trim() !== STR_EMPTY &&
      String(rdv) !== String(raw ?? STR_EMPTY)
    ) {
      return rdv;
    }
    if (
      field.displayValue != null &&
      String(field.displayValue).trim() !== STR_EMPTY &&
      String(field.displayValue) !== String(raw ?? STR_EMPTY)
    ) {
      return field.displayValue;
    }
    return raw;
  }

  _collectFieldListJson() {
    try {
      const fields = [];
      const sections = this.business?.sectionlst ?? [];
      for (const section of sections) {
        for (const sub of section.subSectionlst ?? []) {
          // Chỉ lấy các field thuộc sub-section có FEC_Sub_Section__c = "Property Info"
          if (sub.name !== 'Property Info') continue;
          for (const obj of sub.objlst ?? []) {
            const objectName = obj.name;
            for (const field of obj.fieldlst ?? []) {
              if (field.isHidden) continue;
              const val = this._fieldValueForFlowHistoryJson(objectName, field);
              fields.push({
                apiName: field.apiName,
                label: field.label,
                value: String(val ?? STR_EMPTY),
                objectName
              });
            }
          }
        }
      }
      return JSON.stringify(fields);
    } catch (e) {
      return '[]';
    }
  }

  handleProcessAction(e) {
    let method = e.target.dataset.id;

    if (method === ACTION_ADDRESS_UPDATE) {
      let processObj = this.business.processActionlst?.find(p => p.value === ACTION_ADDRESS_UPDATE);
      if (processObj && processObj.disabled) {
        return;
      }
    }

    this.processActionMethod = method;

    // PhuongNT add handle get field value
    this.handleGetFieldValue();

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
    } else if (method == ACTION_REPLACE_CARD) {
      header = FEC_ACTION_CARD_REPLACEMENT_HEADER;
      content = FEC_MSG_ACTION_CARD_REPLACEMENT;
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

      case ACTION_ADDRESS_UPDATE:
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
          blockCode: this.newBlockCode,
        };
        break;

      case ACTION_UNBLOCK_CARD:
        params = {
          caseId: this.recordId,
          blockCode: this.currentBlockCode,
        };
        break;

      case ACTION_PIN_REISSUE:
        params = {
          caseId: this.recordId,
        };
        break;

      case ACTION_REPLACE_CARD:
        params = {
          caseId: this.recordId,
          blockCode: this.newBlockCodeCardReplace,
          replacementFee: this.cardReplacementFee,
          last4Digit: this.last4Digit,
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
    } else if (this.processActionMethod == ACTION_REPLACE_CARD) {
      msgSuccess = FEC_MSG_ACTION_CARD_REPLACEMENT_SUCCESS;
      msgError = FEC_MSG_ACTION_CARD_REPLACEMENT_ERROR;
    } else {
      msgSuccess = FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS;
      msgError = FEC_MSG_ACTION_PHONE_UPDATE_ERROR;
    }


    // Address Update: Save chỉ lưu local, Process Action mới call API.
    // Các action khác: không đổi luồng gọi API.
    // Author: Toannd61
    let processActionPromise;
    if (this.processActionMethod === ACTION_ADDRESS_UPDATE) {
      const cmp = this._getFecUpdateAddressCmp();
      if (
        cmp &&
        typeof cmp.commitPendingAddressUpdatesForProcessAction === "function"
      ) {
        processActionPromise = cmp.commitPendingAddressUpdatesForProcessAction();
      } else {
        processActionPromise = Promise.resolve({ success: false });
      }
    } else {
      processActionPromise = run({ method: this.processActionMethod, params });
    }

    processActionPromise
      .then((res) => {
        let isSuccess = res?.success;
        console.log('>>>>>>>isSuccess: ' + isSuccess);

        this.isProcessActionValid =
          res?.actionCount != -1 && res?.actionCount != 3;

        if (isSuccess) {
          this.processActionMsg = msgSuccess;
          this.isProcessActionSuccessed = true;
          this.isProcessActionFailed = false;
          if (this.processActionMethod === ACTION_ADDRESS_UPDATE) {
            this.addressUpdateFailCount = 0;
          }
          this._setActionValueByCode(ACTION_RESOLVE);
          // thangtv update logic for Jira KH-931
          this.removeRoutingActions([ACTION_REJECT, ACTION_CANCEL]);

          // thangtv send message re-isuse pin success to NOC component
          if (this.processActionMethod == ACTION_PIN_REISSUE) {
              this.publishPinReissueResult("SUCCESS");
          }

          // PhuongNT send message process action Card to NOC
          if (this.processActionMethod == ACTION_BLOCK_CARD 
            || this.processActionMethod == ACTION_UNBLOCK_CARD
            || this.processActionMethod == ACTION_REPLACE_CARD
          ) {
            this.publishProcessActionResult("SUCCESS");
          }

          if (
            this.processActionMethod === ACTION_ADDRESS_UPDATE ||
            msgSuccess === FEC_MSG_ACTION_PHONE_UPDATE_SUCCESS
          ) {
            this._refreshFecUpdateAddressAfterProcessSuccess();
          }

        } else {
          this.isProcessActionSuccessed = false;
          this.isProcessActionFailed = true;
          // PhuongNT add set msg error for call api
          if (this.isProcessActionValid) {
            if (this.processActionMethod == ACTION_BLOCK_CARD) {
              msgError = FEC_Block_Card_Failed;
            } else if (this.processActionMethod == ACTION_UNBLOCK_CARD) {
              msgError = FEC_MSG_ACTION_UNBLOCK_CARD_ERROR_RETRY;
            } else if (this.processActionMethod == ACTION_PIN_REISSUE) {
              msgError = FEC_MSG_ACTION_PIN_REISSUE_ERROR_RETRY;
            } else if (this.processActionMethod == ACTION_REPLACE_CARD) {
              msgError = FEC_MSG_ACTION_CARD_REPLACEMENT_ERROR_RETRY;
            }
          }
          if (this.processActionMethod === ACTION_ADDRESS_UPDATE) {
            this._handleAddressUpdateFail();
          } else {
            this.processActionMsg = msgError;
            if (msgError === FEC_MSG_ACTION_PHONE_UPDATE_ERROR) {
              this._revertFecUpdateAddressAfterProcessFailure();
            }
          }
          // thangtv send message re-isuse pin error to NOC component
          if (this.processActionMethod == ACTION_PIN_REISSUE) {
              this.publishPinReissueResult("ERROR",msgError);
          }
          // PhuongNT send message process action Card to NOC
          if (this.processActionMethod == ACTION_BLOCK_CARD
            || this.processActionMethod == ACTION_UNBLOCK_CARD
            || this.processActionMethod == ACTION_REPLACE_CARD
          ) {
            this.publishProcessActionResult("ERROR", msgError);
          }
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
        if (this.processActionMethod === ACTION_ADDRESS_UPDATE) {
          this._handleAddressUpdateFail();
        } else {
          this.processActionMsg = msgError;
          if (msgError === FEC_MSG_ACTION_PHONE_UPDATE_ERROR) {
            this._revertFecUpdateAddressAfterProcessFailure();
          }
        }
      })
      .finally(() => {
        this.isLoaded = true;
      });
  }

  _handleAddressUpdateFail() {
    this.addressUpdateFailCount++;
    if (this.addressUpdateFailCount >= 3) {
      this.business.processActionlst = (this.business.processActionlst || []).filter(
        (p) => p.value !== ACTION_ADDRESS_UPDATE
      );
      this.business = { ...this.business };
      this.processActionMsg = FEC_MSG_ACTION_ADDRESS_UPDATE_MAX_FAIL;
      this._revertFecUpdateAddressAfterProcessFailure();
    } else {
      this.processActionMsg = FEC_MSG_ACTION_ADDRESS_UPDATE_ERROR;
    }
  }

  _getFecUpdateAddressCmp() {
    const host = this._findFecUpdateAddressHostEl();
    if (!host) {
      return null;
    }
    return (
      host.querySelector("c-fec_-update-address") || host.firstElementChild
    );
  }

  /** Master data có thể lưu `fec_UpdateAddress`, `c/fec_UpdateAddress` hoặc tên namespaced — tránh bỏ lỡ commit khi Submit. */
  _findFecUpdateAddressHostEl() {
    const exact = this.template.querySelector(
      '[data-fec-lwc="fec_UpdateAddress"]',
    );
    if (exact) {
      return exact;
    }
    const all = this.template.querySelectorAll("[data-fec-lwc]");
    for (let i = 0; i < all.length; i++) {
      const el = all[i];
      const raw = (el.getAttribute("data-fec-lwc") || "").trim();
      if (!raw) {
        continue;
      }
      const tail = raw
        .replace(/^c\//i, "")
        .split("/")
        .pop();
      const base = tail.includes("__") ? tail.split("__").pop() : tail;
      if (base === "fec_UpdateAddress") {
        return el;
      }
    }
    return null;
  }

  /** Đồng bộ lại địa chỉ + mailing sau khi Process Action cập nhật thông tin KH thành công. */
  _refreshFecUpdateAddressAfterProcessSuccess() {
    const cmp = this._getFecUpdateAddressCmp();
    if (
      cmp &&
      typeof cmp.refreshUpdatedInformationAfterProcessSuccess === "function"
    ) {
      cmp.refreshUpdatedInformationAfterProcessSuccess();
    }
  }

  /** Khôi phục UI địa chỉ (fec_UpdateAddress) khi Process Action trả lỗi cập nhật thông tin KH. */
  _revertFecUpdateAddressAfterProcessFailure() {
    const cmp = this._getFecUpdateAddressCmp();
    if (cmp && typeof cmp.revertUpdatedInformationToOriginal === "function") {
      cmp.revertUpdatedInformationToOriginal();
    }
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
  _ensureCaseInformationHoldCaseFlags() {
    if (!this.business?.sectionlst) {
      return;
    }
    this.business.sectionlst.forEach((section) => {
      section.isCaseInformationSection =
        section.name === SECTION_NAME_CASE_INFORMATION;
    });
  }

  _rebuildAllSectionSortedRows() {
    if (!this.business?.sectionlst) {
      return;
    }
    this._ensureCaseInformationHoldCaseFlags();
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
        //linhdev: Fix jira FECREDIT_CSM_2025_KH-1162
        const masterResolved = this._resolveDynCmpMasterIsEdit(name, fecMasterDataSettingIsEdit);

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
            console.log(`[DEBUG][fec_CaseBussiness] _resolveComponentlst — component="${name}", _isEdit=${this._isEdit}, fecMasterDataSettingIsEdit=${fecMasterDataSettingIsEdit}, finalIsEdit=${this._isEdit && masterResolved}`);
            slots[idx] = {
              key: `${name}-${idx}`,
              ctor: mod.default,
              componentName: name,
              isMrcReturnPanel:
                name === "fec_MrcReturnPanel" || name === "fec_MrcReturnCaseForm",
              isMrcReturnCaseForm:
                name === "fec_MrcReturnPanel" || name === "fec_MrcReturnCaseForm",
              fecMasterDataSettingIsEdit,
              isEdit: this._isEdit && masterResolved,
              /** Thứ tự merge: cùng nguồn FEC_Sub_Section_Order__c (Apex → meta.order). */
              sortOrder: fecSubSectionOrder,
              fecSubSectionOrder,
              fieldLayout: meta.fieldLayout,
              subSectionName: meta.subSectionName,
              hideSubSectionHeading: meta.hideSubSectionHeading === true,
              isCollapsible: meta.isCollapsible === true,
              lwcColClassName,
              _hideForMrcRl05: entry._hideForMrcRl05 === true,
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
      this._scheduleRefreshFileUploadCards();
      //linhdev fix section Account Info + Case Info
      this._ensureAccountCaseSectionsExpanded();
      if (
        isMrcRl05Branch(this.business) &&
        !isMrcRl05CaseInformationBlocked(this.business)
      ) {
        this._applyMrcReturnCaseIntegration();
      }
    });
  }

  //linhdev fix section Account Info + Case Info
  /** Đưa Account Information + Case Information vào active-section-name (sau đổi NOC / resolve LWC động). */
  _ensureAccountCaseSectionsExpanded() {
    if (!this.business?.sectionlst?.length) return;
    const want = new Set([
      SECTION_NAME_ACCOUNT_INFORMATION,
      SECTION_NAME_CASE_INFORMATION,
    ]);
    const extraIds = this.business.sectionlst
      .filter((s) => want.has(s.name))
      .map((s) => s.id)
      .filter(Boolean);
    if (!extraIds.length) return;
    const cur = Array.isArray(this.activeMainSectionlst)
      ? this.activeMainSectionlst
      : [];
    this.activeMainSectionlst = [...new Set([...extraIds, ...cur])];
  }

  /**
   * Đẩy file từ các slot `fec_FileUploadCard` (chế độ local) lên Case khi Save & Close / Submit — nếu LWC expose flush.
   */
  _uploadFecFileUploadCardsIfApplicable() {
    const wrappers = this.template.querySelectorAll(
      '[data-fec-lwc="fec_FileUploadCard"]',
    );
    if (!wrappers || !wrappers.length) {
      return Promise.resolve();
    }
    const promises = [];
    wrappers.forEach((wrap) => {
      const el =
        wrap.querySelector("c-fec_-file-upload-card") ||
        wrap.querySelector("c-fec-file-upload-card");
      if (el && typeof el.flushUploadsToCase === "function") {
        promises.push(Promise.resolve(el.flushUploadsToCase()));
      }
    });
    return promises.length ? Promise.all(promises) : Promise.resolve();
  }

  /**
   * Tìm mọi instance fec_FileUploadCard (tag có thể là c-fec_-file-upload-card hoặc c-fec-file-upload-card tùy runtime).
   */
  _queryFecFileUploadCardElements() {
    const selector = "c-fec_-file-upload-card, c-fec-file-upload-card";
    const seen = new Set();
    const out = [];
    const push = (el) => {
      if (el && !seen.has(el)) {
        seen.add(el);
        out.push(el);
      }
    };
    this.template.querySelectorAll('[data-fec-lwc="fec_FileUploadCard"]').forEach((wrap) => {
      wrap.querySelectorAll(selector).forEach(push);
    });
    this.template.querySelectorAll(selector).forEach(push);
    return out;
  }

  /** DungLT — Sau khi dynamic LWC (lwc:is) mount — reload danh sách file trên fec_FileUploadCard. */
  _scheduleRefreshFileUploadCards() {
    const run = () => {
      this._queryFecFileUploadCardElements().forEach((el) => {
        if (typeof el.refreshFilesFromServer === "function") {
          el.refreshFilesFromServer();
        }
      });
    };
    setTimeout(run, 0);
    setTimeout(run, 400);
  }

  /** DungLT — gọi từ parent (vd. Case Detail) sau submit để refresh danh sách file. */
  @api
  refreshFileUploadCards() {
    this._scheduleRefreshFileUploadCards();
  }

  /** Manual Hold Case (Quick Action) báo refresh qua sessionStorage sau TH1/TH2/TH3. */
  _checkHoldCaseRefreshFlag() {
    if (!this.recordId) {
      return;
    }
    try {
      const key = "fec_hold_case_refresh_" + this.recordId;
      const displayKey = "fec_hold_case_display_" + this.recordId;
      const displayVal = sessionStorage.getItem(displayKey);
      if (displayVal) {
        this.holdCaseResultOverride = displayVal;
      }
      if (sessionStorage.getItem(key)) {
        sessionStorage.removeItem(key);
        sessionStorage.removeItem(displayKey);
        this._refreshHoldCaseAutoDisplay();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => this._refreshHoldCaseAutoDisplay(), 600);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => this._refreshHoldCaseAutoDisplay(), 1200);
      }
    } catch (e) {
      // ignore
    }
  }

  async _initializeHoldCaseVisibility() {
    try {
      const result = await getSubmittedSubProcesses({ caseId: this.recordId });
      this.showHoldCase = !!result.showHoldCase || this.holdCaseResultOnCase;
      this.showHoldCaseManual = !!result.showHoldCaseManual;
      if (!this.holdCaseResultOnCase) {
        this.showHoldCaseAuto = !!result.showHoldCaseAuto;
      }
    } catch (error) {
      console.error("[fec_CaseBussiness] _initializeHoldCaseVisibility ERROR", error);
    }
  }

  _refreshHoldCaseAutoDisplay() {
    this._checkHoldCaseRefreshFlag();
    const initPromise = this._initializeHoldCaseVisibility();
    const promises = [initPromise];
    // if (this.wiredHoldCaseSubProcessesWire) {
    //   promises.push(
    //     refreshApex(this.wiredHoldCaseSubProcessesWire).then(() => {
    //       const data = this.wiredHoldCaseSubProcessesWire?.data;
    //       if (data) {
    //         this._applyHoldCaseSubProcessWireData(data);
    //       }
    //     }),
    //   );
    // }
    if (this.wiredCaseHoldResultWire) {
      promises.push(
        refreshApex(this.wiredCaseHoldResultWire).then(() => {
          const resultVal = getFieldValue(
            this.wiredCaseHoldResultWire?.data,
            FEC_NFU_DESCRIPTION_RESULT,
          );
          this.holdCaseResultOnCase = !!resultVal;
          if (resultVal) {
            this.showHoldCase = true;
            this.showHoldCaseAuto = true;
            if (!this.holdCaseResultOverride) {
              this.holdCaseResultOverride = resultVal;
            }
            this._ensureCaseInformationHoldCaseFlags();
            this.business = { ...this.business };
          }
        }),
      );
    }
    if (this.holdCaseResultOverride) {
      this.showHoldCase = true;
      this.showHoldCaseAuto = true;
    }
    return Promise.all(promises).then(() => {
      if (
        this.showHoldCaseAuto &&
        !this.holdCaseResultOnCase &&
        !this.holdCaseResultOverride
      ) {
        this.holdCaseResultOverride = "PENDING";
        this.showHoldCase = true;
        this._ensureCaseInformationHoldCaseFlags();
        this.business = { ...this.business };
      }
      const autoCmp = this.template.querySelector("c-fec_hold-case-auto");
      if (autoCmp?.refresh) {
        return autoCmp.refresh();
      }
      return undefined;
    });
  }

  /** Refresh Auto Hold Case sau Submit (poll khi Queueable Mark NFU hoàn tất). */
  @api
  refreshAutoHoldCase() {
    // void this._refreshHoldCaseAutoDisplay();
    // const subprocess = this._getSubProcessContainerEl();
    // subprocess?.refreshAutoHoldCase?.();
    const delays = [1500, 4000, 8000, 12000, 20000];
    delays.forEach((delayMs) => {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        this._refreshHoldCaseAutoDisplay();
        const subprocess = this._getSubProcessContainerEl();
        subprocess?.refreshAutoHoldCase?.();
      }, delayMs);
    });
  }

  applyDraft() {
    const draft = JSON.parse(localStorage.getItem(this.draftStorageKey));
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
    let draft = JSON.parse(localStorage.getItem(this.draftStorageKey)) || {};
    const key = objId + '_' + fieldName;
    draft[key] = value;
    localStorage.setItem(this.draftStorageKey, JSON.stringify(draft));
  }
  //Thangtv update logic remove routing action Reject, Cancel after run API success
  removeRoutingActions(actionsToRemove = []) {
    if (!this.business?.routingActionlst) return;

    this.business.routingActionlst = this.business.routingActionlst.filter(
      (a) => !actionsToRemove.includes(a.code || a.value)
    );

    // If current selected value was removed, reset to Resolve
    if (actionsToRemove.includes(this._getCurrentActionCode())) {
      this._setActionValueByCode(ACTION_RESOLVE);
    }

    // this._syncHasRoutingAction(); // PhuongNT cmt, method not exist
    this.business = { ...this.business };
  }
  //Thangtv update logic only show routing action when mode = handling
  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  get showRoutingSection() {
    return (
      this.showLegacyRoutingSection ||
      this.showStage1AutoRouteToRoutingSection ||
      this.showScopedStageChangeRoutingSection
    );
  }

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  get showLegacyRoutingSection() {
    return (
      this.isEdit &&
      this.business?.hasRoutingAction &&
      !this._documentRequestStageChangeRoutingActive &&
      !this._mrcReturnStageChangeRoutingActive &&
      !shouldPreferScopedRoutingFromStage2(this)
    );
  }

  //PhongBT 18/05/26: Document Request — read-only Team/Queue chỉ Stage 1
  get showDocumentRequestStageChangeRoutingSection() {
    return computeShowDocumentRequestStageChangeRoutingSection(this);
  }

  get showMrcReturnStageChangeRoutingSection() {
    return computeShowMrcReturnStageChangeRoutingSection(this);
  }

  get showStage1AutoRouteToRoutingSection() {
    return computeShowStage1AutoRouteToRoutingSection(this);
  }

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  _prepareRoutingSectionForDisplay() {
    if (shouldPreferScopedRoutingFromStage2(this)) {
      this._documentRequestStageChangeRoutingActive = false;
      this._mrcReturnStageChangeRoutingActive = false;
    }
  }

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  _syncActiveRoutingSection() {
    if (this.showScopedStageChangeRoutingSection) {
      this.activeRoutingSectionlst = ["routing-action-scoped"];
    } else if (this.showStage1AutoRouteToRoutingSection) {
      this.activeRoutingSectionlst = ["routing-action-doc-request"];
    } else if (this.showLegacyRoutingSection) {
      this.activeRoutingSectionlst = ["routing-action"];
    } else {
      this.activeRoutingSectionlst = [];
    }
  }

  _documentRequestRoutingFieldOverrides() {
    const overrides = {};
    const closureEl = this._getContractClosureFormEl();
    if (
      closureEl &&
      typeof closureEl.getDeliveryOptionForRouting === "function"
    ) {
      const fromClosure = closureEl.getDeliveryOptionForRouting();
      if (fromClosure) {
        overrides.deliveryOption = fromClosure;
      }
    }
    return overrides;
  }

  /** Delivery / Document Type đổi trên Case Information hoặc fec_ContractClosureForm. */
  _syncDocumentRequestRoutingFromBusinessFields() {
    return this._loadDocumentRequestStageChangeRouting().then(() => {
      this._syncActiveRoutingSection();
      this._syncDocumentRequestRoutingActionSelection();
    });
  }

  handleContractClosureDeliveryChange(event) {
    const combined = event.detail?.deliveryOptionCombined ?? "";
    setBusinessFieldValue(
      this.business,
      Fec_CaseBussiness.DOC_REQ_FIELD_DELIVERY,
      combined,
      "Case",
    );
    this.business = { ...this.business };
    this._syncDocumentRequestRoutingFromBusinessFields();
  }

  //PhongBT 18/05/26: Document Request sử dụng cục routing action mới
  _loadDocumentRequestStageChangeRouting() {
    if (isMrcRl05Branch(this.business)) {
      this._documentRequestStageChangeRoutingActive = false;
      return this._loadMrcReturnStageChangeRouting();
    }

    // Stage 2+ (Document Request / Original MRC Return): luôn Scoped; PhongBT chỉ Stage 1.
    if (shouldPreferScopedRoutingFromStage2(this)) {
      this._documentRequestStageChangeRoutingActive = false;
      this._documentRequestDeliveryEligible = false;
      this.business = { ...this.business };
      return Promise.resolve();
    }

    const ctx = getDocumentRequestRoutingContext(
      this.business,
      this._documentRequestRoutingFieldOverrides(),
    );
    this._documentRequestDeliveryEligible = ctx.deliveryEligible;

    if (!ctx.subCodeSupported || !ctx.team) {
      this._documentRequestStageChangeRoutingActive = false;
      return Promise.resolve();
    }

    this._documentRequestStageChangeRoutingActive = true;

    if (!ctx.deliveryEligible) {
      this.business = {
        ...this.business,
        nextTeam: null,
        nextQueue: null,
      };
      this.business = { ...this.business };
      return Promise.resolve();
    }

    return getDocumentRequestStageChangeRouting({
      caseId: this.recordId,
      teamUserGroup: ctx.team,
    })
      .then((res) => {
        if (res?.nextQueueId) {
          this.business = {
            ...this.business,
            nextTeam: res.nextTeam || ctx.team,
            nextQueue: {
              label: res.nextQueueLabel || STR_EMPTY,
              value: res.nextQueueId,
            },
          };
          this._setActionValueByCode(ACTION_ROUTE_TO);
        } else {
          this.business = {
            ...this.business,
            nextTeam: res?.nextTeam || ctx.team || this.business.nextTeam,
            nextQueue: null,
          };
          this.dispatchEvent(
            new ShowToastEvent({
              title: FEC_Warning_Title,
              message: FEC_MSG_Can_Not_Find_Next_Stage,
              variant: "warning",
            }),
          );
        }
        this.business = { ...this.business };
      })
      .catch((err) => {
        console.error(
          "[DocumentRequestStageChangeRouting]",
          JSON.stringify(err),
        );
        this.business = {
          ...this.business,
          nextTeam: null,
          nextQueue: null,
        };
        this.business = { ...this.business };
      });
  }

  _loadMrcReturnStageChangeRouting(options = {}) {
    const showMissingQueueToast = options.showMissingQueueToast === true;
    if (shouldPreferScopedRoutingFromStage2(this)) {
      this._mrcReturnStageChangeRoutingActive = false;
      return Promise.resolve();
    }

    if (
      !isMrcRl05Branch(this.business) ||
      isMrcRl05CaseInformationBlocked(this.business)
    ) {
      this._mrcReturnStageChangeRoutingActive = false;
      return Promise.resolve();
    }

    if (!shouldActivateMrcReturnRouting(this.business)) {
      this._mrcReturnStageChangeRoutingActive = false;
      return Promise.resolve();
    }

    this._mrcReturnStageChangeRoutingActive = true;

    const priorQueue = this.business?.nextQueue;
    const priorTeam = this.business?.nextTeam;
    const ctx = getMrcReturnRoutingContext(
      this.business,
      this.mrcReturnHandlingOptionValue,
      this.mrcReturnCustomerConfirmationValue,
      this._mrcDeliveryOptionDraft,
    );

    if (!ctx.eligible || !ctx.team) {
      if (priorQueue?.value || priorTeam) {
        this.business = { ...this.business };
        return Promise.resolve();
      }
      this.business = {
        ...this.business,
        nextTeam: null,
        nextQueue: null,
      };
      if (this.business.routingActionlst?.length) {
        this._setActionValueByCode(ACTION_ROUTE_TO);
      }
      this.business = { ...this.business };
      return Promise.resolve();
    }

    const routeToActionId = this._resolveRouteToActionId();
    const teamUserGroup = ctx.teamCode || ctx.team;
    this.business = {
      ...this.business,
      nextTeam: ctx.team,
      nextQueue: priorQueue?.value ? priorQueue : this.business?.nextQueue,
    };
    this._setActionValueByCode(ACTION_ROUTE_TO);
    this.business = { ...this.business };

    return getDocumentRequestStageChangeRouting({
      caseId: this.recordId,
      teamUserGroup,
      routeToActionId,
      previousStageId: this.business?.stage || null,
    })
      .then((res) => {
        if (res?.nextQueueId) {
          this.business = {
            ...this.business,
            nextTeam: res.nextTeam || ctx.team,
            nextQueue: {
              label: res.nextQueueLabel || STR_EMPTY,
              value: res.nextQueueId,
            },
          };
          this._setActionValueByCode(ACTION_ROUTE_TO);
        } else {
          const fallbackQueue =
            priorQueue &&
            (priorQueue.value || priorQueue.label) &&
            (!priorTeam || priorTeam === ctx.team)
              ? priorQueue
              : null;
          this.business = {
            ...this.business,
            nextTeam: ctx.team || res?.nextTeam || priorTeam,
            nextQueue: fallbackQueue,
          };
          if (fallbackQueue) {
            this._setActionValueByCode(ACTION_ROUTE_TO);
          } else if (showMissingQueueToast) {
            this.dispatchEvent(
              new ShowToastEvent({
                title: FEC_Warning_Title,
                message: FEC_MSG_Can_Not_Find_Next_Stage,
                variant: "warning",
              }),
            );
          }
        }
        this.business = { ...this.business };
      })
      .catch((err) => {
        console.error("[MrcReturnStageChangeRouting]", JSON.stringify(err));
        this.business = {
          ...this.business,
          nextTeam: ctx.team || priorTeam,
          nextQueue: priorQueue?.value ? priorQueue : null,
        };
        this.business = { ...this.business };
      });
  }

  _resolveRouteToActionId() {
    const actions = this.business?.routingActionlst || [];
    const match = actions.find((a) => {
      const code = String(a?.code ?? STR_EMPTY).trim();
      const value = String(a?.value ?? STR_EMPTY).trim();
      return code === ACTION_ROUTE_TO || value === ACTION_ROUTE_TO;
    });
    return match?.id ?? null;
  }

  handleMrcDeliveryChange(event) {
    const combined = event.detail?.deliveryOptionCombined ?? STR_EMPTY;
    this._mrcDeliveryOptionDraft = combined;
    this._loadMrcReturnStageChangeRouting({
      showMissingQueueToast: false,
    }).then(() => {
      this._syncActiveRoutingSection();
    });
  }

  // tungnm37 thêm: hiển thị Assignment List khi COF/GSR và Case đã submit
  get showAssignmentList() {
    return this.isRoutingAssignmentMode && this.business?.isSubmited === true;
  }
  // Thangtv updated the logic to send a message to the NOC component to prevent users from changing the NOC value.
  async publishPinReissueResult(status, message = "") {
    const payload = {
      status, // "SUCCESS" | "ERROR"
      caseId: this.recordId,
      message,
    };

    publish(this.messageContext, PIN_REISSUE_MESSAGE_CHANNEL, payload);
  }

  // PhuongNT add get current card status for Card Block/Unblock
  async handleGetCardStatus() {
    const result = await getCardStatus({ recordId: this.recordId });
    console.log('>>>>>handleGetCardStatus: ' + JSON.stringify(result));
    this.currentBlockCode = result?.currentBlockCode;
    this.currentCardStatus = result?.currentCardStatus;
    this.business.sectionlst.forEach(section => {
      section.subSectionlst.forEach(sub => {
        sub.objlst.forEach(obj => {
          obj.fieldlst.forEach(field => {
            if (field.editable) return; // ignore editable
            if (field.apiName === FIELD_CURRENT_CARD_STATUS) {
              field.value = this.currentCardStatus;
              field.displayValue = field.value;
              field.readonlyDisplayValue = field.value;
            }
          });
        });
      });
    });
    // PhuongNT add check process action Card Block
    if (this.business?.code === PROCESS_BLOCK_CARD && this._isEdit) {
      this.handleCheckProcessActionCardBlock();
    }
  }

  // PhuongNT add check process action Card Replacement
  handleCheckProcessAction() {
    this.showProcessAction = false;
    this.isProcessActionInfo = false;
    this.processActionMsg = '';
    checkProcessAction({ caseId: this.recordId })
      .then((result) => {
        if (result.isShowAction) {
          this.showProcessAction = true;
        } else {
          this.isProcessActionInfo = true;
          this.processActionMsg = result.strMsg;
        }
      })
      .catch((error) => {
        console.log(error);
      });
  }

  // PhuongNT add check process action Card Block
  handleCheckProcessActionCardBlock() {
    if (this.currentCardStatus == 'Not Blocked' && this.newBlockCode) {
      this.showProcessAction = true;
      return;
    }
    if (!this.currentBlockCode || !this.newBlockCode) {
      return;
    }
    this.showProcessAction = false;
    this.isProcessActionInfo = false;
    this.isProcessActionFailed = false;
    this.processActionMsg = '';
    checkProcessActionCardBlock({
      currentBlockCode: this.currentBlockCode,
      newBlockCode: this.newBlockCode,
    })
      .then((result) => {
        this.processActionMsg = result.strMsg;
        if (result.isShowAction) {
          this.showProcessAction = true;
        } else if (result.isCancel) {
          this.isProcessActionFailed = true;
        } else {
          this.isProcessActionInfo = true;
        }
      })
      .catch((error) => {
        console.log(error);
      });
  }

  // PhuongNT add handle set update field read only
  handleSetUpdateFieldReadOnly() {
    this.business.sectionlst.forEach(section => {
      section.subSectionlst.forEach(sub => {
        sub.objlst.forEach(obj => {
          obj.fieldlst.forEach(field => {
            if (field.editable) return; // ignore editable
            if (FIELD_READ_ONLY_UPDATE.includes(field.apiName)) {
              field.isUpdateReadOnly = true;
            }
          });
        });
      });
    });
  }

  // PhuongNT add handle save data for fields readonly were changed data by another field
  async handleSaveFieldReadOnly() {
    let mapRecord = new Map();
    const els = this.template.querySelectorAll('[data-id="field-read-only"]');
    els?.forEach(el => {
      const isUpdateReadOnly = el.dataset.isUpdateReadOnly;
      if (!isUpdateReadOnly) return; // ingnore

      const fieldName = el.dataset.field;
      const recordId = el.dataset.recordId;
      const value = el.dataset.value;

      if (mapRecord.has(recordId)) {
        mapRecord.get(recordId)[fieldName] = value;
      } else {
        let fields = {
          'Id': recordId,
          [fieldName]: value
        };
        mapRecord.set(recordId, fields);
      }
    });
    if (mapRecord.size === 0) return;
    try {
      const updatePromises = Array.from(mapRecord.values()).map(fields => {
        const recordInput = { fields };
        console.log('>>>>recordInput: ', JSON.stringify(recordInput));
        return updateRecord(recordInput);
      });
      await Promise.all(updatePromises);
      console.log('Record updated successfully!');
    } catch (error) {
      console.error('Error updating record: ', error);
    }
  }

  // PhuongNT add handle get field value
  handleGetFieldValue() {
    this.business.sectionlst.forEach(section => {
      section.subSectionlst.forEach(sub => {
        sub.objlst.forEach(obj => {
          obj.fieldlst.forEach(field => {
            if (field.apiName === FIELD_NEW_BLOCK_CODE) {
              this.newBlockCode = field.value;
            } else if (field.apiName === FIELD_NEW_BLOCK_CODE_CARD_REPLACE) {
              this.newBlockCodeCardReplace = field.value;
            } else if (field.apiName === FIELD_CARD_REPLACEMENT_FEE) {
              this.cardReplacementFee = field.value;
            } else if (field.apiName === FIELD_LAST_4_DIGIT) {
              this.last4Digit = field.value;
            }
          });
        });
      });
    });
  }

  // PhuongNT send a message to the NOC component to prevent users from changing the NOC value.
  async publishProcessActionResult(status, message = "") {
    const payload = {
      status, // "SUCCESS" | "ERROR"
      caseId: this.recordId,
      message,
    };

    publish(this.messageContext, PROCESS_ACTION_MESSAGE_CHANNEL, payload);
  }

  // Linhdev add handle find routing action by value or code (FEC_Custom_Action_Button_Label__c or FEC_Action_Button__r.FEC_Code__c)
  _findRoutingActionByValueOrCode(valueOrCode) {
    if (!valueOrCode || !this.business?.routingActionlst?.length) {
      return null;
    }
    return (
      this.business.routingActionlst.find(
        (a) => a.value === valueOrCode || a.code === valueOrCode,
      ) || null
    );
  }

  _getRoutingActionValueByCode(code) {
    return this._findRoutingActionByValueOrCode(code)?.value;
  }

  _getCurrentActionCode() {
    return this._findRoutingActionByValueOrCode(this.actionValue)?.code || this.actionValue;
  }

  //PhongBT 19/05/26: Fix mr chuyển routing action của document request sang lwc con
  // // Toannd61 19/05/26 jira 1423: Scoped → Document Request → legacy
  _getRoutingActionSelectEl() {
    return resolveRoutingActionSelectEl(this);
  }

  _setActionValueByCode(code) {
    const optionValue = this._getRoutingActionValueByCode(code);
    if (!optionValue) {
      return;
    }
    this.actionValue = optionValue;
    //PhongBT 19/05/26: Fix mr chuyển routing action của document request sang lwc con
    const routeToEle = this._getRoutingActionSelectEl();
    if (routeToEle) {
      routeToEle.value = optionValue;
    }
  }
  // PhuongNT add reset msg process action
  @api resetMsgProcessAction() {
    this.processActionMsg = '';
    this.isProcessActionSuccessed = false;
    this.isProcessActionFailed = false;
    this.isProcessActionInfo = false;
  }
  // PhuongNT add get card replacement address selected
  @api handleValidateAddressSelected() {
    const wrap = this.template.querySelector(
      '[data-fec-lwc="fec_CardReplacementAddress"]',
    );
    const host = wrap && wrap.firstElementChild;
    if (host && typeof host.getAddressSelectedId === "function") {
      const addressInfoId = host.getAddressSelectedId();
      return addressInfoId;
    }
  }
  // PhuongNT add return current process action
  @api handleGetCurrentProcessAction() {
    return this.business?.code;
  }

  /** RD Payment Stage 2+: assessment đã chọn → khóa combobox Team (read-only từ DB hoặc 'default'). */
  get rdPaymentScopedRouteToLocked() {
    if (!shouldPreferScopedRoutingFromStage2(this)) {
      return false;
    }
    const assessmentVal = this._getCaseFieldValue(FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT);
    if (!assessmentVal || assessmentVal === STR_EMPTY) {
      return false;
    }
    const picklistOptions =
      this.business?.picklistOptionsMap?.Case?.[FIELD_RD_PAYMENT_CONTRACT_ASSESSMENT];
    return (
      !!getRdPaymentScopedStageTeam(assessmentVal, picklistOptions) ||
      !!this.business?.nextTeam
    );
  }

  get showScopedStageChangeRoutingSection() {
    return computeShowScopedStageChangeRoutingSection(this);
  }

  get showLegacyRoutingSectionForDisplay() {
    return computeShowLegacyRoutingSectionForDisplay(this);
  }

  get routeToActionButtonId() {
    return computeRouteToActionButtonId(this);
  }

  handleScopedRoutingFieldChange(event) {
    const { fieldName, value } = event.detail || {};
    this.handleChange({
      target: { name: fieldName },
      detail: { value },
    });
  }

  handleScopedRoutingSelectionChange(event) {
    this._scopedRoutingSelection = event.detail || {};
  }
}