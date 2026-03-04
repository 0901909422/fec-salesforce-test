import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getRelevantInteractionsViewAll from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantInteractionsViewAll";
import PAGINATION_PAGE_OF from "@salesforce/label/c.Pagination_Page_Of_Label";
import { formatDateTime, urlCmpWithRecordId } from 'c/fec_CommonUtils';
import { DIV_ELEMENT } from "c/fec_CommonConst";

const COLUMNS = [
  {
    label: "Interaction ID ",
    fieldName: "interactionUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "interactionIdText" },
      target: "_self",
    },
  },
  { label: "Interaction Status", fieldName: "interactionStatus" },
  {
    label: "Interaction Channel",
    fieldName: "interactionChannel",
  },
  {
    label: "Interaction Created Date",
    fieldName: "createdDate",
    
  },
  { label: "Interaction Created By", fieldName: "createdBy" },
];
export default class Fec_RelevantInteractionListViewAll extends LightningElement {
  // ===== Datatable =====
  columns = COLUMNS;
  labels = {
    title: "View All Relevant Interactions",
    pageSizeLabel: "Records per page",
    goToPageLabel: "Go to page",
  };
  // ===== Data =====
  @track data = []; // full data
  @track pagedData = []; // data hiển thị theo page
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
      const result = await getRelevantInteractionsViewAll({
        recordId: this.recordId,
      });
      console.log(result);

      this.data = result.map((c) => ({
        ...c,
        interactionUrl: `/${c.Id}`,
        interactionIdText: this.getPlainCaseId(c.FEC_Interaction_ID__c),
        interactionStatus: c.FEC_Interaction_Status__c,
        interactionChannel: c.FEC_Channel__c,
        createdDate: formatDateTime(c.FEC_Created_On__c),
        createdBy: c.FEC_Created_by__c,
      }));

      this.currentPage = 1;
      this.updatePagedData();
    } catch (error) {
      console.error("Error fetching data: ", error);
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
