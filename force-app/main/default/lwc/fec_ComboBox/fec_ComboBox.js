import { LightningElement, api, track } from "lwc";
import FEC_Complete_This_Field from "@salesforce/label/c.FEC_Complete_This_Field";
import { STR_EMPTY } from "c/fec_CommonConst";

export default class Fec_ComboBox extends LightningElement {
  @api option;

  @api label;
  @api placeholder;
  @api disabled;
  @api required;
  @api enableSearchChange = false;

  openSearch = false;
  @api searchKey;
  hasError = false;

  _value;
  @api get value() {
    return this._value;
  }
  set value(val) {
    this._value = (val === null || val === undefined || val === STR_EMPTY) ? undefined : val;
    if (this._value) {
      this._inputDraft = STR_EMPTY;
    } else {
      this._lastBlurCommittedValue = STR_EMPTY;
    }
  }

  get optionLabel() {
    const found = this.optionlst?.find((item) => item.value === this.value);
    if (found && found.label != null && String(found.label) !== STR_EMPTY) {
      return found.label;
    }
    if (this.value !== undefined && this.value !== null && this.value !== STR_EMPTY) {
      return String(this.value);
    }
    return undefined;
  }

  get formElementClass() {
    return this.hasError ? "slds-form-element slds-has-error" : "slds-form-element";
  }

  get comboboxClassName() {
    return this.openSearch
      ? "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open"
      : "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click";
  }

  get hasValue() {
    return this.value !== undefined && this.value !== STR_EMPTY;
  }

  get optionlst() {
    return this.option ? JSON.parse(this.option) : [];
  }

  get filteredOptionlst() {
    if (this.searchKey) {
      return this.optionlst.filter((item) => {
        return item.label.toLowerCase().includes(this.searchKey.toLowerCase());
      });
    }

    return [...this.optionlst];
  }

  get isNotDisabled() {
    return !this.disabled;
  }

  firstTimeLoaded = true;
  _justPicked = false;
  _skipNextWindowBlurCommit = false;
  _inputDraft = STR_EMPTY;
  _lastBlurCommittedValue = STR_EMPTY;
  _customValidityMsg = STR_EMPTY;
  _boundWindowClick = null;

  get showClose() {
    return !this.disabled
  }

  @api clear() {
    this.value = undefined;
    this.searchKey = undefined;
    this._inputDraft = STR_EMPTY;
    this._lastBlurCommittedValue = STR_EMPTY;
    this.openSearch = false;
    this.hasError = false;
    this._customValidityMsg = STR_EMPTY;
  }

  @api resetBlurCommitState() {
    this._lastBlurCommittedValue = STR_EMPTY;
  }

  @api setCustomValidity(message) {
    this._customValidityMsg = message != null ? String(message) : STR_EMPTY;
    const inputEl = this.template.querySelector('lightning-input[data-id="search-input"]');
    if (inputEl && typeof inputEl.setCustomValidity === "function") {
      const isMissing = !!this.required && !this.hasValue;
      const validityMsg = isMissing ? FEC_Complete_This_Field : this._customValidityMsg;
      inputEl.setCustomValidity(validityMsg);
    }
  }

  @api reportValidity() {
    if (this.disabled) {
      this.hasError = false;
      return true;
    }
    const isMissing = !!this.required && !this.hasValue;
    const customMsg = this._customValidityMsg && String(this._customValidityMsg).trim() ? String(this._customValidityMsg) : STR_EMPTY;
    this.hasError = isMissing || (!!customMsg && !this.hasValue);
    const inputEl = this.template.querySelector('lightning-input[data-id="search-input"]');
    if (inputEl && typeof inputEl.setCustomValidity === "function" && typeof inputEl.reportValidity === "function") {
      const validityMsg = isMissing ? FEC_Complete_This_Field : customMsg;
      inputEl.setCustomValidity(validityMsg);
      return inputEl.reportValidity();
    }
    return !isMissing && !(!!customMsg && !this.hasValue);
  }

  @api checkValidity() {
    if (this.disabled) {
      return true;
    }
    const missingReq = !!(this.required && !this.hasValue);
    const customInvalid = !!(this._customValidityMsg && String(this._customValidityMsg).trim() && !this.hasValue);
    return !missingReq && !customInvalid;
  }

  connectedCallback() {
    // this.filteredOptionlst = [...this.optionlst];
  }

  renderedCallback() {
    if (this.firstTimeLoaded) {
      this.firstTimeLoaded = false;
      this._boundWindowClick = this.handleWindowClick.bind(this);
      window.addEventListener("click", this._boundWindowClick);
    }
  }

  disconnectedCallback() {
    if (this._boundWindowClick) {
      window.removeEventListener("click", this._boundWindowClick);
      this._boundWindowClick = null;
    }
  }

  handleSearch(e) {
    e.preventDefault();
    e.stopPropagation();

    const inputValue = e?.detail?.value !== undefined ? e.detail.value : e.target.value;
    this._inputDraft = inputValue != null ? String(inputValue).trim() : STR_EMPTY;
    this.searchKey = inputValue?.toLowerCase()?.trim();
    this.dispatchSearchChange(inputValue);
  }

  handleSearchInput(e) {
    const inputValue = e?.detail?.value !== undefined ? e.detail.value : e.target.value;
    this._inputDraft = inputValue != null ? String(inputValue).trim() : STR_EMPTY;
    this.searchKey = inputValue?.toLowerCase()?.trim();
    this.dispatchSearchChange(inputValue);
  }

  dispatchSearchChange(inputValue) {
    if (!this.enableSearchChange) {
      return;
    }
    const event = new CustomEvent("searchchange", {
      detail: {
        value: inputValue
      }
    });
    this.dispatchEvent(event);
  }

    handleFocus(e) {
        e.preventDefault();
        e.stopPropagation();

        this.openSearch = true;
        this.dispatchEvent(new CustomEvent('dropdownopen'));
    }

  handleOptionMouseDown(e) {
    e.preventDefault();
  }

  handleComboboxFocusOut(event) {
    if (this.disabled) {
      return;
    }
    if (this._justPicked) {
      this._justPicked = false;
      return;
    }
    const next = event.relatedTarget;
    if (next && this.template.contains(next)) {
      return;
    }
    this._dispatchBlurCommit();
    this._skipNextWindowBlurCommit = true;
    setTimeout(() => {
      this._skipNextWindowBlurCommit = false;
    }, 0);
  }

  handleChipMouseDown(e) {
    if (this.disabled) {
      return;
    }
    const chip = e.currentTarget;
    if (chip && typeof chip.focus === "function") {
      chip.focus();
    }
  }

  handleWindowClick(e) {
    this.openSearch = false;
    if (this._skipNextWindowBlurCommit || this.disabled || this._justPicked) {
      return;
    }
    if (this.template.contains(e.target)) {
      return;
    }
    if (!this.hasValue && this._inputDraft && String(this._inputDraft).trim()) {
      this._dispatchBlurCommit();
    }
  }

  _dispatchBlurCommit() {
    let raw = STR_EMPTY;
    if (this.hasValue) {
      raw =
        this.value !== undefined && this.value !== null
          ? String(this.value).trim()
          : STR_EMPTY;
    } else if (this._inputDraft && String(this._inputDraft).trim()) {
      raw = String(this._inputDraft).trim();
    } else {
      const inp = this.template.querySelector('[data-id="search-input"]');
      if (inp) {
        raw =
          inp.value !== undefined && inp.value !== null
            ? String(inp.value).trim()
            : STR_EMPTY;
      }
    }
    if (raw === this._lastBlurCommittedValue) {
      return;
    }
    this._lastBlurCommittedValue = raw;
    this.dispatchEvent(
      new CustomEvent("blurcommit", {
        detail: { value: raw }
      })
    );
  }

  handleRemoveSelected(e) {
    e.preventDefault();
    e.stopPropagation();

    this.value = undefined;
    this.searchKey = undefined;
    this._inputDraft = STR_EMPTY;
    this._lastBlurCommittedValue = STR_EMPTY;
    this.hasError = false;
    this._customValidityMsg = STR_EMPTY;

    const event = new CustomEvent("remove");

    this.dispatchEvent(event);

    setTimeout(() => {
      let searchInput = this.template.querySelector('[data-id="search-input"]');

      if (searchInput) {
        searchInput.focus();
        this.openSearch = true;
      }
    }, 100);
  }

  handleChoose(e) {
    e.preventDefault();
    e.stopPropagation();

    let value = e.currentTarget.dataset.id;

    if (value) {
      this.searchKey = undefined;
      this.value = value;
      this.openSearch = false;
      this.hasError = false;
      this._customValidityMsg = STR_EMPTY;
      this._justPicked = true;
      this._lastBlurCommittedValue = String(value).trim();

      const event = new CustomEvent("change", {
        detail: {
          value: this.value,
          fromPick: true
        }
      });

      this.dispatchEvent(event);
      setTimeout(() => {
        this._justPicked = false;
      }, 0);
    }
  }
}