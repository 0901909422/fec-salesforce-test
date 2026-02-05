import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import syncStatementFromAPI
    from '@salesforce/apex/FEC_StatementsAccountController.syncStatementFromAPI';
import loadGeneralStatementInfo
    from '@salesforce/apex/FEC_StatementsAccountController.loadGeneralStatementInfo';
import loadStatementDetails
    from '@salesforce/apex/FEC_StatementsAccountController.loadStatementDetails';

export default class Fec_StatementsAccount extends NavigationMixin(LightningElement) {

    /* ================= API ================= */
    @api recordId;

    /* ================= UI STATE ================= */
    activeSections = [
        'General Statement Info',
        'Statement Details'
    ];

    isLoading = false;
    error;

    /* ================= DATA ================= */
    generalStatementInfoFields = [];
    statementDetails = [];

    /* ================= TABLE COLUMNS ================= */
    statementDetailsColumns = [
        {
            label: 'Statement Date',
            fieldName: 'statementDate',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: 'Statement Details',
            hoverFields: [
               { label: 'Statement Date', fieldName: 'statementDate'},
                { label: 'Current Payment Due', fieldName: 'currentPaymentDue'},
                { label: 'Total Past Due', fieldName: 'totalPastDue'},
                { label: 'Beginning Balance', fieldName: 'beginningBalance'},
                { label: 'End Balance', fieldName: 'endingBalance'},
                { label: 'Total Interest', fieldName: 'totalInterest'},
                { label: 'IPP Principal', fieldName: 'ippPrincipal'},
                { label: 'IPP Interest', fieldName: 'ippInterest'}
            ]
        },
        {
            label: 'Total Payment Due',
            fieldName: 'totalPaymentDue',
            type: 'text'
        },
        {
            label: 'Minimum Payment Due',
            fieldName: 'minimumPaymentDue',
            type: 'text'
        },
        {
            label: 'Payment Due Date',
            fieldName: 'paymentDueDate',
            type: 'text'
        }
    ];

    /* ================= LIFECYCLE ================= */
    connectedCallback() {
        this.loadData();
    }

    /* ================= LOAD DATA ================= */
    async loadData() {
        if (!this.recordId) return;

        this.isLoading = true;

        try {
            await syncStatementFromAPI({ caseId: this.recordId });

            const [general, details] = await Promise.all([
                loadGeneralStatementInfo({ caseId: this.recordId }),
                loadStatementDetails({ caseId: this.recordId })
            ]);

            this.mapGeneralStatementInfo(general);
            this.mapStatementDetails(details);

            this.error = undefined;
        } catch (err) {
            this.error = err;
            console.error(err);
        } finally {
            this.isLoading = false;
        }
    }

    /* ================= MAP GENERAL INFO ================= */
    mapGeneralStatementInfo(dto) {
        if (!dto) {
            this.generalStatementInfoFields = [];
            return;
        }

        this.generalStatementInfoFields = [
            { label: 'Billing Cycle', value: dto.billingCycle ?? '-' },
            { label: 'Total Payment Due', value: this.formatNumber(dto.totalPaymentDue) },
            { label: 'Last Statement Date', value: this.formatDate(dto.lastStatementDate) },
            { label: 'Minimum Payment Due', value: this.formatNumber(dto.minimumPaymentDue) },
            { label: 'Next Statement Date', value: this.formatDate(dto.nextStatementDate) },
            { label: 'Payment Due Date', value: this.formatDate(dto.paymentDueDate) }
        ];
    }

    /* ================= MAP STATEMENT DETAILS ================= */
    mapStatementDetails(data = []) {
        this.statementDetails = data.map(row => ({
            Id: row.statementId,

            statementDate: this.formatDate(row.statementDate),
            paymentDueDate: this.formatDate(row.paymentDueDate),

            totalPaymentDue: this.formatNumber(row.totalPaymentDue),
            minimumPaymentDue: this.formatNumber(row.minimumPaymentDue),

            beginningBalance: this.formatNumber(row.beginningBalance),
            endingBalance: this.formatNumber(row.endingBalance),
            totalInterest: this.formatNumber(row.totalInterest),
            ippPrincipal: this.formatNumber(row.ippPrincipal),
            ippInterest: this.formatNumber(row.ippInterest),
            totalPastDue: this.formatNumber(row.totalPastDue)
        }));
    }

    /* ================= LINK CLICK ================= */
    handleStatementSelect(event) {
        const statementId = event.detail.recordId;
        if (!statementId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'statements' },
            state: { c__statementId: statementId }
        });
    }

    /* ================= FORMATTERS ================= */

    // dd/MM/yyyy
    formatDate(value) {
        if (!value) return '-';

        const d = new Date(value);
        if (isNaN(d.getTime())) return '-';

        const day = String(d.getDate()).padStart(2, '0');
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const year = d.getFullYear();

        return `${day}/${month}/${year}`;
    }

    // number with thousand separators
    formatNumber(value) {
        if (value === null || value === undefined || value === '') return '';
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(value);
    }

    // currency VND
    formatCurrency(value) {
        if (value === null || value === undefined) return '-';

        const formatted = new Intl.NumberFormat('vi-VN', {
            style: 'currency',
            currency: 'VND',
            maximumFractionDigits: 0
        }).format(Math.abs(value));

        return value < 0 ? `-${formatted}` : formatted;
    }
}