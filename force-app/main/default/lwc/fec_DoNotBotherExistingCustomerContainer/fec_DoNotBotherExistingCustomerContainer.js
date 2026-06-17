import { LightningElement, api } from "lwc";
import getCaseData from "@salesforce/apex/FEC_DNBHandler.getCaseData";

export default class Fec_DoNotBotherExistingCustomerContainer extends LightningElement {
  @api recordId;

  nationalIds = [];

  async connectedCallback() {
    try {
      const result = await getCaseData({
        caseId: this.recordId,
      });

      this.nationalIds = (result.nationalIds || "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
    } catch (e) {
      console.error(e);
    }
  }
}
