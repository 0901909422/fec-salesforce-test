import { LightningElement, api, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord } from "lightning/uiRecordApi";
import STATUS_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Status__c";

import getNocItems from "@salesforce/apex/FEC_CaseAssignmentNocController.getNocItems";
import getProductTypeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getProductTypeOptions";
import getCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getCategoryOptions";
import getSubCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCategoryOptions";
import getSubCodeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCodeOptions";
import createNoc from "@salesforce/apex/FEC_CaseAssignmentNocController.createNoc";

const ASSIGNMENT_STATUS_FIELDS = [STATUS_FIELD];

export default class Fec_CaseAssignmentNocConfig extends LightningElement {
  _recordId;

  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    const next = value || "";
    const prev = this._recordId || "";
    if (next === prev) {
      return;
    }
    this._recordId = next;
    this.showModal = false;
    this.resetModalFields();
    if (next) {
      this.loadItems();
    } else {
      this.items = [];
    }
  }

  @track items = [];
  @track showModal = false;
  @track isSaving = false;

  @track productTypeOptions = [];
  @track categoryOptions = [];
  @track subCategoryOptions = [];
  @track subCodeOptions = [];

  selectedProductTypeId = "";
  selectedCategoryKey = "";
  selectedSubCategoryId = "";
  selectedSubCodeId = "";

  wiredAssignmentResult;

  @wire(getRecord, { recordId: "$recordId", fields: ASSIGNMENT_STATUS_FIELDS })
  wiredAssignment(result) {
    this.wiredAssignmentResult = result;
  }

  @wire(getProductTypeOptions)
  wiredProductTypes({ data, error }) {
    if (data) {
      this.productTypeOptions = (data || []).map((o) => ({
        label: o.label,
        value: o.value,
      }));
    } else if (error) {
      this.productTypeOptions = [];
    }
  }

  get canAddNoc() {
    const status = this.wiredAssignmentResult?.data?.fields?.FEC_Status__c?.value;
    return Boolean(this.recordId && status === "Draft");
  }

  get hasItems() {
    return this.items.length > 0;
  }

  get disableNewButton() {
    return !this.canAddNoc;
  }

  get categoryComboboxDisabled() {
    return !this.selectedProductTypeId;
  }

  get subCategoryComboboxDisabled() {
    return !this.selectedCategoryKey;
  }

  get subCodeComboboxDisabled() {
    return !this.selectedSubCategoryId;
  }

  get isSaveDisabled() {
    return (
      this.isSaving ||
      !this.selectedProductTypeId ||
      !this.selectedCategoryKey ||
      !this.selectedSubCategoryId
    );
  }

  connectedCallback() {
    if (this._recordId) {
      this.loadItems();
    }
  }

  async loadItems() {
    if (!this.recordId) {
      this.items = [];
      return;
    }
    try {
      const rows = await getNocItems({ assignmentId: this.recordId });
      this.items = (rows || []).map((row) => ({
        ...row,
        recordUrl: row?.id ? `/lightning/r/FEC_Case_Assignment_NOC__c/${row.id}/view` : "",
      }));
    } catch (e) {
      this.items = [];
      this.showToast("Error", "Cannot load Case Assignment NOC items.", "error");
    }
  }

  handleOpenModal() {
    if (!this.canAddNoc) {
      return;
    }
    this.resetModalFields();
    this.showModal = true;
  }

  closeModal() {
    this.showModal = false;
    this.resetModalFields();
  }

  resetModalFields() {
    this.selectedProductTypeId = "";
    this.selectedCategoryKey = "";
    this.selectedSubCategoryId = "";
    this.selectedSubCodeId = "";
    this.categoryOptions = [];
    this.subCategoryOptions = [];
    this.subCodeOptions = [];
  }

  async handleProductTypeChange(event) {
    this.selectedProductTypeId = event.detail.value || "";
    this.selectedCategoryKey = "";
    this.selectedSubCategoryId = "";
    this.selectedSubCodeId = "";
    this.subCategoryOptions = [];
    this.subCodeOptions = [];
    await this.refreshCategories();
  }

  async handleCategoryChange(event) {
    this.selectedCategoryKey = event.detail.value || "";
    this.selectedSubCategoryId = "";
    this.selectedSubCodeId = "";
    this.subCodeOptions = [];
    await this.refreshSubCategories();
  }

  async handleSubCategoryChange(event) {
    this.selectedSubCategoryId = event.detail.value || "";
    this.selectedSubCodeId = "";
    await this.refreshSubCodes();
  }

  handleSubCodeChange(event) {
    this.selectedSubCodeId = event.detail.value || "";
  }

  mapOptionItems(rows) {
    return (rows || []).map((o) => ({ label: o.label, value: o.value }));
  }

  async refreshCategories() {
    this.categoryOptions = [];
    if (!this.selectedProductTypeId) {
      return;
    }
    try {
      const rows = await getCategoryOptions({ productTypeId: this.selectedProductTypeId });
      this.categoryOptions = this.mapOptionItems(rows);
    } catch (e) {
      this.categoryOptions = [];
    }
  }

  async refreshSubCategories() {
    this.subCategoryOptions = [];
    if (!this.selectedProductTypeId || !this.selectedCategoryKey) {
      return;
    }
    try {
      const rows = await getSubCategoryOptions({
        productTypeId: this.selectedProductTypeId,
        categoryKey: this.selectedCategoryKey,
      });
      this.subCategoryOptions = this.mapOptionItems(rows);
    } catch (e) {
      this.subCategoryOptions = [];
    }
  }

  async refreshSubCodes() {
    this.subCodeOptions = [];
    if (!this.selectedProductTypeId || !this.selectedCategoryKey || !this.selectedSubCategoryId) {
      return;
    }
    try {
      const rows = await getSubCodeOptions({
        productTypeId: this.selectedProductTypeId,
        categoryKey: this.selectedCategoryKey,
        subCategoryId: this.selectedSubCategoryId,
      });
      this.subCodeOptions = this.mapOptionItems(rows);
    } catch (e) {
      this.subCodeOptions = [];
    }
  }

  async handleSave() {
    if (this.isSaveDisabled) {
      return;
    }
    this.isSaving = true;
    try {
      await createNoc({
        assignmentId: this.recordId,
        productTypeId: this.selectedProductTypeId,
        categoryKey: this.selectedCategoryKey,
        subCategoryId: this.selectedSubCategoryId,
        subCodeId: this.selectedSubCodeId || null,
      });
      this.showToast("Success", "Case Assignment NOC saved.", "success");
      this.closeModal();
      await this.loadItems();
    } catch (e) {
      const msg = e?.body?.message || e?.message || "Could not save Case Assignment NOC.";
      this.showToast("Error", msg, "error");
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