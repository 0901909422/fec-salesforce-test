import { LightningElement, api, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { publish, subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from "lightning/messageService";
import CASE_NOC from "@salesforce/messageChannel/FEC_Case_NOC__c";
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";

import CASE_ACTUAL_NOC from "@salesforce/schema/Case.FEC_Actual_Nature_of_Case__c";

import getCaseFastCashState from "@salesforce/apex/FEC_FastCashCaseController.getCaseFastCashState";
import checkFastCashEligibility from "@salesforce/apex/FEC_FastCashCaseController.checkFastCashEligibility";
import saveFastCashCaseAmounts from "@salesforce/apex/FEC_FastCashCaseController.saveFastCashCaseAmounts";
import executeFastCashBlock from "@salesforce/apex/FEC_FastCashCaseController.executeFastCashBlock";

import FEC_LBL_Fast_Cash_Error_Code from "@salesforce/label/c.FEC_LBL_Fast_Cash_Error_Code";
import FEC_LBL_Fast_Cash_Error_Description from "@salesforce/label/c.FEC_LBL_Fast_Cash_Error_Description";
import FEC_LBL_Fast_Cash_Requested_Amount from "@salesforce/label/c.FEC_LBL_Fast_Cash_Requested_Amount";
import FEC_LBL_Fast_Cash_Max_Amount from "@salesforce/label/c.FEC_LBL_Fast_Cash_Max_Amount";
import FEC_LBL_Fast_Cash_Block_Amount from "@salesforce/label/c.FEC_LBL_Fast_Cash_Block_Amount";
import FEC_LBL_Fast_Cash_Status from "@salesforce/label/c.FEC_LBL_Fast_Cash_Status";
import FEC_LBL_Fast_Cash_Status_Eligible from "@salesforce/label/c.FEC_LBL_Fast_Cash_Status_Eligible";
import FEC_LBL_Fast_Cash_Btn_No from "@salesforce/label/c.FEC_LBL_Fast_Cash_Btn_No";
import FEC_LBL_Fast_Cash_Btn_Yes from "@salesforce/label/c.FEC_LBL_Fast_Cash_Btn_Yes";
import FEC_LBL_Fast_Cash_Spinner_Loading from "@salesforce/label/c.FEC_LBL_Fast_Cash_Spinner_Loading";
import FEC_LBL_Fast_Cash_Spinner_Processing from "@salesforce/label/c.FEC_LBL_Fast_Cash_Spinner_Processing";
import FEC_MSG_Fast_Cash_Modal_Body from "@salesforce/label/c.FEC_MSG_Fast_Cash_Modal_Body";
import FEC_MSG_Fast_Cash_Noti_01 from "@salesforce/label/c.FEC_MSG_Fast_Cash_Noti_01";
import FEC_MSG_Fast_Cash_Noti_02 from "@salesforce/label/c.FEC_MSG_Fast_Cash_Noti_02";
import FEC_MSG_Fast_Cash_Noti_08 from "@salesforce/label/c.FEC_MSG_Fast_Cash_Noti_08";
import FEC_MSG_Fast_Cash_Noti_09 from "@salesforce/label/c.FEC_MSG_Fast_Cash_Noti_09";
import FEC_MSG_Fast_Cash_Noti_10 from "@salesforce/label/c.FEC_MSG_Fast_Cash_Noti_10";
import FEC_MSG_Fast_Cash_Noti_12 from "@salesforce/label/c.FEC_MSG_Fast_Cash_Noti_12";
import FEC_MSG_Fast_Cash_Noti_15 from "@salesforce/label/c.FEC_MSG_Fast_Cash_Noti_15";
import FEC_Button_Close from "@salesforce/label/c.FEC_Button_Close";

import {
    STR_EMPTY,
    CASE_OBJECT_API_NAME,
    NAV_ACTION_VIEW,
    MIN_FAST_CASH_REGISTRATION_VND,
    MAX_FAST_CASH_BLOCK_ATTEMPTS,
    FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX,
    FEC_FAST_CASH_STORAGE_BLK_FAIL_PREFIX,
    FEC_FAST_CASH_STORAGE_BLK_OK_PREFIX,
    FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX,
    FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX,
    FEC_FAST_CASH_STORAGE_REQUESTED_AMOUNT_PREFIX
} from "c/fec_CommonConst";
import { formatThousandsFromDigits, stripToIntString } from "c/fec_CommonUtils";

const FAST_CASH_SUB_CATEGORY_CODE = "RC35";

export default class Fec_FastCashCaseForm extends NavigationMixin(LightningElement) {
    @api recordId;

    @wire(MessageContext)
    messageContext;

    _isEdit = true;
    @api get isEdit() {
        return this._isEdit;
    }
    set isEdit(value) {
        if (value === undefined || value === null) {
            return;
        }
        this._isEdit = value === true || value === "true";
    }

    _subCategoryCode = "";
    @api get subCategoryCode() {
        return this._subCategoryCode;
    }
    set subCategoryCode(value) {
        const newCode = value == null ? "" : String(value);
        if (this._subCategoryCode === newCode) {
            return;
        }
        const wasFastCash = this._subCategoryCode === FAST_CASH_SUB_CATEGORY_CODE;
        this._subCategoryCode = newCode;
        if (wasFastCash && newCode !== FAST_CASH_SUB_CATEGORY_CODE) {
            //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — rời RC35: dọn session lock & flag
            this._clearFastCashSessionStorage();
            this.nocLockedAfterBlockModal = false;
            //linhdev fix jira FECREDIT_CSM_2025_KH-1294
            this._notifyFastCashPropertyInfoVisibility(false);
        }
        if (this._isFastCashScope) {
            //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — vào RC35 lần đầu mà chưa qua pop-up Block Amount: reset state
            if (!wasFastCash && !this._isBlockModalConfirmedInStorage()) {
                this._resetFastCashBlockSessionState();
            }
            this._maybeHydrateForFastCashScope();
        } else if (wasFastCash) {
            this._presubmitHydrated = false;
        }
    }

    _subCodeCode = "";
    @api get subCodeCode() {
        return this._subCodeCode;
    }
    set subCodeCode(value) {
        this._subCodeCode = value == null ? "" : String(value);
    }

    customLabel = {
        lblErrorCode: FEC_LBL_Fast_Cash_Error_Code,
        lblErrorDescription: FEC_LBL_Fast_Cash_Error_Description,
        lblFastCashStatus: FEC_LBL_Fast_Cash_Status,
        lblRequestedAmount: FEC_LBL_Fast_Cash_Requested_Amount,
        lblMaxAmount: FEC_LBL_Fast_Cash_Max_Amount,
        lblBlockAmount: FEC_LBL_Fast_Cash_Block_Amount,
        lblModalTitle: FEC_LBL_Fast_Cash_Block_Amount,
        btnModalNo: FEC_LBL_Fast_Cash_Btn_No,
        btnModalYes: FEC_LBL_Fast_Cash_Btn_Yes,
        btnClose: FEC_Button_Close,
        spinnerLoading: FEC_LBL_Fast_Cash_Spinner_Loading,
        spinnerProcessing: FEC_LBL_Fast_Cash_Spinner_Processing,
        modalBody: FEC_MSG_Fast_Cash_Modal_Body,
        msgNoti01: FEC_MSG_Fast_Cash_Noti_01,
        msgNoti02: FEC_MSG_Fast_Cash_Noti_02,
        msgNoti08: FEC_MSG_Fast_Cash_Noti_08,
        msgNoti09: FEC_MSG_Fast_Cash_Noti_09,
        msgNoti10: FEC_MSG_Fast_Cash_Noti_10,
        msgNoti12: FEC_MSG_Fast_Cash_Noti_12,
        msgNoti15: FEC_MSG_Fast_Cash_Noti_15,
        statusEligible: FEC_LBL_Fast_Cash_Status_Eligible
    };

    @track eligibilityLoading = false;
    @track blockLoading = false;
    @track showConfirmModal = false;

    @track eligible = false;
    @track notEligible = false;

    @track displayErrorCode = STR_EMPTY;
    @track displayErrorDescription = STR_EMPTY;
    @track displayFastCashStatus = STR_EMPTY;

    @track maxAmountDecimal = null;
    @track requestedAmountDigits = STR_EMPTY;
    @track requestedAmountDisplay = STR_EMPTY;
    @track requestedFieldFocused = false;

    @track blockSucceeded = false;
    @track blockFailCount = 0;
    @track finalBlockFailure = false;

    @track showNoti08 = false;
    @track showNoti09 = false;
    @track showNoti10 = false;

    nocLockedAfterBlockModal = false;
    _lastNocId = null;
    _lockedViewLoaded = false;
    _presubmitHydrated = false;

    @wire(getRecord, { recordId: "$recordId", fields: [CASE_ACTUAL_NOC] })
    wiredCase({ data }) {
        if (!this.recordId) {
            return;
        }
        if (!data) {
            return;
        }
        const nocId = getFieldValue(data, CASE_ACTUAL_NOC);
        //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — chỉ phục hồi lock khi đã xác nhận pop-up; ngược lại reset flag tránh kẹt từ session cũ
        this._syncLocksWithStorage();
        if (!nocId) {
            this._lastNocId = null;
            if (this.nocLockedAfterBlockModal) {
                this._ensureLockedSnapshotLoaded();
                return;
            }
            if (this._isFastCashScope) {
                this._maybeHydrateForFastCashScope();
                return;
            }
            this.resetEligibilityUi();
            return;
        }
        if (this.nocLockedAfterBlockModal) {
            if (!this._lockedViewLoaded) {
                this._lastNocId = nocId;
                this._ensureLockedSnapshotLoaded();
            }
            return;
        }
        if (this._lastNocId !== nocId) {
            const isNocChange = this._lastNocId != null;
            this._lastNocId = nocId;
            this._lockedViewLoaded = false;
            //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — đổi NOC trước khi qua pop-up: dọn state Fast Cash của NOC cũ
            if (isNocChange && !this._isBlockModalConfirmedInStorage()) {
                this._resetFastCashBlockSessionState();
            }
            this.hydrateFromCaseThenEligibility();
        }
    }

    connectedCallback() {
        if (this.recordId) {
            //linhdev fix jira FECREDIT_CSM_2025_KH-1366
            this._syncLocksWithStorage();
            this._maybeHydrateForFastCashScope();
            this._subscribeModeEditChannel();
        }
    }

    disconnectedCallback() {
        if (this._modeEditSubscription) {
            unsubscribe(this._modeEditSubscription);
            this._modeEditSubscription = null;
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — submit xong: dọn session/state Fast Cash
    _subscribeModeEditChannel() {
        if (this._modeEditSubscription || !this.messageContext) {
            return;
        }
        this._modeEditSubscription = subscribe(
            this.messageContext,
            IS_MODE_EDIT,
            (message) => {
                if (!message || message.isModeEdit !== false) {
                    return;
                }
                if (message.caseId != null && message.caseId !== this.recordId) {
                    return;
                }
                this._clearFastCashSessionStorage();
                this._resetBlockStateFlagsInMemory();
            },
            { scope: APPLICATION_SCOPE }
        );
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — guard chung cho wiredCase & connectedCallback
    _syncLocksWithStorage() {
        if (!this._isBlockModalConfirmedInStorage()) {
            if (!this.nocLockedAfterBlockModal) {
                this._clearFastCashSessionStorage();
                this._resetBlockStateFlagsInMemory();
            }
            return;
        }
        if (!this._isFastCashNocSelectionCompleteInStorage()) {
            if (!this.nocLockedAfterBlockModal) {
                this._clearFastCashSessionStorage();
                this._resetBlockStateFlagsInMemory();
            }
            return;
        }
        this.restoreLocksFromStorage();
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    _isFastCashNocSelectionCompleteInStorage() {
        try {
            if (!this.recordId) {
                return false;
            }
            const raw = sessionStorage.getItem(FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX + this.recordId);
            if (!raw) {
                return false;
            }
            const sel = JSON.parse(raw);
            return !!(sel && sel.productTypeId && sel.categoryId && sel.subCategoryId);
        } catch (e) {
            return false;
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    _resetBlockStateFlagsInMemory() {
        this.nocLockedAfterBlockModal = false;
        this.blockSucceeded = false;
        this.finalBlockFailure = false;
        this.blockFailCount = 0;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    _ensureLockedSnapshotLoaded() {
        if (this._lockedViewLoaded) {
            return;
        }
        this._lockedViewLoaded = true;
        this.loadLockedSnapshot();
    }

    restoreLocksFromStorage() {
        try {
            if (!this.recordId || !this._isBlockModalConfirmedInStorage()) {
                return;
            }
            this.nocLockedAfterBlockModal = true;
            const bk = this._storageBlockFailKey();
            const n = parseInt(sessionStorage.getItem(bk) || "0", 10);
            if (!isNaN(n) && n > 0) {
                this.blockFailCount = n;
            }
            if (this.blockFailCount >= MAX_FAST_CASH_BLOCK_ATTEMPTS) {
                this.finalBlockFailure = true;
            }
            if (sessionStorage.getItem(this._storageBlockOkKey()) === "1") {
                this.blockSucceeded = true;
                this.showNoti08 = true;
            }
        } catch (e) {
            /* ignore */
        }
    }

    _storageNocKey() {
        return FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX + this.recordId;
    }

    _storageBlockFailKey() {
        return FEC_FAST_CASH_STORAGE_BLK_FAIL_PREFIX + this.recordId;
    }

    _storageBlockOkKey() {
        return FEC_FAST_CASH_STORAGE_BLK_OK_PREFIX + this.recordId;
    }

    _storageModalConfirmedKey() {
        return FEC_FAST_CASH_STORAGE_MODAL_CONFIRMED_PREFIX + this.recordId;
    }

    _isBlockModalConfirmedInStorage() {
        try {
            return sessionStorage.getItem(this._storageModalConfirmedKey()) === "1";
        } catch (e) {
            return false;
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366
    _clearFastCashSessionStorage() {
        try {
            if (!this.recordId) {
                return;
            }
            sessionStorage.removeItem(this._storageNocKey());
            sessionStorage.removeItem(this._storageBlockFailKey());
            sessionStorage.removeItem(this._storageBlockOkKey());
            sessionStorage.removeItem(this._storageModalConfirmedKey());
            sessionStorage.removeItem(FEC_FAST_CASH_STORAGE_NOC_SELECTION_PREFIX + this.recordId);
            sessionStorage.removeItem(FEC_FAST_CASH_STORAGE_REQUESTED_AMOUNT_PREFIX + this.recordId);
        } catch (e) {
            /* ignore */
        }
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — giữ Requested Amount sau block fail / remount
    _saveRequestedAmountToStorage() {
        try {
            if (!this.recordId || !this.requestedAmountDigits) {
                return;
            }
            sessionStorage.setItem(
                FEC_FAST_CASH_STORAGE_REQUESTED_AMOUNT_PREFIX + this.recordId,
                JSON.stringify({
                    digits: this.requestedAmountDigits,
                    display: this.requestedAmountDisplay
                })
            );
        } catch (e) {
            /* ignore */
        }
    }

    _readRequestedAmountFromStorage() {
        try {
            if (!this.recordId) {
                return null;
            }
            const raw = sessionStorage.getItem(FEC_FAST_CASH_STORAGE_REQUESTED_AMOUNT_PREFIX + this.recordId);
            if (!raw) {
                return null;
            }
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    _restoreRequestedAmountFromStorageOrMemory(preservedDigits, preservedDisplay) {
        const fromSession = this._readRequestedAmountFromStorage();
        if (fromSession && fromSession.digits) {
            this.requestedAmountDigits = fromSession.digits;
            this.requestedAmountDisplay = fromSession.display || formatThousandsFromDigits(fromSession.digits);
            return;
        }
        if (preservedDigits) {
            this.requestedAmountDigits = preservedDigits;
            this.requestedAmountDisplay = preservedDisplay || formatThousandsFromDigits(preservedDigits);
        }
    }

    _persistRequestedAmountBeforeBlock(blockAmount) {
        this._saveRequestedAmountToStorage();
        return saveFastCashCaseAmounts({
            caseId: this.recordId,
            requestedAmount: blockAmount,
            maxAmount: this.maxAmountDecimal
        }).catch(() => undefined);
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — Có/Không & block fail: giữ handling (Save/Submit, remark, routing)
    _ensureHandlingModeAfterBlockModal() {
        if (!this.messageContext || !this.recordId) {
            return;
        }
        publish(this.messageContext, IS_MODE_EDIT, {
            caseId: this.recordId,
            isModeEdit: true
        });
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — đổi NOC / rời RC35: reset toàn bộ state Fast Cash
    _resetFastCashBlockSessionState() {
        this._clearFastCashSessionStorage();
        this._resetBlockStateFlagsInMemory();
        this._lockedViewLoaded = false;
        this.clearBlockMessages();
    }

    loadLockedSnapshot() {
        const preservedDigits = this.requestedAmountDigits;
        const preservedDisplay = this.requestedAmountDisplay;
        const keepNoti09 = this.showNoti09;
        const keepNoti10 = this.showNoti10;
        if (!keepNoti09 && !keepNoti10) {
            this.clearBlockMessages();
        }
        getCaseFastCashState({ caseId: this.recordId })
            .then((st) => {
                if (st && st.maxAmount != null && Number(st.maxAmount) > 0) {
                    this.eligible = true;
                    this.notEligible = false;
                    this.maxAmountDecimal = Number(st.maxAmount);
                }
                if (st && st.requestedAmount != null) {
                    const d = stripToIntString(st.requestedAmount);
                    this.requestedAmountDigits = d;
                    this.requestedAmountDisplay = formatThousandsFromDigits(d);
                } else {
                    this._restoreRequestedAmountFromStorageOrMemory(preservedDigits, preservedDisplay);
                }
                if (sessionStorage.getItem(this._storageBlockOkKey()) === "1") {
                    this.blockSucceeded = true;
                    this.showNoti08 = true;
                }
                if (this.blockFailCount >= MAX_FAST_CASH_BLOCK_ATTEMPTS) {
                    this.showNoti10 = true;
                }
                if (keepNoti09) {
                    this.showNoti09 = true;
                }
                if (keepNoti10) {
                    this.showNoti10 = true;
                }
                //linhdev fix jira FECREDIT_CSM_2025_KH-1294
                this._notifyFastCashPropertyInfoVisibility(false);
            })
            .catch(() => {
                this._restoreRequestedAmountFromStorageOrMemory(preservedDigits, preservedDisplay);
                if (keepNoti09) {
                    this.showNoti09 = true;
                }
                if (keepNoti10) {
                    this.showNoti10 = true;
                }
            });
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1294
    _notifyFastCashPropertyInfoVisibility(hide) {
        this.dispatchEvent(
            new CustomEvent("fecfastcashpropertyinfovisibility", {
                bubbles: true,
                composed: true,
                detail: { hidePropertyInfo: hide === true }
            })
        );
    }

    hydrateFromCaseThenEligibility() {
        this.clearBlockMessages();
        getCaseFastCashState({ caseId: this.recordId })
            .then((st) => {
                if (st && st.requestedAmount != null) {
                    const d = stripToIntString(st.requestedAmount);
                    this.requestedAmountDigits = d;
                    this.requestedAmountDisplay = formatThousandsFromDigits(d);
                } else {
                    this.requestedAmountDigits = STR_EMPTY;
                    this.requestedAmountDisplay = STR_EMPTY;
                }
                if (st && st.maxAmount != null) {
                    this.maxAmountDecimal = Number(st.maxAmount);
                }
                return this.runEligibilityCheck();
            })
            .catch(() => {
                return this.runEligibilityCheck();
            });
    }

    resetEligibilityUi() {
        this.eligible = false;
        this.notEligible = false;
        this.eligibilityLoading = false;
        this.displayErrorCode = STR_EMPTY;
        this.displayErrorDescription = STR_EMPTY;
        this.displayFastCashStatus = STR_EMPTY;
        this.maxAmountDecimal = null;
        this.clearBlockMessages();
        //linhdev fix jira FECREDIT_CSM_2025_KH-1294
        this._notifyFastCashPropertyInfoVisibility(false);
    }

    clearBlockMessages() {
        this.showNoti08 = false;
        this.showNoti09 = false;
        this.showNoti10 = false;
    }

    runEligibilityCheck() {
        if (!this.recordId || this.nocLockedAfterBlockModal) {
            return Promise.resolve();
        }
        this.eligibilityLoading = true;
        this.notEligible = false;
        this.eligible = false;
        return checkFastCashEligibility({ caseId: this.recordId })
            .then((dto) => {
                this.eligibilityLoading = false;
                if (!dto || !dto.callCompleted) {
                    this.notEligible = true;
                    this.displayErrorCode = STR_EMPTY;
                    this.displayFastCashStatus = dto && dto.fastCashStatus ? dto.fastCashStatus : STR_EMPTY;
                    this.displayErrorDescription = dto && dto.technicalMessage ? dto.technicalMessage : STR_EMPTY;
                    //linhdev fix jira FECREDIT_CSM_2025_KH-1294
                    this._notifyFastCashPropertyInfoVisibility(true);
                    return;
                }
                if (dto.fastCashStatus === this.customLabel.statusEligible) {
                    this.eligible = true;
                    this.notEligible = false;
                    this.displayErrorCode = STR_EMPTY;
                    this.displayErrorDescription = STR_EMPTY;
                    this.displayFastCashStatus = STR_EMPTY;
                    //linhdev fix jira FECREDIT_CSM_2025_KH-1294
                    this._notifyFastCashPropertyInfoVisibility(false);
                    if (dto.maxAmount != null) {
                        this.maxAmountDecimal = Number(dto.maxAmount);
                    }
                    return saveFastCashCaseAmounts({
                        caseId: this.recordId,
                        requestedAmount: null,
                        maxAmount: this.maxAmountDecimal
                    });
                }
                this.notEligible = true;
                this.eligible = false;
                this.displayFastCashStatus = dto.fastCashStatus || STR_EMPTY;
                this.displayErrorCode = dto.errorCode || STR_EMPTY;
                this.displayErrorDescription = dto.errorDescription || STR_EMPTY;
                //linhdev fix jira FECREDIT_CSM_2025_KH-1294
                this._notifyFastCashPropertyInfoVisibility(true);
            })
            .catch(() => {
                this.eligibilityLoading = false;
                this.notEligible = true;
                this.eligible = false;
                this.displayErrorCode = STR_EMPTY;
                this.displayErrorDescription = STR_EMPTY;
                this.displayFastCashStatus = STR_EMPTY;
                //linhdev fix jira FECREDIT_CSM_2025_KH-1294
                this._notifyFastCashPropertyInfoVisibility(true);
            });
    }

    get isReadOnly() {
        return this._isEdit === false;
    }

    get showBody() {
        return !!this.recordId && (this._isFastCashScope || !!this._lastNocId);
    }

    get _isFastCashScope() {
        return this._subCategoryCode === FAST_CASH_SUB_CATEGORY_CODE;
    }

    _maybeHydrateForFastCashScope() {
        if (!this.recordId) {
            return;
        }
        if (!this._isFastCashScope) {
            return;
        }
        if (this._lastNocId) {
            return;
        }
        if (this._presubmitHydrated) {
            return;
        }
        if (this.nocLockedAfterBlockModal) {
            return;
        }
        this._presubmitHydrated = true;
        this.hydrateFromCaseThenEligibility();
    }

    get showNotEligible() {
        return this.notEligible && !this.eligibilityLoading;
    }

    get showEligible() {
        return this.eligible && !this.eligibilityLoading;
    }

    get maxAmountDisplay() {
        if (this.maxAmountDecimal == null) {
            return STR_EMPTY;
        }
        const d = stripToIntString(this.maxAmountDecimal);
        return formatThousandsFromDigits(d);
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — lock NOC không khóa amount; chỉ disable sau block OK hoặc 3 lần fail
    get amountFieldsDisabled() {
        if (this.finalBlockFailure || this.blockSucceeded) {
            return true;
        }
        if (this.eligible) {
            return false;
        }
        return this.isReadOnly;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — Block Amount không phụ thuộc isReadOnly từ parent metadata
    get blockAmountButtonDisabled() {
        return this.blockLoading || this.finalBlockFailure || this.blockSucceeded;
    }

    get showNoti12() {
        return (
            this.eligible &&
            (this.requestedFieldFocused || !!this.requestedAmountDigits) &&
            !this.showNoti02 &&
            !this.showNoti08 &&
            !this.showNoti09 &&
            !this.showNoti10
        );
    }

    get showNoti02() {
        if (!this.eligible || !this.requestedAmountDigits) {
            return false;
        }
        const n = parseInt(this.requestedAmountDigits, 10);
        if (isNaN(n)) {
            return false;
        }
        const maxOk = this.maxAmountDecimal == null || n <= Number(this.maxAmountDecimal);
        const minOk = n >= MIN_FAST_CASH_REGISTRATION_VND;
        return !minOk || !maxOk;
    }

    get showBlockButton() {
        if (!this.eligible || this.blockSucceeded || this.finalBlockFailure) {
            return false;
        }
        if (!this.requestedAmountDigits) {
            return false;
        }
        const n = parseInt(this.requestedAmountDigits, 10);
        if (isNaN(n)) {
            return false;
        }
        if (n < MIN_FAST_CASH_REGISTRATION_VND) {
            return false;
        }
        if (this.maxAmountDecimal != null && n > Number(this.maxAmountDecimal)) {
            return false;
        }
        return true;
    }

    get showNoti09BelowButton() {
        return this.showNoti09 && !this.showNoti10;
    }

    get showNoti10UnderInput() {
        return this.showNoti10;
    }

    handleRequestedFocus() {
        this.requestedFieldFocused = true;
    }

    handleRequestedAmountChange(event) {
        const digits = stripToIntString(event.target.value);
        this.requestedAmountDigits = digits;
        this.requestedAmountDisplay = formatThousandsFromDigits(digits);
    }

    handleOpenBlockModal() {
        if (this.blockAmountButtonDisabled || !this.showBlockButton) {
            return;
        }
        this.showConfirmModal = true;
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — chỉ gọi từ handleConfirmYes / handleConfirmNo (pop-up Block Amount)
    applyNocLockAfterModal() {
        this.nocLockedAfterBlockModal = true;
        this._saveRequestedAmountToStorage();
        try {
            sessionStorage.setItem(this._storageModalConfirmedKey(), "1");
            sessionStorage.setItem(this._storageNocKey(), "1");
        } catch (e) {
            /* ignore */
        }
        this._ensureHandlingModeAfterBlockModal();
        if (this.messageContext && this.recordId) {
            publish(this.messageContext, CASE_NOC, {
                caseId: this.recordId,
                fastCashNocLocked: true
            });
        }
        this._ensureLockedSnapshotLoaded();
    }

    handleConfirmNo() {
        this.showConfirmModal = false;
        this.applyNocLockAfterModal();
    }

    handleConfirmYes() {
        this.showConfirmModal = false;
        this.applyNocLockAfterModal();
        //linhdev fix jira FECREDIT_CSM_2025_KH-1366
        this.dispatchEvent(
            new CustomEvent("fecfastcashblockconfirmed", {
                bubbles: true,
                composed: true,
                detail: { recordId: this.recordId }
            })
        );
        this.executeBlock();
    }

    executeBlock() {
        const n = parseInt(this.requestedAmountDigits, 10);
        if (isNaN(n) || !this.recordId) {
            return;
        }
        this.blockLoading = true;
        this.clearBlockMessages();
        this._persistRequestedAmountBeforeBlock(n)
            .then(() => executeFastCashBlock({ caseId: this.recordId, blockAmount: n }))
            .then((res) => {
                this.blockLoading = false;
                if (res && res.success) {
                    this.blockSucceeded = true;
                    this.showNoti08 = true;
                    try {
                        sessionStorage.removeItem(this._storageBlockFailKey());
                        sessionStorage.setItem(this._storageBlockOkKey(), "1");
                    } catch (e) {
                        /* ignore */
                    }
                    this.navigateToCase();
                    return;
                }
                this._handleBlockFailure();
            })
            .catch(() => {
                this.blockLoading = false;
                this._handleBlockFailure();
            });
    }

    //linhdev fix jira FECREDIT_CSM_2025_KH-1366 — block fail: giữ handling mode + Requested Amount, không navigate view
    _handleBlockFailure() {
        this.blockLoading = false;
        this._saveRequestedAmountToStorage();
        this.blockFailCount += 1;
        try {
            sessionStorage.setItem(this._storageBlockFailKey(), String(this.blockFailCount));
        } catch (e) {
            /* ignore */
        }
        if (this.blockFailCount >= MAX_FAST_CASH_BLOCK_ATTEMPTS) {
            this.finalBlockFailure = true;
            this.showNoti10 = true;
        } else {
            this.showNoti09 = true;
        }
        this._ensureHandlingModeAfterBlockModal();
    }

    navigateToCase() {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.recordId,
                objectApiName: CASE_OBJECT_API_NAME,
                actionName: NAV_ACTION_VIEW
            }
        });
    }

    @api
    validateForCaseSubmit() {
        if (this.isReadOnly) {
            return true;
        }
        const root = this.template;
        if (!root) {
            return true;
        }
        const inp = root.querySelector('lightning-input[data-input="requestedAmount"]');
        if (inp && typeof inp.setCustomValidity === "function") {
            inp.setCustomValidity("");
        }
        if (!this.eligible) {
            return true;
        }
        if (!this.requestedAmountDigits) {
            if (inp && typeof inp.setCustomValidity === "function") {
                inp.setCustomValidity(this.customLabel.msgNoti01);
            }
        } else {
            const n = parseInt(this.requestedAmountDigits, 10);
            if (
                isNaN(n) ||
                n < MIN_FAST_CASH_REGISTRATION_VND ||
                (this.maxAmountDecimal != null && n > Number(this.maxAmountDecimal))
            ) {
                if (inp && typeof inp.setCustomValidity === "function") {
                    inp.setCustomValidity(this.customLabel.msgNoti02);
                }
            }
        }
        let ok = true;
        if (inp && typeof inp.reportValidity === "function" && !inp.reportValidity()) {
            ok = false;
        }
        return ok;
    }

    @api
    saveFastCashDataIfVisible() {
        if (this.isReadOnly || !this.recordId || !this.eligible) {
            return Promise.resolve();
        }
        const n = this.requestedAmountDigits ? parseInt(this.requestedAmountDigits, 10) : null;
        if (n == null || isNaN(n)) {
            return Promise.resolve();
        }
        return saveFastCashCaseAmounts({
            caseId: this.recordId,
            requestedAmount: n,
            maxAmount: this.maxAmountDecimal
        }).then(() => Promise.resolve());
    }

    @api
    saveDraftIfApplicable() {
        return this.saveFastCashDataIfVisible();
    }

    @api
    saveForSubmitIfApplicable() {
        return this.saveFastCashDataIfVisible();
    }
}