/**
 * @description  Searchable Combobox – a reusable dropdown with a text filter.
 *               Works like a standard lightning-combobox but adds a search input
 *               to filter the option list by label. Used for Folder and
 *               Enhanced Letterhead fields in the Template Editor.
 *
 *               Public API:
 *               - label      : Field label text
 *               - value      : Currently selected option value
 *               - options     : Array of { label, value } objects
 *               - placeholder : Placeholder text for the search input
 *               - required    : Show required asterisk
 *               - disabled    : Disable the combobox
 *
 *               Events:
 *               - change : { detail: { value } }
 *
 * @component    fec_searchableCombobox
 */
import { LightningElement, api, track } from 'lwc';

const REQUIRED_FIELD_MESSAGE = 'Complete this field.';

export default class Fec_searchableCombobox extends LightningElement {

    @api label       = '';
    @api placeholder = 'Search...';
    @api required    = false;
    @api disabled    = false;

    /** Currently selected value */
    _value = '';

    @api
    get value() { return this._value; }
    set value(val) {
        this._value = val || '';
    }

    /** Options array: [{ label, value }] */
    @track _options = [];

    @api
    get options() {
        return this._options;
    }
    set options(val) {
        this._options = Array.isArray(val) ? [...val] : [];
    }

    /* ── Internal state ── */
    @track _searchTerm   = '';
    @track _isOpen       = false;
    @track _hasFocus     = false;
    @track _errorMessage = '';

    /* ═══════════════════════════════════════════ */
    /*  PUBLIC VALIDATION API                      */
    /* ═══════════════════════════════════════════ */

    /**
     * Set a custom validity message (mirrors lightning-input API).
     * Pass '' to clear the error.
     */
    @api
    setCustomValidity(message) {
        this._errorMessage = message || '';
    }

    /**
     * Show or clear the error message (mirrors lightning-input API).
     * @returns {Boolean} true if valid (no error message).
     */
    @api
    reportValidity() {
        if (this.required && !this._value) {
            this._errorMessage = REQUIRED_FIELD_MESSAGE;
            return false;
        }
        if (this._errorMessage === REQUIRED_FIELD_MESSAGE) {
            this._errorMessage = '';
        }
        return !this._errorMessage;
    }

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED                                   */
    /* ═══════════════════════════════════════════ */

    /** Display label of the currently selected value */
    optionLabel(o) {
        if (!o) {
            return '';
        }
        const lbl = o.label != null ? o.label : o.Label;
        return lbl != null ? String(lbl) : '';
    }

    get selectedLabel() {
        if (!this._value) {
            return '';
        }
        const match = this._options.find((o) => o.value === this._value);
        return match ? this.optionLabel(match) : '';
    }

    /** Value shown in the input field */
    get inputValue() {
        if (this._isOpen) return this._searchTerm;
        return this.selectedLabel;
    }

    /**
     * Chuẩn hóa chuỗi để so khớp tìm kiếm (bỏ dấu tiếng Việt, xử lý đ/Đ, không phân biệt hoa thường).
     * Không dùng \\p{M} (Unicode property) vì có thể không tương thích Locker / engine cũ.
     */
    foldForSearch(s) {
        if (s == null || s === '') {
            return '';
        }
        try {
            let t = String(s).normalize('NFD');
            t = t.replace(/[\u0300-\u036f]/g, '');
            t = t.replace(/\u0111/g, 'd').replace(/\u0110/g, 'd');
            return t.toLowerCase().trim();
        } catch (e) {
            return String(s)
                .toLowerCase()
                .trim();
        }
    }

    /** Filtered options based on search term */
    get filteredOptions() {
        const term = (this._searchTerm || '').trim();
        if (!term) {
            return this._options;
        }
        const foldedTerm = this.foldForSearch(term);
        if (!foldedTerm) {
            return this._options;
        }
        return this._options.filter((o) => {
            const lbl = this.optionLabel(o);
            if (!lbl.trim()) {
                return false;
            }
            return this.foldForSearch(lbl).includes(foldedTerm);
        });
    }

    get hasFilteredOptions() {
        return this.filteredOptions.length > 0;
    }

    /** Bản hiển thị listbox (label chuẩn hóa từ label hoặc Label). */
    get filteredOptionsForTemplate() {
        return this.filteredOptions.map((o) => ({
            value: o.value,
            displayLabel: this.optionLabel(o)
        }));
    }

    get dropdownClass() {
        return this._isOpen
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    get containerClass() {
        return 'slds-combobox_container';
    }

    /** Apply slds-has-error when an error message is set */
    get formElementClass() {
        return this._errorMessage
            ? 'slds-form-element slds-has-error'
            : 'slds-form-element';
    }

    /* ═══════════════════════════════════════════ */
    /*  EVENT HANDLERS                             */
    /* ═══════════════════════════════════════════ */

    handleInputFocus() {
        this._hasFocus = true;
        this._isOpen = true;
        this._searchTerm = '';
    }

    handleInputChange(event) {
        this._searchTerm = event.target.value;
        this._isOpen = true;
    }

    handleInputBlur() {
        // Delay to allow option click to register
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._hasFocus = false;
            this._isOpen = false;
            this._searchTerm = '';
        }, 200);
    }

    handleOptionClick(event) {
        const selectedValue = event.currentTarget.dataset.value;
        this._value = selectedValue;
        this._isOpen = false;
        this._searchTerm = '';
        this._errorMessage = '';

        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: selectedValue }
        }));
    }

    handleClear() {
        this._value = '';
        this._searchTerm = '';
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: '' }
        }));
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') {
            this._isOpen = false;
            this._searchTerm = '';
        }
    }
}