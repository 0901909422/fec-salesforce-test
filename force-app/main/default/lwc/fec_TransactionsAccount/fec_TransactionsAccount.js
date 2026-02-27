/****************************************************************************************
 * File Name    : Fec_TransactionsAccount.js
 * Author       : Quangdv7
 * Date         : 2025-01-16
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-16     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import loadTransactions from '@salesforce/apex/FEC_TransactionsController.loadTransactions';

export default class Fec_TransactionsAccount extends NavigationMixin(LightningElement) {

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
            cellAlign: 'center',
            hoverFields: [
                { label: 'Transaction Code', fieldName: 'transactionCode' },
                { label: 'Transaction Plan', fieldName: 'transactionPlan' },
                { label: 'Effective Date', fieldName: 'effectiveDate' },
                { label: 'Authorization Code', fieldName: 'authorizationCode' },
                { label: 'Post Date', fieldName: 'postDate' },
                { label: 'Credit Debit Flag', fieldName: 'creditDebitFlag' },
                { label: 'Transaction Amount', fieldName: 'transactionAmount' },
                { label: 'Currency Code', fieldName: 'currencyCode' },
                { label: 'Merchant Description', fieldName: 'merchantDescription' },
                { label: 'OTP Sent', fieldName: 'otpSent' },
                { label: 'Merchant Category Code', fieldName: 'merchantCategoryCode' }
            ]
        },
        {
            label: 'Effective Date',
            fieldName: 'effectiveDate',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: 'Post Date',
            fieldName: 'postDate',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: 'Transaction Amount',
            fieldName: 'transactionAmount',
            type: 'text',
            cellAlign: 'right'
        },
        {
            label: 'Merchant Description',
            fieldName: 'merchantDescription',
            type: 'text',
            width: '240px'
        },
        {
            label: 'Credit Debit Flag',
            fieldName: 'creditDebitFlag',
            type: 'text',
            cellAlign: 'center'
        }
    ];

    pendingTransactionsColumns = [
        {
            label: 'Transaction Code',
            fieldName: 'transactionCode',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: 'Pending Transactions',
            cellAlign: 'center',
            hoverFields: [
                { label: 'Transaction Code', fieldName: 'transactionCode' },
                { label: 'Transaction Plan', fieldName: 'transactionPlan' },
                { label: 'Effective Date', fieldName: 'effectiveDate' },
                { label: 'Authorization Code', fieldName: 'authorizationCode' },
                { label: 'Transaction Amount', fieldName: 'transactionAmount' },
                { label: 'Authorization Response', fieldName: 'authorizationResponse' },
                { label: 'Merchant Description', fieldName: 'merchantDescription' },
                { label: 'Currency Code', fieldName: 'currencyCode' },
                { label: 'Merchant Category Code', fieldName: 'merchantCategoryCode' },
                { label: 'Decline Description', fieldName: 'declineDescription' },
                { label: 'Approval Code', fieldName: 'approvalCode' }
            ]
        },
        {
            label: 'Effective Date',
            fieldName: 'effectiveDate',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: 'Transaction Amount',
            fieldName: 'transactionAmount',
            type: 'text',
            cellAlign: 'right'
        },
        {
            label: 'Merchant Description',
            fieldName: 'merchantDescription',
            type: 'text'
        }
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

        loadTransactions({ caseId: this.recordId })
            .then(res => {
                const unbilled = Array.isArray(res?.unbilledTransactions)
                    ? res.unbilledTransactions
                    : [];

                const pending = Array.isArray(res?.pendingTransactions)
                    ? res.pendingTransactions
                    : [];

                this.unbilledTransactions = unbilled.map(tx =>
                    this.mapUnbilled(tx)
                );

                this.pendingTransactions = pending.map(tx =>
                    this.mapPending(tx)
                );
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
   mapUnbilled(tx) {
        return {
            ...tx,
            Id: tx.Id,

            transactionCode: tx.transactionCode || '',
            merchantDescription: tx.merchantDescription || '',
            creditDebitFlag: tx.creditDebitFlag || '',

            effectiveDate: this.formatDate(tx.effectiveDate),
            postDate: this.formatDate(tx.postingDate),
            transactionAmount: this.formatNumber(tx.transactionAmount),

            transactionPlan: tx.transactionPlan || '',
            authorizationCode: tx.authorizationCode || '',
            currencyCode: tx.currencyCode || '',
            merchantCategoryCode: tx.merchantCategoryCode || '',
            otpSent: tx.otpSent || ''
        };
    }

    mapPending(tx) {
        return {
            Id: tx.Id,

            transactionCode: tx.transactionCode || '',
            merchantDescription: tx.merchantDescription || '',

            effectiveDate: this.formatDate(tx.effectiveDate),
            transactionAmount: this.formatNumber(tx.transactionAmount),
            transactionPlan: tx.transactionPlan || '',
            authorizationCode: tx.authorizationCode || '',
            merchantCategoryCode: tx.merchantCategoryCode || '',
            currencyCode: tx.currencyCode || '',

            authorizationResponse: tx.authorizationResponse || '',
            declineDescription: tx.declineDescription || '',
            declineReasonCode: tx.declineReasonCode || '',
            approvalCode: tx.approvalCode || ''
        };
    }

    /* ================= FORMATTERS ================= */
    formatDate(value) {
        if (!value) return '';

        try {
            const d = new Date(value);
            if (isNaN(d.getTime())) return value;

            const day = String(d.getDate()).padStart(2, '0');
            const month = String(d.getMonth() + 1).padStart(2, '0');
            const year = d.getFullYear();

            const hours = String(d.getHours()).padStart(2, '0');
            const minutes = String(d.getMinutes()).padStart(2, '0');
            const seconds = String(d.getSeconds()).padStart(2, '0');

            return `${day}/${month}/${year}, ${hours}:${minutes}:${seconds}`;
        } catch (e) {
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

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'FEC_Transactions'
            },
            state: {
                c__transactionId: recordId,
                c__sectionType: sectionType
            }
        });
    }
}