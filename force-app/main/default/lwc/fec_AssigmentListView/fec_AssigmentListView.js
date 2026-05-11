import { LightningElement, api, wire, track } from "lwc";

import getAssignmentsForView from "@salesforce/apex/FEC_AssignmentListHandler.getAssignmentsForView";

import { getUsernameBeforeAt, formatDateTime } from "c/fec_CommonUtils";

import { ShowToastEvent } from "lightning/platformShowToastEvent";

import { NavigationMixin } from "lightning/navigation";
import {
  getFocusedTabInfo,
  openSubtab,
  setTabLabel,
  setTabIcon,
} from "lightning/platformWorkspaceApi";

import { urlCmpWithRecordId } from "c/fec_CommonUtils";

//Custom labels
import LABEL_ASSIGNMENT_LIST from "@salesforce/label/c.FEC_Assignment_List";

import LABEL_ASSIGNMENT_ID from "@salesforce/label/c.FEC_Assignment_Id";

import LABEL_STAGE_NAME from "@salesforce/label/c.FEC_Label_Stage_Name";

// import LABEL_ASSIGNMENT_TYPE from "@salesforce/label/c.FEC_Assignment_Type";

import LABEL_ASSIGNMENT_STATUS from "@salesforce/label/c.FEC_Assignment_Status";

import LABEL_USER from "@salesforce/label/c.FEC_User_Label";

import LABEL_USER_ROLE from "@salesforce/label/c.CS_OrgChart_Table_UserTable_UserRole_Column";

import LABEL_DATE_TIME from "@salesforce/label/c.FEC_Notification_History_Sort_DateTime";

import LABEL_VIEW_ALL from "@salesforce/label/c.FEC_View_All_Btn_Label";

import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";

// import FEC_Error_Message from "@salesforce/label/c.FEC_Error_Message";
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
    // LABEL_ASSIGNMENT_TYPE,
    LABEL_ASSIGNMENT_STATUS,
    LABEL_USER,
    LABEL_USER_ROLE,
    LABEL_DATE_TIME,
    LABEL_VIEW_ALL,
  };

  @wire(getAssignmentsForView, {
    caseId: "$recordId",
    pageSize: 10,
    pageNumber: 1,
  })
  wiredAssignments({ data, error }) {
    this.isLoading = true;

    if (data) {
      // TOTAL ASSIGNMENT COUNT
      this.totalAssignmentCount = data.totalCount || 0;

      // DISPLAY RECORDS
      this.assignments = (data.assignments || []).map((item, index) => {
        return {
          id: item.id,

          rowNumber: index + 1,

          assignmentId: item.assignmentId,

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

  // SHOW VIEW ALL ONLY WHEN > 10
  get showViewAll() {
    // return this.totalAssignmentCount > 10;
    return true; // Always show "View All" as per the requirement
  }

  handleOpenAssignment(event) {
    const assignmentId = event.currentTarget.dataset.id;

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: assignmentId,
        objectApiName: "FEC_Assignment__c",
        actionName: "view",
      },
    });
  }

  async handleViewAll() {
    try {
      console.log("handleViewAll");

      const focusedTab = await getFocusedTabInfo();

      console.log("focusedTab:", JSON.stringify(focusedTab));

      const subtabId = await openSubtab(focusedTab.tabId, {
        url: urlCmpWithRecordId("fec_AssignmentViewAll", this.recordId),

        focus: true,
      });

      await setTabLabel(subtabId, "Assignment - View All");
    } catch (error) {
      console.error("handleViewAll error", JSON.stringify(error));
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
