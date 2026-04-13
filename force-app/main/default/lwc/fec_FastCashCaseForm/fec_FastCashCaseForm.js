import { LightningElement, api, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";

import CASE_ACTUAL_NOC from "@salesforce/schema/Case.FEC_Actual_Nature_of_Case__c";

import getCaseFastCashState from "@salesforce/apex/FEC_FastCashCaseController.getCaseFastCashState";
import checkFastCashEligibility from "@salesforce/apex/FEC_FastCashCaseController.checkFastCashEligibility";
import saveFastCashCaseAmounts from "@salesforce/apex/FEC_FastCashCaseController.saveFastCashCaseAmounts";
import executeFastCashBlock from "@salesforce/apex/FEC_FastCashCaseController.executeFastCashBlock";

import FEC_LBL_Fast_Cash_Status from "@salesforce/label/c.FEC_LBL_Fast_Cash_Status";
import FEC_LBL_Fast_Cash_Error_Code from "@salesforce/label/c.FEC_LBL_Fast_Cash_Error_Code";
import FEC_LBL_Fast_Cash_Error_Description from "@salesforce/label/c.FEC_LBL_Fast_Cash_Error_Description";
import FEC_LBL_Fast_Cash_Requested_Amount from "@salesforce/label/c.FEC_LBL_Fast_Cash_Requested_Amount";
import FEC_LBL_Fast_Cash_Max_Amount from "@salesforce/label/c.FEC_LBL_Fast_Cash_Max_Amount";
import FEC_LBL_Fast_Cash_Block_Amount from "@salesforce/label/c.FEC_LBL_Fast_Cash_Block_Amount";
import FEC_LBL_Fast_Cash_Status_Eligible from "@salesforce/label/c.FEC_LBL_Fast_Cash_Status_Eligible";
import FEC_LBL_Fast_Cash_Status_Not_Eligible from "@salesforce/label/c.FEC_LBL_Fast_Cash_Status_Not_Eligible";
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
    FEC_FAST_CASH_STORAGE_BLK_OK_PREFIX
} from "c/fec_CommonConst";
import { formatThousandsFromDigits, stripToIntString } from "c/fec_CommonUtils";

export default class Fec_FastCashCaseForm extends NavigationMixin(LightningElement) {
    @api recordId;

    _isEdit = true;
    @api get isEdit() {
        return this._isEdit;
    }
    set isEdit(value) {
        this._isEdit = Boolean(value);
    }

    customLabel = {
        lblFastCashStatus: FEC_LBL_Fast_Cash_Status,
        lblErrorCode: FEC_LBL_Fast_Cash_Error_Code,
        lblErrorDescription: FEC_LBL_Fast_Cash_Error_Description,
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
        statusEligible: FEC_LBL_Fast_Cash_Status_Eligible,
        statusNotEligible: FEC_LBL_Fast_Cash_Status_Not_Eligible
    };

    @track eligibilityLoading = false;
    @track blockLoading = false;
    @track showConfirmModal = false;

    @track eligible = false;
    @track notEligible = false;
    @track fastCashStatusLabel = STR_EMPTY;
    @track displayErrorCode = STR_EMPTY;
    @track displayErrorDescription = STR_EMPTY;

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

    @wire(getRecord, { recordId: "$recordId", fields: [CASE_ACTUAL_NOC] })
    wiredCase({ data }) {
        if (!this.recordId) {
            return;
        }
        if (!data) {
            return;
        }
        const nocId = getFieldValue(data, CASE_ACTUAL_NOC);
        this.restoreLocksFromStorage();
        if (!nocId) {
            this.resetEligibilityUi();
            this._lastNocId = null;
            return;
        }
        if (this.nocLockedAfterBlockModal) {
            if (!this._lockedViewLoaded) {
                this._lockedViewLoaded = true;
                this._lastNocId = nocId;
                this.loadLockedSnapshot();
            }
            return;
        }
        if (this._lastNocId !== nocId) {
            this._lastNocId = nocId;
            this._lockedViewLoaded = false;
            this.hydrateFromCaseThenEligibility();
        }
    }

    connectedCallback() {
        if (this.recordId) {
            this.restoreLocksFromStorage();
        }
    }

    restoreLocksFromStorage() {
        try {
            if (!this.recordId) {
                return;
            }
            const k = this._storageNocKey();
            if (sessionStorage.getItem(k) === "1") {
                this.nocLockedAfterBlockModal = true;
            }
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

    loadLockedSnapshot() {
        this.clearBlockMessages();
        getCaseFastCashState({ caseId: this.recordId })
            .then((st) => {
                if (st && st.maxAmount != null && Number(st.maxAmount) > 0) {
                    this.eligible = true;
                    this.notEligible = false;
                    this.fastCashStatusLabel = this.customLabel.statusEligible;
                    this.maxAmountDecimal = Number(st.maxAmount);
                }
                if (st && st.requestedAmount != null) {
                    const d = stripToIntString(st.requestedAmount);
                    this.requestedAmountDigits = d;
                    this.requestedAmountDisplay = formatThousandsFromDigits(d);
                }
                if (sessionStorage.getItem(this._storageBlockOkKey()) === "1") {
                    this.blockSucceeded = true;
                    this.showNoti08 = true;
                }
                if (this.blockFailCount >= MAX_FAST_CASH_BLOCK_ATTEMPTS) {
                    this.showNoti10 = true;
                }
            })
            .catch(() => {});
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
        this.fastCashStatusLabel = STR_EMPTY;
        this.displayErrorCode = STR_EMPTY;
        this.displayErrorDescription = STR_EMPTY;
        this.maxAmountDecimal = null;
        this.clearBlockMessages();
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
                    this.fastCashStatusLabel = this.customLabel.statusNotEligible;
                    this.displayErrorCode = STR_EMPTY;
                    this.displayErrorDescription = dto && dto.technicalMessage ? dto.technicalMessage : STR_EMPTY;
                    return;
                }
                if (dto.fastCashStatus === this.customLabel.statusEligible) {
                    this.eligible = true;
                    this.notEligible = false;
                    this.fastCashStatusLabel = this.customLabel.statusEligible;
                    this.displayErrorCode = STR_EMPTY;
                    this.displayErrorDescription = STR_EMPTY;
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
                this.fastCashStatusLabel = this.customLabel.statusNotEligible;
                this.displayErrorCode = dto.errorCode || STR_EMPTY;
                this.displayErrorDescription = dto.errorDescription || STR_EMPTY;
            })
            .catch(() => {
                this.eligibilityLoading = false;
                this.notEligible = true;
                this.eligible = false;
                this.fastCashStatusLabel = this.customLabel.statusNotEligible;
                this.displayErrorCode = STR_EMPTY;
                this.displayErrorDescription = STR_EMPTY;
            });
    }

    get isReadOnly() {
        return this._isEdit === false;
    }

    get showBody() {
        return !!this.recordId && !!this._lastNocId;
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

    get amountFieldsDisabled() {
        return this.isReadOnly || this.blockSucceeded || this.nocLockedAfterBlockModal;
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

    handleRequestedFocus() {
        this.requestedFieldFocused = true;
    }

    handleRequestedAmountChange(event) {
        const digits = stripToIntString(event.target.value);
        this.requestedAmountDigits = digits;
        this.requestedAmountDisplay = formatThousandsFromDigits(digits);
    }

    handleOpenBlockModal() {
        if (this.isReadOnly) {
            return;
        }
        this.showConfirmModal = true;
    }

    applyNocLockAfterModal() {
        this.nocLockedAfterBlockModal = true;
        try {
            sessionStorage.setItem(this._storageNocKey(), "1");
        } catch (e) {
            /* ignore */
        }
        this.dispatchEvent(
            new CustomEvent("fecfastcashnoclocked", {
                bubbles: true,
                composed: true,
                detail: { locked: true, recordId: this.recordId }
            })
        );
    }

    handleConfirmNo() {
        this.showConfirmModal = false;
        this.applyNocLockAfterModal();
    }

    handleConfirmYes() {
        this.showConfirmModal = false;
        this.applyNocLockAfterModal();
        this.executeBlock();
    }

    executeBlock() {
        const n = parseInt(this.requestedAmountDigits, 10);
        if (isNaN(n) || !this.recordId) {
            return;
        }
        this.blockLoading = true;
        this.clearBlockMessages();
        executeFastCashBlock({ caseId: this.recordId, blockAmount: n })
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
                this.blockFailCount += 1;
                try {
                    sessionStorage.setItem(this._storageBlockFailKey(), String(this.blockFailCount));
                } catch (e) {
                    /* ignore */
                }
                if (this.blockFailCount >= MAX_FAST_CASH_BLOCK_ATTEMPTS) {
                    this.finalBlockFailure = true;
                    this.showNoti10 = true;
                    this.navigateToCase();
                } else {
                    this.showNoti09 = true;
                }
            })
            .catch(() => {
                this.blockLoading = false;
                this.blockFailCount += 1;
                try {
                    sessionStorage.setItem(this._storageBlockFailKey(), String(this.blockFailCount));
                } catch (e) {
                    /* ignore */
                }
                if (this.blockFailCount >= MAX_FAST_CASH_BLOCK_ATTEMPTS) {
                    this.finalBlockFailure = true;
                    this.showNoti10 = true;
                    this.navigateToCase();
                } else {
                    this.showNoti09 = true;
                }
            });
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
