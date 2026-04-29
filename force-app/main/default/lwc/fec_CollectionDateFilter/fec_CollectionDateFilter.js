/**
 * fec_CollectionDateFilter
 *
 * Component date filter đứng độc lập trên Lightning Page.
 * Khi user bấm Apply, publish lên FEC_Collection_Date_Filter message channel.
 * Các LWC collection data (fec_allocationHistory, fec_CollectionInteractions,
 * fec_communicationHistory, fec_NFU) subscribe và tự gọi lại API.
 */
import { LightningElement, api, track, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import COLLECTION_DATE_FILTER from '@salesforce/messageChannel/FEC_Collection_Date_Filter__c';
import { formatDate } from 'c/fec_CommonUtils';
import FEC_Btn_Apply from '@salesforce/label/c.FEC_Btn_Apply';
import FEC_CollectionDateFilter_HintText from '@salesforce/label/c.FEC_CollectionDateFilter_HintText';
import FEC_CollectionDateFilter_FromDate from '@salesforce/label/c.FEC_CollectionDateFilter_FromDate';
import FEC_CollectionDateFilter_ToDate from '@salesforce/label/c.FEC_CollectionDateFilter_ToDate';
import FEC_CollectionDateFilter_ErrorMissingDate from '@salesforce/label/c.FEC_CollectionDateFilter_ErrorMissingDate';
import FEC_CollectionDateFilter_ErrorFromGtTo from '@salesforce/label/c.FEC_CollectionDateFilter_ErrorFromGtTo';
import FEC_CollectionDateFilter_ErrorExceedRange from '@salesforce/label/c.FEC_CollectionDateFilter_ErrorExceedRange';
import FEC_CollectionDateFilter_SuccessMsg from '@salesforce/label/c.FEC_CollectionDateFilter_SuccessMsg';

const MAX_RANGE_DAYS = 90;

export default class Fec_CollectionDateFilter extends LightningElement {
    @api maxRangeDays = MAX_RANGE_DAYS;

    @wire(MessageContext)
    messageContext;

    @track fromDate = '';
    @track toDate = '';
    @track errorMessage = '';

    label = {
        apply: FEC_Btn_Apply,
        hintText: FEC_CollectionDateFilter_HintText,
        fromDate: FEC_CollectionDateFilter_FromDate,
        toDate: FEC_CollectionDateFilter_ToDate
    };

    connectedCallback() {
        // Default: From = 90 ngày trước, To = hôm nay
        if (!this.fromDate) {
            const today = new Date();
            const from = new Date(today);
            from.setDate(today.getDate() - (this.maxRangeDays || MAX_RANGE_DAYS));
            this.fromDate = this._toInputDateStr(from);
        }
        if (!this.toDate) {
            this.toDate = this._toInputDateStr(new Date());
        }
    }

    handleFromDateChange(e) {
        this.fromDate = e.detail.value;
        this.errorMessage = '';
    }

    handleToDateChange(e) {
        this.toDate = e.detail.value;
        this.errorMessage = '';
    }

    handleApply() {
        this.errorMessage = '';

        if (!this.fromDate || !this.toDate) {
            this.errorMessage = FEC_CollectionDateFilter_ErrorMissingDate;
            this.showErrorToast(FEC_CollectionDateFilter_ErrorMissingDate);
            return;
        }

        const from = new Date(this.fromDate);
        const to = new Date(this.toDate);

        if (from > to) {
            this.errorMessage = FEC_CollectionDateFilter_ErrorFromGtTo;
            this.showErrorToast(FEC_CollectionDateFilter_ErrorFromGtTo);
            return;
        }

        const diffDays = Math.round((to - from) / (1000 * 60 * 60 * 24));
        const maxDays = this.maxRangeDays || MAX_RANGE_DAYS;
        if (diffDays > maxDays) {
            const errorMsg = FEC_CollectionDateFilter_ErrorExceedRange.replace('{0}', maxDays);
            this.errorMessage = errorMsg;
            this.showErrorToast(errorMsg);
            return;
        }

        // Publish lên message channel — tất cả LWC subscriber sẽ nhận và reload
        publish(this.messageContext, COLLECTION_DATE_FILTER, {
            startDate: this._toApiDateStr(from),
            endDate: this._toApiDateStr(to)
        });

        // Hiển thị toast notification thành công
        this.showSuccessToast(from, to);
    }

    showSuccessToast(fromDate, toDate) {
        const fromDateStr = formatDate(fromDate);
        const toDateStr = formatDate(toDate);
        const message = FEC_CollectionDateFilter_SuccessMsg
            .replace('{0}', fromDateStr)
            .replace('{1}', toDateStr);
        this.showToast('Thành công', message, 'success');
    }

    showErrorToast(message) {
        this.showToast('Lỗi', message, 'error');
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
    }

    /** YYYY-MM-DD cho lightning-input[type=date] */
    _toInputDateStr(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    /** YYYYMMDD cho API */
    _toApiDateStr(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}${m}${d}`;
    }
}
