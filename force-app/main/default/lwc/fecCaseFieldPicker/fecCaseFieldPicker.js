import { LightningElement, api, track } from 'lwc';
import LABEL_PLACEHOLDER from '@salesforce/label/c.FEC_Placeholder_Search_Field';
import LABEL_NO_MATCH from '@salesforce/label/c.FEC_Picker_NoMatch';
import LABEL_INVALID_VALUE from '@salesforce/label/c.FEC_Picker_InvalidValue';

/**
 * Searchable combobox cho phép user chọn 1 field từ list options
 * (Case fields + Relationships) thay vì gõ tay free-text.
 *
 * Public API:
 *   @api options          - Array<{label, value, apiName, group}>
 *   @api value            - Hiện tại đang chọn (string apiName)
 *   @api label            - Accessible label (forward cho input)
 *   @api fieldName        - data-id để identify dòng nào trong table
 *   @api disabled         - Disable input
 *
 * Events:
 *   change                - { detail: { value, fieldName } } khi user chọn 1 option
 */
export default class FecCaseFieldPicker extends LightningElement {
    @api options = [];
    @api label = '';
    @api fieldName = '';
    @api disabled = false;

    @track _value = '';
    @track searchTerm = '';
    @track isOpen = false;

    placeholder = LABEL_PLACEHOLDER;
    noMatchLabel = LABEL_NO_MATCH;
    invalidValueLabel = LABEL_INVALID_VALUE;

    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v || '';
        // Nếu chưa user gõ, hiển thị label của option matching trong input
        if (!this.isOpen) {
            this.searchTerm = this._displayLabelFor(this._value);
        }
    }

    connectedCallback() {
        this.searchTerm = this._displayLabelFor(this._value);
    }

    /**
     * Filter options theo searchTerm — match label hoặc apiName,
     * case-insensitive. Trả về list nhóm theo group.
     */
    get filteredGroups() {
        const term = (this.searchTerm || '').toLowerCase().trim();
        const matched = this.options.filter(o => {
            if (!term) return true;
            return (o.label || '').toLowerCase().includes(term)
                || (o.apiName || '').toLowerCase().includes(term);
        });

        // Group by group name, preserve order from server
        const groups = [];
        const groupMap = {};
        matched.forEach(o => {
            const gKey = o.group || '';
            if (!groupMap[gKey]) {
                groupMap[gKey] = {
                    name: gKey,
                    iconName: this._iconForGroup(gKey),
                    items: []
                };
                groups.push(groupMap[gKey]);
            }
            groupMap[gKey].items.push(o);
        });
        return groups;
    }

    /**
     * Icon dùng cho header của mỗi group:
     * - "Case Fields" → utility:case
     * - "Account Fields", "Owner Fields"... → utility:record_lookup
     */
    _iconForGroup(groupName) {
        if (!groupName) return 'utility:record';
        if (groupName.toLowerCase().includes('case')) return 'utility:case';
        return 'utility:record_lookup';
    }

    get hasResults() {
        return this.filteredGroups.some(g => g.items.length > 0);
    }

    /**
     * Trả về true nếu value hiện tại không match bất kỳ option nào.
     * Dùng để hiển thị warning cho legacy data lệch format.
     */
    get isValueInvalid() {
        if (!this._value) return false;
        return !this.options.some(o => o.value === this._value);
    }

    get inputClass() {
        return this.isValueInvalid
            ? 'slds-input slds-input_warning'
            : 'slds-input';
    }

    get dropdownClass() {
        return this.isOpen
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
    }

    handleInput(event) {
        this.searchTerm = event.target.value;
        this.isOpen = true;
    }

    handleFocus() {
        this.isOpen = true;
        // Khi focus, clear text để user search dễ hơn
        // (giữ value thật, chỉ reset visual search)
        if (this._value && this.searchTerm === this._displayLabelFor(this._value)) {
            this.searchTerm = '';
        }
    }

    handleBlur() {
        // Delay để click option kịp xử lý
        setTimeout(() => {
            this.isOpen = false;
            // Restore display label nếu user không pick gì
            this.searchTerm = this._displayLabelFor(this._value);
        }, 200);
    }

    handleOptionClick(event) {
        const newValue = event.currentTarget.dataset.value;
        const oldValue = this._value;
        this._value = newValue;
        this.searchTerm = this._displayLabelFor(newValue);
        this.isOpen = false;

        if (newValue !== oldValue) {
            this.dispatchEvent(new CustomEvent('change', {
                detail: { value: newValue, fieldName: this.fieldName },
                bubbles: true,
                composed: true
            }));
        }
    }

    /**
     * Helper: trả về label (vd "Case Number (CaseNumber)") cho 1 value.
     * Nếu không match option nào, trả về raw value (cho legacy data).
     */
    _displayLabelFor(value) {
        if (!value) return '';
        const opt = this.options.find(o => o.value === value);
        return opt ? opt.label : value;
    }
}