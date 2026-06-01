import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import COMMON_STYLES from "@salesforce/resourceUrl/FEC_CommonCss";
import getRecentRows from "@salesforce/apex/FEC_BatchCaseHandlingController.getRecentRows";
import getCaseFilterPropertyMetadataBundle from "@salesforce/apex/FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadataBundle";
import searchBulkCases from "@salesforce/apex/FEC_BatchCaseHandlingController.searchBulkCases";
import searchBulkCasesForExport from "@salesforce/apex/FEC_BatchCaseHandlingController.searchBulkCasesForExport";
import getSelectedCasesForExport from "@salesforce/apex/FEC_BatchCaseHandlingController.getSelectedCasesForExport";
import getAttachmentCaseSetOptions from "@salesforce/apex/FEC_BatchCaseHandlingController.getAttachmentCaseSetOptions";
import downloadAttachmentsZip from "@salesforce/apex/FEC_BatchCaseHandlingController.downloadAttachmentsZip";
import getBusinessProcessExportRows from "@salesforce/apex/FEC_BatchCaseHandlingController.getBusinessProcessExportRows";
import resolveExportTemplateMeta from "@salesforce/apex/FEC_BatchCaseHandlingController.resolveExportTemplateMeta";
import getBulkExportAllowedBusinessProcessNames from "@salesforce/apex/FEC_BatchCaseHandlingController.getBulkExportAllowedBusinessProcessNames";
import getBulkExportAllowedBusinessProcessCodes from "@salesforce/apex/FEC_BatchCaseHandlingController.getBulkExportAllowedBusinessProcessCodes";
import getTemplateFileBase64 from "@salesforce/apex/FEC_BatchCaseHandlingController.getTemplateFileBase64";
import exportTemplateWorkbook from "@salesforce/apex/FEC_BatchCaseHandlingController.exportTemplateWorkbook";
// 27/05/2026 10:00 linhdev - Export with all Properties: Apex bundle MDS Property theo BP
import getBulkExportPropertyBundle from "@salesforce/apex/FEC_BatchCaseHandlingController.getBulkExportPropertyBundle";
import downloadCaseAttachmentsZip from "@salesforce/apex/FEC_BatchCaseHandlingController.downloadCaseAttachmentsZip";
import zipExcelFiles from "@salesforce/apex/FEC_BatchCaseHandlingController.zipExcelFiles";
import importBatchData from "@salesforce/apex/FEC_BatchCaseHandlingController.importBatchData";
import logFailedImport from "@salesforce/apex/FEC_BatchCaseHandlingController.logFailedImport";
import FEC_SheetJS from "@salesforce/resourceUrl/FEC_SheetJS";
import { STR_EMPTY, DATE_PLACEHOLDER } from "c/fec_CommonConst";
import { arrayBufferToBase64 } from "c/fec_CommonUtils";
import FEC_ACTION_CANCEL from "@salesforce/label/c.FEC_ACTION_CANCEL";
import FEC_Button_Submit from "@salesforce/label/c.FEC_Button_Submit";
import FEC_Go_Button_Label from "@salesforce/label/c.FEC_Go_Button_Label";
import FEC_Go_to_page_label from "@salesforce/label/c.FEC_Go_to_page_label";
import FEC_Btn_Previous from "@salesforce/label/c.FEC_Btn_Previous";
import FEC_Btn_Next from "@salesforce/label/c.FEC_Btn_Next";
import FEC_Button_Refresh from "@salesforce/label/c.FEC_Button_Refresh";
import FEC_TransferCall_Spinner_Loading from "@salesforce/label/c.FEC_TransferCall_Spinner_Loading";
import FEC_BCH_RequestTimeout from "@salesforce/label/c.FEC_BCH_RequestTimeout";
import FEC_BCH_NoDataExport from "@salesforce/label/c.FEC_BCH_NoDataExport";
import FEC_BCH_NoDataFound from "@salesforce/label/c.FEC_BCH_NoDataFound";
import FEC_BCH_ExportSuccess from "@salesforce/label/c.FEC_BCH_ExportSuccess";
import FEC_BCH_ExportFailed from "@salesforce/label/c.FEC_BCH_ExportFailed";
import FEC_BCH_ImportSuccess from "@salesforce/label/c.FEC_BCH_ImportSuccess";
import FEC_BCH_ImportFailed from "@salesforce/label/c.FEC_BCH_ImportFailed";
import FEC_BCH_Import_Submitted from "@salesforce/label/c.FEC_BCH_Import_Submitted";
import FEC_BCH_RequireFile from "@salesforce/label/c.FEC_BCH_RequireFile";
import FEC_BCH_InvalidFileFormat from "@salesforce/label/c.FEC_BCH_InvalidFileFormat";
import FEC_BCH_FileTooLarge from "@salesforce/label/c.FEC_BCH_FileTooLarge";
import FEC_BCH_FileNoData from "@salesforce/label/c.FEC_BCH_FileNoData";
import FEC_BCH_HeaderInvalid from "@salesforce/label/c.FEC_BCH_HeaderInvalid";
import FEC_BCH_BpRequired from "@salesforce/label/c.FEC_BCH_BpRequired";
import FEC_BCH_NoBpFound from "@salesforce/label/c.FEC_BCH_NoBpFound";
import FEC_BCH_TooManyRows from "@salesforce/label/c.FEC_BCH_TooManyRows";
import FEC_BCH_ExportNo from "@salesforce/label/c.FEC_BCH_ExportNo";
import FEC_BCH_ExportYes from "@salesforce/label/c.FEC_BCH_ExportYes";
import FEC_BCH_AttachHas from "@salesforce/label/c.FEC_BCH_AttachHas";
import FEC_BCH_AttachNo from "@salesforce/label/c.FEC_BCH_AttachNo";
import FEC_BCH_ActionPickPlaceholder from "@salesforce/label/c.FEC_BCH_ActionPickPlaceholder";
import FEC_BCH_ActionDownload from "@salesforce/label/c.FEC_BCH_ActionDownload";
import FEC_BCH_ActionExportAll from "@salesforce/label/c.FEC_BCH_ActionExportAll";
import FEC_BCH_ActionExportSelected from "@salesforce/label/c.FEC_BCH_ActionExportSelected";
import FEC_BCH_ActionImportUpdate from "@salesforce/label/c.FEC_BCH_ActionImportUpdate";
import FEC_BCH_ResultHdr_Status from "@salesforce/label/c.FEC_BCH_ResultHdr_Status";
import FEC_BCH_ResultHdr_Errors from "@salesforce/label/c.FEC_BCH_ResultHdr_Errors";
import FEC_BCH_FilterPickProperty from "@salesforce/label/c.FEC_BCH_FilterPickProperty";
import FEC_BCH_FilterPickOperator from "@salesforce/label/c.FEC_BCH_FilterPickOperator";
import FEC_BCH_NoticeTitle from "@salesforce/label/c.FEC_BCH_NoticeTitle";
import FEC_BCH_FilterMetaLoadFailed from "@salesforce/label/c.FEC_BCH_FilterMetaLoadFailed";
import FEC_BCH_SearchFailedTitle from "@salesforce/label/c.FEC_BCH_SearchFailedTitle";
import FEC_BCH_DownloadFailedTitle from "@salesforce/label/c.FEC_BCH_DownloadFailedTitle";
import FEC_BCH_AttachmentDownloadFailedBody from "@salesforce/label/c.FEC_BCH_AttachmentDownloadFailedBody";
import FEC_BCH_ExportToastTitle from "@salesforce/label/c.FEC_BCH_ExportToastTitle";
import FEC_BCH_SelectAtLeastOneCase from "@salesforce/label/c.FEC_BCH_SelectAtLeastOneCase";
import FEC_BCH_DownloadToastTitle from "@salesforce/label/c.FEC_BCH_DownloadToastTitle";
import FEC_BCH_CannotCreateExportFile from "@salesforce/label/c.FEC_BCH_CannotCreateExportFile";
import FEC_BCH_ZipCreatedSuccess from "@salesforce/label/c.FEC_BCH_ZipCreatedSuccess";
import FEC_BCH_ZipCreateFailedBody from "@salesforce/label/c.FEC_BCH_ZipCreateFailedBody";
import FEC_BCH_LoadFailedTitle from "@salesforce/label/c.FEC_BCH_LoadFailedTitle";
import FEC_BCH_InvalidPageTitle from "@salesforce/label/c.FEC_BCH_InvalidPageTitle";
import FEC_BCH_InvalidPageBody from "@salesforce/label/c.FEC_BCH_InvalidPageBody";
import FEC_BCH_UnexpectedError from "@salesforce/label/c.FEC_BCH_UnexpectedError";
import FEC_BCH_ImportUnablePrefix from "@salesforce/label/c.FEC_BCH_ImportUnablePrefix";
import FEC_BCH_DataFileFallback from "@salesforce/label/c.FEC_BCH_DataFileFallback";
import FEC_BCH_EmptyCasesHint from "@salesforce/label/c.FEC_BCH_EmptyCasesHint";
import FEC_BCH_DocumentLinkLabel from "@salesforce/label/c.FEC_BCH_DocumentLinkLabel";
import FEC_BCH_BpItemSingular from "@salesforce/label/c.FEC_BCH_BpItemSingular";
import FEC_BCH_BpItemPlural from "@salesforce/label/c.FEC_BCH_BpItemPlural";
import FEC_BCH_BpItemsSortedSuffix from "@salesforce/label/c.FEC_BCH_BpItemsSortedSuffix";
import FEC_BCH_Section_FilterProperties from "@salesforce/label/c.FEC_BCH_Section_FilterProperties";
import FEC_BCH_FilterHelpAnd from "@salesforce/label/c.FEC_BCH_FilterHelpAnd";
import FEC_BCH_FilterResetHint from "@salesforce/label/c.FEC_BCH_FilterResetHint";
import FEC_BCH_AddFilterRow from "@salesforce/label/c.FEC_BCH_AddFilterRow";
import FEC_BCH_FilterData from "@salesforce/label/c.FEC_BCH_FilterData";
import FEC_BCH_Reset from "@salesforce/label/c.FEC_BCH_Reset";
import FEC_BCH_FilterPropertyField from "@salesforce/label/c.FEC_BCH_FilterPropertyField";
import FEC_BCH_FilterGroupPredefined from "@salesforce/label/c.FEC_BCH_FilterGroupPredefined";
import FEC_BCH_FilterGroupCaseFields from "@salesforce/label/c.FEC_BCH_FilterGroupCaseFields";
import FEC_BCH_FilterColCondition from "@salesforce/label/c.FEC_BCH_FilterColCondition";
import FEC_BCH_FilterColValue from "@salesforce/label/c.FEC_BCH_FilterColValue";
import FEC_BCH_PropertyPlaceholder from "@salesforce/label/c.FEC_BCH_PropertyPlaceholder";
import FEC_BCH_OperatorField from "@salesforce/label/c.FEC_BCH_OperatorField";
import FEC_BCH_ValueField from "@salesforce/label/c.FEC_BCH_ValueField";
import FEC_BCH_RemoveRow from "@salesforce/label/c.FEC_BCH_RemoveRow";
import FEC_BCH_Section_FilteredCases from "@salesforce/label/c.FEC_BCH_Section_FilteredCases";
import FEC_BCH_SelectAll from "@salesforce/label/c.FEC_BCH_SelectAll";
import FEC_BCH_Col_CustomerType from "@salesforce/label/c.FEC_BCH_Col_CustomerType";
import FEC_BCH_Col_CaseId from "@salesforce/label/c.FEC_BCH_Col_CaseId";
import FEC_BCH_Col_Category from "@salesforce/label/c.FEC_BCH_Col_Category";
import FEC_BCH_Col_SubCategory from "@salesforce/label/c.FEC_BCH_Col_SubCategory";
import FEC_BCH_Col_SubCode from "@salesforce/label/c.FEC_BCH_Col_SubCode";
import FEC_BCH_Col_CaseStatus from "@salesforce/label/c.FEC_BCH_Col_CaseStatus";
import FEC_BCH_Col_CaseCreatedOn from "@salesforce/label/c.FEC_BCH_Col_CaseCreatedOn";
import FEC_BCH_Col_LastUpdatedOn from "@salesforce/label/c.FEC_BCH_Col_LastUpdatedOn";
import FEC_BCH_Col_Attachments from "@salesforce/label/c.FEC_BCH_Col_Attachments";
import FEC_BCH_Col_AttachmentDownloaded from "@salesforce/label/c.FEC_BCH_Col_AttachmentDownloaded";
import FEC_BCH_PageSize from "@salesforce/label/c.FEC_BCH_PageSize";
import FEC_BCH_TotalPrefix from "@salesforce/label/c.FEC_BCH_TotalPrefix";
import FEC_BCH_Section_Action from "@salesforce/label/c.FEC_BCH_Section_Action";
import FEC_BCH_SelectActions from "@salesforce/label/c.FEC_BCH_SelectActions";
import FEC_BCH_CaseSet from "@salesforce/label/c.FEC_BCH_CaseSet";
import FEC_BCH_UploadFiles from "@salesforce/label/c.FEC_BCH_UploadFiles";
import FEC_BCH_SelectedCountPrefix from "@salesforce/label/c.FEC_BCH_SelectedCountPrefix";
import FEC_BCH_Err_SelectAction from "@salesforce/label/c.FEC_BCH_Err_SelectAction";
import FEC_BCH_Err_SelectCaseSet from "@salesforce/label/c.FEC_BCH_Err_SelectCaseSet";
import FEC_BCH_Section_MyBulkActions from "@salesforce/label/c.FEC_BCH_Section_MyBulkActions";
import FEC_BCH_Col_FileName from "@salesforce/label/c.FEC_BCH_Col_FileName";
import FEC_BCH_Col_UploadedOn from "@salesforce/label/c.FEC_BCH_Col_UploadedOn";
import FEC_BCH_Col_UploadedBy from "@salesforce/label/c.FEC_BCH_Col_UploadedBy";
import FEC_BCH_Col_TotalRecords from "@salesforce/label/c.FEC_BCH_Col_TotalRecords";
import FEC_BCH_Col_TotalSuccess from "@salesforce/label/c.FEC_BCH_Col_TotalSuccess";
import FEC_BCH_Col_TotalFailed from "@salesforce/label/c.FEC_BCH_Col_TotalFailed";
import FEC_BCH_Col_Status from "@salesforce/label/c.FEC_BCH_Col_Status";
import FEC_BCH_Col_FailureReason from "@salesforce/label/c.FEC_BCH_Col_FailureReason";
import FEC_BCH_Col_Result from "@salesforce/label/c.FEC_BCH_Col_Result";
import FEC_BCH_NoRecordsFound from "@salesforce/label/c.FEC_BCH_NoRecordsFound";
import FEC_BCH_RemoveFile from "@salesforce/label/c.FEC_BCH_RemoveFile";
import FEC_BCH_SortAlt from "@salesforce/label/c.FEC_BCH_SortAlt";
import FEC_BCH_SelectRow from "@salesforce/label/c.FEC_BCH_SelectRow";
import FEC_BCH_Modal_BpSelectionTitle from "@salesforce/label/c.FEC_BCH_Modal_BpSelectionTitle";
import FEC_BCH_Modal_BpColName from "@salesforce/label/c.FEC_BCH_Modal_BpColName";
import FEC_BCH_ExportWithAllProperties from "@salesforce/label/c.FEC_BCH_ExportWithAllProperties";
import FEC_BCH_FooterOf from "@salesforce/label/c.FEC_BCH_FooterOf";

const BATCH_UI = Object.freeze({
  loading: FEC_TransferCall_Spinner_Loading,
  sectionFilterProperties: FEC_BCH_Section_FilterProperties,
  filterHelpAnd: FEC_BCH_FilterHelpAnd,
  filterResetHint: FEC_BCH_FilterResetHint,
  addFilterRow: FEC_BCH_AddFilterRow,
  filterData: FEC_BCH_FilterData,
  reset: FEC_BCH_Reset,
  filterPropertyField: FEC_BCH_FilterPropertyField,
  filterColCondition: FEC_BCH_FilterColCondition,
  filterColValue: FEC_BCH_FilterColValue,
  noFiltersAdded: FEC_BCH_FilterResetHint,
  valueAvailable: FEC_BCH_ValueField,
  valueSelected: FEC_BCH_ValueField,
  propertyPlaceholder: FEC_BCH_PropertyPlaceholder,
  operatorField: FEC_BCH_OperatorField,
  operatorPlaceholder: FEC_BCH_OperatorField,
  valueField: FEC_BCH_ValueField,
  valuePlaceholder: FEC_BCH_ValueField,
  removeRow: FEC_BCH_RemoveRow,
  sectionFilteredCases: FEC_BCH_Section_FilteredCases,
  selectAll: FEC_BCH_SelectAll,
  colCustomerType: FEC_BCH_Col_CustomerType,
  colCaseId: FEC_BCH_Col_CaseId,
  colCategory: FEC_BCH_Col_Category,
  colSubCategory: FEC_BCH_Col_SubCategory,
  colSubCode: FEC_BCH_Col_SubCode,
  colCaseStatus: FEC_BCH_Col_CaseStatus,
  colCaseCreatedOn: FEC_BCH_Col_CaseCreatedOn,
  colLastUpdatedOn: FEC_BCH_Col_LastUpdatedOn,
  colAttachments: FEC_BCH_Col_Attachments,
  colAttachmentDownloaded: FEC_BCH_Col_AttachmentDownloaded,
  pageSize: FEC_BCH_PageSize,
  totalPrefix: FEC_BCH_TotalPrefix,
  previous: FEC_Btn_Previous,
  next: FEC_Btn_Next,
  sectionAction: FEC_BCH_Section_Action,
  selectActions: FEC_BCH_SelectActions,
  caseSet: FEC_BCH_CaseSet,
  uploadFiles: FEC_BCH_UploadFiles,
  submit: FEC_Button_Submit,
  selectedCountPrefix: FEC_BCH_SelectedCountPrefix,
  errSelectAction: FEC_BCH_Err_SelectAction,
  errSelectCaseSet: FEC_BCH_Err_SelectCaseSet,
  errAttachFile: FEC_BCH_RequireFile,
  sectionMyBulkActions: FEC_BCH_Section_MyBulkActions,
  refresh: FEC_Button_Refresh,
  colFileName: FEC_BCH_Col_FileName,
  colUploadedOn: FEC_BCH_Col_UploadedOn,
  colUploadedBy: FEC_BCH_Col_UploadedBy,
  colTotalRecords: FEC_BCH_Col_TotalRecords,
  colTotalSuccess: FEC_BCH_Col_TotalSuccess,
  colTotalFailed: FEC_BCH_Col_TotalFailed,
  colStatus: FEC_BCH_Col_Status,
  colFailureReason: FEC_BCH_Col_FailureReason,
  colResult: FEC_BCH_Col_Result,
  noRecordsFound: FEC_BCH_NoRecordsFound,
  goToPage: FEC_Go_to_page_label,
  go: FEC_Go_Button_Label,
  modalBpTitle: FEC_BCH_Modal_BpSelectionTitle,
  modalBpColName: FEC_BCH_Modal_BpColName,
  sort: FEC_BCH_SortAlt,
  selectRow: FEC_BCH_SelectRow,
  exportWithAllProperties: FEC_BCH_ExportWithAllProperties,
  cancel: FEC_ACTION_CANCEL,
  footerOf: FEC_BCH_FooterOf,
  noBpFound: FEC_BCH_NoBpFound
});

const PAGE_SIZE_OPTIONS = [
  { label: "10", value: "10" },
  { label: "20", value: "20" },
  { label: "30", value: "30" },
  { label: "40", value: "40" },
  { label: "50", value: "50" }
];
const ZIP_TIMEOUT_MS = 60 * 1000;
const ZIP_TIMEOUT_MESSAGE = FEC_BCH_RequestTimeout;
const EXCEL_FILE_TIMEOUT_MS = 30 * 1000;
const EXCEL_FILE_TIMEOUT_MESSAGE = FEC_BCH_RequestTimeout;
const ACTION_DOWNLOAD_ATTACHMENTS = "download_attachments";
const ACTION_EXPORT_ALL = "export_all";
const ACTION_EXPORT_SELECTED = "export_selected";
const ACTION_IMPORT_UPDATE_DATA = "import_update_data";
const MSG_NO_DATA_EXPORT = FEC_BCH_NoDataExport;
const MSG_NO_DATA_FOUND = FEC_BCH_NoDataFound;
const MSG_NO_FILTERS_ADDED = FEC_BCH_FilterResetHint;
const MSG_EXPORT_SUCCESS = FEC_BCH_ExportSuccess;
const MSG_EXPORT_FAILED = FEC_BCH_ExportFailed;
const MSG_IMPORT_SUCCESS = FEC_BCH_ImportSuccess;
const MSG_IMPORT_FAILED = FEC_BCH_ImportFailed;
const MSG_IMPORT_SUBMITTED = FEC_BCH_Import_Submitted;
const IMPORT_STATUS_PROCESSING = "Processing";
const MSG_REQUIRE_FILE = FEC_BCH_RequireFile;
const MSG_INVALID_FILE_FORMAT = FEC_BCH_InvalidFileFormat;
const MSG_FILE_TOO_LARGE = FEC_BCH_FileTooLarge;
const MSG_FILE_NO_DATA = FEC_BCH_FileNoData;
const MSG_HEADER_INVALID = FEC_BCH_HeaderInvalid;
const IMPORT_TIMEOUT_MS = 60 * 1000;
const IMPORT_TIMEOUT_MESSAGE = FEC_BCH_RequestTimeout;
const MAX_UPLOAD_SIZE_BYTES = 150 * 1024 * 1024;
const VALID_FILE_EXTENSION = ".xlsx";
// 30/05/2026 21:00 linhdev - giới hạn Inputted Remarks khớp Excel (32,767 ký tự/ô)
const INPUTTED_REMARKS_MAX_LEN = 32767;
const HEADERS_CASE_ID = ["caseid", "caseidsearch"];
const HEADERS_ROUTING_ACTION = ["routingaction"];
// 29/05/2026 19:30 linhdev - nhận diện cột Inputted Remarks / Input Remark trên template import
const HEADERS_REMARKS = [
  "inputtedremarks",
  "inputtedremark",
  "inputremarks",
  "inputremark"
];
const HEADERS_ASSIGNMENT_ID = ["assignmentid"];
const HEADERS_ASSIGNMENT_ROUTING_ACTION = ["assignmentroutingaction"];
const HEADERS_CS_D2C_ASSESSMENT = [
  "csd2cđánhgiáyêucầu",
  "csd2cdanhgiayeucau",
  "csd2cassessment",
  "csd2cassessmenttype"
];
const HEADERS_CS_SUPPORT_ASSESSMENT = [
  "cssupportđánhgiáyêucầu",
  "cssupportdanhgiayeucau",
  "cssupportassessment",
  "cssupportassessmenttype",
  "cssupportevaluation"
];
const HEADERS_RISK_LEVEL = ["mứcđộrủiro", "mucdoruiro", "risklevel"];
const HEADERS_REQUIRED_ACTION = [
  "hànhđộngcầnthiết",
  "hanhdongcanthiet",
  "requiredaction",
  "requiredcorrectiveaction"
];
const HEADERS_CLASSIFICATION_BY_CS = ["classificationbycs"];
const HEADERS_EVALUATION_BY_CS = ["evaluationbycs"];
const HEADERS_FINAL_PRODUCT = ["finalproduct"];
// 28/05/2026 14:00 linhdev - Payment/CP assessment columns (RefundLoan PM, MRC CP templates)
const HEADERS_PAYMENT_CONTRACT_ASSESSMENT = [
  "paymentđánhgiáyêucầuđónghợpđồng",
  "paymentdanhgiayeucaudonghopdong",
  "paymentcontractassessment",
  "rdpaymentcontractassessment"
];
const HEADERS_CP_ASSESSMENT = [
  "cpđánhgiáyêucầu",
  "cpdanhgiayeucau",
  "cpassessment",
  "contractprocessingassessment"
];
const EXPORT_USER_FILL_HEADERS = new Set([
  ...HEADERS_ROUTING_ACTION,
  ...HEADERS_REMARKS,
  ...HEADERS_ASSIGNMENT_ROUTING_ACTION,
  ...HEADERS_CS_D2C_ASSESSMENT,
  ...HEADERS_CS_SUPPORT_ASSESSMENT,
  ...HEADERS_RISK_LEVEL,
  ...HEADERS_REQUIRED_ACTION,
  ...HEADERS_CLASSIFICATION_BY_CS,
  ...HEADERS_EVALUATION_BY_CS,
  ...HEADERS_FINAL_PRODUCT,
  ...HEADERS_PAYMENT_CONTRACT_ASSESSMENT,
  ...HEADERS_CP_ASSESSMENT
]);
const EXPORT_HEADER_FIELD_MAP = {
  customername: "customerName",
  accountcontractnumber: "accountContractNumber",
  accountandcontractnumber: "accountContractNumber",
  appid: "appId",
  contractstatus: "contractStatus", // Toannd 28/5/2026
  productcode: "productCode", // Toannd 28/5/2026
  loanamount: "loanAmount", // Toannd 28/5/2026
  tenure: "tenure", // Toannd 28/5/2026
  interactionid: "interactionId",
  interactionchannel: "interactionChannel",
  interactionsubchannel: "interactionSubChannel",
  interactionphone: "interactionPhone",
  interactionemail: "interactionEmail",
  casestatus: "caseStatus",
  casecreatedon: "caseCreatedOnLabel",
  lastupdatedon: "lastUpdatedOnLabel",
  complainttype: "complaintType",
  complaintsource: "complaintSource",
  producttype: "productType",
  producttypecode: "productType",
  originalcategory: "originalCategoryDisplay",
  originalsubcategory: "originalSubCategoryDisplay",
  originalsubcode: "originalSubCodeDisplay",
  updatedcategory: "categoryCode",
  updatedsubcategory: "subCategoryDisplay", // Toannd 28/5/2026
  updatedsubcode: "subCodeDisplay", // Toannd 28/5/2026
  category: "categoryCode",
  subcategory: "subCategoryDisplay", // Toannd 28/5/2026
  subcode: "subCodeDisplay", // Toannd 28/5/2026
  caseremarks: "caseRemarks",
  caseremarksenteredby: "caseRemarksEnteredBy",
  caseremarksenteredbyrole: "caseRemarksEnteredByRole",
  caseremarksenteredon: "caseRemarksEnteredOn",
  assignmentid: "assignmentId",
  assignmentowner: "assignmentOwner",
  assignmentremarks: "assignmentRemarks",
  assignmentremarksenteredby: "assignmentRemarksEnteredBy",
  assignmentremarksenteredbyrole: "assignmentRemarksEnteredByRole",
  assignmentremarksenteredon: "assignmentRemarksEnteredOn",
  customertype: "customerType",
  attachments: "hasAttachmentLabel",
  attachment: "hasAttachmentLabel",
  businessprocess: "businessProcessName",
  businessprocessname: "businessProcessName",
  businessprocesscode: "businessProcessCode",
  blocklimitdate: "blockLimitDateLabel",
  blocklimitamount: "blockLimitAmount",
  cccode: "ccCode",
  ccname: "ccName",
  dsacode: "dsaCode",
  dsaname: "dsaName",
  tsacode: "tsaCode",
  tsaname: "tsaName",
  saleschannel: "salesChannel",
  salessubchannel: "salesSubChannel",
  classificationbycs: "classificationByCs",
  evaluationbycs: "evaluationByCs",
  finalproduct: "finalProduct",
  paymentcontractassessment: "paymentContractAssessment", // Toannd 28/5/2026
  rdpaymentcontractassessment: "paymentContractAssessment", // Toannd 28/5/2026
  evaluationbysales: "evaluationBySales",
  disciplineresult: "disciplineResult",
  contactpoint: "contactPoint",
  teamleader: "teamLeader",
  supervisor: "supervisor",
  pendingcssupport: "pendingCsSupportLabel",
  incorrectcontractnumber: "incorrectContractNumber",
  paymentmethod: "paymentMethod",
  billdate: "billDate",
  billamount: "billAmount",
  paymentdate: "paymentDate",
  excessamount: "excessAmount",
  selectedcontractnumber: "selectedContractNumber",
  correctcontractnumber: "correctContractNumber",
  correctaccountcontract: "correctAccountContract",
  correctaccountandcontract: "correctAccountContract",
  adjustedamount: "adjustedAmount"
};
const RESULT_COL_STATUS = "__Status";
const RESULT_COL_ERRORS = "__Errors";
const TEMPLATE_NAME_GSR = "GSR";
const TEMPLATE_NAME_OTHER = "Other";
const MSG_BP_REQUIRED = FEC_BCH_BpRequired;
const MSG_NO_BP_FOUND = FEC_BCH_NoBpFound;
const MSG_TOO_MANY_ROWS = FEC_BCH_TooManyRows;
const EXPORT_MAX_ROWS = 100000;
const EXPORT_FETCH_PAGE_SIZE = 1000;
const EXPORT_PROPERTY_NO = FEC_BCH_ExportNo;
const EXPORT_PROPERTY_YES = FEC_BCH_ExportYes;
const EXPORT_PROPERTY_OPTIONS = [
  { label: FEC_BCH_ExportNo, value: EXPORT_PROPERTY_NO },
  { label: FEC_BCH_ExportYes, value: EXPORT_PROPERTY_YES }
];

const ALLOWED_BULK_EXPORT_BUSINESS_PROCESS_NAMES = [
  "COF - General Flow",
  "GSR - General Flow",
  "Address Update",
  "Phone Update",
  "Document Request",
  "Original MRC Return",
  "Refund Request (Loan)",
  "Incorrect Payment Handling",
  "IPP Closure",
  "Card Unblock",
  "Contract Closure",
  "Card Closure & Refund Request (Card)",
  "Card Replacement",
  "IPP Conversion",
  "Point Redemption",
  "PIN Replacement"
];

const FILTER_SCOPE_PRE_DEFINE = "PRE_DEFINE";
const FILTER_SCOPE_ALL_CASE = "ALL_CASE";
const FILTER_PROPERTY_SCOPE_PRE_DEFINE = "__SCOPE_PRE_DEFINE__";
const FILTER_PROPERTY_SCOPE_ALL_CASE = "__SCOPE_ALL_CASE__";
const PROPERTY_GROUP_PREDEFINED = "PREDEFINED";
const PROPERTY_GROUP_CASE_FIELD = "CASE_FIELD";
const ATTACHMENTS_PROPERTY_KEY = "ATTACHMENTS";

const BOOLEAN_VALUE_OPTIONS = [
  { label: "True", value: "true" },
  { label: "False", value: "false" }
];

const OPERATOR_LABELS = {
  equals: "Equals",
  not_equal_to: "Not equal to",
  contains: "Contains",
  does_not_contain: "Does not contain",
  starts_with: "Starts with",
  does_not_start_with: "Does not start with",
  is_null: "Is null",
  is_not_null: "Is not null",
  less_than: "Less than",
  greater_than: "Greater than",
  less_or_equal: "Less or equal",
  greater_or_equal: "Greater or equal"
};

const ATTACHMENT_VALUE_OPTIONS = [
  { label: FEC_BCH_AttachHas, value: "true" },
  { label: FEC_BCH_AttachNo, value: "false" }
];

const ACTION_OPTIONS = [
  { label: FEC_BCH_ActionPickPlaceholder, value: STR_EMPTY },
  { label: FEC_BCH_ActionDownload, value: ACTION_DOWNLOAD_ATTACHMENTS },
  { label: FEC_BCH_ActionExportAll, value: ACTION_EXPORT_ALL },
  { label: FEC_BCH_ActionExportSelected, value: ACTION_EXPORT_SELECTED },
  { label: FEC_BCH_ActionImportUpdate, value: ACTION_IMPORT_UPDATE_DATA }
];

export default class Fec_BatchCaseHandling extends LightningElement {
  get batchUi() {
    return BATCH_UI;
  }

  @track activeFilterSections = ["filters"];
  @track activeCaseTableSections = ["cases"];
  @track activeActionSections = ["action"];
  @track activeProcessedSections = ["processed"];

  @track rows = [];
  @track pagedRows = [];
  @track isLoading = false;
  @track goToPageInput = "1";

  @track filterPropertyMeta = [];
  @track preDefinePropertyMeta = [];
  @track allCasePropertyMeta = [];
  @track filterPropertyScope = FILTER_SCOPE_PRE_DEFINE;
  @track filterLines = [];
  @track caseRows = [];
  @track caseTotalCount = 0;
  @track casePageSize = "20";
  @track caseSearchPage = 1;
  @track caseGoToPageInput = "1";
  @track caseSearchLoading = false;
  @track caseSearchHasRun = false;
  @track filterResetHint = false;
  @track selectedAction = STR_EMPTY;
  // 30/05/2026 15:33 linhdev - lưu selection theo toàn bộ kết quả filter, không chỉ page hiện tại
  @track selectedCaseIds = [];
  @track deselectedCaseIds = [];
  @track caseSelectAllAcrossPages = false;
  @track caseSetOptions = [];
  @track selectedCaseSet = STR_EMPTY;
  @track actionRequiredError = false;
  @track caseSetRequiredError = false;
  @track caseSortBy = "caseCreatedOn";
  @track caseSortDir = "asc";
  @track bulkSortBy = "uploadedOn";
  @track bulkSortDir = "desc";
  @track exportSuccessMessage = STR_EMPTY;
  @track exportErrorMessage = STR_EMPTY;
  @track importSuccessMessage = STR_EMPTY;
  @track importErrorMessage = STR_EMPTY;
  @track selectedImportFileName = STR_EMPTY;
  @track attachDataRequiredError = false;
  @track isImportSubmitting = false;

  @track showBpModal = false;
  @track bpRows = [];
  @track bpPagedRows = [];
  @track bpPageSize = "10";
  @track bpCurrentPage = 1;
  @track bpGoToPageInput = "1";
  @track bpSortDir = "asc";
  @track includeAllProperties = EXPORT_PROPERTY_NO;
  @track bpSubmitLoading = false;

  currentPage = 1;
  pageSize = "20";
  sheetJsReady = false;
  filterMetaByKey = {};
  preDefineMetaByKey = {};
  allCaseMetaByKey = {};
  fullPropertyOptions = [];
  allowedBulkExportBpSet = null;
  filterUid = 0;
  bpExportUseSelected = false;
  bpExportSourceRows = [];
  bpTemplateMetaByCode = {};
  templateFileCache = {};
  selectedImportFile = null;

  pageSizeOptions = PAGE_SIZE_OPTIONS;
  exportPropertyOptions = EXPORT_PROPERTY_OPTIONS;
  attachmentDownloadedByCase = {};
  actionOptions = ACTION_OPTIONS;
  strEmpty = STR_EMPTY;

  withTimeout(promise, timeoutMs, timeoutMessage) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new Error(timeoutMessage)),
        timeoutMs
      );
      Promise.resolve(promise)
        .then((value) => {
          clearTimeout(timer);
          resolve(value);
        })
        .catch((error) => {
          clearTimeout(timer);
          reject(error);
        });
    });
  }

  isRequestTimeoutError(detail) {
    if (!detail) {
      return false;
    }
    const normalized = String(detail).trim().replace(/\.$/, "");
    const timeoutNorm = String(FEC_BCH_RequestTimeout).trim().replace(/\.$/, "");
    return normalized === timeoutNorm;
  }

  rowBusinessProcessKey(row) {
    const v = (row?.businessProcessCode || row?.businessProcessName || STR_EMPTY)
      .trim();
    return v;
  }

  registerBusinessProcessKeysFromRow(keysFromSource, row) {
    if (!keysFromSource || !row) {
      return;
    }
    const code = String(row.businessProcessCode || STR_EMPTY).trim();
    const name = String(row.businessProcessName || STR_EMPTY).trim();
    const key = String(this.rowBusinessProcessKey(row) || STR_EMPTY).trim();
    [code, name, key].forEach((token) => {
      if (!token || !this.isAllowedBulkExportBusinessProcess(token)) {
        return;
      }
      keysFromSource.set(token.toLowerCase(), token);
    });
  }

  rowMatchesSelectedBusinessProcess(row, selectedBpCodes) {
    const selected = new Set(
      (Array.isArray(selectedBpCodes) ? selectedBpCodes : []).map((c) =>
        String(c || STR_EMPTY).trim().toLowerCase()
      )
    );
    if (!selected.size) {
      return false;
    }
    const code = String(row?.businessProcessCode || STR_EMPTY)
      .trim()
      .toLowerCase();
    const name = String(row?.businessProcessName || STR_EMPTY)
      .trim()
      .toLowerCase();
    const key = String(this.rowBusinessProcessKey(row) || STR_EMPTY)
      .trim()
      .toLowerCase();
    return (
      (code && selected.has(code)) ||
      (name && selected.has(name)) ||
      (key && selected.has(key))
    );
  }

  businessProcessInfoMatchesSourceKeys(bpInfo, keysFromSource) {
    const code = String(bpInfo?.businessProcessCode || STR_EMPTY)
      .trim()
      .toLowerCase();
    const name = String(bpInfo?.businessProcessName || STR_EMPTY)
      .trim()
      .toLowerCase();
    return (
      (code && keysFromSource.has(code)) ||
      (name && keysFromSource.has(name))
    );
  }

  buildAllowedBulkExportBpSet(names, codes) {
    const set = new Set();
    const nameList =
      Array.isArray(names) && names.length
        ? names
        : ALLOWED_BULK_EXPORT_BUSINESS_PROCESS_NAMES;
    nameList.forEach((n) => {
      const k = String(n || STR_EMPTY).trim().toLowerCase();
      if (k) {
        set.add(k);
      }
    });
    const codeList = Array.isArray(codes) ? codes : [];
    codeList.forEach((c) => {
      const k = String(c || STR_EMPTY).trim().toLowerCase();
      if (k) {
        set.add(k);
      }
    });
    this.allowedBulkExportBpSet = set;
  }

  isAllowedBulkExportBusinessProcess(nameOrCode) {
    if (!this.allowedBulkExportBpSet) {
      this.buildAllowedBulkExportBpSet(
        ALLOWED_BULK_EXPORT_BUSINESS_PROCESS_NAMES,
        []
      );
    }
    const k = String(nameOrCode || STR_EMPTY).trim().toLowerCase();
    return Boolean(k) && this.allowedBulkExportBpSet.has(k);
  }

  async loadBulkExportAllowedBusinessProcesses() {
    try {
      const [names, codes] = await Promise.all([
        getBulkExportAllowedBusinessProcessNames(),
        getBulkExportAllowedBusinessProcessCodes()
      ]);
      this.buildAllowedBulkExportBpSet(names, codes);
    } catch {
      this.buildAllowedBulkExportBpSet(
        ALLOWED_BULK_EXPORT_BUSINESS_PROCESS_NAMES,
        []
      );
    }
  }

  async connectedCallback() {
    loadStyle(this, COMMON_STYLES).catch(() => { });
    this.loadAttachmentDownloadedState();
    await this.loadBulkExportAllowedBusinessProcesses();
    await this.loadFilterMetadata();
    this.refreshRows();
  }

  handleProcessedSectionToggle(event) {
    const open = event.detail?.openSections;
    if (Array.isArray(open)) {
      this.activeProcessedSections = [...open];
    }
  }

  handleFilterSectionToggle(event) {
    const open = event.detail?.openSections;
    if (Array.isArray(open)) {
      this.activeFilterSections = [...open];
    }
  }

  handleCaseTableSectionToggle(event) {
    const open = event.detail?.openSections;
    if (Array.isArray(open)) {
      this.activeCaseTableSections = [...open];
    }
  }

  handleActionSectionToggle(event) {
    const open = event.detail?.openSections;
    if (Array.isArray(open)) {
      this.activeActionSections = [...open];
    }
  }

  syncFilterMetaMaps() {
    this.preDefineMetaByKey = {};
    this.allCaseMetaByKey = {};
    this.filterMetaByKey = {};
    (this.preDefinePropertyMeta || []).forEach((m) => {
      if (m?.propertyKey) {
        this.preDefineMetaByKey[m.propertyKey] = m;
        this.filterMetaByKey[m.propertyKey] = m;
      }
    });
    (this.allCasePropertyMeta || []).forEach((m) => {
      if (m?.propertyKey) {
        this.allCaseMetaByKey[m.propertyKey] = m;
        if (!this.filterMetaByKey[m.propertyKey]) {
          this.filterMetaByKey[m.propertyKey] = m;
        }
      }
    });
    this.filterPropertyMeta = [
      ...(this.preDefinePropertyMeta || []),
      ...(this.allCasePropertyMeta || []).filter(
        (m) => m?.propertyGroup === PROPERTY_GROUP_CASE_FIELD
      )
    ];
    this.fullPropertyOptions = this.buildFullPropertyOptions();
  }

  async loadFilterMetadata() {
    try {
      const bundle = await getCaseFilterPropertyMetadataBundle();
      this.preDefinePropertyMeta = Array.isArray(bundle?.preDefineProperties)
        ? bundle.preDefineProperties
        : [];
      this.allCasePropertyMeta = Array.isArray(bundle?.allCaseProperties)
        ? bundle.allCaseProperties
        : [];
      this.syncFilterMetaMaps();
      this.pruneFilterLinesForScope();
    } catch (error) {
      this.preDefinePropertyMeta = [];
      this.allCasePropertyMeta = [];
      this.filterPropertyMeta = [];
      this.filterMetaByKey = {};
      this.preDefineMetaByKey = {};
      this.allCaseMetaByKey = {};
      this.fullPropertyOptions = [];
      this.showInfo(
        FEC_BCH_NoticeTitle,
        `${FEC_BCH_FilterMetaLoadFailed} ${this.extractError(error)}`
      );
    }
  }

  addFilterLine() {
    this.filterUid += 1;
    this.filterResetHint = false;
    this.filterLines = [
      ...this.filterLines,
      {
        rowId: `fl-${this.filterUid}`,
        filterScope: STR_EMPTY,
        propertyKey: STR_EMPTY,
        operatorKey: STR_EMPTY,
        valueText: STR_EMPTY
      }
    ];
  }

  handleAddFilterLine() {
    this.addFilterLine();
  }

  isFilterScopePropertyKey(propertyKey) {
    return (
      propertyKey === FILTER_PROPERTY_SCOPE_PRE_DEFINE ||
      propertyKey === FILTER_PROPERTY_SCOPE_ALL_CASE
    );
  }

  pruneFilterLinesForScope() {
    const validKeys = new Set(Object.keys(this.filterMetaByKey || {}));
    this.filterLines = (this.filterLines || []).map((line) => {
      if (!line.propertyKey) {
        return line;
      }
      if (!validKeys.has(line.propertyKey)) {
        return {
          ...line,
          propertyKey: STR_EMPTY,
          operatorKey: STR_EMPTY,
          valueText: STR_EMPTY,
          valueList: []
        };
      }
      return line;
    });
  }

  resolveFilterScopeForPropertyKey(propertyKey) {
    if (this.preDefineMetaByKey[propertyKey]) {
      return FILTER_SCOPE_PRE_DEFINE;
    }
    if (this.allCaseMetaByKey[propertyKey]) {
      return FILTER_SCOPE_ALL_CASE;
    }
    return this.filterPropertyScope;
  }

  handleRemoveFilterLine(event) {
    const rowId = event.currentTarget?.dataset?.rowid;
    if (!rowId) {
      return;
    }
    this.filterResetHint = false;
    this.filterLines = this.filterLines.filter((l) => l.rowId !== rowId);
  }

  toBoldUnicode(text) {
    if (!text) {
      return text;
    }
    let out = STR_EMPTY;
    for (let i = 0; i < text.length; i += 1) {
      const ch = text[i];
      const code = ch.charCodeAt(0);
      if (code >= 65 && code <= 90) {
        out += String.fromCodePoint(0x1d400 + (code - 65));
      } else if (code >= 97 && code <= 122) {
        out += String.fromCodePoint(0x1d41a + (code - 97));
      } else if (code >= 48 && code <= 57) {
        out += String.fromCodePoint(0x1d7ce + (code - 48));
      } else {
        out += ch;
      }
    }
    return out;
  }

  buildFullPropertyOptions() {
    const preDefineFields = (this.preDefinePropertyMeta || [])
      .filter((m) => m?.propertyKey)
      .map((m) => ({
        label: m.label || m.propertyKey,
        value: m.propertyKey
      }));
    const allCaseFields = (this.allCasePropertyMeta || [])
      .filter(
        (m) =>
          m?.propertyKey && m.propertyGroup === PROPERTY_GROUP_CASE_FIELD
      )
      .map((m) => ({
        label: m.label || m.propertyKey,
        value: m.propertyKey
      }));
    return [
      {
        label: this.toBoldUnicode(FEC_BCH_FilterGroupPredefined),
        value: FILTER_PROPERTY_SCOPE_PRE_DEFINE,
        disabled: true
      },
      ...preDefineFields,
      {
        label: this.toBoldUnicode(FEC_BCH_FilterGroupCaseFields),
        value: FILTER_PROPERTY_SCOPE_ALL_CASE,
        disabled: true
      },
      ...allCaseFields
    ];
  }

  propertyOptionsForLine() {
    return this.fullPropertyOptions || [];
  }

  resolvePropertyComboboxValue(line) {
    if (
      line?.propertyKey &&
      !this.isFilterScopePropertyKey(line.propertyKey)
    ) {
      return line.propertyKey;
    }
    return STR_EMPTY;
  }

  operatorOptionsForLine(line) {
    const meta = this.lineMeta(line);
    const ops = meta?.operators || [];
    const opts = [{ label: FEC_BCH_FilterPickOperator, value: STR_EMPTY }];
    ops.forEach((op) => {
      opts.push({
        label: OPERATOR_LABELS[op] || op,
        value: op
      });
    });
    return opts;
  }

  handleFilterPropertyChange(event) {
    this.filterResetHint = false;
    const rowId = event.currentTarget?.dataset?.rowid;
    const value = event.detail?.value || STR_EMPTY;
    if (!value) {
      this.filterLines = this.filterLines.map((l) =>
        l.rowId === rowId
          ? {
            ...l,
            filterScope: STR_EMPTY,
            propertyKey: STR_EMPTY,
            operatorKey: STR_EMPTY,
            valueText: STR_EMPTY,
            valueList: []
          }
          : l
      );
      return;
    }
    if (
      value === FILTER_PROPERTY_SCOPE_PRE_DEFINE ||
      value === FILTER_PROPERTY_SCOPE_ALL_CASE
    ) {
      return;
    }
    const nextScope = value
      ? this.resolveFilterScopeForPropertyKey(value)
      : this.filterPropertyScope;
    if (nextScope !== this.filterPropertyScope) {
      this.filterPropertyScope = nextScope;
      this.caseRows = [];
      this.caseTotalCount = 0;
      this.caseSearchHasRun = false;
      this.caseSearchPage = 1;
      this.syncCaseGoToPageInput();
    }
    this.filterLines = this.filterLines.map((l) => {
      if (l.rowId !== rowId) {
        return l;
      }
      const meta = value
        ? this.preDefineMetaByKey[value] ||
        this.allCaseMetaByKey[value] ||
        this.filterMetaByKey[value]
        : null;
      const firstOp =
        meta?.operators && meta.operators.length ? meta.operators[0] : STR_EMPTY;
      const isAttachments = value === ATTACHMENTS_PROPERTY_KEY;
      return {
        ...l,
        filterScope: nextScope,
        propertyKey: value,
        operatorKey: isAttachments ? "equals" : firstOp,
        valueText: STR_EMPTY,
        valueList: [],
        attachmentChecked: isAttachments ? true : undefined
      };
    });
  }

  handleFilterAttachmentConditionChange(event) {
    this.filterResetHint = false;
    const rowId = event.currentTarget?.dataset?.rowid;
    const checked = !!event.detail?.checked;
    this.filterLines = this.filterLines.map((l) =>
      l.rowId === rowId ? { ...l, attachmentChecked: checked } : l
    );
  }

  isAttachmentsFilterLine(line) {
    return line?.propertyKey === ATTACHMENTS_PROPERTY_KEY;
  }

  showAttachmentConditionCheckbox(line) {
    return this.isAttachmentsFilterLine(line);
  }

  showOperatorCombobox(line) {
    return !!line?.propertyKey && !this.isAttachmentsFilterLine(line);
  }

  showAttachmentValueLabel(line) {
    return this.isAttachmentsFilterLine(line);
  }

  attachmentValueLabelForLine(line) {
    return line?.attachmentChecked !== false
      ? FEC_BCH_AttachHas
      : FEC_BCH_AttachNo;
  }

  attachmentCheckedForLine(line) {
    return line?.attachmentChecked !== false;
  }

  handleFilterOperatorChange(event) {
    this.filterResetHint = false;
    const rowId = event.currentTarget?.dataset?.rowid;
    const value = event.detail?.value || STR_EMPTY;
    this.filterLines = this.filterLines.map((l) =>
      l.rowId === rowId ? { ...l, operatorKey: value } : l
    );
  }

  handleFilterValueChange(event) {
    this.filterResetHint = false;
    const rowId = event.currentTarget?.dataset?.rowid;
    const value = event.detail?.value ?? STR_EMPTY;
    this.filterLines = this.filterLines.map((l) =>
      l.rowId === rowId ? { ...l, valueText: value } : l
    );
  }

  valueInputType(line) {
    const meta = this.lineMeta(line);
    if (!meta) {
      return "text";
    }
    if (meta.valueType === "date") {
      return "date";
    }
    return "text";
  }

  valueDateStyleForLine(line) {
    if (this.isDateFilterLine(line)) {
      return "short";
    }
    return null;
  }

  isDateFilterLine(line) {
    const meta = this.lineMeta(line);
    return meta?.valueType === "date";
  }

  normalizeDatePayloadValue(rawValue) {
    const value = (rawValue || STR_EMPTY).trim();
    if (!value) {
      return STR_EMPTY;
    }
    const dmy = this.parseDmyDateParts(value);
    if (dmy) {
      return this.formatAsIso(dmy.day, dmy.month, dmy.year);
    }
    const iso = this.parseIsoDateParts(value);
    if (iso) {
      return this.formatAsIso(iso.day, iso.month, iso.year);
    }
    return STR_EMPTY;
  }

  parseDmyDateParts(value) {
    const m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(value);
    if (!m) {
      return null;
    }
    const day = parseInt(m[1], 10);
    const month = parseInt(m[2], 10);
    const year = parseInt(m[3], 10);
    return this.isValidDateParts(day, month, year)
      ? { day, month, year }
      : null;
  }

  parseIsoDateParts(value) {
    const m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(value);
    if (!m) {
      return null;
    }
    const year = parseInt(m[1], 10);
    const month = parseInt(m[2], 10);
    const day = parseInt(m[3], 10);
    return this.isValidDateParts(day, month, year)
      ? { day, month, year }
      : null;
  }

  isValidDateParts(day, month, year) {
    if (
      Number.isNaN(day) ||
      Number.isNaN(month) ||
      Number.isNaN(year) ||
      year < 1000 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31
    ) {
      return false;
    }
    const d = new Date(year, month - 1, day);
    return (
      d.getFullYear() === year &&
      d.getMonth() === month - 1 &&
      d.getDate() === day
    );
  }

  twoDigits(value) {
    return value < 10 ? "0" + String(value) : String(value);
  }

  formatAsDmy(day, month, year) {
    return this.twoDigits(day) + "/" + this.twoDigits(month) + "/" + String(year);
  }

  formatAsIso(day, month, year) {
    return String(year) + "-" + this.twoDigits(month) + "-" + this.twoDigits(day);
  }

  valuePlaceholderForLine(line) {
    if (this.isDateFilterLine(line)) {
      return DATE_PLACEHOLDER;
    }
    return BATCH_UI.valuePlaceholder;
  }

  showValueInput(line) {
    if (!this.operatorNeedsValue(line)) {
      return false;
    }
    if (
      this.showAttachmentValueCombobox(line) ||
      this.showBooleanValueCombobox(line) ||
      this.showValuePicklistCombobox(line) ||
      this.showMultiPicklistValue(line) ||
      this.showDefaultValueInput(line)
    ) {
      return false;
    }
    const meta = this.lineMeta(line);
    if (!meta || meta.valueType === "checkbox") {
      return false;
    }
    return meta.valueType === "date" || meta.valueType === "text";
  }

  lineMeta(line) {
    if (!line?.propertyKey) {
      return null;
    }
    if (
      line.filterScope === FILTER_SCOPE_PRE_DEFINE &&
      this.preDefineMetaByKey[line.propertyKey]
    ) {
      return this.preDefineMetaByKey[line.propertyKey];
    }
    if (
      line.filterScope === FILTER_SCOPE_ALL_CASE &&
      this.allCaseMetaByKey[line.propertyKey]
    ) {
      return this.allCaseMetaByKey[line.propertyKey];
    }
    if (this.preDefineMetaByKey[line.propertyKey]) {
      return this.preDefineMetaByKey[line.propertyKey];
    }
    if (this.allCaseMetaByKey[line.propertyKey]) {
      return this.allCaseMetaByKey[line.propertyKey];
    }
    return this.filterMetaByKey[line.propertyKey] || null;
  }

  operatorNeedsValue(line) {
    const op = (line?.operatorKey || STR_EMPTY).toLowerCase();
    return op !== "is_null" && op !== "is_not_null";
  }

  showAttachmentValueCombobox(line) {
    return false;
  }

  showBooleanValueCombobox(line) {
    const meta = this.lineMeta(line);
    if (!meta || meta.valueType !== "checkbox") {
      return false;
    }
    if (this.isAttachmentsFilterLine(line)) {
      return false;
    }
    return this.operatorNeedsValue(line);
  }

  showValuePicklistCombobox(line) {
    const meta = this.lineMeta(line);
    if (!meta || !this.operatorNeedsValue(line)) {
      return false;
    }
    if (meta.multiValue === true) {
      return false;
    }
    return meta.valueType === "picklist" && (meta.picklistOptions || []).length > 0;
  }

  showMultiPicklistValue(line) {
    const meta = this.lineMeta(line);
    if (!meta || !this.operatorNeedsValue(line)) {
      return false;
    }
    return (
      meta.multiValue === true ||
      meta.valueType === "multipicklist"
    ) && (meta.picklistOptions || []).length > 0;
  }

  showDefaultValueInput(line) {
    const meta = this.lineMeta(line);
    if (!meta || !this.operatorNeedsValue(line)) {
      return false;
    }
    if (
      meta.valueType === "checkbox" ||
      meta.valueType === "picklist" ||
      meta.valueType === "multipicklist" ||
      meta.multiValue === true
    ) {
      return false;
    }
    return meta.valueType === "text";
  }

  valueInputDisabled(line) {
    return !this.operatorNeedsValue(line);
  }

  valuePicklistOptionsForLine(line) {
    const meta = this.lineMeta(line);
    const opts = [{ label: FEC_BCH_FilterPickProperty, value: STR_EMPTY }];
    (meta?.picklistOptions || []).forEach((o) => {
      if (o?.value) {
        opts.push({ label: o.label || o.value, value: o.value });
      }
    });
    return opts;
  }

  multiPicklistOptionsForLine(line) {
    return (this.lineMeta(line)?.picklistOptions || [])
      .filter((o) => o?.value)
      .map((o) => ({ label: o.label || o.value, value: o.value }));
  }

  multiPicklistSizeForLine(line) {
    const count = this.multiPicklistOptionsForLine(line).length;
    if (count <= 3) {
      return 3;
    }
    if (count <= 6) {
      return count;
    }
    return 6;
  }

  filterRowClass(line) {
    let cls = "fec-filter-row fec-filter-table__row";
    if (this.showMultiPicklistValue(line)) {
      cls += " fec-filter-table__row--multi";
    }
    if (this.isAttachmentsFilterLine(line)) {
      cls += " fec-filter-table__row--attach";
    }
    return cls;
  }

  handleFilterValueListChange(event) {
    this.filterResetHint = false;
    const rowId = event.currentTarget?.dataset?.rowid;
    const valueList = event.detail?.value || [];
    this.filterLines = this.filterLines.map((l) =>
      l.rowId === rowId ? { ...l, valueList: [...valueList], valueText: STR_EMPTY } : l
    );
  }

  get booleanPicklistOptions() {
    return BOOLEAN_VALUE_OPTIONS;
  }

  get filterLinesView() {
    return (this.filterLines || []).map((line) => {
      return {
        ...line,
        filterRowClass: this.filterRowClass(line),
        propertyComboboxValue: this.resolvePropertyComboboxValue(line),
        propertyOptions: this.propertyOptionsForLine(line),
        operatorOptions: this.operatorOptionsForLine(line),
        showFilterCriteria: !!line.propertyKey,
        showOperatorCombobox: this.showOperatorCombobox(line),
        showAttachConditionCheckbox: this.showAttachmentConditionCheckbox(line),
        attachmentConditionChecked: this.attachmentCheckedForLine(line),
        showAttachmentValueLabel: this.showAttachmentValueLabel(line),
        attachmentValueLabel: this.attachmentValueLabelForLine(line),
        showValueBox: this.showValueInput(line),
        showAttachCombo: this.showAttachmentValueCombobox(line),
        showBooleanCombo: this.showBooleanValueCombobox(line),
        showValuePicklist: this.showValuePicklistCombobox(line),
        showValueMultiPicklist: this.showMultiPicklistValue(line),
        showValueDefault: this.showDefaultValueInput(line),
        valuePicklistOptions: this.valuePicklistOptionsForLine(line),
        multiPicklistOptions: this.multiPicklistOptionsForLine(line),
        multiPicklistSize: this.multiPicklistSizeForLine(line),
        valueList: Array.isArray(line.valueList) ? line.valueList : [],
        valueInputDisabled: this.valueInputDisabled(line),
        valueTypeAttr: this.valueInputType(line),
        valueDateStyle: this.valueDateStyleForLine(line),
        valuePlaceholder: this.valuePlaceholderForLine(line)
      };
    });
  }

  get attachmentPicklistOptions() {
    return ATTACHMENT_VALUE_OPTIONS;
  }

  buildFiltersPayload() {
    const out = [];
    for (const line of this.filterLines) {
      if (
        !line.filterScope ||
        !line.propertyKey ||
        !line.operatorKey ||
        this.isFilterScopePropertyKey(line.propertyKey)
      ) {
        continue;
      }
      const op = (line.operatorKey || STR_EMPTY).toLowerCase();
      const needsValue = op !== "is_null" && op !== "is_not_null";
      let valueText = (line.valueText || STR_EMPTY).trim();
      let operatorKey = line.operatorKey;
      let valueList = null;
      if (this.isAttachmentsFilterLine(line)) {
        operatorKey = "equals";
        valueText = line.attachmentChecked !== false ? "true" : "false";
      }
      if (Array.isArray(line.valueList) && line.valueList.length) {
        valueList = line.valueList.filter((v) => v);
        valueText = STR_EMPTY;
      } else if (
        (line.propertyKey === "CUSTOMER_TYPE" || line.propertyKey === "QUEUE") &&
        valueText.includes(",")
      ) {
        valueList = valueText
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean);
        valueText = STR_EMPTY;
      }
      if (needsValue && this.isDateFilterLine(line)) {
        valueText = this.normalizeDatePayloadValue(valueText);
      }
      if (needsValue && !valueText && (!valueList || !valueList.length)) {
        continue;
      }
      const entry = {
        propertyKey: line.propertyKey,
        operatorKey,
        valueText
      };
      if (valueList && valueList.length) {
        entry.valueList = valueList;
      }
      out.push(entry);
    }
    return out;
  }

  syncCaseGoToPageInput() {
    this.caseGoToPageInput = String(this.caseSearchPage);
  }

  clearCaseSelection() {
    this.selectedCaseIds = [];
    this.deselectedCaseIds = [];
    this.caseSelectAllAcrossPages = false;
  }

  // 30/05/2026 15:33 linhdev - dùng caseId dạng string để giữ selection ổn định khi chuyển page
  caseIdKey(id) {
    return String(id || STR_EMPTY);
  }

  updateCaseIdList(list, caseId, checked) {
    const key = this.caseIdKey(caseId);
    if (!key) {
      return list;
    }
    if (checked) {
      return list.includes(key) ? list : [...list, key];
    }
    return list.filter((id) => id !== key);
  }

  isCaseSelected(caseId) {
    const key = this.caseIdKey(caseId);
    if (!key) {
      return false;
    }
    if (this.caseSelectAllAcrossPages) {
      return !this.deselectedCaseIds.includes(key);
    }
    return this.selectedCaseIds.includes(key);
  }

  async handleFilterData() {
    this.filterResetHint = false;
    this.caseSearchPage = 1;
    this.syncCaseGoToPageInput();
    this.exportSuccessMessage = STR_EMPTY;
    this.exportErrorMessage = STR_EMPTY;
    this.clearCaseSelection();
    await this.runCaseSearch();
  }

  async handleResetFilters() {
    this.filterResetHint = true;
    this.caseSearchHasRun = false;
    this.filterPropertyScope = FILTER_SCOPE_PRE_DEFINE;
    this.filterLines = [];
    this.syncFilterMetaMaps();
    this.caseRows = [];
    this.caseTotalCount = 0;
    this.caseSearchPage = 1;
    this.syncCaseGoToPageInput();
    this.clearCaseSelection();
    this.exportSuccessMessage = STR_EMPTY;
    this.exportErrorMessage = STR_EMPTY;
  }

  async runCaseSearch() {
    const payload = this.buildFiltersPayload();
    if (!payload.length) {
      this.caseRows = [];
      this.caseTotalCount = 0;
      this.caseSearchHasRun = false;
      this.caseSearchLoading = false;
      return;
    }
    this.caseSearchLoading = true;
    try {
      const filtersJson = JSON.stringify(payload);
      const ps = Number(this.casePageSize) || 10;
      const res = await searchBulkCases({
        filtersJson,
        pageSize: ps,
        pageNumber: this.caseSearchPage
      });
      this.caseTotalCount = res?.totalCount ?? 0;
      const raw = Array.isArray(res?.rows) ? res.rows : [];
      this.caseRows = raw.map((r) => ({
        ...r,
        rowKey: String(r.caseId || STR_EMPTY),
        selected: this.isCaseSelected(r.caseId),
        caseCreatedOnLabel: this.formatDateTimeSafe(r.caseCreatedOn),
        lastUpdatedOnLabel: this.formatDateTimeSafe(r.lastUpdatedOn),
        hasAttachmentLabel: r.hasAttachment ? FEC_BCH_DocumentLinkLabel : STR_EMPTY,
        attachmentDownloaded: !!this.attachmentDownloadedByCase[String(r.caseId || STR_EMPTY)]
      }));
      this.applyCaseSort();
      this.caseSearchHasRun = true;
      this.syncCaseGoToPageInput();
    } catch (error) {
      this.caseRows = [];
      this.caseTotalCount = 0;
      this.caseSearchHasRun = false;
      this.showError(FEC_BCH_SearchFailedTitle, this.extractError(error));
    } finally {
      this.caseSearchLoading = false;
    }
  }

  formatDateTimeSafe(value) {
    if (value == null || value === STR_EMPTY) {
      return STR_EMPTY;
    }
    return this.formatDateTime(value);
  }

  get casePageSizeNum() {
    return Number(this.casePageSize) || 10;
  }

  get caseTotalPages() {
    return Math.max(1, Math.ceil(this.caseTotalCount / this.casePageSizeNum));
  }

  get casePreviousDisabled() {
    return this.caseSearchPage <= 1;
  }

  get caseNextDisabled() {
    return this.caseSearchPage >= this.caseTotalPages;
  }

  caseSortIconFor(key) {
    if (this.caseSortBy !== key) {
      return "utility:arrowdown";
    }
    return this.caseSortDir === "desc" ? "utility:arrowdown" : "utility:arrowup";
  }

  get caseSortIconCustomerType() {
    return this.caseSortIconFor("customerType");
  }

  get caseSortIconCaseId() {
    return this.caseSortIconFor("caseIdSearch");
  }

  get caseSortIconCategory() {
    return this.caseSortIconFor("categoryCode");
  }

  get caseSortIconSubCategory() {
    return this.caseSortIconFor("subCategoryCode");
  }

  get caseSortIconSubCode() {
    return this.caseSortIconFor("subCodeCode");
  }

  get caseSortIconCaseStatus() {
    return this.caseSortIconFor("caseStatus");
  }

  get caseSortIconCaseCreatedOn() {
    return this.caseSortIconFor("caseCreatedOn");
  }

  get caseSortIconLastUpdatedOn() {
    return this.caseSortIconFor("lastUpdatedOn");
  }

  get caseSortIconAttachments() {
    return this.caseSortIconFor("hasAttachment");
  }

  get caseSortIconAttachmentDownloaded() {
    return "utility:arrowdown";
  }

  bulkSortIconFor(key) {
    if (this.bulkSortBy !== key) {
      return "utility:arrowdown";
    }
    return this.bulkSortDir === "desc" ? "utility:arrowdown" : "utility:arrowup";
  }

  get bulkSortIconFileName() {
    return this.bulkSortIconFor("fileName");
  }

  get bulkSortIconUploadedOn() {
    return this.bulkSortIconFor("uploadedOn");
  }

  get bulkSortIconUploadedBy() {
    return this.bulkSortIconFor("uploadedBy");
  }

  get bulkSortIconTotalRecords() {
    return this.bulkSortIconFor("totalRecordsCount");
  }

  get bulkSortIconTotalSuccess() {
    return this.bulkSortIconFor("totalSuccessRecords");
  }

  get bulkSortIconTotalFailed() {
    return this.bulkSortIconFor("totalFailedRecords");
  }

  get bulkSortIconStatus() {
    return this.bulkSortIconFor("status");
  }

  get bulkSortIconFailureReason() {
    return this.bulkSortIconFor("failureReason");
  }

  get bulkSortIconResult() {
    return this.bulkSortIconFor("result");
  }

  get hasCaseRows() {
    return this.caseRows.length > 0;
  }

  get hasValidFilterPayload() {
    return this.buildFiltersPayload().length > 0;
  }

  get filterDataDisabled() {
    return this.caseSearchLoading || !this.hasValidFilterPayload;
  }

  get showNoFiltersAdded() {
    return !(this.filterLines || []).length;
  }

  get showNoFiltersAddedHint() {
    return this.filterResetHint || !this.hasValidFilterPayload;
  }

  get noFiltersAddedMessage() {
    return MSG_NO_FILTERS_ADDED;
  }

  get emptyCasesMessage() {
    if (this.caseSearchHasRun) {
      return MSG_NO_DATA_FOUND;
    }
    return FEC_BCH_EmptyCasesHint;
  }

  get selectedCaseCount() {
    if (this.caseSelectAllAcrossPages) {
      return Math.max(0, this.caseTotalCount - this.deselectedCaseIds.length);
    }
    return this.selectedCaseIds.length;
  }

  get allCaseRowsSelected() {
    return (
      this.caseRows.length > 0 &&
      this.caseRows.every((r) => r.selected)
    );
  }

  handleCasePageSizeChange(event) {
    this.casePageSize = event.detail.value;
    this.caseSearchPage = 1;
    this.syncCaseGoToPageInput();
    this.runCaseSearch();
  }

  handleCasePreviousPage() {
    if (this.caseSearchPage <= 1) {
      return;
    }
    this.caseSearchPage -= 1;
    this.caseGoToPageInput = String(this.caseSearchPage);
    this.runCaseSearch();
  }

  handleCaseNextPage() {
    if (this.caseSearchPage >= this.caseTotalPages) {
      return;
    }
    this.caseSearchPage += 1;
    this.caseGoToPageInput = String(this.caseSearchPage);
    this.runCaseSearch();
  }

  handleCaseGoToPageInput(event) {
    this.caseGoToPageInput = event.detail.value;
  }

  handleCaseGoToPage() {
    const n = parseInt(this.caseGoToPageInput, 10);
    if (Number.isNaN(n) || n < 1) {
      this.showInfo(FEC_BCH_InvalidPageTitle, FEC_BCH_InvalidPageBody);
      return;
    }
    const target = Math.min(Math.max(1, n), this.caseTotalPages);
    this.caseSearchPage = target;
    this.caseGoToPageInput = String(target);
    this.runCaseSearch();
  }

  handleCaseRowSelect(event) {
    const id = event.currentTarget?.dataset?.caseid;
    const checked = !!event.detail?.checked;
    // 30/05/2026 15:33 linhdev - khi select all across pages, chỉ lưu các dòng bị bỏ chọn làm ngoại lệ
    if (this.caseSelectAllAcrossPages) {
      this.deselectedCaseIds = this.updateCaseIdList(
        this.deselectedCaseIds,
        id,
        !checked
      );
    } else {
      this.selectedCaseIds = this.updateCaseIdList(
        this.selectedCaseIds,
        id,
        checked
      );
    }
    this.caseRows = this.caseRows.map((r) =>
      r.caseId === id ? { ...r, selected: checked } : r
    );
  }

  handleCaseSelectAll(event) {
    const checked = !!event.detail?.checked;
    // 30/05/2026 15:33 linhdev - checkbox header áp dụng cho toàn bộ kết quả filter trên các page
    this.caseSelectAllAcrossPages = checked;
    this.selectedCaseIds = [];
    this.deselectedCaseIds = [];
    this.caseRows = this.caseRows.map((r) => ({ ...r, selected: checked }));
  }

  handleCaseSort(event) {
    const key = event.currentTarget?.dataset?.key || STR_EMPTY;
    if (!key) {
      return;
    }
    if (this.caseSortBy === key) {
      this.caseSortDir = this.caseSortDir === "asc" ? "desc" : "asc";
    } else {
      this.caseSortBy = key;
      this.caseSortDir = key === "caseCreatedOn" ? "asc" : "asc";
    }
    this.applyCaseSort();
  }

  applyCaseSort() {
    const key = this.caseSortBy;
    const dir = this.caseSortDir === "desc" ? -1 : 1;
    const valueOf = (row) => {
      if (key === "caseCreatedOn") return row.caseCreatedOn || STR_EMPTY;
      if (key === "lastUpdatedOn") return row.lastUpdatedOn || STR_EMPTY;
      if (key === "hasAttachment") return row.hasAttachment ? 1 : 0;
      return String(row?.[key] || STR_EMPTY).toLowerCase();
    };
    this.caseRows = [...this.caseRows].sort((a, b) => {
      const av = valueOf(a);
      const bv = valueOf(b);
      if (av > bv) return 1 * dir;
      if (av < bv) return -1 * dir;
      return 0;
    });
  }

  handleCaseReviewClick(event) {
    const url = event.currentTarget?.dataset?.url || STR_EMPTY;
    if (url) {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  loadAttachmentDownloadedState() {
    try {
      const raw = window.localStorage.getItem("fec_batch_case_handling_downloaded");
      this.attachmentDownloadedByCase = raw ? JSON.parse(raw) : {};
    } catch (e) {
      this.attachmentDownloadedByCase = {};
    }
  }

  saveAttachmentDownloadedState() {
    try {
      window.localStorage.setItem(
        "fec_batch_case_handling_downloaded",
        JSON.stringify(this.attachmentDownloadedByCase)
      );
    } catch (e) {
      // ignore storage errors
    }
  }

  async handleCaseAttachmentClick(event) {
    const caseId = event.currentTarget?.dataset?.caseid || STR_EMPTY;
    if (!caseId) {
      return;
    }
    this.isLoading = true;
    try {
      const res = await this.withTimeout(
        downloadCaseAttachmentsZip({ caseId }),
        ZIP_TIMEOUT_MS,
        ZIP_TIMEOUT_MESSAGE
      );
      if (res?.success && res?.downloadUrl) {
        window.open(res.downloadUrl, "_blank", "noopener,noreferrer");
        this.attachmentDownloadedByCase = {
          ...this.attachmentDownloadedByCase,
          [String(caseId)]: true
        };
        this.saveAttachmentDownloadedState();
        this.caseRows = this.caseRows.map((r) =>
          String(r.caseId) === String(caseId)
            ? { ...r, attachmentDownloaded: true }
            : r
        );
      } else {
        this.showError(FEC_BCH_DownloadFailedTitle, res?.message || FEC_BCH_AttachmentDownloadFailedBody);
      }
    } catch (error) {
      this.showError(FEC_BCH_DownloadFailedTitle, this.extractError(error));
    } finally {
      this.isLoading = false;
    }
  }

  async fetchAllFilteredRowsForExport() {
    const payload = this.buildFiltersPayload();
    if (!payload.length) {
      return [];
    }
    const filtersJson = JSON.stringify(payload);

    const head = await searchBulkCases({
      filtersJson,
      pageSize: 1,
      pageNumber: 1
    });
    const total = head?.totalCount ?? 0;
    if (total > EXPORT_MAX_ROWS) {
      throw new Error(MSG_TOO_MANY_ROWS);
    }
    if (total === 0) {
      return [];
    }

    const all = [];
    let afterCaseId = STR_EMPTY;
    while (all.length < EXPORT_MAX_ROWS) {
      const res = await searchBulkCasesForExport({
        filtersJson,
        afterCaseId,
        pageSize: EXPORT_FETCH_PAGE_SIZE
      });
      const raw = Array.isArray(res?.rows) ? res.rows : [];
      if (!raw.length) {
        break;
      }
      raw.forEach((r) => {
        all.push({
          ...r,
          caseCreatedOnLabel:
            r.caseCreatedOnLabel || this.formatDateTimeSafe(r.caseCreatedOn),
          lastUpdatedOnLabel:
            r.lastUpdatedOnLabel || this.formatDateTimeSafe(r.lastUpdatedOn),
          hasAttachmentLabel:
            r.hasAttachmentLabel ||
            (r.hasAttachment ? FEC_BCH_DocumentLinkLabel : STR_EMPTY)
        });
      });
      afterCaseId = String(raw[raw.length - 1]?.caseId || STR_EMPTY);
      if (!afterCaseId || raw.length < EXPORT_FETCH_PAGE_SIZE) {
        break;
      }
    }
    return all;
  }

  handleActionChange(event) {
    this.selectedAction = event.detail.value || STR_EMPTY;
    this.actionRequiredError = false;
    this.caseSetRequiredError = false;
    this.exportSuccessMessage = STR_EMPTY;
    this.exportErrorMessage = STR_EMPTY;
    this.importSuccessMessage = STR_EMPTY;
    this.importErrorMessage = STR_EMPTY;
    this.attachDataRequiredError = false;
    if (this.selectedAction !== ACTION_IMPORT_UPDATE_DATA) {
      this.clearSelectedImportFile();
    }
    if (this.selectedAction === ACTION_DOWNLOAD_ATTACHMENTS) {
      this.loadCaseSetOptions();
    }
  }

  handleCaseSetChange(event) {
    this.selectedCaseSet = event.detail.value || STR_EMPTY;
    this.caseSetRequiredError = false;
  }

  get isDownloadAction() {
    return this.selectedAction === ACTION_DOWNLOAD_ATTACHMENTS;
  }

  get isImportAction() {
    return this.selectedAction === ACTION_IMPORT_UPDATE_DATA;
  }

  get hasSelectedImportFile() {
    return !!this.selectedImportFileName;
  }

  get importSubmitDisabled() {
    return this.isImportSubmitting;
  }

  async loadCaseSetOptions() {
    const payload = this.buildFiltersPayload();
    const filtersJson = JSON.stringify(payload);
    const rows = await getAttachmentCaseSetOptions({ filtersJson });
    this.caseSetOptions = (Array.isArray(rows) ? rows : []).map((r) => ({
      label: r.label,
      value: `${r.startIndex}-${r.endIndex}`
    }));
  }

  async handleActionSubmit() {
    this.actionRequiredError = false;
    this.caseSetRequiredError = false;
    this.exportSuccessMessage = STR_EMPTY;
    this.exportErrorMessage = STR_EMPTY;
    this.importSuccessMessage = STR_EMPTY;
    this.importErrorMessage = STR_EMPTY;
    if (!this.selectedAction) {
      this.actionRequiredError = true;
      return;
    }
    if (this.selectedAction === ACTION_DOWNLOAD_ATTACHMENTS) {
      await this.handleDownloadZip();
      return;
    }
    if (this.selectedAction === ACTION_IMPORT_UPDATE_DATA) {
      await this.handleImportData();
      return;
    }
    await this.openBusinessProcessPopup(
      this.selectedAction === ACTION_EXPORT_SELECTED
    );
  }

  async openBusinessProcessPopup(useSelected) {
    let sourceRows = [];
    if (useSelected) {
      //tungnm37 2026-05-27 12:11 - Không dùng trực tiếp grid rows vì grid chỉ có dữ liệu tối thiểu, thiếu field export/enrich
      const selectedCaseIds = this.selectedCaseIds.filter((id) => !!id);
      if (!this.caseSelectAllAcrossPages && !selectedCaseIds.length) {
        this.showInfo(FEC_BCH_ExportToastTitle, FEC_BCH_SelectAtLeastOneCase);
        return;
      }
      this.isLoading = true;
      try {
        //tungnm37 2026-05-27 12:11 - Query lại từ Apex để Export Selected đi cùng nguồn dữ liệu với Export All
        let raw = [];
        if (this.caseSelectAllAcrossPages) {
          // 30/05/2026 15:33 linhdev - Export Selected khi tick header phải lấy tất cả case filtered, trừ ngoại lệ đã untick
          raw = await this.fetchAllFilteredRowsForExport();
          const deselectedSet = new Set(this.deselectedCaseIds);
          raw = raw.filter((r) => !deselectedSet.has(this.caseIdKey(r.caseId)));
        } else {
          const res = await getSelectedCasesForExport({ caseIds: selectedCaseIds });
          raw = Array.isArray(res?.rows) ? res.rows : [];
        }
        sourceRows = raw.map((r) => ({
          ...r,
          caseCreatedOnLabel:
            r.caseCreatedOnLabel || this.formatDateTimeSafe(r.caseCreatedOn),
          lastUpdatedOnLabel:
            r.lastUpdatedOnLabel || this.formatDateTimeSafe(r.lastUpdatedOn),
          hasAttachmentLabel:
            r.hasAttachmentLabel ||
            (r.hasAttachment ? FEC_BCH_DocumentLinkLabel : STR_EMPTY)
        }));
      } catch (error) {
        this.handleExportFailure(error);
        this.isLoading = false;
        return;
      }
      this.isLoading = false;
      if (!sourceRows.length) {
        this.showInfo(FEC_BCH_ExportToastTitle, MSG_NO_DATA_EXPORT);
        return;
      }
    } else {
      this.isLoading = true;
      try {
        sourceRows = await this.fetchAllFilteredRowsForExport();
      } catch (error) {
        this.handleExportFailure(error);
        this.isLoading = false;
        return;
      }
      this.isLoading = false;
      if (!sourceRows.length) {
        this.showInfo(FEC_BCH_ExportToastTitle, MSG_NO_DATA_EXPORT);
        return;
      }
    }

    let bpInfo = [];
    this.isLoading = true;
    try {
      const filtersJson = JSON.stringify(this.buildFiltersPayload());
      bpInfo = await getBusinessProcessExportRows({ filtersJson });
    } catch (error) {
      this.handleExportFailure(error);
      this.isLoading = false;
      return;
    }
    this.isLoading = false;

    this.bpTemplateMetaByCode = {};
    (Array.isArray(bpInfo) ? bpInfo : []).forEach((b) => {
      this.registerTemplateMeta(b);
    });
    await this.ensureExportTemplateMetaForRows(sourceRows);

    const keysFromSource = new Map();
    sourceRows.forEach((r) => {
      this.registerBusinessProcessKeysFromRow(keysFromSource, r);
    });

    let list = (Array.isArray(bpInfo) ? bpInfo : [])
      .filter((b) => {
        const n = String(b.businessProcessCode || STR_EMPTY).trim();
        return (
          n &&
          this.isAllowedBulkExportBusinessProcess(n) &&
          this.businessProcessInfoMatchesSourceKeys(b, keysFromSource)
        );
      })
      .map((b) => {
        const code = String(b.businessProcessCode || STR_EMPTY).trim();
        const name = String(b.businessProcessName || code || STR_EMPTY).trim();
        return {
          rowKey: `bp-${code}`,
          businessProcessCode: code,
          businessProcessName: name,
          templateName: (this.lookupBpTemplateMeta(code) || {}).templateName || STR_EMPTY,
          selected: true
        };
      });

    if (!list.length && keysFromSource.size) {
      list = Array.from(keysFromSource.values())
        .filter((code) => this.isAllowedBulkExportBusinessProcess(code))
        .sort((a, b) => String(a).localeCompare(String(b)))
        .map((code) => ({
          rowKey: `bp-${code}`,
          businessProcessCode: code,
          businessProcessName: code,
          templateName: (this.lookupBpTemplateMeta(code) || {}).templateName || code,
          selected: true
        }));
    }

    if (!list.length) {
      this.showInfo(FEC_BCH_ExportToastTitle, MSG_NO_DATA_EXPORT);
      return;
    }

    this.bpExportUseSelected = useSelected;
    this.bpExportSourceRows = sourceRows;
    this.bpRows = list;
    this.bpSortDir = "asc";
    this.applyBpSort();
    this.bpPageSize = "10";
    this.bpCurrentPage = 1;
    this.includeAllProperties = EXPORT_PROPERTY_NO;
    this.rebuildBpPagedRows();
    this.showBpModal = true;
  }

  applyBpSort() {
    const dir = this.bpSortDir === "desc" ? -1 : 1;
    this.bpRows = [...this.bpRows].sort((a, b) => {
      const av = String(a?.businessProcessCode || STR_EMPTY).toLowerCase();
      const bv = String(b?.businessProcessCode || STR_EMPTY).toLowerCase();
      if (av > bv) return 1 * dir;
      if (av < bv) return -1 * dir;
      return 0;
    });
  }

  rebuildBpPagedRows() {
    const size = Number(this.bpPageSize) || 10;
    const total = this.bpRows.length;
    const maxPage = Math.max(1, Math.ceil(total / size));
    if (this.bpCurrentPage > maxPage) {
      this.bpCurrentPage = maxPage;
    }
    const start = (this.bpCurrentPage - 1) * size;
    this.bpPagedRows = this.bpRows.slice(start, start + size).map((r, i) => ({
      ...r,
      rowIndex: start + i + 1
    }));
    this.bpGoToPageInput = String(this.bpCurrentPage);
  }

  get hasBpRows() {
    return this.bpRows.length > 0;
  }

  get bpTotalPages() {
    const size = Number(this.bpPageSize) || 10;
    return Math.max(1, Math.ceil(this.bpRows.length / size));
  }

  get bpPreviousDisabled() {
    return this.bpCurrentPage <= 1;
  }

  get bpNextDisabled() {
    return this.bpCurrentPage >= this.bpTotalPages;
  }

  get bpItemsLabel() {
    const total = this.bpRows.length;
    const noun = total === 1 ? FEC_BCH_BpItemSingular : FEC_BCH_BpItemPlural;
    return `${total} ${noun}${FEC_BCH_BpItemsSortedSuffix}`;
  }

  get bpSortIcon() {
    return this.bpSortDir === "desc" ? "utility:arrowdown" : "utility:arrowup";
  }

  get allBpRowsSelected() {
    return (
      this.bpPagedRows.length > 0 &&
      this.bpPagedRows.every((r) => r.selected)
    );
  }

  handleBpSort() {
    this.bpSortDir = this.bpSortDir === "asc" ? "desc" : "asc";
    this.applyBpSort();
    this.bpCurrentPage = 1;
    this.rebuildBpPagedRows();
  }

  handleBpRowSelect(event) {
    const code = event.currentTarget?.dataset?.code || STR_EMPTY;
    const checked = !!event.detail?.checked;
    this.bpRows = this.bpRows.map((r) =>
      r.businessProcessCode === code ? { ...r, selected: checked } : r
    );
    this.rebuildBpPagedRows();
  }

  handleBpSelectAll(event) {
    const checked = !!event.detail?.checked;
    const visibleCodes = new Set(
      this.bpPagedRows.map((r) => r.businessProcessCode)
    );
    this.bpRows = this.bpRows.map((r) =>
      visibleCodes.has(r.businessProcessCode) ? { ...r, selected: checked } : r
    );
    this.rebuildBpPagedRows();
  }

  handleExportPropertiesChange(event) {
    this.includeAllProperties = event.detail?.value || EXPORT_PROPERTY_NO;
  }

  handleBpPageSizeChange(event) {
    this.bpPageSize = event.detail.value;
    this.bpCurrentPage = 1;
    this.rebuildBpPagedRows();
  }

  handleBpPreviousPage() {
    if (this.bpCurrentPage <= 1) {
      return;
    }
    this.bpCurrentPage -= 1;
    this.rebuildBpPagedRows();
  }

  handleBpNextPage() {
    if (this.bpCurrentPage >= this.bpTotalPages) {
      return;
    }
    this.bpCurrentPage += 1;
    this.rebuildBpPagedRows();
  }

  handleBpGoToPageInput(event) {
    this.bpGoToPageInput = event.detail.value;
  }

  handleBpGoToPage() {
    const n = parseInt(this.bpGoToPageInput, 10);
    if (Number.isNaN(n) || n < 1) {
      return;
    }
    const target = Math.min(Math.max(1, n), this.bpTotalPages);
    this.bpCurrentPage = target;
    this.rebuildBpPagedRows();
  }

  closeBpModal() {
    this.showBpModal = false;
    this.bpRows = [];
    this.bpPagedRows = [];
    this.bpExportSourceRows = [];
    this.bpTemplateMetaByCode = {};
    this.templateFileCache = {};
    this.bpSubmitLoading = false;
  }

  registerTemplateMeta(bpRow) {
    if (!bpRow) {
      return;
    }
    const meta = {
      templateName: bpRow.templateName || STR_EMPTY,
      templateDownloadUrl: bpRow.templateDownloadUrl || STR_EMPTY,
      templateContentVersionId: bpRow.templateContentVersionId || null
    };
    if (!this.bpTemplateMetaByCode) {
      this.bpTemplateMetaByCode = {};
    }
    const code = String(bpRow.businessProcessCode || STR_EMPTY).trim();
    const name = String(bpRow.businessProcessName || STR_EMPTY).trim();
    if (code) {
      this.bpTemplateMetaByCode[code] = meta;
      this.bpTemplateMetaByCode[code.toLowerCase()] = meta;
    }
    if (name) {
      this.bpTemplateMetaByCode[name] = meta;
      this.bpTemplateMetaByCode[name.toLowerCase()] = meta;
    }
  }

  lookupBpTemplateMeta(bpKey) {
    const map = this.bpTemplateMetaByCode || {};
    if (!bpKey) {
      return {};
    }
    const direct = map[bpKey];
    if (direct) {
      return direct;
    }
    const lower = String(bpKey).trim().toLowerCase();
    return lower ? map[lower] || {} : {};
  }

  async ensureExportTemplateMetaForRows(sourceRows) {
    const keys = new Map();
    (Array.isArray(sourceRows) ? sourceRows : []).forEach((r) => {
      const bpKey = this.rowBusinessProcessKey(r);
      if (!bpKey) {
        return;
      }
      if (!keys.has(bpKey)) {
        const code = String(r.businessProcessCode || STR_EMPTY).trim();
        const name = String(r.businessProcessName || STR_EMPTY).trim();
        keys.set(bpKey, {
          businessProcessCode: code || bpKey,
          businessProcessName: name || bpKey
        });
      }
    });
    const entries = Array.from(keys.entries());
    for (let i = 0; i < entries.length; i += 1) {
      const bpKey = entries[i][0];
      const pair = entries[i][1];
      const existing = this.lookupBpTemplateMeta(bpKey);
      if (this.resolveTemplateContentVersionId(existing)) {
        continue;
      }
      try {
        const resolved = await resolveExportTemplateMeta({
          businessProcessCode: pair.businessProcessCode,
          businessProcessName: pair.businessProcessName
        });
        this.registerTemplateMeta(resolved);
        this.registerTemplateMeta({
          businessProcessCode: bpKey,
          businessProcessName: pair.businessProcessName,
          templateName: resolved?.templateName,
          templateDownloadUrl: resolved?.templateDownloadUrl,
          templateContentVersionId: resolved?.templateContentVersionId
        });
      } catch (error) {
        // keep export error path in buildExcelFileFromTemplate
      }
    }
  }

  resolveTemplateContentVersionId(templateMeta) {
    if (!templateMeta) {
      return null;
    }
    const direct = templateMeta.templateContentVersionId;
    if (direct) {
      return direct;
    }
    const url = String(templateMeta.templateDownloadUrl || STR_EMPTY).trim();
    if (!url) {
      return null;
    }
    const prefix = "/sfc/servlet.shepherd/version/download/";
    const idx = url.indexOf(prefix);
    if (idx < 0) {
      return null;
    }
    const tail = url.substring(idx + prefix.length);
    const id = tail.split(/[?&#]/)[0].trim();
    return /^[a-zA-Z0-9]{15,18}$/.test(id) ? id : null;
  }

  resolveTemplateGroupKey(templateMeta, businessProcessCode) {
    const versionId = String(
      this.resolveTemplateContentVersionId(templateMeta) || STR_EMPTY
    ).trim();
    if (versionId) {
      return `cv:${versionId}`;
    }
    const templateName = String(templateMeta?.templateName || STR_EMPTY).trim();
    if (templateName) {
      return `name:${templateName.toLowerCase()}`;
    }
    const bp = String(businessProcessCode || STR_EMPTY).trim().toLowerCase();
    return `bp:${bp || "other"}`;
  }

  async handleBpSubmit() {
    if (this.bpSubmitLoading) {
      return;
    }
    const selectedBpTokens = [];
    this.bpRows
      .filter((r) => r.selected)
      .forEach((r) => {
        const code = String(r.businessProcessCode || STR_EMPTY).trim();
        const name = String(r.businessProcessName || STR_EMPTY).trim();
        if (code) {
          selectedBpTokens.push(code);
        }
        if (name) {
          selectedBpTokens.push(name);
        }
      });
    if (!selectedBpTokens.length) {
      this.showError(FEC_BCH_ExportToastTitle, MSG_BP_REQUIRED);
      return;
    }
    const rows = (this.bpExportSourceRows || []).filter((r) =>
      this.rowMatchesSelectedBusinessProcess(r, selectedBpTokens)
    );
    if (!rows.length) {
      this.showInfo(FEC_BCH_ExportToastTitle, MSG_NO_DATA_EXPORT);
      return;
    }

    const groups = {};
    rows.forEach((r) => {
      const bp = this.rowBusinessProcessKey(r) || "Other";
      const tmplMeta = this.lookupBpTemplateMeta(bp);
      const groupKey = this.resolveTemplateGroupKey(tmplMeta, bp);
      if (!groups[groupKey]) {
        groups[groupKey] = {
          rows: [],
          templateMeta: tmplMeta,
          fallbackBusinessProcessCode: bp
        };
      }
      groups[groupKey].rows.push(r);
    });

    this.bpSubmitLoading = true;
    this.isLoading = true;
    try {
      await this.ensureExportTemplateMetaForRows(rows);
      await this.ensureSheetJsLoaded();
      const filesPayload = [];
      const groupKeys = Object.keys(groups);
      for (let i = 0; i < groupKeys.length; i += 1) {
        const groupItem = groups[groupKeys[i]];
        const tmplMeta = groupItem?.templateMeta || {};
        const fallbackBp = groupItem?.fallbackBusinessProcessCode || "Other";
        const fileName = this.resolveExportFileName(
          tmplMeta.templateName,
          fallbackBp
        );
        const contentVersionId = this.resolveTemplateContentVersionId(tmplMeta);
        // 27/05/2026 10:00 linhdev - Export with all Properties: load MDS columns + values khi user chọn Yes
        const propertyBundle = await this.loadExportPropertyBundleForRows(groupItem?.rows || []);
        const file = await this.withTimeout(
          this.buildExcelFileFromTemplate(
            groupItem?.rows || [],
            fileName,
            contentVersionId,
            tmplMeta,
            propertyBundle
          ),
          EXCEL_FILE_TIMEOUT_MS,
          EXCEL_FILE_TIMEOUT_MESSAGE
        );
        filesPayload.push(file);
      }

      if (!filesPayload.length) {
        this.showInfo(FEC_BCH_ExportToastTitle, MSG_NO_DATA_EXPORT);
        return;
      }

      const archiveName = this.bpExportUseSelected
        ? "BatchCaseHandling_Selected"
        : "BatchCaseHandling_All";
      const res = await this.withTimeout(
        zipExcelFiles({ files: filesPayload, archiveName }),
        ZIP_TIMEOUT_MS,
        ZIP_TIMEOUT_MESSAGE
      );
      if (res?.success && res?.downloadUrl) {
        window.open(res.downloadUrl, "_blank", "noopener,noreferrer");
        this.showSuccess(FEC_BCH_DownloadToastTitle, MSG_EXPORT_SUCCESS);
        this.exportSuccessMessage = MSG_EXPORT_SUCCESS;
        this.exportErrorMessage = STR_EMPTY;
        this.closeBpModal();
      } else {
        this.handleExportFailure(res?.message || MSG_EXPORT_FAILED);
        this.closeBpModal();
      }
    } catch (error) {
      this.handleExportFailure(error);
      this.closeBpModal();
    } finally {
      this.bpSubmitLoading = false;
      this.isLoading = false;
    }
  }

  handleExportFailure(error) {
    this.exportSuccessMessage = STR_EMPTY;
    const detail =
      typeof error === "string" ? error : this.extractError(error);
    if (this.isRequestTimeoutError(detail)) {
      this.exportErrorMessage = FEC_BCH_RequestTimeout;
      this.showError(FEC_BCH_ExportToastTitle, FEC_BCH_RequestTimeout);
      return;
    }
    this.exportErrorMessage = MSG_EXPORT_FAILED;
    this.showError(
      MSG_EXPORT_FAILED,
      detail || FEC_BCH_CannotCreateExportFile
    );
  }

  handleImportFileChange(event) {
    const file = event.target?.files?.[0];
    if (!file) {
      return;
    }
    const lowerName = (file.name || STR_EMPTY).toLowerCase();
    if (!lowerName.endsWith(VALID_FILE_EXTENSION)) {
      this.showError(MSG_IMPORT_FAILED, MSG_INVALID_FILE_FORMAT);
      this.resetImportFileInput();
      return;
    }
    if (file.size > MAX_UPLOAD_SIZE_BYTES) {
      this.showError(MSG_IMPORT_FAILED, MSG_FILE_TOO_LARGE);
      this.resetImportFileInput();
      return;
    }
    this.selectedImportFile = file;
    this.selectedImportFileName = file.name;
    this.attachDataRequiredError = false;
    this.importSuccessMessage = STR_EMPTY;
    this.importErrorMessage = STR_EMPTY;
    this.resetImportFileInput();
  }

  handleClearImportFile() {
    this.clearSelectedImportFile();
    this.importSuccessMessage = STR_EMPTY;
    this.importErrorMessage = STR_EMPTY;
  }

  triggerImportFilePicker() {
    const input = this.template.querySelector(".fec-import-file-input");
    if (input) {
      input.click();
    }
  }

  clearSelectedImportFile() {
    this.selectedImportFile = null;
    this.selectedImportFileName = STR_EMPTY;
    this.attachDataRequiredError = false;
    this.resetImportFileInput();
  }

  resetImportFileInput() {
    const input = this.template.querySelector(".fec-import-file-input");
    if (input) {
      input.value = null;
    }
  }

  // 01/06/2026 12:00 linhdev - import: gửi file base64 + rowsJson rỗng; Apex parse/validate (không SheetJS)
  async handleImportData() {
    this.importSuccessMessage = STR_EMPTY;
    this.importErrorMessage = STR_EMPTY;
    this.attachDataRequiredError = false;
    if (!this.selectedImportFile) {
      this.attachDataRequiredError = true;
      return;
    }
    const file = this.selectedImportFile;
    const fileName = this.selectedImportFileName;
    this.isImportSubmitting = true;
    this.isLoading = true;
    try {
      const arrayBuffer = await this.readFileAsArrayBuffer(file);
      const fileBodyBase64 = arrayBufferToBase64(arrayBuffer);
      const importCtx = await this.resolveImportTemplateContext(
        this.inferCofOrGsrFromFileName(fileName),
        fileName
      );
      const result = await this.withTimeout(
        importBatchData({
          fileName,
          fileBodyBase64,
          templateName: importCtx.templateName,
          rowsJson: "[]",
          businessProcessCode: importCtx.businessProcessCode,
          businessProcessName: importCtx.businessProcessName
        }),
        IMPORT_TIMEOUT_MS,
        IMPORT_TIMEOUT_MESSAGE
      );
      if (!result || result.success !== true) {
        await this.recordImportFailureInBulkActions(
          fileName,
          importCtx.templateName,
          result?.message || MSG_IMPORT_FAILED
        );
        return;
      }
      const isProcessing = result.status === IMPORT_STATUS_PROCESSING;
      // 28/05/2026 16:20 linhdev - Result file do Apex tạo trực tiếp từ layout import gốc + __Status/__Errors
      const successTitle = isProcessing ? MSG_IMPORT_SUBMITTED : MSG_IMPORT_SUCCESS;
      const successDetail = result.message || STR_EMPTY;
      this.importSuccessMessage = successTitle;
      this.importErrorMessage = STR_EMPTY;
      this.showSuccess(successTitle, successDetail);
      this.clearSelectedImportFile();
      await this.refreshRows();
    } catch (error) {
      await this.recordImportFailureInBulkActions(
        fileName,
        TEMPLATE_NAME_OTHER,
        this.extractError(error) || MSG_IMPORT_FAILED
      );
    } finally {
      this.isImportSubmitting = false;
      this.isLoading = false;
    }
  }

  // 01/06/2026 12:00 linhdev - suy COF/GSR từ tên file (gsrtemp/coftemp) cho resolve template
  inferCofOrGsrFromFileName(fileName) {
    const core = String(fileName || STR_EMPTY)
      .trim()
      .toLowerCase()
      .replace(/\.xlsx$/i, STR_EMPTY);
    return core.startsWith("gsrtemp") || core.startsWith("coftemp");
  }

  // 01/06/2026 12:00 linhdev - Lỗi import: ghi My Bulk Actions, không toast (parse/validate trên Apex)
  async recordImportFailureInBulkActions(fileName, templateName, reason) {
    this.importSuccessMessage = STR_EMPTY;
    this.importErrorMessage = STR_EMPTY;
    await this.safeLogFailedImport(
      fileName,
      templateName,
      reason || MSG_IMPORT_FAILED
    );
    this.clearSelectedImportFile();
    await this.refreshRows();
  }

  handleImportFailure(error, fileName) {
    this.importSuccessMessage = STR_EMPTY;
    const detail =
      typeof error === "string" ? error : this.extractError(error);
    if (this.isRequestTimeoutError(detail)) {
      this.importErrorMessage = FEC_BCH_RequestTimeout;
      this.showError(MSG_IMPORT_FAILED, FEC_BCH_RequestTimeout);
      return;
    }
    this.importErrorMessage = MSG_IMPORT_FAILED;
    this.showError(
      MSG_IMPORT_FAILED,
      detail || `${FEC_BCH_ImportUnablePrefix} ${fileName || FEC_BCH_DataFileFallback}.`
    );
  }

  async safeLogFailedImport(fileName, templateName, reason) {
    try {
      await logFailedImport({
        fileName,
        templateName,
        reason: reason || MSG_IMPORT_FAILED
      });
    } catch (e) {
      // best-effort logging only
    }
  }

  async resolveImportTemplateContext(isCofOrGsr, fileName) {
    const selected = (this.bpRows || []).filter((r) => r && r.selected);
    if (selected.length === 1) {
      const code = String(selected[0].businessProcessCode || STR_EMPTY).trim();
      const name = String(selected[0].businessProcessName || STR_EMPTY).trim();
      const meta = this.lookupBpTemplateMeta(code || name);
      const fallbackTemplate = isCofOrGsr ? TEMPLATE_NAME_GSR : TEMPLATE_NAME_OTHER;
      return {
        templateName: String(meta.templateName || fallbackTemplate).trim(),
        businessProcessCode: code,
        businessProcessName: name
      };
    }
    const normalizedFile = String(fileName || STR_EMPTY).trim();
    if (normalizedFile) {
      try {
        const filtersJson = JSON.stringify(this.buildFiltersPayload());
        const bpInfo = await getBusinessProcessExportRows({ filtersJson });
        const matched = (Array.isArray(bpInfo) ? bpInfo : []).filter((b) =>
          this.uploadedFileMatchesTemplateName(normalizedFile, b.templateName)
        );
        if (matched.length >= 1) {
          const uniqueTemplateKeys = new Set(
            matched.map((b) => String(b.templateName || STR_EMPTY).trim().toLowerCase())
          );
          if (uniqueTemplateKeys.size === 1) {
            const row = matched[0];
            return {
              templateName: String(row.templateName || STR_EMPTY).trim(),
              businessProcessCode: String(row.businessProcessCode || STR_EMPTY).trim(),
              businessProcessName: String(row.businessProcessName || STR_EMPTY).trim()
            };
          }
        }
      } catch (e) {
        // Apex resolveImportTemplateName still matches by file name + user group
      }
    }
    return {
      templateName: isCofOrGsr ? TEMPLATE_NAME_GSR : TEMPLATE_NAME_OTHER,
      businessProcessCode: STR_EMPTY,
      businessProcessName: STR_EMPTY
    };
  }

  uploadedFileMatchesTemplateName(fileName, templateName) {
    if (!fileName || !templateName) {
      return false;
    }
    const fileCore = String(fileName).trim().toLowerCase().replace(/\.xlsx$/i, STR_EMPTY);
    const expectedCore = String(templateName).trim().toLowerCase().replace(/\.xlsx$/i, STR_EMPTY);
    if (!fileCore || !expectedCore) {
      return false;
    }
    return fileCore === expectedCore || fileCore.includes(expectedCore);
  }

  parseImportWorkbook(arrayBuffer) {
    if (typeof window.XLSX === "undefined") {
      return null;
    }
    const workbook = window.XLSX.read(arrayBuffer, { type: "array" });
    // 28/05/2026 17:45 linhdev - import đúng sheet chính (vd. PointsRedemptionTemp1), không lấy Sheet1 đầu tiên
    const firstSheetName = this.resolveMainTemplateSheetName(workbook);
    if (!firstSheetName) {
      return null;
    }
    const sheet = workbook.Sheets[firstSheetName];
    const aoa = window.XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      raw: false,
      defval: STR_EMPTY
    });
    if (!Array.isArray(aoa) || aoa.length === 0) {
      return null;
    }
    const headerMeta = this.detectImportHeaderRow(aoa);
    if (!headerMeta) {
      return null;
    }
    const { headerRowIndex, headerRow, normalized } = headerMeta;
    const importHeaders = this.stripResultColumnsFromImportLayout(headerRow).headers;
    const resultColExclude = this.getResultColumnExcludeIndices(headerRow);
    const headerColumnIndexes = this.resolveWorksheetHeaderColumnIndexes(
      sheet,
      headerRowIndex,
      headerRow
    );
    // 29/05/2026 20:30 linhdev - chỉ số cột Excel khớp importHeaders (đã bỏ __Status/__Errors)
    const importColumnIndexes = this.stripResultColumnsFromImportLayout(
      headerRow,
      headerColumnIndexes
    ).headers;
    const importHeadersNormalized = importHeaders.map((h) =>
      (h == null ? STR_EMPTY : String(h))
        .replace(/\s+/g, STR_EMPTY)
        .toLowerCase()
    );
    const idxCaseIdImport = this.findHeaderIndex(
      importHeadersNormalized,
      HEADERS_CASE_ID
    );
    const idxRemarkImport = this.findHeaderIndex(
      importHeadersNormalized,
      HEADERS_REMARKS
    );
    const idxRoutingImport = this.findHeaderIndex(
      importHeadersNormalized,
      HEADERS_ROUTING_ACTION
    );
    const idxCaseId = this.findHeaderIndex(normalized, HEADERS_CASE_ID);
    const idxRouting = this.findHeaderIndex(normalized, HEADERS_ROUTING_ACTION);
    const idxRemark = this.findHeaderIndex(normalized, HEADERS_REMARKS);
    const idxAssignmentId = this.findHeaderIndex(
      normalized,
      HEADERS_ASSIGNMENT_ID
    );
    const idxAssignmentRouting = this.findHeaderIndex(
      normalized,
      HEADERS_ASSIGNMENT_ROUTING_ACTION
    );
    const idxCsD2CAssessment = this.findHeaderIndex(
      normalized,
      HEADERS_CS_D2C_ASSESSMENT
    );
    const idxRiskLevel = this.findHeaderIndex(normalized, HEADERS_RISK_LEVEL);
    const idxRequiredAction = this.findHeaderIndex(
      normalized,
      HEADERS_REQUIRED_ACTION
    );
    const idxCsSupportAssessment = this.findHeaderIndex(
      normalized,
      HEADERS_CS_SUPPORT_ASSESSMENT
    );
    const idxClassificationByCS = this.findHeaderIndex(
      normalized,
      HEADERS_CLASSIFICATION_BY_CS
    );
    const idxEvaluationByCS = this.findHeaderIndex(
      normalized,
      HEADERS_EVALUATION_BY_CS
    );
    const idxFinalProduct = this.findHeaderIndex(
      normalized,
      HEADERS_FINAL_PRODUCT
    );
    const idxPaymentContractAssessment = this.findHeaderIndex(
      normalized,
      HEADERS_PAYMENT_CONTRACT_ASSESSMENT
    );
    const idxCpAssessment = this.findHeaderIndex(
      normalized,
      HEADERS_CP_ASSESSMENT
    );
    const isCofOrGsr = idxAssignmentId >= 0 || idxAssignmentRouting >= 0;
    const rows = [];
    for (let i = headerRowIndex + 1; i < aoa.length; i++) {
      const r = aoa[i] || [];
      const caseIdSearch = this.readImportCellValue(
        sheet,
        i,
        idxCaseIdImport >= 0 ? idxCaseIdImport : idxCaseId,
        importColumnIndexes,
        r
      );
      const routingAction =
        idxRoutingImport >= 0 || idxRouting >= 0
          ? this.readImportCellValue(
            sheet,
            i,
            idxRoutingImport >= 0 ? idxRoutingImport : idxRouting,
            importColumnIndexes,
            r
          )
          : STR_EMPTY;
      const inputtedRemarksRaw =
        idxRemarkImport >= 0 || idxRemark >= 0
          ? this.readImportCellValue(
            sheet,
            i,
            idxRemarkImport >= 0 ? idxRemarkImport : idxRemark,
            importColumnIndexes,
            r
          )
          : STR_EMPTY;
      const inputtedRemarksCharLength = inputtedRemarksRaw ? inputtedRemarksRaw.length : 0;
      // 30/05/2026 21:00 linhdev - không gửi full remark > 32,767 trong JSON (Apex validate qua charLength + file gốc)
      const inputtedRemarks =
        inputtedRemarksCharLength >= INPUTTED_REMARKS_MAX_LEN
          ? STR_EMPTY
          : inputtedRemarksRaw;
      const assignmentId =
        idxAssignmentId >= 0
          ? this.readImportCellValue(
            sheet,
            i,
            idxAssignmentId,
            headerColumnIndexes,
            r
          )
          : STR_EMPTY;
      const assignmentRoutingAction =
        idxAssignmentRouting >= 0
          ? this.readImportCellValue(
            sheet,
            i,
            idxAssignmentRouting,
            headerColumnIndexes,
            r
          )
          : STR_EMPTY;
      const csD2CAssessmentType =
        idxCsD2CAssessment >= 0
          ? this.cellAsString(r[idxCsD2CAssessment])
          : STR_EMPTY;
      const csSupportAssessment =
        idxCsSupportAssessment >= 0
          ? this.cellAsString(r[idxCsSupportAssessment])
          : STR_EMPTY;
      const riskLevel =
        idxRiskLevel >= 0 ? this.cellAsString(r[idxRiskLevel]) : STR_EMPTY;
      const requiredAction =
        idxRequiredAction >= 0
          ? this.cellAsString(r[idxRequiredAction])
          : STR_EMPTY;
      const classificationByCS =
        idxClassificationByCS >= 0
          ? this.cellAsString(r[idxClassificationByCS])
          : STR_EMPTY;
      const evaluationByCS =
        idxEvaluationByCS >= 0
          ? this.cellAsString(r[idxEvaluationByCS])
          : STR_EMPTY;
      const finalProduct =
        idxFinalProduct >= 0 ? this.cellAsString(r[idxFinalProduct]) : STR_EMPTY;
      const paymentContractAssessment =
        idxPaymentContractAssessment >= 0
          ? this.cellAsString(r[idxPaymentContractAssessment])
          : STR_EMPTY;
      const cpAssessment =
        idxCpAssessment >= 0
          ? this.cellAsString(r[idxCpAssessment])
          : STR_EMPTY;
      if (
        !caseIdSearch &&
        !routingAction &&
        !inputtedRemarks &&
        !assignmentId &&
        !assignmentRoutingAction &&
        !csD2CAssessmentType &&
        !csSupportAssessment &&
        !riskLevel &&
        !requiredAction &&
        !classificationByCS &&
        !evaluationByCS &&
        !finalProduct &&
        !paymentContractAssessment &&
        !cpAssessment
      ) {
        continue;
      }
      const originalCells = [];
      // 01/06/2026 18:00 linhdev - originalCells theo importColumnIndexes (không lệch khi resolveWorksheetHeaderColumnIndexes map sai cột)
      for (let col = 0; col < importHeaders.length; col += 1) {
        const worksheetCol =
          Array.isArray(importColumnIndexes) && col < importColumnIndexes.length
            ? importColumnIndexes[col]
            : col;
        const cellRef = window.XLSX.utils.encode_cell({ r: i, c: worksheetCol });
        const cell = sheet[cellRef];
        const cellValue = cell && cell.v !== undefined ? cell.v : STR_EMPTY;
        let cellStr = this.cellAsString(cellValue);
        // 30/05/2026 21:00 linhdev - giữ tối đa 32,767 ký tự Excel trong originalCells
        if (col === idxRemarkImport && cellStr.length >= INPUTTED_REMARKS_MAX_LEN) {
          cellStr = cellStr.substring(0, INPUTTED_REMARKS_MAX_LEN);
        }
        originalCells.push(cellStr);
      }
      rows.push({
        caseIdSearch,
        routingAction,
        inputtedRemarks,
        inputtedRemarksCharLength,
        assignmentId,
        assignmentRoutingAction,
        csD2CAssessmentType,
        csSupportAssessment,
        riskLevel,
        requiredAction,
        classificationByCS,
        evaluationByCS,
        finalProduct,
        paymentContractAssessment,
        cpAssessment,
        // 28/05/2026 16:20 linhdev - gửi kèm header gốc để Apex build Result theo đúng layout file user import
        originalHeaders: importHeaders,
        originalCells,
        originalColumnIndexes: importColumnIndexes,
        originalHeaderRowIndex: headerRowIndex,
        originalDataRowIndex: i,
        originalSheetName: firstSheetName
      });
    }
    return { rows, isCofOrGsr, originalHeaders: importHeaders };
  }

  detectImportHeaderRow(aoa) {
    // 28/05/2026 17:45 linhdev - quét header tới 25 dòng (template có header sâu hơn 10 dòng)
    const scanLimit = Math.min(aoa.length, 25);
    for (let i = 0; i < scanLimit; i++) {
      const row = aoa[i] || [];
      const normalized = row.map((h) =>
        (h == null ? STR_EMPTY : String(h))
          .replace(/\s+/g, STR_EMPTY)
          .toLowerCase()
      );
      const idxCaseId = this.findHeaderIndex(normalized, HEADERS_CASE_ID);
      const idxRouting = this.findHeaderIndex(normalized, HEADERS_ROUTING_ACTION);
      const idxAssignmentRouting = this.findHeaderIndex(
        normalized,
        HEADERS_ASSIGNMENT_ROUTING_ACTION
      );
      const idxRemark = this.findHeaderIndex(normalized, HEADERS_REMARKS);
      const hasRoutingHeaderCol = idxRouting >= 0 || idxAssignmentRouting >= 0;
      if (idxCaseId >= 0 && hasRoutingHeaderCol && idxRemark >= 0) {
        return {
          headerRowIndex: i,
          headerRow: row,
          normalized
        };
      }
    }
    return null;
  }

  findHeaderIndex(normalizedHeaders, candidates) {
    for (let i = 0; i < normalizedHeaders.length; i++) {
      if (candidates.indexOf(normalizedHeaders[i]) >= 0) {
        return i;
      }
    }
    return -1;
  }

  resolveWorksheetHeaderColumnIndexes(sheet, headerRowIndex, headerRow) {
    if (
      !sheet ||
      !Array.isArray(headerRow) ||
      headerRow.length === 0 ||
      typeof window.XLSX === "undefined"
    ) {
      return Array.isArray(headerRow)
        ? headerRow.map((_, idx) => idx)
        : [];
    }
    const ref = sheet["!ref"];
    if (!ref) {
      return headerRow.map((_, idx) => idx);
    }
    const range = window.XLSX.utils.decode_range(ref);
    const absoluteRow = headerRowIndex;
    const indexes = [];
    let searchCol = range.s.c;
    for (let i = 0; i < headerRow.length; i += 1) {
      const expected = this.cellAsString(headerRow[i]);
      let matchedCol = null;
      for (let col = searchCol; col <= range.e.c; col += 1) {
        const cellRef = window.XLSX.utils.encode_cell({ r: absoluteRow, c: col });
        const cell = sheet[cellRef];
        const cellValue = cell && cell.v !== undefined ? this.cellAsString(cell.v) : STR_EMPTY;
        // 30/05/2026 11:30 linhdev - header rỗng không match ô trống (tránh lệch Temporary Email / Case ID)
        if (expected !== STR_EMPTY && cellValue === expected) {
          matchedCol = col;
          searchCol = col + 1;
          break;
        }
      }
      if (matchedCol === null) {
        matchedCol = indexes.length > 0 ? indexes[indexes.length - 1] + 1 : i;
      }
      indexes.push(matchedCol);
    }
    return indexes;
  }

  cellAsString(value) {
    if (value === null || value === undefined) {
      return STR_EMPTY;
    }
    return String(value).trim();
  }

  // 29/05/2026 19:30 linhdev - đọc ô import từ worksheet (đúng cột khi template có cột trống/merge); giữ đủ remark cho validate Apex
  readImportCellValue(sheet, rowIndex, headerColIndex, headerColumnIndexes, aoaRow) {
    if (headerColIndex < 0) {
      return STR_EMPTY;
    }
    if (
      sheet &&
      typeof window.XLSX !== "undefined" &&
      Array.isArray(headerColumnIndexes) &&
      headerColIndex < headerColumnIndexes.length
    ) {
      const worksheetCol = headerColumnIndexes[headerColIndex];
      const cellRef = window.XLSX.utils.encode_cell({
        r: rowIndex,
        c: worksheetCol
      });
      const cell = sheet[cellRef];
      if (cell) {
        // 30/05/2026 16:15 linhdev - ưu tiên cell.v (raw) thay vì cell.w để không mất ký tự khi remark > 32,768
        if (cell.v !== undefined && cell.v !== null) {
          return this.cellAsString(cell.v);
        }
        if (cell.w !== undefined && cell.w !== null) {
          return this.cellAsString(cell.w);
        }
      }
      return STR_EMPTY;
    }
    if (aoaRow && headerColIndex < aoaRow.length) {
      return this.cellAsString(aoaRow[headerColIndex]);
    }
    return STR_EMPTY;
  }

  normalizeResultHeaderKey(header) {
    return (header == null ? STR_EMPTY : String(header))
      .replace(/\s+/g, STR_EMPTY)
      .toLowerCase();
  }

  isResultExportHeader(header) {
    const key = this.normalizeResultHeaderKey(header);
    if (!key) {
      return false;
    }
    const knownKeys = new Set(
      [
        RESULT_COL_STATUS,
        RESULT_COL_ERRORS,
        FEC_BCH_ResultHdr_Status,
        FEC_BCH_ResultHdr_Errors,
        "Status",
        "Errors",
        "__Err"
      ].map((h) => this.normalizeResultHeaderKey(h))
    );
    return knownKeys.has(key);
  }

  getResultColumnExcludeIndices(headerRow) {
    const excludeIndices = new Set();
    if (!Array.isArray(headerRow)) {
      return excludeIndices;
    }
    headerRow.forEach((h, idx) => {
      if (this.isResultExportHeader(h)) {
        excludeIndices.add(idx);
      }
    });
    return excludeIndices;
  }

  stripResultColumnsFromImportLayout(headerRow, dataCells) {
    if (!Array.isArray(headerRow) || headerRow.length === 0) {
      return {
        headers: Array.isArray(headerRow) ? headerRow : [],
        cells: Array.isArray(dataCells) ? dataCells : []
      };
    }
    const excludeIndices = this.getResultColumnExcludeIndices(headerRow);
    if (excludeIndices.size === 0) {
      return {
        headers: headerRow,
        cells: Array.isArray(dataCells) ? dataCells : []
      };
    }
    return {
      headers: headerRow.filter((_, idx) => !excludeIndices.has(idx)),
      cells: Array.isArray(dataCells)
        ? dataCells.filter((_, idx) => !excludeIndices.has(idx))
        : []
    };
  }

  readFileAsArrayBuffer(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(reader.error || new Error("read error"));
      reader.readAsArrayBuffer(file);
    });
  }

  async handleDownloadZip() {
    if (!this.caseSetOptions.length) {
      await this.loadCaseSetOptions();
    }
    if (!this.selectedCaseSet) {
      this.caseSetRequiredError = true;
      return;
    }
    const [startRaw, endRaw] = this.selectedCaseSet.split("-");
    const startIndex = Number(startRaw);
    const endIndex = Number(endRaw);
    if (!startIndex || !endIndex) {
      this.caseSetRequiredError = true;
      return;
    }
    this.isLoading = true;
    try {
      const filtersJson = JSON.stringify(this.buildFiltersPayload());
      const res = await this.withTimeout(
        downloadAttachmentsZip({
          filtersJson,
          startIndex,
          endIndex
        }),
        ZIP_TIMEOUT_MS,
        ZIP_TIMEOUT_MESSAGE
      );
      if (res?.success && res?.downloadUrl) {
        window.open(res.downloadUrl, "_blank", "noopener,noreferrer");
        this.showSuccess(FEC_BCH_DownloadToastTitle, res.message || FEC_BCH_ZipCreatedSuccess);
      } else {
        this.showError(FEC_BCH_DownloadFailedTitle, res?.message || FEC_BCH_ZipCreateFailedBody);
      }
    } catch (error) {
      this.showError(FEC_BCH_DownloadFailedTitle, this.extractError(error));
    } finally {
      this.isLoading = false;
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get totalPages() {
    const size = Number(this.pageSize) || 10;
    return Math.max(1, Math.ceil(this.rows.length / size));
  }

  get previousDisabled() {
    return this.currentPage <= 1;
  }

  get nextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  async ensureSheetJsLoaded() {
    if (this.sheetJsReady) {
      return;
    }
    await loadScript(this, FEC_SheetJS);
    this.sheetJsReady = true;
  }

  resolveExportFileName(templateName, businessProcessCode) {
    const base =
      templateName && templateName.length
        ? templateName
        : `${businessProcessCode || "Other"}`;
    return base.toLowerCase().endsWith(VALID_FILE_EXTENSION)
      ? base
      : `${base}${VALID_FILE_EXTENSION}`;
  }

  normalizeExportHeader(cell) {
    return (cell == null ? STR_EMPTY : String(cell))
      .replace(/[\s_\-\/]+/g, STR_EMPTY)
      .replace(/[()]/g, STR_EMPTY)
      .replace(/\./g, STR_EMPTY)
      .replace(/:/g, STR_EMPTY)
      .replace(/,/g, STR_EMPTY)
      .replace(/</g, "lessthan")
      .replace(/>/g, "greaterthan")
      .replace(/&/g, "and")
      .toLowerCase();
  }

  resolveTemplateSheetLayout(aoa) {
    const rows = Array.isArray(aoa) ? aoa : [];
    let headerRowIndex = 0;
    let sectionRow = null;
    for (let i = 0; i < Math.min(rows.length, 25); i++) {
      const row = rows[i] || [];
      const normalized = row.map((h) => this.normalizeExportHeader(h));
      const hasCaseId =
        normalized.indexOf("caseid") >= 0 ||
        normalized.indexOf("caseidsearch") >= 0;
      if (hasCaseId) {
        headerRowIndex = i;
        if (i > 0) {
          sectionRow = Array.isArray(rows[i - 1]) ? [...rows[i - 1]] : null;
        }
        break;
      }
    }
    const headerRow = Array.isArray(rows[headerRowIndex])
      ? [...rows[headerRowIndex]]
      : [];
    return { sectionRow, headerRow, headerRowIndex };
  }

  resolveExportFieldKey(normalizedHeader, isCofOrGsr) {
    if (!normalizedHeader) {
      return null;
    }
    if (EXPORT_USER_FILL_HEADERS.has(normalizedHeader)) {
      return null;
    }
    if (HEADERS_CASE_ID.indexOf(normalizedHeader) >= 0) {
      return "caseIdSearch";
    }
    // Toannd 29/5/2026 - map cột original category/subcategory/subcode
    if (isCofOrGsr === true) {
      if (normalizedHeader === "category") {
        return "originalCategoryCode";
      }
      if (normalizedHeader === "subcategory") {
        return "originalSubCategoryCode";
      }
      if (normalizedHeader === "subcode") {
        return "originalSubCodeCode";
      }
    } else {
      if (normalizedHeader === "category") {
        return "categoryCode";
      }
      if (normalizedHeader === "subcategory") {
        return "subCategoryCode";
      }
      if (normalizedHeader === "subcode") {
        return "subCodeCode";
      }
    }
    if (EXPORT_HEADER_FIELD_MAP[normalizedHeader]) {
      return EXPORT_HEADER_FIELD_MAP[normalizedHeader];
    }
    return null;
  }

  // Toannd 29/5/2026 - nhận diện context COF/GSR export (cột assignment routing action)
  isCofOrGsrExportContext(templateMeta, headerRow, businessProcessCode) {
    const templateName = String(templateMeta?.templateName || STR_EMPTY)
      .trim()
      .toLowerCase();
    if (templateName.includes("cof") || templateName.includes("gsr")) {
      return true;
    }
    const bp = String(businessProcessCode || STR_EMPTY).trim().toLowerCase();
    if (bp.startsWith("cof") || bp.startsWith("gsr")) {
      return true;
    }
    const normalized = (headerRow || []).map((h) => this.normalizeExportHeader(h));
    if (
      this.findHeaderIndex(normalized, HEADERS_ASSIGNMENT_ID) >= 0 ||
      this.findHeaderIndex(normalized, HEADERS_ASSIGNMENT_ROUTING_ACTION) >= 0
    ) {
      return true;
    }
    return false;
  }

  buildExportColumnMappings(headerRow, isCofOrGsr) {
    const mappings = [];
    const normalized = (headerRow || []).map((h) =>
      this.normalizeExportHeader(h)
    );
    for (let i = 0; i < normalized.length; i++) {
      // Toannd 29/5/2026 - map cột original category/subcategory/subcode
      mappings.push(this.resolveExportFieldKey(normalized[i], isCofOrGsr));
    }
    return mappings;
  }

  // 27/05/2026 10:00 linhdev - Export with all Properties (SRS): helpers chèn cột Property trước Routing Action
  resolveRoutingActionInsertIndex(headerRow) {
    const normalized = (headerRow || []).map((h) => this.normalizeExportHeader(h));
    for (let i = 0; i < normalized.length; i += 1) {
      const token = normalized[i];
      if (!token) {
        continue;
      }
      if (HEADERS_ASSIGNMENT_ROUTING_ACTION.indexOf(token) >= 0) {
        continue;
      }
      if (HEADERS_ROUTING_ACTION.indexOf(token) >= 0) {
        return i;
      }
    }
    for (let i = 0; i < normalized.length; i += 1) {
      if (EXPORT_USER_FILL_HEADERS.has(normalized[i])) {
        return i;
      }
    }
    return normalized.length;
  }

  collectBusinessProcessCodesFromRows(rows) {
    const codes = new Set();
    (Array.isArray(rows) ? rows : []).forEach((r) => {
      const code = String(r?.businessProcessCode || STR_EMPTY).trim();
      const name = String(r?.businessProcessName || STR_EMPTY).trim();
      if (code) {
        codes.add(code);
      }
      if (name) {
        codes.add(name);
      }
    });
    return Array.from(codes);
  }

  collectCaseIdsFromRows(rows) {
    const ids = [];
    (Array.isArray(rows) ? rows : []).forEach((r) => {
      const caseId = r?.caseId;
      if (caseId) {
        ids.push(caseId);
      }
    });
    return ids;
  }

  async loadExportPropertyBundleForRows(rows) {
    if (this.includeAllProperties !== EXPORT_PROPERTY_YES) {
      return { columns: [], valuesByCaseId: {} };
    }
    const sourceRows = Array.isArray(rows) ? rows : [];
    if (!sourceRows.length) {
      return { columns: [], valuesByCaseId: {} };
    }
    try {
      return await getBulkExportPropertyBundle({
        businessProcessCodes: this.collectBusinessProcessCodesFromRows(sourceRows),
        caseIds: this.collectCaseIdsFromRows(sourceRows),
        includeAllProperties: true
      });
    } catch (error) {
      this.showError(FEC_BCH_ExportToastTitle, this.extractError(error));
      return { columns: [], valuesByCaseId: {} };
    }
  }

  buildPropertyInsertPayload(headerRow, caseRows, propertyBundle) {
    const columns = Array.isArray(propertyBundle?.columns) ? propertyBundle.columns : [];
    if (!columns.length) {
      return null;
    }
    const insertBefore = this.resolveRoutingActionInsertIndex(headerRow);
    const insertColumnHeaders = columns.map((c) => String(c?.label || STR_EMPTY));
    const valuesByCaseId = propertyBundle?.valuesByCaseId || {};
    const insertColumnValues = (Array.isArray(caseRows) ? caseRows : []).map((row) => {
      const caseValues = row?.caseId && valuesByCaseId[row.caseId] ? valuesByCaseId[row.caseId] : {};
      return columns.map((col) => {
        const key = col?.columnKey;
        if (!key || caseValues[key] == null) {
          return STR_EMPTY;
        }
        return String(caseValues[key]);
      });
    });
    return { insertColumnsBeforeIndex: insertBefore, insertColumnHeaders, insertColumnValues };
  }

  // 27/05/2026 10:00 linhdev - nén dòng export cho Apex (mappedColumnIndexes + mergeInsertColumnValues)
  compressExportDataRows(fullRows, mappings) {
    const out = [];
    const sourceRows = Array.isArray(fullRows) ? fullRows : [];
    const sourceMappings = Array.isArray(mappings) ? mappings : [];
    for (let i = 0; i < sourceRows.length; i += 1) {
      const cells = sourceRows[i] || [];
      const compressed = [];
      for (let j = 0; j < sourceMappings.length; j += 1) {
        if (sourceMappings[j]) {
          compressed.push(cells[j]);
        }
      }
      out.push(compressed);
    }
    return out;
  }

  buildMappedTemplateDataRows(caseRows, mappings) {
    const out = [];
    const sourceRows = Array.isArray(caseRows) ? caseRows : [];
    const sourceMappings = Array.isArray(mappings) ? mappings : [];
    for (let i = 0; i < sourceRows.length; i += 1) {
      // tungnm37 - keep full column alignment with template indexes; do not compress mapped cells
      out.push(this.mapCaseRowToExportCells(sourceRows[i], sourceMappings));
    }
    return out;
  }

  mapCaseRowToExportCells(caseRow, mappings) {
    return (mappings || []).map((fieldKey) => {
      if (!fieldKey) {
        return STR_EMPTY;
      }
      const val = caseRow[fieldKey];
      return val == null ? STR_EMPTY : String(val);
    });
  }

  resolveMainTemplateSheetName(workbook) {
    const names = Array.isArray(workbook?.SheetNames) ? workbook.SheetNames : [];
    for (let i = 0; i < names.length; i += 1) {
      const name = String(names[i] || STR_EMPTY);
      if (/^sheet\s*1$/i.test(name.trim())) {
        continue;
      }
      const sheet = workbook.Sheets[names[i]];
      if (!sheet) {
        continue;
      }
      const aoa = window.XLSX.utils.sheet_to_json(sheet, {
        header: 1,
        defval: STR_EMPTY,
        raw: false
      });
      const layout = this.resolveTemplateSheetLayout(aoa);
      if (!layout.headerRow.length) {
        continue;
      }
      const normalized = layout.headerRow.map((h) => this.normalizeExportHeader(h));
      if (
        normalized.indexOf("caseid") >= 0 ||
        normalized.indexOf("caseidsearch") >= 0
      ) {
        return names[i];
      }
    }
    for (let i = 0; i < names.length; i += 1) {
      const name = String(names[i] || STR_EMPTY);
      if (!/^sheet\s*1$/i.test(name.trim())) {
        return names[i];
      }
    }
    return names.length ? names[0] : STR_EMPTY;
  }

  base64ToArrayBuffer(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  // 27/05/2026 10:00 linhdev - propertyBundle: insertColumnsBeforeIndex/Headers/Values gửi FEC_BCH_TemplateExportService
  async buildExcelFileFromTemplate(rows, fileName, contentVersionId, templateMeta, propertyBundle) {
    if (!contentVersionId) {
      const templateName = String(templateMeta?.templateName || STR_EMPTY).trim();
      const hasUrl = !!String(templateMeta?.templateDownloadUrl || STR_EMPTY).trim();
      throw new Error(
        `[NO_TEMPLATE_CV] Missing template ContentVersion Id` +
        (templateName ? ` (template=${templateName})` : STR_EMPTY) +
        (hasUrl ? "" : "; no template file on FEC_Template_Import__c")
      );
    }
    await this.ensureSheetJsLoaded();
    const base64 = await getTemplateFileBase64({ contentVersionId });
    if (!base64) {
      throw new Error(
        `[TEMPLATE_READ_FAILED] contentVersionId=${contentVersionId}`
      );
    }
    const templateWorkbook = window.XLSX.read(this.base64ToArrayBuffer(base64), {
      type: "array",
      cellText: false,
      cellStyles: false
    });
    const sheetNames = Array.isArray(templateWorkbook.SheetNames)
      ? templateWorkbook.SheetNames
      : [];
    if (!sheetNames.length) {
      throw new Error(MSG_HEADER_INVALID);
    }
    const templateSheetName = this.resolveMainTemplateSheetName(templateWorkbook);
    const templateSheet = templateWorkbook.Sheets[templateSheetName];
    if (!templateSheet) {
      throw new Error(MSG_HEADER_INVALID);
    }
    const aoa = window.XLSX.utils.sheet_to_json(templateSheet, {
      header: 1,
      defval: STR_EMPTY,
      raw: false
    });
    if (!Array.isArray(aoa) || !aoa.length) {
      throw new Error(MSG_HEADER_INVALID);
    }
    const layout = this.resolveTemplateSheetLayout(aoa);
    const headerRow = layout.headerRow;
    if (!headerRow.length) {
      throw new Error(MSG_HEADER_INVALID);
    }
    const headerRowIndex =
      Number.isInteger(layout.headerRowIndex) && layout.headerRowIndex >= 0
        ? layout.headerRowIndex
        : 0;
    const list = Array.isArray(rows) ? rows : [];
    // Toannd 29/5/2026 - nhận diện context COF/GSR export (cột assignment routing action)
    const businessProcessCode =
      list[0]?.businessProcessCode || list[0]?.businessProcessName || STR_EMPTY;
    const isCofOrGsr = this.isCofOrGsrExportContext(
      templateMeta,
      headerRow,
      businessProcessCode
    );
    const finalMappings = this.buildExportColumnMappings(headerRow, isCofOrGsr);
    const fullRows = this.buildMappedTemplateDataRows(list, finalMappings);
    const dataRows = this.compressExportDataRows(fullRows, finalMappings);
    const mappedColumnIndexes = [];
    for (let i = 0; i < finalMappings.length; i += 1) {
      if (finalMappings[i]) {
        mappedColumnIndexes.push(i);
      }
    }
    const propertyInsert = this.buildPropertyInsertPayload(headerRow, list, propertyBundle);
    // 27/05/2026 13:15 linhdev - gửi sheet name cho Apex patch đúng worksheet đã map header
    const exportRequest = {
      contentVersionId,
      headerRowIndex,
      mappedColumnIndexes,
      dataRows,
      templateSheetName
    };
    // 27/05/2026 10:00 linhdev - chỉ khi Export with all Properties = Yes và có cột MDS
    if (propertyInsert) {
      exportRequest.insertColumnsBeforeIndex = propertyInsert.insertColumnsBeforeIndex;
      exportRequest.insertColumnHeaders = propertyInsert.insertColumnHeaders;
      exportRequest.insertColumnValues = propertyInsert.insertColumnValues;
    }
    const exportResult = await exportTemplateWorkbook({ requestJson: JSON.stringify(exportRequest) });
    if (!exportResult?.success || !exportResult?.base64Body) {
      const code = exportResult?.errorCode || "EXPORT_FAILED";
      const detail =
        exportResult?.errorMessage || FEC_BCH_CannotCreateExportFile;
      throw new Error(`[${code}] ${detail}`);
    }
    return { fileName, base64Body: exportResult.base64Body };
  }

  async refreshRows() {
    this.isLoading = true;
    try {
      const data = await getRecentRows();
      this.rows = Array.isArray(data) ? data.map((row) => this.normalizeRow(row)) : [];
      if (this.currentPage > this.totalPages) {
        this.currentPage = this.totalPages;
      }
      this.applyBulkSort();
    } catch (error) {
      this.rows = [];
      this.pagedRows = [];
      this.showError(FEC_BCH_LoadFailedTitle, this.extractError(error));
    } finally {
      this.isLoading = false;
    }
  }

  formatBulkCount(value) {
    const n = Number(value);
    return value == null || value === STR_EMPTY || Number.isNaN(n) ? "0" : String(Math.trunc(n));
  }

  normalizeRow(row) {
    const status = row.status || STR_EMPTY;
    const resultDownloadUrl = row.resultDownloadUrl || STR_EMPTY;
    const fileDownloadUrl = row.fileDownloadUrl || STR_EMPTY;
    const fileNameDisplay = String(row.fileName || STR_EMPTY).trim();
    const hasResultDownloadLink =
      (status === "Processed" || status === "Failure") && !!resultDownloadUrl;
    return {
      ...row,
      fileNameDisplay,
      fileDownloadUrl,
      hasFileDownloadLink: !!(fileDownloadUrl && fileNameDisplay),
      uploadedOnLabel: row.uploadedOn ? this.formatDateTime(row.uploadedOn) : STR_EMPTY,
      totalRecordsCount: this.formatBulkCount(row.totalRecordsCount),
      totalSuccessRecords: this.formatBulkCount(row.totalSuccessRecords),
      totalFailedRecords: this.formatBulkCount(row.totalFailedRecords),
      result: hasResultDownloadLink ? FEC_BCH_Col_Result : STR_EMPTY,
      resultDownloadUrl,
      hasResultDownloadLink
    };
  }

  handleBulkLinkClick(event) {
    const url = event.currentTarget?.dataset?.url;
    if (url) {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  formatDateTime(value) {
    try {
      const d = new Date(value);
      const pad = (n) => String(n).padStart(2, "0");
      if (Number.isNaN(d.getTime())) {
        return value;
      }
      return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
    } catch (e) {
      return value;
    }
  }

  handleBulkSort(event) {
    const key = event.currentTarget?.dataset?.key || STR_EMPTY;
    if (!key) {
      return;
    }
    if (this.bulkSortBy === key) {
      this.bulkSortDir = this.bulkSortDir === "asc" ? "desc" : "asc";
    } else {
      this.bulkSortBy = key;
      this.bulkSortDir = key === "uploadedOn" ? "desc" : "asc";
    }
    this.currentPage = 1;
    this.applyBulkSort();
  }

  applyBulkSort() {
    const key = this.bulkSortBy;
    const dir = this.bulkSortDir === "desc" ? -1 : 1;
    const valueOf = (row) => {
      if (key === "uploadedOn") {
        const v = row.uploadedOn;
        if (v == null || v === STR_EMPTY) {
          return 0;
        }
        const t = new Date(v).getTime();
        return Number.isNaN(t) ? 0 : t;
      }
      if (
        key === "totalRecordsCount" ||
        key === "totalSuccessRecords" ||
        key === "totalFailedRecords"
      ) {
        return Number(row[key]) || 0;
      }
      return String(row[key] || STR_EMPTY).toLowerCase();
    };
    this.rows = [...this.rows].sort((a, b) => {
      const av = valueOf(a);
      const bv = valueOf(b);
      if (av > bv) {
        return 1 * dir;
      }
      if (av < bv) {
        return -1 * dir;
      }
      return 0;
    });
    this.rebuildPageRows();
  }

  rebuildPageRows() {
    const size = Number(this.pageSize) || 10;
    const start = (this.currentPage - 1) * size;
    const slice = this.rows.slice(start, start + size);
    this.pagedRows = slice.map((row, idx) => ({
      ...row,
      rowIndex: start + idx + 1
    }));
    this.goToPageInput = String(this.currentPage);
  }

  handlePageSizeChange(event) {
    this.pageSize = event.detail.value;
    this.currentPage = 1;
    this.rebuildPageRows();
  }

  handleGoToPageInput(event) {
    this.goToPageInput = event.detail.value;
  }

  handleGoToPage() {
    const n = parseInt(this.goToPageInput, 10);
    if (Number.isNaN(n) || n < 1) {
      this.showInfo(FEC_BCH_InvalidPageTitle, FEC_BCH_InvalidPageBody);
      return;
    }
    const max = this.totalPages;
    const target = Math.min(Math.max(1, n), max);
    this.currentPage = target;
    this.goToPageInput = String(target);
    this.rebuildPageRows();
  }

  handlePreviousPage() {
    if (this.currentPage <= 1) {
      return;
    }
    this.currentPage -= 1;
    this.rebuildPageRows();
  }

  handleNextPage() {
    if (this.currentPage >= this.totalPages) {
      return;
    }
    this.currentPage += 1;
    this.rebuildPageRows();
  }

  async handleRefresh() {
    await this.refreshRows();
  }

  extractError(error) {
    return (
      error?.body?.message ||
      error?.message ||
      FEC_BCH_UnexpectedError
    );
  }

  showSuccess(title, message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant: "success"
      })
    );
  }

  showInfo(title, message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant: "info"
      })
    );
  }

  showError(title, message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant: "error"
      })
    );
  }
}