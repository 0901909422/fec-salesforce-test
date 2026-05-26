import { LightningElement, api, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from "lightning/refresh";
import { getRecord, getRecordNotifyChange } from "lightning/uiRecordApi";
import STATUS_FIELD from "@salesforce/schema/FEC_Case_Assignment__c.FEC_Status__c";

import getNocItems from "@salesforce/apex/FEC_CaseAssignmentNocController.getNocItems";
import getProductTypeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getProductTypeOptions";
import getCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getCategoryOptions";
import getSubCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCategoryOptions";
import getSubCodeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCodeOptions";
import createNoc from "@salesforce/apex/FEC_CaseAssignmentNocController.createNoc";

const ASSIGNMENT_STATUS_FIELDS = [STATUS_FIELD];

function comboSelector(dataId) {
  return `c-fec_-combo-box[data-id="${dataId}"]`;
}

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

  /** Options for fec_ComboBox (same UX as fec_CaseEditNOC Nature of Case sidebar). */
  @track productTypeOptionlst = [];
  @track categoryOptionlst = [];
  @track subCategoryOptionlst = [];
  @track subCodeOptionlst = [];

  selectedProductTypeId;
  selectedCategoryKey;
  selectedSubCategoryId;
  selectedSubCodeId;

  wiredAssignmentResult;

  @wire(getRecord, { recordId: "$recordId", fields: ASSIGNMENT_STATUS_FIELDS })
  wiredAssignment(result) {
    this.wiredAssignmentResult = result;
  }

  @wire(getProductTypeOptions)
  wiredProductTypes({ data, error }) {
    if (data) {
      this.productTypeOptionlst = (data || []).map((o) => ({
        label: o.label,
        value: o.value,
      }));
    } else if (error) {
      this.productTypeOptionlst = [];
    }
  }

  get formattedProductTypeOption() {
    return JSON.stringify(this.productTypeOptionlst || []);
  }

  get formattedCategoryOption() {
    return JSON.stringify(this.categoryOptionlst || []);
  }

  get formattedSubCategoryOption() {
    return JSON.stringify(this.subCategoryOptionlst || []);
  }

  get formattedSubCodeOption() {
    return JSON.stringify(this.subCodeOptionlst || []);
  }

  get comboProdTypeLocked() {
    return false;
  }

  get comboCategoryLocked() {
    return !this.selectedProductTypeId;
  }

  get comboSubCategoryLocked() {
    return !this.selectedCategoryKey;
  }

  get comboSubCodeLocked() {
    return !this.selectedSubCategoryId;
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

  /** Không chỉ New NOC — mọi thao tác CRM trên NOC đều cần parent Draft (server + UX). */
  get nocRestrictedMessage() {
    const status = this.wiredAssignmentResult?.data?.fields?.FEC_Status__c?.value;
    if (!this.recordId || !status || status === "Draft") {
      return "";
    }
    return (
      "Chỉ khi Case Assignment có Status Draft mới thêm được Case Assignment NOC và chỉnh sửa/xóa NOC trên các màn Salesforce." +
      " Active: chỉ đổi được Status của Case Assignment sang Archived (tab chi tiết). Archived: không chỉnh được."
    );
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
    Promise.resolve().then(() => this.clearAllCombosUi());
  }

  closeModal() {
    this.showModal = false;
    this.resetModalFields();
    Promise.resolve().then(() => this.clearAllCombosUi());
  }

  resetModalFields() {
    this.selectedProductTypeId = undefined;
    this.selectedCategoryKey = undefined;
    this.selectedSubCategoryId = undefined;
    this.selectedSubCodeId = undefined;
    this.categoryOptionlst = [];
    this.subCategoryOptionlst = [];
    this.subCodeOptionlst = [];
  }

  clearAllCombosUi() {
    [
      "assignment-noc-prod-type",
      "assignment-noc-category",
      "assignment-noc-sub-category",
      "assignment-noc-sub-code",
    ].forEach((dataId) => {
      const el = this.template.querySelector(comboSelector(dataId));
      el?.clear?.();
    });
  }

  async handleChangeProductType(e) {
    this.selectedProductTypeId = e.detail?.value ?? undefined;
    this.selectedCategoryKey = undefined;
    this.selectedSubCategoryId = undefined;
    this.selectedSubCodeId = undefined;
    this.subCategoryOptionlst = [];
    this.subCodeOptionlst = [];
    await this.refreshCategories();
  }

  handleRemoveProductType() {
    this.selectedProductTypeId = undefined;
    this.selectedCategoryKey = undefined;
    this.selectedSubCategoryId = undefined;
    this.selectedSubCodeId = undefined;
    this.categoryOptionlst = [];
    this.subCategoryOptionlst = [];
    this.subCodeOptionlst = [];
  }

  async handleChangeCategory(e) {
    this.selectedCategoryKey = e.detail?.value ?? undefined;
    this.selectedSubCategoryId = undefined;
    this.selectedSubCodeId = undefined;
    this.subCodeOptionlst = [];
    await this.refreshSubCategories();
  }

  handleRemoveCategory() {
    this.selectedCategoryKey = undefined;
    this.selectedSubCategoryId = undefined;
    this.selectedSubCodeId = undefined;
    this.subCategoryOptionlst = [];
    this.subCodeOptionlst = [];
  }

  async handleChangeSubCategory(e) {
    this.selectedSubCategoryId = e.detail?.value ?? undefined;
    this.selectedSubCodeId = undefined;
    await this.refreshSubCodes();
  }

  handleRemoveSubCategory() {
    this.selectedSubCategoryId = undefined;
    this.selectedSubCodeId = undefined;
    this.subCodeOptionlst = [];
  }

  handleChangeSubCode(e) {
    this.selectedSubCodeId = e.detail?.value ?? undefined;
  }

  handleRemoveSubCode() {
    this.selectedSubCodeId = undefined;
  }

  mapOptionItems(rows) {
    return (rows || []).map((o) => ({ label: o.label, value: o.value }));
  }

  async refreshCategories() {
    this.categoryOptionlst = [];
    if (!this.selectedProductTypeId) {
      return;
    }
    try {
      const rows = await getCategoryOptions({ productTypeId: this.selectedProductTypeId });
      this.categoryOptionlst = this.mapOptionItems(rows);
    } catch (e) {
      this.categoryOptionlst = [];
    }
  }

  async refreshSubCategories() {
    this.subCategoryOptionlst = [];
    if (!this.selectedProductTypeId || !this.selectedCategoryKey) {
      return;
    }
    try {
      const rows = await getSubCategoryOptions({
        productTypeId: this.selectedProductTypeId,
        categoryKey: this.selectedCategoryKey,
      });
      this.subCategoryOptionlst = this.mapOptionItems(rows);
    } catch (e) {
      this.subCategoryOptionlst = [];
    }
  }

  async refreshSubCodes() {
    this.subCodeOptionlst = [];
    if (!this.selectedProductTypeId || !this.selectedCategoryKey || !this.selectedSubCategoryId) {
      return;
    }
    try {
      const rows = await getSubCodeOptions({
        productTypeId: this.selectedProductTypeId,
        categoryKey: this.selectedCategoryKey,
        subCategoryId: this.selectedSubCategoryId,
      });
      this.subCodeOptionlst = this.mapOptionItems(rows);
    } catch (e) {
      this.subCodeOptionlst = [];
    }
  }

  reportModalComboboxValidity() {
    const prod = this.template.querySelector(comboSelector("assignment-noc-prod-type"));
    const cat = this.template.querySelector(comboSelector("assignment-noc-category"));
    const subCat = this.template.querySelector(comboSelector("assignment-noc-sub-category"));
    return [
      prod?.reportValidity?.() !== false,
      cat?.reportValidity?.() !== false,
      subCat?.reportValidity?.() !== false,
    ].every(Boolean);
  }

  async handleSave() {
    if (this.isSaveDisabled) {
      return;
    }
    if (!this.reportModalComboboxValidity()) {
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
      getRecordNotifyChange([{ recordId: this.recordId }]);
      window.setTimeout(() => {
        getRecordNotifyChange([{ recordId: this.recordId }]);
      }, 700);
      this.dispatchEvent(new RefreshEvent());
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
      }),
    );
  }
}
