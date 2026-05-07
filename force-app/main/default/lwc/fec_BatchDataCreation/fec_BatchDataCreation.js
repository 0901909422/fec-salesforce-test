import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadScript } from "lightning/platformResourceLoader";
import getRecentRows from "@salesforce/apex/FEC_BatchDataCreationController.getRecentRows";
import importBatchData from "@salesforce/apex/FEC_BatchDataCreationController.importBatchData";
import saveResultFile from "@salesforce/apex/FEC_BatchDataCreationController.saveResultFile";
import logFailedImport from "@salesforce/apex/FEC_BatchDataCreationController.logFailedImport";
import getTemplateOptions from "@salesforce/apex/FEC_BatchDataCreationController.getTemplateOptions";
import FEC_SheetJS from "@salesforce/resourceUrl/FEC_SheetJS";
const PAGE_SIZE_OPTIONS = [
  { label: "10", value: "10" },
  { label: "20", value: "20" },
  { label: "30", value: "30" },
  { label: "40", value: "40" },
  { label: "50", value: "50" }
];
const MAX_UPLOAD_SIZE_BYTES = 150 * 1024 * 1024;
const IMPORT_TIMEOUT_MS = 60 * 1000;
const IMPORT_TIMEOUT_MESSAGE =
  "Yêu cầu đã quá thời gian xử lý, vui lòng thử lại.";
const REQUIRED_HEADERS = ["service resource", "start date", "end date"];
const NOTE_HEADER = "note";
const RESULT_FILE_HEADERS = [
  "Service Resource",
  "Start Date",
  "End Date",
  "Note",
  "ID",
  "Status",
  "Errors"
];

function normalizeNoteTextSafe(text) {
  return String(text ?? "").trim();
}

function promiseWithTimeoutSafe(promise, timeoutMs, timeoutMessage) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(timeoutMessage)), timeoutMs);
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

function arrayBufferToBase64Safe(buffer) {
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode.apply(null, chunk);
  }
  return btoa(binary);
}

function removeFileExtensionSafe(fileName) {
  const name = String(fileName ?? "");
  const dotIdx = name.lastIndexOf(".");
  if (dotIdx <= 0) {
    return name;
  }
  return name.substring(0, dotIdx);
}

export default class Fec_BatchDataCreation extends LightningElement {
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
  selectedFile;
  sheetJsReady = false;
  templateDownloadUrlByValue = {};
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
        `Không tải được danh sách mẫu từ cấu hình. ${this.extractError(error)}`
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

  handleTemplateChange(event) {
    this.selectedTemplate = event.detail.value;
    this.templateRequiredError = false;
    this.fileRequiredError = false;
    this.attachDataRequiredError = false;
    this.importValidationError = "";
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
        this.importValidationError = "Chỉ cho phép tải lên file Excel (.xlsx).";
      } else if ((file.size || 0) > MAX_UPLOAD_SIZE_BYTES) {
        this.importValidationError = "Dung lượng file tối đa là 150MB.";
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
        "Mẫu đã chọn chưa có file đính kèm để tải."
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

    const headerCells = headerRow.map((cell) =>
      String(cell ?? "")
        .trim()
        .toLowerCase()
    );
    const headerIndexes = REQUIRED_HEADERS.map((h) => headerCells.indexOf(h));
    const noteIndex = headerCells.indexOf(NOTE_HEADER);
    if (headerIndexes.some((idx) => idx < 0)) {
      return {
        ok: false,
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
      importRows.push({
        serviceResource: vSr,
        startDate: vStart,
        endDate: vEnd,
        note: vNote
      });
    }
    if (dataRowCount === 0) {
      return { ok: false, noData: true };
    }
    return { ok: true, message: "", rows: importRows };
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
      this.fileRequiredError = false;
      this.attachDataRequiredError = true;
      await this.logFailedImportAttempt("", key, "Vui lòng đính kèm tệp dữ liệu");
      return;
    }
    this.fileRequiredError = false;
    this.attachDataRequiredError = false;

    const lowerName = (fileToUpload.name || "").toLowerCase();
    if (!lowerName.endsWith(".xlsx")) {
      this.importValidationError = "Chỉ cho phép tải lên file Excel (.xlsx).";
      await this.logFailedImportAttempt(
        fileToUpload.name,
        key,
        this.importValidationError
      );
      return;
    }
    if ((fileToUpload.size || 0) > MAX_UPLOAD_SIZE_BYTES) {
      this.importValidationError = "Dung lượng file tối đa là 150MB.";
      await this.logFailedImportAttempt(
        fileToUpload.name,
        key,
        this.importValidationError
      );
      return;
    }
    try {
      const check = await this.validateBulkOffCreationExcel(fileToUpload);
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
            this.importValidationError || "Dữ liệu file import không hợp lệ."
          );
        }
        return;
      }
      this.pendingImportRows = Array.isArray(check.rows) ? check.rows : [];
    } catch (error) {
      this.importValidationError =
        error?.message ||
        error?.body?.message ||
        "Không đọc được nội dung file Excel.";
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
          rowsJson: JSON.stringify(this.pendingImportRows || [])
        }),
        IMPORT_TIMEOUT_MS,
        IMPORT_TIMEOUT_MESSAGE
      );
      if (result?.success) {
        if (result.batchRecordId && result.resultRowsJson) {
          await this.saveResultWorkbook(
            result.batchRecordId,
            fileToUpload.name,
            result.resultRowsJson
          );
        }
        this.showSuccess("Success", result.message || "Import started.");
        this.selectedFile = null;
        this.selectedFileName = "";
        this.pendingImportRows = [];
        this.importValidationError = "";
        this.attachDataRequiredError = false;
        await this.refreshRows();
        return;
      }
      this.showError("Import failed", result?.message || "Unable to import.");
    } catch (error) {
      if (error?.message === IMPORT_TIMEOUT_MESSAGE) {
        this.importValidationError = IMPORT_TIMEOUT_MESSAGE;
      } else {
        this.showError("Import failed", this.extractError(error));
      }
    } finally {
      this.isLoading = false;
    }
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

  async saveResultWorkbook(batchRecordId, sourceFileName, resultRowsJson) {
    await this.ensureSheetJsLoaded();
    const parsedRows = JSON.parse(resultRowsJson || "[]");
    const exportRows = Array.isArray(parsedRows)
      ? parsedRows.map((r) => [
          String(r?.serviceResource || ""),
          String(r?.startDate || ""),
          String(r?.endDate || ""),
          String(r?.note || ""),
          String(r?.recordId || ""),
          String(r?.status || ""),
          String(r?.errors || "")
        ])
      : [];
    const worksheet = window.XLSX.utils.aoa_to_sheet([
      RESULT_FILE_HEADERS,
      ...exportRows
    ]);
    const workbook = window.XLSX.utils.book_new();
    window.XLSX.utils.book_append_sheet(workbook, worksheet, "Result");
    const wbout = window.XLSX.write(workbook, {
      type: "array",
      bookType: "xlsx"
    });
    const resultBase64 = arrayBufferToBase64Safe(wbout);
    const resultFileName = `${removeFileExtensionSafe(sourceFileName)}_Result.xlsx`;
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
      await this.refreshRows();
    } catch (e) {
      // Do not block UI flow if fail-log cannot be saved.
    }
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