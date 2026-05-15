import { LightningElement, api, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getRecordNotifyChange, updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getBusinessHourOptions from "@salesforce/apex/FEC_CaseAssignmentConfigController.getBusinessHourOptions";

import BUSINESS_HOURS_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Business_Hours__c";
import NAME_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.Name";
import OWNER_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.OwnerId";
import STATUS_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Status__c";
import METHOD_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Assignment_Method__c";
import SCHEDULED_TIME_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Scheduled_Time__c";
import TIME_SLOTS_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Time_Slots__c";
import QUEUES_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Select_Queues__c";
import ROLE_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Role__c";
import SCALE_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Scale__c";

const OBJECT_API_NAME = "FEC_Case_Assignment__c";

const FIELD_EDIT_LABELS = {
  FEC_Status__c: "Status",
  FEC_Business_Hours__c: "Business Hours",
  FEC_Assignment_Method__c: "Assignment Method",
  FEC_Scheduled_Time__c: "Scheduled Time",
  FEC_Time_Slots__c: "Time Slots",
};

const FIELDS = [
  NAME_FIELD,
  OWNER_FIELD,
  STATUS_FIELD,
  BUSINESS_HOURS_FIELD,
  METHOD_FIELD,
  SCHEDULED_TIME_FIELD,
  TIME_SLOTS_FIELD,
  QUEUES_FIELD,
  ROLE_FIELD,
  SCALE_FIELD,
  "FEC_Case_Assignment__c.Owner.Name",
  "FEC_Case_Assignment__c.FEC_Business_Hours__r.Name",
];

export default class Fec_CaseAssignmentDetailSummary extends NavigationMixin(LightningElement) {
  @api recordId;

  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  record;

  @wire(getBusinessHourOptions)
  wiredBusinessHourOptions(result) {
    this.businessHourOptionsWire = result;
  }

  @track caseInfoExpanded = true;
  @track queuesExpanded = true;
  @track receiptExpanded = true;

  @track isEditModalOpen = false;
  @track editingFieldName = "";
  @track modalFormRenderKey = 0;
  @track modalBusinessHoursValue = "";
  @track isBusinessHoursSaving = false;
  businessHourOptionsWire;

  get assignmentName() {
    return this.getFieldValue("Name");
  }

  get ownerName() {
    return this.getLookupLabel("OwnerId", "Owner.Name");
  }

  get status() {
    return this.getFieldValue("FEC_Status__c");
  }

  get businessHours() {
    return this.getLookupLabel("FEC_Business_Hours__c", "FEC_Business_Hours__r.Name");
  }

  get assignmentMethod() {
    return this.getFieldValue("FEC_Assignment_Method__c");
  }

  get scheduledTime() {
    return this.getFieldValue("FEC_Scheduled_Time__c");
  }

  get timeSlots() {
    return this.getFieldValue("FEC_Time_Slots__c");
  }

  get queuesRaw() {
    return this.getFieldValue("FEC_Select_Queues__c");
  }

  get businessHoursId() {
    const data = this.record?.data;
    const id = data?.fields?.FEC_Business_Hours__c?.value;
    return id || "";
  }

  get caseSectionChevron() {
    return this.caseInfoExpanded ? "utility:chevrondown" : "utility:chevronright";
  }

  get queuesSectionChevron() {
    return this.queuesExpanded ? "utility:chevrondown" : "utility:chevronright";
  }

  get receiptSectionChevron() {
    return this.receiptExpanded ? "utility:chevrondown" : "utility:chevronright";
  }

  get isContinuousMethod() {
    return (this.assignmentMethod || "").toLowerCase() === "continuous";
  }

  get isTimeBasedMethod() {
    const method = (this.assignmentMethod || "").toLowerCase();
    return method === "time-based" || method === "time based" || method === "time_based";
  }

  get roleScaleRows() {
    const roleText = this.getFieldValue("FEC_Role__c");
    const fallbackRaw = this.getFieldValue("FEC_Scale__c");
    let fallbackScale = 1;
    const fbNum = Number(fallbackRaw);
    if (Number.isFinite(fbNum) && fbNum >= 1) {
      fallbackScale = fbNum;
    }
    if (!roleText) {
      return [];
    }
    const rows = [];
    const items = roleText
      .split(";")
      .map((item) => item.trim())
      .filter((item) => item);

    items.forEach((item, idx) => {
      if (item.includes("|")) {
        const [rolePart, scalePart] = item.split("|");
        const scaleNum = Number((scalePart || "").trim());
        rows.push({
          key: `${idx}-${rolePart}`,
          role: (rolePart || "").trim(),
          scale: Number.isFinite(scaleNum) ? scaleNum : fallbackScale,
        });
      } else {
        rows.push({
          key: `${idx}-${item}`,
          role: item,
          scale: fallbackScale,
        });
      }
    });

    return rows.filter((row) => row.role && Number(row.scale) >= 1);
  }

  get hasRoleRows() {
    return this.roleScaleRows.length > 0;
  }

  get queuesIsEmpty() {
    const raw = this.getFieldValue("FEC_Select_Queues__c");
    return raw === null || raw === undefined || String(raw).trim() === "";
  }

  get receiptIsEmpty() {
    return !this.hasRoleRows;
  }

  get displayScheduledTime() {
    return this.isContinuousMethod ? this.normalizeValue(this.scheduledTime) : "";
  }

  get displayTimeSlots() {
    return this.isTimeBasedMethod ? this.normalizeValue(this.timeSlots) : "";
  }

  get displayQueues() {
    const raw = this.queuesRaw;
    if (raw === null || raw === undefined || raw === "") {
      return "-";
    }
    return raw
      .split(";")
      .map((q) => q.trim())
      .filter(Boolean)
      .join("; ");
  }

  get displayName() {
    return this.normalizeValue(this.assignmentName);
  }

  get displayOwner() {
    return this.normalizeValue(this.ownerName);
  }

  get displayStatus() {
    return this.normalizeValue(this.status);
  }

  get displayBusinessHours() {
    return this.normalizeValue(this.businessHours);
  }

  get displayMethod() {
    return this.normalizeValue(this.assignmentMethod);
  }

  get isEditingBusinessHours() {
    return this.editingFieldName === "FEC_Business_Hours__c";
  }

  get businessHoursComboboxOptions() {
    const rows = this.businessHourOptionsWire?.data;
    const noneOpt = { label: "— None —", value: "" };
    if (!rows || !rows.length) {
      return [noneOpt];
    }
    return [noneOpt, ...rows.map((row) => ({ label: row.label, value: row.value }))];
  }

  get modalTitle() {
    const label = FIELD_EDIT_LABELS[this.editingFieldName];
    return label ? `Edit ${label}` : "Edit field";
  }

  toggleCaseSection() {
    this.caseInfoExpanded = !this.caseInfoExpanded;
  }

  toggleQueuesSection() {
    this.queuesExpanded = !this.queuesExpanded;
  }

  toggleReceiptSection() {
    this.receiptExpanded = !this.receiptExpanded;
  }

  openFieldEdit(fieldApiName) {
    if (!this.recordId || !fieldApiName) {
      return;
    }
    this.editingFieldName = fieldApiName;
    if (fieldApiName === "FEC_Business_Hours__c") {
      this.modalBusinessHoursValue = this.businessHoursId || "";
    }
    this.modalFormRenderKey += 1;
    this.isEditModalOpen = true;
  }

  handleFieldEditClick(event) {
    const field = event.currentTarget?.dataset?.field;
    this.openFieldEdit(field);
  }

  closeEditModal() {
    this.isEditModalOpen = false;
    this.editingFieldName = "";
    this.modalBusinessHoursValue = "";
    this.isBusinessHoursSaving = false;
  }

  handleModalBusinessHoursChange(event) {
    this.modalBusinessHoursValue = event.detail.value || "";
  }

  async handleSaveBusinessHours() {
    if (!this.recordId) {
      return;
    }
    this.isBusinessHoursSaving = true;
    try {
      const fields = {
        Id: this.recordId,
        [BUSINESS_HOURS_FIELD.fieldApiName]: this.modalBusinessHoursValue
          ? this.modalBusinessHoursValue
          : null,
      };
      await updateRecord({ fields });
      getRecordNotifyChange([{ recordId: this.recordId }]);
      this.closeEditModal();
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Saved",
          message: "Record updated.",
          variant: "success",
        })
      );
    } catch (e) {
      const msg =
        e?.body?.output?.errors?.[0]?.message ||
        e?.body?.message ||
        e?.message ||
        "Could not save Business Hours.";
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: msg,
          variant: "error",
        })
      );
    } finally {
      this.isBusinessHoursSaving = false;
    }
  }

  handleEditSuccess() {
    getRecordNotifyChange([{ recordId: this.recordId }]);
    this.closeEditModal();
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Saved",
        message: "Record updated.",
        variant: "success",
      })
    );
  }

  handleEditError(event) {
    const msg = event.detail?.message || "Could not save changes.";
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error",
        message: msg,
        variant: "error",
      })
    );
  }

  handleBusinessHoursNav(event) {
    event.preventDefault();
    if (!this.businessHoursId) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.businessHoursId,
        objectApiName: "BusinessHours",
        actionName: "view",
      },
    });
  }

  getFieldValue(fieldPath) {
    const data = this.record?.data;
    if (!data || !data.fields) {
      return "";
    }

    if (!fieldPath.includes(".")) {
      const node = data.fields[fieldPath];
      if (!node) {
        return "";
      }
      const raw = node.value;
      if (raw !== null && raw !== undefined && raw !== "") {
        return typeof raw === "string" ? raw : String(raw);
      }
      const disp = node.displayValue;
      if (disp !== null && disp !== undefined && disp !== "") {
        return String(disp);
      }
      return "";
    }

    const pathParts = fieldPath.split(".");
    let currentFields = data.fields;
    for (let index = 0; index < pathParts.length; index += 1) {
      const pathPart = pathParts[index];
      const fieldNode = currentFields?.[pathPart];
      if (!fieldNode) {
        return "";
      }
      if (index === pathParts.length - 1) {
        return fieldNode.displayValue || fieldNode.value || "";
      }
      const nestedValue = fieldNode.value;
      if (!nestedValue || typeof nestedValue !== "object" || !nestedValue.fields) {
        return "";
      }
      currentFields = nestedValue.fields;
    }
    return "";
  }

  getLookupDisplayValue(fieldApiName) {
    const data = this.record?.data;
    if (!data || !data.fields || !data.fields[fieldApiName]) {
      return "";
    }
    const fieldNode = data.fields[fieldApiName];
    return fieldNode.displayValue || fieldNode.value || "";
  }

  getLookupLabel(lookupFieldApiName, relationshipFieldPath) {
    const relationshipValue = this.getFieldValue(relationshipFieldPath);
    if (relationshipValue) {
      return relationshipValue;
    }
    return this.getLookupDisplayValue(lookupFieldApiName);
  }

  normalizeValue(value) {
    return value === null || value === undefined || value === "" ? "-" : String(value);
  }

  get objectApiName() {
    return OBJECT_API_NAME;
  }
}