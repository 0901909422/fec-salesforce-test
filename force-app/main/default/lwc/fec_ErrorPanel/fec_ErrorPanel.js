import { LightningElement, api, track } from "lwc";
import FEC_MSG_Error_Panel_Title from "@salesforce/label/c.FEC_MSG_Error_Panel_Title";
import FEC_MSG_Error_Panel_Body from "@salesforce/label/c.FEC_MSG_Error_Panel_Body";

export default class Fec_ErrorPanel extends LightningElement {
  @api errors = [];

  @track errlst = [];

  customLabel = {
    errorPanelTitle: FEC_MSG_Error_Panel_Title,
    errorPanelBody: FEC_MSG_Error_Panel_Body
  }

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