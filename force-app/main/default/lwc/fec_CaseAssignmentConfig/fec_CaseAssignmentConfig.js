import { LightningElement, api, track, wire } from "lwc";
import { getRecord, updateRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getActiveCaseQueues from "@salesforce/apex/FEC_CaseAssignmentConfigController.getActiveCaseQueues";
import getRoleOptions from "@salesforce/apex/FEC_CaseAssignmentConfigController.getRoleOptions";

import QUEUES_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Select_Queues__c";
import ROLE_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Role__c";
import SCALE_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Scale__c";
import ID_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.Id";

const FIELDS = [QUEUES_FIELD, ROLE_FIELD, SCALE_FIELD];

export default class Fec_CaseAssignmentConfig extends LightningElement {
  @api recordId;
  @track queueOptions = [];
  @track selectedQueues = [];
  @track roleOptions = [];
  @track roleRows = [];

  selectedRole = "";
  selectedScale = "";
  isSaving = false;
  loaded = false;

  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  wiredRecord({ data, error }) {
    if (data) {
      this.loadFromRecord(data);
      this.loaded = true;
    } else if (error) {
      this.showToast("Error", "Cannot load Case Assignment data.", "error");
    }
  }

  connectedCallback() {
    this.loadQueueOptions();
  }

  get hasRoleRows() {
    return this.roleRows.length > 0;
  }

  get isAddDisabled() {
    return !this.selectedRole || !this.selectedScale || Number(this.selectedScale) < 1;
  }

  async loadQueueOptions() {
    try {
      this.queueOptions = await getActiveCaseQueues();
    } catch (e) {
      this.showToast("Error", "Cannot load queue options.", "error");
    }
  }

  async loadRolesByQueues() {
    try {
      this.roleOptions = await getRoleOptions({ queueNames: this.selectedQueues });
    } catch (e) {
      this.roleOptions = [];
      this.showToast("Error", "Cannot load role options.", "error");
    }
  }

  loadFromRecord(recordData) {
    const rawQueues = recordData.fields.FEC_Select_Queues__c?.value || "";
    const rawRoles = recordData.fields.FEC_Role__c?.value || "";
    const rawScale = recordData.fields.FEC_Scale__c?.value;

    this.selectedQueues = this.deserializeList(rawQueues);
    this.roleRows = this.deserializeRoleRows(rawRoles, rawScale);
    this.loadRolesByQueues();
  }

  deserializeList(value) {
    if (!value) return [];
    return value
      .split(";")
      .map((item) => item.trim())
      .filter((item) => item);
  }

  deserializeRoleRows(roleText, fallbackScale) {
    if (!roleText) {
      return [];
    }

    const rows = [];
    const items = roleText
      .split(";")
      .map((item) => item.trim())
      .filter((item) => item);

    items.forEach((item) => {
      if (item.includes("|")) {
        const [role, scale] = item.split("|");
        rows.push({
          key: `${role}|${scale}`,
          role: (role || "").trim(),
          scale: Number(scale || 0),
        });
      } else {
        rows.push({
          key: `${item}|${fallbackScale || 1}`,
          role: item,
          scale: Number(fallbackScale || 1),
        });
      }
    });
    return rows.filter((row) => row.role && row.scale >= 1);
  }

  handleQueuesChange(event) {
    this.selectedQueues = event.detail.value || [];
    this.loadRolesByQueues();
  }

  handleRoleChange(event) {
    this.selectedRole = event.detail.value;
  }

  handleScaleChange(event) {
    this.selectedScale = event.detail.value;
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

  async handleSave() {
    if (!this.selectedQueues.length) {
      this.showToast("Warning", "Please select at least one queue.", "warning");
      return;
    }
    if (!this.roleRows.length) {
      this.showToast("Warning", "Please add at least one role-scale.", "warning");
      return;
    }

    this.isSaving = true;
    const fields = {};
    fields[ID_FIELD.fieldApiName] = this.recordId;
    fields[QUEUES_FIELD.fieldApiName] = this.selectedQueues.join(";");
    fields[ROLE_FIELD.fieldApiName] = this.roleRows
      .map((row) => `${row.role}|${row.scale}`)
      .join(";");
    fields[SCALE_FIELD.fieldApiName] = this.roleRows.length === 1 ? this.roleRows[0].scale : null;

    try {
      await updateRecord({ fields });
      this.showToast("Success", "Case Assignment configuration saved.", "success");
    } catch (e) {
      this.showToast("Error", "Save failed. Please review required fields.", "error");
    } finally {
      this.isSaving = false;
    }
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