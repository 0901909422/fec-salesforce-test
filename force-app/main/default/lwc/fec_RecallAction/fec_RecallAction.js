import { LightningElement, api } from 'lwc';
import run from "@salesforce/apex/FEC_CaseBusinessService.run";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEC_Toast_Save_Success_Title from "@salesforce/label/c.FEC_Toast_Save_Success_Title";
import FEC_Toast_Recall_Success from "@salesforce/label/c.FEC_Toast_Recall_Success";
import FEC_Toast_Error from "@salesforce/label/c.FEC_Toast_Error";
const RECALL = 'Recall';

export default class Fec_RecallAction extends LightningElement {
    label = {
        FEC_Toast_Save_Success_Title,
        FEC_Toast_Recall_Success,
        FEC_Toast_Error
    }
    @api recordId;
    @api invoke() {
        let params = {
          caseId: this.recordId,
        };
        
        run({ method: RECALL, params: params})
            .then(() => {
                this.showToast(this.label.FEC_Toast_Save_Success_Title, this.label.FEC_Toast_Recall_Success, 'success');
            })
            .catch(error => {
                this.showToast(this.label.FEC_Toast_Error, error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}