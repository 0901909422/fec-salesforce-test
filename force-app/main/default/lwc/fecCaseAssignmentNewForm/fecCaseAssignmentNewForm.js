import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { createRecord, getRecord } from "lightning/uiRecordApi";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import {
  IsConsoleNavigation,
  getFocusedTabInfo,
  closeTab,
  openTab,
  openSubtab,
} from "lightning/platformWorkspaceApi";
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
const STATUS_DRAFT = "Draft";
const STATUS_ACTIVE = "Active";
const STATUS_ARCHIVED = "Archived";
/** Luôn hiển thị đủ 3 giá trị trên form New (org picklist API có thể thiếu Active). */
const STATUS_OPTIONS_CANONICAL = [
  { label: STATUS_DRAFT, value: STATUS_DRAFT },
  { label: STATUS_ACTIVE, value: STATUS_ACTIVE },
  { label: STATUS_ARCHIVED, value: STATUS_ARCHIVED },
];
const MSG_NAME_BLANK = "Case Assignment can't be blank";
const MSG_ROLE_REQUIRED_WITH_QUEUE = "Role is required when Select Queues is specified.";
const MSG_DUPLICATE_NAME = "Case Assignment Name đã tồn tại.";
const MSG_CANNOT_ACTIVE_WITHOUT_NOC =
  "Không thể Active khi chưa thêm Case Assignment NOC.";

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
  pageErrors = [];
  showErrorModal = false;
  queueHasError = false;
  roleHasError = false;
  currentTabId;

  @wire(IsConsoleNavigation) isConsoleNavigation;

  @wire(getObjectInfo, { objectApiName: CASE_ASSIGNMENT_OBJECT })
  objectInfo;

  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: STATUS_FIELD,
  })
  wiredStatus({ data }) {
    if (data) {
      this._wiredStatusOptions = data.values;
      if (!this.status) {
        this.status = STATUS_DRAFT;
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

  async connectedCallback() {
    try {
      const { tabId } = await getFocusedTabInfo();
      this.currentTabId = tabId;
    } catch (e) {
      this.currentTabId = null;
    }
    this.loadQueues();
    this.loadBusinessHours();
  }

  get statusOptions() {
    const wiredByValue = new Map(
      (this._wiredStatusOptions || []).map((option) => [option.value, option])
    );
    return STATUS_OPTIONS_CANONICAL.map(
      (canonical) => wiredByValue.get(canonical.value) || canonical
    );
  }

  get assignmentMethodOptions() {
    return this._assignmentMethodOptions || [];
  }
  set assignmentMethodOptions(value) {
    this._assignmentMethodOptions = value;
  }

  get hasPageErrors() {
    return (this.pageErrors || []).length > 0;
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
    return !this.selectedRole || !this.selectedQueues.length;
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
      this.pruneRoleRowsToAvailableOptions();
    } catch (e) {
      this.roleOptions = [];
      this.selectedRole = "";
      this.roleRows = [];
      this.showToast("Error", "Cannot load role options.", "error");
    }
  }

  pruneRoleRowsToAvailableOptions() {
    if (!this.selectedQueues.length) {
      this.roleRows = [];
      this.selectedRole = "";
      return;
    }
    const allowed = new Set((this.roleOptions || []).map((item) => item.value));
    this.roleRows = this.roleRows.filter((row) => allowed.has(row.role));
    if (this.selectedRole && !allowed.has(this.selectedRole)) {
      this.selectedRole = "";
    }
  }

  handleNameChange(event) {
    this.assignmentName = event.detail.value || "";
    this.clearPageErrors();
  }

  handleStatusChange(event) {
    this.status = event.detail.value || "";
    this.clearPageErrors();
  }

  handleAssignmentMethodChange(event) {
    this.assignmentMethod = event.detail.value || "";
    this.clearPageErrors();
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
    this.clearPageErrors();
  }

  handleScheduledTimeChange(event) {
    this.scheduledTime = event.detail.value || "";
    this.clearPageErrors();
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
    this.clearPageErrors();
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
    this.clearPageErrors();
    await this.loadRolesByQueues();
  }

  async handleRemoveQueue(event) {
    const queueValue = event.target.name;
    this.selectedQueues = this.selectedQueues.filter((item) => item !== queueValue);
    this.clearPageErrors();
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
    this.clearPageErrors();
  }

  async handleSave() {
    await this.saveRecord(false);
  }

  async handleSaveAndNew() {
    await this.saveRecord(true);
  }

  async saveRecord(stayOnForm) {
    this.clearPageErrors();
    const validationErrors = this.validateBeforeSave();
    if (validationErrors.length) {
      this.presentPageErrors(validationErrors);
      return;
    }

    this.isSaving = true;
    const trimmedName = (this.assignmentName || "").trim();
    const fields = {
      Name: trimmedName,
      FEC_Status__c: this.status,
      FEC_Assignment_Method__c: this.assignmentMethod,
      FEC_Select_Queues__c: this.selectedQueues.join(";"),
      FEC_Role__c: this.roleRows.map((row) => `${row.role}|${row.scale}`).join(";"),
      FEC_Business_Hours__c: this.businessHoursId,
    };

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
        await this.navigateAfterCreate(result.id);
      }
    } catch (e) {
      const messages = this.extractRecordErrors(e);
      this.presentPageErrors(
        messages.length ? messages : [e?.body?.message || "Create Case Assignment failed."]
      );
    } finally {
      this.isSaving = false;
    }
  }

  async navigateAfterCreate(recordId) {
    const pageReference = {
      type: "standard__recordPage",
      attributes: {
        recordId,
        objectApiName: OBJECT_API_NAME,
        actionName: "view",
      },
    };

    let tabToClose = this.currentTabId;
    try {
      const focusedTab = await getFocusedTabInfo();
      if (!tabToClose) {
        tabToClose = focusedTab.tabId;
      }
      const parentTabId = focusedTab.isSubtab
        ? focusedTab.parentTabId
        : focusedTab.tabId;

      await openSubtab(parentTabId, {
        pageReference,
        focus: true,
      });

      setTimeout(async () => {
        try {
          if (tabToClose) {
            await closeTab(tabToClose);
          }
        } catch (e) {
          // ignore tab close failures
        }
      }, 500);
      return;
    } catch (e) {
      // fall through to console / standard navigation
    }

    if (this.isConsoleNavigation?.data === true) {
      if (!tabToClose) {
        try {
          const { tabId } = await getFocusedTabInfo();
          tabToClose = tabId;
        } catch (err) {
          tabToClose = null;
        }
      }

      await openTab({
        recordId,
        focus: true,
      });

      setTimeout(async () => {
        try {
          if (tabToClose) {
            await closeTab(tabToClose);
          }
        } catch (err) {
          // ignore tab close failures
        }
      }, 500);
      return;
    }

    this[NavigationMixin.Navigate](pageReference);
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
    this.clearPageErrors();
    const draftOption = this.statusOptions.find((option) => option.value === STATUS_DRAFT);
    this.status = draftOption?.value || STATUS_DRAFT;
  }

  validateBeforeSave() {
    const errors = [];
    const trimmedName = (this.assignmentName || "").trim();

    if (!trimmedName) {
      errors.push(MSG_NAME_BLANK);
    }
    if (!this.status) {
      errors.push("Status can't be blank");
    }
    if (this.status === STATUS_ACTIVE) {
      errors.push(MSG_CANNOT_ACTIVE_WITHOUT_NOC);
    }
    if (!this.assignmentMethod) {
      errors.push("Assignment Method can't be blank");
    }
    if (!this.businessHoursId) {
      errors.push("Business Hours can't be blank");
    }
    if (!this.selectedQueues.length) {
      errors.push("Select Queues can't be blank");
    }
    if (this.isTimeBasedMethod && !this.selectedTimeSlots.length) {
      errors.push("Time Slots can't be blank");
    }
    if (this.selectedQueues.length && !this.roleRows.length) {
      errors.push(MSG_ROLE_REQUIRED_WITH_QUEUE);
    }
    return errors;
  }

  extractRecordErrors(error) {
    const messages = [];
    const output = error?.body?.output;
    if (output?.fieldErrors) {
      Object.values(output.fieldErrors).forEach((entries) => {
        (entries || []).forEach((entry) => {
          if (entry?.message) {
            messages.push(entry.message);
          }
        });
      });
    }
    if (output?.errors) {
      output.errors.forEach((entry) => {
        if (entry?.message) {
          messages.push(entry.message);
        }
      });
    }
    const bodyMessage = error?.body?.message;
    if (bodyMessage) {
      messages.push(bodyMessage);
    }
    return this.normalizePageErrors(messages);
  }

  normalizePageErrors(messages) {
    const normalized = [];
    const seen = new Set();
    (messages || []).forEach((raw) => {
      if (!raw) {
        return;
      }
      let message = String(raw).trim();
      const lower = message.toLowerCase();
      if (
        message === MSG_DUPLICATE_NAME ||
        lower.includes("đã tồn tại") ||
        lower.includes("duplicate") ||
        lower.includes("must be unique")
      ) {
        message = MSG_DUPLICATE_NAME;
      }
      if (!seen.has(message)) {
        seen.add(message);
        normalized.push(message);
      }
    });
    return normalized;
  }

  presentPageErrors(messages) {
    this.pageErrors = this.normalizePageErrors(messages);
    this.showErrorModal = this.pageErrors.length > 0;
    this.reportFieldValidity(this.pageErrors);
    requestAnimationFrame(() => {
      const anchor = this.template.querySelector('[data-id="page-error-anchor"]');
      anchor?.scrollIntoView?.({ behavior: "smooth", block: "start" });
    });
  }

  closeErrorModal() {
    this.showErrorModal = false;
  }

  clearPageErrors() {
    this.pageErrors = [];
    this.showErrorModal = false;
    this.queueHasError = false;
    this.roleHasError = false;
    this.template.querySelectorAll("[data-field]").forEach((field) => {
      if (typeof field.setCustomValidity === "function") {
        field.setCustomValidity("");
        field.reportValidity();
      }
    });
  }

  reportFieldValidity(messages) {
    const hasDuplicate = messages.includes(MSG_DUPLICATE_NAME);
    const fieldRules = [
      {
        blankMessage: MSG_NAME_BLANK,
        selector: '[data-field="assignmentName"]',
      },
      {
        blankMessage: "Status can't be blank",
        selector: '[data-field="status"]',
      },
      {
        blankMessage: "Assignment Method can't be blank",
        selector: '[data-field="assignmentMethod"]',
      },
      {
        blankMessage: "Business Hours can't be blank",
        selector: '[data-field="businessHours"]',
      },
      {
        blankMessage: "Time Slots can't be blank",
        selector: '[data-field="timeSlots"]',
      },
    ];

    fieldRules.forEach(({ blankMessage, selector }) => {
      const field = this.template.querySelector(selector);
      if (!field) {
        return;
      }
      if (messages.includes(blankMessage)) {
        field.setCustomValidity(blankMessage);
        field.reportValidity();
        return;
      }
      if (selector.includes("assignmentName") && hasDuplicate) {
        field.setCustomValidity("");
        field.reportValidity();
        return;
      }
      if (
        selector.includes("status") &&
        messages.includes(MSG_CANNOT_ACTIVE_WITHOUT_NOC)
      ) {
        field.setCustomValidity(MSG_CANNOT_ACTIVE_WITHOUT_NOC);
        field.reportValidity();
        return;
      }
      field.setCustomValidity("");
      field.reportValidity();
    });

    this.queueHasError = messages.includes("Select Queues can't be blank");
    this.roleHasError = messages.includes(MSG_ROLE_REQUIRED_WITH_QUEUE);
  }

  handleAddRole() {
    const rawScale = this.selectedScale;
    const scale =
      rawScale === "" || rawScale == null ? 1 : Number(rawScale);
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
