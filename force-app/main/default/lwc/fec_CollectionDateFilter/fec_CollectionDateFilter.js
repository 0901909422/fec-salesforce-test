/**
 * fec_CollectionDateFilter
 *
 * Component date filter dùng chung cho các LWC collection data.
 * Hiển thị From Date / To Date + nút Apply.
 * Khi Apply, fire event 'datefilterchange' lên parent với:
 *   { detail: { startDate: 'YYYYMMDD', endDate: 'YYYYMMDD' } }
 *
 * @api defaultFromDate - Giá trị mặc định cho From Date (YYYY-MM-DD, optional)
 * @api defaultToDate   - Giá trị mặc định cho To Date (YYYY-MM-DD, optional)
 * @api maxRangeDays    - Số ngày tối đa cho phép (mặc định 90)
 */
import { LightningElement, api, track } from 'lwc';

const MAX_RANGE_DAYS = 90;

export default class Fec_CollectionDateFilter extends LightningElement {
    @api maxRangeDays = MAX_RANGE_DAYS;

    @track fromDate = '';
    @track toDate = '';
    @track errorMessage = '';

    // Nhận default values từ parent
    @api
    get defaultFromDate() {
        return this._defaultFromDate;
    }
    set defaultFromDate(val) {
        this._defaultFromDate = val;
        if (val && !this.fromDate) {
            this.fromDate = val;
        }
    }

    @api
    get defaultToDate() {
        return this._defaultToDate;
    }
    set defaultToDate(val) {
        this._defaultToDate = val;
        if (val && !this.toDate) {
            this.toDate = val;
        }
    }

    _defaultFromDate = '';
    _defaultToDate = '';

    connectedCallback() {
        // Set default: From = 90 ngày trước, To = hôm nay
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

        // Convert sang YYYYMMDD để truyền vào API
        const startDate = this._toApiDateStr(from);
        const endDate = this._toApiDateStr(to);

        this.dispatchEvent(
            new CustomEvent('datefilterchange', {
                detail: { startDate, endDate }
            })
        );
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
