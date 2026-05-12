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

    /** Ngày tối đa được chọn (YYYY-MM-DD). Rỗng = không giới hạn. */
    @api maxDate;

    /** Giá trị hiện tại dạng YYYY-MM-DD */
    @api
    get value() {
        return this._value;
    }
    set value(v) {
        let val = v || '';
        const max = this._maxDateStr;
        if (val && max && val > max) {
            val = max;
        }
        this._value = val;
        if (val) {
            const d = new Date(val + 'T00:00:00');
            this.viewYear  = d.getFullYear();
            this.viewMonth = d.getMonth();
        }
    }

    @track isOpen = false;
    @track showYearMonthPicker = false;
    @track viewYear  = new Date().getFullYear();
    @track viewMonth = new Date().getMonth();

    _value = '';

    /** Đóng khi click ra ngoài (mousedown capture). Dùng tọa độ + getBoundingClientRect — tránh Locker/retarget làm sai event.target. */
    _closeIfClickOutside = (event) => {
        if (!this.isOpen) return;
        let x = event.clientX;
        let y = event.clientY;
        if (event.type === 'touchstart' && event.touches?.length) {
            x = event.touches[0].clientX;
            y = event.touches[0].clientY;
        }
        if (typeof x !== 'number' || typeof y !== 'number' || Number.isNaN(x) || Number.isNaN(y)) {
            return;
        }
        if (this._isPointerInsidePicker(x, y)) return;
        this.closeCalendar();
    };

    /** Input + popup: popup position:absolute không mở rộng rect của wrapper — phải hợp cả .calendar-popup. */
    _isPointerInsidePicker(clientX, clientY) {
        const inRect = (r) =>
            clientX >= r.left &&
            clientX <= r.right &&
            clientY >= r.top &&
            clientY <= r.bottom;

        const wrapper = this.template.querySelector('.datepicker-wrapper');
        if (wrapper && inRect(wrapper.getBoundingClientRect())) return true;

        const popup = this.template.querySelector('.calendar-popup');
        if (popup && inRect(popup.getBoundingClientRect())) return true;

        return false;
    }

    connectedCallback() {
        document.addEventListener('mousedown', this._closeIfClickOutside, true);
        document.addEventListener('touchstart', this._closeIfClickOutside, { capture: true, passive: true });
    }

    disconnectedCallback() {
        document.removeEventListener('mousedown', this._closeIfClickOutside, true);
        document.removeEventListener('touchstart', this._closeIfClickOutside, { capture: true, passive: true });
    }

    /** Đóng popup — gọi từ parent khi mở picker khác */
    @api
    closeCalendar() {
        this.isOpen = false;
        this.showYearMonthPicker = false;
    }

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

    get _maxDateStr() {
        const m = this.maxDate;
        return m != null && String(m).trim() !== '' ? String(m).trim() : null;
    }

    /** Không cho next tháng nếu cả tháng sau đều sau maxDate */
    get disableNextMonth() {
        const max = this._maxDateStr;
        if (!max) return false;
        const firstNextMonth = new Date(this.viewYear, this.viewMonth + 1, 1);
        const maxD = new Date(`${max}T00:00:00`);
        return firstNextMonth > maxD;
    }

    /** Không cho next năm trong year picker nếu năm sau hoàn toàn sau maxDate */
    get disableNextYear() {
        const max = this._maxDateStr;
        if (!max) return false;
        const firstJanNextYear = new Date(this.viewYear + 1, 0, 1);
        return firstJanNextYear > new Date(`${max}T00:00:00`);
    }

    get calendarDays() {
        const year  = this.viewYear;
        const month = this.viewMonth;

        const firstDay = new Date(year, month, 1).getDay(); // 0=Sun
        const daysInMonth = new Date(year, month + 1, 0).getDate();

        const today = this._toIso(new Date());
        const selected = this._value;
        const maxStr = this._maxDateStr;

        const cells = [];

        // Empty cells before first day
        for (let i = 0; i < firstDay; i++) {
            cells.push({ key: `e-${i}`, label: '', dateStr: '', cls: 'day-cell empty' });
        }

        for (let d = 1; d <= daysInMonth; d++) {
            const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
            let cls = 'day-cell';
            if (maxStr && dateStr > maxStr) cls += ' disabled';
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
        if (this.isOpen) {
            this.showYearMonthPicker = false;
            this.dispatchEvent(
                new CustomEvent('pickeropen', {
                    bubbles: true,
                    composed: true
                })
            );
        }
    }

    toggleYearMonthPicker() {
        this.showYearMonthPicker = !this.showYearMonthPicker;
    }

    prevMonth() {
        if (this.viewMonth === 0) { this.viewMonth = 11; this.viewYear--; }
        else this.viewMonth--;
    }

    nextMonth() {
        if (this.disableNextMonth) return;
        if (this.viewMonth === 11) { this.viewMonth = 0; this.viewYear++; }
        else this.viewMonth++;
    }

    prevYear() { this.viewYear--; }
    nextYear() {
        if (this.disableNextYear) return;
        this.viewYear++;
    }

    selectMonth(e) {
        this.viewMonth = parseInt(e.currentTarget.dataset.month, 10);
        this.showYearMonthPicker = false;
    }

    selectDay(e) {
        if (e.currentTarget.classList.contains('disabled')) return;
        const dateStr = e.currentTarget.dataset.date;
        if (!dateStr) return;
        const maxStr = this._maxDateStr;
        if (maxStr && dateStr > maxStr) return;
        this._value = dateStr;
        this.closeCalendar();
        this._fireChange(dateStr);
    }

    handleKeyDown(e) {
        if (e.key === 'Escape') this.closeCalendar();
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
