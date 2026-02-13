import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getRelevantInteractionsViewAll from "@salesforce/apex/FEC_InteractionInforHandler.getRelevantInteractionsViewAll";
import PAGINATION_PAGE_OF from "@salesforce/label/c.Pagination_Page_Of_Label";

import NEXT_BTN from "@salesforce/label/c.FEC_Next_Btn_Label";
import PREV_BTN from "@salesforce/label/c.FEC_Previous_Btn_Label";
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
    type: "date",
    typeAttributes: {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    },
  },
  { label: "Interaction Created By", fieldName: "createdBy" },
];
export default class Fec_RelevantInteractionListViewAll extends LightningElement {
  // ===== Datatable =====
  columns = COLUMNS;
  labels = {
    next: NEXT_BTN,
    prev: PREV_BTN,
  };
  // ===== Data =====
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
  // ===== Fetch data =====

  //   FEC_Channel__c
  // :
  // "Outbound"
  // FEC_Created_On__c
  // :
  // "2026-01-23T03:34:10.000Z"
  // FEC_Interaction_ID__c
  // :
  // "<a href=\"/500Az00000LJIUz\" target=\"_self\">O-0101</a>"
  // Id
  // :
  // "500Az00000LJIUzIAP"
  // RecordTypeId
  // :
  // "012Az000000ohMjIAI"
  async fetchData() {
    try {
      const result = await getRelevantInteractionsViewAll({
        recordId: this.recordId,
      });
      console.log(result);

      const mapped = result.map((c) => ({
        ...c,
        interactionUrl: `/${c.Id}`,
        interactionIdText: this.getPlainCaseId(c.FEC_Interaction_ID__c),
        interactionStatus: c.FEC_Interaction_Status__c,
        interactionChannel: c.FEC_Channel__c,
        createdDate: c.FEC_Created_On__c,
        createdBy: c.FEC_Created_by__c,
      }));

      this.data = mapped;
      console.log("Fetched data: ", this.data);
      this.pagedData = this.data.slice(0, this.pageSize);
    } catch (error) {
      console.error("Error fetching data: ", error);
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
  get pageInfoLabel() {
    return PAGINATION_PAGE_OF.replace("{0}", this.currentPage).replace(
      "{1}",
      this.totalPages,
    );
  }
  // ===== Utils =====
  getPlainCaseId(htmlString) {
    if (!htmlString) return "";
    const div = document.createElement("div");
    div.innerHTML = htmlString;
    return div.textContent || div.innerText || "";
  }
}
