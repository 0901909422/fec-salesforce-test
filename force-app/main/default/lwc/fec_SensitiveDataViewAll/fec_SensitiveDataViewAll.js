import { LightningElement, api, wire } from "lwc";
import getSensitiveDataViewAll from "@salesforce/apex/FEC_InteractionInforHandler.getSensitiveDataViewAll";
import countSensitiveData from "@salesforce/apex/FEC_InteractionInforHandler.countSensitiveData";
import { CurrentPageReference } from "lightning/navigation";
import FEC_RECORDS_PER_PAGE_LABEL from "@salesforce/label/c.FEC_Record_per_Page";
import FEC_GO_TO_PAGE_LABEL from "@salesforce/label/c.FEC_Go_to_page_label";
import FEC_VIEW_ALL_SENSITIVE_LABEL from "@salesforce/label/c.FEC_Sensitive_Data_Table_Label";
import FEC_GO_BTN from "@salesforce/label/c.FEC_Go_Button_Label";

const COLUMNS = [
  { label: "Section", fieldName: "FEC_Section__c" },
  { label: "Field Name", fieldName: "Name" },
  { label: "User", fieldName: "FEC_User__c" },
  { label: "User Role", fieldName: "FEC_User_Role__c" },
  {
    label: "Case ID",
    fieldName: "caseUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "caseIdText" },
      target: "_self",
    },
  },
  { label: "Date Time", fieldName: "formattedDate" },
];

export default class Fec_SensitiveDataViewAll extends LightningElement {
  /* ============== API ============== */
  @api pageSize = 10;
  columns = COLUMNS;
  labels = {
    title: FEC_VIEW_ALL_SENSITIVE_LABEL,
    pageSizeLabel: FEC_RECORDS_PER_PAGE_LABEL,
    goToPageLabel: FEC_GO_TO_PAGE_LABEL,
    goBtnLabel: FEC_GO_BTN,
  };
  /* ============== STATE ============== */
  recordId;
  listSensitiveData = [];
  currentPage = 1;
  totalRecords = 0;
  isLoading = false;

  /* ============== PAGE REF ============== */
  @wire(CurrentPageReference)
  handlePageRef(pageRef) {
    const newRecordId = pageRef?.state?.c__recordId;
    if (newRecordId && newRecordId !== this.recordId) {
      this.recordId = newRecordId;
      this.currentPage = 1;
      this.initData();
    }
  }

  /* ============== INIT ============== */
  async initData() {
    if (!this.recordId) return;

    this.isLoading = true;
    try {
      await this.loadTotalRecords();
      await this.loadPage();
    } finally {
      this.isLoading = false;
    }
  }

  /* ============== APEX ============== */
  async loadTotalRecords() {
    this.totalRecords = await countSensitiveData({
      recordId: this.recordId,
    });
  }

  async loadPage() {
    const result = await getSensitiveDataViewAll({
      recordId: this.recordId,
      pageSize: this.pageSize,
      pageNumber: this.currentPage,
    });

    this.listSensitiveData = result.map((row) => {
      const { caseUrl, caseIdText } = this.parseAnchor(row.FEC_Case_ID__c);
      return {
        ...row,
        caseUrl,
        caseIdText,
        formattedDate: this.formatDate(row.CreatedDate),
      };
    });
  }

  /* ============== GETTERS ============== */

  get hasRecords() {
    return this.totalRecords > 0;
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
    return [
      { label: "10", value: 10 },
      { label: "20", value: 20 },
      { label: "30", value: 30 },
      { label: "40", value: 40 },
      { label: "50", value: 50 },
    ];
  }

  /* ============== EVENTS ============== */
  async handlePrevPage() {
    if (this.isFirstPage) return;
    this.currentPage--;
    await this.loadPage();
  }

  async handleNextPage() {
    if (this.isLastPage) return;
    this.currentPage++;
    await this.loadPage();
  }

  async handlePageSizeChange(event) {
    this.pageSize = Number(event.detail.value); // ✅ FIX
    this.currentPage = 1;
    await this.loadPage(); // ✅ không gọi COUNT lại
  }

  handleGoToPageInput(event) {
    this.goToPageValue = Number(event.target.value);
  }

  async handleGoToPage() {
    if (this.goToPageValue >= 1 && this.goToPageValue <= this.totalPages) {
      this.currentPage = this.goToPageValue;
      await this.loadPage();
    }
  }

  /* ============== HELPERS ============== */
  formatDate(dateString) {
    if (!dateString) return "";
    return new Intl.DateTimeFormat("en-GB", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(new Date(dateString));
  }

  parseAnchor(html) {
    if (!html) return { caseUrl: "", caseIdText: "" };

    const doc = new DOMParser().parseFromString(html, "text/html");
    const a = doc.querySelector("a");

    return {
      caseUrl: a?.getAttribute("href") || "",
      caseIdText: a?.textContent || "",
    };
  }
}
