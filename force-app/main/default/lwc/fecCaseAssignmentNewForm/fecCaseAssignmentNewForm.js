import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { createRecord, getRecord } from "lightning/uiRecordApi";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import USER_ID from "@salesforce/user/Id";
import USER_NAME_FIELD from "@salesforce/schema/User.Name";

import CASE_ASSIGNMENT_OBJECT from "@salesforce/schema/FEC_Case_Assignment__c";
import STATUS_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Status__c";
import ASSIGNMENT_METHOD_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Assignment_Method__c";
import TIME_SLOTS_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Time_Slots__c";

import getActiveCaseQueues from "@salesforce/apex/FEC_CaseAssignmentConfigController.getActiveCaseQueues";
import getRoleOptions from "@salesforce/apex/FEC_CaseAssignmentConfigController.getRoleOptions";
import getBusinessHourOptions from "@salesforce/apex/FEC_CaseAssignmentConfigController.getBusinessHourOptions";

const OBJECT_API_NAME = "FEC_Case_Assignment__c";

export default class FecCaseAssignmentNewForm extends NavigationMixin(LightningElement) {
  @track queueOptions = [];
  @track roleOptions = [];
  @track businessHourOptions = [];
  @track timeSlotOptions = [];

  selectedQueues = [];
  queueDropdownOpen = false;
  roleRows = [];
  status = "";
  assignmentMethod = "";
  businessHoursId = "";
  selectedRole = "";
  selectedScale = "";
  scheduledTime = "";
  selectedTimeSlots = [];
  assignmentName = "";
  ownerName = "";
  isSaving = false;

  @wire(getObjectInfo, { objectApiName: CASE_ASSIGNMENT_OBJECT })
  objectInfo;

  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: STATUS_FIELD,
  })
  wiredStatus({ data }) {
    if (data) {
      this.statusOptions = data.values;
      if (!this.status && data.defaultValue) {
        this.status = data.defaultValue.value;
      }
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: ASSIGNMENT_METHOD_FIELD,
  })
  wiredAssignmentMethod({ data }) {
    if (data) {
      this.assignmentMethodOptions = data.values;
      if (!this.assignmentMethod && data.defaultValue) {
        this.assignmentMethod = data.defaultValue.value;
      }
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: TIME_SLOTS_FIELD,
  })
  wiredTimeSlots({ data }) {
    if (data) {
      this.timeSlotOptions = data.values;
    }
  }

  @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME_FIELD] })
  wiredCurrentUser({ data }) {
    if (data) {
      this.ownerName = data.fields?.Name?.value || "";
    }
  }

  connectedCallback() {
    this.loadQueues();
    this.loadBusinessHours();
  }

  get statusOptions() {
    return this._statusOptions || [];
  }
  set statusOptions(value) {
    this._statusOptions = value;
  }

  get assignmentMethodOptions() {
    return this._assignmentMethodOptions || [];
  }
  set assignmentMethodOptions(value) {
    this._assignmentMethodOptions = value;
  }

  get isSaveDisabled() {
    return (
      this.isSaving ||
      !this.assignmentName ||
      !this.status ||
      !this.assignmentMethod ||
      !this.selectedQueues.length ||
      (this.isContinuousMethod && !this.scheduledTime) ||
      (this.isTimeBasedMethod && !this.selectedTimeSlots.length) ||
      !this.roleRows.length
    );
  }

  get isContinuousMethod() {
    const value = (this.assignmentMethod || "").toLowerCase();
    return value === "continuous";
  }

  get isTimeBasedMethod() {
    const value = (this.assignmentMethod || "").toLowerCase();
    return value === "time-based" || value === "time based" || value === "time_based";
  }

  get showSchedulingPairRow() {
    return this.isContinuousMethod || this.isTimeBasedMethod;
  }

  get hasRoleRows() {
    return this.roleRows.length > 0;
  }

  get hasSelectedQueues() {
    return this.selectedQueues.length > 0;
  }

  get selectedQueuePills() {
    const queueLabelByValue = new Map((this.queueOptions || []).map((item) => [item.value, item.label]));
    return this.selectedQueues.map((value) => ({
      value,
      label: queueLabelByValue.get(value) || value,
    }));
  }

  get queueCheckboxRows() {
    const sel = new Set(this.selectedQueues);
    return (this.queueOptions || []).map((item, index) => ({
      key: item.value,
      optionId: `qcb-${index}`,
      value: item.value,
      label: item.label,
      checked: sel.has(item.value),
    }));
  }

  get allQueuesSelected() {
    const opts = this.queueOptions || [];
    if (!opts.length) {
      return false;
    }
    const sel = new Set(this.selectedQueues);
    return opts.every((o) => sel.has(o.value));
  }

  get queueTriggerLabel() {
    const n = this.selectedQueues.length;
    if (n === 0) {
      return "Select queues";
    }
    if (n === 1) {
      const map = new Map((this.queueOptions || []).map((item) => [item.value, item.label]));
      return map.get(this.selectedQueues[0]) || this.selectedQueues[0];
    }
    return `${n} queues selected`;
  }

  get isAddRoleDisabled() {
    return (
      !this.selectedRole ||
      !this.selectedScale ||
      Number(this.selectedScale) < 1 ||
      !this.selectedQueues.length
    );
  }

  async loadQueues() {
    try {
      this.queueOptions = await getActiveCaseQueues();
    } catch (e) {
      this.queueOptions = [];
      this.showToast("Error", "Cannot load queue options.", "error");
    }
  }

  async loadBusinessHours() {
    try {
      this.businessHourOptions = await getBusinessHourOptions();
    } catch (e) {
      this.businessHourOptions = [];
      this.showToast("Error", "Cannot load business hours.", "error");
    }
  }

  async loadRolesByQueues() {
    try {
      this.roleOptions = await getRoleOptions({ queueNames: this.selectedQueues });
      if (!this.roleOptions.some((item) => item.value === this.selectedRole)) {
        this.selectedRole = "";
      }
    } catch (e) {
      this.roleOptions = [];
      this.selectedRole = "";
      this.showToast("Error", "Cannot load role options.", "error");
    }
  }

  handleNameChange(event) {
    this.assignmentName = event.detail.value || "";
  }

  handleStatusChange(event) {
    this.status = event.detail.value || "";
  }

  handleAssignmentMethodChange(event) {
    this.assignmentMethod = event.detail.value || "";
    if (this.isContinuousMethod) {
      this.selectedTimeSlots = [];
    } else if (this.isTimeBasedMethod) {
      this.scheduledTime = "";
    } else {
      this.scheduledTime = "";
      this.selectedTimeSlots = [];
    }
  }

  handleBusinessHoursChange(event) {
    this.businessHoursId = event.detail.value || "";
  }

  handleScheduledTimeChange(event) {
    this.scheduledTime = event.detail.value || "";
  }

  toggleQueueDropdown(event) {
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    if (this.queueDropdownOpen) {
      this.queueDropdownOpen = false;
      return;
    }
    this.queueDropdownOpen = true;
  }

  handleCloseQueueBackdrop(event) {
    if (event && typeof event.stopPropagation === "function") {
      event.stopPropagation();
    }
    this.queueDropdownOpen = false;
  }

  handleQueueDropdownMouseDown(event) {
    event.stopPropagation();
  }

  async handleToggleAllQueues(event) {
    event.stopPropagation();
    const checked = event.currentTarget.checked;
    const opts = this.queueOptions || [];
    if (checked) {
      this.selectedQueues = opts.map((o) => o.value);
    } else {
      this.selectedQueues = [];
    }
    await this.loadRolesByQueues();
  }

  async handleQueueCheckboxChange(event) {
    event.stopPropagation();
    const value = event.currentTarget.dataset.queueValue || "";
    const checked = event.currentTarget.checked;
    if (!value) {
      return;
    }
    let next = [...this.selectedQueues];
    if (checked && !next.includes(value)) {
      next.push(value);
    } else if (!checked) {
      next = next.filter((q) => q !== value);
    }
    this.selectedQueues = next;
    await this.loadRolesByQueues();
  }

  async handleRemoveQueue(event) {
    const queueValue = event.target.name;
    this.selectedQueues = this.selectedQueues.filter((item) => item !== queueValue);
    await this.loadRolesByQueues();
  }

  handleRoleChange(event) {
    this.selectedRole = event.detail.value || "";
  }

  handleScaleChange(event) {
    this.selectedScale = event.detail.value || "";
  }

  handleTimeSlotsChange(event) {
    this.selectedTimeSlots = event.detail.value || [];
  }

  async handleSave() {
    await this.saveRecord(false);
  }

  async handleSaveAndNew() {
    await this.saveRecord(true);
  }

  async saveRecord(stayOnForm) {
    this.isSaving = true;
    const fields = {
      Name: this.assignmentName,
      FEC_Status__c: this.status,
      FEC_Assignment_Method__c: this.assignmentMethod,
      FEC_Select_Queues__c: this.selectedQueues.join(";"),
      FEC_Role__c: this.roleRows.map((row) => `${row.role}|${row.scale}`).join(";"),
    };

    if (this.businessHoursId) {
      fields.FEC_Business_Hours__c = this.businessHoursId;
    }
    fields.FEC_Scale__c = this.roleRows.length === 1 ? this.roleRows[0].scale : null;
    if (this.isContinuousMethod && this.scheduledTime !== "") {
      fields.FEC_Scheduled_Time__c = Number(this.scheduledTime);
    }
    if (this.isTimeBasedMethod && this.selectedTimeSlots.length) {
      fields.FEC_Time_Slots__c = this.selectedTimeSlots.join(";");
    }

    try {
      const result = await createRecord({
        apiName: OBJECT_API_NAME,
        fields,
      });

      this.showToast("Success", "Case Assignment created.", "success");
      if (stayOnForm) {
        this.resetForm();
      } else {
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: result.id,
            objectApiName: OBJECT_API_NAME,
            actionName: "view",
          },
        });
      }
    } catch (e) {
      const message = e?.body?.message || "Create Case Assignment failed.";
      this.showToast("Error", message, "error");
    } finally {
      this.isSaving = false;
    }
  }

  handleCancel() {
    this[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: OBJECT_API_NAME,
        actionName: "home",
      },
    });
  }

  resetForm() {
    this.assignmentName = "";
    this.selectedQueues = [];
    this.queueDropdownOpen = false;
    this.roleOptions = [];
    this.selectedRole = "";
    this.selectedScale = "";
    this.roleRows = [];
    this.scheduledTime = "";
    this.selectedTimeSlots = [];
    this.businessHoursId = "";
  }

  handleAddRole() {
    const scale = Number(this.selectedScale);
    if (!this.selectedRole || !scale || scale < 1) {
      return;
    }

    const existed = this.roleRows.some((row) => row.role === this.selectedRole);
    if (existed) {
      this.showToast("Warning", "Role already exists in list.", "warning");
      return;
    }

    this.roleRows = [
      ...this.roleRows,
      {
        key: `${this.selectedRole}|${scale}`,
        role: this.selectedRole,
        scale,
      },
    ];

    this.selectedRole = "";
    this.selectedScale = "";
  }

  handleRemoveRole(event) {
    const roleName = event.currentTarget.dataset.role;
    this.roleRows = this.roleRows.filter((row) => row.role !== roleName);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
      })
    );
  }
}