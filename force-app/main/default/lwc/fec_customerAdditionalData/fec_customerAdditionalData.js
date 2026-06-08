import { LightningElement, api } from 'lwc';
import getAdditionalDataRows from '@salesforce/apex/FEC_CustomerAdditionalDataController.getAdditionalDataRows';
import FEC_ADDITIONAL_INFO_LABEL from '@salesforce/label/c.FEC_Additional_Info_Label';
import { STR_EMPTY } from 'c/fec_CommonConst';

export default class FecCustomerAdditionalData extends LightningElement {
    @api recordId;

    cardTitle = FEC_ADDITIONAL_INFO_LABEL;

    rows = [];
    error;
    loading = true;

    // 05/06/2026 18:00 linhdev - imperative call thay @wire: Apex không cacheable, luôn query mới khi load/refresh
    connectedCallback() {
        if (this.recordId) {
            this.loadRows();
        }
    }

    async loadRows() {
        if (!this.recordId) {
            this.rows = [];
            this.loading = false;
            return;
        }
        this.loading = true;
        try {
            const data = await getAdditionalDataRows({ caseId: this.recordId });
            this.rows = (data || []).map((r, idx) => ({
                ...r,
                rowKey: (r.recordName || STR_EMPTY) + '-' + idx,
                showFile: !!(r.sourceFileName && String(r.sourceFileName).trim())
            }));
            this.error = undefined;
        } catch (error) {
            this.rows = [];
            this.error = error;
        } finally {
            this.loading = false;
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
        await this.loadRows();
    }
}
