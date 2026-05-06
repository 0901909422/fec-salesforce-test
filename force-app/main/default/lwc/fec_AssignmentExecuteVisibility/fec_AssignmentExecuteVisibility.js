import { LightningElement, api, wire } from "lwc";
import canExecute from "@salesforce/apex/FEC_AssignmentExecuteService.canExecuteAssignment";

export default class Fec_AssignmentExecuteVisibility extends LightningElement {

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