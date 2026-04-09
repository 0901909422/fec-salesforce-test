import { LightningElement, api, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getExistingReceiptLines from "@salesforce/apex/FEC_RefundRequestController.getExistingReceiptLines";
import saveRefundRequest from "@salesforce/apex/FEC_RefundRequestController.saveRefundRequest";
import FEC_LBL_Add_Item from "@salesforce/label/c.FEC_LBL_Add_Item";
import FEC_LBL_Remove_Row from "@salesforce/label/c.FEC_LBL_Remove_Row";
import FEC_LBL_Refund_Amount from "@salesforce/label/c.FEC_LBL_Refund_Amount";
import FEC_LBL_Receipt_Date from "@salesforce/label/c.FEC_LBL_Receipt_Date";
import FEC_LBL_Receipt_Amount from "@salesforce/label/c.FEC_LBL_Receipt_Amount";
import FEC_LBL_Transaction_No from "@salesforce/label/c.FEC_LBL_Transaction_No";
import FEC_Repay_Payment_Channel_Label from "@salesforce/label/c.FEC_Repay_Payment_Channel_Label";
import FEC_MSG_Refund_Request_Refund_Amount_Positive from "@salesforce/label/c.FEC_MSG_Refund_Request_Refund_Amount_Positive";
import { STR_EMPTY } from "c/fec_CommonConst";
import { formatThousandsFromDigits, stripToIntString, todayIso } from "c/fec_CommonUtils";

const MSG_REFUND_RECEIPT_AMOUNT_POSITIVE =
    "Vui lòng nhập số tiền biên lai lớn hơn 0.";
const MSG_REFUND_REQUEST_RECEIPT_DATE_FUTURE =
    "Ngày biên lai không được lớn hơn ngày hiện tại.";

let rowSeq = 0;

export default class Fec_RefundRequestForm extends LightningElement {
    @api recordId;
    @api isEdit;

    @track manualRefundAmountDisplay = STR_EMPTY;
    @track receiptRows = [];

    _existingReceiptLinesWireResult;

    customLabel = {
        refundAmount: FEC_LBL_Refund_Amount,
        receiptDate: FEC_LBL_Receipt_Date,
        receiptAmount: FEC_LBL_Receipt_Amount,
        transactionNo: FEC_LBL_Transaction_No,
        paymentChannel: FEC_Repay_Payment_Channel_Label,
        removeRow: FEC_LBL_Remove_Row
    };

    get addItemLabel() {
        return FEC_LBL_Add_Item;
    }

    get isReadOnly() {
        return this.isEdit === false;
    }

    @wire(getExistingReceiptLines, { caseId: "$recordId" })
    wiredReceiptLines(result) {
        this._existingReceiptLinesWireResult = result;
        const { data, error } = result;
        if (data) {
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
        } else if (error) {
            this.receiptRows = [];
        }
    }

    get maxDateIso() {
        return todayIso();
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

    @api
    validateRefund() {
        if (this.isReadOnly) {
            return true;
        }
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

        const refundAmtEl = root.querySelector('lightning-input[data-input="refundAmount"]');
        if (refundAmtEl && typeof refundAmtEl.setCustomValidity === "function") {
            const refundDigits = stripToIntString(this.manualRefundAmountDisplay);
            if (refundDigits !== STR_EMPTY) {
                const refundNum = parseInt(refundDigits, 10);
                if (isNaN(refundNum) || refundNum <= 0) {
                    refundAmtEl.setCustomValidity(FEC_MSG_Refund_Request_Refund_Amount_Positive);
                }
            }
        }

        let ok = true;
        if (!this.hasReceiptRows) {
            ok = false;
        }
        root.querySelectorAll("lightning-input").forEach((el) => {
            if (typeof el.reportValidity === "function" && !el.reportValidity()) {
                ok = false;
            }
        });
        return ok;
    }

    @api
    saveRefundDataIfVisible() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
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
            receiptLines: lines
        }).then((res) => {
            if (!res || !res.success) {
                return Promise.reject(new Error((res && res.errorMessage) || "Save failed"));
            }
            if (this._existingReceiptLinesWireResult) {
                return refreshApex(this._existingReceiptLinesWireResult);
            }
            return Promise.resolve();
        });
    }
}