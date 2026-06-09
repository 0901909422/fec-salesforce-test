import { LightningElement, wire } from "lwc";

import { CurrentPageReference } from "lightning/navigation";

// import getAssignmentsForView from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentsForView";
import getAssignmentsForViewNEW from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentsForViewNEW";

import { getUsernameBeforeAt, formatDateTime } from "c/fec_CommonUtils";

// LABELS
import LABEL_ASSIGNMENT_LIST from "@salesforce/label/c.FEC_Assignment_List";

import LABEL_ASSIGNMENT_ID from "@salesforce/label/c.FEC_Assignment_Id";

import LABEL_STAGE_NAME from "@salesforce/label/c.FEC_Label_Stage_Name";

import LABEL_ASSIGNMENT_STATUS from "@salesforce/label/c.FEC_Assignment_Status";

import LABEL_USER from "@salesforce/label/c.FEC_User_Label";

import LABEL_USER_ROLE from "@salesforce/label/c.CS_OrgChart_Table_UserTable_UserRole_Column";

import LABEL_DATE_TIME from "@salesforce/label/c.FEC_Notification_History_Sort_DateTime";

import LABEL_RECORDS_PER_PAGE from "@salesforce/label/c.FEC_Record_per_Page";

import LABEL_GO_TO_PAGE from "@salesforce/label/c.FEC_Go_to_page_label";

import LABEL_GO from "@salesforce/label/c.FEC_Go_Button_Label";

const COLUMNS = [
  {
    label: LABEL_ASSIGNMENT_ID,
    fieldName: "assignmentUrl",
    type: "url",
    initialWidth: 150,
    typeAttributes: {
      label: {
        fieldName: "assignmentId",
      },
      target: "_self",
    },
  },

  {
    label: "Assignment Type",
    fieldName: "assignmentType",
    initialWidth: 160,
  },

  {
    label: "Assignment Name",
    fieldName: "assignmentName",
    initialWidth: 170,
  },

  {
    label: LABEL_ASSIGNMENT_STATUS,
    fieldName: "assignmentStatus",
    initialWidth: 140,
  },

  {
    label: LABEL_STAGE_NAME,
    fieldName: "stageName",
    wrapText: false,
    initialWidth: 260,
  },

  {
    label: LABEL_USER,
    fieldName: "user",
    initialWidth: 150,
  },

  {
    label: LABEL_USER_ROLE,
    fieldName: "userRole",
    wrapText: false,
    initialWidth: 260,
  },

  {
    label: LABEL_DATE_TIME,
    fieldName: "dateTime",
    initialWidth: 190,
  },
];

export default class Fec_AssignmentViewAll extends LightningElement {
  columns = COLUMNS;

  labels = {
    title: LABEL_ASSIGNMENT_LIST,
    pageSizeLabel: LABEL_RECORDS_PER_PAGE,
    goToPageLabel: LABEL_GO_TO_PAGE,
    goBtnLabel: LABEL_GO,
  };

  recordId;

  assignments = [];

  pageSize = 10;

  currentPage = 1;

  totalRecords = 0;

  totalPages = 1;

  goToPageValue = 1;

  isLoading = false;

  @wire(CurrentPageReference)
  handlePageRef(pageRef) {
    const newRecordId = pageRef?.state?.c__recordId;

    if (newRecordId && newRecordId !== this.recordId) {
      this.recordId = newRecordId;

      this.currentPage = 1;

      this.initData();
    }
  }

  async initData() {
    if (!this.recordId) {
      return;
    }

    this.isLoading = true;

    try {
      await this.loadPage();
    } finally {
      this.isLoading = false;
    }
  }

  async loadPage() {
    this.isLoading = true;

    try {
      const result = await getAssignmentsForViewNEW({
        caseId: this.recordId,

        pageSize: this.pageSize,

        pageNumber: this.currentPage,
      });

      this.totalRecords = result.totalCount || 0;

      this.totalPages = Math.max(
        1,
        Math.ceil(this.totalRecords / this.pageSize),
      );

      this.assignments = (result.assignments || []).map((item) => {
        return {
          ...item,

          assignmentUrl: "/" + item.id,

          user: item.user ? getUsernameBeforeAt(item.user) : "",

          dateTime: formatDateTime(item.latestModifiedDateTime),
        };
      });
    } finally {
      this.isLoading = false;
    }
  }

  get hasRecords() {
    return this.totalRecords > 0;
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

  async handlePrevPage() {
    if (this.isFirstPage) {
      return;
    }

    this.currentPage--;

    await this.loadPage();
  }

  async handleNextPage() {
    if (this.isLastPage) {
      return;
    }

    this.currentPage++;

    await this.loadPage();
  }

  async handlePageSizeChange(event) {
    this.pageSize = Number(event.detail.value);

    this.currentPage = 1;

    await this.loadPage();
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
}
