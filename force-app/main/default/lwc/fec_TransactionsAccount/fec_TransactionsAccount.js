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

import FEC_Transaction_Code from '@salesforce/label/c.FEC_Transaction_Code';
import FEC_Unbilled_Transactions from '@salesforce/label/c.FEC_Unbilled_Transactions';
import FEC_Transaction_Plan from '@salesforce/label/c.FEC_Transaction_Plan';
import FEC_Effective_Date from '@salesforce/label/c.FEC_Effective_Date';
import FEC_Authorization_Code from '@salesforce/label/c.FEC_Authorization_Code';
import FEC_Post_Date from '@salesforce/label/c.FEC_Post_Date';
import FEC_Credit_Debit_Flag from '@salesforce/label/c.FEC_Credit_Debit_Flag';
import FEC_Transaction_Amount from '@salesforce/label/c.FEC_Transaction_Amount';
import FEC_Currency_Code from '@salesforce/label/c.FEC_Currency_Code';
import FEC_Merchant_Description from '@salesforce/label/c.FEC_Merchant_Description';
import FEC_OTP_Sent from '@salesforce/label/c.FEC_OTP_Sent';
import FEC_Merchant_Category_Code from '@salesforce/label/c.FEC_Merchant_Category_Code';
import FEC_Pending_Transactions from '@salesforce/label/c.FEC_Pending_Transactions';
import FEC_Authorization_Response from '@salesforce/label/c.FEC_Authorization_Response';
import FEC_Decline_Description from '@salesforce/label/c.FEC_Decline_Description';
import FEC_Approval_Code from '@salesforce/label/c.FEC_Approval_Code';

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

    customLabel = {
        transactionCodeLabel: FEC_Transaction_Code,
        unbilledTransactionsLabel: FEC_Unbilled_Transactions,
        transactionPlanLabel: FEC_Transaction_Plan,
        effectiveDateLabel: FEC_Effective_Date,
        authorizationCodeLabel: FEC_Authorization_Code,
        postDateLabel: FEC_Post_Date,
        creditDebitFlagLabel: FEC_Credit_Debit_Flag,
        transactionAmountLabel: FEC_Transaction_Amount,
        currencyCodeLabel: FEC_Currency_Code,
        merchantDescriptionLabel: FEC_Merchant_Description,
        otpSentLabel: FEC_OTP_Sent,
        merchantCategoryCodeLabel: FEC_Merchant_Category_Code,
        pendingTransactionsLabel: FEC_Pending_Transactions,
        authorizationResponseLabel: FEC_Authorization_Response,
        declineDescriptionLabel: FEC_Decline_Description,
        approvalCodeLabel: FEC_Approval_Code
    }

    /* ================= COLUMNS ================= */
    unbilledTransactionsColumns = [
        {
            label: this.customLabel.transactionCodeLabel,
            fieldName: 'transactionCode',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: this.customLabel.unbilledTransactionsLabel,
            cellAlign: 'center',
            hoverFields: [
                { label: this.customLabel.transactionCodeLabel, fieldName: 'transactionCode' },
                { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlan' },
                { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate' },
                { label: this.customLabel.authorizationCodeLabel, fieldName: 'authorizationCode' },
                { label: this.customLabel.postDateLabel, fieldName: 'postDate' },
                { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag' },
                { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmount' },
                { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode' },
                { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription' },
                { label: this.customLabel.otpSentLabel, fieldName: 'otpSent' },
                { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode' }
            ]
        },
        {
            label: this.customLabel.effectiveDateLabel,
            fieldName: 'effectiveDate',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: this.customLabel.postDateLabel,
            fieldName: 'postDate',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: this.customLabel.transactionAmountLabel,
            fieldName: 'transactionAmount',
            type: 'text',
            cellAlign: 'right'
        },
        {
            label: this.customLabel.merchantDescriptionLabel,
            fieldName: 'merchantDescription',
            type: 'text',
            width: '240px'
        },
        {
            label: this.customLabel.creditDebitFlagLabel,
            fieldName: 'creditDebitFlag',
            type: 'text',
            cellAlign: 'center'
        }
    ];

    pendingTransactionsColumns = [
        {
            label: this.customLabel.transactionCodeLabel,
            fieldName: 'transactionCode',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: this.customLabel.pendingTransactionsLabel,
            cellAlign: 'center',
            hoverFields: [
                { label: this.customLabel.transactionCodeLabel, fieldName: 'transactionCode' },
                { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlan' },
                { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate' },
                { label: this.customLabel.authorizationCodeLabel, fieldName: 'authorizationCode' },
                { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmount' },
                { label: this.customLabel.authorizationResponseLabel, fieldName: 'authorizationResponse' },
                { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription' },
                { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode' },
                { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode' },
                { label: this.customLabel.declineDescriptionLabel, fieldName: 'declineDescription' },
                { label: this.customLabel.approvalCodeLabel, fieldName: 'approvalCode' }
            ]
        },
        {
            label: this.customLabel.effectiveDateLabel,
            fieldName: 'effectiveDate',
            type: 'text',
            cellAlign: 'center'
        },
        {
            label: this.customLabel.transactionAmountLabel,
            fieldName: 'transactionAmount',
            type: 'text',
            cellAlign: 'right'
        },
        {
            label: this.customLabel.merchantDescriptionLabel,
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