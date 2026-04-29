/**
 * fec_DatePicker
 * Custom datepicker hiển thị dd/mm/yyyy.
 * Fire event "datechange" với detail: { value: 'YYYY-MM-DD' | '' }
 */
import { LightningElement, api, track } from 'lwc';

const MONTH_NAMES = [
    'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
    'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
    'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
];
const DAY_HEADERS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

export default class Fec_DatePicker extends LightningElement {
    /** Label hiển thị trên input (aria) */
    @api label = '';

    /** Giá trị hiện tại dạng YYYY-MM-DD */
    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v || '';
        if (v) {
            const d = new Date(v + 'T00:00:00');
            this.viewYear  = d.getFullYear();
            this.viewMonth = d.getMonth();
        }
    }

    @track isOpen = false;
    @track showYearMonthPicker = false;
    @track viewYear  = new Date().getFullYear();
    @track viewMonth = new Date().getMonth();

    _value = '';

    /* ── Computed ─────────────────────────────────────────── */

    get displayValue() {
        if (!this._value) return '';
        const [y, m, d] = this._value.split('-');
        return `${d}/${m}/${y}`;
    }

    get showDayGrid() {
        return !this.showYearMonthPicker;
    }

    get monthYearLabel() {
        return `${MONTH_NAMES[this.viewMonth]} ${this.viewYear}`;
    }

    get dayHeaders() {
        return DAY_HEADERS;
    }

    get monthList() {
        return MONTH_NAMES.map((name, index) => ({
            name,
            index,
            cls: 'month-btn' + (index === this.viewMonth ? ' selected' : '')
        }));
    }

    get calendarDays() {
        const year  = this.viewYear;
        const month = this.viewMonth;

        const firstDay = new Date(year, month, 1).getDay(); // 0=Sun
        const daysInMonth = new Date(year, month + 1, 0).getDate();

        const today = this._toIso(new Date());
        const selected = this._value;

        const cells = [];

        // Empty cells before first day
        for (let i = 0; i < firstDay; i++) {
            cells.push({ key: `e-${i}`, label: '', dateStr: '', cls: 'day-cell empty' });
        }

        for (let d = 1; d <= daysInMonth; d++) {
            const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
            let cls = 'day-cell';
            if (dateStr === selected) cls += ' selected';
            if (dateStr === today)    cls += ' today';
            const ariaLabel = `${String(d).padStart(2, '0')}/${String(month + 1).padStart(2, '0')}/${year}`;
            cells.push({ key: dateStr, label: String(d), dateStr, cls, ariaLabel });
        }

        return cells;
    }

    /* ── Handlers ─────────────────────────────────────────── */

    toggleCalendar() {
        this.isOpen = !this.isOpen;
        if (this.isOpen) this.showYearMonthPicker = false;
    }

    toggleYearMonthPicker() {
        this.showYearMonthPicker = !this.showYearMonthPicker;
    }

    prevMonth() {
        if (this.viewMonth === 0) { this.viewMonth = 11; this.viewYear--; }
        else this.viewMonth--;
    }

    nextMonth() {
        if (this.viewMonth === 11) { this.viewMonth = 0; this.viewYear++; }
        else this.viewMonth++;
    }

    prevYear() { this.viewYear--; }
    nextYear()  { this.viewYear++; }

    selectMonth(e) {
        this.viewMonth = parseInt(e.currentTarget.dataset.month, 10);
        this.showYearMonthPicker = false;
    }

    selectDay(e) {
        const dateStr = e.currentTarget.dataset.date;
        if (!dateStr) return;
        this._value = dateStr;
        this.isOpen = false;
        this._fireChange(dateStr);
    }

    handleKeyDown(e) {
        if (e.key === 'Escape') this.isOpen = false;
    }

    /* ── Utils ────────────────────────────────────────────── */

    _toIso(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    _fireChange(value) {
        this.dispatchEvent(new CustomEvent('datechange', { detail: { value } }));
    }
}
