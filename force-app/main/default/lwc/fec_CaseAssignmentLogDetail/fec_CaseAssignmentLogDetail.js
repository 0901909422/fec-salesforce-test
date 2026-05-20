import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getRelatedListRecords } from "lightning/uiRecordApi";
import { formatDateTimeVNShort } from "c/fec_CommonUtils";

import LOG_NAME_FIELD from "@salesforce/schema/FEC_Case_Assignment_Logs__c.Name";
import LOG_NUMBER_FIELD from "@salesforce/schema/FEC_Case_Assignment_Logs__c.FEC_Number_of_Case__c";
import LOG_ASSIGNMENT_FIELD from "@salesforce/schema/FEC_Case_Assignment_Logs__c.FEC_Case_Assignment_Name__c";

const LOG_FIELDS = [
  LOG_NAME_FIELD,
  LOG_NUMBER_FIELD,
  LOG_ASSIGNMENT_FIELD,
  "FEC_Case_Assignment_Logs__c.CreatedDate",
  "FEC_Case_Assignment_Logs__c.CreatedById",
  "FEC_Case_Assignment_Logs__c.CreatedBy.Name",
  "FEC_Case_Assignment_Logs__c.LastModifiedById",
  "FEC_Case_Assignment_Logs__c.LastModifiedBy.Name",
  "FEC_Case_Assignment_Logs__c.FEC_Case_Assignment_Name__r.Name",
];

const DETAIL_RELATIONSHIP = "Case_Assignment_Log_Details";
const DETAIL_FIELDS = [
  "FEC_Case_Assignment_Log_Detail__c.Id",
  "FEC_Case_Assignment_Log_Detail__c.Name",
  "FEC_Case_Assignment_Log_Detail__c.FEC_Number_of_Case__c",
];

export default class Fec_CaseAssignmentLogDetail extends NavigationMixin(LightningElement) {
  @api recordId;

  @wire(getRecord, { recordId: "$recordId", fields: LOG_FIELDS })
  logRecord;

  @wire(getRelatedListRecords, {
    parentRecordId: "$recordId",
    relatedListId: DETAIL_RELATIONSHIP,
    fields: DETAIL_FIELDS,
    sortBy: ["FEC_Case_Assignment_Log_Detail__c.Name"],
  })
  detailListWire;

  userInfoExpanded = true;
  detailsExpanded = true;
  systemInfoExpanded = true;

  get userSectionChevron() {
    return this.userInfoExpanded ? "utility:chevrondown" : "utility:chevronright";
  }

  get detailsSectionChevron() {
    return this.detailsExpanded ? "utility:chevrondown" : "utility:chevronright";
  }

  get systemSectionChevron() {
    return this.systemInfoExpanded ? "utility:chevrondown" : "utility:chevronright";
  }

  get displayName() {
    return this.getLogField("Name") || "—";
  }

  get assignmentId() {
    return this.getLogField("FEC_Case_Assignment_Name__c") || "";
  }

  get hasNameLink() {
    return Boolean(this.assignmentId);
  }

  get displayNumberOfCase() {
    const raw = this.getLogField("FEC_Number_of_Case__c");
    if (raw === null || raw === undefined || raw === "") {
      return "—";
    }
    return String(raw);
  }

  get displayCreatedDate() {
    const raw = this.getLogField("CreatedDate");
    return formatDateTimeVNShort(raw) || "—";
  }

  get createdById() {
    return this.getLogField("CreatedById") || "";
  }

  get createdByName() {
    return this.getLogLookupLabel("CreatedById", "CreatedBy.Name");
  }

  get hasCreatedByLink() {
    return Boolean(this.createdById);
  }

  get lastModifiedById() {
    return this.getLogField("LastModifiedById") || "";
  }

  get lastModifiedByName() {
    return this.getLogLookupLabel("LastModifiedById", "LastModifiedBy.Name");
  }

  get hasLastModifiedByLink() {
    return Boolean(this.lastModifiedById);
  }

  get detailRows() {
    const records = this.detailListWire?.data?.records || [];
    return records.map((row) => {
      const fields = row.fields || {};
      const id = fields.Id?.value;
      const name = fields.Name?.value || "—";
      const countRaw = fields.FEC_Number_of_Case__c?.value;
      const numberOfCase =
        countRaw === null || countRaw === undefined || countRaw === "" ? "—" : String(countRaw);
      return {
        key: id || name,
        recordId: id,
        name,
        numberOfCase,
        hasNameLink: Boolean(id),
      };
    });
  }

  get hasDetailRows() {
    return this.detailRows.length > 0;
  }

  toggleUserSection() {
    this.userInfoExpanded = !this.userInfoExpanded;
  }

  toggleDetailsSection() {
    this.detailsExpanded = !this.detailsExpanded;
  }

  toggleSystemSection() {
    this.systemInfoExpanded = !this.systemInfoExpanded;
  }

  handleNameNav(event) {
    event.preventDefault();
    if (!this.assignmentId) {
      return;
    }
    this.navigateToRecord(this.assignmentId, "FEC_Case_Assignment__c");
  }

  handleCreatedByNav(event) {
    event.preventDefault();
    if (!this.createdById) {
      return;
    }
    this.navigateToRecord(this.createdById, "User");
  }

  handleLastModifiedByNav(event) {
    event.preventDefault();
    if (!this.lastModifiedById) {
      return;
    }
    this.navigateToRecord(this.lastModifiedById, "User");
  }

  handleDetailNameNav(event) {
    event.preventDefault();
    const detailId = event.currentTarget.dataset.recordId;
    if (!detailId) {
      return;
    }
    this.navigateToRecord(detailId, "FEC_Case_Assignment_Log_Detail__c");
  }

  navigateToRecord(recordId, objectApiName) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId,
        objectApiName,
        actionName: "view",
      },
    });
  }

  getLogField(apiName) {
    const data = this.logRecord?.data;
    if (!data?.fields) {
      return "";
    }
    const field = data.fields[apiName];
    if (!field) {
      return "";
    }
    return field.displayValue !== undefined && field.displayValue !== null
      ? field.displayValue
      : field.value;
  }

  getLogLookupLabel(lookupApi, relatedNamePath) {
    const data = this.logRecord?.data;
    if (!data?.fields) {
      return "—";
    }
    const related = data.fields[relatedNamePath];
    if (related?.displayValue) {
      return related.displayValue;
    }
    const lookup = data.fields[lookupApi];
    return lookup?.displayValue || "—";
  }
}
