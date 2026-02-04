import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import loadUnbilledTransactions
    from '@salesforce/apex/FEC_TransactionsController.loadUnbilledTransactions';

export default class Fec_TransactionsAccount
    extends NavigationMixin(LightningElement) {

    /* ================= API ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track unbilledTransactions = [];
    @track pendingTransactions = [];
    @track isLoading = false;

    activeSections = [
        'unbilledTransactions',
        'pendingTransactions'
    ];

    /* ================= COLUMNS ================= */
    unbilledTransactionsColumns = [
        {
            label: 'Transaction Code',
            fieldName: 'transactionCode',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: 'Unbilled Transactions',
            hoverFields: [
                { label: 'Transaction Code', fieldName: 'transactionCode' }
            ]
        },
        { label: 'Effective Date', fieldName: 'effectiveDate', type: 'text' },
        { label: 'Post Date', fieldName: 'postDate', type: 'text' },
        { label: 'Transaction Amount', fieldName: 'transactionAmount', type: 'text' },
        { label: 'Merchant Description', fieldName: 'merchantDescription', type: 'text' },
        { label: 'Credit Debit Flag', fieldName: 'creditDebitFlag', type: 'text' }
    ];

    pendingTransactionsColumns = [
        {
            label: 'Transaction Code',
            fieldName: 'transactionCode',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: 'Pending Transactions',
            hoverFields: [
                { label: 'Transaction Code', fieldName: 'transactionCode' }
            ]
        },
        { label: 'Effective Date', fieldName: 'effectiveDate', type: 'text' },
        { label: 'Post Date', fieldName: 'postDate', type: 'text' },
        { label: 'Transaction Amount', fieldName: 'transactionAmount', type: 'text' },
        { label: 'Merchant Description', fieldName: 'merchantDescription', type: 'text' },
        { label: 'Credit Debit Flag', fieldName: 'creditDebitFlag', type: 'text' }
    ];

    /* ================= LIFECYCLE ================= */
    connectedCallback() {
        this.loadTransactions();
    }

    /* ================= LOAD DATA ================= */
    loadTransactions() {
        if (!this.recordId) {
            console.error('[FEC] recordId is missing');
            return;
        }

        this.isLoading = true;

        loadUnbilledTransactions({
            caseId: this.recordId,
            fromDate: null,
            toDate: null
        })
            .then(res => {
                console.log('[FEC] RAW res ===>', JSON.stringify(res));

                const rows = Array.isArray(res?.transactions)
                    ? res.transactions
                    : [];

                const mapped = rows.map(tx => this.mapTransaction(tx));

                // NOTE: hiện backend chưa phân loại
                this.unbilledTransactions = mapped;
                this.pendingTransactions = mapped;
            })
            .catch(err => {
                console.error('[FEC] loadTransactions error', err);
                this.unbilledTransactions = [];
                this.pendingTransactions = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= DATA MAPPER ================= */
    mapTransaction(tx) {
        return {
            // Preserve raw fields
            ...tx,

            // Required for table
            Id: tx.Id,

            // Display fields
            transactionCode: tx.transactionCode ?? '',
            merchantDescription: tx.merchantDescription ?? '',
            creditDebitFlag: tx.creditDebitFlag ?? '',

            effectiveDate: this.formatDate(tx.effectiveDate),
            postDate: this.formatDate(tx.postDate || tx.postingDate),

            transactionAmount: this.formatNumber(
                tx.transactionAmount ?? tx.amount
            )
        };
    }

    /* ================= FORMATTERS ================= */
    formatDate(value) {
        if (!value) return '';
        try {
            const d = new Date(value);
            if (isNaN(d.getTime())) return value;
            return d.toLocaleDateString('en-GB');
        } catch {
            return value;
        }
    }

    formatNumber(value) {
        if (value === null || value === undefined) return '';
        try {
            return new Intl.NumberFormat('en-US').format(value);
        } catch {
            return value;
        }
    }

    /* ================= ROW SELECT ================= */
    handleTransactionSelect(event) {
        const recordId = event.detail?.recordId;
        if (!recordId) return;

        const sectionType = event.currentTarget?.dataset?.section;

        console.log('[FEC] recordId ===>', recordId);
        console.log('[FEC] sectionType ===>', sectionType);

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Transactions'
            },
            state: {
                c__transactionId: recordId,
                c__sectionType: sectionType
            }
        });
    }
}