import { LightningElement, api } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import run from "@salesforce/apex/FEC_CaseBusinessService.run";

const REOPEN = 'Reopen';
export default class Fec_ReopenAction extends LightningElement {
    @api recordId; 
    @api invoke() {
            let params = {
              caseId: this.recordId,
            };
            
            run({ method: REOPEN, params })
                .then(() => {
                    this.showToast('Success', 'Thực hiện Reopen thành công.', 'success');
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
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