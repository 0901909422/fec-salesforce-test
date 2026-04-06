import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getRefundFormDefaults from "@salesforce/apex/FEC_RefundRequestController.getRefundFormDefaults";
import getExistingReceiptLines from "@salesforce/apex/FEC_RefundRequestController.getExistingReceiptLines";
import getBankNamePicklistOptions from "@salesforce/apex/FEC_RefundRequestController.getBankNamePicklistOptions";
import getProvinceCityOptions from "@salesforce/apex/FEC_RefundRequestController.getProvinceCityOptions";
import getBankBranchOptions from "@salesforce/apex/FEC_RefundRequestController.getBankBranchOptions";
import saveRefundRequest from "@salesforce/apex/FEC_RefundRequestController.saveRefundRequest";
import FEC_LBL_Add_Item from "@salesforce/label/c.FEC_LBL_Add_Item";
import FEC_LBL_Remove_Row from "@salesforce/label/c.FEC_LBL_Remove_Row";
import FEC_LBL_Refund_Amount from "@salesforce/label/c.FEC_LBL_Refund_Amount";
import FEC_LBL_Receipt_Date from "@salesforce/label/c.FEC_LBL_Receipt_Date";
import FEC_LBL_Receipt_Amount from "@salesforce/label/c.FEC_LBL_Receipt_Amount";
import FEC_LBL_Transaction_No from "@salesforce/label/c.FEC_LBL_Transaction_No";
import FEC_Repay_Payment_Channel_Label from "@salesforce/label/c.FEC_Repay_Payment_Channel_Label";
import FEC_LBL_Beneficiary_Name from "@salesforce/label/c.FEC_LBL_Beneficiary_Name";
import FEC_LBL_Beneficiary_Account from "@salesforce/label/c.FEC_LBL_Beneficiary_Account";
import FEC_LBL_Bank_Name from "@salesforce/label/c.FEC_LBL_Bank_Name";
import FEC_LBL_Bank_Branch from "@salesforce/label/c.FEC_LBL_Bank_Branch";
import FEC_LBL_Province_City from "@salesforce/label/c.FEC_LBL_Province_City";
import { STR_EMPTY } from "c/fec_CommonConst";
import { formatThousandsFromDigits, stripToIntString, todayIso, toUpperNoVietnameseAccent } from "c/fec_CommonUtils";

const MSG_REFUND_RECEIPT_AMOUNT_POSITIVE =
    "Vui lòng nhập số tiền biên lai lớn hơn 0.";
const MSG_REFUND_REQUEST_RECEIPT_DATE_FUTURE =
    "Ngày biên lai không được lớn hơn ngày hiện tại.";

let rowSeq = 0;

export default class Fec_RefundRequestForm extends LightningElement {
    @api recordId;

    @track manualRefundAmountDisplay = STR_EMPTY;
    @track receiptRows = [];
    @track beneficiaryName = STR_EMPTY;
    @track beneficiaryAccount = STR_EMPTY;
    @track bankComboValue = STR_EMPTY;
    @track bankBranch = STR_EMPTY;
    @track provinceComboValue = STR_EMPTY;
    @track bankOptions = [];
    @track provinceOptions = [];
    @track bankBranchOptions = [];
    @track formLocked = false;

    _wiredDefaults;

    customLabel = {
        refundAmount: FEC_LBL_Refund_Amount,
        receiptDate: FEC_LBL_Receipt_Date,
        receiptAmount: FEC_LBL_Receipt_Amount,
        transactionNo: FEC_LBL_Transaction_No,
        paymentChannel: FEC_Repay_Payment_Channel_Label,
        beneficiaryName: FEC_LBL_Beneficiary_Name,
        beneficiaryAccount: FEC_LBL_Beneficiary_Account,
        bankName: FEC_LBL_Bank_Name,
        bankBranch: FEC_LBL_Bank_Branch,
        provinceCity: FEC_LBL_Province_City,
        removeRow: FEC_LBL_Remove_Row
    };

    get addItemLabel() {
        return FEC_LBL_Add_Item;
    }

    get msgReceiptDateFuture() {
        return MSG_REFUND_REQUEST_RECEIPT_DATE_FUTURE;
    }

    @wire(getBankNamePicklistOptions)
    wiredBanks({ data, error }) {
        if (data) {
            this.bankOptions = data.map((r) => ({ label: r.label, value: r.value }));
        } else if (error) {
            this.bankOptions = [];
        }
    }

    @wire(getProvinceCityOptions)
    wiredProvinces({ data, error }) {
        if (data) {
            this.provinceOptions = data.map((r) => ({ label: r.label, value: r.value }));
        } else if (error) {
            this.provinceOptions = [];
        }
    }

    @wire(getBankBranchOptions)
    wiredBankBranches({ data, error }) {
        if (data) {
            this.bankBranchOptions = data.map((r) => ({ label: r.label, value: r.value }));
        } else if (error) {
            this.bankBranchOptions = [];
        }
    }

    @wire(getRefundFormDefaults, { caseId: "$recordId" })
    wiredFormDefaults(result) {
        this._wiredDefaults = result;
        const { data, error } = result;
        if (data) {
            this.beneficiaryName = data.beneficiaryName || data.defaultBeneficiaryUpperNoAccent || STR_EMPTY;
            this.beneficiaryAccount = data.beneficiaryAccount || STR_EMPTY;
            this.bankComboValue = data.bankPicklistValue || STR_EMPTY;
            this.bankBranch = data.bankBranch || STR_EMPTY;
            this.provinceComboValue = data.provinceCity || STR_EMPTY;
            this.hydrateReceiptLinesFromServer();
        } else if (error) {
            this.receiptRows = [];
        }
    }

    hydrateReceiptLinesFromServer() {
        if (!this.recordId) {
            return;
        }
        getExistingReceiptLines({ caseId: this.recordId })
            .then((data) => {
                if (!data || data.length === 0) {
                    this.receiptRows = [];
                    return;
                }
                this.receiptRows = data.map((line) => {
                    rowSeq += 1;
                    const digits =
                        line.receiptAmount != null
                            ? String(Math.round(Number(line.receiptAmount))).replace(/\D/g, "")
                            : STR_EMPTY;
                    return {
                        rowId: "r-" + rowSeq,
                        receiptDateIso: line.receiptDateIso || null,
                        receiptAmountDigits: digits,
                        receiptAmountDisplay: formatThousandsFromDigits(digits),
                        transactionNo: line.transactionNo || STR_EMPTY,
                        paymentChannel: line.paymentChannel || STR_EMPTY
                    };
                });
            })
            .catch(() => {
                this.receiptRows = [];
            });
    }

    get maxDateIso() {
        return todayIso();
    }

    get computedRefundTotalDisplay() {
        if (!this.receiptRows || this.receiptRows.length === 0) {
            return STR_EMPTY;
        }
        let sum = 0;
        this.receiptRows.forEach((row) => {
            if (row.receiptAmountDigits) {
                const n = parseInt(row.receiptAmountDigits, 10);
                if (!isNaN(n)) {
                    sum += n;
                }
            }
        });
        if (sum === 0) {
            return STR_EMPTY;
        }
        return formatThousandsFromDigits(String(sum));
    }

    get hasReceiptRows() {
        return Array.isArray(this.receiptRows) && this.receiptRows.length > 0;
    }

    handleAddItem() {
        rowSeq += 1;
        this.receiptRows = [
            ...this.receiptRows,
            {
                rowId: "r-" + rowSeq,
                receiptDateIso: null,
                receiptAmountDigits: STR_EMPTY,
                receiptAmountDisplay: STR_EMPTY,
                transactionNo: STR_EMPTY,
                paymentChannel: STR_EMPTY
            }
        ];
    }

    handleDeleteRow(event) {
        const id = event.currentTarget.dataset.rowId;
        this.receiptRows = this.receiptRows.filter((r) => r.rowId !== id);
    }

    handleRowDateChange(event) {
        const id = event.currentTarget.dataset.rowId;
        const val = event.target.value;
        this.receiptRows = this.receiptRows.map((r) => {
            if (r.rowId !== id) {
                return r;
            }
            const next = {
                ...r,
                receiptDateIso: val || null
            };
            return next;
        });
    }

    handleRowAmountInput(event) {
        const id = event.currentTarget.dataset.rowId;
        const digits = stripToIntString(event.target.value);
        this.receiptRows = this.receiptRows.map((r) => {
            if (r.rowId !== id) {
                return r;
            }
            return {
                ...r,
                receiptAmountDigits: digits,
                receiptAmountDisplay: formatThousandsFromDigits(digits)
            };
        });
    }

    handleRowTransactionInput(event) {
        const id = event.currentTarget.dataset.rowId;
        const val = event.target.value;
        this.receiptRows = this.receiptRows.map((r) => (r.rowId === id ? { ...r, transactionNo: val } : r));
    }

    handleRowPaymentChannelInput(event) {
        const id = event.currentTarget.dataset.rowId;
        const val = event.target.value;
        this.receiptRows = this.receiptRows.map((r) => (r.rowId === id ? { ...r, paymentChannel: val } : r));
    }

    handleRefundAmountInput(event) {
        const digits = stripToIntString(event.target.value);
        this.manualRefundAmountDisplay = formatThousandsFromDigits(digits);
    }

    handleBeneficiaryInput(event) {
        this.beneficiaryName = toUpperNoVietnameseAccent(event.target.value);
    }

    handleBeneficiaryAccountInput(event) {
        this.beneficiaryAccount = event.target.value;
    }

    handleBankComboChange(event) {
        this.bankComboValue = event.detail.value;
    }

    handleBankBranchInput(event) {
        this.bankBranch = event.detail.value;
    }

    handleProvinceChange(event) {
        this.provinceComboValue = event.detail.value;
    }

    @api
    validateRefund() {
        const root = this.template;

        root.querySelectorAll("lightning-input").forEach((el) => {
            if (typeof el.setCustomValidity === "function") {
                el.setCustomValidity("");
            }
        });

        let sumAmt = 0;
        this.receiptRows.forEach((row) => {
            if (row.receiptAmountDigits) {
                sumAmt += parseInt(row.receiptAmountDigits, 10) || 0;
            }
        });
        const firstAmtEl = root.querySelector('lightning-input[data-input="receiptAmount"]');
        if (firstAmtEl && typeof firstAmtEl.setCustomValidity === "function") {
            if (this.receiptRows.length > 0 && sumAmt <= 0) {
                firstAmtEl.setCustomValidity(MSG_REFUND_RECEIPT_AMOUNT_POSITIVE);
            }
        }
        this.receiptRows.forEach((row) => {
            const dateEl = root.querySelector('lightning-input[data-input="receiptDate"][data-row-id="' + row.rowId + '"]');
            if (!dateEl || typeof dateEl.setCustomValidity !== "function") {
                return;
            }
            if (row.receiptDateIso > todayIso()) {
                dateEl.setCustomValidity(MSG_REFUND_REQUEST_RECEIPT_DATE_FUTURE);
            }
        });

        let ok = true;
        if (!this.hasReceiptRows) {
            ok = false;
        }
        const fields = [
            ...root.querySelectorAll("lightning-input"),
            ...root.querySelectorAll("lightning-combobox")
        ];
        fields.forEach((el) => {
            if (typeof el.reportValidity === "function" && !el.reportValidity()) {
                ok = false;
            }
        });
        return ok;
    }

    @api
    saveRefundDataIfVisible() {
        if (!this.recordId) {
            return Promise.resolve();
        }
        const refundAmountDigits = stripToIntString(this.manualRefundAmountDisplay);
        const refundAmount = refundAmountDigits ? parseInt(refundAmountDigits, 10) : null;
        const lines = this.receiptRows.map((row) => ({
            receiptDateIso: row.receiptDateIso,
            receiptAmount: row.receiptAmountDigits ? parseInt(row.receiptAmountDigits, 10) : null,
            transactionNo: row.transactionNo,
            paymentChannel: row.paymentChannel
        }));
        return saveRefundRequest({
            caseId: this.recordId,
            refundAmount: refundAmount,
            receiptLines: lines,
            beneficiaryName: this.beneficiaryName,
            beneficiaryAccount: this.beneficiaryAccount,
            bankPicklistValue: this.bankComboValue || null,
            bankBranch: this.bankBranch,
            provinceCity: this.provinceComboValue
        }).then((res) => {
            if (!res || !res.success) {
                return Promise.reject(new Error((res && res.errorMessage) || "Save failed"));
            }
            this.formLocked = true;
            if (this._wiredDefaults) {
                return refreshApex(this._wiredDefaults).then(() => this.hydrateReceiptLinesFromServer());
            }
            return this.hydrateReceiptLinesFromServer();
        });
    }
}
