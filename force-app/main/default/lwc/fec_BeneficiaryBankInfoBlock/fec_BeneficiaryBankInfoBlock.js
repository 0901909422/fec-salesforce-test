import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getBankNamePicklistOptions from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getBankNamePicklistOptions";
import getProvinceCityPicklistOptions from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getProvinceCityPicklistOptions";
import getBankBranchPicklistOptions from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getBankBranchPicklistOptions";
import getBeneficiaryFormDefaults from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getBeneficiaryFormDefaults";
import saveBeneficiaryBankInfo from "@salesforce/apex/FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo";
import saveBeneficiaryBankInfoDraft from "@salesforce/apex/FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfoDraft";
import FEC_LBL_Beneficiary_Name from "@salesforce/label/c.FEC_LBL_Beneficiary_Name";
import FEC_LBL_Beneficiary_Account from "@salesforce/label/c.FEC_LBL_Beneficiary_Account";
import FEC_LBL_Bank_Name from "@salesforce/label/c.FEC_LBL_Bank_Name";
import FEC_LBL_Bank_Branch from "@salesforce/label/c.FEC_LBL_Bank_Branch";
import FEC_LBL_Province_City from "@salesforce/label/c.FEC_LBL_Province_City";
import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";
import FEC_Toast_Save_Success_Title from "@salesforce/label/c.FEC_Toast_Save_Success_Title";
import FEC_Toast_Save_Success from "@salesforce/label/c.FEC_Toast_Save_Success";
import FEC_Toast_Validation_Message from "@salesforce/label/c.FEC_Toast_Validation_Message";
import FEC_Toast_Validation_Title from "@salesforce/label/c.FEC_Toast_Validation_Title";
import { STR_EMPTY } from "c/fec_CommonConst";
import { toUpperNoVietnameseAccent } from "c/fec_CommonUtils";

const DRAFT_KEY_PREFIX = "fec-beneficiary-bank-draft-";
const ERR_BENEFICIARY_SAVE_ALREADY_TOASTED = "Beneficiary Save Error";

export default class Fec_BeneficiaryBankInfoBlock extends LightningElement {
    @api recordId;
    @api isEdit;
    @track beneficiaryName = STR_EMPTY;
    @track beneficiaryAccount = STR_EMPTY;
    @track bankComboValue = STR_EMPTY;
    @track bankBranch = STR_EMPTY;
    @track provinceComboValue = STR_EMPTY;
    @track bankOptions = [];
    @track provinceOptions = [];
    @track bankBranchOptions = [];
    @track isBankManualInput = false;
    @track isBankBranchManualInput = false;
    @track isBusy = false;
    shouldFocusBankManualInput = false;
    shouldFocusBranchManualInput = false;
    customLabel = {
        beneficiaryName: FEC_LBL_Beneficiary_Name,
        beneficiaryAccount: FEC_LBL_Beneficiary_Account,
        bankName: FEC_LBL_Bank_Name,
        bankBranch: FEC_LBL_Bank_Branch,
        provinceCity: FEC_LBL_Province_City
    };

    get isReadOnly() {
        return this.isEdit === false;
    }

    get comboRequired() {
        return !this.isReadOnly;
    }

    get bankOptionsJson() {
        return JSON.stringify(this.bankOptions || []);
    }

    get bankBranchOptionsJson() {
        return JSON.stringify(this.bankBranchOptions || []);
    }

    get provinceOptionsJson() {
        return JSON.stringify(this.provinceOptions || []);
    }

    @wire(getBankNamePicklistOptions)
    wiredBanks({ data, error }) {
        if (data) {
            this.bankOptions = data.map((r) => ({ label: r.label, value: r.value }));
            this._syncBankInputMode();
        } else if (error) {
            this.bankOptions = [];
        }
    }

    @wire(getProvinceCityPicklistOptions)
    wiredProvinces({ data, error }) {
        if (data) {
            this.provinceOptions = data.map((r) => ({ label: r.label, value: r.value }));
        } else if (error) {
            this.provinceOptions = [];
        }
    }

    connectedCallback() {
        this._loadBeneficiaryFormDefaults();
    }

    renderedCallback() {
        if (this.shouldFocusBankManualInput) {
            this.shouldFocusBankManualInput = false;
            const bankInput = this.template.querySelector('lightning-input[data-id="bank-manual-input"]');
            if (bankInput && typeof bankInput.focus === "function") {
                bankInput.focus();
            }
        }
        if (this.shouldFocusBranchManualInput) {
            this.shouldFocusBranchManualInput = false;
            const branchInput = this.template.querySelector('lightning-input[data-id="branch-manual-input"]');
            if (branchInput && typeof branchInput.focus === "function") {
                branchInput.focus();
            }
        }
    }

    _loadBeneficiaryFormDefaults() {
        if (!this.recordId) {
            return;
        }
        const caseId = this.recordId;
        getBeneficiaryFormDefaults({ caseId: caseId })
            .then((data) => {
                if (this.recordId !== caseId) {
                    return;
                }
                if (data) {
                    this.beneficiaryName = data.beneficiaryName || data.defaultBeneficiaryUpperNoAccent || STR_EMPTY;
                    this.beneficiaryAccount = data.beneficiaryAccount || STR_EMPTY;
                    this.bankComboValue = data.bankPicklistValue || STR_EMPTY;
                    this.bankBranch = data.bankBranch || STR_EMPTY;
                    this.provinceComboValue = data.provinceCity || STR_EMPTY;
                    this.refreshBranchOptions().then(() => {
                        this._syncBankInputMode();
                        this._syncBankBranchInputMode();
                        this.applyLocalDraftIfAny();
                    });
                }
            })
            .catch(() => {
                this.bankBranchOptions = [];
            });
    }

    get draftStorageKey() {
        if (!this.recordId) {
            return null;
        }
        return DRAFT_KEY_PREFIX + this.recordId;
    }

    readLocalDraft() {
        const key = this.draftStorageKey;
        if (!key) {
            return null;
        }
        try {
            const raw = window.localStorage.getItem(key);
            if (!raw) {
                return null;
            }
            return JSON.parse(raw);
        } catch (e) {
            return null;
        }
    }

    writeLocalDraft() {
        const key = this.draftStorageKey;
        if (!key) {
            return;
        }
        const v = this.getFieldValues();
        const payload = {
            beneficiaryName: v.beneficiaryName || STR_EMPTY,
            beneficiaryAccount: v.beneficiaryAccount || STR_EMPTY,
            bankPicklistValue: v.bankPicklistValue || STR_EMPTY,
            bankBranch: v.bankBranch || STR_EMPTY,
            provinceCity: v.provinceCity || STR_EMPTY
        };
        try {
            window.localStorage.setItem(key, JSON.stringify(payload));
        } catch (e) {
            // no-op
        }
    }

    clearLocalDraft() {
        const key = this.draftStorageKey;
        if (!key) {
            return;
        }
        try {
            window.localStorage.removeItem(key);
        } catch (e) {
            // no-op
        }
    }

    applyLocalDraftIfAny() {
        const draft = this.readLocalDraft();
        if (!draft) {
            return;
        }
        if (draft.beneficiaryName != null) {
            this.beneficiaryName = draft.beneficiaryName;
        }
        if (draft.beneficiaryAccount != null) {
            this.beneficiaryAccount = draft.beneficiaryAccount;
        }
        if (draft.bankPicklistValue != null) {
            this.bankComboValue = draft.bankPicklistValue;
            this._syncBankInputMode();
        }
        if (draft.bankBranch != null) {
            this.bankBranch = draft.bankBranch;
            this._syncBankBranchInputMode();
        }
        if (draft.provinceCity != null) {
            this.provinceComboValue = draft.provinceCity;
        }
        this.refreshBranchOptions();
    }

    _shouldRunBeneficiaryDraftOrSubmit() {
        const v = this.getFieldValues();
        const nz = (s) => !!(s && String(s).trim());
        return nz(v.beneficiaryName) || nz(v.beneficiaryAccount) || nz(v.bankPicklistValue) || nz(v.bankBranch) || nz(v.provinceCity);
    }

    refreshBranchOptions() {
        const bank = this.bankComboValue;
        if (!bank) {
            this.bankBranchOptions = [];
            return Promise.resolve();
        }
        return getBankBranchPicklistOptions({ bankNameNoaccent: bank })
            .then((list) => {
                this.bankBranchOptions = (list || []).map((r) => ({ label: r.label, value: r.value }));
                this._syncBankBranchInputMode();
            })
            .catch(() => {
                this.bankBranchOptions = [];
                this._syncBankBranchInputMode();
            });
    }

    _hasPicklistOption(options, value) {
        if (!value) {
            return false;
        }
        return (options || []).some((o) => o && o.value === value);
    }

    _hasPicklistOptionByText(options, value) {
        if (!value) {
            return false;
        }
        const normalizedValue = toUpperNoVietnameseAccent(value).trim();
        return (options || []).some((o) => o && (toUpperNoVietnameseAccent(o.value || STR_EMPTY).trim().includes(normalizedValue) || toUpperNoVietnameseAccent(o.label || STR_EMPTY).trim().includes(normalizedValue)));
    }

    _syncBankInputMode() {
        this.isBankManualInput = !!(this.bankComboValue && !this._hasPicklistOption(this.bankOptions, this.bankComboValue));
    }

    _syncBankBranchInputMode() {
        this.isBankBranchManualInput = !!(this.bankBranch && !this._hasPicklistOption(this.bankBranchOptions, this.bankBranch));
    }

    handleBeneficiaryInput(event) {
        this.beneficiaryName = toUpperNoVietnameseAccent(event.target.value);
    }

    handleBeneficiaryAccountInput(event) {
        this.beneficiaryAccount = event.target.value;
    }

    _clearPickCombo(pick) {
        Promise.resolve().then(() => {
            const el = this.template.querySelector("c-fec_-combo-box[data-pick=\"" + pick + "\"]");
            if (el && typeof el.clear === "function") {
                el.clear();
            }
        });
    }

    handleBankPickFromCombo(event) {
        const v = event.detail.value;
        if (!v) {
            return;
        }
        if (!this._hasPicklistOption(this.bankOptions, v)) {
            this.isBankManualInput = true;
            this.bankComboValue = toUpperNoVietnameseAccent(v);
            return;
        }
        const prev = this.bankComboValue;
        this.isBankManualInput = false;
        this.bankComboValue = v;
        if (v !== prev) {
            this.bankBranch = STR_EMPTY;
            this.isBankBranchManualInput = false;
            this._clearPickCombo("branch");
            this.refreshBranchOptions();
        }
    }

    handleBankRemove() {
        this.bankComboValue = STR_EMPTY;
        this.bankBranch = STR_EMPTY;
        this.bankBranchOptions = [];
        this.isBankManualInput = false;
        this.isBankBranchManualInput = false;
        this._clearPickCombo("branch");
    }

    handleBankBranchPickFromCombo(event) {
        const v = event.detail.value;
        if (!v) {
            return;
        }
        if (!this._hasPicklistOption(this.bankBranchOptions, v)) {
            this.isBankBranchManualInput = true;
            this.bankBranch = toUpperNoVietnameseAccent(v);
            return;
        }
        this.isBankBranchManualInput = false;
        this.bankBranch = v;
    }

    handleBankBranchRemove() {
        this.bankBranch = STR_EMPTY;
        this.isBankBranchManualInput = false;
    }

    handleBankSearchChange(event) {
        const inputValue = event.detail.value;
        if (!inputValue) {
            return;
        }
        if (this._hasPicklistOptionByText(this.bankOptions, inputValue)) {
            return;
        }
        this.isBankManualInput = true;
        this.shouldFocusBankManualInput = true;
        this.bankComboValue = toUpperNoVietnameseAccent(inputValue);
        this.bankBranch = STR_EMPTY;
        this.isBankBranchManualInput = false;
        this.bankBranchOptions = [];
        this._clearPickCombo("branch");
    }

    handleBankBranchSearchChange(event) {
        const inputValue = event.detail.value;
        if (!inputValue) {
            return;
        }
        if (this._hasPicklistOptionByText(this.bankBranchOptions, inputValue)) {
            return;
        }
        this.isBankBranchManualInput = true;
        this.shouldFocusBranchManualInput = true;
        this.bankBranch = toUpperNoVietnameseAccent(inputValue);
    }

    handleProvincePickFromCombo(event) {
        const v = event.detail.value;
        if (!v) {
            return;
        }
        this.provinceComboValue = v;
    }

    handleProvinceRemove() {
        this.provinceComboValue = STR_EMPTY;
    }

    handleBankInput(event) {
        const v = toUpperNoVietnameseAccent(event.target.value);
        this.bankComboValue = v;
        if (!v) {
            this.isBankManualInput = false;
            this.bankBranch = STR_EMPTY;
            this.isBankBranchManualInput = false;
            this.bankBranchOptions = [];
            this._clearPickCombo("branch");
            return;
        }
        this.isBankManualInput = true;
    }

    handleBankBranchInput(event) {
        const v = toUpperNoVietnameseAccent(event.target.value);
        this.bankBranch = v;
        this.isBankBranchManualInput = !!v;
    }

    handleError(error) {
        let msg = "";
        if (Array.isArray(error?.body)) {
            msg = error.body.map((e) => e.message).join(", ");
        } else if (typeof error?.body?.message === "string") {
            msg = error.body.message;
        }
        return msg;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    @api
    getFieldValues() {
        return {
            beneficiaryName: this.beneficiaryName,
            beneficiaryAccount: this.beneficiaryAccount,
            bankPicklistValue: this.bankComboValue,
            bankBranch: this.bankBranch,
            provinceCity: this.provinceComboValue
        };
    }

    @api
    reportValidity() {
        if (this.isReadOnly) {
            return true;
        }
        const fields = [...this.template.querySelectorAll("lightning-input")];
        const combos = [...this.template.querySelectorAll("c-fec_-combo-box")];
        let ok = true;
        fields.forEach((el) => {
            if (typeof el.reportValidity === "function" && !el.reportValidity()) {
                ok = false;
            }
        });
        combos.forEach((el) => {
            if (typeof el.reportValidity === "function" && !el.reportValidity()) {
                ok = false;
            }
        });
        if (!ok) {
            return false;
        }
        return true;
    }

    /** Submit Case: khi block có dữ liệu thì validate đủ trường bắt buộc. */
    @api
    validateForSubmit() {
        if (this.isReadOnly) {
            return true;
        }
        if (!this.reportValidity()) {
            this.showToast(FEC_Toast_Validation_Title, FEC_Toast_Validation_Message, "warning");
            return false;
        }
        return true;
    }

    /** Save & Close: localStorage + Apex nháp (Case) khi có ít nhất một trường có giá trị. */
    @api
    saveDraftIfApplicable() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this.recordId) {
            return Promise.resolve();
        }
        if (!this._shouldRunBeneficiaryDraftOrSubmit()) {
            return Promise.resolve();
        }
        this.writeLocalDraft();
        const v = this.getFieldValues();
        return saveBeneficiaryBankInfoDraft({
            caseId: this.recordId,
            beneficiaryName: v.beneficiaryName,
            beneficiaryAccount: v.beneficiaryAccount,
            bankPicklistValue: v.bankPicklistValue,
            bankBranch: v.bankBranch,
            provinceCity: v.provinceCity
        });
    }

    /** Submit: gọi Apex lưu đủ khi block có dữ liệu; reject khi validation/Apex lỗi. */
    @api
    saveBeneficiaryIfApplicable() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this._shouldRunBeneficiaryDraftOrSubmit()) {
            return Promise.resolve();
        }
        if (!this.recordId) {
            return Promise.reject(new Error("caseId"));
        }
        if (!this.reportValidity()) {
            this.showToast(FEC_Toast_Validation_Title, FEC_Toast_Validation_Message, "warning");
            return Promise.reject(new Error("validation"));
        }
        const v = this.getFieldValues();
        this.isBusy = true;
        return saveBeneficiaryBankInfo({
            caseId: this.recordId,
            beneficiaryName: v.beneficiaryName,
            beneficiaryAccount: v.beneficiaryAccount,
            bankPicklistValue: v.bankPicklistValue,
            bankBranch: v.bankBranch,
            provinceCity: v.provinceCity
        })
            .then((res) => {
                if (res && res.success) {
                    this.clearLocalDraft();
                    this.showToast(FEC_Toast_Save_Success_Title, FEC_Toast_Save_Success, "success");
                    return res;
                }
                if (res && res.errorMessage) {
                    this.showToast(FEC_Error_Title, res.errorMessage, "error");
                    return Promise.reject(new Error(ERR_BENEFICIARY_SAVE_ALREADY_TOASTED));
                }
                return Promise.reject(new Error(ERR_BENEFICIARY_SAVE_ALREADY_TOASTED));
            })
            .catch((error) => {
                if (error && error.message === ERR_BENEFICIARY_SAVE_ALREADY_TOASTED) {
                    return Promise.reject(error);
                }
                this.showToast(FEC_Error_Title, this.handleError(error), "error");
                return Promise.reject(error);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }
}