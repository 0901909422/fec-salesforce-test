import { LightningElement, api, track } from "lwc";

const ALL_VI = "Tất cả";
const ALL_EN = "All";
const ERROR_MSG_3_VI = "Hoàn tất trường này.";
const ERROR_MSG_3_EN = "Complete this field.";

const OPTION_PREFIX = "option_";
export default class Fec_MultiPicklistInput extends LightningElement {
  firstTimeLoaded = true;

  instanceKey;

  combobox;
  input;
  formElement;

  @track _options = [];

  @api name;
  @api placeholder = "Select an Option...";
  @api label = "Field name";

  @api
  get options() {
    return this._options;
  }

  set options(value) {
    this._options = value;
    this.generateOptions();
  }

  @api required;
  @api isSearch = false;

  _isAll;
  @api
  get isAll() {
    return this._isAll;
  }

  set isAll(value) {
    this._isAll = value && this.optionlst.length > 0;
  }

  _value = [];
  @api get value() {
    let temp = [];

    this.selectedlst.forEach((item) => {
      temp.push(item.value);
    });

    return temp;
  }

  set value(valueArr) {
    this._value = valueArr;
    this.generateOptions();
  }

  selectedIdlst = [];

  @track optionlst = [];
  @track selectedlst = [];

  get isSelected() {
    return this.selectedlst.length > 0;
  }

  isError = false;
  isFocus;

  get isSelectAll() {
    return this.selectedlst.length === this.optionlst.length;
  }

  timeoutHandler;

  errorMsg;
  allLabel;

  connectedCallback() {
    if (!this.instanceKey) {
      this.instanceKey = "fecmp" + Math.random().toString(36).slice(2, 11);
    }
    // this.generateOptions();
    this.currentLang = document.documentElement.lang;

    switch (this.currentLang) {
      case "en-US":
        this.errorMsg = ERROR_MSG_3_EN;
        this.allLabel = ALL_EN;
        break;

      case "vi":
        this.errorMsg = ERROR_MSG_3_VI;
        this.allLabel = ALL_VI;
        break;
      default:
        break;
    }
  }

  renderedCallback() {
    if (this.firstTimeLoaded) {
      this.firstTimeLoaded = false;
      this.combobox = this.template.querySelector(".slds-combobox");
      this.input = this.template.querySelector(".slds-input_faux");
      this.formElement = this.template.querySelector(".slds-form-element");
    }
  }

  handleMouseOver() {
    this.isFocus = true;
  }

  handleMouseLeave() {
    this.combobox.focus();
    this.isFocus = false;
  }

  handleFocus(e) {
    e.stopPropagation();

    if (this.isSearch) {
      this.combobox.classList.add("slds-is-open");
    } else {
      // if (this.combobox.classList.contains("slds-is-open")) {
      //   this.combobox.classList.remove("slds-is-open");
      //   this.input.classList.remove("slds-has-focus");
      // } else {
      this.combobox.classList.add("slds-is-open");
      this.input.classList.add("slds-has-focus");
      // }
    }
  }

  handleBlur(e) {
    if (this.isSearch) {
      if (!this.isFocus) this.combobox.classList.remove("slds-is-open");
    } else {
      this.combobox.classList.remove("slds-is-open");
      this.input.classList.remove("slds-has-focus");
    }

    if (!this.isFocus) this.checkValidity();
  }

  get selectAllCheckboxId() {
    return (this.instanceKey || "fecmpx") + "-all";
  }

  toggleOptionById(dataId) {
    let index = this.selectedIdlst.indexOf(dataId);

    if (index > -1) {
      this.selectedIdlst.splice(index, 1);
    } else {
      this.selectedIdlst.push(dataId);
    }

    this.updateOptions();
  }

  handleChooseOptionClick(e) {
    e.stopPropagation();

    if (e.target.closest(".slds-checkbox")) {
      return;
    }

    let dataId = e.currentTarget.dataset.id;
    this.toggleOptionById(dataId);
  }

  handleChooseOptionChange(e) {
    e.stopPropagation();

    let dataId = e.target.dataset.id;
    let checked = e.target.checked;
    let index = this.selectedIdlst.indexOf(dataId);

    if (checked && index === -1) {
      this.selectedIdlst.push(dataId);
    } else if (!checked && index > -1) {
      this.selectedIdlst.splice(index, 1);
    }

    this.updateOptions();
  }

  generateOptions() {
    if (!this.instanceKey) {
      this.instanceKey = "fecmp" + Math.random().toString(36).slice(2, 11);
    }
    this.selectedIdlst = [];
    let temp = [];
    let selectedTemp = [];
    let isSelected = false;

    let curr;
    this.options.forEach((item, index) => {
      isSelected = this._value.includes(item.value);

      curr = {
        ...item,
        id: OPTION_PREFIX + index,
        checkboxId: this.instanceKey + "-" + OPTION_PREFIX + index,
        isSelected
      };
      temp.push(curr);

      if (isSelected) {
        this.selectedIdlst.push(curr.id);
        selectedTemp.push(curr);
      }
    });

    this.optionlst = [...temp];

    this.selectedlst = [...selectedTemp];
  }

  updateOptions() {
    let temp = [];
    let isSelected = false;
    this.optionlst.forEach((item) => {
      isSelected = this.selectedIdlst.includes(item.id);

      item.isSelected = isSelected;

      if (isSelected) {
        temp.push(item);
      }
    });

    this.selectedlst = [...temp];

    this.optionlst = [...this.optionlst];

    // Create a custom event
    const customEvent = new CustomEvent("change", {
      detail: { ids: this.value },
      bubbles: false,
      composed: false
    });

    // Dispatch the event
    this.dispatchEvent(customEvent);
  }

  handleDeleteOption(e) {
    e.stopPropagation();
    let dataId = e.currentTarget.dataset.id;

    let index = this.selectedIdlst.indexOf(dataId);

    if (index > -1) {
      this.selectedIdlst.splice(index, 1);
      this.updateOptions();
    }
  }

  @api checkValidity() {
    if (this.required && this.selectedlst.length == 0) {
      if (this.formElement) {
        this.formElement.classList.add("has-error");
      }
      this.isError = true;

      return false;
    }

    this.isError = false;
    if (this.formElement) {
      this.formElement.classList.remove("has-error");
    }

    return true;
  }

  handleChange(e) {
    let target = e.target;

    clearTimeout(this.timeoutHandler);

    this.timeoutHandler = setTimeout(() => {
      let keyword = target.value;

      this.optionlst.forEach((item) => {
        if (keyword && keyword.trim() != "") {
          item.isHidden = !item.label
            .toLowerCase()
            .includes(keyword.toLowerCase());
        } else {
          item.isHidden = false;
        }
      });
    }, 500);
  }

  @api reportValidity(handler, msg) {
    this.errorMsg = msg;
    return handler;
  }

  applySelectAll(isSelectAll) {
    if (isSelectAll) {
      let temp = [];

      this.optionlst.forEach((item) => {
        if (!item.isHidden) temp.push(item.id);
      });

      this.selectedIdlst = [...temp];
    } else {
      this.selectedIdlst = [];
    }

    this.updateOptions();
  }

  handleSelectAllChange(e) {
    e.stopPropagation();
    this.applySelectAll(e.target.checked);
  }

  handleSelectAllRow(e) {
    e.stopPropagation();

    if (e.target.closest(".slds-checkbox")) {
      return;
    }

    this.applySelectAll(!this.isSelectAll);
  }
}
