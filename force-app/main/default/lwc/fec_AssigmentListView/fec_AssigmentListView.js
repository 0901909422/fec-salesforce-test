import { LightningElement, api } from "lwc";

// import getAssignmentsForView from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentsForView";

import getAssignmentsForViewNEW from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentsForViewNEW";

import { getUsernameBeforeAt, formatDateTime } from "c/fec_CommonUtils";

import { ShowToastEvent } from "lightning/platformShowToastEvent";

import { NavigationMixin } from "lightning/navigation";

import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
} from "lightning/platformWorkspaceApi";

// Custom labels
import LABEL_ASSIGNMENT_LIST from "@salesforce/label/c.FEC_Assignment_List";
import LABEL_ASSIGNMENT_ID from "@salesforce/label/c.FEC_Assignment_Id";
import LABEL_STAGE_NAME from "@salesforce/label/c.FEC_Label_Stage_Name";
import LABEL_ASSIGNMENT_STATUS from "@salesforce/label/c.FEC_Assignment_Status";
import LABEL_USER from "@salesforce/label/c.FEC_User_Label";
import LABEL_USER_ROLE from "@salesforce/label/c.CS_OrgChart_Table_UserTable_UserRole_Column";
import LABEL_DATE_TIME from "@salesforce/label/c.FEC_Notification_History_Sort_DateTime";
import LABEL_VIEW_ALL from "@salesforce/label/c.FEC_View_All_Btn_Label";
import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";

import LABEL_RECORDS_PER_PAGE from "@salesforce/label/c.FEC_Record_per_Page";

import LABEL_GO_TO_PAGE from "@salesforce/label/c.FEC_Go_to_page_label";

import LABEL_GO from "@salesforce/label/c.FEC_Go_Button_Label";

export default class Fec_AssigmentListView extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  assignments = [];

  totalAssignmentCount = 0;

  isLoading = false;

  pageSize = 10;

  currentPage = 1;

  totalRecords = 0;

  totalPages = 1;

  goToPageValue = 1;

  labels = {
    LABEL_ASSIGNMENT_LIST,
    LABEL_ASSIGNMENT_ID,
    LABEL_STAGE_NAME,
    LABEL_ASSIGNMENT_STATUS,
    LABEL_USER,
    LABEL_USER_ROLE,
    LABEL_DATE_TIME,
    LABEL_VIEW_ALL,
    pageSizeLabel: LABEL_RECORDS_PER_PAGE,
    goToPageLabel: LABEL_GO_TO_PAGE,
    goBtnLabel: LABEL_GO,
  };

  columns = [
    {
      label: LABEL_ASSIGNMENT_ID,
      fieldName: "assignmentUrl",
      type: "url",
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
      type: "text",
    },
    {
      label: "Assignment Name",
      fieldName: "assignmentName",
      type: "text",
    },
    {
      label: LABEL_ASSIGNMENT_STATUS,
      fieldName: "assignmentStatus",
      type: "text",
    },
    {
      label: LABEL_STAGE_NAME,
      fieldName: "stageName",
      type: "text",
    },
    {
      label: LABEL_USER,
      fieldName: "user",
      type: "text",
    },
    {
      label: LABEL_USER_ROLE,
      fieldName: "userRole",
      type: "text",
    },
    {
      label: LABEL_DATE_TIME,
      fieldName: "dateTime",
      type: "text",
    },
  ];

  connectedCallback() {
    this.loadPage();
  }

  async loadPage() {
    this.isLoading = true;

    try {
      const result = await getAssignmentsForViewNEW({
        caseId: this.recordId,
        pageSize: this.pageSize,
        pageNumber: this.currentPage,
      });

      this.totalAssignmentCount = result.totalCount || 0;

      this.totalRecords = result.totalCount || 0;

      this.totalPages = Math.max(
        1,
        Math.ceil(this.totalRecords / this.pageSize),
      );

      this.assignments = (result.assignments || []).map((item) => {
        return {
          id: item.id,

          assignmentId: item.assignmentId,

          assignmentUrl:
            `/lightning/r/FEC_Assignment__c/${item.id}/view`,

          assignmentName: item.assignmentName,

          stageName: item.stageName,

          assignmentType: item.assignmentType,

          assignmentStatus: item.assignmentStatus,

          user: item.user
            ? getUsernameBeforeAt(item.user)
            : "",

          userRole: item.userRole,

          dateTime: formatDateTime(
            item.latestModifiedDateTime,
          ),
        };
      });
    } catch (error) {
      console.error(
        "getAssignmentsForView error",
        JSON.stringify(error),
      );

      this.showToast(
        FEC_Error_Title,
        "Failed to load assignment list",
        "error",
      );
    } finally {
      this.isLoading = false;
    }
  }

  // HEADER COUNT
  get assignmentCount() {
    return this.totalAssignmentCount;
  }

  get showTable() {
    return this.totalAssignmentCount > 0;
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

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  async handlePageSizeChange(event) {
    this.pageSize = Number(event.detail.value);

    this.currentPage = 1;

    this.goToPageValue = 1;

    await this.loadPage();
  }

  async handlePrevPage() {
    if (this.isFirstPage) {
      return;
    }

    this.currentPage--;

    this.goToPageValue = this.currentPage;

    await this.loadPage();
  }

  async handleNextPage() {
    if (this.isLastPage) {
      return;
    }

    this.currentPage++;

    this.goToPageValue = this.currentPage;

    await this.loadPage();
  }

  handleGoToPageInput(event) {
    this.goToPageValue = Number(event.target.value);
  }

  async handleGoToPage() {
    if (
      !this.goToPageValue ||
      this.goToPageValue < 1 ||
      this.goToPageValue > this.totalPages
    ) {
      return;
    }

    this.currentPage = this.goToPageValue;

    await this.loadPage();
  }

  async handleViewAll() {
    try {
      const focusedTab = await getFocusedTabInfo();

      const subtabId = await openSubtab(focusedTab.tabId, {
        pageReference: {
          type: "standard__component",

          attributes: {
            componentName: "c__fec_AssignmentViewAll",
          },

          state: {
            c__recordId: this.recordId,
          },
        },

        focus: true,
      });

      await setTabLabel(subtabId, "Assignment - View All");
    } catch (error) {
      console.error("handleViewAll error", error);
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
      }),
    );
  }
}