import { LightningElement, api } from "lwc";

import canExecute
    from "@salesforce/apex/FEC_AssignmentExecuteService.canExecuteAssignment";

export default class Fec_AssignmentExecuteVisibility
    extends LightningElement {

    @api recordId;

    canExecute = false;

    isLoaded = false;

    renderedCallback() {

        if (this.isLoaded || !this.recordId) {
            return;
        }

        this.isLoaded = true;

        console.log('recordId=', this.recordId);

        canExecute({
            caseId: this.recordId
        })
        .then(result => {

            console.log('RESULT=', result);

            this.canExecute = result.value;

        })
        .catch(error => {

            console.error('ERROR=', error);
        });
    }
}