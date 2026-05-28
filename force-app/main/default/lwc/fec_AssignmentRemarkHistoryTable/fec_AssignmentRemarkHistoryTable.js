import { LightningElement, api, track } from "lwc";
import getAssignmentRemarks from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentRemarks";
const PAGE_SIZE_OPTIONS = [10, 20, 30, 40, 50];
import { getUsernameBeforeAt, formatDateTime } from "c/fec_CommonUtils";
export default class Fec_AssignmentRemarkHistoryTable extends LightningElement {
  @api recordId;
  @api assignmentId;
  @track assignments = [];
  @track pagedData = [];

  @track pageSize = PAGE_SIZE_OPTIONS[0];
  @track currentPage = 1;

  gotoPageInputValue = "";

  columns = [
    {
      label: "Assignment Remark",
      fieldName: "remark",
      type: "text",
      wrapText: true,
      hideDefaultActions: true,
    },
    {
      label: "Stage Name",
      fieldName: "stage",
      type: "text",
      hideDefaultActions: true,
    },
    {
      label: "User",
      fieldName: "user",
      type: "text",
      hideDefaultActions: true,
    },
    {
      label: "User Role",
      fieldName: "userRole",
      type: "text",
      hideDefaultActions: true,
    },
    {
      label: "Date Time",
      fieldName: "createdDate",
      type: "text",
      hideDefaultActions: true,
    },
  ];

  connectedCallback() {
    this.loadData();
  }

  @api
  async refreshData() {
    await this.loadData();
  }

  async loadData() {
    try {
      const result = await getAssignmentRemarks({
        caseId: this.recordId,
        assignmentId: this.assignmentId,
      });

      this.assignments = result.map((item) => ({
        id: item.Id,
        remark: item.FEC_Case_Remarks__c,
        stage: item.FEC_Stage_Name__c,
        user: getUsernameBeforeAt(item.FEC_User__c),
        userRole: item.FEC_User_Role__c,
        createdDate: formatDateTime(item.CreatedDate),
      }));

      this.currentPage = 1;
      this.updatePagedData();
    } catch (e) {
      console.error("Load remarks error:", e);
    }
  }

  // ===== PAGINATION =====

  get isHasData() {
    return this.assignments && this.assignments.length > 0;
  }

  get pageSizeOptions() {
    return PAGE_SIZE_OPTIONS.map((size) => ({
      label: size.toString(),
      value: size.toString(),
    }));
  }

  get pageSizeStr() {
    return this.pageSize.toString();
  }

  get totalPages() {
    return Math.ceil(this.assignments.length / this.pageSize);
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
    this.pagedData = this.assignments.slice(start, end);
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

  handleGoToPageInput(event) {
    this.gotoPageInputValue = event.target.value;
  }

  handleGotoKeydown(event) {
    if (event.key === "Enter") {
      this.handleGoToPage();
    }
  }

  handleGoToPage() {
    let page = parseInt(this.gotoPageInputValue, 10);

    if (!page || page < 1) page = 1;
    if (page > this.totalPages) page = this.totalPages;

    this.currentPage = page;
    this.updatePagedData();
  }
}
