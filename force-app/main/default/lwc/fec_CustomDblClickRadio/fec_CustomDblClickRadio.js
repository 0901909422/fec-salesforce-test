import { LightningElement, api } from "lwc";

export default class Fec_CustomDblClickRadio extends LightningElement {
  @api typeAttributes;
  handleDblClick(event) {
    const rowId = event.target.dataset.id;

    const detail = {
      action: {
        name: "create_history",
      },
      row: rowId,
    };

    this.dispatchEvent(
      new CustomEvent("rowaction", {
        detail,
        bubbles: true,
        composed: true,
      }),
    );
  }
}
