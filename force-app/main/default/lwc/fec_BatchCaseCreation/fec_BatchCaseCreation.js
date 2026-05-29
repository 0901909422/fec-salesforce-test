import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadScript } from "lightning/platformResourceLoader";
import getRecentRows from "@salesforce/apex/FEC_BatchCaseCreationController.getRecentRows";
import importBatchData from "@salesforce/apex/FEC_BatchCaseCreationController.importBatchData";
import saveResultFile from "@salesforce/apex/FEC_BatchCaseCreationController.saveResultFile";
import logFailedImport from "@salesforce/apex/FEC_BatchCaseCreationController.logFailedImport";
import getTemplateOptions from "@salesforce/apex/FEC_BatchCaseCreationController.getTemplateOptions";
import runPendingImportBatch from "@salesforce/apex/FEC_BatchCaseCreationController.runPendingImportBatch";
import FEC_Batch_RequestTimeout from "@salesforce/label/c.FEC_Batch_RequestTimeout";
import FEC_Batch_FileExcelXlsxOnly from "@salesforce/label/c.FEC_Batch_FileExcelXlsxOnly";
import FEC_Batch_FileMaxSize150MB from "@salesforce/label/c.FEC_Batch_FileMaxSize150MB";
import FEC_Batch_TemplateNoAttachment from "@salesforce/label/c.FEC_Batch_TemplateNoAttachment";
import FEC_Batch_Msg_InvalidImportData from "@salesforce/label/c.FEC_Batch_Msg_InvalidImportData";
import FEC_Batch_Msg_CannotReadExcelContent from "@salesforce/label/c.FEC_Batch_Msg_CannotReadExcelContent";
import FEC_Batch_Msg_Select_Template from "@salesforce/label/c.FEC_Batch_Msg_Select_Template";
import FEC_Batch_Import_Missing_Excel_Column from "@salesforce/label/c.FEC_Batch_Import_Missing_Excel_Column";
import FEC_Msg_Process_End_Of_Day from "@salesforce/label/c.FEC_Msg_Process_End_Of_Day";
import FEC_Batch_Import_Contract_Header_Ambiguous from "@salesforce/label/c.FEC_Batch_Import_Contract_Header_Ambiguous";
import FEC_SheetJS from "@salesforce/resourceUrl/FEC_SheetJS";
import {
  normalizeHeaderCell,
  findColumnIndex,
  formatSpreadsheetCellValueAsText,
  getSheetJsCellDisplayText,
  normalizeNoteTextSafe,
  promiseWithTimeoutSafe,
  arrayBufferToBase64Safe,
  buildResultXlsxFileName,
  formatDateTimeEnGb,
  extractErrorMessage
} from "c/fec_CommonUtils";
const PAGE_SIZE_OPTIONS = [
  { label: "10", value: "10" },
  { label: "20", value: "20" },
  { label: "30", value: "30" },
  { label: "40", value: "40" },
  { label: "50", value: "50" }
];
const MAX_UPLOAD_SIZE_BYTES = 150 * 1024 * 1024;
const IMPORT_TIMEOUT_MS = 60 * 1000;
const IMPORT_TIMEOUT_MESSAGE = FEC_Batch_RequestTimeout;
/** Hai layout: simple (8 cột) và extended (thêm channel / sub channel / email). */
const HEADER_WELCOME_CONTRACT = ["contract number"];
const HEADER_OTHER_CONTRACT = [
  "account/ contract number",
  "account/contract number",
  "account contract number"
];
const IMPORT_FILE_TYPE_WELCOME = "welcome";
const IMPORT_FILE_TYPE_OTHER = "other";
const HEADER_INTERACTION_PHONE = [
  "interaction phone",
  "interection phone",
  "interestion phone",
  "interaction phone number",
  "phone"
];
const RESULT_APPEND_HEADERS = [
  "__Status",
  "__Interaction ID",
  "__Case ID",
  "__Errors"
];

const cellValueForSourceRow = (value) => formatSpreadsheetCellValueAsText(value);

/** Cột cần giữ dạng text trong file result (account/contract, phone). */
const isTextPreserveResultColumn = (header) => {
  const norm = normalizeHeaderCell(header);
  if (!norm) {
    return false;
  }
  if (norm.includes("account") && norm.includes("contract")) {
    return true;
  }
  if (norm.includes("contract number")) {
    return true;
  }
  if (norm.includes("interaction phone") || norm === "phone") {
    return true;
  }
  return false;
};

const applyTextFormatToWorksheetColumns = (worksheet, headers, rowCount) => {
  if (!worksheet || !Array.isArray(headers) || rowCount < 2 || !window.XLSX) {
    return;
  }
  headers.forEach((header, colIdx) => {
    if (!isTextPreserveResultColumn(header)) {
      return;
    }
    for (let rowIdx = 1; rowIdx < rowCount; rowIdx += 1) {
      const cellRef = window.XLSX.utils.encode_cell({ c: colIdx, r: rowIdx });
      const cell = worksheet[cellRef];
      if (!cell) {
        continue;
      }
      const text = formatSpreadsheetCellValueAsText(cell.v ?? cell.w ?? "");
      worksheet[cellRef] = { t: "s", v: text, w: text };
    }
  });
};

const isResultExportCutoffHeader = (header) => {
  const norm = normalizeHeaderCell(header);
  if (!norm) {
    return false;
  }
  if (norm === "note" || norm === "id" || norm === "status" || norm === "errors") {
    return true;
  }
  return norm.startsWith("__");
};

const trimSourceForResultExport = (headers, rows) => {
  const headerList = Array.isArray(headers) ? headers : [];
  let cutoff = headerList.length;
  headerList.forEach((header, idx) => {
    if (isResultExportCutoffHeader(header)) {
      cutoff = Math.min(cutoff, idx);
    }
  });
  const exportHeaders = headerList.slice(0, cutoff);
  const exportRows = (Array.isArray(rows) ? rows : []).map((row) =>
    exportHeaders.map((_, colIdx) => {
      const value = Array.isArray(row) ? row[colIdx] : "";
      return formatSpreadsheetCellValueAsText(value);
    })
  );
  return { headers: exportHeaders, rows: exportRows };
};

const formatErrorsForExport = (errors) =>
  String(errors ?? "")
    .replace(/[\r\n\u2028\u2029]+/g, ", ")
    .replace(/\s*,\s*/g, ", ")
    .replace(/,(\s*,)+/g, ",")
    .replace(/^,\s*|\s*,$/g, "")
    .trim();

export default class Fec_BatchCaseCreation extends LightningElement {
  labelSelectTemplate = FEC_Batch_Msg_Select_Template;

  @track activeSettingSections = ["setting"];
  @track activeProcessedSections = ["processed"];

  @track rows = [];
  @track pagedRows = [];
  @track selectedTemplate = "";
  @track selectedFileName = "";
  @track isLoading = false;
  @track goToPageInput = "1";
  @track templateRequiredError = false;
  @track fileRequiredError = false;
  @track attachDataRequiredError = false;
  @track importValidationError = "";

  currentPage = 1;
  pageSize = "20";
  sortBy = "uploadedOn";
  sortDirection = "desc";
  selectedFile;
  sheetJsReady = false;
  templateDownloadUrlByValue = {};
  pendingImportHeaders = [];
  pendingImportSourceRows = [];
  pendingImportRows = [];

  templateOptions = [];
  pageSizeOptions = PAGE_SIZE_OPTIONS;

  async connectedCallback() {
    await this.loadTemplateOptions();
    this.refreshRows();
  }

  async loadTemplateOptions() {
    try {
      const data = await getTemplateOptions();
      const dynamicOptions = Array.isArray(data)
        ? data
            .filter((item) => item && item.value)
            .map((item) => ({
              label: item.label || item.value,
              value: item.value
            }))
        : [];
      this.templateDownloadUrlByValue = {};
      (Array.isArray(data) ? data : []).forEach((item) => {
        if (item?.value) {
          this.templateDownloadUrlByValue[item.value] = item.downloadUrl || "";
        }
      });

      this.templateOptions = [
        { label: "--None--", value: "" },
        ...dynamicOptions
      ];

      const hasCurrentValue = dynamicOptions.some(
        (opt) => opt.value === this.selectedTemplate
      );
      if (!hasCurrentValue) {
        this.selectedTemplate = "";
      }
    } catch (error) {
      this.templateOptions = [];
      this.templateDownloadUrlByValue = {};
      this.selectedTemplate = "";
      this.showInfo(
        "Thông báo",
        `Không tải được danh sách mẫu từ cấu hình. ${extractErrorMessage(error)}`
      );
    }
  }

  handleSettingSectionToggle(event) {
    const open = event.detail?.openSections;
    if (Array.isArray(open)) {
      this.activeSettingSections = [...open];
    }
  }

  handleProcessedSectionToggle(event) {
    const open = event.detail?.openSections;
    if (Array.isArray(open)) {
      this.activeProcessedSections = [...open];
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

  get hasAttachedFile() {
    return !!(this.selectedFile && this.selectedFileName);
  }

  get fileNameSortIcon() {
    return this.getSortIcon("fileName");
  }

  get uploadedOnSortIcon() {
    return this.getSortIcon("uploadedOn");
  }

  get uploadedBySortIcon() {
    return this.getSortIcon("uploadedBy");
  }

  get totalRecordsCountSortIcon() {
    return this.getSortIcon("totalRecordsCount");
  }

  get totalSuccessRecordsSortIcon() {
    return this.getSortIcon("totalSuccessRecords");
  }

  get totalFailedRecordsSortIcon() {
    return this.getSortIcon("totalFailedRecords");
  }

  get statusSortIcon() {
    return this.getSortIcon("status");
  }

  get resultSortIcon() {
    return this.getSortIcon("result");
  }

  getSortIcon(fieldName) {
    if (this.sortBy !== fieldName) {
      return "utility:arrowdown";
    }
    return this.sortDirection === "asc" ? "utility:arrowup" : "utility:arrowdown";
  }

  handleTemplateChange(event) {
    this.selectedTemplate = event.detail.value;
    this.templateRequiredError = false;
    this.fileRequiredError = false;
    this.attachDataRequiredError = false;
    this.importValidationError = "";
    this.pendingImportHeaders = [];
    this.pendingImportSourceRows = [];
    this.pendingImportRows = [];
  }

  handleChooseFile() {
    const input = this.template.querySelector('[data-id="batch-file-input"]');
    if (input) {
      input.click();
    }
  }

  handleFileSelected(event) {
    const file = event.target.files && event.target.files[0];
    this.selectedFile = null;
    this.selectedFileName = "";
    this.fileRequiredError = false;
    this.attachDataRequiredError = false;
    this.importValidationError = "";
    this.pendingImportHeaders = [];
    this.pendingImportSourceRows = [];
    this.pendingImportRows = [];
    if (file) {
      const lowerName = (file.name || "").toLowerCase();
      if (!lowerName.endsWith(".xlsx")) {
        this.importValidationError = FEC_Batch_FileExcelXlsxOnly;
      } else if ((file.size || 0) > MAX_UPLOAD_SIZE_BYTES) {
        this.importValidationError = FEC_Batch_FileMaxSize150MB;
      } else {
        this.selectedFile = file;
        this.selectedFileName = file.name;
      }
    }
    event.target.value = "";
  }

  handleClearFile(event) {
    event.stopPropagation();
    this.selectedFile = null;
    this.selectedFileName = "";
    this.fileRequiredError = false;
    this.attachDataRequiredError = false;
    this.importValidationError = "";
  }

  handleDownloadTemplate() {
    const key = (this.selectedTemplate || "").trim();
    if (!key) {
      this.templateRequiredError = true;
      this.fileRequiredError = false;
      this.attachDataRequiredError = false;
      return;
    }
    this.templateRequiredError = false;
    this.importValidationError = "";
    this.attachDataRequiredError = false;
    const url = this.templateDownloadUrlByValue[key] || "";
    if (!url) {
      this.showError(
        "Thông báo",
        FEC_Batch_TemplateNoAttachment
      );
      return;
    }
    window.open(url, "_blank", "noopener,noreferrer");
  }

  async ensureSheetJsLoaded() {
    if (this.sheetJsReady) {
      return;
    }
    await loadScript(this, FEC_SheetJS);
    this.sheetJsReady = true;
  }

  async validateCaseBatchExcel(file) {
    await this.ensureSheetJsLoaded();
    const data = await this.readFileAsArrayBuffer(file);
    const workbook = window.XLSX.read(data, {
      type: "array",
      cellText: true,
      cellNF: true
    });
    const firstSheetName =
      Array.isArray(workbook.SheetNames) && workbook.SheetNames.length > 0
        ? workbook.SheetNames[0]
        : "";
    if (!firstSheetName) {
      return { ok: false, noData: true };
    }
    const sheet = workbook.Sheets[firstSheetName];
    if (!sheet || sheet["!ref"] == null) {
      return { ok: false, noData: true };
    }

    const rowsAoA = window.XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      defval: "",
      raw: true
    });
    if (!Array.isArray(rowsAoA) || rowsAoA.length === 0) {
      return { ok: false, noData: true };
    }

    const headerRow = rowsAoA[0];
    if (!Array.isArray(headerRow)) {
      return { ok: false, noData: true };
    }
    const originalHeaders = headerRow.map((c) => (c == null ? "" : String(c)));

    const headersNorm = headerRow.map((c) => normalizeHeaderCell(c));
    const idxChannel = findColumnIndex(headersNorm, ["interaction channel"]);
    const extended = idxChannel >= 0;

    const idxWelcomeContract = findColumnIndex(headersNorm, HEADER_WELCOME_CONTRACT);
    const idxOtherContract = findColumnIndex(headersNorm, HEADER_OTHER_CONTRACT);
    let fileType = "";
    let idxContract = -1;
    if (idxWelcomeContract >= 0 && idxOtherContract >= 0) {
      return {
        ok: false,
        message: FEC_Batch_Import_Contract_Header_Ambiguous
      };
    }
    if (idxWelcomeContract >= 0) {
      fileType = IMPORT_FILE_TYPE_WELCOME;
      idxContract = idxWelcomeContract;
    } else if (idxOtherContract >= 0) {
      fileType = IMPORT_FILE_TYPE_OTHER;
      idxContract = idxOtherContract;
    }
    const idxPhone = findColumnIndex(headersNorm, HEADER_INTERACTION_PHONE);
    const idxProduct = findColumnIndex(headersNorm, ["product type"]);
    const idxCategory = findColumnIndex(headersNorm, ["category"]);
    const idxSubCat = findColumnIndex(headersNorm, ["sub category"]);
    const idxSubCode = findColumnIndex(headersNorm, ["sub code"]);
    const idxCaseStatus = findColumnIndex(headersNorm, ["case status"]);
    const idxRemarks = findColumnIndex(headersNorm, ["case remarks"]);
    const idxSubChannel = findColumnIndex(headersNorm, [
      "interaction sub channel"
    ]);
    const idxEmail = findColumnIndex(headersNorm, ["interaction email"]);

    const missing = [];
    if (idxContract < 0) {
      missing.push("Contract Number hoặc Account/ Contract Number");
    }
    if (idxPhone < 0 && fileType === IMPORT_FILE_TYPE_WELCOME) {
      missing.push("Interaction Phone");
    }
    if (idxProduct < 0) {
      missing.push("Product Type");
    }
    if (idxCategory < 0) {
      missing.push("Category");
    }
    if (idxSubCat < 0) {
      missing.push("Sub Category");
    }
    if (idxSubCode < 0) {
      missing.push("Sub Code");
    }
    if (idxCaseStatus < 0) {
      missing.push("Case Status");
    }
    if (extended) {
      if (idxChannel < 0) {
        missing.push("Interaction Channel");
      }
      if (idxSubChannel < 0) {
        missing.push("Interaction Sub Channel");
      }
    }
    if (missing.length > 0) {
      return {
        ok: false,
        message: FEC_Batch_Import_Missing_Excel_Column.replace("{0}", missing.join(", "))
      };
    }

    const cellAt = (rowArr, colIdx, rowIndex) => {
      if (colIdx < 0) {
        return "";
      }
      if (sheet && Number.isInteger(rowIndex) && rowIndex >= 0) {
        return getSheetJsCellDisplayText(sheet, rowIndex, colIdx);
      }
      if (!Array.isArray(rowArr)) {
        return "";
      }
      return cellValueForSourceRow(rowArr[colIdx]);
    };

    let dataRowCount = 0;
    const sourceRows = [];
    const importRows = [];
    for (let i = 1; i < rowsAoA.length; i += 1) {
      const rowArr = rowsAoA[i];
      const contractNumber = cellAt(rowArr, idxContract, i);
      const interactionPhone = cellAt(rowArr, idxPhone, i);
      const productType = cellAt(rowArr, idxProduct, i);
      const category = cellAt(rowArr, idxCategory, i);
      const subCategory = cellAt(rowArr, idxSubCat, i);
      const subCode = cellAt(rowArr, idxSubCode, i);
      const caseStatus = cellAt(rowArr, idxCaseStatus, i);
      const rawCaseRemarks =
        idxRemarks >= 0 ? cellAt(rowArr, idxRemarks, i) : "";
      const caseRemarks = normalizeNoteTextSafe(rawCaseRemarks);
      const interactionChannel = extended ? cellAt(rowArr, idxChannel, i) : "";
      const interactionSubChannel = extended
        ? cellAt(rowArr, idxSubChannel, i)
        : "";
      const interactionEmail = extended ? cellAt(rowArr, idxEmail, i) : "";

      if (
        !contractNumber &&
        !interactionPhone &&
        !productType &&
        !category &&
        !subCategory &&
        !subCode &&
        !caseStatus
      ) {
        continue;
      }
      dataRowCount += 1;
      sourceRows.push(
        originalHeaders.map((_, idx) => getSheetJsCellDisplayText(sheet, i, idx))
      );
      importRows.push({
        fileType,
        layout: extended ? "extended" : "simple",
        contractNumber,
        interactionPhone,
        productType,
        category,
        subCategory,
        subCode,
        caseStatus,
        caseRemarks,
        interactionChannel,
        interactionSubChannel,
        interactionEmail
      });
    }
    if (dataRowCount === 0) {
      return { ok: false, noData: true };
    }
    return {
      ok: true,
      message: "",
      fileType,
      headers: originalHeaders,
      sourceRows,
      rows: importRows
    };
  }

  readFileAsArrayBuffer(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(new Error("Cannot read selected file."));
      reader.readAsArrayBuffer(file);
    });
  }

  async handleImportData() {
    this.importValidationError = "";
    this.attachDataRequiredError = false;
    const key = (this.selectedTemplate || "").trim();
    this.templateRequiredError = false;

    const fileToUpload = this.selectedFile;
    if (!fileToUpload) {
      this.fileRequiredError = false;
      this.attachDataRequiredError = true;
      return;
    }
    this.fileRequiredError = false;
    this.attachDataRequiredError = false;

    const lowerName = (fileToUpload.name || "").toLowerCase();
    if (!lowerName.endsWith(".xlsx")) {
      this.importValidationError = FEC_Batch_FileExcelXlsxOnly;
      await this.logFailedImportAttempt(
        fileToUpload.name,
        key,
        this.importValidationError
      );
      return;
    }
    if ((fileToUpload.size || 0) > MAX_UPLOAD_SIZE_BYTES) {
      this.importValidationError = FEC_Batch_FileMaxSize150MB;
      await this.logFailedImportAttempt(
        fileToUpload.name,
        key,
        this.importValidationError
      );
      return;
    }
    try {
      const check = await this.validateCaseBatchExcel(fileToUpload);
      if (!check.ok) {
        if (check.noData) {
          this.attachDataRequiredError = true;
          await this.logFailedImportAttempt(
            fileToUpload.name,
            key,
            "Vui lòng đính kèm tệp dữ liệu"
          );
        } else {
          this.importValidationError = check.message || "";
          await this.logFailedImportAttempt(
            fileToUpload.name,
            key,
            this.importValidationError || FEC_Batch_Msg_InvalidImportData
          );
        }
        return;
      }
      this.pendingImportHeaders = Array.isArray(check.headers) ? check.headers : [];
      this.pendingImportSourceRows = Array.isArray(check.sourceRows)
        ? check.sourceRows
        : [];
      this.pendingImportRows = Array.isArray(check.rows) ? check.rows : [];
    } catch {
      this.importValidationError = FEC_Batch_Msg_CannotReadExcelContent;
      await this.logFailedImportAttempt(
        fileToUpload.name,
        key,
        this.importValidationError
      );
      return;
    }

    this.isLoading = true;
    try {
      const base64 = await this.readFileAsBase64(fileToUpload);
      const result = await promiseWithTimeoutSafe(
        importBatchData({
          fileName: fileToUpload.name,
          fileBodyBase64: base64,
          templateName: key,
          rowsJson: JSON.stringify(this.pendingImportRows || []),
          sourceHeadersJson: JSON.stringify(this.pendingImportHeaders || []),
          sourceRowsJson: JSON.stringify(this.pendingImportSourceRows || [])
        }),
        IMPORT_TIMEOUT_MS,
        IMPORT_TIMEOUT_MESSAGE
      );
      const importStatus = (result?.status || "").trim();
      const isDeferredUpload = importStatus === "Uploaded";
      // Server tạo xlsx result (EOD); client xlsx khi có resultRowsJson (import đồng bộ).
      if (result?.batchRecordId && result?.resultRowsJson) {
        try {
          await this.saveResultWorkbook(
            result.batchRecordId,
            fileToUpload.name,
            result.resultRowsJson,
            this.pendingImportHeaders,
            this.pendingImportSourceRows
          );
        } catch (saveErr) {
          // Batch row + server xlsx result still allow download; do not block table refresh.
          // eslint-disable-next-line no-console
          console.warn("saveResultWorkbook", saveErr);
        }
      }
      if (result?.success) {
        const successMessage = isDeferredUpload
          ? result.message || FEC_Msg_Process_End_Of_Day
          : result.message || "Import started.";
        this.showSuccess("Success", successMessage);
        this.selectedFile = null;
        this.selectedFileName = "";
        this.pendingImportHeaders = [];
        this.pendingImportSourceRows = [];
        this.pendingImportRows = [];
        this.importValidationError = "";
        this.attachDataRequiredError = false;
      } else {
        // Validation/DML failure: bảng lịch sử + Result đã có — không hiện toast đỏ.
        this.importValidationError = result?.batchRecordId
          ? ""
          : result?.message || "";
      }
    } catch (error) {
      if (error?.message === IMPORT_TIMEOUT_MESSAGE) {
        this.importValidationError = IMPORT_TIMEOUT_MESSAGE;
      } else {
        this.importValidationError = extractErrorMessage(error);
      }
    } finally {
      try {
        await this.refreshRows(false, true);
      } catch (refreshErr) {
        // eslint-disable-next-line no-console
        console.warn("refreshRows", refreshErr);
      }
      this.isLoading = false;
    }
  }

  async refreshRows(showLoading = true, resetToFirstPage = false) {
    if (showLoading) {
      this.isLoading = true;
    }
    try {
      const data = await getRecentRows();
      this.rows = Array.isArray(data) ? data.map((row) => this.normalizeRow(row)) : [];
      this.sortRows();
      if (resetToFirstPage) {
        this.currentPage = 1;
        this.goToPageInput = "1";
      } else if (this.currentPage > this.totalPages) {
        this.currentPage = this.totalPages;
      }
      this.rebuildPageRows();
    } catch (error) {
      this.rows = [];
      this.pagedRows = [];
      this.showError("Load failed", extractErrorMessage(error));
    } finally {
      if (showLoading) {
        this.isLoading = false;
      }
    }
  }

  normalizeRow(row) {
    const status = row.status || "";
    const resultLabel =
      status === "Processed" || status === "Failure" ? "Result" : "";
    const showResultDownload =
      status === "Processed" || status === "Failure";
    return {
      ...row,
      fileDownloadUrl: row.fileDownloadUrl || "",
      uploadedOnLabel: row.uploadedOn ? formatDateTimeEnGb(row.uploadedOn) : "",
      totalRecordsCount: row.totalRecordsCount ?? 0,
      totalSuccessRecords: row.totalSuccessRecords ?? 0,
      totalFailedRecords: row.totalFailedRecords ?? 0,
      result: resultLabel,
      resultDownloadUrl: showResultDownload ? row.resultDownloadUrl || "" : ""
    };
  }

  async saveResultWorkbook(
    batchRecordId,
    sourceFileName,
    resultRowsJson,
    sourceHeaders = [],
    sourceRows = []
  ) {
    await this.ensureSheetJsLoaded();
    const { headers: exportHeaders, rows: exportSourceRows } = trimSourceForResultExport(
      sourceHeaders,
      sourceRows
    );
    const parsedRows = JSON.parse(resultRowsJson || "[]");
    const exportRows = Array.isArray(parsedRows)
      ? parsedRows.map((r, index) => {
          const rowStatus = String(r?.status || "");
          const isSucceeded = rowStatus.toLowerCase() === "succeeded";
          const interactionId = isSucceeded ? String(r?.interactionId || "") : "";
          const caseId = isSucceeded ? String(r?.fecIdSearch || "") : "";
          return [
            ...(exportSourceRows[index] || exportHeaders.map(() => "")),
            rowStatus,
            interactionId,
            caseId,
            formatErrorsForExport(r?.errors)
          ];
        })
      : [];
    const sheetAoA = [[...exportHeaders, ...RESULT_APPEND_HEADERS], ...exportRows];
    const worksheet = window.XLSX.utils.aoa_to_sheet(sheetAoA);
    applyTextFormatToWorksheetColumns(
      worksheet,
      [...exportHeaders, ...RESULT_APPEND_HEADERS],
      sheetAoA.length
    );
    const workbook = window.XLSX.utils.book_new();
    window.XLSX.utils.book_append_sheet(workbook, worksheet, "Result");
    const wbout = window.XLSX.write(workbook, {
      type: "array",
      bookType: "xlsx"
    });
    const resultBase64 = arrayBufferToBase64Safe(wbout);
    const resultFileName = buildResultXlsxFileName(sourceFileName);
    await saveResultFile({
      batchRecordId,
      resultFileName,
      fileBodyBase64: resultBase64
    });
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

  rebuildPageRows() {
    const size = Number(this.pageSize) || 20;
    const start = (this.currentPage - 1) * size;
    this.pagedRows = this.rows.slice(start, start + size).map((row, index) => ({
      ...row,
      rowNumber: start + index + 1
    }));
    this.goToPageInput = String(this.currentPage);
  }

  handleSort(event) {
    const fieldName = event.currentTarget?.dataset?.field;
    if (!fieldName) {
      return;
    }
    if (this.sortBy === fieldName) {
      this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
    } else {
      this.sortBy = fieldName;
      this.sortDirection = fieldName === "uploadedOn" ? "desc" : "asc";
    }
    this.currentPage = 1;
    this.sortRows();
    this.rebuildPageRows();
  }

  sortRows() {
    const fieldName = this.sortBy || "uploadedOn";
    const direction = this.sortDirection === "asc" ? 1 : -1;
    const numericFields = new Set([
      "totalRecordsCount",
      "totalSuccessRecords",
      "totalFailedRecords"
    ]);
    this.rows = [...this.rows].sort((a, b) => {
      let left = a?.[fieldName];
      let right = b?.[fieldName];
      if (fieldName === "uploadedOn") {
        left = left ? new Date(left).getTime() : 0;
        right = right ? new Date(right).getTime() : 0;
        return (left - right) * direction;
      }
      if (numericFields.has(fieldName)) {
        left = Number(left) || 0;
        right = Number(right) || 0;
        return (left - right) * direction;
      }
      left = String(left ?? "").toLocaleLowerCase();
      right = String(right ?? "").toLocaleLowerCase();
      return left.localeCompare(right, undefined, {
        numeric: true,
        sensitivity: "base"
      }) * direction;
    });
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

  async handleProcessPending() {
    this.isLoading = true;
    try {
      const count = await runPendingImportBatch();
      const processed = Number(count) || 0;
      this.showSuccess(
        processed > 1 ? "Processing started" : "Processing completed",
        processed > 1
          ? `Đang xử lý ${processed} file Uploaded (từng file một). Refresh sau 1–2 phút.`
          : processed > 0
            ? "Đã xử lý file Uploaded. Vui lòng Refresh để xem kết quả."
            : "Không có file Uploaded nào cần xử lý."
      );
      await this.refreshRows(false);
    } catch (error) {
      this.showError("Process failed", extractErrorMessage(error));
    } finally {
      this.isLoading = false;
    }
  }

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const result = reader.result || "";
        const commaIndex = result.indexOf(",");
        resolve(commaIndex >= 0 ? result.substring(commaIndex + 1) : result);
      };
      reader.onerror = () => reject(new Error("Cannot read selected file."));
      reader.readAsDataURL(file);
    });
  }

  async logFailedImportAttempt(fileName, templateName, reason) {
    try {
      await logFailedImport({
        fileName: fileName || "Unknown_File.xlsx",
        templateName: templateName || "",
        reason: reason || "Import failed."
      });
      await this.refreshRows(false, true);
    } catch (e) {
      // Do not block UI flow if fail-log cannot be saved.
    }
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