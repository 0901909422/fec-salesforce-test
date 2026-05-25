import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import getAssignmentLogs from "@salesforce/apex/FEC_CaseAssignmentLogController.getAssignmentLogs";

const COLUMNS = [
  {
    label: "Name",
    fieldName: "recordUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "name" },
      target: "_self",
    },
    sortable: false,
  },
  {
    label: "Number of Case",
    fieldName: "numberOfCase",
    type: "number",
    cellAttributes: { alignment: "left" },
  },
  {
    label: "Created Date",
    fieldName: "createdDateLabel",
    type: "text",
  },
];

export default class FecCaseAssignmentLogsList extends NavigationMixin(
  LightningElement,
) {
  @api recordId;

  columns = COLUMNS;
  rows = [];
  error;
  wiredLogsResult;

  @wire(getAssignmentLogs, { assignmentId: "$recordId" })
  wiredLogs(result) {
    this.wiredLogsResult = result;
    const { data, error } = result;
    if (data) {
      this.rows = data.map((row) => ({
        ...row,
        recordUrl: row.id ? `/lightning/r/FEC_Case_Assignment_Logs__c/${row.id}/view` : "",
      }));
      this.error = undefined;
    } else if (error) {
      this.rows = [];
      this.error = error;
    }
  }

  @api
  async refreshList() {
    if (this.wiredLogsResult) {
      await refreshApex(this.wiredLogsResult);
    }
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get errorMessage() {
    if (!this.error) {
      return "";
    }
    return (
      this.error?.body?.message ||
      this.error?.message ||
      "Could not load Case Assignment Logs."
    );
  }
}
