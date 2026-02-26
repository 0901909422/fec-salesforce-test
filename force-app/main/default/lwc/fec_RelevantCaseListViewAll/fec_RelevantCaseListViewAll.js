import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getRelevantCasesViewAll from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantCasesViewAll";
import PAGINATION_PAGE_OF from "@salesforce/label/c.Pagination_Page_Of_Label";

import NEXT_BTN from "@salesforce/label/c.FEC_Next_Btn_Label";
import PREV_BTN from "@salesforce/label/c.FEC_Previous_Btn_Label";
import FEC_View_All_Case_Label from "@salesforce/label/c.FEC_View_All_Case_Label";

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
    next: NEXT_BTN,
    prev: PREV_BTN,
    viewAllCase: FEC_View_All_Case_Label,
  };
  @track data = []; // full data
  @track pagedData = []; // data hiển thị theo page
  recordId;

  // ===== Pagination =====
  pageSize = 10;
  currentPage = 1;

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

  get pageInfoLabel() {
    return PAGINATION_PAGE_OF.replace("{0}", this.currentPage).replace(
      "{1}",
      this.totalPages,
    );
  }

  // ===== Fetch data =====
  async fetchData() {
    try {
      const result = await getRelevantCasesViewAll({ recordId: this.recordId });

      const mapped = result.map((c) => ({
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

      this.data = mapped;
      this.currentPage = 1;
      this.updatePagedData();
    } catch (error) {
      console.error("Error fetching case list view all:", error);
    }
  }

  // ===== Pagination logic =====
  updatePagedData() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.pagedData = this.data.slice(start, end);
  }

  handleNext() {
    if (!this.isLastPage) {
      this.currentPage++;
      this.updatePagedData();
    }
  }

  handlePrev() {
    if (!this.isFirstPage) {
      this.currentPage--;
      this.updatePagedData();
    }
  }

  get totalPages() {
    return Math.ceil(this.data.length / this.pageSize);
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage === this.totalPages;
  }

  // ===== Utils =====
  getPlainCaseId(htmlString) {
    if (!htmlString) return "";
    const div = document.createElement("div");
    div.innerHTML = htmlString;
    return div.textContent || div.innerText || "";
  }
}
