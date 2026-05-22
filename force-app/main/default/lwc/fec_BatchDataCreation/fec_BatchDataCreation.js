import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadScript } from "lightning/platformResourceLoader";
import getRecentRows from "@salesforce/apex/FEC_BatchDataCreationController.getRecentRows";
import importBatchData from "@salesforce/apex/FEC_BatchDataCreationController.importBatchData";
import saveResultFile from "@salesforce/apex/FEC_BatchDataCreationController.saveResultFile";
import logFailedImport from "@salesforce/apex/FEC_BatchDataCreationController.logFailedImport";
import logFailedImportWithFile from "@salesforce/apex/FEC_BatchDataCreationController.logFailedImportWithFile";
import getTemplateOptions from "@salesforce/apex/FEC_BatchDataCreationController.getTemplateOptions";
import FEC_Batch_RequestTimeout from "@salesforce/label/c.FEC_Batch_RequestTimeout";
import FEC_Batch_FileExcelXlsxOnly from "@salesforce/label/c.FEC_Batch_FileExcelXlsxOnly";
import FEC_Batch_FileMaxSize150MB from "@salesforce/label/c.FEC_Batch_FileMaxSize150MB";
import FEC_Batch_TemplateNoAttachment from "@salesforce/label/c.FEC_Batch_TemplateNoAttachment";
import FEC_Batch_Msg_InvalidImportData from "@salesforce/label/c.FEC_Batch_Msg_InvalidImportData";
import FEC_Batch_Msg_CannotReadExcelContent from "@salesforce/label/c.FEC_Batch_Msg_CannotReadExcelContent";
import FEC_Batch_Msg_Select_Template from "@salesforce/label/c.FEC_Batch_Msg_Select_Template";
import FEC_SheetJS from "@salesforce/resourceUrl/FEC_SheetJS";
import {
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
const REQUIRED_HEADERS = ["service resource", "start date", "end date"];
const NOTE_HEADER = "note";
const RESULT_APPEND_HEADERS = ["ID", "Status", "Errors"];

const formatErrorsForExport = (errors) =>
  String(errors ?? "")
    .replace(/[\r\n\u2028\u2029]+/g, ", ")
    .replace(/\s*,\s*/g, ", ")
    .replace(/,(\s*,)+/g, ",")
    .replace(/^,\s*|\s*,$/g, "")
    .trim();

export default class Fec_BatchDataCreation extends LightningElement {
  labelSelectTemplate = FEC_Batch_Msg_Select_Template;

  /** Mỗi session là một accordion riêng — mặc định mở. */
  @track activeSettingSections = ["setting"];
  @track activeProcessedSections = ["processed"];

  @track rows = [];
  @track pagedRows = [];
  /** Mặc định mẫu BulkOffCreation — có thể đổi trong combobox. */
  @track selectedTemplate = "";
  @track selectedFileName = "";
  @track isLoading = false;
  @track goToPageInput = "1";
  /** Đỏ đậm dưới combobox Template. */
  @track templateRequiredError = false;
  /** Đỏ đậm — chưa chọn file mẫu / chưa đính kèm khi Import. */
  @track fileRequiredError = false;
  /** Đỏ đậm — file không có dữ liệu (trống / chỉ tiêu đề). */
  @track attachDataRequiredError = false;
  /** Đỏ đậm — lỗi cấu trúc CSV hoặc dòng thiếu trường bắt buộc. */
  @track importValidationError = "";

  currentPage = 1;
  /** String values must match pageSizeOptions for lightning-combobox. */
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

      this.templateOptions = [...dynamicOptions];
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

  get uploadedFileLabel() {
    return this.selectedFileName || "No file selected";
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

  get failureReasonSortIcon() {
    return this.getSortIcon("failureReason");
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
    this.pendingImportHeaders = [];
    this.pendingImportSourceRows = [];
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

  async validateBulkOffCreationExcel(file) {
    await this.ensureSheetJsLoaded();
    const data = await this.readFileAsArrayBuffer(file);
    // cellText: false — không tạo cell.w (chuỗi hiển thị) lúc đọc; cell.w dễ gây lỗi Unicode tiếng Việt.
    const workbook = window.XLSX.read(data, { type: "array", cellText: false });
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

    // raw: true — lấy giá trị ô (cell.v, shared string đã resolve). raw: false sẽ gọi tn() và ưu tiên cell.w → dễ hỏng Note.
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
    const originalHeaders = headerRow.map((cell) =>
      cell == null ? "" : String(cell)
    );

    const headerCells = headerRow.map((cell) =>
      String(cell ?? "")
        .trim()
        .toLowerCase()
    );
    const headerIndexes = REQUIRED_HEADERS.map((h) => headerCells.indexOf(h));
    const noteIndex = headerCells.indexOf(NOTE_HEADER);
    const sourceRows = [];
    for (let i = 1; i < rowsAoA.length; i += 1) {
      const rowArr = rowsAoA[i];
      if (!Array.isArray(rowArr) || rowArr.every((value) => value == null || value === "")) {
        continue;
      }
      sourceRows.push(
        originalHeaders.map((_, idx) => {
          const value = rowArr[idx];
          return value == null ? "" : value;
        })
      );
    }
    if (headerIndexes.some((idx) => idx < 0)) {
      return {
        ok: false,
        headers: originalHeaders,
        sourceRows,
        message:
          "File phải có các cột: Service Resource, Start Date, End Date."
      };
    }

    const cellAt = (rowArr, colIdx) => {
      if (!Array.isArray(rowArr) || colIdx < 0) {
        return "";
      }
      const v = rowArr[colIdx];
      if (v == null || v === "") {
        return "";
      }
      return String(v).trim();
    };

    let dataRowCount = 0;
    const importRows = [];
    const validSourceRows = [];
    for (let i = 1; i < rowsAoA.length; i += 1) {
      const rowArr = rowsAoA[i];
      const vSr = cellAt(rowArr, headerIndexes[0]);
      const vStart = cellAt(rowArr, headerIndexes[1]);
      const vEnd = cellAt(rowArr, headerIndexes[2]);
      const vNote = noteIndex >= 0 ? normalizeNoteTextSafe(cellAt(rowArr, noteIndex)) : "";
      if (!vSr && !vStart && !vEnd) {
        continue;
      }
      dataRowCount += 1;
      validSourceRows.push(
        originalHeaders.map((_, idx) => {
          const value = Array.isArray(rowArr) ? rowArr[idx] : "";
          return value == null ? "" : value;
        })
      );
      importRows.push({
        serviceResource: vSr,
        startDate: vStart,
        endDate: vEnd,
        note: vNote
      });
    }
    if (dataRowCount === 0) {
      return {
        ok: false,
        noData: true,
        headers: originalHeaders,
        sourceRows
      };
    }
    return {
      ok: true,
      message: "",
      headers: originalHeaders,
      sourceRows: validSourceRows,
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
    // Import không bắt buộc chọn template; template chỉ bắt buộc cho Download.
    this.templateRequiredError = false;

    const fileToUpload = this.selectedFile;
    if (!fileToUpload) {
      // Chưa chọn file: chỉ hiển thị cảnh báo inline, KHÔNG ghi history.
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
        this.importValidationError,
        fileToUpload,
        []
      );
      return;
    }
    if ((fileToUpload.size || 0) > MAX_UPLOAD_SIZE_BYTES) {
      this.importValidationError = FEC_Batch_FileMaxSize150MB;
      await this.logFailedImportAttempt(
        fileToUpload.name,
        key,
        this.importValidationError,
        fileToUpload,
        []
      );
      return;
    }
    try {
      const check = await this.validateBulkOffCreationExcel(fileToUpload);
      if (!check.ok) {
        const parsedRows = Array.isArray(check.rows) ? check.rows : [];
        const sourceHeaders = Array.isArray(check.headers) ? check.headers : [];
        const sourceRows = Array.isArray(check.sourceRows) ? check.sourceRows : [];
        if (check.noData) {
          // File đã đính kèm nhưng rỗng → dùng importValidationError, không phải attachDataRequiredError.
          this.attachDataRequiredError = false;
          this.importValidationError = "File không có dữ liệu, vui lòng kiểm tra lại.";
          await this.logFailedImportAttempt(
            fileToUpload.name,
            key,
            this.importValidationError,
            fileToUpload,
            parsedRows,
            sourceHeaders,
            sourceRows
          );
        } else {
          this.importValidationError = check.message || "";
          await this.logFailedImportAttempt(
            fileToUpload.name,
            key,
            this.importValidationError || FEC_Batch_Msg_InvalidImportData,
            fileToUpload,
            parsedRows,
            sourceHeaders,
            sourceRows
          );
        }
        return;
      }
      this.pendingImportHeaders = Array.isArray(check.headers) ? check.headers : [];
      this.pendingImportSourceRows = Array.isArray(check.sourceRows)
        ? check.sourceRows
        : [];
      this.pendingImportRows = Array.isArray(check.rows) ? check.rows : [];
    } catch (error) {
      this.importValidationError =
        error?.message ||
        error?.body?.message ||
        FEC_Batch_Msg_CannotReadExcelContent;
      await this.logFailedImportAttempt(
        fileToUpload.name,
        key,
        this.importValidationError,
        fileToUpload,
        []
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
          rowsJson: JSON.stringify(this.pendingImportRows || [])
        }),
        IMPORT_TIMEOUT_MS,
        IMPORT_TIMEOUT_MESSAGE
      );
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
          // eslint-disable-next-line no-console
          console.warn("saveResultWorkbook", saveErr);
        }
      }
      if (result?.success) {
        this.showSuccess("Success", result.message || "Import started.");
        this.selectedFile = null;
        this.selectedFileName = "";
        this.pendingImportHeaders = [];
        this.pendingImportSourceRows = [];
        this.pendingImportRows = [];
        this.importValidationError = "";
        this.attachDataRequiredError = false;
      } else {
        this.importValidationError = result?.message || "";
      }
    } catch (error) {
      if (error?.message === IMPORT_TIMEOUT_MESSAGE) {
        this.importValidationError = IMPORT_TIMEOUT_MESSAGE;
      } else {
        this.showError("Import failed", extractErrorMessage(error));
      }
    } finally {
      try {
        await this.refreshRows(false);
      } catch (refreshErr) {
        // eslint-disable-next-line no-console
        console.warn("refreshRows", refreshErr);
      }
      this.isLoading = false;
    }
  }

  async refreshRows(showLoading = true) {
    if (showLoading) {
      this.isLoading = true;
    }
    try {
      const data = await getRecentRows();
      this.rows = Array.isArray(data) ? data.map((row) => this.normalizeRow(row)) : [];
      this.sortRows();
      if (this.currentPage > this.totalPages) {
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
      status === "Processed" || status === "Failure" || row.resultDownloadUrl
        ? "Result"
        : "";
    return {
      ...row,
      fileDownloadUrl: row.fileDownloadUrl || "",
      uploadedOnLabel: row.uploadedOn ? formatDateTimeEnGb(row.uploadedOn) : "",
      totalRecordsCount: row.totalRecordsCount ?? 0,
      totalSuccessRecords: row.totalSuccessRecords ?? 0,
      totalFailedRecords: row.totalFailedRecords ?? 0,
      result: resultLabel,
      resultDownloadUrl: row.resultDownloadUrl || ""
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
    const parsedRows = JSON.parse(resultRowsJson || "[]");
    const exportRows = Array.isArray(parsedRows)
      ? parsedRows.map((r, index) => {
          const rowStatus = String(r?.status || "");
          const exportId =
            rowStatus.toLowerCase() === "succeeded" ? String(r?.recordId || "") : "";
          return [
            ...(sourceRows[index] || sourceHeaders.map(() => "")),
            exportId,
            rowStatus,
            formatErrorsForExport(r?.errors)
          ];
        })
      : [];
    const worksheet = window.XLSX.utils.aoa_to_sheet([
      [...sourceHeaders, ...RESULT_APPEND_HEADERS],
      ...exportRows
    ]);
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

  async logFailedImportAttempt(
    fileName,
    templateName,
    reason,
    fileObject,
    parsedRows,
    sourceHeaders = [],
    sourceRows = []
  ) {
    try {
      const safeFileName = fileName || "Unknown_File.xlsx";
      const safeReason = reason || "Import failed.";
      let batchRecordId = null;

      if (fileObject) {
        try {
          const base64 = await this.readFileAsBase64(fileObject);
          batchRecordId = await logFailedImportWithFile({
            fileName: safeFileName,
            fileBodyBase64: base64,
            templateName: templateName || "",
            reason: safeReason
          });
        } catch (uploadError) {
          batchRecordId = null;
        }
      }

      if (batchRecordId) {
        try {
          await this.saveResultWorkbookForFailure(
            batchRecordId,
            safeFileName,
            parsedRows,
            safeReason,
            sourceHeaders,
            sourceRows
          );
        } catch (resultError) {
          // Failed to save result file should not block flow.
        }
      } else {
        await logFailedImport({
          fileName: safeFileName,
          templateName: templateName || "",
          reason: safeReason
        });
      }
      await this.refreshRows();
    } catch (e) {
      // Do not block UI flow if fail-log cannot be saved.
    }
  }

  async saveResultWorkbookForFailure(
    batchRecordId,
    sourceFileName,
    parsedRows,
    reason,
    sourceHeaders = [],
    sourceRows = []
  ) {
    await this.ensureSheetJsLoaded();
    const headers = Array.isArray(sourceHeaders) && sourceHeaders.length
      ? sourceHeaders
      : ["Service Resource", "Start Date", "End Date", "Note"];
    const baseRows =
      Array.isArray(sourceRows) && sourceRows.length
        ? sourceRows
        : Array.isArray(parsedRows) && parsedRows.length
          ? parsedRows.map((r) => [
              String(r?.serviceResource || ""),
              String(r?.startDate || ""),
              String(r?.endDate || ""),
              String(r?.note || "")
            ])
          : [headers.map(() => "")];
    const exportRows = baseRows.map((row) => [
      ...(Array.isArray(row) ? row : headers.map(() => "")),
      "",
      "Failed",
      String(reason || "")
    ]);
    const worksheet = window.XLSX.utils.aoa_to_sheet([
      [...headers, ...RESULT_APPEND_HEADERS],
      ...exportRows
    ]);
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