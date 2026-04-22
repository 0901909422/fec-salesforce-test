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
import COLLECTION_DATE_FILTER from '@salesforce/messageChannel/FEC_Collection_Date_Filter__c';

const MAX_RANGE_DAYS = 90;

export default class Fec_CollectionDateFilter extends LightningElement {
    @api maxRangeDays = MAX_RANGE_DAYS;

    @wire(MessageContext)
    messageContext;

    @track fromDate = '';
    @track toDate = '';
    @track errorMessage = '';

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
            this.errorMessage = 'Vui lòng chọn đầy đủ From Date và To Date.';
            return;
        }

        const from = new Date(this.fromDate);
        const to = new Date(this.toDate);

        if (from > to) {
            this.errorMessage = 'From Date không được lớn hơn To Date.';
            return;
        }

        const diffDays = Math.round((to - from) / (1000 * 60 * 60 * 24));
        const maxDays = this.maxRangeDays || MAX_RANGE_DAYS;
        if (diffDays > maxDays) {
            this.errorMessage = `Khoảng thời gian không được vượt quá ${maxDays} ngày.`;
            return;
        }

        // Publish lên message channel — tất cả LWC subscriber sẽ nhận và reload
        publish(this.messageContext, COLLECTION_DATE_FILTER, {
            startDate: this._toApiDateStr(from),
            endDate: this._toApiDateStr(to)
        });
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
