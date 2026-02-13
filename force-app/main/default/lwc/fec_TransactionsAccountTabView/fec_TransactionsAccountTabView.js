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

export default class Fec_TransactionsAccountTabView extends LightningElement {

    /* ================= STATE ================= */
    @track transaction = null;
    transactionId;
    sectionType;
    isLoading = false;

    /* ================= FIELD CONFIG ================= */
    unbilledFields = [
        { label: 'Transaction Code', fieldName: 'transactionCode', apiName: 'FEC_Transaction_Code__c' },
        { label: 'Effective Date', fieldName: 'effectiveDate', apiName: 'FEC_Effective_Date__c' },
        { label: 'Credit Debit Flag', fieldName: 'creditDebitFlag', apiName: 'FEC_Credit_Debit_Flag__c' },
        { label: 'Merchant Description', fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: 'Transaction Plan', fieldName: 'plan', apiName: 'FEC_Transaction_Plan__c' },
        { label: 'Post Date', fieldName: 'postingDate', apiName: 'FEC_Post_Date__c' },
        { label: 'Currency Code', fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' },
        { label: 'Merchant Category Code', fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: 'Authorization Code', fieldName: 'authCode', apiName: 'FEC_Authorization_Code__c' },
        { label: 'Transaction Amount', fieldName: 'amount', apiName: 'FEC_Transaction_Amount__c' },
        { label: 'OTP Sent', fieldName: 'otpSent', apiName: 'FEC_OTP_Sent__c' },
    ];

    pendingFields = [
        { label: 'Transaction Code', fieldName: 'transactionCode', apiName: 'FEC_Transaction_Code__c' },
        { label: 'Effective Date', fieldName: 'effectiveDate', apiName: 'FEC_Effective_Date__c' },
        { label: 'Authorization Response', fieldName: 'authorizationResponse', apiName: 'FEC_Authorization_Response__c' },
        { label: 'Merchant Description', fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: 'Transaction Plan', fieldName: 'plan', apiName: 'FEC_Transaction_Plan__c' },
        { label: 'Transaction Amount', fieldName: 'amount', apiName: 'FEC_Transaction_Amount__c' },
        { label: 'Decline Description', fieldName: 'declineDescription', apiName: 'FEC_Decline_Description__c' },
        { label: 'Merchant Category Code', fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: 'Authorization Code', fieldName: 'authCode', apiName: 'FEC_Authorization_Code__c' },
        { label: 'Approval Code', fieldName: 'approvalCode', apiName: 'FEC_Approval_Code__c' },
        { label: 'Currency Code', fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' }
    ];

    billedFields = [
        { label: 'Transaction Code', fieldName: 'transactionCode', apiName: 'FEC_Transaction_Code__c' },
        { label: 'Effective Date', fieldName: 'effectiveDate', apiName: 'FEC_Effective_Date__c' },
        { label: 'Credit Debit Flag', fieldName: 'creditDebitFlag', apiName: 'FEC_Credit_Debit_Flag__c' },
        { label: 'Merchant Description', fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: 'Transaction Plan', fieldName: 'plan', apiName: 'FEC_Transaction_Plan__c' },
        { label: 'Post Date', fieldName: 'postingDate', apiName: 'FEC_Post_Date__c' },
        { label: 'Currency Code', fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' },
        { label: 'Merchant Category Code', fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: 'Authorization Code', fieldName: 'authCode', apiName: 'FEC_Authorization_Code__c' },
        { label: 'Transaction Amount', fieldName: 'amount', apiName: 'FEC_Transaction_Amount__c' },
        { label: 'OTP Sent', fieldName: 'otpSent', apiName: 'FEC_OTP_Sent__c' }
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

        return new Intl.DateTimeFormat('vi-VN', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        }).format(d);
    }

    formatNumber(value) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(value);
    }
}
