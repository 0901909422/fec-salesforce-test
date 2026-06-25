import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getArchiveInteractions from '@salesforce/apex/FEC_SearchArchiveInteraction.getArchiveInteractions';
import getArchiveServiceCases from '@salesforce/apex/FEC_SearchArchiveInteraction.getArchiveServiceCases';
import { STR_NA, MSG_NO_RESULTS, MSG_UNKNOWN_ERROR, STR_EMPTY } from 'c/fec_CommonConst';
import { formatDateTime } from 'c/fec_CommonUtils';
import FEC_Button_Refresh from '@salesforce/label/c.FEC_Button_Refresh';

const MODE_SERVICE_CASES = 'serviceCases';

export default class Fec_SearchArchiveInteraction extends LightningElement {
    _recordId;
    _connected = false;

    // Chế độ hiển thị: 'interactions' (mặc định) hoặc 'serviceCases'.
    // Cấu hình trong Lightning App Builder để dùng lại component trên 2 tab khác nhau.
    @api displayMode = 'interactions';

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (!value || value === this._recordId) {
            return;
        }
        this._recordId = value;
        if (this._connected) {
            this.fetchData();
        }
    }

    get isServiceCaseMode() {
        return this.displayMode === MODE_SERVICE_CASES;
    }

    @track data = [];
    @track lastRefreshTime = null;
    @track isLoading = false;
    @track error;

    sortedBy = 'caseId';

    activeSections = ['archiveInteractions'];

    emptyMessage = MSG_NO_RESULTS;

    customLabel = {
        refresh: FEC_Button_Refresh,
        accountNumberLabel: 'Account Number',
        contractNumberLabel: 'Contract Number',
        customerNameLabel: 'Customer Name',
        migrationSourceLabel: 'Migration Source',
        s3PathLabel: 'S3 Path',
        externalIdLabel: 'External ID',
    };

    // Tiêu đề section + label cột ID đổi theo chế độ hiển thị.
    get sectionTitle() {
        return this.isServiceCaseMode ? 'Archive Service Cases' : 'Archive Interactions';
    }

    get caseIdLabel() {
        return this.isServiceCaseMode ? 'Service Case ID' : 'Interaction ID';
    }

    get channelLabel() {
        return this.isServiceCaseMode ? 'Service Channel' : 'Interaction Channel';
    }

    get archiveColumns() {
        const idCol = {
            label: this.caseIdLabel,
            fieldName: 'caseId',
            type: 'link',
            recordIdField: 'externalId',
            actionKey: 'open_case',
            cellAlign: 'center',
            initialWidth: 160
        };

        // Service Cases mode: bám cột theo mẫu Closed/Pending Service Cases
        if (this.isServiceCaseMode) {
            return [
                idCol,
                { label: 'Case Status', fieldName: 'status', type: 'text', cellAlign: 'center' },
                { label: 'Account / Contract Number', fieldName: 'accountContractNumber', type: 'text' },
                { label: 'Sub Category', fieldName: 'subcategory', type: 'text' },
                { label: 'Sub Code', fieldName: 'subcode', type: 'text' },
                { label: 'Interaction ID', fieldName: 'currentInteractionId', type: 'text', cellAlign: 'center' },
                { label: this.channelLabel, fieldName: 'interactionChannel', type: 'text', cellAlign: 'center' },
                { label: 'Case Created On', fieldName: 'pxcreatedatetime', type: 'text', cellAlign: 'center' },
                { label: 'Migration Source', fieldName: 'migrationSource', type: 'text', cellAlign: 'center' },
            ];
        }

        // Interactions mode: bám cột theo mẫu Interactions
        return [
            idCol,
            { label: 'Interaction Status', fieldName: 'status', type: 'text', cellAlign: 'center' },
            { label: this.channelLabel, fieldName: 'interactionChannel', type: 'text', cellAlign: 'center' },
            { label: 'Interaction Created On', fieldName: 'pxcreatedatetime', type: 'text', cellAlign: 'center' },
            { label: 'Interaction Phone', fieldName: 'phone', type: 'text', cellAlign: 'center' },
            { label: 'Migration Source', fieldName: 'migrationSource', type: 'text', cellAlign: 'center' },
        ];
    }

    get archiveRecords() {
        return this.data;
    }

    get hasArchiveRecords() {
        return this.data && this.data.length > 0;
    }

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const idFromPage = pageRef?.attributes?.recordId;
        if (!idFromPage || idFromPage === this._recordId) {
            return;
        }
        this._recordId = idFromPage;
        if (this._connected) {
            this.fetchData();
        }
    }

    connectedCallback() {
        this._connected = true;
        if (this._recordId) {
            this.fetchData();
        }
    }

    async fetchData() {
        if (!this._recordId) {
            this.data = [];
            return;
        }
        this.isLoading = true;
        this.error = undefined;
        try {
            const apexMethod = this.isServiceCaseMode ? getArchiveServiceCases : getArchiveInteractions;
            const result = await apexMethod({ recordId: this._recordId });
            this.lastRefreshTime = new Date().toISOString();

            // Process data - store all needed fields
            this.data = (result || []).map((row) => {
                return {
                    ...row,
                    caseId: row.caseId || STR_EMPTY,
                    caseUrl: row.caseUrl || '#',
                    s3Path: row.s3Path || STR_NA,
                    accountNumber: row.accountNumber || STR_NA,
                    contractNumber: row.contractNumber || STR_NA,
                    accountContractNumber: row.accountNumber || row.contractNumber || STR_NA,
                    customerName: row.customerName || STR_NA,
                    migrationSource: row.migrationSource || STR_NA,
                    status: row.status || STR_NA,
                    phone: row.phone || STR_NA,
                    currentInteractionId: row.currentInteractionId || STR_NA,
                    subcategory: row.subcategory || STR_NA,
                    subcode: row.subcode || STR_NA,
                    pxcreatedatetime: formatDateTime(row.pxcreatedatetime) || STR_NA,
                };
            });
        } catch (e) {
            this.error = e.body?.message || e.message || MSG_UNKNOWN_ERROR;
            this.data = [];
        } finally {
            this.isLoading = false;
        }
    }

    handleRowSelect(event) {
        const { actionKey, recordId } = event.detail;

        if (actionKey === 'open_case') {
            // Find the row data by externalId
            const row = this.data.find(r => r.externalId === recordId);
            if (row && row.caseUrl) {
                window.open(row.caseUrl, '_blank');
            }
        }
    }

    handleRefresh() {
        this.fetchData();
    }

    get showTable() {
        return !this.isLoading && !this.error;
    }
}