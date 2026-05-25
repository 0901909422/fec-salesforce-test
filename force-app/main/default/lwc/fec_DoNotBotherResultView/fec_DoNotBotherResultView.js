import { LightningElement, api, track, wire } from "lwc";
import getDNBResultTable from "@salesforce/apex/FEC_DNBHandler.getDNBResultTable";
import { PAGE_SIZE_OPTIONS_MAP } from "c/fec_CommonConst";

import LABEL_RECORDS_PER_PAGE from "@salesforce/label/c.FEC_Record_per_Page";

import LABEL_GO_TO_PAGE from "@salesforce/label/c.FEC_Go_to_page_label";

import LABEL_GO from "@salesforce/label/c.FEC_Go_Button_Label";

import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
} from "lightning/messageService";

import DO_NOT_BOTHER_CHANNEL from "@salesforce/messageChannel/FEC_DoNotBother__c";

export default class Fec_DoNotBotherResultView extends LightningElement {
  @api recordId;

  @track dnbData = [];
  @track pagedData = [];
  @track pageSize = PAGE_SIZE_OPTIONS_MAP.keys().next().value;
  @track currentPage = 1;
  @track noData = false;
  @track errorMessage = null;

  subscription = null;

  labels = {
    pageSizeLabel: LABEL_RECORDS_PER_PAGE,
    goToPageLabel: LABEL_GO_TO_PAGE,
    goBtnLabel: LABEL_GO,
  };
  sortedBy;
  sortDirection = "asc";

  currentPage = 1;

  totalRecords = 0;

  goToPageValue = 1;

  columns = [
    {
      label: "DNB Channel",
      fieldName: "recordUrl",
      type: "url",
      sortable: true,
      typeAttributes: {
        label: { fieldName: "channel" },
        target: "_self",
      },
    },

    { label: "Type", fieldName: "type", sortable: true },

    {
      label: "Phone/Email",
      fieldName: "contactDisplay",
      type: "maskedContact",
      typeAttributes: {
        maskedValue: { fieldName: "maskedContact" },
        rawValue: { fieldName: "rawContact" },
        isVisible: { fieldName: "isVisible" },
        rowId: { fieldName: "id" },
      },
    },

    {
      label: "Action",

      fieldName: "action",

      type: "boolean",
    },

    { label: "Update Reason", fieldName: "updateReason" },

    { label: "Remark", fieldName: "remark" },
  ];

  //----------Pagination & Sorting Logic----------

  get sectionLabel() {
    return this.errorMessage
      ? `Do Not Bother - ${this.errorMessage}`
      : "Do Not Bother";
  }

  get showTable() {
    return this.pagedData && this.pagedData.length > 0;
  }
  get pageSizeOptions() {
    return Array.from(PAGE_SIZE_OPTIONS_MAP, ([value, label]) => ({
      label,
      value: value.toString(),
    }));
  }

  get pageSizeStr() {
    return this.pageSize.toString();
  }

  get totalPages() {
    return Math.ceil(this.dnbData.length / this.pageSize);
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get showPagination() {
    return this.totalPages > 1;
  }

  updatePagedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.pagedData = this.dnbData.slice(start, end);
  }

  handlePageSizeChange(event) {
    this.pageSize = parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.updatePagedData();
  }

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

  handleSort(event) {
    const { fieldName: sortedBy, sortDirection } = event.detail;
    this.sortedBy = sortedBy;
    this.sortDirection = sortDirection;

    let cloneData = [...this.dnbData];

    cloneData.sort((a, b) => {
      let valA = a[sortedBy] || "";
      let valB = b[sortedBy] || "";

      return sortDirection === "asc"
        ? valA > valB
          ? 1
          : -1
        : valA < valB
          ? 1
          : -1;
    });

    this.dnbData = cloneData;
    this.updatePagedData();
  }

  handleGoToPageInput(event) {
    this.goToPageValue = parseInt(event.target.value, 10);
  }

  handleGoToPage() {
    let targetPage = this.goToPageValue;

    if (!targetPage || isNaN(targetPage)) {
      targetPage = 1;
    }

    // clamp range
    if (targetPage < 1) {
      targetPage = 1;
    }

    if (targetPage > this.totalPages) {
      targetPage = this.totalPages;
    }

    this.currentPage = targetPage;
    this.updatePagedData();
  }

  get isDisabled() {
    return this.errorMessage || this.noData;
  }

  //------------------------------------------

  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    this.fetchDNBData();
    this.subscribeToMessageChannel();
  }

  subscribeToMessageChannel() {
    if (this.subscription) {
      return;
    }

    this.subscription = subscribe(
      this.messageContext,

      DO_NOT_BOTHER_CHANNEL,

      (message) => this.handleMessage(message),

      {
        scope: APPLICATION_SCOPE,
      },
    );
  }

  disconnectedCallback() {
    unsubscribe(this.subscription);

    this.subscription = null;
  }
  handleMessage(message) {
    console.log("DO_NOT_BOTHER_CHANNEL:", JSON.stringify(message));

    /*
     * Refresh after DNB updated
     */
    if (message?.status === "SUCCESS" && message?.caseId === this.recordId) {
      this.fetchDNBData();
    }
  }

  async fetchDNBData() {
    this.errorMessage = "";

    this.noData = false;

    try {
      const result = await getDNBResultTable({
        caseId: this.recordId,
      });

      console.log("RESULT TABLE:", JSON.stringify(result));

      if (!result || result.length === 0) {
        this.noData = true;

        this.dnbData = [];

        this.isOpen = false;

        return;
      }

      this.mapData(result);
    } catch (error) {
      console.error("DNB RESULT ERROR:", error);

      this.errorMessage = "Tải dữ liệu không thành công";

      this.isOpen = false;
    }
  }

  mapData(data) {
    this.dnbData = data.map((item) => ({
      id: item.id,
      recordUrl: `/lightning/r/FEC_Do_Not_Bother__c/${item.id}/view`,
      channel: item.channel || "",

      type: item.type || "",

      contactDisplay: item.phoneEmail || "",

      rawContact: item.phoneEmail || "",

      maskedContact: this.maskContact(item.phoneEmail),

      isVisible: false,

      action: item.action,

      updateReason: item.updatedReason || "",

      remark: item.remarks || "",
    }));

    this.currentPage = 1;

    this.updatePagedData();
  }

  maskContact(value) {
    if (!value) return "";

    const trimmed = value.trim();

    if (trimmed.includes("@")) {
      return this.maskEmail(trimmed);
    }

    return this.maskPhone(trimmed);
  }

  maskEmail(email) {
    const [name, domain] = email.split("@");

    if (!name || !domain) return email;

    if (name.length <= 3) {
      return `${name[0]}***@${domain}`;
    }

    return `${name.substring(0, 3)}***@${domain}`;
  }

  maskPhone(phone) {
    const cleaned = phone.replace(/\D/g, "");

    // 024 / 028
    if (cleaned.startsWith("024") || cleaned.startsWith("028")) {
      return (
        cleaned.substring(0, 3) +
        "*".repeat(cleaned.length - 6) +
        cleaned.substring(cleaned.length - 3)
      );
    }

    // 0xxxxxxxxx
    if (cleaned.startsWith("0")) {
      return (
        cleaned.substring(0, 4) + "***" + cleaned.substring(cleaned.length - 3)
      );
    }

    // 84xxxxxxxxx
    if (cleaned.startsWith("84")) {
      return (
        cleaned.substring(0, 5) + "***" + cleaned.substring(cleaned.length - 3)
      );
    }

    return (
      cleaned.substring(0, 3) + "***" + cleaned.substring(cleaned.length - 3)
    );
  }

  handleToggleMask(event) {
    const rowId = event.detail.rowId;

    this.dnbData = this.dnbData.map((row) => {
      if (row.id === rowId) {
        return {
          ...row,
          isVisible: !row.isVisible,
        };
      }

      return row;
    });

    this.updatePagedData();
  }
}
