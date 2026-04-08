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
import FEC_MSG_Param_Required from "@salesforce/label/c.FEC_MSG_Param_Required";
import FEC_Toast_Validation_Message from "@salesforce/label/c.FEC_Toast_Validation_Message";
import FEC_Toast_Validation_Title from "@salesforce/label/c.FEC_Toast_Validation_Title";
import { STR_EMPTY } from "c/fec_CommonConst";
import { toUpperNoVietnameseAccent } from "c/fec_CommonUtils";

const DRAFT_KEY_PREFIX = "fec-beneficiary-bank-draft-";

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
    @track isBusy = false;
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

    @wire(getBankNamePicklistOptions)
    wiredBanks({ data, error }) {
        if (data) {
            this.bankOptions = data.map((r) => ({ label: r.label, value: r.value }));
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

    @wire(getBeneficiaryFormDefaults, { caseId: "$recordId" })
    wiredFormDefaults({ data, error }) {
        if (data) {
            this.beneficiaryName = data.beneficiaryName || data.defaultBeneficiaryUpperNoAccent || STR_EMPTY;
            this.beneficiaryAccount = data.beneficiaryAccount || STR_EMPTY;
            this.bankComboValue = data.bankPicklistValue || STR_EMPTY;
            this.bankBranch = data.bankBranch || STR_EMPTY;
            this.provinceComboValue = data.provinceCity || STR_EMPTY;
            this.refreshBranchOptions().then(() => {
                this.applyLocalDraftIfAny();
            });
        } else if (error) {
            this.bankBranchOptions = [];
        }
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
        }
        if (draft.bankBranch != null) {
            this.bankBranch = draft.bankBranch;
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
            })
            .catch(() => {
                this.bankBranchOptions = [];
            });
    }

    handleBeneficiaryInput(event) {
        this.beneficiaryName = toUpperNoVietnameseAccent(event.target.value);
    }

    handleBeneficiaryAccountInput(event) {
        this.beneficiaryAccount = event.target.value;
    }

    handleBankComboChange(event) {
        this.bankComboValue = event.detail.value;
        this.bankBranch = STR_EMPTY;
        this.refreshBranchOptions();
    }

    handleBankBranchInput(event) {
        this.bankBranch = event.detail.value;
    }

    handleProvinceChange(event) {
        this.provinceComboValue = event.detail.value;
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
        const fields = [...this.template.querySelectorAll("lightning-input"), ...this.template.querySelectorAll("lightning-combobox")];
        let ok = true;
        fields.forEach((el) => {
            if (typeof el.reportValidity === "function" && !el.reportValidity()) {
                ok = false;
            }
        });
        return ok;
    }

    /** Submit Case: khi block có dữ liệu thì validate đủ trường bắt buộc. */
    @api
    validateForSubmit() {
        if (this.isReadOnly) {
            return true;
        }
        if (!this._shouldRunBeneficiaryDraftOrSubmit()) {
            return true;
        }
        if (!this.reportValidity()) {
            this.showToast(FEC_Toast_Validation_Title, FEC_Toast_Validation_Message, "warning");
            return false;
        }
        return true;
    }

    /** Save & Close: localStorage + Apex nháp khi có ít nhất một trường có giá trị. */
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
                    return Promise.reject(new Error("fec_beneficiary_save_dto"));
                }
                return Promise.reject(new Error("fec_beneficiary_save_dto"));
            })
            .catch((error) => {
                if (error && error.message === "fec_beneficiary_save_dto") {
                    return Promise.reject(error);
                }
                this.showToast(FEC_Error_Title, this.handleError(error), "error");
                return Promise.reject(error);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    @api
    saveBeneficiaryToCustomerHistory() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this.recordId) {
            return Promise.resolve({
                success: false,
                errorMessage: FEC_MSG_Param_Required.replace("{0}", "Case Id")
            });
        }
        if (!this.reportValidity()) {
            return Promise.resolve({
                success: false,
                errorMessage: FEC_Toast_Validation_Message
            });
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
                } else if (res && res.errorMessage) {
                    this.showToast(FEC_Error_Title, res.errorMessage, "error");
                }
                return res;
            })
            .catch((error) => {
                this.showToast(FEC_Error_Title, this.handleError(error), "error");
                return { success: false, errorMessage: this.handleError(error) };
            })
            .finally(() => {
                this.isBusy = false;
            });
    }
}