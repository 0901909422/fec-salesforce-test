import { LightningElement, api, wire, track } from 'lwc';
import getSettingHistoryByIds from '@salesforce/apex/FEC_HistoryController.getSettingHistoryByIds';
import { refreshApex } from '@salesforce/apex';

export default class FecSettingHistoryByNoc extends LightningElement {
    @api nocId;
    @api isIntegration = null; // null=all, true=fraud, false=property
    @track lstHistory;
    @track error;
    isLoading = true;
    wiredResult;

    get hasHistory() { return this.lstHistory && this.lstHistory.length > 0; }

    @wire(getSettingHistoryByIds, { nocId: '$nocId', isIntegration: '$isIntegration' })
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