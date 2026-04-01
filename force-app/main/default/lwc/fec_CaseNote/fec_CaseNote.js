import { LightningElement, api, wire, track } from "lwc";
import FEC_RECORDS_PER_PAGE_LABEL from "@salesforce/label/c.FEC_Record_per_Page";
import FEC_GO_TO_PAGE_LABEL from "@salesforce/label/c.FEC_Go_to_page_label";
import getNotes from "@salesforce/apex/FEC_CaseRelatedNoteHandler.getNotes";
import removeNoteFromRecord from "@salesforce/apex/FEC_CaseRelatedNoteHandler.removeNoteFromRecord";
import deleteNote from "@salesforce/apex/FEC_CaseRelatedNoteHandler.deleteNote";
import { formatDateTime } from "c/fec_CommonUtils";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";
import { refreshApex } from "@salesforce/apex";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
export default class Fec_CaseNote extends LightningElement {
  @api recordId;
  @track notes = [];
  @track pagedNotes = [];

  @track showModal = false;
  isEditMode = false;
  // ===== Pagination state =====
  pageSize = 10;
  currentPage = 1;
  goToPageValue;
  wiredNotesResult;
  @wire(MessageContext)
  messageContext;
  @track showConfirmModal = false;
  @track confirmType; // 'remove' | 'delete'
  @track selectedRow;
  /* =======================
   * LMS SUBSCRIPTION
   * ======================= */

  connectedCallback() {
    this.subscribeToModeChannel();
  }

  subscribeToModeChannel() {
    if (this.subscription) return;

    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleModeMessage(message),
      { scope: APPLICATION_SCOPE },
    );
  }

  handleModeMessage(message) {
    console.log("[LMS] Mode received:", message);

    if (message?.isModeEdit !== undefined) {
      this.isEditMode = message.isModeEdit;

      console.log("[LMS] isEditMode:", this.isEditMode);
    }
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = null;
    }
  }

  /*
   * ============================
   */

  @wire(getNotes, { recordId: "$recordId" })
  wiredData(result) {
    this.wiredNotesResult = result;
    if (result.data) {
      const data = result.data;
      console.log("raw data:", JSON.stringify(data));
      this.notes = data.map((note) => ({
        ...note,
        id: note.id,
        title: note.title,
        preview: note.preview,
        createdByName: note.createdByName,
        lastModifiedDateText: formatDateTime(note.lastModifiedDate),
      }));
      this.currentPage = 1;
      this.updatePagedData();
      console.log("display data:", JSON.stringify(this.notes));
    }
  }

  labels = {
    pageSizeLabel: FEC_RECORDS_PER_PAGE_LABEL,
    goToPageLabel: FEC_GO_TO_PAGE_LABEL,
  };

  columns = [
    {
      label: "Title",
      fieldName: "title",
    },
    { label: "Text Preview", fieldName: "preview" },
    { label: "Created By", fieldName: "createdByName" },
    { label: "Last Modified", fieldName: "lastModifiedDateText" },
    // 👉 ACTION COLUMN
    {
      type: "action",
      typeAttributes: { rowActions: this.getRowActions },
    },
  ];

  handleNew() {
    this.showModal = true;
  }

  handleClose() {
    this.showModal = false;
  }

  handleSuccess() {
    this.showModal = false;
    // reload lại dữ liệu
    return refreshApex(this.wiredNotesResult);
  }

  getRowActions(row, doneCallback) {
    const actions = [
      { label: "View", name: "view" },
      { label: "Delete", name: "delete" },
      { label: "Remove from Record", name: "remove" },
    ];
    doneCallback(actions);
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    switch (actionName) {
      case "view":
        this.openViewModal(row);
        break;

      case "delete":
        this.openConfirmModal("delete", row);
        break;

      case "remove":
        this.openConfirmModal("remove", row);
        break;
    }
  }
  openViewModal(note) {
    this.selectedNote = note;
    this.showModal = true;
  }
  openConfirmModal(type, row) {
    console.log(row);
    this.confirmType = type;
    this.selectedRow = row;
    this.showConfirmModal = true;
  }

  closeConfirmModal() {
    this.showConfirmModal = false;
  }

  handleConfirm() {
    if (this.confirmType === "remove") {
      this.handleRemoveConfirmed();
    } else if (this.confirmType === "delete") {
      this.handleDeleteConfirmed();
    }
  }
  hhandleRemoveConfirmed() {
    removeNoteFromRecord({
      recordId: this.recordId,
      noteId: this.selectedRow.id,
    })
      .then(() => {
        this.showToast("Success", "Note removed from record", "success");
        this.closeConfirmModal();
        return refreshApex(this.wiredNotesResult);
      })
      .catch((error) => {
        this.showToast("Error", error.body?.message, "error");
      });
  }

  handleDeleteConfirmed() {
    console.log(this.recordId);
    console.log(this.selectedRow.id);
    deleteNote({ noteId: this.selectedRow.id })
      .then(() => {
        this.showToast("Success", "Note deleted", "success");
        this.closeConfirmModal();
        return refreshApex(this.wiredNotesResult);
      })
      .catch((error) => {
        this.showToast("Error", error.body?.message, "error");
      });
  }

  get modalTitle() {
    return this.confirmType === "remove" ? "Remove file?" : "Delete File?";
  }

  get modalMessage() {
    return this.confirmType === "remove"
      ? "The file will be removed from the record, but not deleted."
      : "Deleting a file also removes it from any records or posts it's attached to.";
  }

  get confirmLabel() {
    return this.confirmType === "remove" ? "Remove from Record" : "Delete";
  }
  // ===== Computed Properties =====
  get totalRecords() {
    return this.notes.length;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get pageSizeOptions() {
    return [10, 20, 30, 40, 50].map((size) => ({
      label: size.toString(),
      value: size,
    }));
  }

  // ===== Core Pagination Logic =====
  updatePagedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.pagedNotes = this.notes.slice(start, end);
  }

  // ===== Event Handlers =====
  handleNextPage() {
    if (!this.isLastPage) {
      this.currentPage++;
      this.updatePagedData();
    }
  }

  handlePrevPage() {
    if (!this.isFirstPage) {
      this.currentPage--;
      this.updatePagedData();
    }
  }

  handlePageSizeChange(event) {
    this.pageSize = Number(event.detail.value);
    this.currentPage = 1;
    this.updatePagedData();
  }

  handleGoToPageInput(event) {
    this.goToPageValue = Number(event.target.value);
  }

  handleGoToPage() {
    if (
      this.goToPageValue &&
      this.goToPageValue >= 1 &&
      this.goToPageValue <= this.totalPages
    ) {
      this.currentPage = this.goToPageValue;
      this.updatePagedData();
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
      }),
    );
  }
}