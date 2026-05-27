import { LightningElement, api } from "lwc";

export default class Fec_NameLink extends LightningElement {
  @api rowId;
  @api label;
  @api columnName;

  handleClick(event) {
    event.preventDefault();
    event.stopPropagation();
    this.dispatchEvent(
      new CustomEvent("namelinkclick", {
        bubbles: true,
        composed: true,
        detail: { rowId: this.rowId, columnName: this.columnName || '' },
      })
    );
  }
}