import { LightningElement, track, api, wire } from "lwc";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext,
  publish
} from "lightning/messageService";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import CASE_INFORMATION_EDIT from "@salesforce/messageChannel/FEC_Case_Information_Edit__c";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import getCase from "@salesforce/apex/FEC_CaseEditNOCController.getCase";
//PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
import getOriginalNOCFromFlowHistory from "@salesforce/apex/FEC_CaseEditNOCController.getOriginalNOCFromFlowHistory";
//HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
import PIN_RESET_CHANNEL from "@salesforce/messageChannel/FEC_PinReset__c";
//Thangtv update logic for Jira KH-1043: disable các NOC value after call api reissue pin
import PIN_REISSUE_MESSAGE_CHANNEL from "@salesforce/messageChannel/FEC_PinReissue__c";
// PhuongNT disable NOC after process action call api success
import PROCESS_ACTION_MESSAGE_CHANNEL from "@salesforce/messageChannel/FEC_ProcessAction__c";
// import getProductTypeIds from "@salesforce/apex/FEC_CaseEditNOCController.getProductTypeIds";
// import getCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getCategoryIds";
// import getSubCategoryIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCategoryIds";
// import getSubCodeIds from "@salesforce/apex/FEC_CaseEditNOCController.getSubCodeIds";

import getNatureOfCase from "@salesforce/apex/FEC_CaseEditNOCController.getNatureOfCase";
import getNatureOfCaseWithoutSubCode from "@salesforce/apex/FEC_CaseEditNOCController.getNatureOfCaseWithoutSubCode";
//PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
import hasAutoRoutingAssignment from "@salesforce/apex/FEC_CaseEditNOCController.hasAutoRoutingAssignment";

import getProductTypelst from "@salesforce/apex/FEC_CaseEditNOCController.getProductTypelst";
import getCategorylst from "@salesforce/apex/FEC_CaseEditNOCController.getCategorylst";
import getSubCategorylst from "@salesforce/apex/FEC_CaseEditNOCController.getSubCategorylst";
import getSubCodelst from "@salesforce/apex/FEC_CaseEditNOCController.getSubCodelst";
//HieuTT74-[UPDATE - 5/5/2026]: Lưu NOC sau khi call api Reset Pin,...
import saveNOC from "@salesforce/apex/FEC_CaseEditNOCController.saveNOC";
import saveCaseNOC from "@salesforce/apex/FEC_CaseBusinessService.saveCaseNOC";
//Toannd61
import clearCaseNOC from "@salesforce/apex/FEC_CaseEditNOCController.clearCaseNOC";
import getByCase from "@salesforce/apex/FEC_CaseBusinessService.getByCase";
import updateRoutingActionDisplayApex from "@salesforce/apex/FEC_CaseInitUpdateService.updateRoutingActionDisplay";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FEC_Tab_Nature_Of_Case from "@salesforce/label/c.FEC_Tab_Nature_Of_Case";

//HieuTT74 Cập nhật ngày  18-5-2026: Bổ sung message channel để disable các combobox khi call api tạo DNB
import DO_NOT_BOTHER_CHANNEL from "@salesforce/messageChannel/FEC_DoNotBother__c";
import { 
  ACTION_REOPEN, 
  ACTION_RECALL,
  // RECORD_TYPE_INTERNAL_CASE, 
  VIEW_MODE_HANDLING, 
  VIEW_MODE_REVIEW, 
  // STR_UNDEFINED, 
  INTERNAL_REQUEST, 
  INTERNAL_UBANK,
  //linhdev fix jira FECREDIT_CSM_2025_KH-1366
  FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX,
  FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX,
  FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX,
  FEC_FAST_CASH_STORAGE_BLK_FAIL_PREFIX,
  FEC_FAST_CASH_STORAGE_BLK_OK_PREFIX,
  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  FEC_POINTS_REDEMPTION_STORAGE_NOC_LOCK_PREFIX,
  FEC_POINTS_REDEMPTION_STORAGE_MODAL_CONFIRMED_PREFIX,
  FEC_POINTS_REDEMPTION_STORAGE_NOC_SELECTION_PREFIX
} from "c/fec_CommonConst";
import resetViewMode from "@salesforce/apex/FEC_InteractionInforHandler.resetViewMode";

export default class Fec_CaseEditNOC extends LightningElement {
  @api recordId;
  @api modeEditCase;

  @track isSubmited = true;
  _isInternalRequest = false;
  _internalProductTypeId = null;
  _internalApplied = false;
  
  //HieuTT74-[UPDATE - 5/5/2026]: Lưu NOC sau khi call api Reset Pin,...
  isDisableNOC = false;
  _lastPersistedNatureOfCaseId = null;

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366
  @track isNocLockedAfterFastCashBlock = false;
  _fastCashLockCombosApplied = false;
  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — RC33: khóa NOC sau Có/Không pop-up Redeem Points
  @track isNocLockedAfterPointsRedemption = false;
  _pointsRedemptionLockCombosApplied = false;

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  get isNocNatureLocked() {
    return this.isNocLockedAfterFastCashBlock === true || this.isNocLockedAfterPointsRedemption === true;
  }

  //PhongBT: update bộ noc chọn ở updated khi revert về
  _currentStageName = null;
  /** FEC_Actual_Nature_of_Case__r.FEC_Business_Process__r.FEC_Code__c */
  _actualBusinessProcessCode = null;
  /** contextFlags từ FEC_CaseBusinessService.getByCase (đồng bộ qua CASE_NOC). */
  _caseBusinessContextFlags = {};

  /** Partial edit Case Information sau Execute Assignment (FEC_Case_Information_Edit__c). */
  _isCaseInformationEdit = false;

  //PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
  updatedCategoryId;       // Category đã chọn trong Updated section
  updatedSubCategoryId;    // Sub-Category đã chọn trong Updated section
  updatedSubCodeId;        // Sub-Code đã chọn trong Updated section
  @track updatedNocDisplayNames = {};
  hasAutoRoutingAssignment = false; // true → ẩn Updated section (có Routing Assignment)
  _selectedNocDisplayNames = {};
  //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
  @track originalNOC = null;
  originalNOCBusinessProcessCode;

  //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
  get originalNOCFields() {
    if (!this.originalNOC) return [];
    return [
      { key: 'productType',  label: 'Product Type',  value: this.originalNOC.productType  || '-' },
      { key: 'category',     label: 'Category',      value: this.originalNOC.category     || '-' },
      { key: 'subCategory',  label: 'Sub-Category',  value: this.originalNOC.subCategory  || '-' },
      { key: 'subCode',      label: 'Sub-Code',      value: this.originalNOC.subCode      || '-' }
    ];
  }

  get isSubmittedState() {
    console.log('issubmited ' + this.isSubmited);
    console.log('showUpdatedSection ' + this.showUpdatedSection);
    return this.isSubmited === true && this.showUpdatedSection;
  }

  //PhongBT: update bộ noc chọn ở updated khi revert về
  get _isStage1() {
    return (this._currentStageName || '').includes('Stage 1');
  }

  /** GSR (Actual NOC) + Revert/Recall về Stage 1: cho phép sửa Updated NOC khi bật mode edit Case. */
  _isGsrStage1RevertEditable() {
    const actualBp = (this._actualBusinessProcessCode || '').toUpperCase();
    if (!actualBp.includes('GSR') || !this._isStage1) {
      return false;
    }
    const flags = this._caseBusinessContextFlags;
    return (
      flags?.isGsrStage1Revert === true || flags?.isGsrStage1Recall === true
    );
  }

  /** GSR (Actual NOC) + Revert Stage 2 → Stage 1: cho phép sửa Updated NOC khi bật mode edit Case. */
  _isGsrStage2ToStage1RevertEditable() {
    const actualBp = (this._actualBusinessProcessCode || '').toUpperCase();
    if (!actualBp.includes('GSR') || !this._isStage1) {
      return false;
    }
    return this._caseBusinessContextFlags?.isGsrStage2ToStage1Revert === true;
  }

  // Sau submit (Submitted + Updated section): chỉ cho sửa khi user bật lại mode edit Case.
  // Không dùng interactionViewMode === handling — sau submit field Case có thể chưa kịp review
  // nên vẫn là handling và Updated NOC bị editable tới khi reload; chỉ còn modeEditCase là đúng UX.
  get _canEditCaseInformationNoc() {
    return this.modeEditCase === true || this._isCaseInformationEdit === true;
  }

  get isUpdatedSectionEditable() {
    if (!this.isSubmittedState) {
      return false;
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return false;
    }
    // GSR Revert Stage 2 → Stage 1: cho phép edit Updated NOC (Actual NOC chứa GSR).
    if (this._isGsrStage2ToStage1RevertEditable()) {
      return this.modeEditCase === true;
    }
    // GSR Revert về Stage 1: cho phép edit Updated NOC (Actual NOC chứa GSR).
    if (this._isGsrStage1RevertEditable()) {
      return this._canEditCaseInformationNoc;
    }
    // Stage 1 → readonly Updated NOC (COF / GSR revert từ stage khác)
    if (this._isStage1) return false;
    //PhongBT 15/06/26: Có Routing Assignment (hasAutoRoutingAssignment) → không cho edit Updated NOC
    if (this.hasAutoRoutingAssignment) return false;
    return this._canEditCaseInformationNoc;
  }

  get showUpdatedSection() {
    const bpCode = (
      this._actualBusinessProcessCode ||
      this.originalNOCBusinessProcessCode ||
      ""
    ).toUpperCase();
    const isGsrOrCof = bpCode.includes("GSR") || bpCode.includes("COF");
    console.log('bpCode ' + bpCode);
    console.log('isGsrOrCof ' + isGsrOrCof);
    console.log('hasAutoRoutingAssignment ' + this.hasAutoRoutingAssignment);
    return this.isSubmited === true 
    // && !this.hasAutoRoutingAssignment 
    && isGsrOrCof;
  }

  get serializedProductTypeOptions() {
    return JSON.stringify(this.productTypeOptionlst ?? []);
  }

  get serializedCategoryOptions() {
    return JSON.stringify(this.categoryOptionlst ?? []);
  }

  get serializedSubCategoryOptions() {
    return JSON.stringify(this.subCategoryOptionlst ?? []);
  }

  get serializedSubCodeOptions() {
    return JSON.stringify(this.subCodeOptionlst ?? []);
  }

  get updatedNocProductTypeName() {
    return this.updatedNocDisplayNames?.productType ?? null;
  }

  get updatedNocCategoryName() {
    return this.updatedNocDisplayNames?.category ?? null;
  }

  get updatedNocSubCategoryName() {
    return this.updatedNocDisplayNames?.subCategory ?? null;
  }

  get updatedNocSubCodeName() {
    return this.updatedNocDisplayNames?.subCode ?? null;
  }

  _setUpdatedNocDisplayNamesFromCase(caseRecord) {
    if (!caseRecord) {
      this.updatedNocDisplayNames = {};
      return;
    }
    this.updatedNocDisplayNames = {
      productType: caseRecord.FEC_Product_Type__r?.Name ?? null,
      category: caseRecord.FEC_Category__r?.Name ?? null,
      subCategory: caseRecord.FEC_SubCategory__r?.Name ?? null,
      subCode: caseRecord.FEC_SubCode__r?.Name ?? null,
    };
  }

  _setSelectedNocDisplayNamesFromCase(caseRecord) {
    this._selectedNocDisplayNames = {
      productType: caseRecord?.FEC_Product_Type__r?.Name ?? null,
      category: caseRecord?.FEC_Category__r?.Name ?? null,
      subCategory: caseRecord?.FEC_SubCategory__r?.Name ?? null,
      subCode: caseRecord?.FEC_SubCode__r?.Name ?? null,
    };
  }

  //PhongBT 02/06/26: Vẫn hiển thị Name cho user không có phân quyền xem noc: bổ sung option hiện tại theo Name lấy từ Case khi list option bị filter theo user group.
  _ensureSelectedOptionLabel(options, selectedId, selectedName) {
    const normalizedOptions = Array.isArray(options) ? [...options] : [];
    if (!selectedId) {
      return normalizedOptions;
    }
    const hasSelected = normalizedOptions.some((opt) => opt?.value === selectedId);
    if (hasSelected || !selectedName) {
      return normalizedOptions;
    }
    return [{ label: selectedName, value: selectedId }, ...normalizedOptions];
  }

  get isEdit() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — sau pop-up Block Amount: reload vẫn giữ combo disable, không chuyển output-field Case (resetViewMode → review)
    if (this.isNocNatureLocked && !this.isSubmited) {
      return true;
    }
    const defaultEdit = (this.modeEditCase || this.interactionViewMode === VIEW_MODE_HANDLING) ? true : false;
    return defaultEdit && !this.isSubmited;
  }

  get natureOfCaseLabel() {
    return FEC_Tab_Nature_Of_Case;
  }

  @wire(MessageContext)
  messageContext;

  @track productTypeFilter = {
    criteria: []
  };
  @track categoryFilter = {
    criteria: []
  };
  @track subCategoryFilter = {
    criteria: []
  };
  @track subCodeFilter = {
    criteria: []
  };

  subscription = null;
  subscriptionNOC = null;
  _nocResolveEpoch = 0;
  subscriptionResetPin = null;
  subscriptionPinReissue = null;
  subscriptionDoNotBother = null;
  activeSection = ["noc"];
  productTypeSelectedId;
  categorySelectedId;
  subCategorySelectedId;
  subCodeSelectedId;
  natureOfCase;

  disableProdType;
  @track interactionViewMode;
  recordTypeDevName;

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — RC35: sau pop-up Block Amount khóa 3 combo Category / Sub-Category / Sub-Code
  get disableCategory() {
    return this.isNocNatureLocked || !this.productTypeSelectedId;
  }
  get disableSubCategory() {
    return this.isNocNatureLocked || !this.categorySelectedId;
  }
  get disableSubCode() {
    return this.isNocNatureLocked || !this.subCategorySelectedId;
  }

  @track productTypeOptionlst = [];
  @track categoryOptionlst = [];
  @track subCategoryOptionlst = [];
  @track subCodeOptionlst = [];

  get formattedProductTypeOption() {
    return JSON.stringify(this.productTypeOptionlst);
  }

  get formattedCategoryOption() {
    return JSON.stringify(this.categoryOptionlst);
  }

  get formattedSubCategoryOption() {
    return JSON.stringify(this.subCategoryOptionlst);
  }

  get formattedSubCodeOption() {
    return JSON.stringify(this.subCodeOptionlst);
  }

  renderedCallback() {
    if (this._internalProductTypeId && !this._internalApplied) {
      const el = this.template.querySelector(`c-fec_-combo-box[data-id="prod-type"]`);
      if (el) {
        el.value = this._internalProductTypeId;
        el.disabled = true;
        this._internalApplied = true;
      }
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — đồng bộ lock từ sessionStorage (fec_FastCashCaseForm là sibling trên flexipage)
    if (!this.isNocLockedAfterFastCashBlock) {
      this._restoreFastCashNocLockFromStorage();
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    this._releaseFastCashNocLockIfStale();
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    if (!this.isNocLockedAfterPointsRedemption) {
      this._restorePointsRedemptionNocLockFromStorage();
    }
    this._applyPointsRedemptionNocSelectionFromStorage();
    this._applyFastCashRc35PartialLockCombos();
    this._applyPointsRedemptionNocLockCombos();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — RC35: chỉ disable Category / Sub-Category / Sub-Code sau pop-up Block Amount
  _applyFastCashRc35PartialLockCombos() {
    if (
      !this.isNocLockedAfterFastCashBlock ||
      this.isSubmittedState ||
      this._fastCashLockCombosApplied
    ) {
      return;
    }
    const cat = this.template.querySelector(`c-fec_-combo-box[data-id="category"]`);
    if (!cat) {
      return;
    }
    ["category", "sub-category", "sub-code"].forEach((id) => {
      this.handleDisableResetPinSuccess(id);
    });
    this._fastCashLockCombosApplied = true;
  }

  _isFastCashBlockModalConfirmedInStorage() {
    try {
      if (!this.recordId) {
        return false;
      }
      return sessionStorage.getItem(FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId) === "1";
    } catch (e) {
      return false;
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  _isPointsRedemptionModalConfirmedInStorage() {
    try {
      if (!this.recordId) {
        return false;
      }
      return sessionStorage.getItem(FEC_POINTS_REDEMPTION_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId) === "1";
    } catch (e) {
      return false;
    }
  }

  _readPointsRedemptionNocSelectionFromStorage() {
    try {
      if (!this.recordId) {
        return null;
      }
      const raw = sessionStorage.getItem(FEC_POINTS_REDEMPTION_STORAGE_NOC_SELECTION_PREFIX + this.recordId);
      if (!raw) {
        return null;
      }
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  _applyPointsRedemptionNocSelectionFromStorage() {
    if (!this.isNocLockedAfterPointsRedemption) {
      return;
    }
    const sel = this._readPointsRedemptionNocSelectionFromStorage();
    if (!sel || !this._isNocSelectionComplete(sel)) {
      return;
    }
    if (sel.productTypeId) {
      this.productTypeSelectedId = sel.productTypeId;
      this.disableProdType = true;
    }
    if (sel.categoryId) {
      this.categorySelectedId = sel.categoryId;
    }
    if (sel.subCategoryId) {
      this.subCategorySelectedId = sel.subCategoryId;
    }
    if (sel.subCodeId) {
      this.subCodeSelectedId = sel.subCodeId;
    }
  }

  _syncPublishedNocToCaseBusinessIfComplete() {
    if (
      !this._isNocSelectionComplete({
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId,
        subCategoryId: this.subCategorySelectedId,
        subCodeId: this.subCodeSelectedId
      })
    ) {
      return;
    }
    if (!this.messageContext) {
      return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    Promise.resolve().then(() => {
      this.handlePublishMessageChanel();
    });
  }

  /** Case draft: reload trang → xóa NOC DB + UI; đã submit / sau API success → giữ nguyên. 
   * Toannd61
   */
  _shouldClearNocOnPageLoad(caseRecord) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — RC33 đang xử lý (session): không xóa NOC khi reload sau Execute
    if (this._isPointsRedemptionModalConfirmedInStorage()) {
      return false;
    }
    return (
      caseRecord &&
      caseRecord.FEC_Is_Submited__c !== true &&
      caseRecord.FEC_Is_Call_API_Success__c !== true
    );
  }

  _stripNocFieldsOnCaseRecord(caseRecord) {
    caseRecord.FEC_Category__c = null;
    caseRecord.FEC_SubCategory__c = null;
    caseRecord.FEC_SubCode__c = null;
    return caseRecord;
  }

  _resetNocUiState(preservedProductTypeId) {
    this.productTypeSelectedId = preservedProductTypeId || null;
    this.categorySelectedId = null;
    this.subCategorySelectedId = null;
    this.subCodeSelectedId = null;
    this.natureOfCase = null;
    this.disableProdType = !!preservedProductTypeId;
    this._lastPersistedNatureOfCaseId = null;
    this.categoryOptionlst = [];
    this.subCategoryOptionlst = [];
    this.subCodeOptionlst = [];

    ["category", "sub-category", "sub-code"].forEach((id) => {
      const el = this.template.querySelector(`c-fec_-combo-box[data-id="${id}"]`);
      if (el && typeof el.clear === "function") {
        el.clear();
      }
    });
    if (!preservedProductTypeId) {
      const prodEl = this.template.querySelector(`c-fec_-combo-box[data-id="prod-type"]`);
      if (prodEl && typeof prodEl.clear === "function") {
        prodEl.clear();
      }
    }
    this.handleDisable("category");
    this.handleDisable("sub-category");
    this.handleDisable("sub-code");
    if (preservedProductTypeId) {
      this.handleEnable("category");
    }
  }

  _publishEmptyNocMessage(preservedProductTypeId) {
    if (!this.messageContext) {
      return;
    }
    publish(this.messageContext, CASE_NOC, {
      caseId: this.recordId,
      productTypeId: preservedProductTypeId || null,
      categoryId: null,
      subCategoryId: null,
      subCodeId: null,
      natureOfCaseId: null,
      nocClearedOnPageLoad: true
    });
  }

  async _clearNocOnPageLoad(caseRecord) {
    const preservedProductTypeId = caseRecord?.FEC_Product_Type__c ?? null;
    this._clearFastCashBlockSessionStorage();
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    this._clearPointsRedemptionSessionStorage();
    this._clearSubProcessNocSessionStorage();
    await clearCaseNOC({ recordId: this.recordId });
    this.isNocLockedAfterFastCashBlock = false;
    this._fastCashLockCombosApplied = false;
    this.isNocLockedAfterPointsRedemption = false;
    this._pointsRedemptionLockCombosApplied = false;
    this._resetNocUiState(preservedProductTypeId);
    this._publishEmptyNocMessage(preservedProductTypeId);
  }

  async connectedCallback() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — phục hồi lock trước resetViewMode để isEdit không rơi output-field khi reload
    this._restoreFastCashNocLockFromStorage();
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    this._restorePointsRedemptionNocLockFromStorage();
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — sau Có/Không Block Amount: giữ handling, không ép review
    if (this._isFastCashBlockModalConfirmedInStorage()) {
      await resetViewMode({
        recordId: this.recordId,
        viewMode: VIEW_MODE_HANDLING,
      });
    } else if (this._isPointsRedemptionModalConfirmedInStorage()) {
      //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
      await resetViewMode({
        recordId: this.recordId,
        viewMode: VIEW_MODE_HANDLING,
      });
    } else {
      await resetViewMode({
        recordId: this.recordId,
        viewMode: VIEW_MODE_REVIEW,
      });
    }
    this.subscribeToMessageChannel();
    
    getCase({ recordId: this.recordId })
    /** Toannd61: clear NOC on page load */
      .then(async (res) => {
        let nocClearedOnLoad = false;
        if (this._shouldClearNocOnPageLoad(res)) {
          try {
            await this._clearNocOnPageLoad(res);
            res = this._stripNocFieldsOnCaseRecord(res);
            nocClearedOnLoad = true;
          } catch (err) {
            console.error("clearCaseNOC on page load failed:", err);
          }
        }

        if (!nocClearedOnLoad) {
          this.productTypeSelectedId = res.FEC_Product_Type__c;
          this.disableProdType = !!this.productTypeSelectedId;

          this.categorySelectedId = res.FEC_Category__c;

          this.subCategorySelectedId = res.FEC_SubCategory__c;

          this.subCodeSelectedId = res.FEC_SubCode__c;
          //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — NOC chọn trên UI chưa ghi Case: overlay từ session sau Có/Không
          this._applyFastCashNocSelectionFromStorage();
          //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
          this._applyPointsRedemptionNocSelectionFromStorage();
        } else {
          this.disableProdType = !!this.productTypeSelectedId;
          this._applyPointsRedemptionNocSelectionFromStorage();
        }
        this._setSelectedNocDisplayNamesFromCase(res);

        this.isSubmited = res.FEC_Is_Submited__c;
        this.interactionViewMode = res.FEC_Interaction_View_Mode__c;
        this.recordTypeDevName = res.RecordType?.DeveloperName;
        this._isInternalRequest = res.FEC_Account_Contract_Number_PL__c === INTERNAL_REQUEST;
        this.isDisableNOC = res.FEC_Is_Call_API_Success__c;
        //PhongBT: update bộ noc chọn ở updated khi revert về
        this._currentStageName = res.FEC_Current_Case_Stage__r?.Name || null;
        this._actualBusinessProcessCode =
          res.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c || null;
        this.getProdType();
        this.getCategory();
        this.getSubCategory();
        this.getSubCode();

         // 👉 FIX: đặt ở đây
        if (this.isDisableNOC) {
          this.handleDisableResetPinSuccess("category");
          this.handleDisableResetPinSuccess("sub-category");
          this.handleDisableResetPinSuccess("sub-code");
        }

        //linhdev fix jira FECREDIT_CSM_2025_KH-1366
        this._restoreFastCashNocLockFromStorage();
        this._releaseFastCashNocLockIfStale();
        //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
        this._restorePointsRedemptionNocLockFromStorage();

        //PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
        // [NOC-HANDLING-STAGE-UPDATE]: Khi đã submit, kiểm tra Auto-Routing Assignment
        // và pre-populate Updated section với giá trị hiện tại của Case
        if (res.FEC_Is_Submited__c) {
          // Pre-populate Updated section với giá trị NOC hiện tại
          this.updatedCategoryId = res.FEC_Category__c;
          this.updatedSubCategoryId = res.FEC_SubCategory__c;
          this.updatedSubCodeId = res.FEC_SubCode__c;
          this._setUpdatedNocDisplayNamesFromCase(res);

          // Kiểm tra có Routing Assignment không — nếu có thì ẩn Updated section
          hasAutoRoutingAssignment({ caseId: this.recordId })
            .then((result) => {
              this.hasAutoRoutingAssignment = result === true;
            })
            .catch((err) => {
              // Default false để không ẩn Updated section một cách sai lầm
              console.error("hasAutoRoutingAssignment error:", err);
              this.hasAutoRoutingAssignment = false;
            });

          //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
          getOriginalNOCFromFlowHistory({ caseId: this.recordId })
            .then((nocData) => {
              this.originalNOC = nocData || null;
              this.originalNOCBusinessProcessCode = nocData?.businessProcessCode || null;
            })
            .catch((err) => {
              console.error("getOriginalNOCFromFlowHistory error:", err);
              this.originalNOC = null;
              this.originalNOCBusinessProcessCode = null;
            });
        }

        getByCase({
          caseId: this.recordId,
          productTypeId: this.productTypeSelectedId,
          categoryId: this.categorySelectedId,
          subCategoryId: this.subCategorySelectedId,
          subCodeId: this.subCodeSelectedId,
        })
          .then((res) => {
            if (!res) return;
            this._caseBusinessContextFlags = res.contextFlags || {};

            let business = { ...res };
            const actions = business.routingActionlst || [];
            const foundActions = [];

            if (actions.some((a) => a.value === ACTION_REOPEN))
              foundActions.push(ACTION_REOPEN);
            if (actions.some((a) => a.value === ACTION_RECALL))
              foundActions.push(ACTION_RECALL);

            this.updateRoutingActionDisplay(
              foundActions.length > 0 ? foundActions.join(";") : ""
            );
          });
        //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474 — đồng bộ Case Information khi NOC đủ (fec_CaseBussiness có thể getData trước khi NOC sẵn sàng)
        this._syncPublishedNocToCaseBusinessIfComplete();
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ connectedCallback ~ err:", err);
      });
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — RC35 cần đủ Product Type + Category + Sub-Category trước khi coi lock hợp lệ
  _isFastCashNocSelectionComplete(sel) {
    return !!(sel && sel.productTypeId && sel.categoryId && sel.subCategoryId);
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366
  _clearFastCashBlockSessionStorage() {
    try {
      if (!this.recordId) {
        return;
      }
      sessionStorage.removeItem(FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId);
      sessionStorage.removeItem(FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX + this.recordId);
      sessionStorage.removeItem(FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX + this.recordId);
      sessionStorage.removeItem(FEC_FAST_CASH_STORAGE_BLK_FAIL_PREFIX + this.recordId);
      sessionStorage.removeItem(FEC_FAST_CASH_STORAGE_BLK_OK_PREFIX + this.recordId);
    } catch (e) {
      /* ignore */
    }
  }

  _clearSubProcessNocSessionStorage() {
    try {
      if (!this.recordId) {
        return;
      }
      sessionStorage.removeItem("fec_case_noc_" + this.recordId);
    } catch (e) {
      /* ignore */
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — session cũ (chỉ Card, chưa RC35): bỏ lock để chọn lại NOC
  _releaseFastCashNocLockIfStale() {
    if (!this.isNocLockedAfterFastCashBlock) {
      return;
    }
    const sel = this._readFastCashNocSelectionFromStorage();
    if (this._isFastCashNocSelectionComplete(sel)) {
      return;
    }
    this._clearFastCashBlockSessionStorage();
    this.isNocLockedAfterFastCashBlock = false;
    this._fastCashLockCombosApplied = false;
    if (this.productTypeSelectedId) {
      this.handleEnable("category");
    }
    if (this.categorySelectedId) {
      this.handleEnable("sub-category");
    }
    if (this.subCategorySelectedId) {
      this.handleEnable("sub-code");
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366
  _restoreFastCashNocLockFromStorage() {
    try {
      if (!this.recordId) {
        return;
      }
      const modalKey = FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId;
      if (sessionStorage.getItem(modalKey) !== "1") {
        return;
      }
      const k = FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX + this.recordId;
      if (sessionStorage.getItem(k) === "1") {
        this.isNocLockedAfterFastCashBlock = true;
        this._fastCashLockCombosApplied = false;
      }
    } catch (e) {
      /* ignore */
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — lưu bộ NOC đang chọn (chưa submit Case) để reload không mất Case Information / Fast Cash
  _saveFastCashNocSelectionToStorage() {
    try {
      if (!this.recordId) {
        return;
      }
      sessionStorage.setItem(
        FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX + this.recordId,
        JSON.stringify({
          productTypeId: this.productTypeSelectedId || null,
          categoryId: this.categorySelectedId || null,
          subCategoryId: this.subCategorySelectedId || null,
          subCodeId: this.subCodeSelectedId || null
        })
      );
    } catch (e) {
      /* ignore */
    }
  }

  _readFastCashNocSelectionFromStorage() {
    try {
      if (!this.recordId) {
        return null;
      }
      const modalKey = FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId;
      if (sessionStorage.getItem(modalKey) !== "1") {
        return null;
      }
      const raw = sessionStorage.getItem(FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX + this.recordId);
      if (!raw) {
        return null;
      }
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  _applyFastCashNocSelectionFromStorage() {
    const sel = this._readFastCashNocSelectionFromStorage();
    if (!sel || !this.isNocLockedAfterFastCashBlock) {
      return;
    }
    if (sel.productTypeId) {
      this.productTypeSelectedId = sel.productTypeId;
      this.disableProdType = true;
    }
    if (sel.categoryId) {
      this.categorySelectedId = sel.categoryId;
    }
    if (sel.subCategoryId) {
      this.subCategorySelectedId = sel.subCategoryId;
    }
    if (sel.subCodeId !== undefined) {
      this.subCodeSelectedId = sel.subCodeId;
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1366
  @api
  applyFastCashBlockNocLock() {
    const pendingSel = {
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId,
      subCategoryId: this.subCategorySelectedId,
      subCodeId: this.subCodeSelectedId
    };
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — chưa chọn đủ RC35 thì không khóa (tránh execute lại kẹt disable)
    if (!this._isFastCashNocSelectionComplete(pendingSel)) {
      return;
    }
    this.isNocLockedAfterFastCashBlock = true;
    this._fastCashLockCombosApplied = false;
    try {
      if (this.recordId) {
        sessionStorage.setItem(FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId, "1");
        sessionStorage.setItem(FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX + this.recordId, "1");
        this._saveFastCashNocSelectionToStorage();
      }
    } catch (e) {
      /* ignore */
    }
    this._applyFastCashRc35PartialLockCombos();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  _clearPointsRedemptionSessionStorage() {
    try {
      if (!this.recordId) {
        return;
      }
      sessionStorage.removeItem(FEC_POINTS_REDEMPTION_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId);
      sessionStorage.removeItem(FEC_POINTS_REDEMPTION_STORAGE_NOC_LOCK_PREFIX + this.recordId);
      sessionStorage.removeItem(FEC_POINTS_REDEMPTION_STORAGE_NOC_SELECTION_PREFIX + this.recordId);
    } catch (e) {
      /* ignore */
    }
  }

  _isNocSelectionComplete(sel) {
    return !!(
      sel &&
      sel.productTypeId &&
      sel.categoryId &&
      sel.subCategoryId &&
      sel.subCodeId
    );
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  _savePointsRedemptionNocSelectionToStorage() {
    try {
      if (!this.recordId) {
        return;
      }
      sessionStorage.setItem(
        FEC_POINTS_REDEMPTION_STORAGE_NOC_SELECTION_PREFIX + this.recordId,
        JSON.stringify({
          productTypeId: this.productTypeSelectedId || null,
          categoryId: this.categorySelectedId || null,
          subCategoryId: this.subCategorySelectedId || null,
          subCodeId: this.subCodeSelectedId || null
        })
      );
    } catch (e) {
      /* ignore */
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  _restorePointsRedemptionNocLockFromStorage() {
    try {
      if (!this.recordId) {
        return;
      }
      const modalKey = FEC_POINTS_REDEMPTION_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId;
      if (sessionStorage.getItem(modalKey) !== "1") {
        return;
      }
      const k = FEC_POINTS_REDEMPTION_STORAGE_NOC_LOCK_PREFIX + this.recordId;
      if (sessionStorage.getItem(k) === "1") {
        this.isNocLockedAfterPointsRedemption = true;
        this._pointsRedemptionLockCombosApplied = false;
      }
    } catch (e) {
      /* ignore */
    }
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  @api
  applyPointsRedemptionNocLock() {
    const pendingSel = {
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId,
      subCategoryId: this.subCategorySelectedId,
      subCodeId: this.subCodeSelectedId
    };
    if (!this._isNocSelectionComplete(pendingSel)) {
      return;
    }
    this.isNocLockedAfterPointsRedemption = true;
    this._pointsRedemptionLockCombosApplied = false;
    try {
      if (this.recordId) {
        sessionStorage.setItem(FEC_POINTS_REDEMPTION_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId, "1");
        sessionStorage.setItem(FEC_POINTS_REDEMPTION_STORAGE_NOC_LOCK_PREFIX + this.recordId, "1");
        this._savePointsRedemptionNocSelectionToStorage();
      }
    } catch (e) {
      /* ignore */
    }
    this._applyPointsRedemptionNocSelectionFromStorage();
    this._applyPointsRedemptionNocLockCombos();
  }

  //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
  _applyPointsRedemptionNocLockCombos() {
    if (
      !this.isNocLockedAfterPointsRedemption ||
      this.isSubmittedState ||
      this._pointsRedemptionLockCombosApplied
    ) {
      return;
    }
    const prod = this.template.querySelector(`c-fec_-combo-box[data-id="prod-type"]`);
    if (!prod) {
      return;
    }
    ["prod-type", "category", "sub-category", "sub-code"].forEach((id) => {
      this.handleDisableResetPinSuccess(id);
    });
    this.disableProdType = true;
    this._pointsRedemptionLockCombosApplied = true;
  }

  updateRoutingActionDisplay(field) {
    updateRoutingActionDisplayApex({
      caseId: this.recordId,
      routingActionDisplay: field
    })
      .then(() => {
        console.log("Record updated successfully");
      })
      .catch((error) => {
        console.error("Error updating record:", error);
      });
  }

  disconnectedCallback() {
    unsubscribe(this.subscription);
    this.subscription = null;

    unsubscribe(this.subscriptionNOC);
    this.subscriptionNOC = null;

    unsubscribe(this.subscriptionCaseInformationEdit);
    this.subscriptionCaseInformationEdit = null;

    //HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
    unsubscribe(this.subscriptionResetPin);
    this.subscriptionResetPin = null;

    //HieuTT74 Cập nhật ngày  17-5-2026: Bổ sung message channel để disable các combobox khi call api tạo DNB thành công
    unsubscribe(this.subscriptionDoNotBother);
    this.subscriptionDoNotBother = null;

    this.modeEditCase = false;
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      IS_MODE_EDIT,
      (message) => this.handleMessage(message),
      { scope: APPLICATION_SCOPE }
    );

    this.subscriptionNOC = subscribe(
      this.messageContext,
      CASE_NOC,
      (message) => this.handleCaseNOCMessage(message),
      { scope: APPLICATION_SCOPE }
    );

    this.subscriptionCaseInformationEdit = subscribe(
      this.messageContext,
      CASE_INFORMATION_EDIT,
      (message) => this.handleCaseInformationEditMessage(message),
      { scope: APPLICATION_SCOPE }
    );

    //HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
    this.subscriptionResetPin = subscribe(
      this.messageContext,
      PIN_RESET_CHANNEL,
      (message) => this.handleMessageResetPin(message),
      { scope: APPLICATION_SCOPE },
    );
    //Thangtv update logic for Jira KH-1043: disable các NOC value after call api reissue pin
    this.subscriptionPinReissue = subscribe(
      this.messageContext,
      PIN_REISSUE_MESSAGE_CHANNEL,
      (message) => this.handleMessageResetPin(message),
      { scope: APPLICATION_SCOPE },
    );
    // PhuongNT disable NOC after process action call api success
    this.subscriptionPinReissue = subscribe(
      this.messageContext,
      PROCESS_ACTION_MESSAGE_CHANNEL,
      (message) => this.handleMessageResetPin(message),
      { scope: APPLICATION_SCOPE },
    );

    //HieuTT74 Cập nhật ngày  17-5-2026: Bổ sung message channel để disable các combobox khi call api tạo DNB thành công
    this.subscriptionDoNotBother = subscribe(
      this.messageContext,
      DO_NOT_BOTHER_CHANNEL,
      (message) => this.handleMessageDoNotBother(message),
      { scope: APPLICATION_SCOPE }
    );
    
  }

  handleCaseInformationEditMessage(message) {
    if (message == null || typeof message.isCaseInformationEdit === "undefined") {
      return;
    }
    if (message.caseId != null && message.caseId !== this.recordId) {
      return;
    }
    this._isCaseInformationEdit = message.isCaseInformationEdit === true;
  }

  handleCaseNOCMessage(message) {
    if (message.caseId != null && message.caseId !== this.recordId) {
      return;
    }
    if (message.contextFlagsSync === true && message.contextFlags) {
      this._caseBusinessContextFlags = message.contextFlags;
      return;
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — khóa NOC ngay khi Có/Không pop-up Block Amount
    if (message.fastCashNocLocked === true) {
      this.applyFastCashBlockNocLock();
      return;
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1469-1474
    if (message.pointsRedemptionNocLocked === true) {
      this.applyPointsRedemptionNocLock();
      return;
    }
    if (!Object.prototype.hasOwnProperty.call(message, 'accountType')) return;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }

    const accountType = message.accountType;
    const isInternalType = accountType === INTERNAL_REQUEST || accountType === INTERNAL_UBANK;
    const hasExistingNOCSelection =
      !!this.productTypeSelectedId ||
      !!this.categorySelectedId ||
      !!this.subCategorySelectedId ||
      !!this.subCodeSelectedId;

    if (this._incomingAccountType == null && hasExistingNOCSelection && !isInternalType) {
      this._incomingAccountType = accountType;
      return;
    }

    if (this._incomingAccountType === accountType) {
      return;
    }

    this._incomingAccountType = accountType;
    this._isInternalRequest = false;
    this.disableProdType = false;
    this._internalProductTypeId = null;
    this._internalApplied = false;

    this.productTypeSelectedId = null;
    this.categorySelectedId = null;
    this.subCategorySelectedId = null;
    this.subCodeSelectedId = null;

    this.categoryOptionlst = [];
    this.subCategoryOptionlst = [];
    this.subCodeOptionlst = [];

    this.natureOfCase = null;

    ['prod-type', 'category', 'sub-category', 'sub-code'].forEach(id => {
      const el = this.template.querySelector(`c-fec_-combo-box[data-id="${id}"]`);
      if (el) el.clear();
    });

    if (isInternalType) {
      this._isInternalRequest = accountType === INTERNAL_REQUEST;

      const option = this.productTypeOptionlst?.find(
        (opt) => opt.label === accountType
      );

      if (option) {
        setTimeout(() => {
          this.productTypeSelectedId = option.value;
          this.disableProdType = true;
          this._internalProductTypeId = option.value;
          this._internalApplied = false;

          const categoryEl = this.template.querySelector(`c-fec_-combo-box[data-id="category"]`);
          if (categoryEl) categoryEl.disabled = false;

          this.getCategory();
        }, 50);
      }
    } else {
      this.handleDisable('category');
      this.handleDisable('sub-category');
      this.handleDisable('sub-code');
    }
  }

  handleMessageResetPin(message) {
    this.handleDisableResetPinSuccess("category");
    this.handleDisableResetPinSuccess("sub-category");
    this.handleDisableResetPinSuccess("sub-code");

    saveNOC({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId,
        subCategoryId: this.subCategorySelectedId,
        subCodeId: this.subCodeSelectedId
    })
    .then(() => {
        console.log('Save NOC success');
    })
    .catch(error => {
        console.error('Save NOC failed:', error);
    });
  }

  //HieuTT74 Cập nhật ngày  17-5-2026: Bổ sung message channel để disable các combobox khi call api tạo DNB thành công
  handleMessageDoNotBother(message) {
    this.handleDisableResetPinSuccess("category");
    this.handleDisableResetPinSuccess("sub-category");
    this.handleDisableResetPinSuccess("sub-code");

    saveNOC({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId,
        subCategoryId: this.subCategorySelectedId,
        subCodeId: this.subCodeSelectedId
    })
    .then(() => {
        console.log('Save NOC success');
    })
    .catch(error => {
        console.error('Save NOC failed:', error);
    });
  }

  /**
   * Ghi bộ NOC đã chọn lên Case (cùng Apex saveCaseNOC như Submit).
   * Chỉ gọi khi đã resolve natureOfCaseId; không dùng saveNOC (tránh FEC_Is_Call_API_Success__c).
   */
  _persistSelectedNocToDatabase(natureOfCaseId) {
    if (!this.recordId || !natureOfCaseId || this.isDisableNOC) {
      return Promise.resolve();
    }
    const nocId = String(natureOfCaseId);
    if (nocId === this._lastPersistedNatureOfCaseId) {
      return Promise.resolve();
    }
    return saveCaseNOC({
      caseId: this.recordId,
      natureOfCaseId: nocId
    })
      .then(() => {
        this._lastPersistedNatureOfCaseId = nocId;
      })
      .catch((error) => {
        console.error("persistSelectedNocToDatabase failed:", error);
      });
  }

  async handlePublishMessageChanel() {
    const payload = {
      caseId: this.recordId,
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId,
      subCategoryId: this.subCategorySelectedId,
      subCodeId: this.subCodeSelectedId,
      natureOfCaseId: this.natureOfCase?.Id
    };

    publish(this.messageContext, CASE_NOC, payload);
  }

  _publishCaseNocAfterPersist(payload) {
    const nocId = payload?.natureOfCaseId ?? null;
    return this._persistSelectedNocToDatabase(nocId).then(() => {
      publish(this.messageContext, CASE_NOC, payload);
    });
  }

  handleMessage(message) {
    if (!message || typeof message.isModeEdit === "undefined") return;

    if (message.caseId != null && message.caseId !== this.recordId) {
      return;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — submit → review: bỏ lock Fast Cash, cho reload NOC
    if (message.isModeEdit === false) {
      this._clearFastCashBlockSessionStorage();
      this.isNocLockedAfterFastCashBlock = false;
      this._fastCashLockCombosApplied = false;
    }

    // 🚫 API success rồi thì không cho edit nữa
    if (this.isDisableNOC) {
      return;
    }
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }

    const nextModeEdit = message.isModeEdit === true;
    const prevModeEdit = this.modeEditCase === true;
    this.modeEditCase = nextModeEdit;
    if (nextModeEdit) {
      this._isCaseInformationEdit = false;
    }
    if (prevModeEdit !== nextModeEdit && !nextModeEdit) {
      this.reloadData();
    }
  }

  reloadData() {
    this._internalApplied = false;
    this._internalProductTypeId = null;
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    this._fastCashLockCombosApplied = false;

    getCase({ recordId: this.recordId })
      .then((res) => {
        this.productTypeSelectedId = res.FEC_Product_Type__c;
        this.categorySelectedId = res.FEC_Category__c;
        this.subCategorySelectedId = res.FEC_SubCategory__c;
        this.subCodeSelectedId = res.FEC_SubCode__c;
        //linhdev fix jira FECREDIT_CSM_2025_KH-1366
        this._applyFastCashNocSelectionFromStorage();

        this.isSubmited = res.FEC_Is_Submited__c;
        this.interactionViewMode = res.FEC_Interaction_View_Mode__c;
        this.recordTypeDevName = res.RecordType?.DeveloperName;
        this._isInternalRequest = res.FEC_Account_Contract_Number_PL__c === INTERNAL_REQUEST;
        //PhongBT: update bộ noc chọn ở updated khi revert về
        this._currentStageName = res.FEC_Current_Case_Stage__r?.Name || null;
        this._actualBusinessProcessCode =
          res.FEC_Actual_Nature_of_Case__r?.FEC_Business_Process__r?.FEC_Code__c || null;
        this._setSelectedNocDisplayNamesFromCase(res);
        this.getProdType();
        this.getCategory();
        this.getSubCategory();
        this.getSubCode();
        //PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
        // [NOC-HANDLING-STAGE-UPDATE]: Re-populate Updated section sau khi reload
        if (res.FEC_Is_Submited__c) {
          this.updatedCategoryId = res.FEC_Category__c;
          this.updatedSubCategoryId = res.FEC_SubCategory__c;
          this.updatedSubCodeId = res.FEC_SubCode__c;
          this._setUpdatedNocDisplayNamesFromCase(res);

          hasAutoRoutingAssignment({ caseId: this.recordId })
            .then((result) => {
              this.hasAutoRoutingAssignment = result === true;
            })
            .catch((err) => {
              console.error("hasAutoRoutingAssignment error (reloadData):", err);
              this.hasAutoRoutingAssignment = false;
            });

          //PhongBT: Original Information của NOC lấy từ FEC_Case_Flow_History__c
          getOriginalNOCFromFlowHistory({ caseId: this.recordId })
            .then((nocData) => {
              this.originalNOC = nocData || null;
              this.originalNOCBusinessProcessCode = nocData?.businessProcessCode || null;
            })
            .catch((err) => {
              console.error("getOriginalNOCFromFlowHistory error (reloadData):", err);
              this.originalNOC = null;
              this.originalNOCBusinessProcessCode = null;
            });
        }
        //linhdev fix jira FECREDIT_CSM_2025_KH-1366
        this._restoreFastCashNocLockFromStorage();
        this._releaseFastCashNocLockIfStale();
      })
      .catch((err) => {
        console.log("reloadData err:", err);
      });
  }

  // handleProductTypeSelect(event) {
  //   this.productTypeSelectedId = event.detail.recordId;
  //   if (!this.productTypeSelectedId) {
  //     this.handleClearSelection("category");
  //     this.handleClearSelection("subCategory");
  //     this.handleClearSelection("subCode");
  //     this.categorySelectedId = null;
  //     this.subCategorySelectedId = null;
  //     this.subCodeSelectedId = null;
  //   } else {
  //     getCategoryIds({
  //       recordId: this.recordId,
  //       productTypeId: this.productTypeSelectedId
  //     })
  //       .then((result) => {
  //         this.categoryFilter = {
  //           criteria: [
  //             {
  //               fieldPath: "Id",
  //               operator: "in",
  //               value: result
  //             }
  //           ]
  //         };
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });
  //   }
  // }

  // handleCategorySelect(event) {
  //   this.categorySelectedId = event.detail.recordId;
  //   if (!this.categorySelectedId) {
  //     this.handleClearSelection("subCategory");
  //     this.handleClearSelection("subCode");
  //     this.subCategorySelectedId = null;
  //     this.subCodeSelectedId = null;
  //   } else {
  //     getSubCategoryIds({
  //       recordId: this.recordId,
  //       productTypeId: this.productTypeSelectedId,
  //       categoryId: this.categorySelectedId
  //     })
  //       .then((result) => {
  //         this.subCategoryFilter = {
  //           criteria: [
  //             {
  //               fieldPath: "Id",
  //               operator: "in",
  //               value: result
  //             }
  //           ]
  //         };
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });
  //   }
  // }

  // handleSubCategorySelect(event) {
  //   this.subCategorySelectedId = event.detail.recordId;
  //   if (!this.subCategorySelectedId) {
  //     this.handleClearSelection("subCode");
  //     this.subCodeSelectedId = null;
  //   } else {
  //     getSubCodeIds({
  //       recordId: this.recordId,
  //       productTypeId: this.productTypeSelectedId,
  //       categoryId: this.categorySelectedId,
  //       subCategoryId: this.subCategorySelectedId
  //     })
  //       .then((result) => {
  //         this.subCodeFilter = {
  //           criteria: [
  //             {
  //               fieldPath: "Id",
  //               operator: "in",
  //               value: result
  //             }
  //           ]
  //         };
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });
  //   }

  //   this.handlePublishMessageChanel();
  // }

  // handleSubCodeSelect(event) {
  //   this.subCodeSelectedId = event.detail.recordId;
  //   if (this.subCodeSelectedId) {
  //     getNatureOfCase({
  //       productTypeId: this.productTypeSelectedId,
  //       categoryId: this.categorySelectedId,
  //       subCategoryId: this.subCategorySelectedId,
  //       subCodeId: this.subCodeSelectedId
  //     })
  //       .then((result) => {
  //         this.natureOfCase = result;
  //       })
  //       .catch((error) => {
  //         console.log("error", error);
  //       });

  //     this.handlePublishMessageChanel();
  //   }
  // }

  // handleClearSelection(selection) {
  //   const picker = this.template.querySelector(
  //     `lightning-record-picker[data-name="${selection}"]`
  //   );
  //   picker.clearSelection();
  // }

  getProdType() {
    getProductTypelst({ recordId: this.recordId }).then((res) => {
      console.log(
        "🚀 ~ Fec_CaseEditNOC ~ getProdType ~ res:",
        JSON.stringify(res)
      );
      this.productTypeOptionlst = this._ensureSelectedOptionLabel(
        res,
        this.productTypeSelectedId,
        this._selectedNocDisplayNames?.productType
      );
      if (this._isInternalRequest && !this.productTypeSelectedId) {
        const internalOption = res?.find((opt) => opt.label === INTERNAL_REQUEST);

        if (internalOption) {
          this.productTypeSelectedId = internalOption.value;
          this.disableProdType = true;
          this._internalProductTypeId = internalOption.value;
          this._internalApplied = false; 
          this.getCategory();
          this.getSubCategory();
          this.getSubCode();
        }
      }
    });
  }

  getCategory() {
    getCategorylst({
      recordId: this.recordId,
      productTypeId: this.productTypeSelectedId
    })
      .then((res) => {
        console.log(
          "🚀 ~ Fec_CaseEditNOC ~ getCategory ~ res:",
          JSON.stringify(res)
        );
        this.categoryOptionlst = this._ensureSelectedOptionLabel(
          res,
          this.categorySelectedId,
          this._selectedNocDisplayNames?.category
        );

        this.handleChangeOption("category", this.categoryOptionlst);
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ getCategory ~ err:", err);
      });
  }

  getSubCategory() {
    getSubCategorylst({
      recordId: this.recordId,
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId
    })
      .then((res) => {
        console.log(
          "🚀 ~ Fec_CaseEditNOC ~ getSubCategory ~ res:",
          JSON.stringify(res)
        );
        this.subCategoryOptionlst = this._ensureSelectedOptionLabel(
          res,
          this.subCategorySelectedId,
          this._selectedNocDisplayNames?.subCategory
        );

        this.handleChangeOption("sub-category", this.subCategoryOptionlst);
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ getSubCategory ~ err:", err);
      });
  }

  getSubCode() {
    getSubCodelst({
      recordId: this.recordId,
      productTypeId: this.productTypeSelectedId,
      categoryId: this.categorySelectedId,
      subCategoryId: this.subCategorySelectedId
    })
      .then((res) => {
        console.log(
          "🚀 ~ Fec_CaseEditNOC ~ getSubCode ~ res:",
          JSON.stringify(res)
        );

        this.subCodeOptionlst = this._ensureSelectedOptionLabel(
          res,
          this.subCodeSelectedId,
          this._selectedNocDisplayNames?.subCode
        );

        this.handleChangeOption("sub-code", this.subCodeOptionlst);
        // Không có option Sub-Code: resolve NOC không Sub-Code; getByCase (Apex) không fallback Sub-Code từ Case khi đã có Sub-Category từ UI.
        const triple =
          this.productTypeSelectedId &&
          this.categorySelectedId &&
          this.subCategorySelectedId;
        const noSubCodeOptions = !res || res.length === 0;

        if (triple && noSubCodeOptions) {
          this.subCodeSelectedId = null;
          this.syncSubCodeComboValue();
          return getNatureOfCaseWithoutSubCode({
            productTypeId: this.productTypeSelectedId,
            categoryId: this.categorySelectedId,
            subCategoryId: this.subCategorySelectedId
          })
            .then((noc) => {
              this.natureOfCase = noc;
              return this._persistSelectedNocToDatabase(noc?.Id);
            })
            .then(() => {
              this.handlePublishMessageChanel();
            })
            .catch((e) => {
              console.log("getNatureOfCaseWithoutSubCode err:", e);
              this.natureOfCase = null;
              this.handlePublishMessageChanel();
            });
        }
      })
      .catch((err) => {
        console.log("🚀 ~ Fec_CaseEditNOC ~ getSubCode ~ err:", err);
      });
  }

    syncSubCodeComboValue() {
    const el = this.template.querySelector(`c-fec_-combo-box[data-id="sub-code"]`);
    if (el) {
      el.value = undefined;
    }
  }

  handleRemoveProdType() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="prod-type"]`
    );

    if (element) {
      element.searchKey = undefined;
    }

    this.handleDisable("category");
    this.handleDisable("sub-category");
    this.handleDisable("sub-code");
  }

  handleRemoveCategory() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this.handleDisable("sub-category");
    this.handleDisable("sub-code");
  }

  handleRemoveSubCategory() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this.handleDisable("sub-code");
  }

  handleRemoveSubCode() {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="sub-code"]`
    );

    if (element) {
      element.value = undefined;
      element.disabled = false;
    }
  }

  handleChangeProdType(e) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this.productTypeSelectedId = e.detail.value;
    this.handleEnable("category");
  }

  //linhdev fix section Account Info + Case Info
  _bumpNocResolveEpoch() {
    this._nocResolveEpoch += 1;
    return this._nocResolveEpoch;
  }

  _isNocResolveEpochCurrent(epoch) {
    return epoch === this._nocResolveEpoch;
  }

  handleChangeCategory(e) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this._bumpNocResolveEpoch();
    this.categorySelectedId = e.detail.value;
    this.subCategorySelectedId = null;
    this.subCodeSelectedId = null;
    this.natureOfCase = null;
    this.handleDisable("sub-category");
    this.handleDisable("sub-code");
    this.handleEnable("sub-category");
    if (this.productTypeSelectedId && this.categorySelectedId) {
      this.handlePublishMessageChanel();
    }
  }

  handleChangeSubCategory(e) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this._bumpNocResolveEpoch();
    this.subCategorySelectedId = e.detail.value;
    this.subCodeSelectedId = null;
    this.natureOfCase = null;

    this.handleEnable("sub-code");
    this.handlePublishMessageChanel();
  }

  handleChangeSubCode(e) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this.subCodeSelectedId = e.detail.value;

    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="sub-code"]`
    );

    if (element) {
      element.value = this.subCodeSelectedId;
    }

    if (this.subCodeSelectedId) {
      const epoch = this._bumpNocResolveEpoch();
      const resolvedSubCodeId = this.subCodeSelectedId;
      getNatureOfCase({
        productTypeId: this.productTypeSelectedId,
        categoryId: this.categorySelectedId,
        subCategoryId: this.subCategorySelectedId,
        subCodeId: resolvedSubCodeId
      })
        .then((result) => {
          if (!this._isNocResolveEpochCurrent(epoch)) {
            return;
          }
          this.natureOfCase = result;
          return this._persistSelectedNocToDatabase(result?.Id);
        })
        .then(() => {
          if (!this._isNocResolveEpochCurrent(epoch)) {
            return;
          }
          this._savePointsRedemptionNocSelectionToStorage();
          this.handlePublishMessageChanel();
        })
        .catch((error) => {
          console.log("error", error);
        });
    } else {
      this.natureOfCase = null;
      this.handlePublishMessageChanel();
    }
  }

  handleDisable(id) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`
    );

    if (element) {
      element.value = undefined;
      element.disabled = true;
      element.searchKey = undefined;
    }
  }

  //HieuTT74 Cập nhật ngày  17-4-2026: Bổ sung message channel để disable các combobox khi call api reset pin thành công
  handleDisableResetPinSuccess(id) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`,
    );

    if (element) {
      element.disabled = true;
    }
  }

  handleEnable(id) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`
    );

    if (element) {
      element.disabled = false;

      switch (id) {
        case "category":
          this.getCategory();
          break;
        case "sub-category":
          this.getSubCategory();
          break;
        case "sub-code":
          this.getSubCode();
          break;
        default:
          break;
      }
    }
  }

  handleChangeOption(id, optionlst) {
    let element = this.template.querySelector(
      `c-fec_-combo-box[data-id="${id}"]`
    );

    if (element) {
      element.option = JSON.stringify(optionlst);
    }
  }
//PhongBT11 update jira KH-1084 bổ sung Updated Information cho NOC, GSR Handling Stage
  // ─────────────────────────────────────────────────────────────────────────
  // [NOC-HANDLING-STAGE-UPDATE]: Event handlers từ child component
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Handler khi Category thay đổi trong Updated section (từ child component).
   * Reset Sub-Category và Sub-Code, reload Sub-Category options.
   */
  handleUpdatedCategoryChange(e) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this._bumpNocResolveEpoch();
    this.updatedCategoryId = e.detail.categoryId;
    this.updatedSubCategoryId = null;
    this.updatedSubCodeId = null;

    // Reload Sub-Category options theo Category mới
    if (this.updatedCategoryId) {
      getSubCategorylst({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: this.updatedCategoryId
      })
        .then((res) => {
          this.subCategoryOptionlst = res;
        })
        .catch((err) => {
          console.error("getSubCategorylst error (Updated section):", err);
        });
    }
  }

  /**
   * Handler khi Sub-Category thay đổi trong Updated section (từ child component).
   * Reset Sub-Code, reload Sub-Code options.
   */
  handleUpdatedSubCategoryChange(e) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    const epoch = this._bumpNocResolveEpoch();
    this.updatedSubCategoryId = e.detail.subCategoryId;
    this.updatedSubCodeId = null;

    // Reload Sub-Code options theo Sub-Category mới
    if (this.updatedSubCategoryId) {
      const resolvedSubCategoryId = this.updatedSubCategoryId;
      const resolvedCategoryId = this.updatedCategoryId;
      getSubCodelst({
        recordId: this.recordId,
        productTypeId: this.productTypeSelectedId,
        categoryId: resolvedCategoryId,
        subCategoryId: resolvedSubCategoryId
      })
        .then((res) => {
          if (!this._isNocResolveEpochCurrent(epoch)) {
            return;
          }
          this.subCodeOptionlst = res;

          const noSubCodeOptions = !res || res.length === 0;
          if (this.productTypeSelectedId && resolvedCategoryId && resolvedSubCategoryId && noSubCodeOptions) {
            return getNatureOfCaseWithoutSubCode({
              productTypeId: this.productTypeSelectedId,
              categoryId: resolvedCategoryId,
              subCategoryId: resolvedSubCategoryId
            })
              .then((noc) => {
                if (!this._isNocResolveEpochCurrent(epoch)) {
                  return;
                }
                const payload = {
                  caseId: this.recordId,
                  productTypeId: this.productTypeSelectedId,
                  categoryId: resolvedCategoryId,
                  subCategoryId: resolvedSubCategoryId,
                  subCodeId: null,
                  natureOfCaseId: noc?.Id ?? null
                };
                return this._publishCaseNocAfterPersist(payload);
              })
              .catch((err) => {
                if (!this._isNocResolveEpochCurrent(epoch)) {
                  return;
                }
                console.error("getNatureOfCaseWithoutSubCode error (Updated section):", err);
                const payload = {
                  caseId: this.recordId,
                  productTypeId: this.productTypeSelectedId,
                  categoryId: resolvedCategoryId,
                  subCategoryId: resolvedSubCategoryId,
                  subCodeId: null,
                  natureOfCaseId: null
                };
                publish(this.messageContext, CASE_NOC, payload);
              });
          }
        })
        .catch((err) => {
          console.error("getSubCodelst error (Updated section):", err);
        });
    }
  }

  /**
   * Handler khi Sub-Code thay đổi trong Updated section (từ child component).
   * Child đã gọi getNatureOfCase và trả về natureOfCaseId trong event.detail.
   * Publish full payload lên CASE_NOC_Channel để trigger fec_CaseBussiness reload.
   */
  handleUpdatedSubCodeChange(e) {
    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    if (this.isNocNatureLocked) {
      return;
    }
    this.updatedSubCodeId = e.detail.subCodeId;
    const natureOfCaseId = e.detail.natureOfCaseId;

    // Publish lên CASE_NOC_Channel với bộ NOC mới (Updated NOC)
    const payload = {
      caseId: this.recordId,
      productTypeId: this.productTypeSelectedId,
      categoryId: this.updatedCategoryId,
      subCategoryId: this.updatedSubCategoryId,
      subCodeId: this.updatedSubCodeId,
      natureOfCaseId: natureOfCaseId
    };

    this._publishCaseNocAfterPersist(payload);
  }
}