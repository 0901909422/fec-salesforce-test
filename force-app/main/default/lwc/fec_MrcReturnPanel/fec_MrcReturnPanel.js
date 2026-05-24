import { LightningElement, api } from "lwc";
import { STR_EMPTY } from "c/fec_CommonConst";
import {
  FIELD_MRC_CUSTOMER_CONFIRMATION,
  FIELD_MRC_HANDLING_OPTION,
  MRC_CONF_NOT_RECEIVED,
  MRC_CONF_RECEIVED,
  isMrcNotReceivedConfirmation,
  shouldShowMrcHandlingRadio,
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
    return this.isEdit !== true;
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
      "Xác nhận khách hàng"
    );
  }

  get handlingOptionFieldLabel() {
    const labels = this.mrcRl05Ui?.caseFieldLabels;
    return (
      labels?.[FIELD_MRC_HANDLING_OPTION] ||
      "Phương án xử lý yêu cầu MRC"
    );
  }

  get confirmationPicklistOptions() {
    // Luôn dùng map label/value chuẩn — tránh bản dịch org bị đảo label↔value.
    return [
      {
        label: "Khách hàng đã xác nhận MRC",
        value: MRC_CONF_RECEIVED,
      },
      {
        label: "Khách hàng chưa xác nhận MRC",
        value: MRC_CONF_NOT_RECEIVED,
      },
    ];
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
    return false;
  }

  get customerConfirmationRequired() {
    return this.showCustomerConfirmation && this.isEdit !== false;
  }

  get hasDuplicateCase() {
    const id = String(this.duplicateCaseId ?? STR_EMPTY).trim();
    return id.length >= 15;
  }

  get showMrcHandlingRadioBlock() {
    if (!this.isRl0502 || this.mrcRl05Ui?.autoRouteReject === true) {
      return false;
    }
    return (
      isMrcNotReceivedConfirmation(this._confirmationValue) ||
      shouldShowMrcHandlingRadio(
        this._businessSnapshot,
        this._confirmationValue,
      )
    );
  }

  get hideMrcDupMessageForRadio() {
    if (!this.hasDuplicateCase) {
      return true;
    }
    return !isMrcNotReceivedConfirmation(this._confirmationValue);
  }

  get showDupBanner() {
    return false;
  }

  /** @deprecated use showMrcHandlingRadioBlock */
  get showHandlingRadioInline() {
    return false;
  }

  get showHandlingRadioBlock() {
    return this.showMrcHandlingRadioBlock;
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
      stageName: this.stageName,
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