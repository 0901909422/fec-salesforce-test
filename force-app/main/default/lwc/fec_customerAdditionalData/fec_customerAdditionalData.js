import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getAdditionalDataRows from '@salesforce/apex/FEC_CustomerAdditionalDataController.getAdditionalDataRows';
import FEC_ADDITIONAL_INFO_LABEL from '@salesforce/label/c.FEC_Additional_Info_Label';
import { STR_EMPTY } from 'c/fec_CommonConst';

export default class FecCustomerAdditionalData extends LightningElement {
    @api recordId;

    cardTitle = FEC_ADDITIONAL_INFO_LABEL;

    wiredResult;
    rows = [];
    error;
    loading = true;

    @wire(getAdditionalDataRows, { caseId: '$recordId' })
    wiredRows(value) {
        this.wiredResult = value;
        const { data, error } = value;
        this.loading = false;
        if (data) {
            this.rows = data.map((r, idx) => ({
                ...r,
                rowKey: (r.recordName || STR_EMPTY) + '-' + idx,
                showFile: !!(r.sourceFileName && String(r.sourceFileName).trim())
            }));
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.error = error;
        } else {
            this.rows = [];
        }
    }

    get hasRows() {
        return this.rows && this.rows.length > 0;
    }

    get showEmpty() {
        return !this.loading && !this.error && !this.hasRows;
    }

    get errorMessage() {
        if (!this.error || !this.error.body) {
            return STR_EMPTY;
        }
        const b = this.error.body;
        if (Array.isArray(b)) {
            return b.map((e) => e.message).join(' ');
        }
        return b.message || STR_EMPTY;
    }

    @api
    async refresh() {
        if (this.wiredResult) {
            this.loading = true;
            await refreshApex(this.wiredResult);
            this.loading = false;
        }
    }
}