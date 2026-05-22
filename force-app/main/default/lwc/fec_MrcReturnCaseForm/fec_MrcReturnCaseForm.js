import { LightningElement, api } from "lwc";
import { STR_EMPTY } from "c/fec_CommonConst";
import {
  FIELD_MRC_HANDLING_OPTION,
  showMrcRl0502DupBanner,
} from "c/fecMrcReturnCaseLogic";

export default class Fec_MrcReturnCaseForm extends LightningElement {
  @api recordId;
  @api subCodeCode;
  @api subCategoryCode;
  @api isEdit = false;
  @api mrcRl05Ui;
  @api duplicateCaseId;
  @api duplicateCaseNumber;
  @api handlingOptionValue = STR_EMPTY;

  get showStandaloneDupBanner() {
    if (!showMrcRl0502DupBanner(this._businessSnapshot)) {
      return false;
    }
    return this.mrcRl05Ui?.dupCaseOnly === true;
  }

  get _businessSnapshot() {
    return {
      mrcRl05Ui: this.mrcRl05Ui,
      mrcRl0502DuplicateOpenCaseId: this.duplicateCaseId,
      mrcRl0502DuplicateCaseNumber: this.duplicateCaseNumber,
    };
  }

  get isReadOnly() {
    return this.isEdit === false;
  }

  get trackedFieldApiName() {
    return FIELD_MRC_HANDLING_OPTION;
  }

  handleHandlingOptionChange(event) {
    const detail = event.detail || {};
    this.dispatchEvent(
      new CustomEvent("fecmrcreturnhandlingchange", {
        detail,
        bubbles: true,
        composed: true,
      }),
    );
  }

  @api validateForSubmit() {
    if (!showMrcRl0502DupBanner(this._businessSnapshot)) {
      return true;
    }
    return Boolean(this.handlingOptionValue);
  }

  @api getHandlingOptionValue() {
    return this.handlingOptionValue || STR_EMPTY;
  }

  @api getTrackedFieldApiName() {
    return FIELD_MRC_HANDLING_OPTION;
  }
}
