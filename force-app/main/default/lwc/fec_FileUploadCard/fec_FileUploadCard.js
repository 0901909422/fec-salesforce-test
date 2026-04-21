import { LightningElement, api, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getLinkedFilesForCase from "@salesforce/apex/FEC_CaseLinkedFilesController.getLinkedFilesForCase";

function formatBytes(bytes) {
  const n = Number(bytes);
  if (!n || n <= 0) {
    return "0 B";
  }
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(n) / Math.log(k));
  return `${(n / k ** i).toFixed(i > 0 ? 1 : 0)} ${sizes[i]}`;
}

function formatShortDate(dt) {
  if (!dt) {
    return "";
  }
  try {
    const d = new Date(dt);
    return d.toLocaleDateString(undefined, {
      day: "2-digit",
      month: "short",
      year: "numeric"
    });
  } catch (e) {
    return "";
  }
}

function extensionBadge(ext) {
  const e = (ext || "").toLowerCase().replace(/^\./, "");
  if (!e) {
    return "FILE";
  }
  return e.length <= 4 ? e.toUpperCase() : e.slice(0, 4).toUpperCase();
}

export default class Fec_FileUploadCard extends NavigationMixin(
  LightningElement
) {
  @api accept;
  /** Use 'multiple' (default) or 'single' to allow one file only. */
  @api fileSelectionMode = "multiple";
  @api disabled = false;

  _recordId;
  _uploadNameSuffix = Math.random().toString(36).slice(2, 10);

  /** Case Id (Salesforce injects on record page; fec_CaseBussiness passes record-id). */
  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    this._recordId = value;
    if (value) {
      this.refreshFilesFromServer();
    } else {
      this.serverFiles = [];
    }
  }

  @track serverFiles = [];
  @track isLoadingServerFiles = false;

  files = [];
  isDragOver = false;
  _dragDepth = 0;

  /** Sau khi mở file preview / related list bên ngoài, poll Apex để list khớp server (vd. xóa file trong preview). */
  _externalEditorPollId = null;
  _externalEditorPollCount = 0;
  _pollSignatureStart = "";
  _visibilityHandler = this._onDocumentVisibilityChange.bind(this);
  _refreshDebounceId = null;
  _windowFocusHandler = this._onWindowFocusDebounced.bind(this);
  _focusDebounceId = null;
  _lastFocusDrivenRefreshAt = 0;

  get hasRecordId() {
    return !!this._recordId;
  }

  get uploadName() {
    return `fecCaseFU_${this._recordId || "x"}_${this._uploadNameSuffix}`;
  }

  get fileCount() {
    return this.hasRecordId ? this.serverFiles.length : this.files.length;
  }

  get titleLabel() {
    return `Files (${this.fileCount})`;
  }

  get fileRows() {
    return this.files.map((file, index) => ({
      id: `${index}-${file.name}-${file.size}-${file.lastModified}`,
      file,
      index
    }));
  }

  get hasServerFiles() {
    return (this.serverFiles || []).length > 0;
  }

  get serverFileRows() {
    return (this.serverFiles || []).map((row) => {
      const ext = row.fileExtension || "";
      const title = row.title || row.contentDocumentId;
      return {
        id: row.linkId,
        /** Link label like standard Files list (title without forcing .ext). */
        linkLabel: title,
        metaLine: `${formatShortDate(row.linkedCreatedDate)} • ${formatBytes(row.contentSize)}${ext ? ` • ${ext}` : ""}`,
        contentDocumentId: row.contentDocumentId,
        extBadge: extensionBadge(ext)
      };
    });
  }

  get inputAccept() {
    return this.accept || undefined;
  }

  get multiple() {
    return this.fileSelectionMode !== "single";
  }

  get dropZoneClass() {
    const base = "fec-drop-zone";
    return this.isDragOver ? `${base} fec-drop-zone_active` : base;
  }

  get uploadDisabled() {
    return this.disabled || !this.hasRecordId || this.isLoadingServerFiles;
  }

  connectedCallback() {
    document.addEventListener("visibilitychange", this._visibilityHandler);
    window.addEventListener("focus", this._windowFocusHandler);
    if (this._recordId) {
      this.refreshFilesFromServer();
    }
  }

  disconnectedCallback() {
    document.removeEventListener("visibilitychange", this._visibilityHandler);
    window.removeEventListener("focus", this._windowFocusHandler);
    this._clearRefreshDebounce();
    this._clearFocusDebounce();
    this._stopExternalEditorPolling();
  }

  _clearRefreshDebounce() {
    if (this._refreshDebounceId != null) {
      window.clearTimeout(this._refreshDebounceId);
      this._refreshDebounceId = null;
    }
  }

  _clearFocusDebounce() {
    if (this._focusDebounceId != null) {
      window.clearTimeout(this._focusDebounceId);
      this._focusDebounceId = null;
    }
  }

  /** Đóng modal preview / quay lại cửa sổ app → load lại list file (màn review không remount). */
  _onWindowFocusDebounced() {
    if (!this._recordId) {
      return;
    }
    this._clearFocusDebounce();
    this._focusDebounceId = window.setTimeout(() => {
      this._focusDebounceId = null;
      const now = Date.now();
      if (now - this._lastFocusDrivenRefreshAt < 600) {
        return;
      }
      this._lastFocusDrivenRefreshAt = now;
      this.refreshFilesFromServer();
    }, 450);
  }

  _onDocumentVisibilityChange() {
    if (document.visibilityState !== "visible" || !this._recordId) {
      return;
    }
    this._clearRefreshDebounce();
    this._refreshDebounceId = window.setTimeout(() => {
      this._refreshDebounceId = null;
      this.refreshFilesFromServer();
    }, 400);
  }

  _stopExternalEditorPolling() {
    if (this._externalEditorPollId != null) {
      window.clearInterval(this._externalEditorPollId);
      this._externalEditorPollId = null;
    }
    this._externalEditorPollCount = 0;
    this._pollSignatureStart = "";
  }

  _filesSignature() {
    return (this.serverFiles || [])
      .map((r) => r.linkId)
      .filter(Boolean)
      .sort()
      .join("|");
  }

  /**
   * Gọi sau khi điều hướng sang UI chuẩn (preview / related list) nơi user có thể xóa file;
   * component vẫn mounted nên cần poll nhẹ thay vì chờ uploadfinished.
   */
  _startExternalEditorPolling() {
    if (!this._recordId) {
      return;
    }
    this._stopExternalEditorPolling();
    this._pollSignatureStart = this._filesSignature();
    const intervalMs = 1500;
    const maxTicks = 24;
    const runTick = () => {
      this._externalEditorPollCount += 1;
      if (!this._recordId || this._externalEditorPollCount > maxTicks) {
        this._stopExternalEditorPolling();
        return;
      }
      this.refreshFilesFromServer().then(() => {
        if (!this._externalEditorPollId) {
          return;
        }
        if (this._filesSignature() !== this._pollSignatureStart) {
          this._stopExternalEditorPolling();
          this.dispatchEvent(
            new CustomEvent("filesrefreshed", {
              bubbles: true,
              composed: true
            })
          );
        }
      });
    };
    this._externalEditorPollId = window.setInterval(runTick, intervalMs);
    runTick();
  }

  /** Gọi từ fec_CaseBussiness sau getData / submit để list file khớp server. */
  @api
  refreshFilesFromServer() {
    if (!this._recordId) {
      this.serverFiles = [];
      return Promise.resolve();
    }
    this.isLoadingServerFiles = true;
    return getLinkedFilesForCase({ caseId: this._recordId })
      .then((rows) => {
        this.serverFiles = Array.isArray(rows) ? rows : [];
      })
      .catch((err) => {
        // eslint-disable-next-line no-console
        console.error("[fec_FileUploadCard] getLinkedFilesForCase", err);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: err?.body?.message || err?.message || "Could not load files",
            variant: "error"
          })
        );
        this.serverFiles = [];
      })
      .finally(() => {
        this.isLoadingServerFiles = false;
      });
  }

  handleUploadFinished() {
    this.refreshFilesFromServer().then(() => {
      this.dispatchEvent(
        new CustomEvent("filesrefreshed", {
          bubbles: true,
          composed: true
        })
      );
    });
  }

  handleUploadError(event) {
    const msg =
      event?.detail?.message ||
      event?.detail?.statusText ||
      "Upload failed";
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Upload error",
        message: msg,
        variant: "error"
      })
    );
  }

  handleOpenServerFile(event) {
    const docId = event.currentTarget?.dataset?.docid;
    if (!docId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__namedPage",
      attributes: {
        pageName: "filePreview"
      },
      state: {
        selectedRecordId: docId,
        recordIds: docId
      }
    });
    this._startExternalEditorPolling();
  }

  handleViewAllFiles() {
    if (!this._recordId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordRelationshipPage",
      attributes: {
        recordId: this._recordId,
        objectApiName: "Case",
        relationshipApiName: "ContentDocumentLinks",
        actionName: "view"
      }
    });
    this._startExternalEditorPolling();
  }

  /* --- Local-only mode (no Case Id): giữ hành vi cũ --- */

  openFilePicker() {
    if (this.disabled || this.hasRecordId) {
      return;
    }
    const input = this.template.querySelector('[data-id="file-input"]');
    if (input) {
      input.click();
    }
  }

  handleAddFilesClick() {
    this.openFilePicker();
  }

  handleUploadClick() {
    this.openFilePicker();
  }

  handleInputChange(event) {
    if (this.hasRecordId) {
      return;
    }
    const list = event.target.files;
    if (list && list.length) {
      this._mergeFiles(list);
    }
    event.target.value = "";
  }

  handleDragEnter(event) {
    event.preventDefault();
    if (this.disabled || this.hasRecordId) {
      return;
    }
    this._dragDepth += 1;
    this.isDragOver = true;
  }

  handleDragLeave(event) {
    event.preventDefault();
    if (this.disabled || this.hasRecordId) {
      return;
    }
    this._dragDepth = Math.max(0, this._dragDepth - 1);
    if (this._dragDepth === 0) {
      this.isDragOver = false;
    }
  }

  handleDragOver(event) {
    event.preventDefault();
    if (!this.disabled && !this.hasRecordId) {
      event.dataTransfer.dropEffect = "copy";
    }
  }

  handleDrop(event) {
    event.preventDefault();
    this._dragDepth = 0;
    this.isDragOver = false;
    if (this.disabled || this.hasRecordId) {
      return;
    }
    const list = event.dataTransfer?.files;
    if (list && list.length) {
      this._mergeFiles(list);
    }
  }

  _mergeFiles(fileList) {
    const incoming = Array.from(fileList);
    if (this.fileSelectionMode === "single" && incoming.length > 0) {
      this.files = [incoming[0]];
    } else if (this.multiple) {
      const map = new Map();
      [...this.files, ...incoming].forEach((f) => {
        map.set(`${f.name}_${f.size}_${f.lastModified}`, f);
      });
      this.files = Array.from(map.values());
    }
    this._emitChange();
  }

  handleRemoveFile(event) {
    const index = Number(event.currentTarget.dataset.index);
    if (Number.isNaN(index)) {
      return;
    }
    this.files = this.files.filter((_, i) => i !== index);
    this._emitChange();
  }

  _emitChange() {
    this.dispatchEvent(
      new CustomEvent("fileschange", {
        detail: { files: [...this.files] },
        bubbles: true,
        composed: true
      })
    );
  }

  @api
  getFiles() {
    return [...this.files];
  }

  @api
  clearFiles() {
    this.files = [];
    if (!this.hasRecordId) {
      this._emitChange();
    }
  }
}
