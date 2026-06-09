import { LightningElement, api } from "lwc";
import { ICON_HIDE, ICON_PREVIEW } from "c/fec_CommonConst";

export default class Fec_MaskedContactTemplate extends LightningElement {
  @api maskedValue;
  @api rawValue;
  @api isVisible;
  @api rowId;

  get displayValue() {
    return this.isVisible
      ? this.rawValue
      : this.maskedValue;
  }

  get iconName() {
    return this.isVisible
      ?ICON_PREVIEW 
      :ICON_HIDE;
  }

  handleToggle() {
    this.dispatchEvent(
      new CustomEvent("togglemask", {
        bubbles: true,
        composed: true,
        detail: {
          rowId: this.rowId
        }
      })
    );
  }
}