import { LightningElement, api, track } from "lwc";
import FEC_Complete_This_Field from "@salesforce/label/c.FEC_Complete_This_Field";

export default class Fec_ComboBox extends LightningElement {
  @api option;

  @api label;
  @api placeholder;
  @api disabled;
  @api required;

  openSearch = false;
  @api searchKey;
  hasError = false;

  _value;
  @api get value() {
    return this._value;
  }
  set value(val) {
    this._value = (val === null || val === undefined || val === '') ? undefined : val;
  }

  get optionLabel() {
    return this.optionlst?.find((item) => item.value === this.value)?.label;
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
    return this.value !== undefined && this.value !== "";
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

  get showClose() {
    return !this.disabled
  }

  @api clear() {
    this.value = undefined;
    this.searchKey = undefined;
    this.openSearch = false;
    this.hasError = false;
  }

  @api reportValidity() {
    if (this.disabled) {
      this.hasError = false;
      return true;
    }
    const isMissing = !!this.required && !this.hasValue;
    this.hasError = isMissing;
    const inputEl = this.template.querySelector('lightning-input[data-id="search-input"]');
    if (inputEl && typeof inputEl.setCustomValidity === "function" && typeof inputEl.reportValidity === "function") {
      inputEl.setCustomValidity(isMissing ? FEC_Complete_This_Field : "");
      return inputEl.reportValidity();
    }
    return !isMissing;
  }

  @api checkValidity() {
    if (this.disabled) {
      return true;
    }
    return !(!!this.required && !this.hasValue);
  }

  connectedCallback() {
    // this.filteredOptionlst = [...this.optionlst];
  }

  renderedCallback() {
    if (this.firstTimeLoaded) {
      this.firstTimeLoaded = false;

      window.addEventListener("click", (e) => {
        this.openSearch = false;
      });
    }
  }

  disconnectedCallback() {
    window.removeEventListener("click", () => {});
  }

  handleSearch(e) {
    e.preventDefault();
    e.stopPropagation();

    this.searchKey = e.target.value?.toLowerCase()?.trim();

    // if (searchKey) {
    //   this.filteredOptionlst = this.optionlst.filter((item) => {
    //     return item.label.toLowerCase().includes(searchKey);
    //   });
    // } else {
    //   this.filteredOptionlst = [...this.optionlst];
    // }
  }

  handleFocus(e) {
    e.preventDefault();
    e.stopPropagation();

    this.openSearch = true;
  }

  handleRemoveSelected(e) {
    e.preventDefault();
    e.stopPropagation();

    this.value = undefined;
    this.searchKey = undefined;
    this.hasError = false;

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
      this.value = value;
      this.openSearch = false;
      this.hasError = false;

      const event = new CustomEvent("change", {
        detail: {
          value: this.value
        }
      });

      this.dispatchEvent(event);
    }
  }
}