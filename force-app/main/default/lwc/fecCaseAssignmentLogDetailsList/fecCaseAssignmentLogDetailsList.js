import { LightningElement, api, wire } from "lwc";
import getAssignmentLogDetails from "@salesforce/apex/FEC_CaseAssignmentLogController.getAssignmentLogDetails";

const COLUMNS = [
  { label: "Name", fieldName: "name", type: "text" },
  {
    label: "Number of Case",
    fieldName: "numberOfCase",
    type: "number",
    cellAttributes: { alignment: "left" },
  },
  { label: "Created Date", fieldName: "createdDateLabel", type: "text" },
];

export default class FecCaseAssignmentLogDetailsList extends LightningElement {
  @api recordId;

  columns = COLUMNS;
  rows = [];
  error;

  @wire(getAssignmentLogDetails, { logId: "$recordId" })
  wiredDetails({ data, error }) {
    if (data) {
      this.rows = data;
      this.error = undefined;
    } else if (error) {
      this.rows = [];
      this.error = error;
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
      "Could not load Case Assignment Log Details."
    );
  }
}
