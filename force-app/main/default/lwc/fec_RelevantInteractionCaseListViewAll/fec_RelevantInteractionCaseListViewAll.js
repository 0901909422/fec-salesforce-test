import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getCaseListViewAll from "@salesforce/apex/FEC_InteractionInforHandler.getCaseListViewAll";

import { DIV_ELEMENT } from "c/fec_CommonConst";

import FEC_RECORDS_PER_PAGE_LABEL from "@salesforce/label/c.FEC_Record_per_Page";
import FEC_GO_TO_PAGE_LABEL from "@salesforce/label/c.FEC_Go_to_page_label";
import FEC_VIEW_ALL_LABEL from "@salesforce/label/c.FEC_View_All_Case_Label";
import { formatDateTime, urlCmpWithRecordId } from 'c/fec_CommonUtils';
const COLUMNS = [
  {
    label: "Case ID",
    fieldName: "caseUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "caseIdText" },
      target: "_self",
    },
  },
  { label: "Case Status", fieldName: "FEC_Case_Status__c" },
  {
    label: "Account / Contract Number",
    fieldName: "accountContractNumber",
  },
  { label: "Sub Category", fieldName: "subCategory" },
  { label: "Sub Code", fieldName: "subCode" },
  {
    label: "Case Created Date",
    fieldName: "createdDate",
  },
  { label: "Case Created By", fieldName: "createdBy" },
];

export default class Fec_RelevantInteractionCaseListViewAll extends LightningElement {
  // ===== Datatable =====
  columns = COLUMNS;
  labels = {
    title: FEC_VIEW_ALL_LABEL,
    pageSizeLabel: FEC_RECORDS_PER_PAGE_LABEL,
    goToPageLabel: FEC_GO_TO_PAGE_LABEL,
  };
  // ===== Data =====
  @track data = [];
  @track pagedData = [];

  recordId;

  // ===== Pagination state =====
  pageSize = 10;
  currentPage = 1;
  goToPageValue;

  // ===== Page reference =====
  @wire(CurrentPageReference)
  getStateParameters(currentPageReference) {
    if (currentPageReference?.state?.c__recordId) {
      this.recordId = currentPageReference.state.c__recordId;
      if (this.recordId) {
        this.fetchData();
      }
    }
  }

  // ===== Fetch data =====
  async fetchData() {
    try {
      const result = await getCaseListViewAll({ recordId: this.recordId });

      this.data = result.map((c) => ({
        ...c,
        caseUrl: `/${c.Id}`,
        caseIdText: this.getPlainCaseId(c.FEC_Case_ID__c),
        subCategory: c.FEC_SubCategory__r?.FEC_Name_VN__c,
        subCode: c.FEC_SubCode__r?.FEC_Name_VN__c,
        createdDate: formatDateTime(c.FEC_Case_Created_On__c),
        createdBy: c.FEC_Case_Created_By__c,
        accountContractNumber:
          c.FEC_Account_or_Contract__r.FEC_Account_Number__c,
      }));

      this.currentPage = 1;
      this.updatePagedData();
    } catch (error) {
      console.error("Error fetching case list view all:", error);
    }
  }

  // ===== Computed Properties =====
  get totalRecords() {
    return this.data.length;
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
    this.pagedData = this.data.slice(start, end);
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

  // ===== Utils =====
  getPlainCaseId(htmlString) {
    if (!htmlString) return "";
    const div = document.createElement(DIV_ELEMENT);
    div.innerHTML = htmlString;
    return div.textContent || div.innerText || "";
  }
}
