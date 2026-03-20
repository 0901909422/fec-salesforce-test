import { LightningElement, api } from "lwc";

export default class Fec_RadioCell extends LightningElement {
  @api rowId;
  @api selected;

  get iconName() {
    return this.selected
      ? "utility:radio_button_checked"
      : "utility:radio_button_unchecked";
  }

  handleClick(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("radioclick", {
        bubbles: true,
        composed: true,
        detail: { rowId: this.rowId },
      }),
    );
  }

  handleDoubleClick(event) {
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("radiodblclick", {
        bubbles: true,
        composed: true,
        detail: { rowId: this.rowId },
      }),
    );
  }
}