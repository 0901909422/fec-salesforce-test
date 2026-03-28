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
    _options = [];

    @api
    get options() { return this._options; }
    set options(val) {
        this._options = val || [];
    }

    /* ── Internal state ── */
    @track _searchTerm   = '';
    @track _isOpen       = false;
    @track _hasFocus     = false;

    /* ═══════════════════════════════════════════ */
    /*  COMPUTED                                   */
    /* ═══════════════════════════════════════════ */

    /** Display label of the currently selected value */
    get selectedLabel() {
        if (!this._value) return '';
        const match = this._options.find(o => o.value === this._value);
        return match ? match.label : '';
    }

    /** Value shown in the input field */
    get inputValue() {
        if (this._isOpen) return this._searchTerm;
        return this.selectedLabel;
    }

    /** Filtered options based on search term */
    get filteredOptions() {
        const term = (this._searchTerm || '').toLowerCase().trim();
        if (!term) return this._options;
        return this._options.filter(o =>
            o.label && o.label.toLowerCase().includes(term)
        );
    }

    get hasFilteredOptions() {
        return this.filteredOptions.length > 0;
    }

    get dropdownClass() {
        return this._isOpen
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    get containerClass() {
        return 'slds-combobox_container';
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