import { LightningElement, api, wire } from "lwc";
import canExecute from "@salesforce/apex/FEC_CaseExecuteService.canExecute";

export default class Fec_CaseExecuteVisibility extends LightningElement {

    @api recordId;

    canExecute;

    @wire(canExecute, { caseId: "$recordId" })
    wiredResult({ data, error }) {

        if (data) {
            this.canExecute = data.value;
        }

        if (error) {
            console.error(error);
        }
    }
}