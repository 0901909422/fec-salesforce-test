import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getRelevantCasesViewAll from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantCasesViewAll";

import { DIV_ELEMENT } from "c/fec_CommonConst";

import FEC_RECORDS_PER_PAGE_LABEL from "@salesforce/label/c.FEC_Record_per_Page";
import FEC_GO_TO_PAGE_LABEL from "@salesforce/label/c.FEC_Go_to_page_label";
import FEC_RELEVANT_CASE_LIST_VIEW_ALL_LABEL from "@salesforce/label/c.FEC_RelevantCaseListViewAll_Label";

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
  { label: "Account / Contract Number", fieldName: "accountContractNumber" },
  { label: "Sub Category", fieldName: "subCategory" },
  { label: "Sub Code", fieldName: "subCode" },
  {
    label: "Case Created Date",
    fieldName: "createdDate",
    type: "date",
    typeAttributes: {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    },
  },
  { label: "Case Created By", fieldName: "createdBy" },
];

export default class Fec_RelevantCaseListViewAll extends LightningElement {
  columns = COLUMNS;
  labels = {
    title: FEC_RELEVANT_CASE_LIST_VIEW_ALL_LABEL,
    pageSizeLabel: FEC_RECORDS_PER_PAGE_LABEL,
    goToPageLabel: FEC_GO_TO_PAGE_LABEL,
  };


  @track data = [];
  @track pagedData = [];

  recordId;

  // ===== Pagination state =====
  pageSize = 10;
  currentPage = 1;
  goToPageValue;

  // ===== Get recordId from URL =====
  @wire(CurrentPageReference)
  getStateParameters(pageRef) {
    if (pageRef?.state?.c__recordId) {
      this.recordId = pageRef.state.c__recordId;
      this.fetchData();
    }
  }

  // ===== Fetch Data =====
  async fetchData() {
    try {
      const result = await getRelevantCasesViewAll({
        recordId: this.recordId,
      });

      this.data = result.map((c) => ({
        ...c,
        caseUrl: `/${c.Id}`,
        caseIdText: this.getPlainCaseId(c.FEC_Case_ID__c),
        subCategory: c.FEC_SubCategory__r?.FEC_Name_VN__c,
        subCode: c.FEC_SubCode__r?.FEC_Name_VN__c,
        createdDate: c.FEC_Case_Created_On__c,
        createdBy: c.FEC_Case_Created_By__c,
        accountContractNumber:
          c.FEC_Account_or_Contract__r?.FEC_Account_Number__c,
      }));

      this.currentPage = 1;
      this.updatePagedData();
    } catch (error) {
      console.error("Error fetching cases:", error);
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
