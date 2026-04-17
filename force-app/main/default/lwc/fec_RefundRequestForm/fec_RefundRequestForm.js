/****************************************************************************************
 * File Name    : fec_RefundRequestForm.js
 * Description  : Refund Request — same row pattern as fec_IncorrectPaymentForm adjustments (numeric id, data-id-value, findIndex + spread).
 ****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRefundRequestData from '@salesforce/apex/FEC_RefundRequestController.getRefundRequestData';
import saveRefundRequest from '@salesforce/apex/FEC_RefundRequestController.saveRefundRequest';
import saveRefundRequestDraft from '@salesforce/apex/FEC_RefundRequestController.saveRefundRequestDraft';
import FEC_LBL_Add_Item from '@salesforce/label/c.FEC_LBL_Add_Item';
import FEC_LBL_Remove_Row from '@salesforce/label/c.FEC_LBL_Remove_Row';
import FEC_LBL_Refund_Amount from '@salesforce/label/c.FEC_LBL_Refund_Amount';
import FEC_LBL_Receipt_Date from '@salesforce/label/c.FEC_LBL_Receipt_Date';
import FEC_LBL_Receipt_Amount from '@salesforce/label/c.FEC_LBL_Receipt_Amount';
import FEC_LBL_Transaction_No from '@salesforce/label/c.FEC_LBL_Transaction_No';
import FEC_Repay_Payment_Channel_Label from '@salesforce/label/c.FEC_Repay_Payment_Channel_Label';
import FEC_MSG_Refund_Request_Refund_Amount_Positive from '@salesforce/label/c.FEC_MSG_Refund_Request_Refund_Amount_Positive';
import FEC_MSG_Refund_Request_Receipt_Amount_Positive from '@salesforce/label/c.FEC_MSG_Refund_Request_Receipt_Amount_Positive';
import FEC_MSG_Refund_Request_Receipt_Date_Future from '@salesforce/label/c.FEC_MSG_Refund_Request_Receipt_Date_Future';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Toast_Save_Success from '@salesforce/label/c.FEC_Toast_Save_Success';
import FEC_Toast_Error from '@salesforce/label/c.FEC_Toast_Error';
import FEC_Toast_Save_Error_Message from '@salesforce/label/c.FEC_Toast_Save_Error_Message';
import FEC_Toast_Validation_Title from '@salesforce/label/c.FEC_Toast_Validation_Title';
import FEC_Complete_This_Field from '@salesforce/label/c.FEC_Complete_This_Field';
import Loading from '@salesforce/label/c.Loading';
import { todayIso } from 'c/fec_CommonUtils';

const CONST = {
    EMPTY: '',
    VARIANT_ERROR: 'error',
    VARIANT_SUCCESS: 'success',
    VARIANT_WARNING: 'warning'
};

export default class Fec_RefundRequestForm extends LightningElement {

    _recordId;
    _connected = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        const prev = this._recordId;
        this._recordId = value;
        if (prev === value) {
            return;
        }
        if (!this._connected) {
            return;
        }
        if (value) {
            this.configLoaded = false;
            this.loadRefundRequestData();
        } else {
            this._resetStateForEmptyCase();
            this.configLoaded = true;
        }
    }

    @api isEdit;

    @track configLoaded = false;
    @track isLoadingData = false;
    @track refundAmount = null;
    @track receiptLines = [];
    @track nextLineId = 1;

    customLabel = {
        loading: Loading,
        refundAmount: FEC_LBL_Refund_Amount,
        receiptDate: FEC_LBL_Receipt_Date,
        receiptAmount: FEC_LBL_Receipt_Amount,
        transactionNo: FEC_LBL_Transaction_No,
        paymentChannel: FEC_Repay_Payment_Channel_Label,
        removeRow: FEC_LBL_Remove_Row,
        addItem: FEC_LBL_Add_Item
    };

    get addItemLabel() {
        return FEC_LBL_Add_Item;
    }

    get isReadOnly() {
        return this.isEdit === false;
    }

    get maxDateIso() {
        return todayIso();
    }

    get hasReceiptRows() {
        return Array.isArray(this.receiptLines) && this.receiptLines.length > 0;
    }

    connectedCallback() {
        this._connected = true;
        if (this.recordId) {
            this.loadRefundRequestData();
        } else {
            this.configLoaded = true;
        }
    }

    _resetStateForEmptyCase() {
        this.refundAmount = null;
        this.receiptLines = [];
        this.nextLineId = 1;
    }

    loadRefundRequestData() {
        if (!this.recordId) {
            this.configLoaded = true;
            return Promise.resolve();
        }
        this.isLoadingData = true;
        return getRefundRequestData({ caseId: this.recordId })
            .then((data) => {
                this._applyServerData(data);
            })
            .catch(() => {
                this._resetStateForEmptyCase();
            })
            .finally(() => {
                this.isLoadingData = false;
                this.configLoaded = true;
            });
    }

    _normReceiptDateIso(raw) {
        if (raw == null || raw === CONST.EMPTY) {
            return null;
        }
        const s = String(raw).trim();
        if (s.length >= 10) {
            return s.substring(0, 10);
        }
        return s || null;
    }

    _applyServerData(data) {
        if (!data) {
            this._resetStateForEmptyCase();
            return;
        }
        if (data.refundAmount != null && data.refundAmount !== undefined) {
            const n = Number(data.refundAmount);
            this.refundAmount = isNaN(n) ? null : n;
        } else {
            this.refundAmount = null;
        }
        const lines = data.receiptLines;
        if (lines && lines.length > 0) {
            this.receiptLines = lines.map((line, index) => ({
                id: index + 1,
                detailId: line.detailId || null,
                receiptDateIso: this._normReceiptDateIso(line.receiptDateIso),
                receiptAmount: line.receiptAmount != null && line.receiptAmount !== undefined ? Number(line.receiptAmount) : null,
                transactionNo: line.transactionNo != null ? String(line.transactionNo) : CONST.EMPTY,
                paymentChannel: line.paymentChannel != null ? String(line.paymentChannel) : CONST.EMPTY
            }));
            this.nextLineId = this.receiptLines.length + 1;
        } else {
            this.receiptLines = [];
            this.nextLineId = 1;
        }
    }

    _lineHasAnyInput(row) {
        if (!row) {
            return false;
        }
        if (row.receiptDateIso) {
            return true;
        }
        if (row.receiptAmount != null && row.receiptAmount !== 0) {
            return true;
        }
        if (row.transactionNo && String(row.transactionNo).trim()) {
            return true;
        }
        if (row.paymentChannel && String(row.paymentChannel).trim()) {
            return true;
        }
        return false;
    }

    _lineSubmitComplete(row) {
        if (!row) {
            return false;
        }
        const dIso = this._normReceiptDateIso(row.receiptDateIso);
        if (!dIso || dIso > todayIso()) {
            return false;
        }
        if (row.receiptAmount == null || row.receiptAmount <= 0) {
            return false;
        }
        if (!row.transactionNo || !String(row.transactionNo).trim()) {
            return false;
        }
        if (!row.paymentChannel || !String(row.paymentChannel).trim()) {
            return false;
        }
        return true;
    }

    _shouldRunRefundSave(isDraft) {
        if (this.refundAmount != null && this.refundAmount > 0) {
            return true;
        }
        const rows = this.receiptLines || [];
        if (isDraft) {
            return rows.length > 0;
        }
        return rows.some((r) => this._lineHasAnyInput(r));
    }

    handleAddReceiptLine() {
        this.receiptLines = [
            ...this.receiptLines,
            {
                id: this.nextLineId,
                detailId: null,
                receiptDateIso: null,
                receiptAmount: null,
                transactionNo: CONST.EMPTY,
                paymentChannel: CONST.EMPTY
            }
        ];
        this.nextLineId += 1;
    }

    handleRemoveReceiptLine(event) {
        const id = Number(event.currentTarget.dataset.id);
        if (isNaN(id)) {
            return;
        }
        const filtered = this.receiptLines.filter((r) => r.id !== id);
        this.receiptLines = filtered;
    }

    handleRefundAmountChange(event) {
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        this.refundAmount = v === CONST.EMPTY || v == null || v === '' ? null : (Number(v) || null);
    }

    handleReceiptDateChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.receiptLines.findIndex((r) => r.id === id);
        if (idx < 0) {
            return;
        }
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        const raw = v || null;
        const next = [...this.receiptLines];
        next[idx] = { ...next[idx], receiptDateIso: this._normReceiptDateIso(raw) };
        this.receiptLines = next;
        const cmp = event.currentTarget;
        if (cmp && cmp.setCustomValidity) {
            cmp.setCustomValidity('');
            cmp.reportValidity();
        }
    }

    handleReceiptAmountChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.receiptLines.findIndex((r) => r.id === id);
        if (idx < 0) {
            return;
        }
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        let amt = null;
        if (v !== CONST.EMPTY && v != null && v !== '') {
            const n = Number(v);
            if (!isNaN(n)) {
                amt = n;
            }
        }
        const next = [...this.receiptLines];
        next[idx] = { ...next[idx], receiptAmount: amt };
        this.receiptLines = next;
        const cmp = event.currentTarget;
        if (cmp && cmp.setCustomValidity) {
            cmp.setCustomValidity('');
            cmp.reportValidity();
        }
    }

    handleTransactionChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.receiptLines.findIndex((r) => r.id === id);
        if (idx < 0) {
            return;
        }
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        const next = [...this.receiptLines];
        next[idx] = { ...next[idx], transactionNo: v != null ? String(v) : CONST.EMPTY };
        this.receiptLines = next;
    }

    handlePaymentChannelChange(event) {
        const id = Number(event.currentTarget.dataset.idValue);
        const idx = this.receiptLines.findIndex((r) => r.id === id);
        if (idx < 0) {
            return;
        }
        const v = event.detail != null && event.detail.value !== undefined ? event.detail.value : event.target.value;
        const next = [...this.receiptLines];
        next[idx] = { ...next[idx], paymentChannel: v != null ? String(v) : CONST.EMPTY };
        this.receiptLines = next;
    }

    _rowToApexDto(row) {
        return {
            detailId: row.detailId != null && String(row.detailId).trim() !== CONST.EMPTY ? String(row.detailId).trim() : null,
            receiptDateIso: row.receiptDateIso,
            receiptAmount: row.receiptAmount,
            transactionNo: row.transactionNo,
            paymentChannel: row.paymentChannel
        };
    }

    _receiptLinesForPayload(isDraft) {
        const src = this.receiptLines || [];
        const rows = isDraft
            ? src.filter(Boolean)
            : src.filter((row) => row && this._lineSubmitComplete(row));
        return rows.map((row) => this._rowToApexDto(row));
    }

    _refundSavePayload(isDraft) {
        return {
            refundAmount: this.refundAmount != null && this.refundAmount > 0 ? this.refundAmount : null,
            receiptLines: this._receiptLinesForPayload(!!isDraft)
        };
    }

    clearReceiptLineCustomValidity() {
        const rows = this.receiptLines || [];
        rows.forEach((r) => {
            const dateEl = this.template.querySelector('lightning-input[data-id-value="' + r.id + '"][data-field="receiptDate"]');
            const amtEl = this.template.querySelector('lightning-input[data-id-value="' + r.id + '"][data-field="receiptAmount"]');
            const txnEl = this.template.querySelector('lightning-input[data-id-value="' + r.id + '"][data-field="transactionNo"]');
            const payEl = this.template.querySelector('lightning-input[data-id-value="' + r.id + '"][data-field="paymentChannel"]');
            [dateEl, amtEl, txnEl, payEl].forEach((el) => {
                if (el && el.setCustomValidity) {
                    el.setCustomValidity('');
                }
            });
        });
    }

    _performClientSaveValidation(showToastOnFail) {
        const root = this.template;
        root.querySelectorAll('lightning-input').forEach((el) => {
            if (typeof el.setCustomValidity === 'function') {
                el.setCustomValidity('');
            }
        });
        this.clearReceiptLineCustomValidity();

        let sumAmt = 0;
        this.receiptLines.forEach((row) => {
            if (row.receiptAmount != null && !isNaN(Number(row.receiptAmount))) {
                sumAmt += Number(row.receiptAmount);
            }
        });
        const firstRow = this.receiptLines[0];
        const firstAmtEl = firstRow
            ? root.querySelector('lightning-input[data-id-value="' + firstRow.id + '"][data-field="receiptAmount"]')
            : null;
        if (firstAmtEl && typeof firstAmtEl.setCustomValidity === 'function') {
            if (this.receiptLines.length > 0 && sumAmt <= 0) {
                firstAmtEl.setCustomValidity(FEC_MSG_Refund_Request_Receipt_Amount_Positive);
            }
        }
        this.receiptLines.forEach((row) => {
            const dateEl = root.querySelector('lightning-input[data-id-value="' + row.id + '"][data-field="receiptDate"]');
            if (!dateEl || typeof dateEl.setCustomValidity !== 'function') {
                return;
            }
            const dIso = this._normReceiptDateIso(row.receiptDateIso);
            if (dIso && dIso > todayIso()) {
                dateEl.setCustomValidity(FEC_MSG_Refund_Request_Receipt_Date_Future);
            }
        });

        const refundAmtEl = root.querySelector('lightning-input[name="refundAmount"]');
        if (refundAmtEl && typeof refundAmtEl.setCustomValidity === 'function') {
            if (this.refundAmount != null && (isNaN(Number(this.refundAmount)) || this.refundAmount <= 0)) {
                refundAmtEl.setCustomValidity(FEC_MSG_Refund_Request_Refund_Amount_Positive);
            }
        }

        let ok = true;
        if (!this.hasReceiptRows) {
            ok = false;
        }
        if (this.receiptLines.length > 0 && sumAmt <= 0) {
            ok = false;
        }
        this.receiptLines.forEach((row) => {
            if (this._lineHasAnyInput(row) && !this._lineSubmitComplete(row)) {
                ok = false;
            }
        });
        root.querySelectorAll('lightning-input').forEach((el) => {
            if (typeof el.reportValidity === 'function' && !el.reportValidity()) {
                ok = false;
            }
        });

        if (!ok && showToastOnFail) {
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Toast_Validation_Title,
                message: FEC_Complete_This_Field,
                variant: CONST.VARIANT_WARNING
            }));
        }
        return ok;
    }

    @api
    validateForSubmit() {
        if (this.isReadOnly) {
            return true;
        }
        if (!this._shouldRunRefundSave(false)) {
            return true;
        }
        return this._performClientSaveValidation(true);
    }

    @api
    validateRefund() {
        if (this.isReadOnly) {
            return true;
        }
        return this._performClientSaveValidation(false);
    }

    @api
    saveDraftIfApplicable() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this._shouldRunRefundSave(true)) {
            return Promise.resolve();
        }
        if (!this.recordId) {
            return Promise.resolve();
        }
        const p = this._refundSavePayload(true);
        return saveRefundRequestDraft({ caseId: this.recordId, refundAmount: p.refundAmount, receiptLines: p.receiptLines })
            .catch((err) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Error,
                    message: (err.body && err.body.message) ? err.body.message : err.message || FEC_Toast_Save_Error_Message,
                    variant: CONST.VARIANT_ERROR
                }));
                return Promise.reject(err);
            });
    }

    @api
    saveRefundDataIfApplicable() {
        if (this.isReadOnly) {
            return Promise.resolve();
        }
        if (!this._shouldRunRefundSave(false)) {
            return Promise.resolve();
        }
        return this.saveRefundRequest();
    }

    @api
    saveRefundDataIfVisible() {
        return this.saveRefundDataIfApplicable();
    }

    saveRefundRequest() {
        if (this.isReadOnly) {
            return Promise.reject(new Error('readonly'));
        }
        if (!this._performClientSaveValidation(true)) {
            return Promise.reject(new Error('validation'));
        }
        if (!this.recordId) {
            return Promise.reject(new Error('missing case'));
        }
        const p = this._refundSavePayload(false);
        return saveRefundRequest({ caseId: this.recordId, refundAmount: p.refundAmount, receiptLines: p.receiptLines })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Success_Title,
                    message: FEC_Toast_Save_Success,
                    variant: CONST.VARIANT_SUCCESS
                }));
                return this.loadRefundRequestData();
            })
            .catch((err) => {
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Toast_Error,
                    message: (err.body && err.body.message) ? err.body.message : err.message || FEC_Toast_Save_Error_Message,
                    variant: CONST.VARIANT_ERROR
                }));
                return Promise.reject(err);
            });
    }
}
