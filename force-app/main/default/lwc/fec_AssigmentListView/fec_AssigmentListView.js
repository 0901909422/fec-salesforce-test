import { LightningElement, api, wire, track } from "lwc";

import getAssignmentsForView from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentsForView";

import { getUsernameBeforeAt, formatDateTime } from "c/fec_CommonUtils";

import { ShowToastEvent } from "lightning/platformShowToastEvent";

import { NavigationMixin } from "lightning/navigation";

import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
} from "lightning/platformWorkspaceApi";

import { urlCmpWithRecordId } from "c/fec_CommonUtils";

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

export default class Fec_AssigmentListView extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  @track assignments = [];

  totalAssignmentCount = 0;

  isLoading = false;

  labels = {
    LABEL_ASSIGNMENT_LIST,
    LABEL_ASSIGNMENT_ID,
    LABEL_STAGE_NAME,
    LABEL_ASSIGNMENT_STATUS,
    LABEL_USER,
    LABEL_USER_ROLE,
    LABEL_DATE_TIME,
    LABEL_VIEW_ALL,
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

  @wire(getAssignmentsForView, {
    caseId: "$recordId",
    pageSize: 10,
    pageNumber: 1,
  })
  wiredAssignments({ data, error }) {
    this.isLoading = true;

    if (data) {
      this.totalAssignmentCount = data.totalCount || 0;

      this.assignments = (data.assignments || []).map((item) => {
        return {
          id: item.id,

          assignmentId: item.assignmentId,

          assignmentUrl: `/lightning/r/FEC_Assignment__c/${item.id}/view`,

          assignmentName: item.assignmentName,

          stageName: item.stageName,

          assignmentType: item.assignmentType,

          assignmentStatus: item.assignmentStatus,

          user: getUsernameBeforeAt(item.user),

          userRole: item.userRole,

          dateTime: formatDateTime(item.latestModifiedDateTime),
        };
      });

      this.isLoading = false;
    } else if (error) {
      this.isLoading = false;

      console.error("getAssignmentsForView error", JSON.stringify(error));

      this.showToast(
        FEC_Error_Title,
        "Failed to load assignment list",
        "error",
      );
    }
  }

  // HEADER COUNT
  get assignmentCount() {
    return this.totalAssignmentCount;
  }

  // SHOW VIEW ALL
  get showViewAll() {
    return true;
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
