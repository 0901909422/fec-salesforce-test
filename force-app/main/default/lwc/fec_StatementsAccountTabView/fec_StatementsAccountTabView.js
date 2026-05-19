/****************************************************************************************
 * File Name    : Fec_StatementsAccountTabView.js
 * Author       : Quangdv7
 * Date         : 2025-01-15
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
   1.1      2026-05-12     Agent                Billed tx: GetCardFinancialTransactions; VN column labels; sort by effectiveSortEpoch
 
****************************************************************************************/

import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { getFocusedTabInfo, openSubtab } from 'lightning/platformWorkspaceApi';
import { setConsoleTab } from 'c/fec_CommonUtils';

import loadStatementDetails from '@salesforce/apex/FEC_StatementsAccountController.loadStatementDetails';
import getBilledTransactions from '@salesforce/apex/FEC_StatementsAccountController.getBilledTransactions';

import FEC_Statement from '@salesforce/label/c.FEC_Statement';
import FEC_Billed_Transactions from '@salesforce/label/c.FEC_Billed_Transactions';
import FEC_MSG_No_statement_selected from '@salesforce/label/c.FEC_MSG_No_statement_selected';
import FEC_Total_Payment_Due from '@salesforce/label/c.FEC_Total_Payment_Due';
import FEC_Payment_Due_Date from '@salesforce/label/c.FEC_Payment_Due_Date';
import FEC_Minimum_Payment_Due from '@salesforce/label/c.FEC_Minimum_Payment_Due';
import FEC_Statement_Date from '@salesforce/label/c.FEC_Statement_Date';
import FEC_Total_Interest from '@salesforce/label/c.FEC_Total_Interest';
import FEC_Beginning_Balance from '@salesforce/label/c.FEC_Beginning_Balance';
import FEC_IPP_Principal from '@salesforce/label/c.FEC_IPP_Principal';
import FEC_End_Balance from '@salesforce/label/c.FEC_End_Balance';
import FEC_Total_Past_Due from '@salesforce/label/c.FEC_Total_Past_Due';
import FEC_Current_Payment_Due from '@salesforce/label/c.FEC_Current_Payment_Due';
import FEC_IPP_Interest from '@salesforce/label/c.FEC_IPP_Interest';
import FEC_Statement_Details from '@salesforce/label/c.FEC_Statement_Details';
import FEC_Transaction_Code from '@salesforce/label/c.FEC_Transaction_Code';
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

import FEC_BilledTx_Col_EffectiveDate from '@salesforce/label/c.FEC_BilledTx_Col_EffectiveDate';
import FEC_BilledTx_Col_PostDate from '@salesforce/label/c.FEC_BilledTx_Col_PostDate';
import FEC_BilledTx_Col_Amount from '@salesforce/label/c.FEC_BilledTx_Col_Amount';
import FEC_BilledTx_Col_Merchant from '@salesforce/label/c.FEC_BilledTx_Col_Merchant';
import FEC_BilledTx_Col_DebitCredit from '@salesforce/label/c.FEC_BilledTx_Col_DebitCredit';
import FEC_BilledTx_Col_Plan from '@salesforce/label/c.FEC_BilledTx_Col_Plan';
import FEC_BilledTx_Col_TxnCode from '@salesforce/label/c.FEC_BilledTx_Col_TxnCode';
import FEC_BilledTx_Col_AuthCode from '@salesforce/label/c.FEC_BilledTx_Col_AuthCode';
import FEC_BilledTx_Col_MCC from '@salesforce/label/c.FEC_BilledTx_Col_MCC';
import FEC_BilledTx_Col_Currency from '@salesforce/label/c.FEC_BilledTx_Col_Currency';
import FEC_BilledTx_Col_OTP from '@salesforce/label/c.FEC_BilledTx_Col_OTP';

export default class Fec_StatementsAccountTabView extends NavigationMixin(LightningElement) {

    // ==============================
    // STATE
    // ==============================
    @track statement;
    @track billedTransactions = [];
    @track isLoading = false;

    statementId;
    activeSections = ['statementDetail', 'billedTx'];

    // ==============================
    // LABELS (must be before columns that reference this.customLabel)
    // ==============================
    customLabel = {
        statementLabel: FEC_Statement,
        billedTransactionsLabel: FEC_Billed_Transactions,
        msgNoStatementSelected: FEC_MSG_No_statement_selected,
        totalPaymentDueLabel: FEC_Total_Payment_Due,
        paymentDueDateLabel: FEC_Payment_Due_Date,
        minimumPaymentDueLabel: FEC_Minimum_Payment_Due,
        statementDateLabel: FEC_Statement_Date,
        totalInterestLabel: FEC_Total_Interest,
        beginningBalanceLabel: FEC_Beginning_Balance,
        ippPrincipalLabel: FEC_IPP_Principal,
        endBalanceLabel: FEC_End_Balance,
        totalPastDueLabel: FEC_Total_Past_Due,
        currentPaymentDueLabel: FEC_Current_Payment_Due,
        ippInterestLabel: FEC_IPP_Interest,
        statementDetailsLabel: FEC_Statement_Details,
        transactionCodeLabel: FEC_Transaction_Code,
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
        billedColEffectiveDate: FEC_BilledTx_Col_EffectiveDate,
        billedColPostDate: FEC_BilledTx_Col_PostDate,
        billedColAmount: FEC_BilledTx_Col_Amount,
        billedColMerchant: FEC_BilledTx_Col_Merchant,
        billedColDebitCredit: FEC_BilledTx_Col_DebitCredit,
        billedColPlan: FEC_BilledTx_Col_Plan,
        billedColTxnCode: FEC_BilledTx_Col_TxnCode,
        billedColAuthCode: FEC_BilledTx_Col_AuthCode,
        billedColMcc: FEC_BilledTx_Col_MCC,
        billedColCurrency: FEC_BilledTx_Col_Currency,
        billedColOtp: FEC_BilledTx_Col_OTP
    };

    // ==============================
    // COLUMNS
    // ==============================
    billedTransactionsColumns = [
        {
            label: this.customLabel.transactionCodeLabel,
            fieldName: 'transactionCode',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: this.customLabel.billedTransactionsLabel,
            cellAlign: 'center',
            hoverFields: [
                { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate' },
                { label: this.customLabel.postDateLabel, fieldName: 'postDate' },
                { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmount' },
                { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription' },
                { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag' },
                { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlan' },
                { label: this.customLabel.transactionCodeLabel, fieldName: 'transactionCode' },
                { label: this.customLabel.authorizationCodeLabel, fieldName: 'authorizationCode' },
                { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode' },
                { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode' },
                { label: this.customLabel.otpSentLabel, fieldName: 'otpSent' }
            ]
        },
        { label: this.customLabel.effectiveDateLabel, fieldName: 'effectiveDate', type: 'text', cellAlign: 'center' },
        { label: this.customLabel.postDateLabel, fieldName: 'postDate', type: 'text', cellAlign: 'center' },
        { label: this.customLabel.transactionAmountLabel, fieldName: 'transactionAmount', type: 'text', cellAlign: 'right' },
        { label: this.customLabel.merchantDescriptionLabel, fieldName: 'merchantDescription', type: 'text', width: '240px' },
        { label: this.customLabel.creditDebitFlagLabel, fieldName: 'creditDebitFlag', type: 'text', cellAlign: 'center' },
        { label: this.customLabel.transactionPlanLabel, fieldName: 'transactionPlan', type: 'text', cellAlign: 'center' },
        { label: this.customLabel.authorizationCodeLabel, fieldName: 'authorizationCode', type: 'text', cellAlign: 'center' },
        { label: this.customLabel.merchantCategoryCodeLabel, fieldName: 'merchantCategoryCode', type: 'text', cellAlign: 'center' },
        { label: this.customLabel.currencyCodeLabel, fieldName: 'currencyCode', type: 'text', cellAlign: 'center' },
        { label: this.customLabel.otpSentLabel, fieldName: 'otpSent', type: 'text', cellAlign: 'center' },
        {
            label: this.customLabel.billedColTxnCode,
            fieldName: 'transactionCode',
            type: 'text',
            cellAlign: 'center',
            width: '120px'
        },
        {
            label: this.customLabel.billedColEffectiveDate,
            fieldName: 'effectiveDate',
            sortFieldName: 'effectiveSortEpoch',
            type: 'text',
            cellAlign: 'center',
            width: '120px'
        },
        {
            label: this.customLabel.billedColPostDate,
            fieldName: 'postDate',
            type: 'text',
            cellAlign: 'center',
            width: '120px'
        },
        {
            label: this.customLabel.billedColAmount,
            fieldName: 'transactionAmount',
            type: 'text',
            cellAlign: 'right',
            width: '140px'
        },
        {
            label: this.customLabel.billedColMerchant,
            fieldName: 'merchantDescription',
            type: 'text',
            width: '220px'
        },
        {
            label: this.customLabel.billedColDebitCredit,
            fieldName: 'creditDebitFlag',
            type: 'text',
            cellAlign: 'center',
            width: '120px'
        },
        {
            label: this.customLabel.billedColPlan,
            fieldName: 'transactionPlan',
            type: 'text',
            cellAlign: 'left',
            width: '100px'
        },
        {
            label: this.customLabel.billedColAuthCode,
            fieldName: 'authorizationCode',
            type: 'text',
            cellAlign: 'center',
            width: '120px'
        },
        {
            label: this.customLabel.billedColMcc,
            fieldName: 'merchantCategoryCode',
            type: 'text',
            cellAlign: 'center',
            width: '100px'
        },
        {
            label: this.customLabel.billedColCurrency,
            fieldName: 'currencyCode',
            type: 'text',
            cellAlign: 'center',
            width: '100px'
        },
        {
            label: this.customLabel.billedColOtp,
            fieldName: 'otpSent',
            type: 'text',
            cellAlign: 'center',
            width: '88px'
        }
    ];

    // ==============================
    // PAGE STATE
    // ==============================
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const idFromTab = pageRef?.state?.c__statementId;
        if (!idFromTab || idFromTab === this.statementId) return;

        this.statementId = idFromTab;
        this.loadData();
    }

    // ==============================
    // LOAD DATA
    // ==============================
    async loadData() {
        if (!this.statementId) return;

        this.isLoading = true;

        try {
            const [statementRes, billedTxRes] = await Promise.all([
                loadStatementDetails({ statementId: this.statementId }),
                getBilledTransactions({ statementId: this.statementId })
            ]);
           this.statement = Array.isArray(statementRes)
            ? statementRes.find(s => s.statementId === this.statementId)
            : null;
            this.billedTransactions = this.formatBilledTransactions(billedTxRes);
            setConsoleTab('Statements Detail', 'standard:record');

        } catch (error) {
            console.error('Load data error:', error);
            this.statement = null;
            this.billedTransactions = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ==============================
    // COMPUTED
    // ==============================
    get hasStatement() {
        return !!this.statement;
    }

    get statementSubTitle() {
        return this.formatDate(this.statement?.statementDate);
    }

    // ==============================
    // DETAIL SECTIONS 
    // ==============================
    get detailSections() {
        if (!this.statement) return [];

        const fields = [
            { label: this.customLabel.statementDateLabel, value: this.formatDate(this.statement.statementDate), apiName: 'FEC_Statement_Date__c' },
            { label: this.customLabel.totalPaymentDueLabel, value: this.formatNumber(this.statement.totalPaymentDue), apiName: 'FEC_Total_Payment_Due__c' },
            { label: this.customLabel.totalInterestLabel, value: this.formatNumber(this.statement.totalInterest), apiName: 'FEC_Total_Interest__c' },
            { label: this.customLabel.beginningBalanceLabel, value: this.formatNumber(this.statement.beginningBalance), apiName: 'FEC_Beginning_Balance__c' },
            { label: this.customLabel.paymentDueDateLabel, value: this.formatDate(this.statement.paymentDueDate), apiName: 'FEC_Payment_Due_Date__c' },
            { label: this.customLabel.minimumPaymentDueLabel, value: this.formatNumber(this.statement.minimumPaymentDue), apiName: 'FEC_Minimum_Payment_Due__c' },
            { label: this.customLabel.ippPrincipalLabel, value: this.formatNumber(this.statement.iPPPrincipal), apiName: 'FEC_IPP_Principal__c' },
            { label: this.customLabel.endBalanceLabel, value: this.formatNumber(this.statement.endBalance), apiName: 'FEC_End_Balance__c' },
            { label: this.customLabel.totalPastDueLabel, value: this.formatNumber(this.statement.totalPastDue), apiName: 'FEC_Total_Past_Due__c' },
            { label: this.customLabel.currentPaymentDueLabel, value: this.formatNumber(this.statement.currentPaymentDue), apiName: 'FEC_Current_Payment_Due__c' },
            { label: this.customLabel.ippInterestLabel, value: this.formatNumber(this.statement.iPPInterest), apiName: 'FEC_IPP_Interest__c' }
        ];
        return [
            {
                name: 'statementDetail',
                columns: 4,
                label: this.customLabel.statementDetailsLabel,
                fields: this.addHelpTextToFields(fields)
            }
        ];
    }

    // ==============================
    // FORMAT BILLED TX 
    // ==============================
    formatBilledTransactions(records) {
        if (!Array.isArray(records)) return [];

        return records.map((tx) => ({
            ...tx,
            effectiveDate: this.formatDate(tx.effectiveDate),
            postDate: this.formatDate(tx.postDate),
            postingDate: this.formatDate(tx.postDate),
            transactionAmount: this.formatNumber(tx.transactionAmount)
        }));
    }

    // ==============================
    // FORMAT HELPERS
    // ==============================
    formatDate(value) {
        if (!value) return '';
        const d = new Date(value);
        if (isNaN(d)) return value;

        return new Intl.DateTimeFormat('vi-VN', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        }).format(d);
    }

    formatNumber(value) {
        if (value === null || value === undefined || value === '') return '';
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(value);
    }

    addHelpTextToFields(fields) {
        if (!this.statement || !this.statement.helpTexts) {
            return fields;
        }

        const helpTexts = this.statement.helpTexts;

        return fields.map(f => {
            const apiName = f.apiName;
            const helpText =
                apiName
                    ? helpTexts[apiName] || helpTexts[apiName.toLowerCase()]
                    : null;

            return {
                ...f,
                helpText,
                hasHelpText: !!helpText
            };
        });
    }

    // ==============================
    // NAVIGATION
    // ==============================
    /**
     * Mở subtab Transaction detail (giống Statement Date → FEC_Statements).
     */
    async handleTransactionSelect(event) {
        const recordId = event.detail.recordId;
        if (!recordId) return;

        const row = this.billedTransactions.find((r) => r.Id === recordId);
        if (!row) return;

        const state = {
            c__transactionId: recordId,
            c__transactionCode: row.transactionCode,
            c__sectionType: 'billed',
            uid: recordId + '_' + Date.now()
        };

        try {
            const tabInfo = await getFocusedTabInfo();
            const parentTabId = tabInfo.isSubtab ? tabInfo.parentTabId : tabInfo.tabId;

            await openSubtab(parentTabId, {
                pageReference: {
                    type: 'standard__navItemPage',
                    attributes: {
                        apiName: 'FEC_Transactions'
                    },
                    state
                },
                focus: true,
                label: 'Transaction ' + row.transactionCode
            });
        } catch (e) {
            console.error('openSubtab Transaction failed', e);
            this[NavigationMixin.Navigate]({
                type: 'standard__navItemPage',
                attributes: { apiName: 'FEC_Transactions' },
                state
            });
        }
    }
}