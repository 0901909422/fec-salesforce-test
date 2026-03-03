/****************************************************************************************
 * File Name    : FecTransactionsAccountTabView.js
 * Author       : Quangdv7
 * Date         : 2025-01-16
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-16     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import loadTransactionDetail from '@salesforce/apex/FEC_TransactionsController.loadTransactionDetail';
import { setConsoleTab } from 'c/fec_CommonUtils';
import { LOCALE_ENG, LOCALE_VN } from 'c/fec_CommonConst';

import FEC_Transaction from '@salesforce/label/c.FEC_Transaction';
import FEC_MSG_No_transaction_selected from '@salesforce/label/c.FEC_MSG_No_transaction_selected';
import FEC_Transaction_Code from '@salesforce/label/c.FEC_Transaction_Code';
import FEC_Effective_Date from '@salesforce/label/c.FEC_Effective_Date';
import FEC_Credit_Debit_Flag from '@salesforce/label/c.FEC_Credit_Debit_Flag';
import FEC_Merchant_Description from '@salesforce/label/c.FEC_Merchant_Description';
import FEC_Transaction_Plan from '@salesforce/label/c.FEC_Transaction_Plan';
import FEC_Post_Date from '@salesforce/label/c.FEC_Post_Date';
import FEC_Currency_Code from '@salesforce/label/c.FEC_Currency_Code';
import FEC_Merchant_Category_Code from '@salesforce/label/c.FEC_Merchant_Category_Code';
import FEC_Authorization_Code from '@salesforce/label/c.FEC_Authorization_Code';
import FEC_Transaction_Amount from '@salesforce/label/c.FEC_Transaction_Amount';
import FEC_OTP_Sent from '@salesforce/label/c.FEC_OTP_Sent';
import FEC_Authorization_Response from '@salesforce/label/c.FEC_Authorization_Response';
import FEC_Decline_Description from '@salesforce/label/c.FEC_Decline_Description';
import FEC_Approval_Code from '@salesforce/label/c.FEC_Approval_Code';

export default class Fec_TransactionsAccountTabView extends LightningElement {

    /* ================= STATE ================= */
    @track transaction = null;
    transactionId;
    sectionType;
    isLoading = false;

    customLabel = {
        transactionLabel: FEC_Transaction,
        msgNoTransactionSelected: FEC_MSG_No_transaction_selected,
        transactionCodeLabel: FEC_Transaction_Code,
        effectiveDateLabel: FEC_Effective_Date,
        creditDebitFlagLabel: FEC_Credit_Debit_Flag,
        merchantDescriptionLabel: FEC_Merchant_Description,
        transactionPlanLabel: FEC_Transaction_Plan,
        postDateLabel: FEC_Post_Date,
        currencyCodeLabel: FEC_Currency_Code,
        merchantCategoryCodeLabel: FEC_Merchant_Category_Code,
        authorizationCodeLabel: FEC_Authorization_Code,
        transactionAmountLabel: FEC_Transaction_Amount,
        otpSentLabel: FEC_OTP_Sent,
        authorizationResponseLabel: FEC_Authorization_Response,
        declineDescriptionLabel: FEC_Decline_Description,
        approvalCodeLabel: FEC_Approval_Code
    }

    /* ================= FIELD CONFIG ================= */
    unbilledFields = [
        { label: this.customLabel.transactionCodeLabel, fieldName: 'transactionCode', apiName: 'FEC_Transaction_Code__c' },
        { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate', apiName: 'FEC_Effective_Date__c' },
        { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag', apiName: 'FEC_Credit_Debit_Flag__c' },
        { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: this.customLabel.transactionPlanLabel, fieldName: 'plan', apiName: 'FEC_Transaction_Plan__c' },
        { label: this.customLabel.postDateLabel, fieldName: 'postingDate', apiName: 'FEC_Post_Date__c' },
        { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' },
        { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: this.customLabel.authorizationCodeLabel, fieldName: 'authCode', apiName: 'FEC_Authorization_Code__c' },
        { label: this.customLabel.transactionAmountLabel, fieldName: 'amount', apiName: 'FEC_Transaction_Amount__c' },
        { label: this.customLabel.otpSentLabel, fieldName: 'otpSent', apiName: 'FEC_OTP_Sent__c' }
    ];

    pendingFields = [
        { label: this.customLabel.transactionCodeLabel, fieldName: 'transactionCode', apiName: 'FEC_Transaction_Code__c' },
        { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate', apiName: 'FEC_Effective_Date__c' },
        { label: this.customLabel.authorizationResponseLabel, fieldName: 'authorizationResponse', apiName: 'FEC_Authorization_Response__c' },
        { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: this.customLabel.transactionPlanLabel, fieldName: 'plan', apiName: 'FEC_Transaction_Plan__c' },
        { label: this.customLabel.transactionAmountLabel, fieldName: 'amount', apiName: 'FEC_Transaction_Amount__c' },
        { label: this.customLabel.declineDescriptionLabel, fieldName: 'declineDescription', apiName: 'FEC_Decline_Description__c' },
        { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: this.customLabel.authorizationCodeLabel, fieldName: 'authCode', apiName: 'FEC_Authorization_Code__c' },
        { label: this.customLabel.approvalCodeLabel, fieldName: 'approvalCode', apiName: 'FEC_Approval_Code__c' },
        { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' }
    ];

    billedFields = [
        { label: this.customLabel.transactionCodeLabel, fieldName: 'transactionCode', apiName: 'FEC_Transaction_Code__c' },
        { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate', apiName: 'FEC_Effective_Date__c' },
        { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag', apiName: 'FEC_Credit_Debit_Flag__c' },
        { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: this.customLabel.transactionPlanLabel, fieldName: 'plan', apiName: 'FEC_Transaction_Plan__c' },
        { label: this.customLabel.postDateLabel, fieldName: 'postingDate', apiName: 'FEC_Post_Date__c' },
        { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' },
        { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: this.customLabel.authorizationCodeLabel, fieldName: 'authCode', apiName: 'FEC_Authorization_Code__c' },
        { label: this.customLabel.transactionAmountLabel, fieldName: 'amount', apiName: 'FEC_Transaction_Amount__c' },
        { label: this.customLabel.otpSentLabel, fieldName: 'otpSent', apiName: 'FEC_OTP_Sent__c' }
    ];

    /* ================= PAGE STATE ================= */
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (!pageRef?.state) return;

        const { c__transactionId, c__sectionType } = pageRef.state;

        this.sectionType = c__sectionType || 'unbilled';

        if (c__transactionId && c__transactionId !== this.transactionId) {
            this.transactionId = c__transactionId;
            this.loadDetail();
        }
    }

    /* ================= LOAD DETAIL ================= */
    loadDetail() {
        if (!this.transactionId) return;

        this.isLoading = true;

        loadTransactionDetail({ transactionId: this.transactionId })
            .then(res => {
                this.transaction = res;
            })
            .catch(() => {
                this.transaction = null;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= SET TABNAME ================= */
    connectedCallback() {
        setConsoleTab('Transactions Detail', 'standard:record');
    }

    /* ================= SECTIONS ================= */
    get sections() {
        if (!this.transaction) return [];

        let fields;
        let label;

        switch (this.sectionType) {
            case 'pending':
                fields = this.pendingFields;
                label = 'Pending Transaction';
                break;
            case 'billed':
                fields = this.billedFields;
                label = 'Billed Transaction';
                break;
            default:
                fields = this.unbilledFields;
                label = 'Unbilled Transaction';
        }

        const helpTexts = this.transaction.helpTexts || {};

        return [
            {
                name: this.sectionType,
                label,
                fields: fields.map(f => {
                    const helpText = f.apiName
                        ? helpTexts[f.apiName]
                        : null;

                    return {
                        label: f.label,
                        value: this.formatValue(
                            f.fieldName,
                            this.transaction[f.fieldName]
                        ),
                        hasHelpText: !!helpText,
                        helpText
                    };
                })
            }
        ];
    }

    get hasData() {
        return !!this.transaction;
    }

    /* ================= FORMAT LOGIC ================= */
    formatValue(fieldName, value) {
        if (value === null || value === undefined || value === '') {
            return '-';
        }

        if (this.isDateField(fieldName)) {
            return this.formatDate(value);
        }

        if (this.isNumberField(fieldName)) {
            return this.formatNumber(value);
        }

        return value;
    }

    isDateField(fieldName) {
        return fieldName.toLowerCase().includes('date');
    }

    isNumberField(fieldName) {
        return [
            'amount',
            'balance',
            'total',
            'payment'
        ].some(key => fieldName.toLowerCase().includes(key));
    }

    formatDate(value) {
        const d = new Date(value);
        if (isNaN(d)) return value;

        return new Intl.DateTimeFormat(LOCALE_VN, {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        }).format(d);
    }

    formatNumber(value) {
        return new Intl.NumberFormat(LOCALE_ENG, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(value);
    }
}
