import { LightningElement } from 'lwc';
import lblPushRecordsTitle from '@salesforce/label/c.FEC_Lbl_Push_Records_Title';
import lblTypeOfRecord from '@salesforce/label/c.FEC_Lbl_Type_Of_Record';
import lblExistingRecords from '@salesforce/label/c.FEC_Lbl_Existing_Records';
import lblFreshRecords from '@salesforce/label/c.FEC_Lbl_Fresh_Records';
import lblCallbackRecords from '@salesforce/label/c.FEC_Lbl_Callback_Records';
import btnCancel from '@salesforce/label/c.FEC_Btn_Cancel';
import btnComplete from '@salesforce/label/c.FEC_Btn_Complete';

export default class FecPushRecordsModal extends LightningElement {
    label = {
        lblPushRecordsTitle,
        lblTypeOfRecord,
        lblExistingRecords,
        lblFreshRecords,
        lblCallbackRecords,
        btnCancel,
        btnComplete
    };

    selectedType = 'fresh';

    get isExistingSelected() {
        return this.selectedType === 'existing';
    }

    get isFreshSelected() {
        return this.selectedType === 'fresh';
    }

    get isCallbackSelected() {
        return this.selectedType === 'callback';
    }

    handleTypeChange(event) {
        this.selectedType = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleComplete() {
        this.dispatchEvent(new CustomEvent('complete', {
            detail: { recordType: this.selectedType }
        }));
    }
}
