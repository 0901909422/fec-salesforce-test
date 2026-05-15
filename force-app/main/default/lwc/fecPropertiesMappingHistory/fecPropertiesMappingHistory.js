import { LightningElement, api, wire, track } from 'lwc';
import getPropertiesMappingHistory from '@salesforce/apex/FEC_HistoryController.getPropertiesMappingHistory';
import { refreshApex } from '@salesforce/apex';

export default class FecPropertiesMappingHistory extends LightningElement {
    @api natureOfCaseCode;
    @track lstHistory;
    @track error;
    isLoading = true;
    wiredResult;

    get hasHistory() { return this.lstHistory && this.lstHistory.length > 0; }

    @wire(getPropertiesMappingHistory, { natureOfCaseCode: '$natureOfCaseCode' })
    wiredHistory(result) {
        this.wiredResult = result;
        if (result.data) {
            this.lstHistory = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body?.message || result.error.message;
            this.lstHistory = undefined;
        }
        this.isLoading = false;
    }

    @api
    refreshData() {
        if (this.wiredResult) {
            this.isLoading = true;
            const prev = this.lstHistory ? this.lstHistory.length : 0;
            return refreshApex(this.wiredResult).then(() => {
                const curr = this.lstHistory ? this.lstHistory.length : 0;
                if (curr === prev) {
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    return new Promise(r => setTimeout(() => refreshApex(this.wiredResult).then(r).catch(r), 1000));
                }
            }).finally(() => { this.isLoading = false; });
        }
        return Promise.resolve();
    }
}