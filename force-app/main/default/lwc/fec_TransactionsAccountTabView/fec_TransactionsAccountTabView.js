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
   1.1      2026-05-12     Agent                Unbilled detail: show dual-source strings when Apex provides *DualDisplay
   1.2      2026-05-12     Agent                Pending detail fields: sheet columns + dual *Display; drop removed pending fields
 
****************************************************************************************/

import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import loadTransactionDetail from '@salesforce/apex/FEC_TransactionsController.loadTransactionDetail';
import { setConsoleTab, formatDateTime, formatDateVNI, isNegative } from 'c/fec_CommonUtils';
import { LOCALE_ENG } from 'c/fec_CommonConst';

import FEC_Transaction from '@salesforce/label/c.FEC_Transaction';
import FEC_Billed_Transactions from '@salesforce/label/c.FEC_Billed_Transactions';
import FEC_Unbilled_Transactions from '@salesforce/label/c.FEC_Unbilled_Transactions';
import FEC_Pending_Transactions from '@salesforce/label/c.FEC_Pending_Transactions';
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
    transactionCodeFromState;
    sectionType;
    navUid;
    isLoading = false;
    activeSectionName = 'detail';

    customLabel = {
        transactionLabel: FEC_Transaction,
        billedTransactionsLabel: FEC_Billed_Transactions,
        unbilledTransactionsLabel: FEC_Unbilled_Transactions,
        pendingTransactionsLabel: FEC_Pending_Transactions,
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
        { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate', dualFieldName: 'effectiveDateDualDisplay', apiName: 'FEC_Effective_Date__c' },
        { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag', apiName: 'FEC_Credit_Debit_Flag__c' },
        { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlan', dualFieldName: 'transactionPlanDualDisplay', apiName: 'FEC_Transaction_Plan__c' },
        { label: this.customLabel.postDateLabel, fieldName: 'postingDate', dualFieldName: 'postDateDualDisplay', apiName: 'FEC_Post_Date__c' },
        { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' },
        { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: this.customLabel.authorizationCodeLabel, fieldName: 'authorizationCode', dualFieldName: 'authorizationCodeDualDisplay', apiName: 'FEC_Authorization_Code__c' },
        { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmount', dualFieldName: 'transactionAmountDualDisplay', apiName: 'FEC_Transaction_Amount__c' },
        { label: this.customLabel.otpSentLabel, fieldName: 'otpSent', apiName: 'FEC_OTP_Sent__c' }
    ];

    pendingFields = [
        { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate', dualFieldName: 'effectiveDateDualDisplay', apiName: 'FEC_Effective_Date__c' },
        { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmount', dualFieldName: 'transactionAmountDualDisplay', apiName: 'FEC_Transaction_Amount__c' },
        { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription', dualFieldName: 'merchantDescriptionDualDisplay', apiName: 'FEC_Merchant_Description__c' },
        { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlan', dualFieldName: 'transactionPlanDualDisplay', apiName: 'FEC_Transaction_Plan__c' },
        { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode', dualFieldName: 'merchantCategoryDualDisplay', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode', dualFieldName: 'currencyCodeDualDisplay', apiName: 'FEC_Currency_Code__c' },
        { label: this.customLabel.approvalCodeLabel, fieldName: 'approvalCode', dualFieldName: 'approvalCodeDualDisplay', apiName: 'FEC_Approval_Code__c' },
        { label: this.customLabel.authorizationResponseLabel, fieldName: 'authorizationResponse', dualFieldName: 'authorizationResponseDualDisplay', apiName: 'FEC_Authorization_Response__c' },
        { label: this.customLabel.declineDescriptionLabel, fieldName: 'declineDescription', dualFieldName: 'declineDescriptionDualDisplay', apiName: 'FEC_Decline_Description__c' }
    ];

    billedFields = [
        { label: this.customLabel.transactionCodeLabel, fieldName: 'transactionCode', apiName: 'FEC_Transaction_Code__c' },
        { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate', apiName: 'FEC_Effective_Date__c' },
        { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag', apiName: 'FEC_Credit_Debit_Flag__c' },
        { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription', apiName: 'FEC_Merchant_Description__c' },
        { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlan', apiName: 'FEC_Transaction_Plan__c' },
        { label: this.customLabel.postDateLabel, fieldName: 'postingDate', apiName: 'FEC_Post_Date__c' },
        { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode', apiName: 'FEC_Currency_Code__c' },
        { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode', apiName: 'FEC_Merchant_Category_Code__c' },
        { label: this.customLabel.authorizationCodeLabel, fieldName: 'authorizationCode', apiName: 'FEC_Authorization_Code__c' },
        { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmount', apiName: 'FEC_Transaction_Amount__c' },
        { label: this.customLabel.otpSentLabel, fieldName: 'otpSent', apiName: 'FEC_OTP_Sent__c' }
    ];

    /* ================= PAGE STATE ================= */
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (!pageRef?.state) return;

        const { c__transactionId, c__sectionType, c__transactionCode, uid } =
            pageRef.state;

        this.sectionType = c__sectionType || 'unbilled';
        this.transactionCodeFromState = c__transactionCode || this.transactionCodeFromState;

        if (!c__transactionId) {
            return;
        }

        if (c__transactionId === this.transactionId && uid === this.navUid) {
            return;
        }

        this.transactionId = c__transactionId;
        this.navUid = uid;
        this.transaction = null;
        this.loadDetail();
    }

    /* ================= LOAD DETAIL ================= */
    loadDetail() {
        if (!this.transactionId) return;

        this.isLoading = true;

        loadTransactionDetail({ transactionId: this.transactionId })
            .then(res => {
                this.transaction = res || null;
                setConsoleTab('Transactions Detail', 'standard:record');
            })
            .catch(() => {
                this.transaction = null;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get transactionSubTitle() {
        return this.transaction?.transactionCode || this.transactionCodeFromState || '';
    }

    get sectionLabel() {
        switch (this.sectionType) {
            case 'pending':
                return this.customLabel.pendingTransactionsLabel;
            case 'billed':
                return this.customLabel.billedTransactionsLabel;
            default:
                return this.customLabel.unbilledTransactionsLabel;
        }
    }

    get fieldConfig() {
        switch (this.sectionType) {
            case 'pending':
                return this.pendingFields;
            case 'billed':
                return this.billedFields;
            default:
                return this.unbilledFields;
        }
    }

    get detailFields() {
        if (!this.transaction) return [];

        const helpTexts = this.transaction.helpTexts || {};

        return this.fieldConfig.map(f => {
            const value = this.formatValue(f.fieldName, this.transaction[f.fieldName]);
            const helpText = f.apiName ? helpTexts[f.apiName] : null;

            return {
                key: f.fieldName,
                fieldName: f.fieldName,
                label: f.label,
                value,
                hasHelpText: !!helpText,
                helpText,
                valueClass: isNegative(value) ? 'slds-truncate text-red' : 'slds-wrap'
            };
        });
    }

    /** 4 columns — row-major field order (matches spec layout). */
    get fieldColumns() {
        const columns = [
            { key: 'col-0', fields: [] },
            { key: 'col-1', fields: [] },
            { key: 'col-2', fields: [] },
            { key: 'col-3', fields: [] }
                    const dualRaw =
                        f.dualFieldName != null
                            ? this.transaction[f.dualFieldName]
                            : null;
                    const useDual =
                        f.dualFieldName != null &&
                        dualRaw != null &&
                        String(dualRaw).trim() !== '';

                    return {
                        label: f.label,
                        value: useDual
                            ? dualRaw
                            : this.formatValue(
                                  f.fieldName,
                                  this.transaction[f.fieldName]
                              ),
                        hasHelpText: !!helpText,
                        helpText
                    };
                })
            }
        ];

        this.detailFields.forEach((field, index) => {
            columns[index % 4].fields.push(field);
        });

        return columns;
    }

    get hasData() {
        return !!this.transaction;
    }

    /* ================= FORMAT LOGIC ================= */
    formatValue(fieldName, value) {
        if (value === null || value === undefined || value === '') {
            return '-';
        }

        if (fieldName === 'effectiveDate') {
            return formatDateTime(value) || '-';
        }

        if (fieldName === 'postingDate') {
            return formatDateVNI(value) || '-';
        }

        if (this.isDateField(fieldName)) {
            return formatDateVNI(value) || '-';
        }

        if (this.isNumberField(fieldName)) {
            return this.formatNumber(value);
        }

        return value;
    }

    isDateField(fieldName) {
        if (fieldName.endsWith('DualDisplay')) {
            return false;
        }
        return fieldName.toLowerCase().includes('date');
    }

    isNumberField(fieldName) {
        if (fieldName.endsWith('DualDisplay')) {
            return false;
        }
        return [
            'amount',
            'balance',
            'total',
            'payment'
        ].some(key => fieldName.toLowerCase().includes(key));
    }

    formatNumber(value) {
        return new Intl.NumberFormat(LOCALE_ENG, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(value);
    }
}
