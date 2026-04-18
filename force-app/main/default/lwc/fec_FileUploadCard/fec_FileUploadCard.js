import { LightningElement, api } from "lwc";

export default class Fec_FileUploadCard extends LightningElement {
  @api accept;
  /** Use 'multiple' (default) or 'single' to allow one file only. */
  @api fileSelectionMode = "multiple";
  @api disabled = false;

  files = [];
  isDragOver = false;
  _dragDepth = 0;

  get fileCount() {
    return this.files.length;
  }

  get fileRows() {
    return this.files.map((file, index) => ({
      id: `${index}-${file.name}-${file.size}-${file.lastModified}`,
      file,
      index
    }));
  }

  get titleLabel() {
    return `Files (${this.fileCount})`;
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

  openFilePicker() {
    if (this.disabled) {
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
    const list = event.target.files;
    if (list && list.length) {
      this._mergeFiles(list);
    }
    event.target.value = "";
  }

  handleDragEnter(event) {
    event.preventDefault();
    if (this.disabled) {
      return;
    }
    this._dragDepth += 1;
    this.isDragOver = true;
  }

  handleDragLeave(event) {
    event.preventDefault();
    if (this.disabled) {
      return;
    }
    this._dragDepth = Math.max(0, this._dragDepth - 1);
    if (this._dragDepth === 0) {
      this.isDragOver = false;
    }
  }

  handleDragOver(event) {
    event.preventDefault();
    if (!this.disabled) {
      event.dataTransfer.dropEffect = "copy";
    }
  }

  handleDrop(event) {
    event.preventDefault();
    this._dragDepth = 0;
    this.isDragOver = false;
    if (this.disabled) {
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
    this._emitChange();
  }
}
