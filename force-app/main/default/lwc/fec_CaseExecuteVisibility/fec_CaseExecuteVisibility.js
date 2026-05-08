import { LightningElement, api } from "lwc";
import canExecute from "@salesforce/apex/FEC_CaseExecuteService.canExecute";

export default class Fec_CaseExecuteVisibility extends LightningElement {
  @api recordId;

  canExecute;

  renderedCallback() {
    console.log("recordId=", this.recordId);

    if (this.recordId && !this.loaded) {
      this.loaded = true;

      canExecute({ caseId: this.recordId })
        .then((result) => {
          console.log("RESULT=", result);

          this.canExecute = result.value;
        })
        .catch((error) => {
          console.error("ERROR=", error);
        });
    }
  }
}
