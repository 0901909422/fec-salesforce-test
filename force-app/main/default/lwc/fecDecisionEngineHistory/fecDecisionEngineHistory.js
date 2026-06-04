import { LightningElement, api, track } from 'lwc';
import getHistory from '@salesforce/apex/FEC_ContentHistoryTrackingController.getDecisionEngineHistory';

export default class FecDecisionEngineHistory extends LightningElement {
    @api recordId;
    @track lstHistory = [];
    @track isLoading = false;

    get hasHistory() {
        return this.lstHistory && this.lstHistory.length > 0;
    }

    connectedCallback() {
        this.loadHistory();
    }

    async loadHistory() {
        this.isLoading = true;
        try {
            const result = await getHistory({ recordId: this.recordId });
            this.lstHistory = result || [];
        } catch (error) {
            console.error('FecDecisionEngineHistory error:', error);
            this.lstHistory = [];
        } finally {
            this.isLoading = false;
        }
    }
}
