import { LightningElement, api } from "lwc";

export default class Fec_Modal extends LightningElement {
  @api header;
  @api isLoading = false;

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }
}