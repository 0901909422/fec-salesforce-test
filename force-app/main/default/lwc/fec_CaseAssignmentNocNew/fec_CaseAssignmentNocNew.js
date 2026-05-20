import { LightningElement, wire, track } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import USER_ID from "@salesforce/user/Id";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import NAME_FIELD from "@salesforce/schema/User.Name";

import getProductTypeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getProductTypeOptions";
import getCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getCategoryOptions";
import getSubCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCategoryOptions";
import getSubCodeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCodeOptions";
import createNoc from "@salesforce/apex/FEC_CaseAssignmentNocController.createNoc";

const USER_FIELDS = [NAME_FIELD];

const ASSIGNMENT_LOOKUP = "FEC_Case_Assignment_Name__c";

function comboSel(dataId) {
  return `c-fec_-combo-box[data-id="${dataId}"]`;
}

/** One segment "Key=Val" hoặc "Key:Val" → map. */
function mergePairInto(out, segment) {
  if (!segment) {
    return;
  }
  const s = segment.trim();
  const eq = s.indexOf("=");
  const col = s.indexOf(":");
  let sep = -1;
  if (eq >= 0 && (col < 0 || eq < col)) {
    sep = eq;
  } else if (col >= 0) {
    sep = col;
  }
  if (sep <= 0) {
    return;
  }
  const k = s.slice(0, sep).trim();
  const v = s.slice(sep + 1).trim();
  if (k) {
    out[k] = v;
  }
}

/** defaultFieldValues: & và dạng list phân cách bởi dấu phẩy (một số org). */
function parseDefaultFieldValues(raw) {
  const out = {};
  if (raw == null || raw === "") {
    return out;
  }
  if (typeof raw === "object") {
    return { ...raw };
  }
  const str = String(raw).trim();
  if (str.startsWith("{")) {
    try {
      return JSON.parse(str);
    } catch (e) {
      /* continue */
    }
  }
  const decoded = decodeURIComponent(str.replace(/\+/g, " "));
  decoded.split("&").forEach((p) => mergePairInto(out, p));
  if (!out[ASSIGNMENT_LOOKUP]) {
    decoded.split(",").forEach((p) => mergePairInto(out, p));
  }
  return out;
}

/** Lấy Id Case Assignment trong chuỗi URL/context (workspace, inContextOfRef,...). */
function scrapeAssignmentIdFromText(text) {
  if (!text) {
    return undefined;
  }
  let s;
  try {
    s = decodeURIComponent(String(text));
  } catch (e) {
    s = String(text);
  }
  const rid = /\bFEC_Case_Assignment__c\/([a-zA-Z0-9]{15,18})(?:\/|\b)/;
  let m = s.match(rid);
  if (m) {
    return m[1];
  }
  m = s.match(/\/r\/FEC_Case_Assignment__c\/([a-zA-Z0-9]{15,18})(?:\/|$)/);
  return m?.[1];
}

function scrapeFromWs(wsParam) {
  if (!wsParam) {
    return undefined;
  }
  return scrapeAssignmentIdFromText(wsParam);
}

/**
 * LEX truyền inContextOfRef dạng "1.{base64url JSON}" — bên trong có attributes.recordId,
 * không có chuỗi FEC_Case_Assignment__c ở dạng plain text để regex bắt.
 */
function parseJsonFromBase64UrlPayload(payload) {
  if (!payload || typeof payload !== "string") {
    return null;
  }
  try {
    const b64 = payload.replace(/-/g, "+").replace(/_/g, "/");
    const pad = "=".repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(atob(b64 + pad));
  } catch (e) {
    return null;
  }
}

function assignmentIdFromInContextRef(raw) {
  if (raw == null || raw === "") {
    return undefined;
  }
  const s = String(raw).trim();
  const dot = s.indexOf(".");
  const payloadB64 = dot >= 0 ? s.slice(dot + 1).trim() : s;
  const obj = parseJsonFromBase64UrlPayload(payloadB64);
  const api = obj?.attributes?.objectApiName;
  const rid = obj?.attributes?.recordId;
  if (api === "FEC_Case_Assignment__c" && rid) {
    return String(rid).trim();
  }
  return scrapeAssignmentIdFromText(s);
}

function resolveParentAssignmentFromState(state) {
  if (!state) {
    return undefined;
  }
  const fromDefaults = parseDefaultFieldValues(state.defaultFieldValues)?.[ASSIGNMENT_LOOKUP];

  let id = fromDefaults;
  if (!id) {
    id = assignmentIdFromInContextRef(state.inContextOfRef);
  }
  if (!id) {
    id = scrapeFromWs(state.ws);
  }
  if (!id && state.backgroundContext != null && state.backgroundContext !== "") {
    id = scrapeAssignmentIdFromText(String(state.backgroundContext));
  }
  return id ? String(id).trim() : undefined;
}

export default class Fec_CaseAssignmentNocNew extends NavigationMixin(LightningElement) {
  pageTitle = "New Case Assignment NOC";
  sectionTitle = "Case Assignment NOC Information";

  @track productTypeOptionlst = [];
  @track categoryOptionlst = [];
  @track subCategoryOptionlst = [];
  @track subCodeOptionlst = [];

  assignmentRecordId;
  ownerRecordId = USER_ID;
  /** Related List → New có defaultFieldValues: khóa thay Assignment. */
  lockRelatedAssignmentPicker = false;

  selectedProductTypeId;
  selectedCategoryKey;
  selectedSubCategoryId;
  selectedSubCodeId;

  pickerRemountNonce = 0;

  userRecord;

  isSaving = false;

  assignmentSyncPass = 0;

  @wire(getProductTypeOptions)
  wiredProductTypes({ data, error }) {
    if (data) {
      this.productTypeOptionlst = (data || []).map((o) => ({ label: o.label, value: o.value }));
    } else if (error) {
      this.productTypeOptionlst = [];
    }
  }

  @wire(CurrentPageReference)
  wiredPageRef(pageRef) {
    const merged = {
      ...(pageRef?.state || {}),
      ...this._readUrlStateParams(),
    };
    const aid = resolveParentAssignmentFromState(merged);
    if (aid) {
      this.applyResolvedAssignmentId(aid);
    }
  }

  @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
  wiredMe({ data }) {
    this.userRecord = data;
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

  get auditStamp() {
    const name = getFieldValue(this.userRecord, NAME_FIELD) || "";
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    const stamp = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}, ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    return name ? `${name}, ${stamp}` : stamp;
  }

  get assignmentPickerKey() {
    return `ca-${String(this.pickerRemountNonce)}-${this.assignmentRecordId || "none"}`;
  }

  get assignmentPickerLocked() {
    return this.lockRelatedAssignmentPicker === true;
  }

  get isSaveDisabled() {
    return (
      this.isSaving ||
      !this.assignmentRecordId ||
      !this.ownerRecordId ||
      !this.selectedProductTypeId ||
      !this.selectedCategoryKey ||
      !this.selectedSubCategoryId
    );
  }

  connectedCallback() {
    Promise.resolve().then(() => {
      this.applyResolvedAssignmentId(resolveParentAssignmentFromState(this._readUrlStateParams()));
      this.syncAssignmentFromWindowLocation();
      this.clearComboUi();
    });
  }

  renderedCallback() {
    if (this.assignmentRecordId || this.assignmentSyncPass >= 2) {
      return;
    }
    this.assignmentSyncPass += 1;
    Promise.resolve().then(() => {
      this.applyResolvedAssignmentId(resolveParentAssignmentFromState(this._readUrlStateParams()));
      this.syncAssignmentFromWindowLocation();
    });
  }

  _readUrlStateParams() {
    try {
      const href = window.location?.href;
      if (!href) {
        return {};
      }
      const u = new URL(href);
      const out = {};
      const ws = u.searchParams.get("ws");
      const ic = u.searchParams.get("inContextOfRef");
      const dfv = u.searchParams.get("defaultFieldValues");
      const bg = u.searchParams.get("backgroundContext");
      if (ws) {
        out.ws = ws;
      }
      if (ic) {
        out.inContextOfRef = ic;
      }
      if (dfv) {
        out.defaultFieldValues = dfv;
      }
      if (bg) {
        out.backgroundContext = bg;
      }
      return out;
    } catch (e) {
      return {};
    }
  }

  applyResolvedAssignmentId(aid) {
    if (!aid) {
      return;
    }
    if (aid === this.assignmentRecordId) {
      return;
    }
    this.assignmentRecordId = aid;
    this.lockRelatedAssignmentPicker = true;
    this.pickerRemountNonce += 1;
  }

  /** Bổ sung khi override Aura / state chưa có đủ field (defaultFieldValues, ws trên URL). */
  syncAssignmentFromWindowLocation() {
    try {
      const href = window.location?.href;
      if (!href) {
        return;
      }
      const u = new URL(href);
      const dfv = u.searchParams.get("defaultFieldValues");
      if (dfv) {
        const fromD = parseDefaultFieldValues(dfv)[ASSIGNMENT_LOOKUP];
        if (fromD) {
          this.applyResolvedAssignmentId(String(fromD).trim());
        }
      }
      const ic = u.searchParams.get("inContextOfRef");
      const fromIc = assignmentIdFromInContextRef(ic);
      if (fromIc) {
        this.applyResolvedAssignmentId(fromIc);
      }
      const ws = u.searchParams.get("ws");
      const fromWs = scrapeFromWs(ws);
      if (fromWs) {
        this.applyResolvedAssignmentId(fromWs);
      }
    } catch (e) {
      /* ignore */
    }
  }

  handleAssignmentChange(e) {
    this.assignmentRecordId = e.detail?.recordId || undefined;
  }

  handleOwnerChange(e) {
    this.ownerRecordId = e.detail?.recordId || undefined;
  }

  clearComboUi() {
    ["noc-new-prod-type", "noc-new-category", "noc-new-sub-category", "noc-new-sub-code"].forEach((id) => {
      this.template.querySelector(comboSel(id))?.clear?.();
    });
  }

  mapOptionItems(rows) {
    return (rows || []).map((o) => ({ label: o.label, value: o.value }));
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

  reportRequiredCombos() {
    const p = this.template.querySelector(comboSel("noc-new-prod-type"));
    const c = this.template.querySelector(comboSel("noc-new-category"));
    const s = this.template.querySelector(comboSel("noc-new-sub-category"));
    return (
      [p?.reportValidity?.(), c?.reportValidity?.(), s?.reportValidity?.()].every((v) => v !== false)
    );
  }

  handleCancel() {
    if (this.assignmentRecordId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: this.assignmentRecordId,
          objectApiName: "FEC_Case_Assignment__c",
          actionName: "view",
        },
      });
    } else {
      this[NavigationMixin.Navigate]({
        type: "standard__objectPage",
        attributes: {
          objectApiName: "FEC_Case_Assignment_NOC__c",
          actionName: "home",
        },
      });
    }
  }

  async handleSave() {
    if (this.isSaveDisabled) {
      return;
    }
    if (!this.assignmentRecordId || !this.ownerRecordId) {
      this.showToast("Error", "Case Assignment và Owner là bắt buộc.", "error");
      return;
    }
    if (!this.reportRequiredCombos()) {
      return;
    }
    this.isSaving = true;
    try {
      const nocId = await createNoc({
        assignmentId: this.assignmentRecordId,
        productTypeId: this.selectedProductTypeId,
        categoryKey: this.selectedCategoryKey,
        subCategoryId: this.selectedSubCategoryId,
        subCodeId: this.selectedSubCodeId || null,
        ownerId: this.ownerRecordId,
      });
      this.showToast("Success", "Case Assignment NOC saved.", "success");
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: nocId,
          objectApiName: "FEC_Case_Assignment_NOC__c",
          actionName: "view",
        },
      });
    } catch (e) {
      const msg =
        e?.body?.pageErrors?.[0]?.message ||
        e?.body?.message ||
        e?.message ||
        "Could not save Case Assignment NOC.";
      this.showToast("Error", msg, "error");
    } finally {
      this.isSaving = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
