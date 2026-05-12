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
   1.1      2026-05-12     Agent                Unbilled: show dual-source columns (BasicInfo | M_FAS); sort effective by effectiveSortEpoch
   1.2      2026-05-12     Agent                Unbilled table: Currency Code, Merchant Category Code, OTP Sent columns
   1.3      2026-05-12     Agent                Pending: columns per sheet; M_FAS AUTHS rows; dual vs VMX detail (detail null); no row nav without Id
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import loadTransactions from '@salesforce/apex/FEC_TransactionsController.loadTransactions';
import { formatDateVNI, formatDateTime, formatNumber } from 'c/fec_CommonUtils';

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
                { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlanDualDisplay' },
                { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDateDualDisplay' },
                { label: this.customLabel.authorizationCodeLabel, fieldName: 'authorizationCodeDualDisplay' },
                { label: this.customLabel.postDateLabel, fieldName: 'postDateDualDisplay' },
                { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag' },
                { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmountDualDisplay' },
                { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode' },
                { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription' },
                { label: this.customLabel.otpSentLabel, fieldName: 'otpSent' },
                { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode' }
            ]
        },
        {
            label: this.customLabel.effectiveDateLabel,
            fieldName: 'effectiveDateDualDisplay',
            sortFieldName: 'effectiveSortEpoch',
            type: 'text',
            cellAlign: 'left',
            width: '260px'
        },
        {
            label: this.customLabel.postDateLabel,
            fieldName: 'postDateDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '240px'
        },
        {
            label: this.customLabel.transactionAmountLabel,
            fieldName: 'transactionAmountDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '220px'
        },
        {
            label: this.customLabel.authorizationCodeLabel,
            fieldName: 'authorizationCodeDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '220px'
        },
        {
            label: this.customLabel.transactionPlanLabel,
            fieldName: 'transactionPlanDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '200px'
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
        },
        {
            label: this.customLabel.currencyCodeLabel,
            fieldName: 'currencyCode',
            type: 'text',
            cellAlign: 'center',
            width: '100px'
        },
        {
            label: this.customLabel.merchantCategoryCodeLabel,
            fieldName: 'merchantCategoryCode',
            type: 'text',
            cellAlign: 'center',
            width: '100px'
        },
        {
            label: this.customLabel.otpSentLabel,
            fieldName: 'otpSent',
            type: 'text',
            cellAlign: 'center',
            width: '88px'
        }
    ];

    pendingTransactionsColumns = [
        {
            label: this.customLabel.effectiveDateLabel,
            fieldName: 'effectiveDateDualDisplay',
            sortFieldName: 'effectiveSortEpoch',
            type: 'text',
            cellAlign: 'left',
            width: '200px'
        },
        {
            label: this.customLabel.transactionAmountLabel,
            fieldName: 'transactionAmountDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '160px'
        },
        {
            label: this.customLabel.merchantDescriptionLabel,
            fieldName: 'merchantDescriptionDualDisplay',
            type: 'text',
            width: '220px'
        },
        {
            label: this.customLabel.transactionPlanLabel,
            fieldName: 'transactionPlanDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '120px'
        },
        {
            label: this.customLabel.merchantCategoryCodeLabel,
            fieldName: 'merchantCategoryDualDisplay',
            type: 'text',
            cellAlign: 'center',
            width: '100px'
        },
        {
            label: this.customLabel.currencyCodeLabel,
            fieldName: 'currencyCodeDualDisplay',
            type: 'text',
            cellAlign: 'center',
            width: '100px'
        },
        {
            label: this.customLabel.approvalCodeLabel,
            fieldName: 'approvalCodeDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '120px'
        },
        {
            label: this.customLabel.authorizationResponseLabel,
            fieldName: 'authorizationResponseDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '160px'
        },
        {
            label: this.customLabel.declineDescriptionLabel,
            fieldName: 'declineDescriptionDualDisplay',
            type: 'text',
            cellAlign: 'left',
            width: '200px'
        }
    ];

    /* ================= LIFECYCLE ================= */
    connectedCallback() {
        this.loadTransactions();
    }

    /* ================= LOAD DATA ================= */
    loadTransactions() {
        if (!this.recordId) {
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
        const effectiveSortEpoch =
            tx.effectiveSortEpoch != null && tx.effectiveSortEpoch !== undefined
                ? Number(tx.effectiveSortEpoch)
                : tx.effectiveDate
                    ? Date.parse(tx.effectiveDate)
                    : 0;

        return {
            Id: tx.Id,

            transactionCode: tx.transactionCode || '',
            merchantDescription: tx.merchantDescription || '',
            creditDebitFlag: tx.creditDebitFlag || '',

            effectiveDateDualDisplay:
                tx.effectiveDateDualDisplay || formatDateTime(tx.effectiveDate),
            postDateDualDisplay:
                tx.postDateDualDisplay || formatDateVNI(tx.postingDate),
            transactionAmountDualDisplay:
                tx.transactionAmountDualDisplay || formatNumber(tx.transactionAmount),
            authorizationCodeDualDisplay:
                tx.authorizationCodeDualDisplay || (tx.authorizationCode || ''),
            transactionPlanDualDisplay:
                tx.transactionPlanDualDisplay || (tx.transactionPlan || ''),

            effectiveSortEpoch,

            effectiveDate: formatDateTime(tx.effectiveDate),
            postDate: formatDateVNI(tx.postingDate),
            transactionAmount: formatNumber(tx.transactionAmount),

            transactionPlan: tx.transactionPlan || '',
            authorizationCode: tx.authorizationCode || '',
            currencyCode: tx.currencyCode || '',
            merchantCategoryCode: tx.merchantCategoryCode || '',
            otpSent: tx.otpSent || ''
        };
    }

    mapPending(tx) {
        const effectiveSortEpoch =
            tx.effectiveSortEpoch != null && tx.effectiveSortEpoch !== undefined
                ? Number(tx.effectiveSortEpoch)
                : tx.effectiveDate
                    ? Date.parse(tx.effectiveDate)
                    : 0;

        return {
            Id: tx.Id,
            effectiveSortEpoch,

            effectiveDateDualDisplay:
                tx.effectiveDateDualDisplay || formatDateTime(tx.effectiveDate),
            transactionAmountDualDisplay:
                tx.transactionAmountDualDisplay ||
                formatNumber(tx.transactionAmount),
            merchantDescriptionDualDisplay:
                tx.merchantDescriptionDualDisplay || (tx.merchantDescription || ''),
            transactionPlanDualDisplay:
                tx.transactionPlanDualDisplay || (tx.transactionPlan || ''),
            merchantCategoryDualDisplay:
                tx.merchantCategoryDualDisplay || (tx.merchantCategoryCode || ''),
            currencyCodeDualDisplay:
                tx.currencyCodeDualDisplay || (tx.currencyCode || ''),
            approvalCodeDualDisplay:
                tx.approvalCodeDualDisplay || (tx.approvalCode || ''),
            authorizationResponseDualDisplay:
                tx.authorizationResponseDualDisplay ||
                (tx.authorizationResponse || ''),
            declineDescriptionDualDisplay:
                tx.declineDescriptionDualDisplay || (tx.declineDescription || ''),

            effectiveDate: formatDateTime(tx.effectiveDate),
            transactionAmount: formatNumber(tx.transactionAmount),
            merchantDescription: tx.merchantDescription || '',
            transactionPlan: tx.transactionPlan || '',
            merchantCategoryCode: tx.merchantCategoryCode || '',
            currencyCode: tx.currencyCode || '',
            approvalCode: tx.approvalCode || '',
            authorizationResponse: tx.authorizationResponse || '',
            declineDescription: tx.declineDescription || ''
        };
    }

    /* ================= ROW SELECT ================= */
    handleTransactionSelect(event) {
        const recordId = event.detail?.recordId;
        const sectionType = event.currentTarget?.dataset?.section;

        if (sectionType === 'pending') {
            return;
        }
        if (!recordId) {
            return;
        }

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