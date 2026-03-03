import { LightningElement, api } from 'lwc';
import run from "@salesforce/apex/FEC_CaseBusinessService.run";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const RECALL = 'Recall';

export default class Fec_RecallAction extends LightningElement {
    @api recordId;
    @api invoke() {
        let params = {
          caseId: this.recordId,
        };
        
        run({ method: RECALL, params: params})
            .then(() => {
                this.showToast('Success', 'Thực hiện Recall thành công.', 'success');
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