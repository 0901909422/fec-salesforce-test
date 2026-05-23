import { LightningElement, api } from "lwc";
import { STR_EMPTY } from "c/fec_CommonConst";
import {
  FIELD_MRC_CUSTOMER_CONFIRMATION,
  FIELD_MRC_HANDLING_OPTION,
  isMrcNotReceivedConfirmation,
  showMrcRl0502DupBanner,
  shouldShowMrcReturnDelivery,
} from "c/fecMrcReturnCaseLogic";

/**
 * RL05 MRC Return — panel gom Delivery Option + Xác nhận KH (RL05.02) + Noti-11.
 */
export default class Fec_MrcReturnPanel extends LightningElement {
  @api recordId;
  @api subCodeCode;
  @api subCategoryCode;
  @api stageName;
  @api isEdit = false;
  @api mrcRl05Ui;
  @api duplicateCaseId;
  @api duplicateCaseNumber;
  @api handlingOptionValue = STR_EMPTY;
  @api customerConfirmationOptions;
  @api handlingOptionOptions;

  customerConfirmationField = FIELD_MRC_CUSTOMER_CONFIRMATION;
  handlingOptionField = FIELD_MRC_HANDLING_OPTION;
  _confirmationValue = STR_EMPTY;

  @api
  get customerConfirmationValue() {
    return this._confirmationValue;
  }
  set customerConfirmationValue(value) {
    this._confirmationValue = value ?? STR_EMPTY;
  }

  get isReadOnly() {
    return this.isEdit === false;
  }

  get isRl0502() {
    const code = String(this.subCodeCode ?? STR_EMPTY).toUpperCase();
    if (code.includes("RL05.02")) {
      return true;
    }
    const stage = String(this.stageName ?? STR_EMPTY).toUpperCase();
    if (stage.includes("RL05.02")) {
      return true;
    }
    if (this.mrcRl05Ui?.isReturnSubCode === true) {
      return true;
    }
    const subCat = String(this.subCategoryCode ?? STR_EMPTY).toUpperCase();
    return subCat.includes("RL05") && code.includes("RL05") && !this.isRl05PhotoSubCode;
  }

  get isRl05PhotoSubCode() {
    const code = String(this.subCodeCode ?? STR_EMPTY).toUpperCase();
    return code.includes("RL05.01") || code.includes("RL05.03");
  }

  get showCustomerConfirmation() {
    if (!this.isRl0502) {
      return false;
    }
    if (this.mrcRl05Ui?.autoRouteReject === true) {
      return false;
    }
    if (!this.mrcRl05Ui) {
      return true;
    }
    return this.mrcRl05Ui.showCustomerConfirmation !== false;
  }

  get customerConfirmationFieldLabel() {
    const labels = this.mrcRl05Ui?.caseFieldLabels;
    return (
      labels?.[FIELD_MRC_CUSTOMER_CONFIRMATION] ||
      FIELD_MRC_CUSTOMER_CONFIRMATION
    );
  }

  get confirmationPicklistOptions() {
    const fromBusiness = Array.isArray(this.customerConfirmationOptions)
      ? this.customerConfirmationOptions
      : [];
    return fromBusiness.map((o) => ({
      label: o.label || o.value,
      value: o.value,
    }));
  }

  get handlingOptionPicklistOptions() {
    const fromBusiness = Array.isArray(this.handlingOptionOptions)
      ? this.handlingOptionOptions
      : [];
    return fromBusiness.map((o) => ({
      label: o.label || o.value,
      value: o.value,
    }));
  }

  get showStandaloneDupBanner() {
    if (this.showCustomerConfirmation) {
      return false;
    }
    if (this.mrcRl05Ui?.showMrcDupBanner !== true) {
      return false;
    }
    return showMrcRl0502DupBanner(this._businessSnapshot);
  }

  get customerConfirmationRequired() {
    return this.showCustomerConfirmation && this.isEdit !== false;
  }

  get hasDuplicateCase() {
    const id = String(this.duplicateCaseId ?? STR_EMPTY).trim();
    return id.length >= 15;
  }

  get showDupBanner() {
    if (!this.showCustomerConfirmation) {
      return false;
    }
    if (!isMrcNotReceivedConfirmation(this._confirmationValue)) {
      return false;
    }
    return this.hasDuplicateCase || showMrcRl0502DupBanner(this._businessSnapshot);
  }

  /** TH3: Cond2, Chưa nhận MRC — Noti-11 radio (không có Case trùng). */
  get showHandlingRadioInline() {
    if (!this.showCustomerConfirmation) {
      return false;
    }
    if (this.showDupBanner) {
      return false;
    }
    if (this.mrcRl05Ui?.showHandlingRadioOnNotReceived !== true) {
      return false;
    }
    return isMrcNotReceivedConfirmation(this._confirmationValue);
  }

  get showHandlingRadioBlock() {
    return this.showDupBanner || this.showStandaloneDupBanner || this.showHandlingRadioInline;
  }

  get showDelivery() {
    if (this.isRl05PhotoSubCode) {
      return true;
    }
    if (!this.isRl0502 && !this.isRl05PhotoSubCode) {
      return false;
    }
    return shouldShowMrcReturnDelivery(
      this.mrcRl05Ui,
      this._businessSnapshot,
      this.handlingOptionValue,
      this._confirmationValue,
    );
  }

  get _businessSnapshot() {
    return {
      subCodeCode: this.subCodeCode,
      subCategoryCode: this.subCategoryCode,
      mrcRl05Ui: this.mrcRl05Ui,
      mrcRl0502DuplicateOpenCaseId: this.duplicateCaseId,
      mrcRl0502DuplicateCaseNumber: this.duplicateCaseNumber,
    };
  }

  handleCustomerConfirmationChange(event) {
    const value = event.detail?.value ?? STR_EMPTY;
    this._confirmationValue = value;
    this.dispatchEvent(
      new CustomEvent("customerconfirmationchange", {
        detail: { value, fieldName: FIELD_MRC_CUSTOMER_CONFIRMATION },
        bubbles: true,
        composed: true,
      }),
    );
  }

  handleHandlingOptionChange(event) {
    this.dispatchEvent(
      new CustomEvent("handlingoptionchange", {
        detail: event.detail || {},
        bubbles: true,
        composed: true,
      }),
    );
  }

  handleMrcDeliveryChange(event) {
    this.dispatchEvent(
      new CustomEvent("mrcdeliverychange", {
        detail: event.detail || {},
        bubbles: true,
        composed: true,
      }),
    );
  }

  @api getDeliveryForm() {
    return this.template.querySelector("c-fec_-mrc-delivery-form");
  }

  @api validateForSubmit() {
    if (
      this.showCustomerConfirmation &&
      this.customerConfirmationRequired &&
      !String(this._confirmationValue ?? STR_EMPTY).trim()
    ) {
      return false;
    }
    if (this.showHandlingRadioBlock && !this.handlingOptionValue) {
      return false;
    }
    const delivery = this.getDeliveryForm();
    if (delivery && typeof delivery.validateForSubmit === "function") {
      return delivery.validateForSubmit();
    }
    return true;
  }

  @api async saveToCase() {
    const delivery = this.getDeliveryForm();
    if (delivery && typeof delivery.saveToCase === "function") {
      return delivery.saveToCase();
    }
    return { valid: true, messages: [] };
  }

  @api async saveDraftIfApplicable() {
    const delivery = this.getDeliveryForm();
    if (delivery && typeof delivery.saveDraftIfApplicable === "function") {
      return delivery.saveDraftIfApplicable();
    }
    return { valid: true, messages: [] };
  }

  @api getHandlingOptionValue() {
    return this.handlingOptionValue || STR_EMPTY;
  }
}
