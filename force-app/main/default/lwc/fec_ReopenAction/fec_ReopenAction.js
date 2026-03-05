import { LightningElement, api } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import run from "@salesforce/apex/FEC_CaseBusinessService.run";
import FEC_Toast_Save_Success_Title from "@salesforce/label/c.FEC_Toast_Save_Success_Title";
import FEC_Toast_Reopen_Success from "@salesforce/label/c.FEC_Toast_Reopen_Success";
import FEC_Toast_Error from "@salesforce/label/c.FEC_Toast_Error";

const REOPEN = 'Reopen';
export default class Fec_ReopenAction extends LightningElement {
    label = {
        FEC_Toast_Save_Success_Title,
        FEC_Toast_Reopen_Success,
        FEC_Toast_Error
    }
    @api recordId; 
    @api invoke() {
            let params = {
              caseId: this.recordId,
            };
            
            run({ method: REOPEN, params })
                .then(() => {
                    this.showToast(this.label.FEC_Toast_Save_Success_Title, this.label.FEC_Toast_Reopen_Success, 'success');
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