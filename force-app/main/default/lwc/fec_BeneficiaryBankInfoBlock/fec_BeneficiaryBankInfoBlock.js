import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getBankNamePicklistOptions from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getBankNamePicklistOptions";
import getProvinceCityPicklistOptions from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getProvinceCityPicklistOptions";
import getBankBranchPicklistOptions from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getBankBranchPicklistOptions";
import getBeneficiaryFormDefaults from "@salesforce/apex/FEC_BeneficiaryBankInfoController.getBeneficiaryFormDefaults";
import saveBeneficiaryBankInfo from "@salesforce/apex/FEC_BeneficiaryBankInfoController.saveBeneficiaryBankInfo";
import FEC_LBL_Beneficiary_Name from "@salesforce/label/c.FEC_LBL_Beneficiary_Name";
import FEC_LBL_Beneficiary_Account from "@salesforce/label/c.FEC_LBL_Beneficiary_Account";
import FEC_LBL_Bank_Name from "@salesforce/label/c.FEC_LBL_Bank_Name";
import FEC_LBL_Bank_Branch from "@salesforce/label/c.FEC_LBL_Bank_Branch";
import FEC_LBL_Province_City from "@salesforce/label/c.FEC_LBL_Province_City";
import FEC_Error_Title from "@salesforce/label/c.FEC_Error_Title";
import FEC_Toast_Save_Success_Title from "@salesforce/label/c.FEC_Toast_Save_Success_Title";
import FEC_Toast_Save_Success from "@salesforce/label/c.FEC_Toast_Save_Success";
import { STR_EMPTY } from "c/fec_CommonConst";
import { toUpperNoVietnameseAccent } from "c/fec_CommonUtils";

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
            this.refreshBranchOptions();
        } else if (error) {
            this.bankBranchOptions = [];
        }
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

    @api
    saveBeneficiaryToCustomerHistory() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this.recordId) {
            return Promise.resolve({ success: false, errorMessage: "Case Id required" });
        }
        if (!this.reportValidity()) {
            return Promise.resolve({ success: false, errorMessage: "Validation failed" });
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