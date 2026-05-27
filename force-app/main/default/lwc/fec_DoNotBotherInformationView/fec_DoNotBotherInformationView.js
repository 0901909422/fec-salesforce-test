import { LightningElement, api, track } from "lwc";
import getDNBResultC360 from "@salesforce/apex/FEC_DNBHandler.getDNBResultC360";
import getListDNBs from "@salesforce/apex/FEC_DNBHandler.getListDNBs";
import { PAGE_SIZE_OPTIONS_MAP } from "c/fec_CommonConst";

import LABEL_RECORDS_PER_PAGE from "@salesforce/label/c.FEC_Record_per_Page";

import LABEL_GO_TO_PAGE from "@salesforce/label/c.FEC_Go_to_page_label";

import LABEL_GO from "@salesforce/label/c.FEC_Go_Button_Label";
export default class Fec_DoNotBotherInformationView extends LightningElement {
  @api recordId;

  @track dnbData = [];
  @track pagedData = [];
  @track pageSize = PAGE_SIZE_OPTIONS_MAP.keys().next().value;
  @track currentPage = 1;
  @track noData = false;
  @track errorMessage = null;
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
    { label: "DNB Channel", fieldName: "channel", sortable: true },

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

    { label: "Current Status", fieldName: "status" },

    { label: "Expiry Date", fieldName: "expiryDate", type: "date" },

    { label: "Original Reason", fieldName: "originalReason" },
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

  @track isOpen = true;

  get isDisabled() {
    return this.errorMessage || this.noData;
  }

  toggleSection() {
    if (this.isDisabled) return;

    this.isOpen = !this.isOpen;
  }

  get sectionClass() {
    return this.isOpen ? "slds-is-open" : "";
  }

  // 🔥 FIX CHEVRON
  get iconClass() {
    return this.isOpen
      ? "slds-accordion__summary-action-icon"
      : "slds-accordion__summary-action-icon rotate-closed";
  }
  //------------------------------------------

  connectedCallback() {
    this.fetchDNBData();
  }

  async fetchDNBData() {
    this.errorMessage = "";
    this.noData = false;

    try {
      const existing = await getListDNBs({ caseId: this.recordId });
      console.log("Existing DNBs:", JSON.stringify(existing));
      if (existing && existing.length > 0) {
        this.mapData(existing);
        return;
      }

      const dnbResult = await getDNBResultC360({ caseId: this.recordId });
      console.log("DNB Result from API:", JSON.stringify(dnbResult));

      // 🔥 STOP HERE if API failed
      if (!dnbResult || dnbResult.success === false) {
        this.errorMessage = "Tải dữ liệu không thành công";
        this.dnbData = [];
        this.noData = false;
        this.isOpen = false;
        return;
      }

      const data = await getListDNBs({ caseId: this.recordId });
      console.log("DNBs after API call:", JSON.stringify(data));
      if (!data || data.length === 0) {
        this.noData = true;
        this.dnbData = [];
        this.isOpen = false;
        return;
      }

      this.mapData(data);
    } catch (error) {
      console.error("DNB ERROR:", error);
      this.errorMessage = "Tải dữ liệu không thành công";
      this.isOpen = false;
    }
  }

  // mapData(data) {
  //   this.dnbData = data.map((item) => ({
  //     id: item.id,
  //     channel: item.channel || "",
  //     type: item.type,
  //     // FULL VALUE
  //     rawContact: item.typeValue || "",

  //     // MASKED VALUE
  //     maskedContact: this.maskContact(item.typeValue),

  //     // DEFAULT HIDDEN
  //     isVisible: false,
  //     status: item.doNotBother,
  //     expiryDate: item.expectedExcludeTime,
  //     originalReason: item.reason2,
  //   }));

  //   this.currentPage = 1; // reset page khi load mới
  //   this.updatePagedData();
  // }

  mapData(data) {
    this.dnbData = data.map((item) => ({
      id: item.id,

      channel: item.channel || "",

      type: item.type || "",

      // 🔥 ADD THIS
      contactDisplay: item.typeValue || "",

      rawContact: item.typeValue || "",

      maskedContact: this.maskContact(item.typeValue),

      isVisible: false,

      status: item.doNotBother || "",

      expiryDate: item.expectedExcludeTime,

      originalReason: item.reason2 || "",
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
