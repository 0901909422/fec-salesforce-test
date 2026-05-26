import { LightningElement, api, wire, track } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from "lightning/refresh";
import USER_ID from "@salesforce/user/Id";
import { getRecord, getFieldValue, getRecordNotifyChange } from "lightning/uiRecordApi";
import NAME_FIELD from "@salesforce/schema/User.Name";
import {
  IsConsoleNavigation,
  getFocusedTabInfo,
  closeTab,
  openSubtab,
  openTab,
  refreshTab,
} from "lightning/platformWorkspaceApi";

import getProductTypeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getProductTypeOptions";
import getCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getCategoryOptions";
import getSubCategoryOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCategoryOptions";
import getSubCodeOptions from "@salesforce/apex/FEC_CaseAssignmentNocController.getSubCodeOptions";
import createNoc from "@salesforce/apex/FEC_CaseAssignmentNocController.createNoc";
import updateNoc from "@salesforce/apex/FEC_CaseAssignmentNocController.updateNoc";
import NOC_ASSIGNMENT_FIELD from "@salesforce/schema/FEC_Case_Assignment_NOC__c.FEC_Case_Assignment_Name__c";
import NOC_PRODUCT_TYPE_FIELD from "@salesforce/schema/FEC_Case_Assignment_NOC__c.FEC_Product_Type__c";
import NOC_CATEGORY_FIELD from "@salesforce/schema/FEC_Case_Assignment_NOC__c.FEC_Category__c";
import NOC_CATEGORY_NAME_FIELD from "@salesforce/schema/FEC_Case_Assignment_NOC__c.FEC_Category__r.Name";
import NOC_SUB_CATEGORY_FIELD from "@salesforce/schema/FEC_Case_Assignment_NOC__c.FEC_Sub_Category__c";
import NOC_SUB_CODE_FIELD from "@salesforce/schema/FEC_Case_Assignment_NOC__c.FEC_Sub_Code__c";

const USER_FIELDS = [NAME_FIELD];
const NOC_EDIT_FIELDS = [
  NOC_ASSIGNMENT_FIELD,
  NOC_PRODUCT_TYPE_FIELD,
  NOC_CATEGORY_FIELD,
  NOC_CATEGORY_NAME_FIELD,
  NOC_SUB_CATEGORY_FIELD,
  NOC_SUB_CODE_FIELD,
];

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

function scrapeNocRecordIdFromHref(href) {
  if (!href) {
    return undefined;
  }
  const m = String(href).match(
    /\/FEC_Case_Assignment_NOC__c\/([a-zA-Z0-9]{15,18})(?:\/edit|$|\?|#)/i
  );
  return m?.[1];
}

function resolveNocRecordIdFromState(state, href) {
  const recordId = state?.recordId || state?.c__recordId;
  if (recordId) {
    return String(recordId).trim();
  }
  return scrapeNocRecordIdFromHref(href);
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

  nocRecordId;
  isEditMode = false;
  nocHydrated = false;

  _recordId;

  /** Aura Edit override truyền recordId — CurrentPageReference thường không có trên action override. */
  @api
  get recordId() {
    return this._recordId;
  }
  set recordId(value) {
    this._recordId = value;
    if (value) {
      this.applyEditContext(String(value).trim());
    }
  }

  @track productTypeOptionlst = [];
  @track categoryOptionlst = [];
  @track subCategoryOptionlst = [];
  @track subCodeOptionlst = [];

  assignmentRecordId;
  /** Related List → New có defaultFieldValues: khóa thay Assignment. */
  lockRelatedAssignmentPicker = false;

  selectedProductTypeId;
  selectedCategoryKey;
  selectedSubCategoryId;
  selectedSubCodeId;

  pickerRemountNonce = 0;

  userRecord;

  isSaving = false;
  pageErrors = [];
  currentTabId;

  assignmentSyncPass = 0;

  @wire(IsConsoleNavigation) isConsoleNavigation;

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
    const objectApiName = pageRef?.attributes?.objectApiName;
    const actionName = pageRef?.attributes?.actionName;
    const recordId = pageRef?.attributes?.recordId;
    if (
      objectApiName === "FEC_Case_Assignment_NOC__c" &&
      actionName === "edit" &&
      recordId
    ) {
      this.applyEditContext(recordId);
      return;
    }

    const nocFromState = resolveNocRecordIdFromState(
      pageRef?.state,
      typeof window !== "undefined" ? window.location?.href : undefined
    );
    if (nocFromState) {
      this.applyEditContext(nocFromState);
      return;
    }

    const merged = {
      ...(pageRef?.state || {}),
      ...this._readUrlStateParams(),
    };
    const aid = resolveParentAssignmentFromState(merged);
    if (aid) {
      this.applyResolvedAssignmentId(aid);
    }
  }

  applyEditContext(recordId) {
    if (!recordId) {
      return;
    }
    const normalizedId = String(recordId).trim();
    if (this.nocRecordId === normalizedId && this.isEditMode) {
      return;
    }
    this.nocHydrated = false;
    this.isEditMode = true;
    this.nocRecordId = normalizedId;
    this._recordId = normalizedId;
    this.pageTitle = "Edit Case Assignment NOC";
    this.lockRelatedAssignmentPicker = true;
  }

  @wire(getRecord, { recordId: "$nocRecordId", fields: NOC_EDIT_FIELDS })
  wiredNocRecord({ data, error }) {
    if (!this.isEditMode || !this.nocRecordId || !data || this.nocHydrated) {
      if (error && this.isEditMode) {
        this.showToast("Error", "Cannot load Case Assignment NOC.", "error");
      }
      return;
    }
    this.assignmentRecordId = getFieldValue(data, NOC_ASSIGNMENT_FIELD);
    this.selectedProductTypeId = getFieldValue(data, NOC_PRODUCT_TYPE_FIELD);
    this.selectedCategoryKey = getFieldValue(data, NOC_CATEGORY_NAME_FIELD);
    this.selectedSubCategoryId = getFieldValue(data, NOC_SUB_CATEGORY_FIELD);
    this.selectedSubCodeId = getFieldValue(data, NOC_SUB_CODE_FIELD);
    this.nocHydrated = true;
    this.pickerRemountNonce += 1;
    this.hydrateNocComboOptions();
  }

  async hydrateNocComboOptions() {
    await this.refreshCategories();
    await this.refreshSubCategories();
    await this.refreshSubCodes();
    this.pickerRemountNonce += 1;
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
    const now = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    return `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()}, ${pad(now.getHours())}:${pad(now.getMinutes())}`;
  }

  get ownerDisplayName() {
    return getFieldValue(this.userRecord, NAME_FIELD) || "";
  }

  get hasOwnerDisplayName() {
    return Boolean(this.ownerDisplayName);
  }

  get hasPageErrors() {
    return (this.pageErrors || []).length > 0;
  }

  get isSaveDisabled() {
    return this.isSaving;
  }

  get assignmentPickerKey() {
    return `ca-${String(this.pickerRemountNonce)}-${this.assignmentRecordId || "none"}`;
  }

  get assignmentPickerLocked() {
    return this.lockRelatedAssignmentPicker === true || this.isEditMode === true;
  }

  connectedCallback() {
    Promise.resolve().then(async () => {
      try {
        const { tabId } = await getFocusedTabInfo();
        this.currentTabId = tabId;
      } catch (e) {
        this.currentTabId = null;
      }
      const nocFromUrl = scrapeNocRecordIdFromHref(window.location?.href);
      if (nocFromUrl) {
        this.applyEditContext(nocFromUrl);
      }
      if (!this.isEditMode) {
        this.applyResolvedAssignmentId(resolveParentAssignmentFromState(this._readUrlStateParams()));
        this.syncAssignmentFromWindowLocation();
        this.clearComboUi();
      }
    });
  }

  renderedCallback() {
    if (this.isEditMode || this.assignmentRecordId || this.assignmentSyncPass >= 2) {
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
    this.clearPageErrors();
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
    this.clearPageErrors();
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
    this.clearPageErrors();
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
    this.clearPageErrors();
    await this.refreshSubCodes();
  }

  handleRemoveSubCategory() {
    this.selectedSubCategoryId = undefined;
    this.selectedSubCodeId = undefined;
    this.subCodeOptionlst = [];
  }

  handleChangeSubCode(e) {
    this.selectedSubCodeId = e.detail?.value ?? undefined;
    this.clearPageErrors();
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

  validateBeforeSave() {
    const errors = [];
    if (!this.assignmentRecordId) {
      errors.push("Case Assignment can't be blank");
    }
    if (!this.selectedProductTypeId) {
      errors.push("Product Type can't be blank");
    }
    if (!this.selectedCategoryKey) {
      errors.push("Category can't be blank");
    }
    if (!this.selectedSubCategoryId) {
      errors.push("Sub-Category can't be blank");
    }
    return errors;
  }

  clearPageErrors() {
    this.pageErrors = [];
  }

  reportFieldValidity(messages) {
    const assignmentPicker = this.template.querySelector('[data-id="picker-assignment"]');
    if (assignmentPicker) {
      const blankAssignment = messages.some((msg) => msg.includes("Case Assignment"));
      assignmentPicker.setCustomValidity?.(
        blankAssignment ? "Case Assignment can't be blank" : ""
      );
      assignmentPicker.reportValidity?.();
    }

    [
      { id: "noc-new-prod-type", label: "Product Type" },
      { id: "noc-new-category", label: "Category" },
      { id: "noc-new-sub-category", label: "Sub-Category" },
    ].forEach(({ id, label }) => {
      const combo = this.template.querySelector(comboSel(id));
      if (!combo) {
        return;
      }
      const blank = messages.some((msg) => msg.includes(label));
      combo.setCustomValidity?.(blank ? `${label} can't be blank` : "");
      combo.reportValidity?.();
    });
  }

  handleUserNav(event) {
    event.preventDefault();
    if (!USER_ID) {
      return;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: USER_ID,
        objectApiName: "User",
        actionName: "view",
      },
    });
  }

  async navigateAfterSave(nocId) {
    const pageReference = {
      type: "standard__recordPage",
      attributes: {
        recordId: nocId,
        objectApiName: "FEC_Case_Assignment_NOC__c",
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
          /* ignore tab close failures */
        }
      }, 500);
      return;
    } catch (e) {
      /* fall through */
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
        recordId: nocId,
        focus: true,
      });

      setTimeout(async () => {
        try {
          if (tabToClose) {
            await closeTab(tabToClose);
          }
        } catch (err) {
          /* ignore tab close failures */
        }
      }, 500);
      return;
    }

    this[NavigationMixin.Navigate](pageReference);
  }

  /** Invalidate LDS parent; gọi lại sau ~700ms vì rollup NOC count có thể cập nhật trễ. */
  notifyParentAssignmentRecordChanged() {
    if (!this.assignmentRecordId) {
      return;
    }
    getRecordNotifyChange([{ recordId: this.assignmentRecordId }]);
    window.setTimeout(() => {
      getRecordNotifyChange([{ recordId: this.assignmentRecordId }]);
    }, 700);
  }

  /**
   * Sau tạo NOC: quay detail + notify LDS để fec_CaseAssignmentDetailSummary refresh related list.
   */
  async navigateToAssignmentDetailAfterCreate() {
    if (!this.assignmentRecordId) {
      return;
    }

    this.notifyParentAssignmentRecordChanged();

    const assignmentPageRef = {
      type: "standard__recordPage",
      attributes: {
        recordId: this.assignmentRecordId,
        objectApiName: "FEC_Case_Assignment__c",
        actionName: "view",
      },
    };

    let tabToClose = this.currentTabId;
    let parentTabId = null;
    const isConsole = this.isConsoleNavigation?.data === true;
    try {
      const focused = await getFocusedTabInfo();
      tabToClose = tabToClose || focused.tabId;
      if (focused.isSubtab && focused.parentTabId) {
        parentTabId = focused.parentTabId;
      }
    } catch (e) {
      /* ignore */
    }

    if (isConsole && parentTabId) {
      try {
        await openSubtab(parentTabId, {
          pageReference: assignmentPageRef,
          focus: true,
        });
      } catch (e) {
        this[NavigationMixin.Navigate](assignmentPageRef);
      }
    } else {
      this[NavigationMixin.Navigate](assignmentPageRef);
    }

    window.setTimeout(async () => {
      this.notifyParentAssignmentRecordChanged();

      try {
        if (isConsole) {
          let refreshTabId = parentTabId;
          if (!refreshTabId) {
            const focusedAfterNav = await getFocusedTabInfo();
            refreshTabId = focusedAfterNav.tabId;
          }
          if (refreshTabId) {
            await refreshTab(refreshTabId, { includeAllSubtabs: true });
          }
        } else {
          this.dispatchEvent(new RefreshEvent());
        }
      } catch (refreshErr) {
        this.dispatchEvent(new RefreshEvent());
      }

      try {
        if (tabToClose) {
          const focusedNow = await getFocusedTabInfo();
          if (focusedNow.tabId !== tabToClose) {
            await closeTab(tabToClose);
          }
        }
      } catch (closeErr) {
        /* ignore */
      }
    }, 600);
  }

  handleCancel() {
    if (this.isEditMode && this.nocRecordId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: this.nocRecordId,
          objectApiName: "FEC_Case_Assignment_NOC__c",
          actionName: "view",
        },
      });
      return;
    }
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
    this.clearPageErrors();
    const validationErrors = this.validateBeforeSave();
    if (validationErrors.length) {
      this.pageErrors = validationErrors;
      this.reportFieldValidity(validationErrors);
      return;
    }

    this.isSaving = true;
    try {
      const nocId = this.isEditMode
        ? await updateNoc({
            nocId: this.nocRecordId,
            productTypeId: this.selectedProductTypeId,
            categoryKey: this.selectedCategoryKey,
            subCategoryId: this.selectedSubCategoryId,
            subCodeId: this.selectedSubCodeId || null,
          })
        : await createNoc({
            assignmentId: this.assignmentRecordId,
            productTypeId: this.selectedProductTypeId,
            categoryKey: this.selectedCategoryKey,
            subCategoryId: this.selectedSubCategoryId,
            subCodeId: this.selectedSubCodeId || null,
          });
      this.showToast("Success", "Case Assignment NOC saved.", "success");
      if (this.assignmentRecordId && !this.isEditMode) {
        await this.navigateToAssignmentDetailAfterCreate();
        return;
      }
      if (this.assignmentRecordId) {
        this.notifyParentAssignmentRecordChanged();
        this.dispatchEvent(new RefreshEvent());
      }
      await this.navigateAfterSave(nocId);
    } catch (e) {
      const msg =
        e?.body?.pageErrors?.[0]?.message ||
        e?.body?.message ||
        e?.message ||
        "Could not save Case Assignment NOC.";
      this.pageErrors = [msg];
      this.showToast("Error", msg, "error");
    } finally {
      this.isSaving = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}