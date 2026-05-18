import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadScript } from "lightning/platformResourceLoader";
import getRecentRows from "@salesforce/apex/FEC_BatchCaseHandlingController.getRecentRows";
import getCaseFilterPropertyMetadata from "@salesforce/apex/FEC_BatchCaseHandlingController.getCaseFilterPropertyMetadata";
import searchBulkCases from "@salesforce/apex/FEC_BatchCaseHandlingController.searchBulkCases";
import searchBulkCasesForExport from "@salesforce/apex/FEC_BatchCaseHandlingController.searchBulkCasesForExport";
import getAttachmentCaseSetOptions from "@salesforce/apex/FEC_BatchCaseHandlingController.getAttachmentCaseSetOptions";
import downloadAttachmentsZip from "@salesforce/apex/FEC_BatchCaseHandlingController.downloadAttachmentsZip";
import getBusinessProcessExportRows from "@salesforce/apex/FEC_BatchCaseHandlingController.getBusinessProcessExportRows";
import getTemplateFileBase64 from "@salesforce/apex/FEC_BatchCaseHandlingController.getTemplateFileBase64";
import downloadCaseAttachmentsZip from "@salesforce/apex/FEC_BatchCaseHandlingController.downloadCaseAttachmentsZip";
import zipExcelFiles from "@salesforce/apex/FEC_BatchCaseHandlingController.zipExcelFiles";
import importBatchData from "@salesforce/apex/FEC_BatchCaseHandlingController.importBatchData";
import saveResultFile from "@salesforce/apex/FEC_BatchCaseHandlingController.saveResultFile";
import logFailedImport from "@salesforce/apex/FEC_BatchCaseHandlingController.logFailedImport";
import FEC_SheetJS from "@salesforce/resourceUrl/FEC_SheetJS";
import { STR_EMPTY } from "c/fec_CommonConst";
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
import FEC_BCH_ResultHdr_RoutingAction from "@salesforce/label/c.FEC_BCH_ResultHdr_RoutingAction";
import FEC_BCH_ResultHdr_Remarks from "@salesforce/label/c.FEC_BCH_ResultHdr_Remarks";
import FEC_BCH_ResultHdr_Status from "@salesforce/label/c.FEC_BCH_ResultHdr_Status";
import FEC_BCH_ResultHdr_Errors from "@salesforce/label/c.FEC_BCH_ResultHdr_Errors";
import FEC_BCH_ResultHdr_AssignmentId from "@salesforce/label/c.FEC_BCH_ResultHdr_AssignmentId";
import FEC_BCH_ResultHdr_AssignmentRouting from "@salesforce/label/c.FEC_BCH_ResultHdr_AssignmentRouting";
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
const MSG_EXPORT_SUCCESS = FEC_BCH_ExportSuccess;
const MSG_EXPORT_FAILED = FEC_BCH_ExportFailed;
const MSG_IMPORT_SUCCESS = FEC_BCH_ImportSuccess;
const MSG_IMPORT_FAILED = FEC_BCH_ImportFailed;
const MSG_REQUIRE_FILE = FEC_BCH_RequireFile;
const MSG_INVALID_FILE_FORMAT = FEC_BCH_InvalidFileFormat;
const MSG_FILE_TOO_LARGE = FEC_BCH_FileTooLarge;
const MSG_FILE_NO_DATA = FEC_BCH_FileNoData;
const MSG_HEADER_INVALID = FEC_BCH_HeaderInvalid;
const IMPORT_TIMEOUT_MS = 60 * 1000;
const IMPORT_TIMEOUT_MESSAGE = FEC_BCH_RequestTimeout;
const MAX_UPLOAD_SIZE_BYTES = 150 * 1024 * 1024;
const VALID_FILE_EXTENSION = ".xlsx";
const HEADERS_CASE_ID = ["caseid", "caseidsearch"];
const HEADERS_ROUTING_ACTION = ["routingaction"];
const HEADERS_REMARKS = ["inputtedremarks", "remark", "remarks"];
const HEADERS_ASSIGNMENT_ID = ["assignmentid"];
const HEADERS_ASSIGNMENT_ROUTING_ACTION = ["assignmentroutingaction"];
const EXPORT_USER_FILL_HEADERS = new Set([
  ...HEADERS_ROUTING_ACTION,
  ...HEADERS_REMARKS,
  ...HEADERS_ASSIGNMENT_ROUTING_ACTION
]);
const EXPORT_HEADER_FIELD_MAP = {
  customername: "customerName",
  accountcontractnumber: "accountContractNumber",
  appid: "appId",
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
  originalcategory: "originalCategoryDisplay",
  originalsubcategory: "originalSubCategoryDisplay",
  originalsubcode: "originalSubCodeDisplay",
  updatedcategory: "categoryDisplay",
  updatedsubcategory: "subCategoryDisplay",
  updatedsubcode: "subCodeDisplay",
  category: "categoryDisplay",
  subcategory: "subCategoryDisplay",
  subcode: "subCodeDisplay",
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
  evaluationbysales: "evaluationBySales",
  disciplineresult: "disciplineResult",
  contactpoint: "contactPoint",
  teamleader: "teamLeader",
  supervisor: "supervisor",
  pendingcssupport: "pendingCsSupportLabel"
};
const FILTERED_EXPORT_EXTRA_COLUMNS = [
  { header: FEC_BCH_Col_CustomerType, field: "customerType" },
  { header: FEC_BCH_Col_CaseId, field: "caseIdSearch" },
  { header: FEC_BCH_Col_Category, field: "categoryCode" },
  { header: FEC_BCH_Col_SubCategory, field: "subCategoryCode" },
  { header: FEC_BCH_Col_SubCode, field: "subCodeCode" },
  { header: FEC_BCH_Col_CaseStatus, field: "caseStatus" },
  { header: FEC_BCH_Col_CaseCreatedOn, field: "caseCreatedOnLabel" },
  { header: FEC_BCH_Col_LastUpdatedOn, field: "lastUpdatedOnLabel" },
  { header: FEC_BCH_Col_Attachments, field: "hasAttachmentLabel" }
];
const RESULT_HEADERS_BASIC = [
  FEC_BCH_Col_CaseId,
  FEC_BCH_ResultHdr_RoutingAction,
  FEC_BCH_ResultHdr_Remarks,
  FEC_BCH_ResultHdr_Status,
  FEC_BCH_ResultHdr_Errors
];
const RESULT_HEADERS_GSR = [
  FEC_BCH_Col_CaseId,
  FEC_BCH_ResultHdr_RoutingAction,
  FEC_BCH_ResultHdr_Remarks,
  FEC_BCH_ResultHdr_AssignmentId,
  FEC_BCH_ResultHdr_AssignmentRouting,
  FEC_BCH_ResultHdr_Status,
  FEC_BCH_ResultHdr_Errors
];
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

const FILTERED_CASE_EXPORT_HEADERS = [
  FEC_BCH_Col_CustomerType,
  FEC_BCH_Col_CaseId,
  FEC_BCH_Col_Category,
  FEC_BCH_Col_SubCategory,
  FEC_BCH_Col_SubCode,
  FEC_BCH_Col_CaseStatus,
  FEC_BCH_Col_CaseCreatedOn,
  FEC_BCH_Col_LastUpdatedOn,
  FEC_BCH_Col_Attachments
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
  @track filterLines = [];
  @track caseRows = [];
  @track caseTotalCount = 0;
  @track casePageSize = "20";
  @track caseSearchPage = 1;
  @track caseSearchLoading = false;
  @track caseSearchHasRun = false;
  @track filterResetHint = false;
  @track selectedAction = STR_EMPTY;
  @track caseSetOptions = [];
  @track selectedCaseSet = STR_EMPTY;
  @track actionRequiredError = false;
  @track caseSetRequiredError = false;
  @track caseSortBy = "caseCreatedOn";
  @track caseSortDir = "asc";
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

  rowBusinessProcessKey(row) {
    const v = (row?.businessProcessName || row?.businessProcessCode || STR_EMPTY)
      .trim();
    return v;
  }

  async connectedCallback() {
    this.loadAttachmentDownloadedState();
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

  async loadFilterMetadata() {
    try {
      const data = await getCaseFilterPropertyMetadata();
      this.filterPropertyMeta = Array.isArray(data) ? data : [];
      this.filterMetaByKey = {};
      this.filterPropertyMeta.forEach((m) => {
        if (m?.propertyKey) {
          this.filterMetaByKey[m.propertyKey] = m;
        }
      });
      if (!this.filterLines.length) {
        this.addFilterLine();
      }
    } catch (error) {
      this.filterPropertyMeta = [];
      this.filterMetaByKey = {};
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
        propertyKey: STR_EMPTY,
        operatorKey: STR_EMPTY,
        valueText: STR_EMPTY
      }
    ];
  }

  handleAddFilterLine() {
    this.addFilterLine();
  }

  handleRemoveFilterLine(event) {
    const rowId = event.currentTarget?.dataset?.rowid;
    if (!rowId) {
      return;
    }
    const next = this.filterLines.filter((l) => l.rowId !== rowId);
    this.filterResetHint = false;
    this.filterLines = next.length ? next : [];
    if (!this.filterLines.length) {
      this.addFilterLine();
    }
  }

  get propertyOptionsForFilter() {
    const base = [{ label: FEC_BCH_FilterPickProperty, value: STR_EMPTY }];
    const rest = (this.filterPropertyMeta || []).map((m) => ({
      label: m.label || m.propertyKey,
      value: m.propertyKey
    }));
    return [...base, ...rest];
  }

  operatorOptionsForLine(line) {
    const meta = line?.propertyKey ? this.filterMetaByKey[line.propertyKey] : null;
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
    this.filterLines = this.filterLines.map((l) => {
      if (l.rowId !== rowId) {
        return l;
      }
      const meta = value ? this.filterMetaByKey[value] : null;
      const firstOp =
        meta?.operators && meta.operators.length ? meta.operators[0] : STR_EMPTY;
      return { ...l, propertyKey: value, operatorKey: firstOp, valueText: STR_EMPTY };
    });
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
    const meta = line?.propertyKey ? this.filterMetaByKey[line.propertyKey] : null;
    if (!meta) {
      return "text";
    }
    if (meta.valueType === "date") {
      return "date";
    }
    return "text";
  }

  showValueInput(line) {
    const op = (line?.operatorKey || STR_EMPTY).toLowerCase();
    if (op === "is_null" || op === "is_not_null") {
      return false;
    }
    const meta = line?.propertyKey ? this.filterMetaByKey[line.propertyKey] : null;
    if (meta?.valueType === "checkbox") {
      return false;
    }
    return true;
  }

  showAttachmentValueCombobox(line) {
    const meta = line?.propertyKey ? this.filterMetaByKey[line.propertyKey] : null;
    if (!meta || meta.valueType !== "checkbox") {
      return false;
    }
    const op = (line?.operatorKey || STR_EMPTY).toLowerCase();
    if (op === "is_null" || op === "is_not_null") {
      return false;
    }
    return true;
  }

  get filterLinesView() {
    return (this.filterLines || []).map((line) => ({
      ...line,
      operatorOptions: this.operatorOptionsForLine(line),
      showValueBox: this.showValueInput(line),
      showAttachCombo: this.showAttachmentValueCombobox(line),
      valueTypeAttr: this.valueInputType(line)
    }));
  }

  get attachmentPicklistOptions() {
    return ATTACHMENT_VALUE_OPTIONS;
  }

  buildFiltersPayload() {
    const out = [];
    for (const line of this.filterLines) {
      if (!line.propertyKey || !line.operatorKey) {
        continue;
      }
      const op = (line.operatorKey || STR_EMPTY).toLowerCase();
      const needsValue = op !== "is_null" && op !== "is_not_null";
      let valueText = (line.valueText || STR_EMPTY).trim();
      let valueList = null;
      if (line.propertyKey === "CUSTOMER_TYPE" && valueText.includes(",")) {
        valueList = valueText
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean);
        valueText = STR_EMPTY;
      }
      if (needsValue && !valueText && (!valueList || !valueList.length)) {
        continue;
      }
      const entry = {
        propertyKey: line.propertyKey,
        operatorKey: line.operatorKey,
        valueText
      };
      if (valueList && valueList.length) {
        entry.valueList = valueList;
      }
      out.push(entry);
    }
    return out;
  }

  async handleFilterData() {
    this.filterResetHint = false;
    this.caseSearchPage = 1;
    this.exportSuccessMessage = STR_EMPTY;
    this.exportErrorMessage = STR_EMPTY;
    await this.runCaseSearch();
  }

  handleResetFilters() {
    this.filterResetHint = true;
    this.caseSearchHasRun = false;
    this.filterLines = [];
    this.addFilterLine();
    this.caseRows = [];
    this.caseTotalCount = 0;
    this.caseSearchPage = 1;
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
      const ps = Number(this.casePageSize) || 20;
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
        selected: false,
        caseCreatedOnLabel: this.formatDateTimeSafe(r.caseCreatedOn),
        lastUpdatedOnLabel: this.formatDateTimeSafe(r.lastUpdatedOn),
        hasAttachmentLabel: r.hasAttachment ? FEC_BCH_DocumentLinkLabel : STR_EMPTY,
        attachmentDownloaded: !!this.attachmentDownloadedByCase[String(r.caseId || STR_EMPTY)]
      }));
      this.applyCaseSort();
      this.caseSearchHasRun = true;
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
    return Number(this.casePageSize) || 20;
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

  get hasCaseRows() {
    return this.caseRows.length > 0;
  }

  get hasValidFilterPayload() {
    return this.buildFiltersPayload().length > 0;
  }

  get filterDataDisabled() {
    return this.caseSearchLoading || !this.hasValidFilterPayload;
  }

  get emptyCasesMessage() {
    if (this.caseSearchHasRun) {
      return MSG_NO_DATA_FOUND;
    }
    return FEC_BCH_EmptyCasesHint;
  }

  get selectedCaseCount() {
    return this.caseRows.filter((r) => r.selected).length;
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
    this.runCaseSearch();
  }

  handleCasePreviousPage() {
    if (this.caseSearchPage <= 1) {
      return;
    }
    this.caseSearchPage -= 1;
    this.runCaseSearch();
  }

  handleCaseNextPage() {
    if (this.caseSearchPage >= this.caseTotalPages) {
      return;
    }
    this.caseSearchPage += 1;
    this.runCaseSearch();
  }

  handleCaseRowSelect(event) {
    const id = event.currentTarget?.dataset?.caseid;
    const checked = !!event.detail?.checked;
    this.caseRows = this.caseRows.map((r) =>
      r.caseId === id ? { ...r, selected: checked } : r
    );
  }

  handleCaseSelectAll(event) {
    const checked = !!event.detail?.checked;
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
    while (all.length < total && all.length < EXPORT_MAX_ROWS) {
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
      if (!afterCaseId) {
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
      sourceRows = this.caseRows.filter((r) => r.selected);
      if (!sourceRows.length) {
        this.showInfo(FEC_BCH_ExportToastTitle, FEC_BCH_SelectAtLeastOneCase);
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

    const templateMetaByCode = {};
    (Array.isArray(bpInfo) ? bpInfo : []).forEach((b) => {
      if (b?.businessProcessCode) {
        templateMetaByCode[b.businessProcessCode] = {
          templateName: b.templateName || STR_EMPTY,
          templateDownloadUrl: b.templateDownloadUrl || STR_EMPTY,
          templateContentVersionId: b.templateContentVersionId || null
        };
      }
    });
    this.bpTemplateMetaByCode = templateMetaByCode;

    const keysFromSource = new Set();
    sourceRows.forEach((r) => {
      const k = this.rowBusinessProcessKey(r);
      if (k) {
        keysFromSource.add(k);
      }
    });

    const list = (Array.isArray(bpInfo) ? bpInfo : [])
      .filter((b) => {
        const n = String(b.businessProcessCode || STR_EMPTY).trim();
        return n && keysFromSource.has(n);
      })
      .map((b) => {
        const code = String(b.businessProcessCode || STR_EMPTY).trim();
        return {
          rowKey: `bp-${code}`,
          businessProcessCode: code,
          templateName: (templateMetaByCode[code] || {}).templateName || STR_EMPTY,
          selected: true
        };
      });

    if (!list.length) {
      this.showInfo(FEC_BCH_ExportToastTitle, MSG_NO_BP_FOUND);
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

  async handleBpSubmit() {
    if (this.bpSubmitLoading) {
      return;
    }
    const selectedBpCodes = this.bpRows
      .filter((r) => r.selected)
      .map((r) => r.businessProcessCode);
    if (!selectedBpCodes.length) {
      this.showError(FEC_BCH_ExportToastTitle, MSG_BP_REQUIRED);
      return;
    }
    const selectedSet = new Set(selectedBpCodes);
    const rows = (this.bpExportSourceRows || []).filter((r) =>
      selectedSet.has(this.rowBusinessProcessKey(r))
    );
    if (!rows.length) {
      this.showInfo(FEC_BCH_ExportToastTitle, MSG_NO_DATA_EXPORT);
      return;
    }

    const groups = {};
    rows.forEach((r) => {
      const bp = this.rowBusinessProcessKey(r) || "Other";
      if (!groups[bp]) {
        groups[bp] = [];
      }
      groups[bp].push(r);
    });

    this.bpSubmitLoading = true;
    this.isLoading = true;
    try {
      await this.ensureSheetJsLoaded();
      const filesPayload = [];
      const bpKeys = Object.keys(groups);
      for (let i = 0; i < bpKeys.length; i += 1) {
        const bp = bpKeys[i];
        const tmplMeta = this.bpTemplateMetaByCode[bp] || {};
        const fileName = this.resolveExportFileName(
          tmplMeta.templateName,
          bp
        );
        const file = await this.withTimeout(
          this.buildExcelFileFromTemplate(
            groups[bp],
            fileName,
            tmplMeta.templateContentVersionId
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
    this.exportErrorMessage = MSG_EXPORT_FAILED;
    const detail =
      typeof error === "string" ? error : this.extractError(error);
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

  async handleImportData() {
    this.importSuccessMessage = STR_EMPTY;
    this.importErrorMessage = STR_EMPTY;
    this.attachDataRequiredError = false;
    if (!this.selectedImportFile) {
      this.attachDataRequiredError = true;
      this.importErrorMessage = MSG_REQUIRE_FILE;
      return;
    }
    const file = this.selectedImportFile;
    const fileName = this.selectedImportFileName;
    if (!this.sheetJsReady) {
      try {
        await loadScript(this, FEC_SheetJS + "/xlsx.full.min.js");
        this.sheetJsReady = true;
      } catch (e) {
        this.handleImportFailure(e, fileName);
        return;
      }
    }
    this.isImportSubmitting = true;
    this.isLoading = true;
    try {
      const arrayBuffer = await this.readFileAsArrayBuffer(file);
      const fileBodyBase64 = arrayBufferToBase64(arrayBuffer);
      const parsed = this.parseImportWorkbook(arrayBuffer);
      if (!parsed) {
        this.handleImportFailure(MSG_HEADER_INVALID, fileName);
        await this.safeLogFailedImport(
          fileName,
          TEMPLATE_NAME_OTHER,
          MSG_HEADER_INVALID
        );
        return;
      }
      const { rows, isCofOrGsr, originalHeaders } = parsed;
      if (!rows.length) {
        this.handleImportFailure(MSG_FILE_NO_DATA, fileName);
        await this.safeLogFailedImport(
          fileName,
          isCofOrGsr ? TEMPLATE_NAME_GSR : TEMPLATE_NAME_OTHER,
          MSG_FILE_NO_DATA
        );
        return;
      }
      const templateName = isCofOrGsr ? TEMPLATE_NAME_GSR : TEMPLATE_NAME_OTHER;
      const result = await this.withTimeout(
        importBatchData({
          fileName,
          fileBodyBase64,
          templateName,
          rowsJson: JSON.stringify(rows)
        }),
        IMPORT_TIMEOUT_MS,
        IMPORT_TIMEOUT_MESSAGE
      );
      if (!result || result.success !== true) {
        this.handleImportFailure(
          result?.message || MSG_IMPORT_FAILED,
          fileName
        );
        await this.refreshRows();
        return;
      }
      const resultRows = this.parseResultRows(result.resultRowsJson);
      try {
        await this.saveResultWorkbook(
          result.batchRecordId,
          fileName,
          isCofOrGsr,
          originalHeaders,
          rows,
          resultRows
        );
      } catch (saveErr) {
        // Result file generation failure does not invalidate the import itself
      }
      this.importSuccessMessage = MSG_IMPORT_SUCCESS;
      this.importErrorMessage = STR_EMPTY;
      this.showSuccess(MSG_IMPORT_SUCCESS, result.message || STR_EMPTY);
      this.clearSelectedImportFile();
      await this.refreshRows();
    } catch (error) {
      this.handleImportFailure(error, fileName);
      await this.safeLogFailedImport(
        fileName,
        TEMPLATE_NAME_OTHER,
        this.extractError(error)
      );
    } finally {
      this.isImportSubmitting = false;
      this.isLoading = false;
    }
  }

  handleImportFailure(error, fileName) {
    this.importSuccessMessage = STR_EMPTY;
    const detail =
      typeof error === "string" ? error : this.extractError(error);
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

  parseResultRows(rowsJson) {
    if (!rowsJson) {
      return [];
    }
    try {
      const arr = JSON.parse(rowsJson);
      return Array.isArray(arr) ? arr : [];
    } catch (e) {
      return [];
    }
  }

  parseImportWorkbook(arrayBuffer) {
    if (typeof window.XLSX === "undefined") {
      return null;
    }
    const workbook = window.XLSX.read(arrayBuffer, { type: "array" });
    const firstSheetName = workbook.SheetNames?.[0];
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
    const headerRow = aoa[0] || [];
    const normalized = headerRow.map((h) =>
      (h == null ? STR_EMPTY : String(h)).replace(/\s+/g, STR_EMPTY).toLowerCase()
    );
    const idxCaseId = this.findHeaderIndex(normalized, HEADERS_CASE_ID);
    const idxRouting = this.findHeaderIndex(normalized, HEADERS_ROUTING_ACTION);
    const idxRemark = this.findHeaderIndex(normalized, HEADERS_REMARKS);
    if (idxCaseId < 0 || idxRouting < 0 || idxRemark < 0) {
      return null;
    }
    const idxAssignmentId = this.findHeaderIndex(
      normalized,
      HEADERS_ASSIGNMENT_ID
    );
    const idxAssignmentRouting = this.findHeaderIndex(
      normalized,
      HEADERS_ASSIGNMENT_ROUTING_ACTION
    );
    const isCofOrGsr = idxAssignmentId >= 0 || idxAssignmentRouting >= 0;
    const rows = [];
    for (let i = 1; i < aoa.length; i++) {
      const r = aoa[i] || [];
      const caseIdSearch = this.cellAsString(r[idxCaseId]);
      const routingAction = this.cellAsString(r[idxRouting]);
      const inputtedRemarks = this.cellAsString(r[idxRemark]);
      const assignmentId =
        idxAssignmentId >= 0 ? this.cellAsString(r[idxAssignmentId]) : STR_EMPTY;
      const assignmentRoutingAction =
        idxAssignmentRouting >= 0
          ? this.cellAsString(r[idxAssignmentRouting])
          : STR_EMPTY;
      if (
        !caseIdSearch &&
        !routingAction &&
        !inputtedRemarks &&
        !assignmentId &&
        !assignmentRoutingAction
      ) {
        continue;
      }
      rows.push({
        caseIdSearch,
        routingAction,
        inputtedRemarks,
        assignmentId,
        assignmentRoutingAction
      });
    }
    return { rows, isCofOrGsr, originalHeaders: headerRow };
  }

  findHeaderIndex(normalizedHeaders, candidates) {
    for (let i = 0; i < normalizedHeaders.length; i++) {
      if (candidates.indexOf(normalizedHeaders[i]) >= 0) {
        return i;
      }
    }
    return -1;
  }

  cellAsString(value) {
    if (value === null || value === undefined) {
      return STR_EMPTY;
    }
    return String(value).trim();
  }

  readFileAsArrayBuffer(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(reader.error || new Error("read error"));
      reader.readAsArrayBuffer(file);
    });
  }

  async saveResultWorkbook(
    batchRecordId,
    originalFileName,
    isCofOrGsr,
    originalHeaders,
    inputRows,
    resultRows
  ) {
    if (!batchRecordId) {
      return;
    }
    if (typeof window.XLSX === "undefined") {
      return;
    }
    const headers = isCofOrGsr ? RESULT_HEADERS_GSR : RESULT_HEADERS_BASIC;
    const sheetData = [headers];
    const resultByIndex = Array.isArray(resultRows) ? resultRows : [];
    for (let i = 0; i < inputRows.length; i++) {
      const r = inputRows[i] || {};
      const meta = resultByIndex[i] || {};
      const baseRow = [
        r.caseIdSearch || STR_EMPTY,
        r.routingAction || STR_EMPTY,
        r.inputtedRemarks || STR_EMPTY
      ];
      if (isCofOrGsr) {
        baseRow.push(r.assignmentId || STR_EMPTY);
        baseRow.push(r.assignmentRoutingAction || STR_EMPTY);
      }
      baseRow.push(meta.status || STR_EMPTY);
      baseRow.push(meta.errors || STR_EMPTY);
      sheetData.push(baseRow);
    }
    const workbook = window.XLSX.utils.book_new();
    const sheet = window.XLSX.utils.aoa_to_sheet(sheetData);
    window.XLSX.utils.book_append_sheet(workbook, sheet, "Result");
    const arrayBuffer = window.XLSX.write(workbook, {
      bookType: "xlsx",
      type: "array"
    });
    const base64 = arrayBufferToBase64(arrayBuffer);
    const baseName = (originalFileName || "Import").replace(/\.[^.]+$/, STR_EMPTY);
    const resultFileName = `${baseName}_Result.xlsx`;
    await saveResultFile({
      batchRecordId,
      resultFileName,
      fileBodyBase64: base64
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
    const size = Number(this.pageSize) || 20;
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
    await loadScript(this, FEC_SheetJS + "/xlsx.full.min.js");
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
      .toLowerCase();
  }

  resolveTemplateSheetLayout(aoa) {
    const rows = Array.isArray(aoa) ? aoa : [];
    let headerRowIndex = 0;
    let sectionRow = null;
    for (let i = 0; i < Math.min(rows.length, 6); i++) {
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

  resolveExportFieldKey(normalizedHeader) {
    if (!normalizedHeader) {
      return null;
    }
    if (EXPORT_USER_FILL_HEADERS.has(normalizedHeader)) {
      return null;
    }
    if (HEADERS_CASE_ID.indexOf(normalizedHeader) >= 0) {
      return "caseIdSearch";
    }
    if (EXPORT_HEADER_FIELD_MAP[normalizedHeader]) {
      return EXPORT_HEADER_FIELD_MAP[normalizedHeader];
    }
    return null;
  }

  buildExportColumnMappings(headerRow) {
    const mappings = [];
    const normalized = (headerRow || []).map((h) =>
      this.normalizeExportHeader(h)
    );
    for (let i = 0; i < normalized.length; i++) {
      mappings.push(this.resolveExportFieldKey(normalized[i]));
    }
    return mappings;
  }

  appendExtraExportColumns(headerRow, mappings) {
    if (this.includeAllProperties !== EXPORT_PROPERTY_YES) {
      return { headerRow, mappings };
    }
    const outHeader = Array.isArray(headerRow) ? [...headerRow] : [];
    const outMappings = Array.isArray(mappings) ? [...mappings] : [];
    const existing = new Set(
      outHeader.map((h) => this.normalizeExportHeader(h))
    );
    FILTERED_EXPORT_EXTRA_COLUMNS.forEach((col) => {
      const norm = this.normalizeExportHeader(col.header);
      if (existing.has(norm)) {
        return;
      }
      outHeader.push(col.header);
      outMappings.push(col.field);
      existing.add(norm);
    });
    return { headerRow: outHeader, mappings: outMappings };
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

  base64ToArrayBuffer(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
  }

  async loadTemplateSheetData(contentVersionId) {
    const cacheKey = String(contentVersionId || STR_EMPTY);
    if (cacheKey && this.templateFileCache[cacheKey]) {
      return this.templateFileCache[cacheKey];
    }
    const base64 = await getTemplateFileBase64({
      contentVersionId
    });
    if (!base64) {
      return null;
    }
    const arrayBuffer = this.base64ToArrayBuffer(base64);
    const workbook = window.XLSX.read(arrayBuffer, {
      type: "array",
      cellText: false
    });
    const sheetName =
      Array.isArray(workbook.SheetNames) && workbook.SheetNames.length > 0
        ? workbook.SheetNames[0]
        : STR_EMPTY;
    if (!sheetName) {
      return null;
    }
    const sheet = workbook.Sheets[sheetName];
    const aoa = window.XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      defval: STR_EMPTY,
      raw: false
    });
    if (!Array.isArray(aoa) || !aoa.length) {
      return null;
    }
    const parsed = { sheetName, aoa };
    if (cacheKey) {
      this.templateFileCache[cacheKey] = parsed;
    }
    return parsed;
  }

  async buildExcelFileFromTemplate(rows, fileName, contentVersionId) {
    await this.ensureSheetJsLoaded();
    if (!contentVersionId) {
      return this.buildExcelFile(rows, fileName);
    }
    let templateData;
    try {
      templateData = await this.loadTemplateSheetData(contentVersionId);
    } catch (e) {
      templateData = null;
    }
    if (!templateData || !templateData.aoa || !templateData.aoa.length) {
      return this.buildExcelFile(rows, fileName);
    }
    const layout = this.resolveTemplateSheetLayout(templateData.aoa);
    const headerRow = layout.headerRow;
    if (!headerRow.length) {
      return this.buildExcelFile(rows, fileName);
    }
    let mappings = this.buildExportColumnMappings(headerRow);
    const extended = this.appendExtraExportColumns(headerRow, mappings);
    const finalHeader = extended.headerRow;
    const finalMappings = extended.mappings;
    const list = Array.isArray(rows) ? rows : [];
    const dataRows = list.map((r) =>
      this.mapCaseRowToExportCells(r, finalMappings)
    );
    const sheetData = [];
    if (
      layout.sectionRow &&
      layout.sectionRow.some((cell) => String(cell || STR_EMPTY).trim().length)
    ) {
      sheetData.push(layout.sectionRow);
    }
    sheetData.push(finalHeader, ...dataRows);
    const workbook = window.XLSX.utils.book_new();
    const sheet = window.XLSX.utils.aoa_to_sheet(sheetData);
    window.XLSX.utils.book_append_sheet(
      workbook,
      sheet,
      templateData.sheetName || "Sheet1"
    );
    const wbout = window.XLSX.write(workbook, {
      type: "array",
      bookType: "xlsx",
      compression: true
    });
    const base64 = arrayBufferToBase64(wbout);
    return { fileName, base64Body: base64 };
  }

  buildExcelFile(rows, fileName) {
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        try {
          const list = Array.isArray(rows) ? rows : [];
          const exportRows = list.map((r) => [
            String(r?.customerType || STR_EMPTY),
            String(r?.caseIdSearch || STR_EMPTY),
            String(r?.categoryCode || STR_EMPTY),
            String(r?.subCategoryCode || STR_EMPTY),
            String(r?.subCodeCode || STR_EMPTY),
            String(r?.caseStatus || STR_EMPTY),
            String(r?.caseCreatedOnLabel || STR_EMPTY),
            String(r?.lastUpdatedOnLabel || STR_EMPTY),
            String(r?.hasAttachmentLabel || STR_EMPTY)
          ]);
          const worksheet = window.XLSX.utils.aoa_to_sheet([
            FILTERED_CASE_EXPORT_HEADERS,
            ...exportRows
          ]);
          const workbook = window.XLSX.utils.book_new();
          window.XLSX.utils.book_append_sheet(workbook, worksheet, "Cases");
          const wbout = window.XLSX.write(workbook, {
            type: "array",
            bookType: "xlsx",
            compression: true
          });
          const base64 = arrayBufferToBase64(wbout);
          resolve({ fileName, base64Body: base64 });
        } catch (err) {
          reject(err);
        }
      }, 0);
    });
  }

  async refreshRows() {
    this.isLoading = true;
    try {
      const data = await getRecentRows();
      this.rows = Array.isArray(data) ? data.map((row) => this.normalizeRow(row)) : [];
      if (this.currentPage > this.totalPages) {
        this.currentPage = this.totalPages;
      }
      this.rebuildPageRows();
    } catch (error) {
      this.rows = [];
      this.pagedRows = [];
      this.showError(FEC_BCH_LoadFailedTitle, this.extractError(error));
    } finally {
      this.isLoading = false;
    }
  }

  normalizeRow(row) {
    const status = row.status || STR_EMPTY;
    const resultLabel =
      status === "Processed" || status === "Failure" ? FEC_BCH_Col_Result : STR_EMPTY;
    return {
      ...row,
      fileDownloadUrl: row.fileDownloadUrl || STR_EMPTY,
      uploadedOnLabel: row.uploadedOn ? this.formatDateTime(row.uploadedOn) : STR_EMPTY,
      totalRecordsCount: row.totalRecordsCount ?? 0,
      totalSuccessRecords: row.totalSuccessRecords ?? 0,
      totalFailedRecords: row.totalFailedRecords ?? 0,
      result: resultLabel,
      resultDownloadUrl: row.resultDownloadUrl || STR_EMPTY
    };
  }

  handleResultClick(event) {
    const url = event.currentTarget?.dataset?.url || STR_EMPTY;
    if (url) {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  handleFileNameClick(event) {
    const url = event.currentTarget?.dataset?.url || STR_EMPTY;
    if (url) {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  formatDateTime(value) {
    try {
      return new Intl.DateTimeFormat("en-GB", {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
      }).format(new Date(value));
    } catch (e) {
      return value;
    }
  }

  rebuildPageRows() {
    const size = Number(this.pageSize) || 20;
    const start = (this.currentPage - 1) * size;
    this.pagedRows = this.rows.slice(start, start + size);
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