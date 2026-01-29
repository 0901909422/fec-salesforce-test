import { LightningElement, api, track } from "lwc";

export default class Fec_ErrorPanel extends LightningElement {
  @api errors = [];

  @track errlst = [];

  connectedCallback() {
    this.errors.forEach((item, index) => {
      this.errlst.push({
        id: index,
        value: item
      });
    });
  }

  handleToggle(e) {
    const panel = this.template.querySelector(".error__panel");
    if (panel) {
      if (panel.classList.contains("open")) {
        panel.classList.remove("open");
      } else {
        panel.classList.add("open");
      }
    }
  }

  handleClose(e) {
    const panel = this.template.querySelector(".error__panel");
    if (panel) {
      panel.classList.remove("open");
    }
  }
}