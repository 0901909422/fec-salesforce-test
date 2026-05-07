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
import downloadCaseAttachmentsZip from "@salesforce/apex/FEC_BatchCaseHandlingController.downloadCaseAttachmentsZip";
import zipExcelFiles from "@salesforce/apex/FEC_BatchCaseHandlingController.zipExcelFiles";
import importBatchData from "@salesforce/apex/FEC_BatchCaseHandlingController.importBatchData";
import saveResultFile from "@salesforce/apex/FEC_BatchCaseHandlingController.saveResultFile";
import logFailedImport from "@salesforce/apex/FEC_BatchCaseHandlingController.logFailedImport";
import FEC_SheetJS from "@salesforce/resourceUrl/FEC_SheetJS";
import { STR_EMPTY } from "c/fec_CommonConst";

function arrayBufferToBase64(buffer) {
  if (!buffer) {
    return "";
  }
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode.apply(null, chunk);
  }
  return btoa(binary);
}

const PAGE_SIZE_OPTIONS = [
  { label: "10", value: "10" },
  { label: "20", value: "20" },
  { label: "30", value: "30" },
  { label: "40", value: "40" },
  { label: "50", value: "50" }
];
const ZIP_TIMEOUT_MS = 60 * 1000;
const ZIP_TIMEOUT_MESSAGE =
  "Yêu cầu đã quá thời gian xử lý, vui lòng thử lại.";
const EXCEL_FILE_TIMEOUT_MS = 30 * 1000;
const EXCEL_FILE_TIMEOUT_MESSAGE =
  "Yêu cầu đã quá thời gian xử lý, vui lòng thử lại.";
const ACTION_DOWNLOAD_ATTACHMENTS = "download_attachments";
const ACTION_EXPORT_ALL = "export_all";
const ACTION_EXPORT_SELECTED = "export_selected";
const ACTION_IMPORT_UPDATE_DATA = "import_update_data";
const MSG_NO_DATA_EXPORT = "Không có dữ liệu để export.";
const MSG_NO_DATA_FOUND = "Không tìm thấy dữ liệu.";
const MSG_EXPORT_SUCCESS = "Xuất dữ liệu thành công";
const MSG_EXPORT_FAILED = "Xuất dữ liệu thất bại";
const MSG_IMPORT_SUCCESS = "Import dữ liệu thành công";
const MSG_IMPORT_FAILED = "Import dữ liệu thất bại";
const MSG_REQUIRE_FILE = "Vui lòng đính kèm tệp dữ liệu";
const MSG_INVALID_FILE_FORMAT =
  "Định dạng tệp không hợp lệ. Chỉ chấp nhận tệp .xlsx";
const MSG_FILE_TOO_LARGE =
  "Kích thước tệp vượt quá 150MB. Vui lòng kiểm tra lại.";
const MSG_FILE_NO_DATA =
  "Tệp đính kèm không có dữ liệu. Vui lòng kiểm tra lại.";
const MSG_HEADER_INVALID =
  "Tệp đính kèm thiếu cột bắt buộc (Case ID, Routing Action, Inputted Remarks).";
const IMPORT_TIMEOUT_MS = 60 * 1000;
const IMPORT_TIMEOUT_MESSAGE =
  "Yêu cầu đã quá thời gian xử lý, vui lòng thử lại.";
const MAX_UPLOAD_SIZE_BYTES = 150 * 1024 * 1024;
const VALID_FILE_EXTENSION = ".xlsx";
const HEADERS_CASE_ID = ["caseid", "caseidsearch"];
const HEADERS_ROUTING_ACTION = ["routingaction"];
const HEADERS_REMARKS = ["inputtedremarks", "remark", "remarks"];
const HEADERS_ASSIGNMENT_ID = ["assignmentid"];
const HEADERS_ASSIGNMENT_ROUTING_ACTION = ["assignmentroutingaction"];
const RESULT_HEADERS_BASIC = [
  "Case ID",
  "Routing Action",
  "Inputted Remarks",
  "__Status",
  "__Errors"
];
const RESULT_HEADERS_GSR = [
  "Case ID",
  "Routing Action",
  "Inputted Remarks",
  "Assignment ID",
  "Assignment Routing Action",
  "__Status",
  "__Errors"
];
const TEMPLATE_NAME_GSR = "GSR";
const TEMPLATE_NAME_OTHER = "Other";
const MSG_BP_REQUIRED = "Vui lòng chọn ít nhất một Business Process.";
const MSG_NO_BP_FOUND = "Không tìm thấy Business Process phù hợp.";
const MSG_TOO_MANY_ROWS =
  "Tổng số dòng vượt quá 100.000. Vui lòng thu hẹp bộ lọc.";
const EXPORT_MAX_ROWS = 100000;
const EXPORT_FETCH_PAGE_SIZE = 1000;
const EXPORT_PROPERTY_NO = "No";
const EXPORT_PROPERTY_YES = "Yes";
const EXPORT_PROPERTY_OPTIONS = [
  { label: "No", value: EXPORT_PROPERTY_NO },
  { label: "Yes", value: EXPORT_PROPERTY_YES }
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
  { label: "Has attachment", value: "true" },
  { label: "No attachment", value: "false" }
];

const FILTERED_CASE_EXPORT_HEADERS = [
  "Customer Type",
  "Case ID",
  "Category",
  "Sub Category",
  "Sub Code",
  "Case Status",
  "Case Created On",
  "Last Updated On",
  "Attachments"
];
const ACTION_OPTIONS = [
  { label: "--Chọn action--", value: STR_EMPTY },
  { label: "Download Attachments", value: ACTION_DOWNLOAD_ATTACHMENTS },
  { label: "Export All Data", value: ACTION_EXPORT_ALL },
  { label: "Export Selected Data", value: ACTION_EXPORT_SELECTED },
  { label: "Import Update Data", value: ACTION_IMPORT_UPDATE_DATA }
];

export default class Fec_BatchCaseHandling extends LightningElement {
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
  bpTemplateByCode = {};
  selectedImportFile = null;

  pageSizeOptions = PAGE_SIZE_OPTIONS;
  exportPropertyOptions = EXPORT_PROPERTY_OPTIONS;
  attachmentDownloadedByCase = {};
  actionOptions = ACTION_OPTIONS;

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
    const v = (row?.businessProcessName || row?.businessProcessCode || "")
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
        "Thông báo",
        `Không tải được metadata bộ lọc. ${this.extractError(error)}`
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
    const base = [{ label: "--Chọn thuộc tính--", value: STR_EMPTY }];
    const rest = (this.filterPropertyMeta || []).map((m) => ({
      label: m.label || m.propertyKey,
      value: m.propertyKey
    }));
    return [...base, ...rest];
  }

  operatorOptionsForLine(line) {
    const meta = line?.propertyKey ? this.filterMetaByKey[line.propertyKey] : null;
    const ops = meta?.operators || [];
    const opts = [{ label: "--Chọn toán tử--", value: STR_EMPTY }];
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
    const op = (line?.operatorKey || "").toLowerCase();
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
    const op = (line?.operatorKey || "").toLowerCase();
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
      const op = (line.operatorKey || "").toLowerCase();
      const needsValue = op !== "is_null" && op !== "is_not_null";
      let valueText = (line.valueText || "").trim();
      let valueList = null;
      if (line.propertyKey === "CUSTOMER_TYPE" && valueText.includes(",")) {
        valueList = valueText
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean);
        valueText = "";
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
        rowKey: String(r.caseId || ""),
        selected: false,
        caseCreatedOnLabel: this.formatDateTimeSafe(r.caseCreatedOn),
        lastUpdatedOnLabel: this.formatDateTimeSafe(r.lastUpdatedOn),
        hasAttachmentLabel: r.hasAttachment ? "Document" : "",
        attachmentDownloaded: !!this.attachmentDownloadedByCase[String(r.caseId || "")]
      }));
      this.applyCaseSort();
      this.caseSearchHasRun = true;
    } catch (error) {
      this.caseRows = [];
      this.caseTotalCount = 0;
      this.caseSearchHasRun = false;
      this.showError("Search failed", this.extractError(error));
    } finally {
      this.caseSearchLoading = false;
    }
  }

  formatDateTimeSafe(value) {
    if (value == null || value === "") {
      return "";
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
    return "Chưa có dữ liệu — thêm điều kiện lọc và bấm Filter Data.";
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
    const key = event.currentTarget?.dataset?.key || "";
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
      if (key === "caseCreatedOn") return row.caseCreatedOn || "";
      if (key === "lastUpdatedOn") return row.lastUpdatedOn || "";
      if (key === "hasAttachment") return row.hasAttachment ? 1 : 0;
      return String(row?.[key] || "").toLowerCase();
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
    const url = event.currentTarget?.dataset?.url || "";
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
    const caseId = event.currentTarget?.dataset?.caseid || "";
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
        this.showError("Download failed", res?.message || "Không thể tải tệp đính kèm.");
      }
    } catch (error) {
      this.showError("Download failed", this.extractError(error));
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
    let afterCaseId = "";
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
          caseCreatedOnLabel: this.formatDateTimeSafe(r.caseCreatedOn),
          lastUpdatedOnLabel: this.formatDateTimeSafe(r.lastUpdatedOn),
          hasAttachmentLabel: r.hasAttachment ? "Document" : ""
        });
      });
      afterCaseId = String(raw[raw.length - 1]?.caseId || "");
      if (!afterCaseId) {
        break;
      }
    }
    return all;
  }

  handleActionChange(event) {
    this.selectedAction = event.detail.value || "";
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
        this.showInfo("Export", "Chọn ít nhất một Case trong lưới.");
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
        this.showInfo("Export", MSG_NO_DATA_EXPORT);
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

    const templateByCode = {};
    (Array.isArray(bpInfo) ? bpInfo : []).forEach((b) => {
      if (b?.businessProcessCode) {
        templateByCode[b.businessProcessCode] = b.templateName || STR_EMPTY;
      }
    });
    this.bpTemplateByCode = templateByCode;

    const keysFromSource = new Set();
    sourceRows.forEach((r) => {
      const k = this.rowBusinessProcessKey(r);
      if (k) {
        keysFromSource.add(k);
      }
    });

    const list = (Array.isArray(bpInfo) ? bpInfo : [])
      .filter((b) => {
        const n = String(b.businessProcessCode || "").trim();
        return n && keysFromSource.has(n);
      })
      .map((b) => {
        const code = String(b.businessProcessCode || "").trim();
        return {
          rowKey: `bp-${code}`,
          businessProcessCode: code,
          templateName: templateByCode[code] || STR_EMPTY,
          selected: true
        };
      });

    if (!list.length) {
      this.showInfo("Export", MSG_NO_BP_FOUND);
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
      const av = String(a?.businessProcessCode || "").toLowerCase();
      const bv = String(b?.businessProcessCode || "").toLowerCase();
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
    const noun = total === 1 ? "item" : "items";
    return `${total} ${noun} • Sorted by Business Process Name`;
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
    const code = event.currentTarget?.dataset?.code || "";
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
    this.bpTemplateByCode = {};
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
      this.showError("Export", MSG_BP_REQUIRED);
      return;
    }
    const selectedSet = new Set(selectedBpCodes);
    const rows = (this.bpExportSourceRows || []).filter((r) =>
      selectedSet.has(this.rowBusinessProcessKey(r))
    );
    if (!rows.length) {
      this.showInfo("Export", MSG_NO_DATA_EXPORT);
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
        const tmplName = this.bpTemplateByCode[bp];
        const fileName =
          tmplName && tmplName.length ? tmplName : `${bp || "Other"}.xlsx`;
        const file = await this.withTimeout(
          this.buildExcelFile(groups[bp], fileName),
          EXCEL_FILE_TIMEOUT_MS,
          EXCEL_FILE_TIMEOUT_MESSAGE
        );
        filesPayload.push(file);
      }

      if (!filesPayload.length) {
        this.showInfo("Export", MSG_NO_DATA_EXPORT);
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
        this.showSuccess("Download", MSG_EXPORT_SUCCESS);
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
      detail || "Không thể tạo file xuất dữ liệu."
    );
  }

  handleImportFileChange(event) {
    const file = event.target?.files?.[0];
    if (!file) {
      return;
    }
    const lowerName = (file.name || "").toLowerCase();
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
      detail || `Không thể import ${fileName || "tệp dữ liệu"}.`
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
      defval: ""
    });
    if (!Array.isArray(aoa) || aoa.length === 0) {
      return null;
    }
    const headerRow = aoa[0] || [];
    const normalized = headerRow.map((h) =>
      (h == null ? "" : String(h)).replace(/\s+/g, "").toLowerCase()
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
        idxAssignmentId >= 0 ? this.cellAsString(r[idxAssignmentId]) : "";
      const assignmentRoutingAction =
        idxAssignmentRouting >= 0
          ? this.cellAsString(r[idxAssignmentRouting])
          : "";
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
      return "";
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
        r.caseIdSearch || "",
        r.routingAction || "",
        r.inputtedRemarks || ""
      ];
      if (isCofOrGsr) {
        baseRow.push(r.assignmentId || "");
        baseRow.push(r.assignmentRoutingAction || "");
      }
      baseRow.push(meta.status || "");
      baseRow.push(meta.errors || "");
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
    const baseName = (originalFileName || "Import").replace(/\.[^.]+$/, "");
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
        this.showSuccess("Download", res.message || "Đã tạo file ZIP.");
      } else {
        this.showError("Download failed", res?.message || "Không thể tạo file ZIP.");
      }
    } catch (error) {
      this.showError("Download failed", this.extractError(error));
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
    await loadScript(this, FEC_SheetJS);
    this.sheetJsReady = true;
  }

  buildExcelFile(rows, fileName) {
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        try {
          const list = Array.isArray(rows) ? rows : [];
          const exportRows = list.map((r) => [
            String(r?.customerType || ""),
            String(r?.caseIdSearch || ""),
            String(r?.categoryCode || ""),
            String(r?.subCategoryCode || ""),
            String(r?.subCodeCode || ""),
            String(r?.caseStatus || ""),
            String(r?.caseCreatedOnLabel || ""),
            String(r?.lastUpdatedOnLabel || ""),
            String(r?.hasAttachmentLabel || "")
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
      this.showError("Load failed", this.extractError(error));
    } finally {
      this.isLoading = false;
    }
  }

  normalizeRow(row) {
    const status = row.status || "";
    const resultLabel =
      status === "Processed" || status === "Failure" ? "Result" : "";
    return {
      ...row,
      fileDownloadUrl: row.fileDownloadUrl || "",
      uploadedOnLabel: row.uploadedOn ? this.formatDateTime(row.uploadedOn) : "",
      totalRecordsCount: row.totalRecordsCount ?? 0,
      totalSuccessRecords: row.totalSuccessRecords ?? 0,
      totalFailedRecords: row.totalFailedRecords ?? 0,
      result: resultLabel,
      resultDownloadUrl: row.resultDownloadUrl || ""
    };
  }

  handleResultClick(event) {
    const url = event.currentTarget?.dataset?.url || "";
    if (url) {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  handleFileNameClick(event) {
    const url = event.currentTarget?.dataset?.url || "";
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
      this.showInfo("Invalid page", "Enter a page number ≥ 1.");
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
      "Unexpected error"
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
